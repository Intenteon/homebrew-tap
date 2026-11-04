# homebrew-tap

The Homebrew tap for Intenteon apps.

```sh
brew tap intenteon/tap
brew install --cask intenteon/tap/<token>   # macOS apps (casks)
brew install intenteon/tap/<name>           # command-line tools (formulas)
```

You can also skip `brew tap` and use the fully qualified name, for example
`brew install --cask intenteon/tap/snipdash`.

## Layout

| path | holds |
|---|---|
| `Casks/<token>.rb` | notarized Developer ID `.app` zips |
| `Formula/<name>.rb` | CLIs |

The layout is flat, with no letter shards. Every change arrives as a pull request opened by an app's
release workflow, and the `tap-ci` check (`brew style` plus `brew audit --strict --online`) must
pass before it merges.

## Standard

The rules for this tap are in
[Intenteon/infrastructure `docs/cicd/HOMEBREW-TAP-STANDARD.md`](https://github.com/Intenteon/infrastructure/blob/main/docs/cicd/HOMEBREW-TAP-STANDARD.md).
They cover pinned `sha256` values, versioned URLs, the notarization checks, the publish path, tap
protection, withdrawal and onboarding.

## Owners

Each app's owner merges that app's tap PRs and withdraws its cask when a release is pulled.

| token | kind | owner (workspace) | status |
|---|---|---|---|
| `snipdash` | cask | snipdash | pending: first cask lands with Intenteon/snipdash#203 |
