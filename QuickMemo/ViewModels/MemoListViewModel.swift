import Foundation
import SwiftData
import Observation

@Observable
class MemoListViewModel {
    var pinnedMemos: [Memo] = []
    var otherMemos: [Memo] = []

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func fetchMemos() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<Memo>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let allMemos = try modelContext.fetch(descriptor)
            pinnedMemos = allMemos.filter { $0.isPinned }
            otherMemos = allMemos.filter { !$0.isPinned }
        } catch {
            pinnedMemos = []
            otherMemos = []
        }
    }

    func deleteMemo(_ memo: Memo) {
        guard let modelContext else { return }
        modelContext.delete(memo)
        try? modelContext.save()
        fetchMemos()
    }

    func togglePin(_ memo: Memo) {
        memo.isPinned.toggle()
        memo.updatedAt = Date()
        try? modelContext?.save()
        fetchMemos()
    }
}
