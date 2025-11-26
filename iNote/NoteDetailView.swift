import SwiftUI
import AVFoundation
import AVKit

struct NoteDetailView: View {
    @Environment(\.modelContext) private var context
    @State var note: Note
    @State private var isEditing: Bool = false
    @State private var showMediaPreview: Bool = false
    @State private var selectedAssetIndex: Int = 0
    @State private var newTagName: String = ""
    @FocusState private var isTagFieldFocused: Bool
    @State private var showAddTagAlert: Bool = false

    private var visualAssets: [MediaAsset] {
        note.assets?.filter { $0.kind == MediaKind.image.rawValue || $0.kind == MediaKind.video.rawValue } ?? []
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Header (Title & Date)
                    if isEditing {
                        TextField("标题", text: $note.title)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(false)
                            .font(AppFonts.title1())
                            .foregroundColor(AppColors.primaryText)
                    } else if !note.title.isEmpty {
                        Text(note.title)
                            .font(AppFonts.title1())
                            .foregroundColor(AppColors.primaryText)
                    }
                    
                    Text(note.createdAt, style: .date)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.secondaryText)
                    
                    // 2. Visual Assets (Images & Videos)
                    if let images = note.assets?.filter({ $0.kind == MediaKind.image.rawValue }), !images.isEmpty {
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(images) { a in
                                if let url = a.validURL {
                                    Button(action: {
                                        if let index = visualAssets.firstIndex(of: a) {
                                            selectedAssetIndex = index
                                            showMediaPreview = true
                                        }
                                    }) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img): 
                                                img.resizable()
                                            case .failure(let error):
                                                let _ = print("DEBUG: AsyncImage failed to load \(url): \(error)")
                                                AppColors.background
                                            case .empty:
                                                AppColors.background
                                            @unknown default:
                                                AppColors.background
                                            }
                                        }
                                        .scaledToFill()
                                        .frame(height: 100)
                                        .clipped()
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let videos = note.assets?.filter({ $0.kind == MediaKind.video.rawValue }), !videos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(videos) { v in
                                if let url = v.validURL {
                                    VideoPlayer(player: AVPlayer(url: url))
                                        .frame(height: 220)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // 3. AI Analysis (Integrated Summary & Summary)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("综合总结")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.integratedSummary, minHeight: 100, placeholder: "请输入综合总结...")
                                .font(AppFonts.body())
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI总结")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.summary, minHeight: 100, placeholder: "请输入 AI 总结...")
                                .font(AppFonts.body())
                        }
                    } else {
                        if !note.integratedSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("综合总结")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.primaryText)
                                Text(note.integratedSummary)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(16)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            }
                        }
                        if !note.summary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI总结")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.primaryText)
                                Text(note.summary)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(16)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // 3.5 Link URL (if present)
                    if !note.linkURL.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("链接地址")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            if isEditing {
                                TextField("链接地址", text: $note.linkURL)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.primaryText)
                                    .padding(12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            } else {
                                Link(destination: URL(string: note.linkURL) ?? URL(string: "https://example.com")!) {
                                    Text(note.linkURL)
                                        .font(AppFonts.body())
                                        .foregroundColor(AppColors.accent)
                                        .underline()
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // 4. Visual Analysis (Description & Transcript)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("视觉描述")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.visualDescription, minHeight: 100, placeholder: "请输入视觉描述...")
                                .font(AppFonts.body())
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("视觉逐字稿")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.visualTranscript, minHeight: 120, placeholder: "请输入视觉逐字稿...")
                                .font(AppFonts.body())
                        }
                    } else {
                        if !note.visualDescription.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("视觉描述")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.primaryText)
                                Text(note.visualDescription)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(16)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            }
                        }
                        if !note.visualTranscript.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("视觉逐字稿")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.primaryText)
                                Text(note.visualTranscript)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(16)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                            }
                        }
                    }

                    // 5. Audio Analysis (Player & Transcript)
                    if let audios = note.assets?.filter({ $0.kind == MediaKind.audio.rawValue }), !audios.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("语音文件")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            ForEach(audios) { a in
                                if let url = a.validURL {
                                    AudioPlayerRow(url: url)
                                }
                            }
                        }
                    }
                    
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("语音逐字稿")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.transcript, minHeight: 120, placeholder: "请输入语音逐字稿...")
                                .font(AppFonts.body())
                        }
                    } else if !note.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("语音逐字稿")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            Text(note.transcript)
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.secondaryText)
                                .padding(16)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                        }
                    }
                    
                    // 6. User Content (Text)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("正文/备注")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.content, minHeight: 240, placeholder: "请输入正文...")
                                .font(AppFonts.body())
                        }
                    } else if !note.content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("正文/备注")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            Text(note.content)
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                        }
                    }
                    
                    // 7. Tags (AI Generated)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("标签")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // Add tag button
                                    Button(action: {
                                        newTagName = ""
                                        showAddTagAlert = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.accent)
                                            Text("标签")
                                                .font(AppFonts.caption())
                                                .foregroundColor(AppColors.accent)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(AppColors.accent, lineWidth: 1)
                                        )
                                        .cornerRadius(16)
                                    }
                                    
                                    // Display existing tags with remove button
                                    if let tags = note.tags, !tags.isEmpty {
                                        ForEach(tags, id: \.name) { tag in
                                            HStack(spacing: 4) {
                                                Text(tag.name)
                                                    .font(AppFonts.caption())
                                                    .foregroundColor(.white)
                                                Button(action: {
                                                    // Remove tag
                                                    note.tags?.removeAll { $0.name == tag.name }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.accent)
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                        }
                    } else if let tags = note.tags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("标签")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.name) { tag in
                                        Text(tag.name)
                                            .font(AppFonts.caption())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.accent)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppDimens.padding)
            }
        }
        .fullScreenCover(isPresented: $showMediaPreview) {
            MediaPreviewView(initialIndex: selectedAssetIndex, assets: visualAssets)
        }
        .navigationTitle("笔记")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.keyboard)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "完成" : "编辑") {
                    isEditing.toggle()
                    if !isEditing {
                        try? context.save()
                        NotificationCenter.default.post(name: .noteSaved, object: nil)
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { dismissKeyboard() }
            }
        }
        .alert("添加标签", isPresented: $showAddTagAlert) {
            TextField("标签名称", text: $newTagName)
            Button("取消", role: .cancel) {
                newTagName = ""
            }
            Button("添加") {
                addNewTag()
            }
        } message: {
            Text("请输入新标签的名称")
        }
    }

    private func addNewTag() {
        let tagName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tagName.isEmpty else { return }
        
        // Check if tag already exists
        if let existingTags = note.tags, existingTags.contains(where: { $0.name == tagName }) {
            newTagName = ""
            isTagFieldFocused = false
            return
        }
        
        // Create new tag
        let newTag = Tag(name: tagName)
        context.insert(newTag)
        
        // Add to note's tags
        if note.tags == nil {
            note.tags = []
        }
        note.tags?.append(newTag)
        
        // Clear input
        newTagName = ""
        isTagFieldFocused = false
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct AudioPlayerRow: View {
    let url: URL
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false

    var body: some View {
        HStack {
            Button(action: {
                if player == nil { player = AVPlayer(url: url) }
                if isPlaying { player?.pause(); isPlaying = false } else { player?.play(); isPlaying = true }
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accent)
            }
            
            Text(url.lastPathComponent)
                .font(AppFonts.subheadline())
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}