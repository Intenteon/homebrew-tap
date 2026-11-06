cask "snipdash" do
  version "1.2.1"
  sha256 "805d31c15e367e06cbb1e2fc14c36598df8f36515b1bee9774811faa0b55fa28"

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
