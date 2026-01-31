import SwiftUI

struct SettingsView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var newUsername = ""
    @State private var newToken = ""
    @State private var isAddingAccount = false
    @State private var errorMessage: String?
    @State private var isValidating = false
    @State private var newBlockedUser = ""

    @Environment(\.dismiss) private var dismiss
    var onSave: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                // Accounts section
                Section {
                    ForEach(accountManager.accounts) { account in
                        AccountRowView(
                            account: account,
                            onToggle: { accountManager.toggleAccount(account) },
                            onDelete: { accountManager.removeAccount(account) }
                        )
                    }

                    if isAddingAccount {
                        AddAccountView(
                            username: $newUsername,
                            token: $newToken,
                            isValidating: isValidating,
                            onSave: addAccount,
                            onCancel: { isAddingAccount = false }
                        )
                    } else if accountManager.canAddMoreAccounts {
                        Button {
                            isAddingAccount = true
                            newUsername = ""
                            newToken = ""
                        } label: {
                            Label("Add Account", systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("GitHub Accounts (\(accountManager.accounts.count)/\(AccountManager.maxAccounts))")
                } footer: {
                    Text("Add up to \(AccountManager.maxAccounts) accounts to see PRs from different organizations.")
                        .font(.caption)
                }

                // Notifications section
                Section {
                    Toggle("Play notification sound", isOn: Binding(
                        get: { accountManager.soundEnabled },
                        set: { accountManager.setSoundEnabled($0) }
                    ))
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Plays a sound when new commits or comments are detected (not by you)")
                        .font(.caption)
                }

                // Blocked users section
                Section {
                    ForEach(accountManager.blockedUsernames, id: \.self) { username in
                        HStack {
                            Text(username)
                            Spacer()
                            Button {
                                accountManager.removeBlockedUser(username)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Username to block", text: $newBlockedUser)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        Button {
                            accountManager.addBlockedUser(newBlockedUser)
                            newBlockedUser = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(newBlockedUser.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Blocked Users")
                } footer: {
                    Text("No notifications from these users")
                        .font(.caption)
                }

                // Token help
                Section {
                    Link(destination: URL(string: "https://github.com/settings/tokens")!) {
                        Label("Create GitHub Token", systemImage: "link")
                    }
                } footer: {
                    Text("Required scope: repo (full control of private repositories)")
                        .font(.caption)
                }

                // Clear all
                if !accountManager.accounts.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            accountManager.clearAll()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Remove All Accounts")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave?()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func addAccount() {
        guard !newUsername.isEmpty, !newToken.isEmpty else {
            errorMessage = "Username and token are required"
            return
        }

        isValidating = true

        Task {
            do {
                // Validate token by fetching user info
                let api = GitHubAPI(token: newToken)
                let fetchedUsername = try await api.validateToken()

                // Use the fetched username if it differs
                let finalUsername = fetchedUsername.isEmpty ? newUsername : fetchedUsername

                try accountManager.addAccount(username: finalUsername, token: newToken)

                await MainActor.run {
                    isValidating = false
                    isAddingAccount = false
                    newUsername = ""
                    newToken = ""
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct AccountRowView: View {
    let account: GitHubAccount
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: account.isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(account.isActive ? .green : .secondary)
                .onTapGesture { onToggle() }

            VStack(alignment: .leading) {
                Text(account.username)
                    .font(.body)
                Text(account.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct AddAccountView: View {
    @Binding var username: String
    @Binding var token: String
    let isValidating: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("GitHub Username", text: $username)
                .textContentType(.username)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            SecureField("Personal Access Token", text: $token)
                .textContentType(.password)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.secondary)

                Spacer()

                if isValidating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Add") {
                        onSave()
                    }
                    .disabled(username.isEmpty || token.isEmpty)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView()
}
