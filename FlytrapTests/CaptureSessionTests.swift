import XCTest
@testable import Flytrap

final class CaptureSessionTests: XCTestCase {
    func testEmptySession() {
        let session = CaptureSession()
        XCTAssertTrue(session.items.isEmpty)
        XCTAssertTrue(session.isEmpty)
    }

    func testAddItems() {
        var session = CaptureSession()
        session.addItem(.text("Hello"))
        session.addItem(.link(URL(string: "https://example.com")!))
        XCTAssertEqual(session.items.count, 2)
        XCTAssertFalse(session.isEmpty)
    }

    func testToMarkdownWithFallbackTitle() {
        var session = CaptureSession()
        session.addItem(.text("Some notes about auth"))
        session.addItem(.image(filename: "screenshot.png", originalPath: "/tmp/screenshot.png"))

        let md = session.toMarkdown(title: nil)

        XCTAssertTrue(md.range(of: #"^## \d{1,2}:\d{2} [AP]M"#, options: .regularExpression) != nil,
                      "Fallback title should be a 'H:mm a' time heading at the start of the entry")
        XCTAssertTrue(md.contains("Some notes about auth"))
        XCTAssertTrue(md.contains("![[attachments/screenshot.png|500]]"))
    }

    func testToMarkdownWithCustomTitle() {
        var session = CaptureSession()
        session.addItem(.text("Auth flow notes"))

        let md = session.toMarkdown(title: "Auth Flow Investigation")

        XCTAssertTrue(md.hasPrefix("## Auth Flow Investigation"),
                      "Per-entry heading is H2 (## …), not H1; H1 is reserved for the daily-note date heading written by VaultWriter")
        XCTAssertTrue(md.contains("Auth flow notes"))
    }

    func testClear() {
        var session = CaptureSession()
        session.addItem(.text("Hello"))
        session.clear()
        XCTAssertTrue(session.isEmpty)
    }

    func testPersistence() throws {
        var session = CaptureSession()
        session.addItem(.text("Persist me"))
        session.addItem(.link(URL(string: "https://example.com")!))

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(CaptureSession.self, from: data)

        XCTAssertEqual(decoded.items.count, 2)
        XCTAssertEqual(decoded.items[0].toMarkdown(), "Persist me")
    }

    func testAllMediaFiles() {
        var session = CaptureSession()
        session.addItem(.text("Hello"))
        session.addItem(.image(filename: "a.png", originalPath: "/tmp/a.png"))
        session.addItem(.video(filename: "b.mov", originalPath: "/tmp/b.mov"))
        session.addItem(.link(URL(string: "https://example.com")!))

        let media = session.allMediaFiles
        XCTAssertEqual(media.count, 2)
        XCTAssertEqual(media[0].filename, "a.png")
        XCTAssertEqual(media[1].filename, "b.mov")
    }
}
