import Foundation
import SwiftData

enum MediaKind: String, Codable, CaseIterable {
    case audio
    case image
    case video
}

@Model
final class MediaAsset {
    var kind: String = MediaKind.image.rawValue
    var localURLString: String?
    var thumbnail: Data?
    var createdAt: Date = Date.now
    var note: Note?

    init(kind: MediaKind = .image,
         localURLString: String? = nil,
         thumbnail: Data? = nil,
         createdAt: Date = Date.now) {
        self.kind = kind.rawValue
        self.localURLString = localURLString
        self.thumbnail = thumbnail
        self.createdAt = createdAt
    }
    var validURL: URL? {
        guard let localURLString = localURLString else { return nil }
        if let url = URL(string: localURLString), url.scheme != "file" { return url }
        
        // Extract filename and reconstruct path relative to current Documents directory
        let filename = (localURLString as NSString).lastPathComponent
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Check common subdirectories
        let audioPath = docs.appendingPathComponent("iNoteMedia/audio").appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: audioPath.path) { return audioPath }
        
        let imagePath = docs.appendingPathComponent("iNoteMedia/images").appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: imagePath.path) { 
            print("DEBUG: Found image at \(imagePath.path)")
            return imagePath 
        } else {
            print("DEBUG: Image NOT found at \(imagePath.path)")
        }
        
        let videoPath = docs.appendingPathComponent("iNoteMedia/videos").appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: videoPath.path) { return videoPath }
        
        // Fallback to temp or direct check if it was just created
        if let url = URL(string: localURLString), FileManager.default.fileExists(atPath: url.path) { return url }
        
        return nil
    }
}

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#999999"
    @Relationship(deleteRule: .cascade) var notes: [Note]?

    init(name: String = "",
         colorHex: String = "#999999",
         notes: [Note]? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.notes = notes
    }
}

@Model
final class Note {
    var title: String = ""
    var content: String = ""
    var summary: String = ""
    var integratedSummary: String = ""
    var visualTranscript: String = ""
    var createdAt: Date = Date.now
    var isDraft: Bool = true
    var aiStatus: String = "idle"
    var transcript: String = ""
    var visualDescription: String = ""
    var linkURL: String = ""
    @Relationship(deleteRule: .cascade) var assets: [MediaAsset]?
    @Relationship(deleteRule: .nullify) var tags: [Tag]?

    init(title: String = "",
         content: String = "",
         summary: String = "",
         integratedSummary: String = "",
         visualTranscript: String = "",
         createdAt: Date = Date.now,
         isDraft: Bool = true,
         aiStatus: String = "idle",
         transcript: String = "",
         visualDescription: String = "",
         linkURL: String = "",
         assets: [MediaAsset]? = nil,
         tags: [Tag]? = nil) {
        self.title = title
        self.content = content
        self.summary = summary
        self.integratedSummary = integratedSummary
        self.visualTranscript = visualTranscript
        self.createdAt = createdAt
        self.isDraft = isDraft
        self.aiStatus = aiStatus
        self.transcript = transcript
        self.visualDescription = visualDescription
        self.linkURL = linkURL
        self.assets = assets
        self.tags = tags
    }
}
