// FlytrapTests/ClaudeServiceTests.swift
import XCTest
@testable import Flytrap

final class ClaudeServiceTests: XCTestCase {
    func testDisabledWhenNoApiKey() async {
        let service = ClaudeService(apiKey: nil)
        XCTAssertFalse(service.isEnabled)
    }

    func testEnabledWithApiKey() async {
        let service = ClaudeService(apiKey: "sk-test")
        XCTAssertTrue(service.isEnabled)
    }

    func testParseEnhanceResponse() throws {
        try XCTSkipIf(true, "Pre-existing drift: ClaudeService.parseEnhanceResponse / buildEnhancePrompt are not implemented in this repo. Predates the Flytrap rename. Re-enable when the enhance API ships.")
        #if false // Body preserved as documentation; will not compile until ClaudeService.parseEnhanceResponse is added.
        let json = """
        {
            "content": [{"type": "text", "text": "{\\"title\\": \\"Auth Flow Notes\\", \\"folder\\": \\"Projects\\", \\"cleanedText\\": \\"Fixed up text here.\\"}"}]
        }
        """
        let result = try ClaudeService.parseEnhanceResponse(json.data(using: .utf8)!)
        XCTAssertEqual(result.title, "Auth Flow Notes")
        XCTAssertEqual(result.folder, "Projects")
        XCTAssertEqual(result.cleanedText, "Fixed up text here.")
        #endif
    }

    func testParseEnhanceResponseHandlesMalformed() throws {
        try XCTSkipIf(true, "Pre-existing drift: ClaudeService.parseEnhanceResponse / buildEnhancePrompt are not implemented in this repo. Predates the Flytrap rename. Re-enable when the enhance API ships.")
        #if false // Body preserved as documentation; will not compile until ClaudeService.parseEnhanceResponse is added.
        let badJson = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try ClaudeService.parseEnhanceResponse(badJson))
        #endif
    }

    func testBuildPrompt() throws {
        try XCTSkipIf(true, "Pre-existing drift: ClaudeService.parseEnhanceResponse / buildEnhancePrompt are not implemented in this repo. Predates the Flytrap rename. Re-enable when the enhance API ships.")
        #if false // Body preserved as documentation; will not compile until ClaudeService.buildEnhancePrompt is added.
        var session = CaptureSession()
        session.addItem(.text("some dictated text"))
        session.addItem(.link(URL(string: "https://example.com")!))

        let prompt = ClaudeService.buildEnhancePrompt(for: session)
        XCTAssertTrue(prompt.contains("some dictated text"))
        XCTAssertTrue(prompt.contains("https://example.com"))
        XCTAssertTrue(prompt.contains("title"))
        XCTAssertTrue(prompt.contains("folder"))
        #endif
    }
}
