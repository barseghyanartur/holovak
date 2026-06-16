import Foundation

enum FFmpegError: LocalizedError {
    case ffmpegNotFound
    case noSegments
    case invalidSegment(Int)
    case notEnoughFiles
    case processFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .ffmpegNotFound:
            return "ffmpeg not found. Install it via Homebrew: brew install ffmpeg"
        case .noSegments:
            return "Add at least one segment before exporting."
        case .invalidSegment(let i):
            return "Segment \(i + 1) is invalid — end must be after start."
        case .notEnoughFiles:
            return "Add at least two files to join."
        case .processFailed(let code, let log):
            return "ffmpeg exited with code \(code).\n\(log)"
        }
    }
}

struct FFmpegRunner {

    // MARK: - ffmpeg discovery

    static func ffmpegPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",   // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",       // Intel Homebrew
            "/usr/bin/ffmpeg",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func ffprobePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffprobe",   // Apple Silicon Homebrew
            "/usr/local/bin/ffprobe",       // Intel Homebrew
            "/usr/bin/ffprobe",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - Output path

    static func outputPath(for input: URL) -> URL {
        let stem = input.deletingPathExtension().lastPathComponent
        let ext  = input.pathExtension
        return input.deletingLastPathComponent()
            .appendingPathComponent("\(stem)-edited.\(ext)")
    }

    static func joinOutputPath(for inputs: [URL]) -> URL {
        let first = inputs[0]
        let stem  = first.deletingPathExtension().lastPathComponent
        let ext   = first.pathExtension
        return first.deletingLastPathComponent()
            .appendingPathComponent("\(stem)-joined.\(ext)")
    }

    // MARK: - Join command builder

    static func buildJoinArguments(inputs: [URL], output: URL) throws -> [String] {
        guard ffmpegPath() != nil      else { throw FFmpegError.ffmpegNotFound }
        guard inputs.count >= 2        else { throw FFmpegError.notEnoughFiles }

        var args = ["-y"]
        for url in inputs { args += ["-i", url.path] }

        let n = inputs.count
        var concatInputs = ""
        for i in 0..<n { concatInputs += "[\(i):v][\(i):a]" }

        let filterComplex = "\(concatInputs)concat=n=\(n):v=1:a=1[vout][aout]"

        args += [
            "-filter_complex", filterComplex,
            "-map", "[vout]",
            "-map", "[aout]",
            "-c:v", "libx264", "-crf", "0", "-preset", "ultrafast",
            "-c:a", "aac", "-b:a", "192k",
            output.path,
        ]
        return args
    }

    // MARK: - Join execution

    @discardableResult
    static func join(
        inputs: [URL],
        output: URL,
        onLog: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Process? {
        return _run(
            args: { try buildJoinArguments(inputs: inputs, output: output) },
            onLog: onLog,
            completion: completion
        )
    }

    static func buildArguments(
        input: URL,
        segments: [Segment],
        output: URL
    ) throws -> [String] {

        guard let _ = ffmpegPath() else { throw FFmpegError.ffmpegNotFound }
        guard !segments.isEmpty   else { throw FFmpegError.noSegments }

        for (i, seg) in segments.enumerated() {
            guard seg.isValid else { throw FFmpegError.invalidSegment(i) }
        }

        var args = ["-y", "-i", input.path]

        if segments.count == 1, let seg = segments.first,
           let s = seg.startSeconds, let e = seg.endSeconds {
            // Simple single-segment: no filtergraph needed
            args += [
                "-ss", String(s),
                "-to", String(e),
                "-c:v", "libx264", "-crf", "0", "-preset", "ultrafast",
                "-c:a", "aac", "-b:a", "192k",
                output.path,
            ]
        } else {
            // Multi-segment filtergraph
            var filterParts: [String] = []
            var concatInputs = ""

            for (i, seg) in segments.enumerated() {
                let s = seg.startSeconds!
                let e = seg.endSeconds!
                filterParts.append("[0:v]trim=start=\(s):end=\(e),setpts=PTS-STARTPTS[v\(i)]")
                filterParts.append("[0:a]atrim=start=\(s):end=\(e),asetpts=PTS-STARTPTS[a\(i)]")
                concatInputs += "[v\(i)][a\(i)]"
            }

            let n = segments.count
            let filterComplex = filterParts.joined(separator: ";")
                + ";\(concatInputs)concat=n=\(n):v=1:a=1[vout][aout]"

            args += [
                "-filter_complex", filterComplex,
                "-map", "[vout]",
                "-map", "[aout]",
                "-c:v", "libx264", "-crf", "0", "-preset", "ultrafast",
                "-c:a", "aac", "-b:a", "192k",
                output.path,
            ]
        }

        return args
    }

    // MARK: - Trim execution

    /// Runs ffmpeg asynchronously, streaming log lines via `onLog`, calling `completion` when done.
    @discardableResult
    static func run(
        input: URL,
        segments: [Segment],
        output: URL,
        onLog: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Process? {
        return _run(
            args: { try buildArguments(input: input, segments: segments, output: output) },
            onLog: onLog,
            completion: completion
        )
    }

    // MARK: - Shared process runner

    @discardableResult
    private static func _run(
        args: () throws -> [String],
        onLog: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> Process? {

        guard let ffmpeg = ffmpegPath() else {
            completion(.failure(FFmpegError.ffmpegNotFound))
            return nil
        }

        let resolvedArgs: [String]
        do {
            resolvedArgs = try args()
        } catch {
            completion(.failure(error))
            return nil
        }

        // Output is always the last argument
        let outputURL = URL(fileURLWithPath: resolvedArgs.last ?? "")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = resolvedArgs

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { onLog(line) }
        }

        process.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    completion(.success(outputURL))
                } else {
                    completion(.failure(FFmpegError.processFailed(proc.terminationStatus, "")))
                }
            }
        }

        do {
            try process.run()
        } catch {
            completion(.failure(error))
            return nil
        }

        return process
    }
}
