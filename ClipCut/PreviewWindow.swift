import SwiftUI
import AVKit

struct PreviewWindow: View {
    @ObservedObject var previewPlayer: PreviewPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let player = previewPlayer.player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        Text(previewPlayer.joinURLs.isEmpty ? "No valid segments" : "No files to preview")
                            .foregroundColor(.secondary)
                    )
            }

            Divider()

            HStack(spacing: 12) {
                Button { previewPlayer.stop(); dismiss() } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .help("Stop and close")

                Button { previewPlayer.togglePlayPause() } label: {
                    Image(systemName: previewPlayer.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.bordered)
                .help(previewPlayer.isPlaying ? "Pause" : "Play")

                Spacer()

                Text(formatTime(previewPlayer.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private func formatTime(_ seconds: Double) -> String {
        Segment.fromSeconds(max(0, seconds))
    }
}

// MARK: - NSWindow hosting

struct PreviewWindowAccessor: NSViewRepresentable {
    let window: NSWindow
    @ObservedObject var previewPlayer: PreviewPlayer

    func makeNSView(context: Context) -> NSView {
        DispatchQueue.main.async {
            self.window.contentView = NSHostingView(
                rootView: PreviewWindow(
                    previewPlayer: context.coordinator.player
                )
            )
        }
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(player: previewPlayer)
    }

    final class Coordinator: ObservableObject {
        let player: PreviewPlayer
        init(player: PreviewPlayer) { self.player = player }
    }
}

func openPreviewWindow(url: URL, segments: [Segment], player: PreviewPlayer) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Preview"
    window.center()
    window.isReleasedWhenClosed = false

    let hostingView = NSHostingView(
        rootView: PreviewWindowAccessor(
            window: window,
            previewPlayer: player
        )
    )
    window.contentView = hostingView
    window.makeKeyAndOrderFront(nil)

    Task { @MainActor in
        player.onFinished = {
            DispatchQueue.main.async {
                window.close()
            }
        }
        player.load(url: url, segments: segments)
    }
}

func openJoinPreviewWindow(urls: [URL], player: PreviewPlayer) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Preview"
    window.center()
    window.isReleasedWhenClosed = false

    let hostingView = NSHostingView(
        rootView: PreviewWindowAccessor(
            window: window,
            previewPlayer: player
        )
    )
    window.contentView = hostingView
    window.makeKeyAndOrderFront(nil)

    Task { @MainActor in
        player.onFinished = {
            DispatchQueue.main.async {
                window.close()
            }
        }
        player.loadJoin(urls: urls)
    }
}
