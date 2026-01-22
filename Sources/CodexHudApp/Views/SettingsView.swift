import SwiftUI
import CodexHudCore

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var drafts: [AccountDraft] = []
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accounts")
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            GlassCard {
                VStack(spacing: 10) {
                    ForEach($drafts) { $draft in
                        HStack(spacing: 12) {
                            Text("Codex \(draft.codexNumber)")
                                .frame(width: 70, alignment: .leading)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            TextField("Email", text: $draft.email)
                                .textFieldStyle(.roundedBorder)
                            TextField("Display name", text: $draft.displayName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Save") {
                    save()
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(!isValid)

                if let message {
                    Text(message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }

                Spacer()
            }

            GlassDivider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnostics")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if let path = viewModel.storagePath() {
                    Text("Storage: \(path)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                if let lastRefresh = viewModel.state.lastRefresh {
                    Text("Last refresh: \(formatDate(lastRefresh))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                if let source = viewModel.lastRefreshSource {
                    Text("Last source: \(source.rawValue)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620)
        .background(Theme.background)
        .onAppear { loadDrafts() }
    }

    private var isValid: Bool {
        let emails = drafts.map { $0.email.trimmingCharacters(in: .whitespaces) }
        guard emails.allSatisfy({ !$0.isEmpty }) else { return false }
        let unique = Set(emails)
        return unique.count == emails.count
    }

    private func loadDrafts() {
        if !drafts.isEmpty { return }
        if viewModel.state.accounts.count == 5 {
            drafts = viewModel.state.accounts.map { AccountDraft(from: $0) }
        } else {
            drafts = (2...6).map { AccountDraft(codexNumber: $0, email: "", displayName: "") }
        }
    }

    private func save() {
        guard isValid else {
            message = "Please set all emails and ensure they are unique."
            return
        }
        let accounts = drafts.map { $0.toAccountRecord() }
        viewModel.saveAccounts(accounts)
        message = "Saved"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct AccountDraft: Identifiable {
    let id = UUID()
    let codexNumber: Int
    var email: String
    var displayName: String

    init(codexNumber: Int, email: String, displayName: String) {
        self.codexNumber = codexNumber
        self.email = email
        self.displayName = displayName
    }

    init(from record: AccountRecord) {
        self.codexNumber = record.codexNumber
        self.email = record.email
        self.displayName = record.displayName ?? ""
    }

    func toAccountRecord() -> AccountRecord {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        return AccountRecord(
            codexNumber: codexNumber,
            email: email.trimmingCharacters(in: .whitespaces),
            displayName: trimmedName.isEmpty ? nil : trimmedName,
            lastSnapshot: nil,
            lastUpdated: nil
        )
    }
}
