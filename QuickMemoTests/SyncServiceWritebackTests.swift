import XCTest
@testable import QuickMemo

final class SyncServiceWritebackTests: XCTestCase {

    func test_fetchIssueDetails_methodSignatureCompiles() {
        let client = GitHubAPIClient()
        let _: (String, String, String, Int) async throws -> [GitHubIssueDetail] = client.fetchIssueDetails
    }

    func test_memo_repositoryFields_areNilByDefault() {
        let memo = Memo(title: "test")
        XCTAssertNil(memo.repositoryOwner)
        XCTAssertNil(memo.repositoryName)
    }

    func test_memo_repositoryFields_canBeSet() {
        let memo = Memo(title: "test")
        memo.repositoryOwner = "testOwner"
        memo.repositoryName = "testRepo"
        XCTAssertEqual(memo.repositoryOwner, "testOwner")
        XCTAssertEqual(memo.repositoryName, "testRepo")
    }
}
