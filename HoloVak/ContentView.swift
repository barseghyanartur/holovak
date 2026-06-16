import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct ContentView: View {
    @StateObject private var vm = HolovakViewModel()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var previewPlayer = PreviewPlayer()
    @State private var isDropTargeted = false
    @State private var showLog = false

    private var videoHeight: CGFloat {
        get { CGFloat(settings.videoHeight) }
        set { settings.videoHeight = Double(newValue) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if !vm.isFFmpegInstalled {
                dependencyWarningBanner
            }

            switch vm.mode {
            case .trim:
                if vm.inputURL == nil { dropZone } else { trimPanel }
            case .join:
                joinPanel
            }
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { restoreWindowFrame() }
        .onDisappear { saveWindowFrame() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { note in
            guard let window = note.object as? NSWindow, window.isKeyWindow else { return }
            saveWindowFrame()
        }
    }

    private func saveWindowFrame() {
        guard let window = NSApp.keyWindow else { return }
        let frame = window.frame
        settings.windowFrame = [
            frame.origin.x, frame.origin.y,
            frame.size.width, frame.size.height,
        ]
    }

    private func restoreWindowFrame() {
        let data = settings.windowFrame
        guard data.count == 4 else { return }
        let rect = NSRect(
            x: data[0], y: data[1],
            width: data[2], height: data[3]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.keyWindow?.setFrame(rect, display: true)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Holovak")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))

            Spacer()

            Picker("", selection: $vm.mode) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .onChange(of: vm.mode) { vm.switchMode($0) }

            if vm.inputURL != nil || !vm.joinURLs.isEmpty {
                Button("Reset") { vm.reset() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    private var dependencyWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text("FFmpeg or FFprobe is not installed")
                    .font(.system(size: 12, weight: .semibold))
                Text("Install them via Homebrew to enable video analysis and editing: brew install ffmpeg")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Drop zone (Trim)

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .padding(24)

            VStack(spacing: 10) {
                Image(systemName: "film.stack")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.secondary)
                Text("Drop a video file here")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Button("Or click to browse…") { openSingleFile() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.movie, .video, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers, multi: false)
        }
        .contentShape(Rectangle())
        .onTapGesture { openSingleFile() }
    }

    // MARK: - Trim panel

    private var trimPanel: some View {
        VStack(spacing: 0) {
            fileHeader
            Divider()
            if vm.isAdvancedMode {
                videoPlayer
                advancedControls
                resizableDivider
                Divider()
            }
            segmentList
            Divider()
            exportBar
        }
    }

    private var videoPlayer: some View {
        Group {
            if let player = vm.player {
                PlayerView(player: player)
                    .frame(height: videoHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color(nsColor: .textBackgroundColor))
                    .frame(height: videoHeight)
                    .overlay(
                        Text("Loading…")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var resizableDivider: some View {
        HStack {
            Spacer()
            Circle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 20, height: 5)
            Spacer()
        }
        .frame(height: 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let newHeight = settings.videoHeight + Double(value.translation.height)
                    settings.videoHeight = max(100, newHeight)
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active: NSCursor.resizeUpDown.push()
            case .ended: NSCursor.pop()
            }
        }
    }

    private var advancedControls: some View {
        HStack(spacing: 12) {
            Text(Segment.fromSeconds(vm.currentTime))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Button("Set Start") { vm.setStartFromPlayback() }
                .buttonStyle(.bordered)
                .font(.system(size: 12))
                .disabled(vm.selectedSegmentIndex == nil)
            Button("Set End") { vm.setEndFromPlayback() }
                .buttonStyle(.bordered)
                .font(.system(size: 12))
                .disabled(vm.selectedSegmentIndex == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var fileHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "film")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            Text(vm.inputURL?.lastPathComponent ?? "")
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let dur = vm.duration {
                Text(Segment.fromSeconds(dur))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if vm.inputURL != nil {
                Toggle("Advanced", isOn: $vm.isAdvancedMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: vm.isAdvancedMode) { _ in vm.toggleAdvancedMode() }
            }
            Button("Open…") { openSingleFile() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var segmentList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("#").frame(width: 24, alignment: .center)
                Text("Start").frame(width: 90, alignment: .leading)
                Text("End").frame(width: 90, alignment: .leading)
                Spacer()
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            List(selection: segmentSelectionBinding) {
                ForEach(Array(vm.segments.enumerated()), id: \.element.id) { i, seg in
                    SegmentRow(
                        segment: $vm.segments[i],
                        index: i,
                        isSelected: vm.segments[i].id == vm.selectedSegmentID,
                        onDelete: {
                            withAnimation {
                                vm.segments.remove(at: i)
                                if vm.segments.isEmpty { vm.addSegment() }
                            }
                        }
                    )
                    .tag(vm.segments[i].id)
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .onMove(perform: vm.moveSegment)
                .onDelete(perform: vm.removeSegment)
            }
            .listStyle(.plain)
            .frame(minHeight: 100)

            Divider()

            Button { withAnimation { vm.addSegment() } } label: {
                Label("Add segment", systemImage: "plus").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .padding(.vertical, 8)
        }
    }

    private var segmentSelectionBinding: Binding<Set<Segment.ID>> {
        Binding(
            get: { vm.selectedSegmentID.map { [$0] } ?? [] },
            set: { vm.selectedSegmentID = $0.first }
        )
    }

    // MARK: - Join panel

    private var joinPanel: some View {
        VStack(spacing: 0) {
            // Column header
            HStack {
                Text("#").frame(width: 24, alignment: .center)
                Text("File").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if vm.joinURLs.isEmpty {
                joinDropZone
            } else {
                joinFileList
            }

            Divider()

            // Add files button
            HStack(spacing: 16) {
                Button {
                    openMultipleFiles()
                } label: {
                    Label("Add files…", systemImage: "plus").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Text("Drag rows to reorder")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
            exportBar
        }
    }

    private var joinDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .padding(24)
            VStack(spacing: 10) {
                Image(systemName: "film.stack")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary)
                Text("Drop video files here")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Button("Or click to browse…") { openMultipleFiles() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.movie, .video, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers, multi: true)
        }
        .contentShape(Rectangle())
        .onTapGesture { openMultipleFiles() }
    }

    private var joinFileList: some View {
        List {
            ForEach(Array(vm.joinURLs.enumerated()), id: \.element) { i, url in
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .center)
                    Image(systemName: "film")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(url.lastPathComponent)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        if let idx = vm.joinURLs.firstIndex(of: url) {
                            vm.joinURLs.remove(at: idx)
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .onMove(perform: vm.moveJoinFile)
            .onDelete(perform: vm.removeJoinFile)
        }
        .listStyle(.plain)
        .frame(minHeight: 100)
        .onDrop(of: [.movie, .video, .fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers, multi: true)
        }
    }

    // MARK: - Export bar (shared)

    private var exportBar: some View {
        VStack(spacing: 0) {
            if showLog && !vm.log.isEmpty {
                ScrollView {
                    Text(vm.log)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 80)
                .background(Color(nsColor: .textBackgroundColor))
                Divider()
            }

            HStack(spacing: 12) {
                statusBadge
                Spacer()

                if !vm.log.isEmpty {
                    Button(showLog ? "Hide log" : "Show log") { showLog.toggle() }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }

                if case .done(let url) = vm.exportState {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 12))
                }

                if vm.mode == .trim, vm.inputURL != nil, vm.segments.allSatisfy(\.isValid),
                   vm.exportState != .running {
                    Button("Preview") {
                        openPreviewWindow(
                            url: vm.inputURL!,
                            segments: vm.segments,
                            player: previewPlayer
                        )
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 12))
                }

                if vm.mode == .join, vm.joinURLs.count >= 2, vm.exportState != .running {
                    Button("Preview") {
                        openJoinPreviewWindow(
                            urls: vm.joinURLs,
                            player: previewPlayer
                        )
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 12))
                }

                if vm.exportState == .running {
                    Button("Cancel") { vm.cancel() }
                        .buttonStyle(.bordered)
                        .font(.system(size: 12))
                } else {
                    Button("Export") { vm.export() }
                        .buttonStyle(.borderedProminent)
                        .font(.system(size: 12, weight: .semibold))
                        .disabled(!vm.canExport)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch vm.exportState {
        case .idle:   EmptyView()
        case .running:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                Text("Exporting…").font(.system(size: 11)).foregroundColor(.secondary)
            }
        case .done:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11)).foregroundColor(.green)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11)).foregroundColor(.red).lineLimit(2)
        }
    }

    // MARK: - File helpers

    private func openSingleFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            vm.loadFile(url)
        }
    }

    private func openMultipleFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            vm.addJoinFiles(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], multi: Bool) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        if multi { self.vm.addJoinFiles([url]) }
                        else     { self.vm.loadFile(url) }
                    }
                }
                handled = true
                if !multi { break }
            }
        }
        return handled
    }
}

// MARK: - AVPlayerView wrapper

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
