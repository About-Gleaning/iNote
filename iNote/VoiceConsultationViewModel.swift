import Foundation
import Speech
import AVFoundation
import SwiftData

@MainActor
class VoiceConsultationViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var liveTranscript = ""
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let qwenService = QwenService()
    
    // Base text to support appending new speech to existing manual edits
    private var baseText = ""
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let content: String
        let source_notes: [String]
        
        enum MessageRole {
            case user
            case ai
        }
    }
    
    struct ConsultationResponse: Codable {
        let reply_content: String
        let source_notes: [String]
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        // Cancel previous task if any
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Save current text as base
        baseText = liveTranscript
        if !baseText.isEmpty && !baseText.hasSuffix("\n") {
            baseText += " " // Add space separator if needed
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "无法激活音频会话"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                // Append new speech to base text
                self.liveTranscript = self.baseText + result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "无法启动录音引擎"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    func cancelRecording() {
        stopRecording()
        recognitionTask?.cancel()
        liveTranscript = ""
        errorMessage = nil
    }
    
    func submit(context: ModelContext) async {
        let query = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        stopRecording()
        
        // 1. Add User Message
        let userMsg = ChatMessage(role: .user, content: query, source_notes: [])
        messages.append(userMsg)
        
        // 2. Clear Input
        liveTranscript = ""
        baseText = ""
        
        isLoading = true
        errorMessage = nil
        
        // Gather context from notes
        let notesContext = await gatherNotesContext(context: context)
        
        // Build chat history context
        var historyContext = ""
        if !messages.isEmpty {
            historyContext = "对话历史：\n"
            for msg in messages.prefix(messages.count - 1) { // Exclude just added user msg to avoid duplication if we pass it separately, but here we pass query separately
                let roleStr = msg.role == .user ? "用户" : "AI"
                historyContext += "\(roleStr): \(msg.content)\n"
            }
        }
        
        let fullContext = "\(notesContext)\n\n\(historyContext)"
        
        do {
            let jsonString = try await qwenService.consult(query: query, context: fullContext)
            
            // Parse JSON
            if let data = jsonString.data(using: .utf8) {
                // Try to clean markdown code blocks if present
                let cleanData: Data
                if let str = String(data: data, encoding: .utf8) {
                    let cleaned = str.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                    cleanData = cleaned.data(using: .utf8) ?? data
                } else {
                    cleanData = data
                }
                
                let response = try JSONDecoder().decode(ConsultationResponse.self, from: cleanData)
                
                // 3. Add AI Message
                let aiMsg = ChatMessage(role: .ai, content: response.reply_content, source_notes: response.source_notes)
                messages.append(aiMsg)
            }
        } catch {
            errorMessage = "AI 咨询失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func findNote(by title: String, context: ModelContext) -> Note? {
        // Use a simple fetch and filter to avoid predicate issues with special characters
        let descriptor = FetchDescriptor<Note>()
        guard let notes = try? context.fetch(descriptor) else { return nil }
        return notes.first { $0.title == title }
    }

    private func gatherNotesContext(context: ModelContext) async -> String {
        // Fetch all notes
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let notes = try? context.fetch(descriptor) else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var contextStr = ""
        for (index, note) in notes.enumerated() {
            contextStr += "--- 笔记 \(index + 1) ---\n"
            contextStr += "创建时间: \(dateFormatter.string(from: note.createdAt))\n"
            if !note.title.isEmpty { contextStr += "标题: \(note.title)\n" }
            if !note.content.isEmpty { contextStr += "内容: \(note.content)\n" }
            if !note.summary.isEmpty { contextStr += "总结: \(note.summary)\n" }
            if !note.transcript.isEmpty { contextStr += "逐字稿: \(note.transcript)\n" }
            if !note.visualDescription.isEmpty { contextStr += "视觉描述: \(note.visualDescription)\n" }
            contextStr += "\n"
        }
        return contextStr
    }
}
