import XCTest
@testable import QuickMemo

final class MemoFiltersScopedTests: XCTestCase {

    // MARK: - Matching

    func test_scoped_returnsMemosMatchingRepository() {
        let matching = Memo(title: "Match", repositoryOwner: "octocat", repositoryName: "hello-world")
        let other = Memo(title: "Other", repositoryOwner: "octocat", repositoryName: "other-repo")

        let result = MemoFilters.scoped([matching, other], owner: "octocat", repository: "hello-world")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Match")
    }

    func test_scoped_excludesMismatchedRepository() {
        let memo = Memo(title: "Wrong", repositoryOwner: "alice", repositoryName: "notes")

        let result = MemoFilters.scoped([memo], owner: "bob", repository: "docs")

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Nil owner (local memos)

    func test_scoped_includesMemosWithNilOwner() {
        let local = Memo(title: "Local", repositoryOwner: nil, repositoryName: nil)
        let matching = Memo(title: "Match", repositoryOwner: "octocat", repositoryName: "hello-world")

        let result = MemoFilters.scoped([local, matching], owner: "octocat", repository: "hello-world")

        XCTAssertEqual(result.count, 2)
        let titles = result.map(\.title)
        XCTAssertTrue(titles.contains("Local"))
        XCTAssertTrue(titles.contains("Match"))
    }

    // MARK: - Empty input

    func test_scoped_returnsEmptyForEmptyInput() {
        let result = MemoFilters.scoped([], owner: "octocat", repository: "hello-world")

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Partial matches

    func test_scoped_excludesWhenOwnerMatchesButNameDiffers() {
        let memo = Memo(title: "Partial", repositoryOwner: "octocat", repositoryName: "wrong-repo")

        let result = MemoFilters.scoped([memo], owner: "octocat", repository: "hello-world")

        XCTAssertTrue(result.isEmpty)
    }

    func test_scoped_excludesWhenNameMatchesButOwnerDiffers() {
        let memo = Memo(title: "Partial", repositoryOwner: "stranger", repositoryName: "hello-world")

        let result = MemoFilters.scoped([memo], owner: "octocat", repository: "hello-world")

        XCTAssertTrue(result.isEmpty)
    }
}
