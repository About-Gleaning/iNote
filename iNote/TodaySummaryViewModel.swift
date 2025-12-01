import Foundation
import SwiftData

@MainActor
class TodaySummaryViewModel: ObservableObject {
    @Published var state: LoadingState = .idle
    @Published var summary: String = ""
    @Published var errorMessage: String = ""
    
    private let qwenService = QwenService()
    
    enum LoadingState {
        case idle
        case loading
        case success
        case error
        case empty
    }
    
    func loadTodaySummary(context: ModelContext) async {
        state = .loading
        
        // Fetch today's notes
        let todayNotes = fetchTodayNotes(context: context)
        
        // Check if there are any notes today
        if todayNotes.isEmpty {
            state = .empty
            return
        }
        
        // Format notes for AI
        let formattedNotes = formatNotesForAI(notes: todayNotes)
        
        print("DEBUG: Sending \(todayNotes.count) notes to AI for today's summary")
        print("DEBUG: Formatted content length: \(formattedNotes.count) characters")
        
        // Call AI service
        do {
            let result = try await qwenService.summarizeToday(notes: formattedNotes)
            summary = result
            state = .success
        } catch QwenError.unauthorized(let msg) {
            errorMessage = "API密钥无效或未配置: \(msg)"
            state = .error
        } catch QwenError.paymentRequired(let msg) {
            errorMessage = "API额度不足: \(msg)"
            state = .error
        } catch {
            errorMessage = "生成总结失败: \(error.localizedDescription)"
            state = .error
        }
    }
    
    private func fetchTodayNotes(context: ModelContext) -> [Note] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = #Predicate<Note> { note in
            note.createdAt >= today && note.createdAt < tomorrow
        }
        
        let descriptor = FetchDescriptor<Note>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        
        do {
            let notes = try context.fetch(descriptor)
            print("DEBUG: Found \(notes.count) notes for today")
            return notes
        } catch {
            print("ERROR: Failed to fetch today's notes: \(error)")
            return []
        }
    }
    
    private func formatNotesForAI(notes: [Note]) -> String {
        var formatted = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        for (index, note) in notes.enumerated() {
            formatted += "--- 笔记 \(index + 1) ---\n"
            formatted += "创建时间: \(dateFormatter.string(from: note.createdAt))\n"
            
            if !note.title.isEmpty {
                formatted += "标题: \(note.title)\n"
            }
            
            if !note.content.isEmpty {
                formatted += "内容: \(note.content)\n"
            }
            
            if !note.transcript.isEmpty {
                formatted += "语音逐字稿: \(note.transcript)\n"
            }
            
            if !note.summary.isEmpty {
                formatted += "AI总结: \(note.summary)\n"
            }
            
            if !note.integratedSummary.isEmpty {
                formatted += "综合总结: \(note.integratedSummary)\n"
            }
            
            if !note.visualDescription.isEmpty {
                formatted += "视觉描述: \(note.visualDescription)\n"
            }
            
            if !note.visualTranscript.isEmpty {
                formatted += "视觉逐字稿: \(note.visualTranscript)\n"
            }
            
            if let tags = note.tags, !tags.isEmpty {
                let tagNames = tags.map { $0.name }.joined(separator: ", ")
                formatted += "标签: \(tagNames)\n"
            }
            
            formatted += "\n"
        }
        
        return formatted
    }
}
