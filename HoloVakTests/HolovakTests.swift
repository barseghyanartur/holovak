import XCTest
@testable import Holovak

// MARK: - SegmentTests

final class SegmentTests: XCTestCase {

    func testToSeconds_HHMMSS() {
        XCTAssertEqual(Segment.toSeconds("01:02:03"), 3723)
    }

    func testToSeconds_MMSS() {
        XCTAssertEqual(Segment.toSeconds("02:07"), 127)
    }

    func testToSeconds_seconds() {
        XCTAssertEqual(Segment.toSeconds("42"), 42)
    }

    func testToSeconds_invalid() {
        XCTAssertNil(Segment.toSeconds("not:a:time:code"))
    }

    func testToSeconds_empty() {
        XCTAssertNil(Segment.toSeconds(""))
    }

    func testToSeconds_withWhitespace() {
        XCTAssertEqual(Segment.toSeconds("  00:30  "), 30)
    }

    func testFromSeconds_zero() {
        XCTAssertEqual(Segment.fromSeconds(0), "00:00:00")
    }

    func testFromSeconds_oneHour() {
        XCTAssertEqual(Segment.fromSeconds(3600), "01:00:00")
    }

    func testFromSeconds_mixed() {
        XCTAssertEqual(Segment.fromSeconds(3723), "01:02:03")
    }

    func testFromSeconds_roundtrip() {
        let original = "02:07:45"
        let seconds = Segment.toSeconds(original)!
        XCTAssertEqual(Segment.fromSeconds(seconds), original)
    }

    func testIsValid_endAfterStart() {
        var seg = Segment()
        seg.start = "00:00"
        seg.end   = "00:17"
        XCTAssertTrue(seg.isValid)
    }

    func testIsValid_endEqualStart_invalid() {
        var seg = Segment()
        seg.start = "00:30"
        seg.end   = "00:30"
        XCTAssertFalse(seg.isValid)
    }

    func testIsValid_endBeforeStart_invalid() {
        var seg = Segment()
        seg.start = "01:00"
        seg.end   = "00:30"
        XCTAssertFalse(seg.isValid)
    }

    func testIsValid_badTimecode_invalid() {
        var seg = Segment()
        seg.start = "abc"
        seg.end   = "01:00"
        XCTAssertFalse(seg.isValid)
    }
}

// MARK: - FFmpegRunnerTests

final class FFmpegRunnerTests: XCTestCase {

    private let input  = URL(fileURLWithPath: "/tmp/test.mp4")
    private let output = URL(fileURLWithPath: "/tmp/test-edited.mp4")

    func testOutputPath_addsEditedSuffix() {
        let url = URL(fileURLWithPath: "/Users/artur/Videos/clip.mp4")
        let out = FFmpegRunner.outputPath(for: url)
        XCTAssertEqual(out.lastPathComponent, "clip-edited.mp4")
    }

    func testOutputPath_preservesDirectory() {
        let url = URL(fileURLWithPath: "/Users/artur/Videos/clip.mp4")
        let out = FFmpegRunner.outputPath(for: url)
        XCTAssertEqual(out.deletingLastPathComponent().path, "/Users/artur/Videos")
    }

    func testOutputPath_preservesExtension() {
        let url = URL(fileURLWithPath: "/tmp/video.mov")
        let out = FFmpegRunner.outputPath(for: url)
        XCTAssertEqual(out.pathExtension, "mov")
    }

    func testBuildArguments_noSegments_throws() {
        guard FFmpegRunner.ffmpegPath() != nil else { return }
        XCTAssertThrowsError(
            try FFmpegRunner.buildArguments(input: input, segments: [], output: output)
        ) { error in
            XCTAssertEqual(error as? FFmpegError, FFmpegError.noSegments)
        }
    }

    func testBuildArguments_invalidSegment_throws() {
        guard FFmpegRunner.ffmpegPath() != nil else { return }
        var seg = Segment(); seg.start = "01:00"; seg.end = "00:30"
        XCTAssertThrowsError(
            try FFmpegRunner.buildArguments(input: input, segments: [seg], output: output)
        ) { error in
            XCTAssertEqual(error as? FFmpegError, FFmpegError.invalidSegment(0))
        }
    }

    func testBuildArguments_singleSegment_usesSSToo() throws {
        guard FFmpegRunner.ffmpegPath() != nil else { return }
        var seg = Segment(); seg.start = "00:42"; seg.end = "02:00"
        let args = try FFmpegRunner.buildArguments(input: input, segments: [seg], output: output)
        XCTAssertTrue(args.contains("-ss"))
        XCTAssertTrue(args.contains("-to"))
        XCTAssertFalse(args.contains("-filter_complex"))
    }

