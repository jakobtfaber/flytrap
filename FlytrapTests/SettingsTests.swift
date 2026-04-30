// FlytrapTests/SettingsTests.swift
import XCTest
@testable import Flytrap

final class SettingsTests: XCTestCase {
    override func setUp() {
        AppSettings.defaults = UserDefaults(suiteName: "com.flytrap.tests")!
        AppSettings.defaults.removePersistentDomain(forName: "com.flytrap.tests")
    }

    func testDefaultVaultPath() {
        let expected = "\(NSHomeDirectory())/Obsidian/"
        XCTAssertEqual(AppSettings.vaultPath, expected,
                       "Default vault path is ~/Obsidian/ for the current user.")
    }

    func testSetVaultPath() {
        AppSettings.vaultPath = "/tmp/test-vault"
        XCTAssertEqual(AppSettings.vaultPath, "/tmp/test-vault")
    }

    func testClaudeApiKeyDefaultsToNil() {
        XCTAssertNil(AppSettings.claudeApiKey)
    }

    func testSetClaudeApiKey() {
        AppSettings.claudeApiKey = "sk-test-key"
        XCTAssertEqual(AppSettings.claudeApiKey, "sk-test-key")
    }

    func testHasClaudeApiKey() {
        XCTAssertFalse(AppSettings.hasClaudeApiKey)
        AppSettings.claudeApiKey = "sk-test"
        XCTAssertTrue(AppSettings.hasClaudeApiKey)
    }

    func testLaunchAtLoginDefaultsFalse() {
        XCTAssertFalse(AppSettings.launchAtLogin)
    }
}
