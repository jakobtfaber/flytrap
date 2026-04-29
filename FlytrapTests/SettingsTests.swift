// FlytrapTests/SettingsTests.swift
import XCTest
@testable import Flytrap

final class SettingsTests: XCTestCase {
    override func setUp() {
        AppSettings.defaults = UserDefaults(suiteName: "com.flytrap.tests")!
        AppSettings.defaults.removePersistentDomain(forName: "com.flytrap.tests")
    }

    func testDefaultVaultPath() {
        XCTAssertEqual(AppSettings.vaultPath, "/Users/jakobfaber/Obsidian/",
                       "The default vault path is hardcoded in AppSettings; this test pins it.")
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
