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

The layout is flat, with no letter shards. Every change arrives as a pull request: an app's release
workflow opens one per release, and the owner opens withdrawals and onboarding. The `tap-ci` check
(`brew style` plus `brew audit --strict --online`) must pass before any of them merges. It also
fails closed on any path, change type or mode the allowlist does not allow, and on any cask whose
`brew info --cask --json=v2 --variations` shows an unpinned `sha256`, `version :latest`, or an
artifact other than `app` (plus `zap`/`uninstall` with only `quit`, `delete`, `trash`). The rules
are in `scripts/tap-check.sh`; `tests/run-fixtures.sh` pins them, and `tap-ci` fails unless that
fixture test passes.

Formulas get no structural check: `brew audit` and the owner's review of the diff are the only
gates on a formula.

## Merging

`tap-ci` runs the workflow from the PR's own branch, so a green check is only evidence when nothing
in the PR could have changed the check.

- A green `tap-ci` counts on its own ONLY for a PR opened by an app's release workflow (the GitHub
  App) from a `release/<token>-<version>` branch, whose diff is exactly one `Casks/<token>.rb` or
  `Formula/<name>.rb`.
- Every other PR (opened by a person, from a fork, a withdrawal, onboarding, or anything touching
  `.github/`, `scripts/` or `tests/`) needs the app owner to review the diff by hand before
  merging. When the PR changes `.github/workflows/`, `scripts/` or `tests/`, read that diff
  itself: the green check came from that code.
- Known residual (tracked follow-up): because `pull_request` runs the PR's own copy of the workflow
  and of `scripts/tap-check.sh`, `tap-ci` cannot grade a PR that changes the check itself.

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
