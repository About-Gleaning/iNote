import SwiftUI
import AVFoundation
import AVKit

struct NoteDetailView: View {
    @Environment(\.modelContext) private var context
    @State var note: Note
    @State private var isEditing: Bool = false
    @State private var showMediaPreview: Bool = false
    @State private var selectedAssetIndex: Int = 0

    private var visualAssets: [MediaAsset] {
        note.assets?.filter { $0.kind == MediaKind.image.rawValue || $0.kind == MediaKind.video.rawValue } ?? []
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                    
                    if isEditing {
                        MultilineTextEditor(text: $note.content, minHeight: 240, placeholder: "请输入正文...")
                            .font(AppFonts.body())
                    } else if !note.content.isEmpty {
                        Text(note.content)
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                    }
                    
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("视觉描述")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.visualDescription, minHeight: 100, placeholder: "请输入视觉描述...")
                                .font(AppFonts.body())
                        }
                    } else if !note.visualDescription.isEmpty {
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI总结")
                                .font(AppFonts.headline())
                                .foregroundColor(AppColors.primaryText)
                            MultilineTextEditor(text: $note.summary, minHeight: 100, placeholder: "请输入 AI 总结...")
                                .font(AppFonts.body())
                        }
                    } else {
                        if !note.transcript.isEmpty {
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
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { dismissKeyboard() }
            }
        }
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