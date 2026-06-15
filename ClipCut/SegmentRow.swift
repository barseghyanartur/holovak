import SwiftUI

struct SegmentRow: View {
    @Binding var segment: Segment
    let index: Int
    let isSelected: Bool
    let onDelete: () -> Void

    @FocusState private var startFocused: Bool
    @FocusState private var endFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 3)
                .frame(height: 20)

            // Row number
            Text("\(index + 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .center)

            // Start timecode
            timecodeField(
                value: $segment.start,
                placeholder: "00:00:00",
                focused: $startFocused
            )
            .frame(width: 86)

            Text("→")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            // End timecode
            timecodeField(
                value: $segment.end,
                placeholder: "00:00:00",
                focused: $endFocused
            )
            .frame(width: 86)

            Spacer()

            // Validity indicator
            if !segment.start.isEmpty && !segment.end.isEmpty {
                Image(systemName: segment.isValid ? "checkmark" : "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(segment.isValid ? .green : .red)
            }

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(4)
    }

    private func timecodeField(
        value: Binding<String>,
        placeholder: String,
        focused: FocusState<Bool>.Binding
    ) -> some View {
        TextField(placeholder, text: value)
            .font(.system(size: 12, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            .focused(focused)
            .onSubmit { startFocused = false; endFocused = false }
    }
}
