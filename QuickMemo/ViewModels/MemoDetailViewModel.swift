import Foundation
import SwiftData
import Observation

@Observable
class MemoDetailViewModel {
    var title: String = ""
    var body: String = ""
    var status: MemoStatus = .open

    private var memo: Memo?
    private var modelContext: ModelContext?

    func setMemo(_ memo: Memo, context: ModelContext) {
        self.memo = memo
        self.modelContext = context
        self.title = memo.title
        self.body = memo.body ?? ""
        self.status = memo.status
    }

    func save() {
        guard let memo else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        var changed = false

        if memo.title != trimmedTitle {
            memo.title = trimmedTitle
            changed = true
        }

        let newBody = body.isEmpty ? nil : body
        if memo.body != newBody {
            memo.body = newBody
            changed = true
        }

        if memo.status != status {
            memo.status = status
            changed = true
        }

        if changed {
            memo.updatedAt = Date()
            do {
                try modelContext?.save()
            } catch {
                print("[QuickMemo] Failed to save memo detail: \(error)")
            }
        }
    }

    func toggleStatus() {
        status = (status == .open) ? .closed : .open
    }
}
