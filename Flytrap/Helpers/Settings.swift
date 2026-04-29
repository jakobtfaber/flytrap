// Flytrap/Helpers/Settings.swift
import Foundation

enum AppSettings {
    static var defaults: UserDefaults = .standard

    static var vaultPath: String {
        get { defaults.string(forKey: "vaultPath") ?? "/Users/jakobfaber/Obsidian/" }
        set { defaults.set(newValue, forKey: "vaultPath") }
    }

    static var claudeApiKey: String? {
        get { defaults.string(forKey: "claudeApiKey") }
        set { defaults.set(newValue, forKey: "claudeApiKey") }
    }

    static var hasClaudeApiKey: Bool {
        guard let key = claudeApiKey else { return false }
        return !key.isEmpty
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    static var togglePanelHotkey: String {
        get { defaults.string(forKey: "togglePanelHotkey") ?? "ctrl+space" }
        set { defaults.set(newValue, forKey: "togglePanelHotkey") }
    }

    static var dictateHotkey: String {
        get { defaults.string(forKey: "dictateHotkey") ?? "ctrl+shift+space" }
        set { defaults.set(newValue, forKey: "dictateHotkey") }
    }

    static var autoCloseEnabled: Bool {
        get { defaults.object(forKey: "autoCloseEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoCloseEnabled") }
    }

    static var autoCloseSeconds: Double {
        get {
            let val = defaults.double(forKey: "autoCloseSeconds")
            return val > 0 ? val : 10
        }
        set { defaults.set(newValue, forKey: "autoCloseSeconds") }
    }

    // MARK: - Legacy migration (Zoidberg → Flytrap)

    private static let migrationFlagKey = "flytrap.migration.v1.complete"
    private static let legacyBundleId = "com.malecks.zoidberg"
    private static let legacyKeys = [
        "vaultPath",
        "claudeApiKey",
        "launchAtLogin",
        "togglePanelHotkey",
        "dictateHotkey",
        "autoCloseEnabled",
        "autoCloseSeconds",
    ]

    static func migrateLegacyDefaultsIfNeeded() {
        guard !defaults.bool(forKey: migrationFlagKey) else { return }
        if let legacy = UserDefaults(suiteName: legacyBundleId) {
            for key in legacyKeys {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }
        migrateApplicationSupportDirectory()
        defaults.set(true, forKey: migrationFlagKey)
    }

    private static func migrateApplicationSupportDirectory() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let oldDir = home + "/Library/Application Support/Zoidberg"
        let newDir = home + "/Library/Application Support/Flytrap"

        var oldIsDir: ObjCBool = false
        guard fm.fileExists(atPath: oldDir, isDirectory: &oldIsDir), oldIsDir.boolValue else {
            return
        }
        try? fm.createDirectory(atPath: newDir, withIntermediateDirectories: true)
        if let entries = try? fm.contentsOfDirectory(atPath: oldDir) {
            for entry in entries {
                let src = (oldDir as NSString).appendingPathComponent(entry)
                let dst = (newDir as NSString).appendingPathComponent(entry)
                if !fm.fileExists(atPath: dst) {
                    try? fm.moveItem(atPath: src, toPath: dst)
                }
            }
        }
    }
}
