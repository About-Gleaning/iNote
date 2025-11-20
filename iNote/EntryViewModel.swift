import Foundation
import SwiftData
import AVFoundation
import UIKit

@MainActor
final class EntryViewModel: ObservableObject {
    enum Mode { case audioText, imageText, videoText }
    @Published var mode: Mode = .audioText
    @Published var text: String = ""
    @Published var isRecording: Bool = false
    @Published var currentNote: Note? = nil
    @Published var selectedTags: [Tag] = []
    @Published var pendingTranscription: String? = nil
    @Published var shouldShowEditor: Bool = false
    @Published var isNoteInserted: Bool = false

    private var recorder: AVAudioRecorder?
    private var autosaveTimer: Timer?

    func start(context: ModelContext) {
        if currentNote != nil { scheduleAutosave(context: context) }
    }

    func scheduleAutosave(context: ModelContext) {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let note = self.currentNote else { return }
                note.content = self.text
                if note.title.isEmpty {
                    note.title = self.text.split(separator: "\n").first.map(String.init) ?? note.title
                }
            }
        }
    }

    func toggleRecord(context: ModelContext) {
        if isRecording { stopRecord(context: context) } else { startRecord(context: context) }
    }

    private func startRecord(context: ModelContext) {
        beginNewNote(context: context)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("entry_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        isRecording = true
    }

    func beginNewNote(context: ModelContext) {
        let note = Note()
        currentNote = note
        isNoteInserted = false
        text = ""
        selectedTags = []
        pendingTranscription = nil
        scheduleAutosave(context: context)
    }

    private func stopRecord(context: ModelContext) {
        recorder?.stop()
        isRecording = false
        guard let url = recorder?.url else { return }
        attachMedia(kind: .audio, localURL: url, context: context)
        recorder = nil
        Task { await sendAudioAndTextToAI(audioURL: url, context: context) }
    }

    func attachImageData(_ datas: [Data], context: ModelContext) async {
        for data in datas {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("image_\(UUID().uuidString).jpg")
            try? data.write(to: tempURL)
            attachMedia(kind: .image, localURL: tempURL, context: context)
        }
        await analyzeVisualForCurrentNote()
    }

    func attachVideoURLs(_ urls: [URL], context: ModelContext) async {
        for url in urls { attachMedia(kind: .video, localURL: url, context: context) }
        await analyzeVisualForCurrentNote()
    }

    private func attachMedia(kind: MediaKind, localURL: URL, context: ModelContext) {
        if currentNote == nil {
            let note = Note()
            currentNote = note
            isNoteInserted = false
            scheduleAutosave(context: context)
        }
        guard let note = currentNote else { return }
        var finalURL = localURL
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let subDirName: String
        switch kind {
        case .audio: subDirName = "iNoteMedia/audio"
        case .image: subDirName = "iNoteMedia/images"
        case .video: subDirName = "iNoteMedia/videos"
        }
        
        let dir = docs.appendingPathComponent(subDirName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            print("DEBUG: Created directory at \(dir.path)")
        } catch {
            print("DEBUG: Failed to create directory \(dir.path): \(error)")
        }
        
        let dst = dir.appendingPathComponent(localURL.lastPathComponent)
        
        if localURL != dst {
            if FileManager.default.fileExists(atPath: dst.path) {
                print("DEBUG: File already exists at \(dst.path)")
                finalURL = dst
            } else {
                do {
                    // If the source is in a temporary location, we should copy it to the permanent location
                    try FileManager.default.copyItem(at: localURL, to: dst)
                    print("DEBUG: Successfully copied media from \(localURL.path) to \(dst.path)")
                    finalURL = dst
                } catch {
                    print("DEBUG: Failed to copy media from \(localURL.path) to \(dst.path): \(error)")
                    // If copy fails, we might still want to use the original URL if it's valid, 
                    // but for temp files this is risky. We'll log it and try to use the temp one for now 
                    // but this indicates a persistence failure.
                }
            }
        } else {
            print("DEBUG: localURL equals dst, no copy needed: \(localURL.path)")
        }
        
        let asset = MediaAsset()
        asset.kind = kind.rawValue
        // IMPORTANT: Store the relative path or a path that can be reconstructed. 
        // Storing the absolute path is fine IF we handle the container change in Models.swift (which we do).
        // However, to be safe, we are storing the absolute path of the *persisted* file.
        asset.localURLString = finalURL.absoluteString
        print("DEBUG: Created MediaAsset with localURLString: \(asset.localURLString ?? "nil")")
        
        if kind == .video {
            Task {
                let avAsset = AVURLAsset(url: finalURL)
                let gen = AVAssetImageGenerator(asset: avAsset)
                gen.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: 0.0, preferredTimescale: 600)
                if let cg = try? await generateCGImage(gen: gen, time: time) {
                    let ui = UIImage(cgImage: cg)
                    if let data = ui.jpegData(compressionQuality: 0.5) {
                        await MainActor.run {
                            asset.thumbnail = data
                        }
                    }
                }
            }
        }
        
        if note.assets == nil { note.assets = [] }
        note.assets?.append(asset)
    }

    func analyzeVisualForCurrentNote() async {
        guard let note = currentNote else { return }
        note.aiStatus = "requesting"
        var imagesData: [Data] = []
        if let assets = note.assets {
            for a in assets {
                guard let s = a.localURLString, let url = URL(string: s) else { continue }
                if a.kind == MediaKind.image.rawValue {
                    if let data = try? Data(contentsOf: url) { imagesData.append(data) }
                } else if a.kind == MediaKind.video.rawValue {
                    let asset = AVURLAsset(url: url)
                    let gen = AVAssetImageGenerator(asset: asset)
                    gen.appliesPreferredTrackTransform = true
                    let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                    if let cg = try? await generateCGImage(gen: gen, time: time) {
                        let ui = UIImage(cgImage: cg)
                        if let data = ui.jpegData(compressionQuality: 0.75) { imagesData.append(data) }
                    }
                }
            }
        }
        let service = QwenService()
        let instruction = "请基于这些图片/关键帧，只输出 JSON：{\"title\": string, \"description\": string, \"summary\": string, \"tags\": [string]}。要求：\n1) title 不超过15字\n2) description 详细描述图片与视频内容，500字内\n3) summary 80-150字，严格如实不发散\n4) tags 至多5个，中文，简短。"
        do {
            let out = try await service.analyzeImagesJSON(imagesData, instruction: instruction)
            func decodeDict(_ s: String) -> [String: Any]? {
                if let d = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return obj }
                if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
                    let sub = String(s[first...last])
                    if let d2 = sub.data(using: .utf8), let obj2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any] { return obj2 }
                }
                return nil
            }
            func pickStr(_ dict: [String: Any], keys: [String]) -> String? {
                var lowered: [String: Any] = [:]
                for (k, v) in dict { lowered[k.lowercased()] = v }
                for k in keys {
                    if let v = dict[k] as? String, !v.isEmpty { return v }
                    if let v = lowered[k.lowercased()] as? String, !v.isEmpty { return v }
                }
                return nil
            }
            func pickArr(_ dict: [String: Any], keys: [String]) -> [String]? {
                var lowered: [String: Any] = [:]
                for (k, v) in dict { lowered[k.lowercased()] = v }
                for k in keys {
                    if let v = dict[k] as? [String], !v.isEmpty { return v }
                    if let v = lowered[k.lowercased()] as? [String], !v.isEmpty { return v }
                }
                return nil
            }
            if let dict = decodeDict(out) {
                if let t = pickStr(dict, keys: ["title", "标题"]) { note.title = t }
                if let desc = pickStr(dict, keys: ["description", "视觉描述", "图像描述"]) { note.visualDescription = desc }
                if let sum = pickStr(dict, keys: ["summary", "总结"]) { note.summary = sum }
                if let tagNames = pickArr(dict, keys: ["tags", "标签"]) {
                    var tags: [Tag] = []
                    for name in tagNames.prefix(5) {
                        if let existed = note.tags?.first(where: { $0.name == name }) { tags.append(existed) }
                        else {
                            let t = Tag()
                            t.name = name
                            tags.append(t)
                        }
                    }
                    note.tags = tags
                }
            }
            note.aiStatus = "success"
            shouldShowEditor = true
            shouldShowEditor = true
        } catch {
            note.aiStatus = "error"
        }
    }

    private func generateCGImage(gen: AVAssetImageGenerator, time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            gen.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let cgImage = cgImage {
                    cont.resume(returning: cgImage)
                } else {
                    cont.resume(throwing: error ?? NSError(domain: "AVAssetImageGenerator", code: -1))
                }
            }
        }
    }

    func applyTags(_ tags: [Tag]) {
        guard let note = currentNote else { return }
        note.tags = tags
    }

    func finalize() {
        currentNote?.isDraft = false
    }

    func persistAndFinalize(context: ModelContext) {
        guard let note = currentNote else { return }
        if !isNoteInserted { context.insert(note); isNoteInserted = true }
        finalize()
    }

    func resetSession() {
        currentNote = nil
        text = ""
        selectedTags = []
        pendingTranscription = nil
        shouldShowEditor = false
        isNoteInserted = false
    }

    func sendAudioAndTextToAI(audioURL: URL, context: ModelContext) async {
        guard let note = currentNote else { return }
        note.aiStatus = "requesting"
        let service = QwenService()
        let prompt = """
        你是一个专业的语音内容分析师。请基于用户上传的音频，输出一个 JSON 对象，包含以下字段：

        {
          "title": "不超过15个汉字的标题",
          "transcript": "演讲稿（删除非语义填充成分；修正无意义重复；不改写、不总结、不润色，仅做最小必要清理；若有多位说话人，请用 [说话人A]、[说话人B] 标注",
          "summary": "80–150字的客观摘要，不得发散或添加外部信息"
        }
        
        只输出纯 JSON，不要额外文本。
        """
        do {
            print("Qwen 准备调用: chat(audio), 文本长度=\(text.count), 音频路径=\(audioURL.absoluteString)")
            let out = try await service.chat(text: prompt, audioURL: audioURL)
            func decodeDict(_ s: String) -> [String: Any]? {
                if let d = s.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return obj }
                if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
                    let sub = String(s[first...last])
                    if let d2 = sub.data(using: .utf8),
                       let obj2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any] { return obj2 }
                }
                return nil
            }
            func pick(_ dict: [String: Any], keys: [String]) -> String? {
                var lowered: [String: Any] = [:]
                for (k, v) in dict { lowered[k.lowercased()] = v }
                for k in keys {
                    if let v = dict[k] as? String, !v.isEmpty { return v }
                    if let v = lowered[k.lowercased()] as? String, !v.isEmpty { return v }
                }
                return nil
            }
            if let dict = decodeDict(out) {
                if let t = pick(dict, keys: ["title", "标题"]) { note.title = t }
                if let tr = pick(dict, keys: ["transcript", "逐字稿", "转写", "text"]) { note.transcript = tr; pendingTranscription = tr }
                if let s = pick(dict, keys: ["summary", "总结"]) { note.summary = s }
            } else {
                let processor = MediaProcessingService()
                if let localText = try? await processor.transcribeAudio(at: audioURL) {
                    note.transcript = localText
                    pendingTranscription = localText
                } else {
                    let fb = [text, note.transcript].filter{ !$0.isEmpty }.joined(separator: "\n")
                    let trimmed = String(fb.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
                    if !trimmed.isEmpty { note.summary = trimmed }
                }
            }
            if note.title.isEmpty {
                if !text.isEmpty { note.title = text.split(separator: "\n").first.map(String.init) ?? note.title }
                else if !note.transcript.isEmpty { note.title = String(note.transcript.prefix(15)) }
            }
            note.aiStatus = "success"
            shouldShowEditor = true
            shouldShowEditor = true
        } catch {
            if let e = error as? QwenError {
                switch e {
                case .missingAPIKey, .invalidAPIKey, .unauthorized:
                    note.aiStatus = "unauthorized"
                case .paymentRequired:
                    note.aiStatus = "payment_required"
                default:
                    note.aiStatus = "error"
                }
            } else {
                note.aiStatus = "error"
            }
            let processor = MediaProcessingService()
            if let localText = try? await processor.transcribeAudio(at: audioURL) {
                note.transcript = localText
                pendingTranscription = localText
            } else {
                let fallback = [text].compactMap{ $0 }.joined(separator: "\n")
                let trimmed = String(fallback.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
                if !trimmed.isEmpty { note.summary = trimmed }
            }
        }
    }
}