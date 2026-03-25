# Claude Token Tracker

🇰🇷 [한국어 버전](README.ko.md)

A macOS menu bar app that displays your Claude AI usage limits in real time — the same data shown in Claude Desktop's settings, always visible at a glance.

[![Release](https://img.shields.io/github/v/release/devsungmin/claude-usage-tracker?style=flat-square)](https://github.com/devsungmin/claude-usage-tracker/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square)](https://github.com/devsungmin/claude-usage-tracker/releases/latest)

---

## Download

> **[📥 Download Latest Release](https://github.com/devsungmin/claude-usage-tracker/releases/latest)**

| File | Description |
|------|-------------|
| `ClaudeTokenTracker-vX.X.X.dmg` | DMG installer (drag to Applications) |
| `ClaudeTokenTracker-vX.X.X.zip` | Zipped .app bundle |

---

## Screenshot

| Claude Token Tracker | Claude Desktop Settings |
|:---:|:---:|
| ![App Popover](screenshots/app-popover.png) | ![Claude Desktop](screenshots/claude-desktop-compare.png) |

---

## Features

- 📊 **Real-time usage display** — shows one of four metrics in the menu bar (e.g. `5h: 42%`, `7d: 15%`):
  - 5-hour session usage %
  - 7-day weekly usage % (all models)
  - 7-day weekly usage % (Sonnet only)
  - 7-day weekly usage % (Opus only)
- 🔐 **Claude Code auto-connect** — reads OAuth credentials from macOS Keychain or `~/.claude/.credentials.json`
- 🔑 **Session Key login** — supports manual login via `claude.ai` session cookie (validated format: `sk-ant-sid01-`)
- 📈 **Popover dashboard** — left-click the menu bar icon to see all usage limits with animated, color-coded progress bars
- 🖱️ **Right-click menu** — quick access to Refresh, Settings, Logout, and Quit
- 🌐 **English / Korean** — in-app language selector (System Default, English, 한국어)
- ⚙️ **Configurable** — choose which metric to display, set refresh interval (1m / 5m / 15m), launch at login
- 🔒 **Secure** — credentials stored in macOS Keychain (`WhenUnlockedThisDeviceOnly`), input sanitization against header injection, error messages sanitized

---

## How It Works

### API

The app calls the same endpoint that the Claude Desktop app uses:

```
GET https://claude.ai/api/organizations/{orgId}/usage
```

Response:

```json
{
  "five_hour": { "utilization": 2.0, "resets_at": "2026-03-21T18:00:00Z" },
  "seven_day": { "utilization": 1.0, "resets_at": "2026-03-24T00:00:00Z" },
  "seven_day_opus": { "utilization": 0.0 },
  "seven_day_sonnet": { "utilization": 0.5, "resets_at": "2026-03-24T00:00:00Z" }
}
```

### OAuth Fallback

When the usage endpoint is unavailable (e.g., OAuth token limitations), the app falls back to reading rate-limit headers from the Messages API:

```
anthropic-ratelimit-unified-5h-utilization: 0.02
anthropic-ratelimit-unified-7d-utilization: 0.01
```

---

## Supported Plans

| Plan | Supported | Notes |
|------|-----------|-------|
| **Pro** | Yes | 5h session + 7d weekly limits |
| **Max** | Yes | Higher limits, same data format |
| **Team** | Yes | Organization-level limits |
| **Enterprise** | Yes | Custom limits |
| Free | No | Usage endpoint not available |
| API (pay-per-token) | No | Uses console.anthropic.com billing |

---

## Requirements

- macOS 13 Ventura or later
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) **or** a [claude.ai](https://claude.ai) account (Pro / Max / Team / Enterprise)

---

## Installation

### Homebrew (recommended)

```bash
brew install --cask devsungmin/tap/claude-token-tracker
```

### Download

1. Go to **[Releases](https://github.com/devsungmin/claude-usage-tracker/releases/latest)**
2. Download `ClaudeTokenTracker-vX.X.X.dmg`
3. Open the DMG and drag **Claude Token Tracker** to Applications
4. Launch from Applications — the app appears in the menu bar

### Build from source

```bash
git clone https://github.com/devsungmin/claude-usage-tracker.git
cd claude-usage-tracker
open ClaudeTokenTracker.xcodeproj
```

Then **⌘R** to build and run.

### macOS Gatekeeper notice

This app is not notarized by Apple. On first launch, macOS may block it. To open:

1. **System Settings** → **Privacy & Security**
2. Scroll down to find the blocked app message
3. Click **"Open Anyway"**

This only needs to be done once.

---

## Usage

### Option 1 — Claude Code (recommended)

If Claude Code is installed and logged in, click **"Claude Code에서 자동 연결"**. The app reads your OAuth token from the macOS Keychain or `~/.claude/.credentials.json` automatically.

### Option 2 — Session Key

1. Log in to [claude.ai](https://claude.ai) in your browser.
2. Open DevTools → Application → Cookies → `claude.ai`.
3. Copy the `sessionKey` value (starts with `sk-ant-sid01-`).
4. Paste it into the app and click **Login** (or press **Enter**).

---

## Project Structure

```text
ClaudeTokenTracker/
├── AppDelegate.swift              - NSStatusItem, NSPopover, right-click menu, settings window
├── ClaudeTokenTracker.swift       - @main app entry point
├── Models/
│   ├── TokenUsage.swift           - UsageData, UsageLimit (5h/7d/opus/sonnet)
│   └── UserSettings.swift         - Display mode, refresh interval, launch at login
├── Services/
│   ├── KeychainService.swift      - Keychain CRUD + Claude Code credential reader + input validation
│   └── AnthropicAPIService.swift  - claude.ai /usage API + OAuth fallback + header sanitization
├── ViewModels/
│   └── AppViewModel.swift         - State management, auto-refresh, error sanitization
└── Views/
    ├── LoginView.swift            - Auth screen (Claude Code + Session Key)
    ├── MenuBarPopoverView.swift   - Dashboard with animated progress bars
    └── SettingsView.swift         - Settings window (display mode, interval, launch at login)
```

---

## Tech Stack

- **SwiftUI** + **NSStatusItem** / **NSPopover** (macOS 13+)
- **Security.framework** — Keychain access
- **ServiceManagement** — Launch at Login
- **URLSession** — HTTP requests (TLS 1.2+ enforced)

---

## License

[MIT License](LICENSE)

---

> This project is not affiliated with or endorsed by Anthropic.
