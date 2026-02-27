import SwiftUI
import AVKit

struct AVPlayerControlsView: View {
    @StateObject private var viewModel: AVPlayerViewModel
    var segments: [WhisperTranscriptionSegment]
    var timeOffset: TimeInterval
    
    init(url: URL, segments: [WhisperTranscriptionSegment] = [], timeOffset: TimeInterval = 0) {
        _viewModel = StateObject(wrappedValue: AVPlayerViewModel(url: url))
        self.segments = segments
        self.timeOffset = timeOffset
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: viewModel.player)
                    .frame(maxHeight: 250)
                    .cornerRadius(8)
                
                subtitleOverlay()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Custom Controls overlay or below
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Scrub Bar
                Slider(value: $viewModel.currentTime, in: 0...viewModel.duration) { editing in
                    viewModel.isScrubbing = editing
                    if !editing {
                        viewModel.seek(to: viewModel.currentTime)
                    }
                }
                .accentColor(ThemeColors.accent)
                
                Text("\(formatTime(viewModel.currentTime)) / \(formatTime(viewModel.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                // Speed Selector
                Menu {
                    ForEach([0.5, 1.0, 1.25, 1.5, 2.0, 3.0] as [Float], id: \.self) { speed in
                        Button(action: {
                            viewModel.setSpeed(speed)
                        }) {
                            HStack {
                                Text("\(String(format: "%.2g", speed))x")
                                if viewModel.playbackSpeed == speed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text("\(String(format: "%.2g", viewModel.playbackSpeed))x")
                        .font(.caption2.bold())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            viewModel.pause()
        }
    }
    
    @ViewBuilder
    private func subtitleOverlay() -> some View {
        if let currentSegment = activeSegment {
            VStack(spacing: 4) {
                Text(currentSegment.text)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(8)
                
                if let translated = currentSegment.translatedText {
                    Text(translated)
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(6)
                }
            }
            .padding(.bottom, 24)
            .padding(.horizontal, 32)
        }
    }
    
    private var activeSegment: WhisperTranscriptionSegment? {
        let currentTime = viewModel.currentTime
        return segments.first { segment in
            currentTime >= (segment.startTime + timeOffset) && currentTime <= (segment.endTime + timeOffset)
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time > 0 else { return "00:00" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: time) ?? "00:00"
    }
}

class AVPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackSpeed: Float = 1.0
    var isScrubbing = false
    
    private var timeObserver: Any?
    
    init(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: playerItem)
        setupObservers()
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }
    
    func play() {
        player.play()
        player.rate = playbackSpeed
        isPlaying = true
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    func setSpeed(_ speed: Float) {
        self.playbackSpeed = speed
        if isPlaying {
            player.rate = speed
        }
    }
    
    private func setupObservers() {
        // Duration
        player.currentItem?.observationInfo // Access to load duration later, simplier pattern:
        if let currentItem = player.currentItem {
            // Using KVO to wait for duration if not instantly available on init.
            // Simplified for brevity, usually AVPlayerItem.duration becomes available shortly.
            Task {
                if let duration = try? await currentItem.asset.load(.duration) {
                    DispatchQueue.main.async {
                        self.duration = duration.seconds
                    }
                }
            }
        }
        
        // Time observation
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isScrubbing else { return }
            self.currentTime = time.seconds
            
            // Post notification for sync highlighting
            NotificationCenter.default.post(
                name: NSNotification.Name("AVPlayerTimeUpdated"),
                object: nil,
                userInfo: ["time": time.seconds]
            )
        }
    }
}
