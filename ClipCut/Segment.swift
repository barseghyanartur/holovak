import Foundation

/// A single keep-segment defined by a start and end timecode string (HH:MM:SS or MM:SS).
struct Segment: Identifiable, Equatable {
    var id = UUID()
    var start: String = "00:00"
    var end: String   = "00:00"

    // MARK: - Parsing

    /// Converts a "HH:MM:SS", "MM:SS", or bare seconds string to total seconds.
    static func toSeconds(_ timecode: String) -> Double? {
        let parts = timecode.trimmingCharacters(in: .whitespaces)
            .split(separator: ":")
            .compactMap { Double($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60  + parts[1]
        case 1: return parts[0]
        default: return nil
        }
    }

    /// Formats total seconds as "HH:MM:SS".
    static func fromSeconds(_ total: Double) -> String {
        let t = Int(total)
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var startSeconds: Double? { Segment.toSeconds(start) }
    var endSeconds:   Double? { Segment.toSeconds(end)   }

    var isValid: Bool {
        guard let s = startSeconds, let e = endSeconds else { return false }
        return e > s
    }
}
