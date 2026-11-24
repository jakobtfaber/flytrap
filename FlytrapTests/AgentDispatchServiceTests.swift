// FlytrapTests/AgentDispatchServiceTests.swift
import XCTest
@testable import Flytrap

final class AgentDispatchServiceTests: XCTestCase {
    override func setUp() {
        AppSettings.defaults = UserDefaults(suiteName: "com.flytrap.agent.tests")!
        AppSettings.defaults.removePersistentDomain(forName: "com.flytrap.agent.tests")
    }

    func testBuildPromptFramesUntrustedCaptureAndDestinations() {
        let fixedDate = Date(timeIntervalSince1970: 1_795_549_200)
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let link = URL(string: "https://example.com/meeting")!

        let prompt = AgentDispatchService.buildPrompt(
            jot: "dentist next tues 2pm also remind me buy milk",
            links: [link],
            now: fixedDate,
            timeZone: tz
        )

        XCTAssertTrue(prompt.contains("<untrusted_capture>"))
        XCTAssertTrue(prompt.contains("dentist next tues 2pm also remind me buy milk"))
        XCTAssertTrue(prompt.contains("https://example.com/meeting"))
        XCTAssertTrue(prompt.contains("America/Los_Angeles"))
        XCTAssertTrue(prompt.contains("Do NOT run tools"))
    }

    func testBuildArgumentsUsesSandboxPlanModeAndJsonSchema() {
        let args = AgentDispatchService.buildArguments(prompt: "hello", model: nil, effort: "low")
        XCTAssertTrue(args.contains("--sandbox"))
        XCTAssertTrue(args.contains("--mode"))
        XCTAssertTrue(args.contains("plan"))
        XCTAssertFalse(args.contains("--disable-slash-commands"))
        XCTAssertFalse(args.contains("--dangerously-skip-permissions"))
        XCTAssertTrue(args.contains("--json-schema"))
        XCTAssertTrue(args.contains("--effort"))
        XCTAssertTrue(args.contains("low"))
        XCTAssertFalse(args.contains("--model"))
        XCTAssertEqual(args.last, "hello")
    }

    func testBuildArgumentsIncludesModelWhenConfigured() {
        let args = AgentDispatchService.buildArguments(prompt: "hello", model: "gemini-4-neon", effort: "medium")
        XCTAssertTrue(args.contains("--model"))
        XCTAssertTrue(args.contains("gemini-4-neon"))
        XCTAssertTrue(args.contains("--effort"))
        XCTAssertTrue(args.contains("medium"))
    }

    func testBuildEnvironmentPrependsHomebrewAndLocalBin() {
        let env = AgentDispatchService.buildEnvironment(home: "/Users/tester", base: ["PATH": "/usr/bin:/bin"])
        XCTAssertEqual(env["HOME"], "/Users/tester")
        let pathEntries = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        XCTAssertEqual(pathEntries.first, "/Users/tester/.local/bin")
        XCTAssertTrue(pathEntries.contains("/opt/homebrew/bin"))
        XCTAssertTrue(pathEntries.contains("/Users/tester/bin"))
    }

    func testParseCapturePlanSuccessAndNothingToAdd() throws {
        let envelope = """
        {"status":"SUCCESS","response":"{\\"status\\":\\"ok\\",\\"items\\":[{\\"destination\\":\\"reminder\\",\\"title\\":\\"Buy milk\\",\\"notes\\":null,\\"list\\":\\"General\\",\\"due\\":null,\\"start\\":null,\\"end\\":null,\\"allDay\\":false,\\"calendar\\":null,\\"priority\\":\\"none\\"}],\\"summary\\":\\"Buy milk\\"}"}
        """
        let plan = try AgentDispatchService.parseCapturePlan(from: envelope)
        XCTAssertEqual(plan.status, "ok")
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items[0].destination, "reminder")
        XCTAssertEqual(plan.items[0].title, "Buy milk")

        let errorEnvelope = #"{"status":"ERROR","error":"quota exceeded"}"#
        XCTAssertThrowsError(try AgentDispatchService.parseCapturePlan(from: errorEnvelope))

        let structuredEnvelope = """
        {"status":"SUCCESS","response":"```json\\n{}\\n```\\n{}","structured_output":{"status":"ok","items":[{"destination":"calendar","title":"Dentist","start":"2026-11-25T17:00:00-08:00"}],"summary":"Dentist"}}
        """
        let structuredPlan = try AgentDispatchService.parseCapturePlan(from: structuredEnvelope)
        XCTAssertEqual(structuredPlan.items.count, 1)
        XCTAssertEqual(structuredPlan.items[0].destination, "calendar")
        XCTAssertNotNil(AgentDispatchService.parseLocalDate("2026-11-25T17:00:00-08:00"))
    }

    func testCreateTaskNoteWritesValidFrontmatterAndSanitizesFilename() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("flytrap-tasknote-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = AgentCaptureItem(
            destination: "tasknote",
            title: "../Fix: parser/edge case",
            notes: "Investigate timeout on large captures",
            list: nil,
            due: "2026-12-01",
            start: nil,
            end: nil,
            allDay: false,
            calendar: nil,
            priority: "high"
        )

        let label = try AgentDispatchService.createTaskNote(item, title: item.title, vaultPath: tmpDir.path)
        XCTAssertTrue(label.hasPrefix("TaskNote: "))

        let recordsDir = tmpDir.appendingPathComponent("Task records", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: recordsDir.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertFalse(files[0].contains("/"))
        XCTAssertFalse(files[0].contains(".."))

        let content = try String(contentsOf: recordsDir.appendingPathComponent(files[0]), encoding: .utf8)
        XCTAssertTrue(content.contains("type: task"))
        XCTAssertTrue(content.contains("status: open"))
        XCTAssertTrue(content.contains("priority: high"))
        XCTAssertTrue(content.contains("due: \"2026-12-01\""))
        XCTAssertTrue(content.contains("Investigate timeout on large captures"))
    }

    func testDefaultAgentSettings() {
        XCTAssertEqual(AppSettings.agyEffort, "low")
        XCTAssertNil(AppSettings.agyModel)
        XCTAssertEqual(AppSettings.agentPanelHotkey, "ctrl+opt+space")
        XCTAssertTrue(AppSettings.agyBinaryPath.hasSuffix("/.local/bin/agy"))
    }
}
