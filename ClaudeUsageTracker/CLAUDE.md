# Claude Usage Tracker

## 기능 명세

- macOS 상단 메뉴바에 Claude AI 사용량 한도를 실시간 표시 (예: `5h: 42%`)
- Claude Desktop 설정 화면과 동일한 데이터 (5시간 세션, 7일 주간 한도)
- 표시 항목: 5시간 세션 / 7일 전체 모델 / 7일 Sonnet / 7일 Opus 중 선택
- 좌클릭: 팝오버 대시보드 (애니메이션 진행 바)
- 우클릭: 컨텍스트 메뉴 (새로고침, 설정, 로그아웃, 종료)
- 연결 방식 아이콘 표시 (터미널/키 아이콘 + 계정 이메일)
- 로그인 시 자동 실행 (SMAppService)
- 영어/한국어 앱 내 언어 선택 (Localizable.strings, AppleLanguages)

## 인증 방식

- **Claude Code 자동 연결**: macOS Keychain의 `Claude Code-credentials`에서 OAuth 토큰 자동 읽기
- **파일 폴백**: `~/.claude/.credentials.json`에서 `claudeAiOauth.accessToken` 읽기
- **Session Key**: claude.ai 쿠키의 `sessionKey` 값 직접 입력 (형식 검증: `sk-ant-sid01-` 접두어)

## API

- `GET https://claude.ai/api/organizations` — 조직 ID 조회
- `GET https://claude.ai/api/organizations/{orgId}/usage` — 사용량 조회 (orgId는 URL 퍼센트 인코딩)
  - 응답: `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet` (각각 `utilization`, `resets_at`)
- **OAuth 폴백**: `POST https://api.anthropic.com/v1/messages` 헤더에서 `anthropic-ratelimit-unified-5h/7d-utilization` 읽기

## 보안

- App Sandbox 비활성화 (다른 앱의 Keychain 항목 및 자격증명 파일 접근 필요)
- Keychain 저장: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- HTTP 헤더 인젝션 방지: Session Key, OAuth 토큰에 CR/LF/NULL 검증 (`sanitizeHeaderValue`)
- 에러 응답 새니타이징: 서버 응답 본문을 사용자에게 노출하지 않음 (`sanitizedErrorMessage`)
- User-Agent: `ClaudeUsageTracker/{버전}` (Bundle에서 동적 읽기)
- 전용 URLSession: TLS 1.2~1.3 명시 적용
- CI: Hardened Runtime 활성화 (`ENABLE_HARDENED_RUNTIME=YES`)
- Session Key 입력 검증 + 로그인 2초 쿨다운
- refreshInterval 화이트리스트 검증 (60/300/900초만 허용)

## 기술 스택

- SwiftUI + NSStatusItem / NSPopover (macOS 13+)
- Security.framework (Keychain)
- ServiceManagement (Launch at Login)
- URLSession (HTTP, TLS 1.2+)
- NotificationCenter (뷰 ↔ AppDelegate 통신)

## 프로젝트 구조

- `ClaudeUsageTracker.swift` — @main 앱 진입점 (NSApplicationDelegateAdaptor)
- `AppDelegate.swift` — NSStatusItem, NSPopover, 우클릭 NSMenu, 설정 NSWindow 관리
- `Models/TokenUsage.swift` — UsageData, UsageLimit
- `Models/UserSettings.swift` — 표시 모드, 새로고침 간격, 로그인 시 자동 실행 (UserDefaults + SMAppService)
- `Services/KeychainService.swift` — Keychain CRUD + Claude Code 인증 읽기 + 입력 검증
- `Services/AnthropicAPIService.swift` — claude.ai API 호출 + 파싱 + 헤더 새니타이징
- `ViewModels/AppViewModel.swift` — 상태 관리, 자동 새로고침 타이머, 에러 정제
- `Views/LoginView.swift` — 로그인 화면 (로딩 피드백, Enter 제출, 쿨다운)
- `Views/MenuBarPopoverView.swift` — 사용량 대시보드 (애니메이션 진행 바, 연결 방식 표시)
- `Views/SettingsView.swift` — 설정 창 (표시 모드, 간격, 자동 실행)
