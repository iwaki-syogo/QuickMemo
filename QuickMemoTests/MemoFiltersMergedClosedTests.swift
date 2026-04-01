import XCTest
@testable import QuickMemo

final class MemoFiltersMergedClosedTests: XCTestCase {

    // MARK: - closed() should include merged memos

    func test_closed_includesMergedMemos() {
        let merged = Memo(title: "Merged", status: .merged)

        let result = MemoFilters.closed([merged])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Merged")
    }

    func test_closed_includesClosedMemos() {
        let closed = Memo(title: "Closed", status: .closed)

        let result = MemoFilters.closed([closed])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Closed")
    }

    func test_closed_excludesOpenMemos() {
        let open = Memo(title: "Open", status: .open)

        let result = MemoFilters.closed([open])

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - merged() should be removed (return empty)

    func test_merged_sectionIsRemoved() {
        let merged = Memo(title: "Merged", status: .merged)

        let result = MemoFilters.merged([merged])

        XCTAssertTrue(result.isEmpty, "merged() should return empty after unification — merged memos belong in closed()")
    }
}
