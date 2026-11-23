cask "snipdash" do
  version "1.4.1"
  sha256 "d6a86ac842baeb046ad06be21a45ed350597208efe3500756516f35e474c18b4"

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
