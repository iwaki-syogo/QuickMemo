import XCTest
@testable import QuickMemo

final class MemoListGroupingTests: XCTestCase {

    // MARK: - Open memos

    func test_openMemos_excludesPinned() {
        let pinned = Memo(title: "Pinned", isPinned: true, status: .open)
        let normal = Memo(title: "Normal", isPinned: false, status: .open)

        let result = MemoFilters.open([pinned, normal])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Normal")
    }

    func test_openMemos_filtersCorrectStatus() {
        let open = Memo(title: "Open", status: .open)
        let closed = Memo(title: "Closed", status: .closed)
        let merged = Memo(title: "Merged", status: .merged)

        let result = MemoFilters.open([open, closed, merged])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Open")
    }

    // MARK: - Merged memos (unified into closed)

    func test_mergedMemos_filtersCorrectStatus() {
        let open = Memo(title: "Open", status: .open)
        let closed = Memo(title: "Closed", status: .closed)
        let merged = Memo(title: "Merged", status: .merged)

        let result = MemoFilters.merged([open, closed, merged])

        XCTAssertEqual(result.count, 0, "merged() should return empty after unification")
    }

    // MARK: - Closed memos (includes merged)

    func test_closedMemos_filtersCorrectStatus() {
        let open = Memo(title: "Open", status: .open)
        let closed = Memo(title: "Closed", status: .closed)
        let merged = Memo(title: "Merged", status: .merged)

        let result = MemoFilters.closed([open, closed, merged])

        XCTAssertEqual(result.count, 2, "closed() should include both closed and merged memos")
    }

    // MARK: - Pinned memos

    func test_pinnedMemos_onlyIncludesPinned() {
        let pinned = Memo(title: "Pinned", isPinned: true, status: .open)
        let normal = Memo(title: "Normal", isPinned: false, status: .open)

        let result = MemoFilters.pinned([pinned, normal])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Pinned")
    }

    // MARK: - Group coverage

    func test_allGroups_coverAllNonPinnedMemos() {
        let memos = [
            Memo(title: "Open", status: .open),
            Memo(title: "Closed", status: .closed),
            Memo(title: "Merged", status: .merged),
            Memo(title: "Pinned", isPinned: true, status: .open),
        ]

        let open = MemoFilters.open(memos)
        let merged = MemoFilters.merged(memos)
        let closed = MemoFilters.closed(memos)
        let pinned = MemoFilters.pinned(memos)

        XCTAssertEqual(open.count + merged.count + closed.count + pinned.count, memos.count)
    }
}
