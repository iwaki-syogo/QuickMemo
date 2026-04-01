import XCTest
@testable import QuickMemo

final class MemoSyncIndicatorTests: XCTestCase {

    // MARK: - Shown cases

    func test_shouldShow_whenPendingAndLinked() {
        XCTAssertTrue(SyncIndicator.shouldShow(syncStatus: .pending, isGitHubLinked: true))
    }

    func test_shouldShow_whenFailedAndLinked() {
        XCTAssertTrue(SyncIndicator.shouldShow(syncStatus: .failed, isGitHubLinked: true))
    }

    // MARK: - Hidden cases

    func test_shouldHide_whenSynced() {
        XCTAssertFalse(SyncIndicator.shouldShow(syncStatus: .synced, isGitHubLinked: true))
    }

    func test_shouldHide_whenNotLinkedStatus() {
        XCTAssertFalse(SyncIndicator.shouldShow(syncStatus: .notLinked, isGitHubLinked: true))
    }

    func test_shouldHide_whenGitHubNotLinked_pending() {
        XCTAssertFalse(SyncIndicator.shouldShow(syncStatus: .pending, isGitHubLinked: false))
    }

    func test_shouldHide_whenGitHubNotLinked_failed() {
        XCTAssertFalse(SyncIndicator.shouldShow(syncStatus: .failed, isGitHubLinked: false))
    }

    func test_shouldHide_whenGitHubNotLinked_synced() {
        XCTAssertFalse(SyncIndicator.shouldShow(syncStatus: .synced, isGitHubLinked: false))
    }
}
