import SwiftUI
import SwiftData

struct MemoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(GitHubAccount.self) private var gitHubAccount
    @Environment(SyncService.self) private var syncService

    let memo: Memo
    @State private var viewModel = MemoDetailViewModel()
    @State private var showLabelPicker = false
    @State private var selectedLabelIDs: [UUID] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("タイトル", text: $viewModel.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Divider()

                    if gitHubAccount.isLinked {
                        labelsSection
                        Divider()
                    }

                    TextEditor(text: $viewModel.body)
                        .font(.body)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)

                    Divider()

                    statusSection

                    if gitHubAccount.isLinked {
                        syncStatusSection
                    }

                    metadataSection

                    if gitHubAccount.isLinked, memo.githubIssueURL != nil {
                        gitHubLinkSection
                    }
                }
                .padding()
            }
            AdBannerView()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setMemo(memo, context: modelContext)
            selectedLabelIDs = memo.labelIDs
        }
        .onDisappear {
            saveMemo()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                saveMemo()
            }
        }
        .sheet(isPresented: $showLabelPicker) {
            LabelPickerSheet(selectedLabelIDs: $selectedLabelIDs)
                .presentationDetents([.medium])
                .onChange(of: selectedLabelIDs) { _, newValue in
                    memo.labelIDs = newValue
                    try? modelContext.save()
                }
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ラベル")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showLabelPicker = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
            }

            if !selectedLabelIDs.isEmpty {
                labelTagsView
            }
        }
    }

    private var labelTagsView: some View {
        FlowLayout(spacing: 6) {
            ForEach(labelsForDisplay, id: \.id) { label in
                Text(label.name)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: label.color).opacity(0.2))
                    .foregroundStyle(Color(hex: label.color))
                    .clipShape(Capsule())
            }
        }
    }

    private var labelsForDisplay: [Label] {
        let descriptor = FetchDescriptor<Label>()
        guard let allLabels = try? modelContext.fetch(descriptor) else { return [] }
        return allLabels.filter { selectedLabelIDs.contains($0.id) }
    }

    private var statusSection: some View {
        HStack {
            Text("ステータス")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.toggleStatus()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.status == .open ? "circle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                    Text(viewModel.status == .open ? "オープン" : "クローズ")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(viewModel.status == .open ? Color.green : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (viewModel.status == .open ? Color.green : Color.secondary)
                        .opacity(0.12)
                )
                .clipShape(Capsule())
            }
        }
    }

    private var syncStatusSection: some View {
        Group {
            if memo.syncStatus == .failed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(memo.syncError ?? "同期に失敗しました")
                        .font(.caption2)
                        .foregroundStyle(.red)

                    Spacer()

                    Button {
                        retrySyncMemo()
                    } label: {
                        Text("再送")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if memo.syncStatus == .pending {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("同期中...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("作成日時")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("更新日時")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(memo.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var gitHubLinkSection: some View {
        Button {
            if let urlString = memo.githubIssueURL,
               let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: "arrow.up.right")
                Text("GitHubで開く")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func saveMemo() {
        viewModel.save()

        guard gitHubAccount.isLinked, gitHubAccount.hasRepository else { return }

        Task {
            await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
        }
    }

    private func retrySyncMemo() {
        Task {
            await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
