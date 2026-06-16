import SwiftUI

struct AboutView: View {
    @State private var selectedTab = "About"

    var body: some View {
        TabView(selection: $selectedTab) {
            aboutTab
                .tabItem { Text("About") }
                .tag("About")

            licenseTab
                .tabItem { Text("License") }
                .tag("License")

            creditsTab
                .tabItem { Text("Credits") }
                .tag("Credits")
        }
        .frame(width: 420, height: 240)
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Holovak")
                .font(.title2.weight(.semibold))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A minimal macOS desktop application for trimming and joining video files.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(20)
    }

    private var licenseTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MIT License")
                .font(.headline)

            Text("Copyright © \(Calendar.current.component(.year, from: Date())) Artur Barseghyan")
                .font(.subheadline)

            ScrollView {
                Text("""
                    Permission is hereby granted, free of charge, to any person obtaining a copy \
                    of this software and associated documentation files (the "Software"), to deal \
                    in the Software without restriction, including without limitation the rights \
                    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
                    copies of the Software, and to permit persons to whom the Software is \
                    furnished to do so, subject to the following conditions:

                    The above copyright notice and this permission notice shall be included in all \
                    copies or substantial portions of the Software.

                    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
                    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
                    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
                    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
                    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
                    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
                    SOFTWARE.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }

    private var creditsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Credits")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Author")
                    .font(.subheadline.weight(.medium))
                Text("Artur Barseghyan")
                Text("artur.barseghyan@gmail.com")
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("App Icon")
                    .font(.subheadline.weight(.medium))
                Text("The application icon has been taken from the amazing tabler icons (MIT licensed).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Link("https://github.com/tabler/tabler-icons",
                     destination: URL(string: "https://github.com/tabler/tabler-icons")!)
                    .font(.caption)
            }

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - About window

func showAboutWindow() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "About Holovak"
    window.center()
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: AboutView())
    window.makeKeyAndOrderFront(nil)
}
