cask "snipdash" do
  version "1.3"
  sha256 "66a49724748d6a9c6d0d5095fd141b76b4f0015bcc1717a38a6d2adddeafb162"

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

  caveats <<~EOS
    zap also removes the App Store build's library, since both share the container.
  EOS
end
