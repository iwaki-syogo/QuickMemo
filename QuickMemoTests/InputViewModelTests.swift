import XCTest
import SwiftData
@testable import QuickMemo

@MainActor
final class InputViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Memo.self, configurations: config)
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Save with labels and repository

    func test_save_withLabelsAndRepository() {
        let vm = InputViewModel()
        vm.setModelContext(context)
        vm.title = "Test memo"
        vm.body = "Body text"
        vm.selectedLabelIDs = [UUID(), UUID()]
        vm.repositoryOwner = "octocat"
        vm.repositoryName = "hello-world"

        vm.save()

        XCTAssertNotNil(vm.savedMemo)
        XCTAssertEqual(vm.savedMemo?.title, "Test memo")
        XCTAssertEqual(vm.savedMemo?.labelIDs.count, 2)
        XCTAssertEqual(vm.savedMemo?.repositoryOwner, "octocat")
        XCTAssertEqual(vm.savedMemo?.repositoryName, "hello-world")
    }

    func test_save_withoutRepository() {
        let vm = InputViewModel()
        vm.setModelContext(context)
        vm.title = "Local memo"

        vm.save()

        XCTAssertNotNil(vm.savedMemo)
        XCTAssertNil(vm.savedMemo?.repositoryOwner)
        XCTAssertNil(vm.savedMemo?.repositoryName)
        XCTAssertTrue(vm.savedMemo?.labelIDs.isEmpty == true)
    }

    // MARK: - setDefaults

    func test_setDefaults_setsRepositoryFromAccount() {
        let account = GitHubAccount()
        account.isLinked = true
        account.repositoryOwner = "owner"
        account.repositoryName = "repo"

        let vm = InputViewModel()
        vm.setDefaults(from: account)

        XCTAssertEqual(vm.repositoryOwner, "owner")
        XCTAssertEqual(vm.repositoryName, "repo")
    }

    func test_setDefaults_doesNothingWhenNotLinked() {
        let account = GitHubAccount()
        account.isLinked = false

        let vm = InputViewModel()
        vm.setDefaults(from: account)

        XCTAssertNil(vm.repositoryOwner)
        XCTAssertNil(vm.repositoryName)
    }
}