    func testBuildArguments_multiSegment_usesFilterComplex() throws {
        guard FFmpegRunner.ffmpegPath() != nil else { return }
        var s1 = Segment(); s1.start = "00:00"; s1.end = "00:17"
        var s2 = Segment(); s2.start = "00:42"; s2.end = "02:00"
        let args = try FFmpegRunner.buildArguments(input: input, segments: [s1, s2], output: output)
        XCTAssertTrue(args.contains("-filter_complex"))
        XCTAssertTrue(args.contains("-map"))
        XCTAssertFalse(args.contains("-ss"))
    }

    func testBuildArguments_outputIsLast() throws {
        guard FFmpegRunner.ffmpegPath() != nil else { return }
        var seg = Segment(); seg.start = "00:10"; seg.end = "00:20"
        let args = try FFmpegRunner.buildArguments(input: input, segments: [seg], output: output)
        XCTAssertEqual(args.last, output.path)
    }

    func testBuildArguments_containsCRF0() throws {
        guard FFmpegRunner.ffmpegPath() != nil else { return }
        var seg = Segment(); seg.start = "00:10"; seg.end = "00:20"
        let args = try FFmpegRunner.buildArguments(input: input, segments: [seg], output: output)
        let crf = args.firstIndex(of: "-crf").map { args[$0 + 1] }
        XCTAssertEqual(crf, "0")
    }
}

// MARK: - FFmpegError equatable

