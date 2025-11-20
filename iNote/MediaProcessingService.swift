import Foundation
import AVFoundation
import Speech

final class MediaProcessingService {
    func transcribeAudio(at url: URL) async throws -> String {
        let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard auth == .authorized else { return "" }
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        let request = SFSpeechURLRecognitionRequest(url: url)
        return try await withCheckedThrowingContinuation { cont in
            recognizer?.recognitionTask(with: request) { result, error in
                if let error = error { cont.resume(throwing: error); return }
                if let final = result, final.isFinal { cont.resume(returning: final.bestTranscription.formattedString) }
            }
        }
    }

    func summarizeAndDescribe(note: Note) async throws {
        let service = QwenService()
        var prompt = "请基于以下‘输入文本(可选)’与‘音频逐字稿’，只输出 JSON：{\"summary\": string}。要求：\n1) 总结80-150字\n2) 严格如实，不发散、不杜撰\n3) 使用中文\n"
        if !note.content.isEmpty { prompt += "输入文本：\n\(note.content)\n" }
        if !note.transcript.isEmpty { prompt += "音频逐字稿：\n\(note.transcript)\n" }
        let s = try await service.chat(prompt: prompt)
        func decodeDict(_ s: String) -> [String: Any]? {
            if let d = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return obj }
            if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}") {
                let sub = String(s[first...last])
                if let d2 = sub.data(using: .utf8), let obj2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any] { return obj2 }
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
        if let dict = decodeDict(s), let sum = pick(dict, keys: ["summary", "总结"]) {
            note.summary = sum
        } else {
            let fb = [note.content, note.transcript].filter{ !$0.isEmpty }.joined(separator: "\n")
            let trimmed = String(fb.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
            if !trimmed.isEmpty { note.summary = trimmed } else { note.summary = s }
        }
    }
}