cask "snipdash" do
  version "1.4"
  sha256 "2cf610e8932244c9ab5197384ce784fd8e5852201df1ac06741054aa8fdb094f"

  url "https://downloads.intenteon.com/snipdash/SnipDash-#{version}.zip"
  name "SnipDash"
  desc "Menu bar text snippets with global keyboard shortcuts"
  homepage "https://intenteon.com/solutions/snipdash/"

  livecheck do
    skip "Updates through its signed Sparkle feed"
  end

  auto_updates true
  depends_on macos: :ventura

  app "SnipDash.app"

  zap trash: [
    "~/Library/Containers/com.intenteon.snipdash",
    "~/Library/Preferences/com.intenteon.snipdash.plist",
  ]
end
