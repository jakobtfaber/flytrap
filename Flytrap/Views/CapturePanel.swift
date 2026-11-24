import SwiftUI

struct CapturePanel: View {
    @ObservedObject var appState: AppState
    @State private var textInput = ""
    @State private var escapeHoldTimer: Timer?
    @State private var isHoldingEscape = false
    @State private var micHover = false
    @State private var modeHover = false
    @State private var borderRotation: Double = -0.5
    @State private var borderOpacity: Double = 0
    var onToggleDictation: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            textArea
                .frame(minHeight: 40)
            attachmentsArea
            footer
                .overlay {
                    if appState.isDragOver {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3])
                            )
                            .foregroundColor(.blue.opacity(0.5))
                            .background(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.blue.opacity(0.15))
                            )
                            .padding(4)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.15), value: appState.isDragOver)
                    }
                }
        }
        .frame(width: 340)
        .frame(minHeight: 80)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1)))
        // Shimmer border inside the panel, drawn against dark background
        .overlay(
            ZStack {
                LinearGradient(
                    colors: appState.captureMode == .agent
                        ? [
                            Color.cyan.opacity(0.55),
                            Color.cyan.opacity(0.08),
                            Color.blue.opacity(0.45),
                            Color.teal.opacity(0.1),
                        ]
                        : [
                            Color.purple.opacity(0.4),
                            Color.purple.opacity(0.05),
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.05),
                        ],
                    startPoint: UnitPoint(x: borderRotation - 0.5, y: 0),
                    endPoint: UnitPoint(x: borderRotation + 0.5, y: 1)
                )
            }
            .mask(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(lineWidth: 1.5)
            )
            .opacity(appState.isDragOver ? 0 : borderOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        // Dark outer border to sandwich the shimmer against a dark background
        .padding(1.5)
        .background(
            RoundedRectangle(cornerRadius: 41.5, style: .continuous)
                .fill(Color(nsColor: NSColor(red: 0.06, green: 0.04, blue: 0.1, alpha: 1)))
        )
        .overlay(
            appState.isDragOver ?
                RoundedRectangle(cornerRadius: 41.5, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.8), lineWidth: 2)
            : nil
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .onDrop(of: [.fileURL, .url], isTargeted: $appState.isDragOver) { providers in
            handleDrop(providers)
        }
        .background(
            Button("") { appState.cleanupWithClaude() }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        )
        .onAppear {
            textInput = currentTextContent()
        }
        .onChange(of: appState.isDragOver) { _, isDragging in
            if isDragging {
                appState.pauseIdle()
            } else {
                appState.resetIdle()
            }
        }
        .onChange(of: appState.openCount) { _, _ in
            // Reset without animation, then sweep on next frame
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                borderRotation = -0.5
                borderOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    borderOpacity = 1
                }
                withAnimation(.easeInOut(duration: 1.2)) {
                    borderRotation = 1.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        borderOpacity = 0.3
                    }
                }
            }
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
            Image(systemName: appState.captureMode == .agent ? "bell.badge.fill" : "cpu")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(statusColor)
            
            if let status = statusText {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity)
            }
            
            Spacer()
            
            if appState.isDictating {
                AudioWaveView(level: appState.audioLevel)
                    .transition(.opacity)
            }

            Button(action: { appState.toggleCaptureMode() }) {
                HStack(spacing: 4) {
                    Image(systemName: appState.captureMode == .agent ? "sparkles" : "doc.text")
                        .font(.system(size: 10, weight: .semibold))
                    Text(appState.captureMode == .agent ? "Agent" : "Vault")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(
                    appState.captureMode == .agent
                        ? .cyan
                        : (modeHover ? .white : .white.opacity(0.55))
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            appState.captureMode == .agent
                                ? Color.cyan.opacity(0.16)
                                : (modeHover ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                        )
                )
            }
            .buttonStyle(.plain)
            .help(appState.captureMode == .agent
                  ? "Agent mode: ⌘↩ sends to Antigravity (Reminders / Calendar / TaskNotes). Click to switch to Vault."
                  : "Vault mode: ⌘↩ saves to Obsidian · ⌘⇧↩ sends to Antigravity. Click to switch to Agent mode.")
            .onHover { modeHover = $0 }

            Button(action: { onToggleDictation?() }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(appState.isDictating ? .red : (micHover ? .white : .white.opacity(0.5)))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(micHover && !appState.isDictating ? Color.white.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { micHover = $0 }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isDictating)
        .animation(.easeInOut(duration: 0.2), value: appState.captureMode)
        .animation(.easeInOut(duration: 0.5), value: statusText)
        .animation(.easeInOut(duration: 0.5), value: appState.isIdle)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }

    private var statusText: String? {
        if appState.isCleaning {
            return "Cleaning up..."
        }
        if appState.isDiscardHolding {
            return "Hold ⎋ to discard"
        }
        if appState.isDragOver {
            return "Drop here"
        }
        if let toast = appState.toastMessage {
            return toast
        }
        if appState.isFinalizingDictation {
            return "Finalizing dictation..."
        }
        if appState.isDictating {
            return "Listening"
        }
        if appState.isIdle && appState.hasContent {
            return appState.captureMode == .agent ? "⌘↩ send to agent" : "⌘↩ save · ⌘⇧↩ agent"
        }
        if appState.captureMode == .agent {
            return "Reminders / Calendar"
        }
        return nil
    }

    private var statusColor: Color {
        if appState.isCleaning { return .purple }
        if appState.isDiscardHolding { return .red }
        if appState.isDragOver { return .blue }
        if appState.toastMessage != nil { return appState.toastIsError ? .red : .green }
        if appState.isDictating { return .red }
        if appState.isIdle { return appState.captureMode == .agent ? .cyan : .green }
        if appState.captureMode == .agent { return .cyan.opacity(0.9) }
        return .white.opacity(0.85)
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

    private var textArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            CapturePanelTextView(text: $textInput)
                .frame(minHeight: 48, maxHeight: 260)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: textInput) { _, newValue in
                    appState.updateText(newValue)
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    private var attachmentsArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(nonTextItems().enumerated()), id: \.offset) { index, item in
                CaptureItemRow(item: item, onDelete: {
                    appState.removeItem(at: item)
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, nonTextItems().isEmpty ? 0 : 4)
        .padding(.bottom, nonTextItems().isEmpty ? 0 : 4)
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


