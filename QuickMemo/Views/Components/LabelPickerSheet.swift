import SwiftUI
import SwiftData

struct LabelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(GitHubAccount.self) private var gitHubAccount

    @Binding var selectedLabelIDs: [UUID]
    @State private var githubLabels: [GitHubLabel] = []
    @State private var localLabels: [Label] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if localLabels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("ラベルがありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(sortedLabels, id: \.id) { label in
                        Button {
                            toggleLabel(label)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: label.color))
                                    .frame(width: 12, height: 12)

                                Text(label.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedLabelIDs.contains(label.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("ラベル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            fetchLabels()
        }
    }

    private var sortedLabels: [Label] {
        localLabels.sorted { a, b in
            let aUsed = a.lastUsedAt ?? .distantPast
            let bUsed = b.lastUsedAt ?? .distantPast
            return aUsed > bUsed
        }
    }

    private func toggleLabel(_ label: Label) {
        if let index = selectedLabelIDs.firstIndex(of: label.id) {
            selectedLabelIDs.remove(at: index)
        } else {
            selectedLabelIDs.append(label.id)
            label.lastUsedAt = Date()
            try? modelContext.save()
        }
    }

    private func fetchLabels() {
        guard gitHubAccount.hasRepository else { return }

        isLoading = true
        Task {
            do {
                let apiClient = GitHubAPIClient()
                let fetchedLabels = try await apiClient.fetchLabels(
                    owner: gitHubAccount.repositoryOwner,
                    repo: gitHubAccount.repositoryName
                )

                let descriptor = FetchDescriptor<Label>()
                let existingLabels = (try? modelContext.fetch(descriptor)) ?? []

                for ghLabel in fetchedLabels {
                    if let existing = existingLabels.first(where: { $0.githubID == ghLabel.id }) {
                        existing.name = ghLabel.name
                        existing.color = ghLabel.color
                    } else {
                        let newLabel = Label(
                            githubID: ghLabel.id,
                            name: ghLabel.name,
                            color: ghLabel.color
                        )
                        modelContext.insert(newLabel)
                    }
                }

                try? modelContext.save()
                localLabels = (try? modelContext.fetch(descriptor)) ?? []
            } catch {
                let descriptor = FetchDescriptor<Label>()
                localLabels = (try? modelContext.fetch(descriptor)) ?? []
            }
            isLoading = false
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
