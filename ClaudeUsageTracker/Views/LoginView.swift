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

            Text("Claude 사용량을 상단바에 표시합니다.")
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
                    Text("Claude Code에서 자동 연결")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoginInProgress)

            Text("또는")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Session key
            if showSessionInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("sk-ant-sid01-...", text: $sessionKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitSessionKey() }

                    Text("claude.ai > 개발자 도구 > Cookies > sessionKey")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Login") {
                        submitSessionKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoginInProgress)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button("Session Key로 로그인") {
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
            viewModel.errorMessage = "올바른 Session Key 형식이 아닙니다.\nsk-ant-sid01-로 시작하는 값을 입력해주세요."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoginInProgress = false
        }
    }
}
