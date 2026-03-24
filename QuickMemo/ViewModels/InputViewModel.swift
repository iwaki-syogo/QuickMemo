import Foundation
import SwiftData
import Observation

@Observable
class InputViewModel {
    var title: String = ""
    var body: String = ""

    private var modelContext: ModelContext?
    private var hasSaved = false
    private(set) var savedMemo: Memo?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func save() {
        guard !hasSaved else { return }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let modelContext else { return }

        let memo = Memo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.isEmpty ? nil : body
        )
        modelContext.insert(memo)
        do {
            try modelContext.save()
        } catch {
            print("[QuickMemo] Failed to save new memo: \(error)")
        }
        savedMemo = memo
        hasSaved = true
    }
}
