import AVFoundation
import Combine

/// Manages an AVPlayer that plays through segments sequentially for preview.
@MainActor
final class PreviewPlayer: ObservableObject {

    @Published var player: AVPlayer?
    @Published var currentTime: Double = 0
    @Published var isPlaying = false

    var onFinished: (() -> Void)?

    private(set) var segments: [Segment] = []
    private(set) var joinURLs: [URL] = []
    private var inputURL: URL?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    var totalDuration: Double {
        segments.compactMap { seg in
            guard let s = seg.startSeconds, let e = seg.endSeconds else { return nil }
            return e - s
        }.reduce(0, +)
    }

    func load(url: URL, segments: [Segment]) {
        stop()
        self.inputURL = url
        self.segments = segments.filter(\.isValid)
        self.joinURLs = []
        guard !self.segments.isEmpty else {
            onFinished?()
            return
        }

        let player = AVPlayer()
        self.player = player

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
            }
        }

        playNextSegment(from: 0)
    }

    func loadJoin(urls: [URL]) {
        stop()
        self.joinURLs = urls
        self.segments = []
        self.inputURL = nil
        guard !urls.isEmpty else {
            onFinished?()
            return
        }

        let player = AVPlayer()
        self.player = player

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
            }
        }

        playNextJoinFile(from: 0)
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        removeTimeObserver()
        player = nil
        isPlaying = false
        currentTime = 0
        cancellables.removeAll()
        joinURLs = []
    }

    private func playNextSegment(from index: Int) {
        guard index < segments.count, let url = inputURL else {
            stop()
            onFinished?()
            return
        }

        let seg = segments[index]
        guard let start = seg.startSeconds, let end = seg.endSeconds else {
            playNextSegment(from: index + 1)
            return
        }

        let item = AVPlayerItem(url: url)
        let startCM = CMTime(seconds: start, preferredTimescale: 600)
        let duration = CMTime(seconds: end - start, preferredTimescale: 600)

        Task {
            do {
                try await item.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero)
            } catch {}

            let nextIndex = index + 1
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.playNextSegment(from: nextIndex)
                }
                .store(in: &cancellables)

            item.forwardPlaybackEndTime = CMTimeRange(start: startCM, duration: duration).end

            player?.replaceCurrentItem(with: item)
            player?.play()
            isPlaying = true
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }

    private func playNextJoinFile(from index: Int) {
        guard index < joinURLs.count else {
            stop()
            onFinished?()
            return
        }

        let url = joinURLs[index]
        let item = AVPlayerItem(url: url)
        let nextIndex = index + 1

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.playNextJoinFile(from: nextIndex)
            }
            .store(in: &cancellables)

        player?.replaceCurrentItem(with: item)
        player?.play()
        isPlaying = true
    }
}
