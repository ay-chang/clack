# Homebrew cask for Clack.
#
# Copy this file into a tap repository named `homebrew-tap` (so users can run
# `brew install --cask ay-chang/tap/clack`), updating `version` and
# `sha256` from each GitHub release. Once the project meets homebrew-cask's
# notability requirements it can be submitted to the main cask repository and
# the tap prefix drops away.
cask "clack" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/ay-chang/clack/releases/download/v#{version}/Clack-#{version}.dmg",
      verified: "github.com/ay-chang/clack/"
  name "Clack"
  desc "Menu bar keystroke counter"
  homepage "https://github.com/ay-chang/clack"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Clack.app"

  zap trash: [
    "~/Library/Application Support/Clack",
    "~/Library/Preferences/com.allenchang.clack.plist",
  ]
end
