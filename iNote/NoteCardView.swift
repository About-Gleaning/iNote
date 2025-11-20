import SwiftUI

struct NoteCardView: View {
    let note: Note
    @State private var showMediaPreview: Bool = false
    @State private var selectedAssetIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title.isEmpty ? "未命名" : note.title)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                if note.isDraft {
                    Text("草稿")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.warning.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            if !note.summary.isEmpty {
                Text(note.summary)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text(note.content)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            if let assets = note.assets, !assets.isEmpty {
                let visualAssets = assets.filter { $0.kind == MediaKind.image.rawValue || $0.kind == MediaKind.video.rawValue }
                if !visualAssets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<visualAssets.count, id: \.self) { index in
                                let asset = visualAssets[index]
                                Button(action: {
                                    selectedAssetIndex = index
                                    showMediaPreview = true
                                }) {
                                    ZStack {
                                        if let url = asset.validURL {
                                            if asset.kind == MediaKind.image.rawValue {
                                                AsyncImage(url: url) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().aspectRatio(contentMode: .fill)
                                                    } else {
                                                        Color.gray.opacity(0.3)
                                                    }
                                                }
                                            } else if asset.kind == MediaKind.video.rawValue {
                                                if let thumbData = asset.thumbnail, let uiImage = UIImage(data: thumbData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                    
                                                    Image(systemName: "play.circle.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                        .shadow(radius: 2)
                                                } else {
                                                    ZStack {
                                                        Color.black.opacity(0.8)
                                                        Image(systemName: "video.fill")
                                                            .foregroundColor(.white)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    .fullScreenCover(isPresented: $showMediaPreview) {
                        MediaPreviewView(initialIndex: selectedAssetIndex, assets: visualAssets)
                    }
                }
                
                if let audioAsset = assets.first(where: { $0.kind == MediaKind.audio.rawValue }),
                   let url = audioAsset.validURL {
                    AudioPlayerView(url: url)
                        .padding(.top, 4)
                }
            }
            
            HStack {
                Text(note.createdAt, style: .date)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.secondaryText.opacity(0.8))
                Spacer()
            }
        }
        .padding(AppDimens.padding)
        .cardStyle()
    }
}
