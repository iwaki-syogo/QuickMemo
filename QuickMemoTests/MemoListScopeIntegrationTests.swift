import XCTest
@testable import QuickMemo
import SwiftData

final class MemoListScopeIntegrationTests: XCTestCase {

    // Test that scoped filter works correctly with actual Memo objects in a SwiftData context
    @MainActor
    func test_scopedMemos_onlyReturnsCurrentRepoAndLocalMemos() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Memo.self, Label.self, configurations: config)
        let context = container.mainContext

        // Create memos for different repos
        let memoRepoA = Memo(title: "Repo A Issue", repositoryOwner: "ownerA", repositoryName: "repoA")
        let memoRepoB = Memo(title: "Repo B Issue", repositoryOwner: "ownerB", repositoryName: "repoB")
        let memoLocal = Memo(title: "Local Memo")  // repositoryOwner = nil

        context.insert(memoRepoA)
        context.insert(memoRepoB)
        context.insert(memoLocal)
        try context.save()

        let allMemos = try context.fetch(FetchDescriptor<Memo>())
        XCTAssertEqual(allMemos.count, 3)

        // Scope to repoA
        let scopedA = MemoFilters.scoped(allMemos, owner: "ownerA", repository: "repoA")
        XCTAssertEqual(scopedA.count, 2, "Should include repoA memo + local memo")
        XCTAssertTrue(scopedA.contains(where: { $0.title == "Repo A Issue" }))
        XCTAssertTrue(scopedA.contains(where: { $0.title == "Local Memo" }))
        XCTAssertFalse(scopedA.contains(where: { $0.title == "Repo B Issue" }))

        // Scope to repoB
        let scopedB = MemoFilters.scoped(allMemos, owner: "ownerB", repository: "repoB")
        XCTAssertEqual(scopedB.count, 2, "Should include repoB memo + local memo")
        XCTAssertTrue(scopedB.contains(where: { $0.title == "Repo B Issue" }))
        XCTAssertTrue(scopedB.contains(where: { $0.title == "Local Memo" }))
    }

    @MainActor
    func test_scopedMemos_filtersCorrectlyByStatus() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Memo.self, Label.self, configurations: config)
        let context = container.mainContext

        let openMemo = Memo(title: "Open", status: .open, repositoryOwner: "owner", repositoryName: "repo")
        let closedMemo = Memo(title: "Closed", status: .closed, repositoryOwner: "owner", repositoryName: "repo")
        let otherRepoMemo = Memo(title: "Other", status: .open, repositoryOwner: "other", repositoryName: "other")

        context.insert(openMemo)
        context.insert(closedMemo)
        context.insert(otherRepoMemo)
        try context.save()

        let allMemos = try context.fetch(FetchDescriptor<Memo>())
        let scoped = MemoFilters.scoped(allMemos, owner: "owner", repository: "repo")

        // After scoping, apply open filter
        let openFiltered = MemoFilters.open(scoped)
        XCTAssertEqual(openFiltered.count, 1)
        XCTAssertEqual(openFiltered.first?.title, "Open")

        let closedFiltered = MemoFilters.closed(scoped)
        XCTAssertEqual(closedFiltered.count, 1)
        XCTAssertEqual(closedFiltered.first?.title, "Closed")
    }
}
