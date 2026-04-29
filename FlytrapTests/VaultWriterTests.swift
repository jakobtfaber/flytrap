// FlytrapTests/VaultWriterTests.swift
import XCTest
@testable import Flytrap

final class VaultWriterTests: XCTestCase {
    var testVaultPath: String!

    override func setUp() {
        testVaultPath = NSTemporaryDirectory() + "flytrap-test-vault-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: testVaultPath, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testVaultPath)
    }

    func testWriteTextOnlySession() throws {
        var session = CaptureSession()
        session.addItem(.text("Hello from test"))
        let writer = VaultWriter(vaultPath: testVaultPath)
        let result = try writer.save(session: session, title: nil, folder: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.filePath))
        XCTAssertTrue(result.filePath.contains("/Captures/"))
        XCTAssertTrue(result.filePath.hasSuffix("-capture.md"))
        let content = try String(contentsOfFile: result.filePath, encoding: .utf8)
        XCTAssertTrue(content.contains("Hello from test"))
    }

    func testWriteWithCustomTitleAndFolder() throws {
        var session = CaptureSession()
        session.addItem(.text("Auth notes"))
        let writer = VaultWriter(vaultPath: testVaultPath)
        let result = try writer.save(session: session, title: "Auth Flow", folder: "Projects")
        XCTAssertTrue(result.filePath.contains("/Projects/"))
        XCTAssertTrue(result.filePath.contains("Auth Flow.md"))
        let content = try String(contentsOfFile: result.filePath, encoding: .utf8)
        XCTAssertTrue(content.contains("# Auth Flow"))
    }

    func testWriteWithMediaCopiesFiles() throws {
        let imagePath = NSTemporaryDirectory() + "test-image.png"
        try "fake png data".write(toFile: imagePath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: imagePath) }
        var session = CaptureSession()
        session.addItem(.text("See screenshot:"))
        session.addItem(.image(filename: "test-image.png", originalPath: imagePath))
        let writer = VaultWriter(vaultPath: testVaultPath)
        let result = try writer.save(session: session, title: nil, folder: nil)
        let attachmentDir = (result.filePath as NSString).deletingLastPathComponent + "/attachments"
        let attachmentPath = attachmentDir + "/test-image.png"
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentPath))
    }

    func testValidateVaultPathFailsForMissingPath() {
        let writer = VaultWriter(vaultPath: "/nonexistent/path/vault")
        XCTAssertThrowsError(try writer.validate()) { error in
            XCTAssertTrue(error is VaultWriterError)
        }
    }

    func testMoveToEnhancedLocation() throws {
        var session = CaptureSession()
        session.addItem(.text("Move me"))
        let writer = VaultWriter(vaultPath: testVaultPath)
        let initial = try writer.save(session: session, title: nil, folder: nil)
        let moved = try writer.moveToEnhancedLocation(
            from: initial.filePath,
            enhancedMarkdown: session.toMarkdown(title: "Better Title"),
            title: "Better Title",
            folder: "Notes"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: initial.filePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved))
        XCTAssertTrue(moved.contains("/Notes/"))
        XCTAssertTrue(moved.contains("Better Title.md"))
    }
}
