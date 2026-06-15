import Foundation
import Combine
import AVKit

enum AppMode: String, CaseIterable {
    case trim = "Trim"
    case join = "Join"
}

enum ExportState: Equatable {
    case idle
    case running
    case done(URL)
    case failed(String)
}

@MainActor
final class ClipCutViewModel: ObservableObject {

    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Mode

    @Published var mode: AppMode = .trim

    // MARK: - Trim state

    @Published var inputURL: URL?
    @Published var segments: [Segment]    = [Segment()]
    @Published var duration: Double?      = nil

    // MARK: - Advanced mode state

    @Published var player: AVPlayer?
    @Published var currentTime: Double = 0
    @Published var selectedSegmentID: UUID?
    @Published var isAdvancedMode: Bool = false
    private var timeObserver: Any?

    // MARK: - Join state

    @Published var joinURLs: [URL] = []

    // MARK: - Shared

    @Published var exportState: ExportState = .idle
    @Published var log: String = ""

    private var process: Process?

    // MARK: - Init

    init() {
        isAdvancedMode = settings.advancedMode

        settings.$advancedMode
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAdvancedMode)
    }

    // MARK: - Mode switching

    func switchMode(_ newMode: AppMode) {
        cancel()
        mode        = newMode
        exportState = .idle
        log         = ""
    }

    // MARK: - Advanced mode

    var selectedSegmentIndex: Int? {
        guard let id = selectedSegmentID else { return nil }
        return segments.firstIndex { $0.id == id }
    }

    func toggleAdvancedMode() {
        settings.advancedMode = isAdvancedMode
        if isAdvancedMode {
            guard let url = inputURL else { return }
            let player = AVPlayer(url: url)
            self.player = player
            let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                self?.currentTime = time.seconds
            }
            if selectedSegmentID == nil {
                selectedSegmentID = segments.first?.id
            }
        } else {
            removeTimeObserver()
            player = nil
            currentTime = 0
        }
    }

    func selectSegment(_ id: UUID) {
        selectedSegmentID = id
    }

    func setStartFromPlayback() {
        guard let idx = selectedSegmentIndex else { return }
        segments[idx].start = Segment.fromSeconds(currentTime)
    }

    func setEndFromPlayback() {
        guard let idx = selectedSegmentIndex else { return }
        segments[idx].end = Segment.fromSeconds(currentTime)
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Trim: file loading

    func loadFile(_ url: URL) {
        inputURL    = url
        exportState = .idle
        log         = ""
        duration    = probe(url: url)
        selectedSegmentID = segments.first?.id
        if isAdvancedMode { toggleAdvancedMode() }
    }

    // MARK: - Trim: segments

    func addSegment() {
        segments.append(Segment())
    }

    func removeSegment(at offsets: IndexSet) {
        if let id = selectedSegmentID, offsets.contains(where: { segments[$0].id == id }) {
            selectedSegmentID = nil
        }
        segments.remove(atOffsets: offsets)
        if segments.isEmpty { segments.append(Segment()) }
    }

    func moveSegment(from source: IndexSet, to destination: Int) {
        segments.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Join: files

    func addJoinFiles(_ urls: [URL]) {
        joinURLs.append(contentsOf: urls)
        exportState = .idle
    }

    func removeJoinFile(at offsets: IndexSet) {
        joinURLs.remove(atOffsets: offsets)
    }

    func moveJoinFile(from source: IndexSet, to destination: Int) {
        joinURLs.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Export

    var canExport: Bool {
        guard exportState != .running else { return false }
        switch mode {
        case .trim: return inputURL != nil && segments.allSatisfy(\.isValid)
        case .join: return joinURLs.count >= 2
        }
    }

    func export() {
        exportState = .running
        log = ""

        switch mode {
        case .trim:  exportTrim()
        case .join:  exportJoin()
        }
    }

    private func exportTrim() {
        guard let url = inputURL else { return }
        let output = FFmpegRunner.outputPath(for: url)
        process = FFmpegRunner.run(
            input: url, segments: segments, output: output,
            onLog: { [weak self] line in self?.log += line },
            completion: { [weak self] result in self?.handle(result) }
        )
    }

    private func exportJoin() {
        guard joinURLs.count >= 2 else { return }
        let output = FFmpegRunner.joinOutputPath(for: joinURLs)
        process = FFmpegRunner.join(
            inputs: joinURLs, output: output,
            onLog: { [weak self] line in self?.log += line },
            completion: { [weak self] result in self?.handle(result) }
        )
    }

    private func handle(_ result: Result<URL, Error>) {
        switch result {
        case .success(let out): exportState = .done(out)
        case .failure(let err): exportState = .failed(err.localizedDescription)
        }
    }

    // MARK: - Cancel / Reset

    func cancel() {
        process?.terminate()
        exportState = .idle
    }

    func reset() {
        cancel()
        inputURL    = nil
        segments    = [Segment()]
        joinURLs    = []
        exportState = .idle
        log         = ""
        duration    = nil
        removeTimeObserver()
        player = nil
        currentTime = 0
        selectedSegmentID = nil
        isAdvancedMode = false
    }

    // MARK: - ffprobe

    private func probe(url: URL) -> Double? {
        guard let ffprobe = findFFprobe() else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffprobe)
        proc.arguments = [
            "-v", "quiet",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path,
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let data   = pipe.fileHandleForReading.readDataToEndOfFile()
        let string = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Double(string)
    }

    var isFFmpegInstalled: Bool {
        FFmpegRunner.ffmpegPath() != nil && FFmpegRunner.ffprobePath() != nil
    }

    private func findFFprobe() -> String? {
        FFmpegRunner.ffprobePath()
    }
}
