import Foundation
import SwiftData
import Observation
import os

private let logger = Logger(subsystem: "com.iwakisyogo.QuickMemo", category: "InputViewModel")

@MainActor
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
        logger.notice("save() called - hasSaved: \(self.hasSaved), title: '\(self.title)', modelContext: \(self.modelContext != nil)")
        guard !hasSaved else { logger.notice("save() skipped: already saved"); return }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { logger.notice("save() skipped: title is empty"); return }
        guard let modelContext else { logger.error("save() skipped: modelContext is nil"); return }

        let memo = Memo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.isEmpty ? nil : body
        )
        modelContext.insert(memo)
        do {
            try modelContext.save()
            logger.notice("save() SUCCESS - memo id: \(memo.id), title: '\(memo.title)'")
        } catch {
            logger.error("Failed to save new memo: \(error)")
        }
        savedMemo = memo
        hasSaved = true
    }
}
