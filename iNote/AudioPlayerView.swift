import SwiftUI
import AVFoundation

class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var currentTime: TimeInterval = 0.0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
        setupPlayer()
    }
    
    private func setupPlayer() {
        do {
            // 1. Try the URL as is (if it's a valid file URL)
            var fileURL = url
            
            // 2. If not reachable, try to resolve relative to Documents/iNoteMedia/audio
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                let filename = url.lastPathComponent
                if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let candidate = docs.appendingPathComponent("iNoteMedia/audio").appendingPathComponent(filename)
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        fileURL = candidate
                        print("Resolved audio path to: \(candidate.path)")
                    }
                }
            }
            
            // Check if file exists at the resolved path
            if FileManager.default.fileExists(atPath: fileURL.path) {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                duration = audioPlayer?.duration ?? 0.0
            } else {
                print("Audio file not found at: \(fileURL.path)")
            }
        } catch {
            print("Error initializing audio player: \(error)")
        }
    }
    
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            if player.duration > 0 {
                self.progress = player.currentTime / player.duration
            }
        }
    }
    
    func seek(to value: Double) {
        guard let player = audioPlayer else { return }
        let time = value * player.duration
        player.currentTime = time
        currentTime = time
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        timer?.invalidate()
        currentTime = 0
        progress = 0
        player.currentTime = 0
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct AudioPlayerView: View {
    @StateObject private var vm: AudioPlayerViewModel
    
    init(url: URL) {
        _vm = StateObject(wrappedValue: AudioPlayerViewModel(url: url))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { vm.togglePlayPause() }) {
                Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accent)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 4) {
                Slider(value: Binding(get: { vm.progress }, set: { vm.seek(to: $0) }))
                    .accentColor(AppColors.accent)
                
                HStack {
                    Text(formatTime(vm.currentTime))
                    Spacer()
                    Text(formatTime(vm.duration))
                }
                .font(AppFonts.caption())
                .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(12)
        .background(AppColors.background.opacity(0.5))
        .cornerRadius(12)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        if time.isNaN || time.isInfinite { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