extension FFmpegError: Equatable {
    public static func == (lhs: FFmpegError, rhs: FFmpegError) -> Bool {
        switch (lhs, rhs) {
        case (.ffmpegNotFound, .ffmpegNotFound): return true
        case (.noSegments, .noSegments):         return true
        case (.invalidSegment(let a), .invalidSegment(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - HolovakViewModel segment selection tests

@MainActor
final class HolovakViewModelSelectionTests: XCTestCase {

    private func makeSUT(segmentCount: Int = 3) -> HolovakViewModel {
        let vm = HolovakViewModel()
        vm.segments = (0..<segmentCount).map { _ in Segment() }
        return vm
    }

    func testSelectSegment_setsSelectedSegmentID() {
        let vm = makeSUT()
        let secondID = vm.segments[1].id
        vm.selectSegment(secondID)
        XCTAssertEqual(vm.selectedSegmentID, secondID)
    }

    func testSelectSegment_selectingDifferentSegment_updatesSelection() {
        let vm = makeSUT()
        let firstID = vm.segments[0].id
        let thirdID = vm.segments[2].id
        vm.selectSegment(firstID)
        XCTAssertEqual(vm.selectedSegmentID, firstID)
        vm.selectSegment(thirdID)
        XCTAssertEqual(vm.selectedSegmentID, thirdID)
    }

    func testSelectSegment_selectingSameSegment_doesNotChange() {
        let vm = makeSUT()
        let id = vm.segments[1].id
        vm.selectSegment(id)
        vm.selectSegment(id)
        XCTAssertEqual(vm.selectedSegmentID, id)
    }

    func testSelectedSegmentIndex_returnsCorrectIndex() {
        let vm = makeSUT()
        let secondID = vm.segments[1].id
        vm.selectSegment(secondID)
        XCTAssertEqual(vm.selectedSegmentIndex, 1)
    }

    func testSelectedSegmentIndex_nilWhenNoSelection() {
        let vm = makeSUT()
        XCTAssertNil(vm.selectedSegmentIndex)
    }

    func testSelectedSegmentIndex_nilWhenSelectedSegmentRemoved() {
        let vm = makeSUT()
        let firstID = vm.segments[0].id
        vm.selectSegment(firstID)
        XCTAssertEqual(vm.selectedSegmentIndex, 0)
        vm.segments.remove(at: 0)
        XCTAssertNil(vm.selectedSegmentIndex)
    }

    func testSetStartFromPlayback_updatesSelectedSegmentStart() {
        let vm = makeSUT()
        vm.selectSegment(vm.segments[1].id)
        vm.currentTime = 42.0
        vm.setStartFromPlayback()
        XCTAssertEqual(vm.segments[1].start, "00:00:42")
    }

    func testSetEndFromPlayback_updatesSelectedSegmentEnd() {
        let vm = makeSUT()
        vm.selectSegment(vm.segments[0].id)
        vm.currentTime = 127.0
        vm.setEndFromPlayback()
        XCTAssertEqual(vm.segments[0].end, "00:02:07")
    }

    func testSetStartFromPlayback_noOpWhenNoSelection() {
        let vm = makeSUT()
        vm.currentTime = 60.0
        let originalStarts = vm.segments.map(\.start)
        vm.setStartFromPlayback()
        XCTAssertEqual(vm.segments.map(\.start), originalStarts)
    }

    func testSetEndFromPlayback_noOpWhenNoSelection() {
        let vm = makeSUT()
        vm.currentTime = 60.0
        let originalEnds = vm.segments.map(\.end)
        vm.setEndFromPlayback()
        XCTAssertEqual(vm.segments.map(\.end), originalEnds)
    }

    func testSetStartAndEnd_createsValidSegment() {
        let vm = makeSUT(segmentCount: 1)
        vm.selectSegment(vm.segments[0].id)
        vm.currentTime = 10.0
        vm.setStartFromPlayback()
        vm.currentTime = 30.0
        vm.setEndFromPlayback()
        XCTAssertTrue(vm.segments[0].isValid)
        XCTAssertEqual(vm.segments[0].start, "00:00:10")
        XCTAssertEqual(vm.segments[0].end, "00:00:30")
    }

    func testAddSegment_doesNotChangeSelection() {
        let vm = makeSUT(segmentCount: 1)
        let id = vm.segments[0].id
        vm.selectSegment(id)
        vm.addSegment()
        XCTAssertEqual(vm.selectedSegmentID, id)
        XCTAssertEqual(vm.segments.count, 2)
    }

    func testRemoveSegment_atOffsets_clearsSelectionIfRemoved() {
        let vm = makeSUT(segmentCount: 2)
        let secondID = vm.segments[1].id
        vm.selectSegment(secondID)
        vm.removeSegment(at: IndexSet(integer: 1))
        XCTAssertNil(vm.selectedSegmentID)
    }

    func testRemoveSegment_atOffsets_preservesSelectionIfNotRemoved() {
        let vm = makeSUT(segmentCount: 3)
        let thirdID = vm.segments[2].id
        vm.selectSegment(thirdID)
        vm.removeSegment(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.selectedSegmentID, thirdID)
    }

    func testMoveSegment_preservesSelectionByID() {
        let vm = makeSUT(segmentCount: 3)
        let secondID = vm.segments[1].id
        vm.selectSegment(secondID)
        vm.moveSegment(from: IndexSet(integer: 1), to: 3)
        XCTAssertEqual(vm.selectedSegmentID, secondID)
        XCTAssertEqual(vm.selectedSegmentIndex, 2)
    }

    func testReset_clearsSelection() {
        let vm = makeSUT()
        vm.selectSegment(vm.segments[1].id)
        vm.reset()
        XCTAssertNil(vm.selectedSegmentID)
    }

    // MARK: - Advanced mode + file loading

    func testLoadFile_whenAdvancedModeOn_createsPlayer() {
        let vm = makeSUT(segmentCount: 1)
        vm.isAdvancedMode = true
        vm.inputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        vm.toggleAdvancedMode()
        XCTAssertNotNil(vm.player)
    }

    func testLoadFile_whenAdvancedModeOff_noPlayerCreated() {
        let vm = makeSUT(segmentCount: 1)
        vm.isAdvancedMode = false
        vm.inputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        XCTAssertNil(vm.player)
    }

    func testToggleAdvancedMode_onWithoutURL_noPlayerCreated() {
        let vm = makeSUT(segmentCount: 1)
        vm.isAdvancedMode = true
        vm.inputURL = nil
        vm.toggleAdvancedMode()
        XCTAssertNil(vm.player)
    }

    func testToggleAdvancedMode_off_tearsDownPlayer() {
        let vm = makeSUT(segmentCount: 1)
        vm.inputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        vm.isAdvancedMode = true
        vm.toggleAdvancedMode()
        XCTAssertNotNil(vm.player)
        vm.isAdvancedMode = false
        vm.toggleAdvancedMode()
        XCTAssertNil(vm.player)
        XCTAssertEqual(vm.currentTime, 0)
    }

    func testLoadFile_whenAdvancedModeAlreadyOn_initializesPlayer() {
        let vm = makeSUT(segmentCount: 1)
        vm.isAdvancedMode = true
        AppSettings.shared.advancedMode = true
        vm.loadFile(URL(fileURLWithPath: "/tmp/test.mp4"))
        XCTAssertNotNil(vm.player)
        AppSettings.shared.reset()
    }

    func testLoadFile_whenAdvancedModeAlreadyOn_selectsFirstSegment() {
        let vm = makeSUT(segmentCount: 2)
        vm.isAdvancedMode = true
        AppSettings.shared.advancedMode = true
        vm.loadFile(URL(fileURLWithPath: "/tmp/test.mp4"))
        XCTAssertEqual(vm.selectedSegmentID, vm.segments.first?.id)
        AppSettings.shared.reset()
    }

    func testReset_afterToggleAdvancedModeOn_clearsPlayer() {
        let vm = makeSUT(segmentCount: 1)
        vm.inputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        vm.isAdvancedMode = true
        vm.toggleAdvancedMode()
        XCTAssertNotNil(vm.player)
        vm.reset()
        XCTAssertNil(vm.player)
        XCTAssertFalse(vm.isAdvancedMode)
        XCTAssertEqual(vm.currentTime, 0)
    }
}

// MARK: - PreviewPlayer tests

@MainActor
final class PreviewPlayerTests: XCTestCase {

    private func validSegment(start: String = "00:00:00", end: String = "00:00:10") -> Segment {
        var seg = Segment()
        seg.start = start
        seg.end = end
        return seg
    }

    private func invalidSegment() -> Segment {
        var seg = Segment()
        seg.start = "00:10"
        seg.end = "00:05"
        return seg
    }

    func testTotalDuration_singleSegment() {
        let pp = PreviewPlayer()
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [validSegment()])
        XCTAssertEqual(pp.totalDuration, 10, accuracy: 0.001)
    }

    func testTotalDuration_multipleSegments() {
        let pp = PreviewPlayer()
        let s1 = validSegment(start: "00:00:00", end: "00:00:10")
        let s2 = validSegment(start: "00:00:20", end: "00:00:35")
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [s1, s2])
        XCTAssertEqual(pp.totalDuration, 25, accuracy: 0.001)
    }

    func testTotalDuration_excludesInvalidSegments() {
        let pp = PreviewPlayer()
        let s1 = validSegment(start: "00:00:00", end: "00:00:10")
        let s2 = invalidSegment()
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [s1, s2])
        XCTAssertEqual(pp.totalDuration, 10, accuracy: 0.001)
    }

    func testTotalDuration_emptySegments() {
        let pp = PreviewPlayer()
        XCTAssertEqual(pp.totalDuration, 0, accuracy: 0.001)
    }

    func testLoad_noValidSegments_noPlayerCreated() {
        let pp = PreviewPlayer()
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [invalidSegment()])
        XCTAssertNil(pp.player)
    }

    func testLoad_emptySegments_noPlayerCreated() {
        let pp = PreviewPlayer()
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [])
        XCTAssertNil(pp.player)
    }

