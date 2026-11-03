import SwiftUI

/// Shared building blocks for the member and group editor sheets.

struct EditorSection<Content: View>: View {
    let title: String
    let symbol: String
    var error: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: symbol).foregroundStyle(Theme.red)
                Text(title).font(.headline)
                Spacer()
                if let error {
                    ErrorText(error).transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(error == nil ? .white.opacity(0.07) : Theme.red.opacity(0.6), lineWidth: 1)
        )
        .animation(Theme.bouncy, value: error)
    }
}

struct FieldBox<Content: View>: View {
    var label: String?
    var required = false
    var trailing: String? = nil
    var error: String? = nil
    var focused: Bool
    var invalid = false
    @ViewBuilder var content: Content

    var body: some View {
        let isBad = error != nil || invalid
        VStack(alignment: .leading, spacing: 5) {
            if label != nil || trailing != nil {
                HStack(spacing: 2) {
                    if let label {
                        Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    if required { Text("*").font(.caption.weight(.bold)).foregroundStyle(Theme.red) }
                    Spacer()
                    if let trailing {
                        Text(trailing).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    }
                }
            }
            content
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(focused ? 0.09 : 0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isBad ? Theme.red : (focused ? .white.opacity(0.45) : .white.opacity(0.1)),
                                      lineWidth: isBad || focused ? 1.5 : 1)
                )
            if let error {
                ErrorText(error).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.bouncy, value: error)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

struct ErrorText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(hex: "#FF4D4D"))
    }
}
