import SwiftUI

struct CapturePanel: View {
    @ObservedObject var appState: AppState
    @State private var textInput = ""
    @State private var escapeHoldTimer: Timer?
    @State private var isHoldingEscape = false
    @State private var micHover = false
    @State private var saveHover = false
    var onToggleDictation: (() -> Void)?

    private let cornerRadius: CGFloat = 40
    private let bgColor = Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1))

    var body: some View {
        VStack(spacing: 0) {
            contentArea
            if let toast = appState.toastMessage {
                ToastView(message: toast, isError: appState.toastIsError)
            }
            footer
        }
        .frame(width: 340)
        .frame(minHeight: 80)
        .fixedSize(horizontal: false, vertical: true)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    appState.isDragOver
                        ? Color.blue.opacity(0.8)
                        : Color.white.opacity(0.08),
                    lineWidth: appState.isDragOver ? 2 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .onDrop(of: [.fileURL, .url], isTargeted: $appState.isDragOver) { providers in
            handleDrop(providers)
        }
        .onAppear {
            textInput = currentTextContent()
        }
        .onChange(of: appState.currentSession.items) { _, _ in
            let latest = currentTextContent()
            if latest != textInput {
                textInput = latest
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("🤖")
                .font(.system(size: 16))

            Spacer()

            if appState.isDictating {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .shadow(color: .red.opacity(0.6), radius: 4)
                    Text("Listening")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                }
                .onTapGesture { onToggleDictation?() }
            } else {
                headerButton(icon: "mic.fill", isHovered: $micHover) {
                    onToggleDictation?()
                }
            }

            headerButton(icon: "checkmark", isHovered: $saveHover) {
                appState.save()
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private func headerButton(icon: String, isHovered: Binding<Bool>, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovered.wrappedValue ? .white : .white.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered.wrappedValue ? Color.white.opacity(0.12) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered.wrappedValue = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered.wrappedValue)
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.showUndoDiscard {
                Button("Undo discard") {
                    appState.undoDiscard()
                    textInput = currentTextContent()
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.bottom, 4)
            }
            TextEditor(text: $textInput)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 48, maxHeight: 260)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: textInput) { _, newValue in
                    appState.updateText(newValue)
                }
            ForEach(Array(nonTextItems().enumerated()), id: \.offset) { _, item in
                CaptureItemRow(item: item)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .opacity(appState.isDragOver ? 0.5 : 1)
        .overlay(
            appState.isDragOver ?
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundColor(.blue.opacity(0.6))
                .padding(8)
            : nil
        )
    }

    private func currentTextContent() -> String {
        for item in appState.currentSession.items {
            if case .text(let content) = item { return content }
        }
        return ""
    }

    private func nonTextItems() -> [CaptureItem] {
        appState.currentSession.items.filter {
            if case .text = $0 { return false }
            return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, url.isFileURL else { return }
                    let filename = url.lastPathComponent
                    let path = url.path
                    let ext = url.pathExtension.lowercased()
                    Task { @MainActor in
                        if ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff"].contains(ext) {
                            appState.addItem(.image(filename: filename, originalPath: path))
                        } else if ["mov", "mp4", "m4v", "avi", "mkv"].contains(ext) {
                            appState.addItem(.video(filename: filename, originalPath: path))
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url,
                          url.scheme == "http" || url.scheme == "https" else { return }
                    Task { @MainActor in
                        appState.addItem(.link(url))
                    }
                }
            }
        }
        return true
    }
}
