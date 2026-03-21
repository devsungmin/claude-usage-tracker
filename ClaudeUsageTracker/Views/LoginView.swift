import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var sessionKey = ""
    @State private var showSessionInput = false
    @State private var isLoginInProgress = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text("Claude Usage Tracker")
                .font(.headline)

            Text("login.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Claude Code auto-connect
            Button(action: {
                isLoginInProgress = true
                viewModel.connectClaudeCode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoginInProgress = false
                }
            }) {
                HStack {
                    if isLoginInProgress && !showSessionInput {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "terminal.fill")
                    }
                    Text("login.claude_code_connect")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoginInProgress)

            Text("login.or")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Session key
            if showSessionInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("login.session_key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("sk-ant-sid01-...", text: $sessionKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitSessionKey() }

                    Text("login.session_key_hint")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("login.login_button") {
                        submitSessionKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoginInProgress)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button("login.session_key_login") {
                    showSessionInput = true
                }
                .buttonStyle(.bordered)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func submitSessionKey() {
        isLoginInProgress = true
        let trimmed = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainService.isValidSessionKeyFormat(trimmed) {
            viewModel.loginWithSessionKey(trimmed)
        } else {
            viewModel.errorMessage = String(localized: "login.invalid_session_key")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoginInProgress = false
        }
    }
}
