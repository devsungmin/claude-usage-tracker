import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.authState {
            case .loggedOut:
                LoginView()
            case .loggedIn:
                UsageDashboardView()
            }
        }
    }
}

struct UsageDashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            headerSection
            Divider()
            usageLimitsSection
            Divider()
            footerSection
        }
        .padding(16)
        .frame(width: 320)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("dashboard.usage_limits")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task { await viewModel.refreshUsage() }
                }) {
                    ZStack {
                        Color.clear.frame(width: 16, height: 16)

                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
                .help(String(localized: "dashboard.refresh"))
            }
            HStack(spacing: 4) {
                Image(systemName: viewModel.authMethod == .claudeCode ? "terminal.fill" : "key.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let account = viewModel.accountInfo {
                    Text(account)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(viewModel.authMethod == .claudeCode ? "Claude Code" : "Session Key")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var usageLimitsSection: some View {
        VStack(spacing: 14) {
            UsageLimitRow(
                title: String(localized: "dashboard.current_session"),
                subtitle: String(localized: "dashboard.five_hour_window"),
                limit: viewModel.usage.fiveHour,
                color: .blue
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("dashboard.weekly_limits")
                    .font(.subheadline)
                    .fontWeight(.medium)

                UsageLimitRow(
                    title: String(localized: "dashboard.all_models"),
                    subtitle: nil,
                    limit: viewModel.usage.sevenDay,
                    color: .orange
                )

                UsageLimitRow(
                    title: "Opus",
                    subtitle: nil,
                    limit: viewModel.usage.sevenDayOpus,
                    color: .purple
                )

                UsageLimitRow(
                    title: "Sonnet",
                    subtitle: nil,
                    limit: viewModel.usage.sevenDaySonnet,
                    color: .green
                )
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            if let error = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("\(String(localized: "dashboard.last_updated")) \(viewModel.usage.formattedLastUpdated)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "dashboard.settings"))

                Button("Logout") {
                    viewModel.logout()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.red)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Text("v\(Bundle.main.appVersion)")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct UsageLimitRow: View {
    let title: String
    let subtitle: String?
    let limit: UsageLimit
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.caption)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text("\(limit.formattedPercent) \(String(localized: "dashboard.used"))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(geometry.size.width * limit.effectivePercent / 100, 2), height: 6)
                        .animation(.easeInOut(duration: 0.4), value: limit.effectivePercent)
                }
            }
            .frame(height: 6)

            Text(limit.formattedResetTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var barColor: Color {
        if limit.effectivePercent >= 80 {
            return .red
        } else if limit.effectivePercent >= 50 {
            return .yellow
        }
        return color
    }
}