    func testStop_clearsState() {
        let pp = PreviewPlayer()
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [validSegment()])
        pp.stop()
        XCTAssertNil(pp.player)
        XCTAssertFalse(pp.isPlaying)
        XCTAssertEqual(pp.currentTime, 0)
    }

    func testStop_withoutLoad_noOp() {
        let pp = PreviewPlayer()
        pp.stop()
        XCTAssertNil(pp.player)
        XCTAssertFalse(pp.isPlaying)
    }

    func testOnFinished_calledWhenNoSegments() {
        let pp = PreviewPlayer()
        var finished = false
        pp.onFinished = { finished = true }
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [])
        XCTAssertTrue(finished)
    }

    func testOnFinished_calledWhenOnlyInvalidSegments() {
        let pp = PreviewPlayer()
        var finished = false
        pp.onFinished = { finished = true }
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [invalidSegment()])
        XCTAssertTrue(finished)
    }

    // MARK: - loadJoin

    func testLoadJoin_emptyURLs_callsOnFinished() {
        let pp = PreviewPlayer()
        var finished = false
        pp.onFinished = { finished = true }
        pp.loadJoin(urls: [])
        XCTAssertTrue(finished)
        XCTAssertNil(pp.player)
    }

    func testLoadJoin_withURLs_createsPlayer() {
        let pp = PreviewPlayer()
        let urls = [
            URL(fileURLWithPath: "/tmp/a.mp4"),
            URL(fileURLWithPath: "/tmp/b.mp4"),
        ]
        pp.loadJoin(urls: urls)
        XCTAssertNotNil(pp.player)
        XCTAssertEqual(pp.joinURLs.count, 2)
    }

    func testLoadJoin_clearsTrimSegments() {
        let pp = PreviewPlayer()
        pp.load(url: URL(fileURLWithPath: "/tmp/test.mp4"), segments: [validSegment()])
        XCTAssertFalse(pp.segments.isEmpty)
        pp.loadJoin(urls: [URL(fileURLWithPath: "/tmp/a.mp4")])
        XCTAssertTrue(pp.segments.isEmpty)
    }

    func testStop_clearsJoinURLs() {
        let pp = PreviewPlayer()
        pp.loadJoin(urls: [URL(fileURLWithPath: "/tmp/a.mp4")])
        pp.stop()
        XCTAssertTrue(pp.joinURLs.isEmpty)
    }
}

