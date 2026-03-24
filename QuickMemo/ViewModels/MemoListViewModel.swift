import Foundation
import SwiftData
import Observation

@Observable
class MemoListViewModel {
    var pinnedMemos: [Memo] = []
    var otherMemos: [Memo] = []
    var openMemos: [Memo] = []
    var closedMemos: [Memo] = []

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func fetchMemos(isGitHubLinked: Bool = false) {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let allMemos = try modelContext.fetch(descriptor)
            pinnedMemos = allMemos.filter { $0.isPinned }

            if isGitHubLinked {
                let unpinned = allMemos.filter { !$0.isPinned }
                openMemos = unpinned.filter { $0.status == .open }
                closedMemos = unpinned.filter { $0.status == .closed }
                otherMemos = []
            } else {
                otherMemos = allMemos.filter { !$0.isPinned }
                openMemos = []
                closedMemos = []
            }
        } catch {
            pinnedMemos = []
            otherMemos = []
            openMemos = []
            closedMemos = []
        }
    }

    func deleteMemo(_ memo: Memo) {
        guard let modelContext else { return }
        modelContext.delete(memo)
        try? modelContext.save()
    }

    func togglePin(_ memo: Memo) {
        memo.isPinned.toggle()
        memo.updatedAt = Date()
        try? modelContext?.save()
    }
}
