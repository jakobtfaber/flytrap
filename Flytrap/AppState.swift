// Flytrap/AppState.swift
import SwiftUI
import Combine

enum CaptureMode: Equatable {
    case vault
    case agent
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentSession = CaptureSession()
    @Published var captureMode: CaptureMode = .vault
    @Published var activeAgentDispatches = 0
    @Published var isDictating = false
    @Published var isFinalizingDictation = false
    @Published var audioLevel: Float = 0
    /// Text that existed before the current dictation session started
    private var textBeforeDictation: String?
    /// If the user submits while dictation is still finalizing, defer until final transcript arrives.
    private var pendingSubmitAfterDictation: CaptureMode?
    private var pendingDictationFlushTimer: Timer?
    @Published var isDragOver = false
    @Published var toastMessage: String?
    @Published var toastIsError = false
    @Published var openCount = 0
    @Published var isIdle = false
    @Published var isCleaning = false
    @Published var isAutoClosing = false
    @Published var isDiscardHolding = false

    /// Called when the panel should close (after save, discard, etc.)
    var onDismiss: (() -> Void)?
    /// Called to stop any active dictation
    var onStopDictation: (() -> Void)?
    @Published var settingsRequested = false

    private var idleTimer: Timer?
    private var autoCloseTimer: Timer?
    private let idleDelay: TimeInterval = 1.5
    private let hintDuration: TimeInterval = 2.5
    private var autoCloseDelay: TimeInterval { AppSettings.autoCloseSeconds }

    private var toastTimer: Timer?

    private let appSupportDir: String = {
        let dir = NSHomeDirectory() + "/Library/Application Support/Flytrap"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var persistencePath: String { appSupportDir + "/pending-session.json" }
    private var failedQueuePath: String { appSupportDir + "/failed-agent-drafts.json" }
    private var inflightRunsPath: String { appSupportDir + "/inflight-agent-runs.json" }

    init() {
        loadPersistedSession()
        recoverInterruptedAgentRuns()
        restoreNextFailedDraftIfEmpty()
    }

    var hasContent: Bool { !currentSession.isEmpty }

    /// Call whenever the user does something — resets the idle countdown
    func resetIdle(showHint: Bool = false) {
        isIdle = false
        isAutoClosing = false
        idleTimer?.invalidate()
        autoCloseTimer?.invalidate()

        // Save hint only after typing, and only if there's content.
        // Timer.scheduledTimer callbacks run on the runloop they're scheduled
        // on (here: main), so MainActor.assumeIsolated is correct and avoids
        // the @Sendable Task-capture issues that Swift 6 strict mode flags.
        if showHint && hasContent {
            idleTimer = Timer.scheduledTimer(withTimeInterval: idleDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    self.isIdle = true
                    self.idleTimer = Timer.scheduledTimer(withTimeInterval: self.hintDuration, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.isIdle = false
                        }
                    }
                }
            }
        }