// MARK: - AppSettings persistence tests

final class AppSettingsTests: XCTestCase {

    private let s = AppSettings.shared

    // MARK: - Defaults

    func testDefaults_videoHeight() {
        s.reset()
        XCTAssertEqual(s.videoHeight, 300, accuracy: 0.001)
    }

    func testDefaults_advancedMode() {
        s.reset()
        XCTAssertFalse(s.advancedMode)
    }

    func testDefaults_windowFrameIsEmpty() {
        s.reset()
        XCTAssertTrue(s.windowFrame.isEmpty)
    }

    // MARK: - Round-trips

    func testVideoHeight_roundTrip() {
        s.reset()
        s.videoHeight = 550
        XCTAssertEqual(s.videoHeight, 550, accuracy: 0.001)
    }

    func testAdvancedMode_roundTrip() {
        s.reset()
        s.advancedMode = true
        XCTAssertTrue(s.advancedMode)
    }

    func testWindowFrame_roundTrip() {
        s.reset()
        s.windowFrame = [10, 20, 800, 600]
        XCTAssertEqual(s.windowFrame, [10, 20, 800, 600])
    }

    // MARK: - Reset

    func testReset_restoresDefaults() {
        s.videoHeight = 999
        s.advancedMode = true
        s.windowFrame = [1, 2, 3, 4]
        s.reset()
        XCTAssertEqual(s.videoHeight, 300, accuracy: 0.001)
        XCTAssertFalse(s.advancedMode)
        XCTAssertTrue(s.windowFrame.isEmpty)
    }

    func testReset_writesDefaultsToUserDefaults() {
        s.videoHeight = 42
        s.advancedMode = true
        s.windowFrame = [5, 6, 7, 8]
        s.reset()
        XCTAssertEqual(UserDefaults.standard.double(forKey: "settings.videoHeight"), 300, accuracy: 0.001)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "settings.advancedMode"))
    }

    func testReset_postsNotification() {
        let exp = expectation(description: "didChange")
        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: AppSettings.didChange, object: nil, queue: .main
        ) { _ in received = true; exp.fulfill() }
        s.reset()
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(received)
        NotificationCenter.default.removeObserver(token)
    }

    // MARK: - Corrupt data handling

    func testCorruptVideoHeight_usesDefault() {
        s.reset()
        UserDefaults.standard.set("not-a-number", forKey: "settings.videoHeight")
        let customSettings = AppSettings()
        XCTAssertEqual(customSettings.videoHeight, 300, accuracy: 0.001)
    }

    func testCleanLaunchVideoHeight_usesDefault() {
        UserDefaults.standard.removeObject(forKey: "settings.videoHeight")
        let customSettings = AppSettings()
        XCTAssertEqual(customSettings.videoHeight, 300, accuracy: 0.001)
    }

    func testCorruptWindowFrame_usesDefault() {
        s.reset()
        UserDefaults.standard.set("not-an-array", forKey: "settings.windowFrame")
        let customSettings = AppSettings()
        XCTAssertTrue(customSettings.windowFrame.isEmpty)
    }

    // MARK: - Overwrite

    func testVideoHeight_overwritesPrevious() {
        s.reset()
        s.videoHeight = 100
        s.videoHeight = 200
        XCTAssertEqual(s.videoHeight, 200, accuracy: 0.001)
    }

    func testAdvancedMode_overwritesPrevious() {
        s.reset()
        s.advancedMode = true
        s.advancedMode = false
        XCTAssertFalse(s.advancedMode)
    }

    // MARK: - Window frame NSRect reconstruction

    func testNSRect_reconstructedFromStoredData() {
        s.reset()
        s.windowFrame = [120, 340, 800, 600]
        let data = s.windowFrame
        let rect = NSRect(
            x: data[0], y: data[1],
            width: data[2], height: data[3]
        )
        XCTAssertEqual(rect.origin.x, 120, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 340, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 800, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 600, accuracy: 0.001)
    }
}
