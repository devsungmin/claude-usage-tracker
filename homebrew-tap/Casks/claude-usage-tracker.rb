cask "claude-usage-tracker" do
  version :latest
  sha256 :no_check

  url "https://github.com/devsungmin/claude-usage-tracker/releases/latest/download/ClaudeUsageTracker-latest.zip"
  name "Claude Usage Tracker"
  desc "Real-time Claude AI usage monitor for the macOS menu bar"
  homepage "https://github.com/devsungmin/claude-usage-tracker"

  depends_on macos: ">= :ventura"

  app "ClaudeUsageTracker.app"

  zap trash: [
    "~/Library/Preferences/dev.sungmin.ClaudeUsageTracker.plist",
  ]
end