        // Auto-close after configured seconds of inactivity.
        if AppSettings.autoCloseEnabled {
            autoCloseTimer = Timer.scheduledTimer(withTimeInterval: autoCloseDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.onDismiss?()
                }
            }
        }
    }

    func pauseIdle() {
        idleTimer?.invalidate()
        autoCloseTimer?.invalidate()
        isIdle = false
    }

    func startDictation() {
        textBeforeDictation = currentTextContent()
        isDictating = true
        idleTimer?.invalidate()
        autoCloseTimer?.invalidate()
        isIdle = false
    }

    func beginStoppingDictation() {
        isFinalizingDictation = true
        pendingDictationFlushTimer?.invalidate()
        pendingDictationFlushTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isDictating else { return }
                self.stopDictation()
            }
        }
    }

    func stopDictation() {
        isDictating = false
        isFinalizingDictation = false
        pendingDictationFlushTimer?.invalidate()
        pendingDictationFlushTimer = nil
        if let pendingMode = pendingSubmitAfterDictation {
            pendingSubmitAfterDictation = nil
            switch pendingMode {
            case .agent:
                performSendToAgent()
            case .vault:
                save()
            }
            return
        }
        resetIdle(showHint: true)
    }

    func addItem(_ item: CaptureItem) {
        currentSession.addItem(item)
        persistSession()
        resetIdle()
    }

    func removeItem(at item: CaptureItem) {
        currentSession.removeItem(item)
        persistSession()
    }

    /// Called with transcription text during dictation, or with user edits.
    func updateText(_ text: String) {
        var items = currentSession.items.filter {
            if case .text = $0 { return false }
            return true
        }
        if !text.isEmpty {
            items.insert(.text(text), at: 0)
        }
        currentSession = CaptureSession()
        for item in items {
            currentSession.addItem(item)
        }
        persistSession()
        if !isDictating {
            resetIdle(showHint: true)
        }
    }

    /// Called by the transcription service — appends new speech after existing text.
    func updateTranscription(_ transcribedText: String) {
        guard isDictating || pendingSubmitAfterDictation != nil else { return }
        let prefix = textBeforeDictation ?? ""
        if prefix.isEmpty {
            updateText(transcribedText)
        } else {
            updateText(prefix + "\n" + transcribedText)
        }
    }

    private func currentTextContent() -> String {
        for item in currentSession.items {
            if case .text(let content) = item { return content }
        }
        return ""
    }

    func cleanupWithClaude() {
        let text = currentTextContent()
        guard !text.isEmpty, !isCleaning, AppSettings.hasClaudeApiKey else { return }

        isCleaning = true
        pauseIdle()
        let claude = ClaudeService(apiKey: AppSettings.claudeApiKey)

        Task {
            if let cleaned = await claude.cleanup(text: text) {
                await MainActor.run {
                    updateText(cleaned)
                    isCleaning = false
                    resetIdle(showHint: true)
                }
            } else {
                await MainActor.run {
                    isCleaning = false
                    showToast("Cleanup failed", isError: true)
                    resetIdle()
                }
            }
        }
    }

    func toggleCaptureMode() {
        captureMode = (captureMode == .vault) ? .agent : .vault
        resetIdle(showHint: hasContent)
    }

    func submitPrimary() {
        switch captureMode {
        case .vault:
            save()
        case .agent:
            sendToAgent()
        }
    }

    func submitSecondary() {
        switch captureMode {
        case .vault:
            sendToAgent()
        case .agent:
            save()
        }
    }

    func sendToAgent() {
        if isDictating {
            pendingSubmitAfterDictation = .agent
            isFinalizingDictation = true
            onStopDictation?()
            pendingDictationFlushTimer?.invalidate()
            pendingDictationFlushTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, self.pendingSubmitAfterDictation == .agent else { return }
                    self.stopDictation()
                }
            }
            return
        }
        performSendToAgent()
    }

    private func performSendToAgent() {
        let hasMediaAttachments = currentSession.items.contains { item in
            switch item {
            case .image, .video: return true
            case .text, .link: return false
            }
        }
        if hasMediaAttachments {
            showToast("Images/videos not supported in Agent mode — use Vault", isError: true)
            return
        }

        let text = currentTextContent().trimmingCharacters(in: .whitespacesAndNewlines)
        let links: [URL] = currentSession.items.compactMap { item in
            if case .link(let url) = item { return url }
            return nil
        }

        guard !text.isEmpty || !links.isEmpty else {
            showToast("Nothing to send", isError: true)
            return
        }

        guard AgentDispatchService.resolveBinaryPath() != nil else {
            showToast("agy not found — check Settings", isError: true)
            return
        }

        let snapshotSession = currentSession
        guard let runDir = AgentDispatchService.shared.prepareRunDirectory(draft: snapshotSession) else {
            showToast("Failed to save draft backup", isError: true)
            return
        }

        let runId = runDir.lastPathComponent
        recordInflightRun(id: runId, session: snapshotSession)

        activeAgentDispatches += 1
        AgentDispatchService.shared.dispatch(jot: text, links: links, runDirectory: runDir) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.activeAgentDispatches = max(0, self.activeAgentDispatches - 1)
                self.removeInflightRun(id: runId)
                if !result.success {
                    let retrySession: CaptureSession
                    if result.createdItems.isEmpty {
                        retrySession = snapshotSession
                    } else if !result.failedItems.isEmpty {
                        var partial = CaptureSession()
                        partial.addItem(.text(AgentDispatchService.formatRetryDraft(for: result.failedItems)))
                        retrySession = partial
                    } else {
                        var partial = CaptureSession()
                        let retryText = "Retry failed items:\n" + result.failures.map { "- \($0)" }.joined(separator: "\n")
                        partial.addItem(.text(retryText))
                        retrySession = partial
                    }

                    if self.currentSession.isEmpty {
                        self.currentSession = retrySession
                        self.persistSession()
                    } else {
                        self.enqueueFailedDraft(retrySession)
                    }
                }
            }
        }

        showToast("Sent to Antigravity", isError: false)
        clearSession()
        restoreNextFailedDraftIfEmpty()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onDismiss?()
        }
    }

    func save() {
        if isDictating {
            pendingSubmitAfterDictation = .vault
            isFinalizingDictation = true
            onStopDictation?()
            pendingDictationFlushTimer?.invalidate()
            pendingDictationFlushTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, self.pendingSubmitAfterDictation == .vault else { return }
                    self.stopDictation()
                }
            }
            return
        }

        let vaultPath = AppSettings.vaultPath
        let writer = VaultWriter(vaultPath: vaultPath)

        do {
            let _ = try writer.save(session: currentSession, title: nil, folder: nil)
            showToast("Saved to vault", isError: false)
            clearSession()
            restoreNextFailedDraftIfEmpty()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onDismiss?()
            }
        } catch {
            showToast("Failed to save — check vault path in settings", isError: true)
        }
    }

    func discardSession() {
        pendingSubmitAfterDictation = nil
        pendingDictationFlushTimer?.invalidate()
        pendingDictationFlushTimer = nil
        isDictating = false
        isFinalizingDictation = false
        onStopDictation?()
        clearSession()
        deletePersistence()
        restoreNextFailedDraftIfEmpty()
    }

    private func showToast(_ message: String, isError: Bool) {
        toastMessage = message
        toastIsError = isError
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: isError ? 3 : 1.5, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.toastMessage = nil
            }
        }
    }

    private func persistSession() {
        guard !currentSession.isEmpty else {
            deletePersistence()
            return
        }
        if let data = try? JSONEncoder().encode(currentSession) {
            try? data.write(to: URL(fileURLWithPath: persistencePath))
        }
    }

    private func loadPersistedSession() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: persistencePath)),
              let session = try? JSONDecoder().decode(CaptureSession.self, from: data) else {
            return
        }
        currentSession = session
    }

    private func clearSession() {
        currentSession = CaptureSession()
        textBeforeDictation = nil
        deletePersistence()
    }

    private func deletePersistence() {
        try? FileManager.default.removeItem(atPath: persistencePath)
    }

    private func loadInflightRuns() -> [String: CaptureSession] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: inflightRunsPath)),
              let map = try? JSONDecoder().decode([String: CaptureSession].self, from: data) else {
            return [:]
        }
        return map
    }

    private func saveInflightRuns(_ map: [String: CaptureSession]) {
        if map.isEmpty {
            try? FileManager.default.removeItem(atPath: inflightRunsPath)
        } else if let data = try? JSONEncoder().encode(map) {
            try? data.write(to: URL(fileURLWithPath: inflightRunsPath), options: .atomic)
        }
    }

    private func recordInflightRun(id: String, session: CaptureSession) {
        var map = loadInflightRuns()
        map[id] = session
        saveInflightRuns(map)
    }

    private func removeInflightRun(id: String) {
        var map = loadInflightRuns()
        map.removeValue(forKey: id)
        saveInflightRuns(map)
    }

    private func loadFailedQueue() -> [CaptureSession] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: failedQueuePath)),
              let queue = try? JSONDecoder().decode([CaptureSession].self, from: data) else {
            return []
        }
        return queue
    }

    private func saveFailedQueue(_ queue: [CaptureSession]) {
        if queue.isEmpty {
            try? FileManager.default.removeItem(atPath: failedQueuePath)
        } else if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: URL(fileURLWithPath: failedQueuePath), options: .atomic)
        }
    }

    private func enqueueFailedDraft(_ session: CaptureSession) {
        var queue = loadFailedQueue()
        queue.append(session)
        saveFailedQueue(queue)
    }

    private func recoverInterruptedAgentRuns() {
        let interrupted = loadInflightRuns()
        guard !interrupted.isEmpty else { return }
        var queue = loadFailedQueue()
        let runsRoot = URL(fileURLWithPath: appSupportDir, isDirectory: true)
            .appendingPathComponent("agent-runs", isDirectory: true)
        for key in interrupted.keys.sorted() {
            guard let session = interrupted[key] else { continue }
            let runDir = runsRoot.appendingPathComponent(key, isDirectory: true)
            let metaURL = runDir.appendingPathComponent("meta.json")
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let exitCode = meta["exitCode"] as? Int ?? -1
                let created = meta["created"] as? [String] ?? []
                if exitCode == 0 {
                    continue
                }
                if !created.isEmpty {
                    if let rawFailed = meta["failedItems"],
                       let failedData = try? JSONSerialization.data(withJSONObject: rawFailed),
                       let failedItems = try? JSONDecoder().decode([AgentCaptureItem].self, from: failedData),
                       !failedItems.isEmpty {
                        var partial = CaptureSession()
                        partial.addItem(.text(AgentDispatchService.formatRetryDraft(for: failedItems)))
                        queue.append(partial)
                    }
                    continue
                }
            }
            let progressURL = runDir.appendingPathComponent("progress.json")
            if let pData = try? Data(contentsOf: progressURL),
               let progress = try? JSONSerialization.jsonObject(with: pData) as? [String: Any],
               let created = progress["created"] as? [String],
               !created.isEmpty {
                // At least one item was already committed before interruption; do not blindly replay the whole draft.
                continue
            }
            queue.append(session)
        }
        saveFailedQueue(queue)
        saveInflightRuns([:])
    }

    private func restoreNextFailedDraftIfEmpty() {
        guard currentSession.isEmpty else { return }
        var queue = loadFailedQueue()
        guard !queue.isEmpty else { return }
        let restored = queue.removeFirst()
        saveFailedQueue(queue)
        currentSession = restored
        persistSession()
    }
}
