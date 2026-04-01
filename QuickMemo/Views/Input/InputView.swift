import SwiftUI
import SwiftData

struct InputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(GitHubAccount.self) private var gitHubAccount
    @Environment(SyncService.self) private var syncService

    @State private var viewModel = InputViewModel()
    @State private var hasSynced = false
    @State private var showLabelPicker = false
    @State private var showRepositoryPicker = false
    @FocusState private var isTitleFocused: Bool
    @Query(sort: \QuickMemo.Label.name) private var allLabels: [QuickMemo.Label]

    var body: some View {
        VStack(spacing: 0) {
            TextField("タイトル", text: $viewModel.title, axis: .vertical)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .focused($isTitleFocused)

            Divider()
                .padding(.horizontal)

            TextEditor(text: $viewModel.body)
                .font(.body)
                .frame(minHeight: 80)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .scrollContentBackground(.hidden)

            if gitHubAccount.isLinked {
                Divider()
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    // Repository picker
                    Button {
                        showRepositoryPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            if let owner = viewModel.repositoryOwner, let repo = viewModel.repositoryName {
                                Text("\(owner)/\(repo)")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("リポジトリを選択")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // Label picker
                    Button {
                        showLabelPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            if viewModel.selectedLabelIDs.isEmpty {
                                Text("ラベルを追加")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(selectedLabels, id: \.id) { label in
                                            Text(label.name)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: label.color).opacity(0.2))
                                                .foregroundStyle(Color(hex: label.color))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("新規メモ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完了") {
                    viewModel.save()
                    syncNewMemo()
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.setDefaults(from: gitHubAccount)
            isTitleFocused = true
        }
        .onDisappear {
            viewModel.save()
            syncNewMemo()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.save()
                syncNewMemo()
            }
        }
        .sheet(isPresented: $showLabelPicker) {
            LabelPickerSheet(selectedLabelIDs: $viewModel.selectedLabelIDs)
        }
        .sheet(isPresented: $showRepositoryPicker) {
            InputRepositoryPickerView(
                selectedOwner: $viewModel.repositoryOwner,
                selectedName: $viewModel.repositoryName
            )
        }
    }

    private var selectedLabels: [QuickMemo.Label] {
        allLabels.filter { viewModel.selectedLabelIDs.contains($0.id) }
    }

    private func syncNewMemo() {
        guard !hasSynced else { return }
        guard let memo = viewModel.savedMemo,
              gitHubAccount.isLinked, gitHubAccount.hasRepository else { return }

        hasSynced = true
        Task {
            await syncService.syncMemo(memo, account: gitHubAccount, context: modelContext)
        }
    }
}
