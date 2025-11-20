import SwiftUI
import AVKit

struct MediaPreviewView: View {
    let initialIndex: Int
    let assets: [MediaAsset]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    
    init(initialIndex: Int, assets: [MediaAsset]) {
        self.initialIndex = initialIndex
        self.assets = assets
        _currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(0..<assets.count, id: \.self) { index in
                    let asset = assets[index]
                    if let urlString = asset.localURLString, let url = URL(string: urlString) {
                        if asset.kind == MediaKind.video.rawValue {
                            VideoPlayer(player: AVPlayer(url: url))
                                .tag(index)
                        } else {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .tint(.white)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
