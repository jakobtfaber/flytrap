// FlytrapTests/MigrationTests.swift
import XCTest
@testable import Flytrap

final class MigrationTests: XCTestCase {
    private let testSuite = "com.flytrap.tests.migration"
    private let legacySuite = "com.flytrap.tests.migration.legacy"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: testSuite)
        UserDefaults().removePersistentDomain(forName: legacySuite)
        AppSettings.defaults = UserDefaults(suiteName: testSuite)!
    }

    override func tearDown() {
        AppSettings.defaults = .standard
        UserDefaults().removePersistentDomain(forName: testSuite)
        UserDefaults().removePersistentDomain(forName: legacySuite)
        super.tearDown()
    }

    func test_migration_is_no_op_when_flag_already_set() {
        AppSettings.defaults.set(true, forKey: "flytrap.migration.v1.complete")
        AppSettings.defaults.set("preexisting", forKey: "vaultPath")

        AppSettings.migrateLegacyDefaultsIfNeeded()

        XCTAssertEqual(AppSettings.defaults.string(forKey: "vaultPath"), "preexisting",
                       "Migration must be skipped when flag is already set")
    }

    func test_migration_sets_flag_after_first_run() {
        XCTAssertFalse(AppSettings.defaults.bool(forKey: "flytrap.migration.v1.complete"))
        AppSettings.migrateLegacyDefaultsIfNeeded()
        XCTAssertTrue(AppSettings.defaults.bool(forKey: "flytrap.migration.v1.complete"))
    }
}
