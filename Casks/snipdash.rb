cask "snipdash" do
  version "1.2"
  sha256 "39960ad45cd0e41ab4a3f278a1a88d64f1fa2d8b9b8608acfdfd338e37d1bfc6"

  url "https://downloads.intenteon.com/snipdash/SnipDash-#{version}.zip"
  name "SnipDash"
  desc "Menu bar text snippets with global keyboard shortcuts"
  homepage "https://intenteon.com/solutions/snipdash/"

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
