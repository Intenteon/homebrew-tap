#!/usr/bin/env bash
# Tap CI checks, called by .github/workflows/tap-ci.yml and pinned by tests/run-fixtures.sh.
#
#   tap-check.sh classify-paths < raw-diff
#       stdin: `git diff --raw -z --no-renames --no-abbrev <base> <head>` (status AND modes).
#       stdout: one `cask <token>` or `formula <name>` line per added or modified file to audit.
#   tap-check.sh check-cask-json <file>
#       <file>: `brew info --cask --json=v2 --variations <tap/token>` output for exactly one cask.
#   tap-check.sh check-pragmas <file>...
#       refuses any `rubocop:disable` / `rubocop:todo` comment, so `brew style` cannot be turned off.
#
# Exit codes: 0 accepted, 1 refused (one `::error::REFUSE <code>: ...` line per refusal on stderr),
# 2 usage error. Refusal codes are a contract: the fixture test asserts them by name.
set -euo pipefail

refused=0
refuse() { # refuse <code> <detail>; %q keeps a hostile file name from forming a workflow command.
  printf '::error::REFUSE %s: %q\n' "$1" "$2" >&2
  refused=1
}

usage() {
  echo "usage: tap-check.sh classify-paths < raw-diff | check-cask-json <file> | check-pragmas <file>..." >&2
  exit 2
}

# Lower-cased shapes of every allowlisted path. A path that is not allowlisted but matches one of
# these is a case variant of a listed path (casks/x.rb, Casks/X.rb, README.MD).
is_case_variant() {
  local p="${1,,}"
  [[ "${p}" =~ ^casks/[^/]+\.rb$ || "${p}" =~ ^formula/[^/]+\.rb$ || "${p}" == casks/.keep ||
    "${p}" == formula/.keep || "${p}" == readme.md || "${p}" =~ ^\.github/workflows/[^/]+\.yml$ ||
    "${p}" == scripts/tap-check.sh || "${p}" == scripts/check_cask_json.py || "${p}" == tests/run-fixtures.sh || "${p}" =~ ^tests/fixtures/ ]]
}

classify_paths() {
  local meta='' path old new st gate=0 content=0
  local -a out=()
  # --raw -z record: ":<old mode> <new mode> <old sha> <new sha> <status>\0<path>\0".
  while IFS= read -r -d '' meta
  do
    if ! IFS= read -r -d '' path
    then
      refuse malformed-input "record without a path: ${meta}"
      meta=''
      break
    fi
    if [[ ! "${meta}" =~ ^:([0-7]{6})\ ([0-7]{6})\ [0-9a-f]+\ [0-9a-f]+\ ([A-Z])$ ]]
    then
      refuse malformed-input "${meta}"
      continue
    fi
    old="${BASH_REMATCH[1]}" new="${BASH_REMATCH[2]}" st="${BASH_REMATCH[3]}"
    case "${st}" in
      A | M | D) ;;
      *)
        refuse unsupported-status "${st} ${path}"
        continue
        ;;
    esac
    if [[ "${old}" = 120000 ]] || [[ "${new}" = 120000 ]]
    then
      refuse symlink "${path}"
      continue
    fi
    if [[ ! "${old}" =~ ^(000000|100644|100755)$ || ! "${new}" =~ ^(000000|100644|100755)$ ]]
    then
      refuse bad-mode "${old} ${new} ${path}"
      continue
    fi
    # shellcheck disable=SC2310 # is_case_variant is a pure test; set -e is moot inside it.
    if [[ "${path}" =~ ^Casks/([a-z0-9][a-z0-9@._+-]*)\.rb$ ]]
    then
      content=1
      [[ "${st}" = D ]] || out+=("cask ${BASH_REMATCH[1]}") # D is a withdrawal: nothing to audit
    elif [[ "${path}" =~ ^Formula/([a-z0-9][a-z0-9@._+-]*)\.rb$ ]]
    then
      content=1
      [[ "${st}" = D ]] || out+=("formula ${BASH_REMATCH[1]}")
    elif [[ "${path}" == Casks/.keep || "${path}" == Formula/.keep ]]
    then
      # Without Formula/ (or Casks/) brew reads the tap root as that directory, outside this audit.
      [[ "${st}" = A ]] || refuse keep-file-change "${st} ${path}"
    elif [[ "${path}" == README.md ]]
    then
      :
    elif [[ "${path}" =~ ^\.github/workflows/[^/]+\.yml$ || "${path}" == scripts/tap-check.sh ||
            "${path}" == scripts/check_cask_json.py ||
            "${path}" == tests/run-fixtures.sh || "${path}" =~ ^tests/fixtures/(paths|cask-json|pragmas)/[A-Za-z0-9._-]+$ ]]
    then
      gate=1 # the check itself, its tests, or its fixtures
    elif is_case_variant "${path}"
    then
      refuse case-variant "${path}"
    else
      refuse unlisted-path "${path}"
    fi
  done
  # read returns non-zero at EOF; anything left in meta was not NUL-terminated.
  [[ -z "${meta}" ]] || refuse malformed-input "trailing bytes without a NUL terminator"
  # Under pull_request the PR's own copy of the workflow and of this script runs, so a PR may change
  # the gate or the content it gates, never both.
  if [[ "${gate}" -eq 1 ]] && [[ "${content}" -eq 1 ]]
  then
    refuse gate-and-content "a PR changes the check and a cask or formula; open them separately"
  fi
  [[ "${refused}" -eq 0 ]] || return 1
  [[ "${#out[@]}" -eq 0 ]] || printf '%s\n' "${out[@]}"
}

check_cask_json() {
  [[ "$#" -eq 1 ]] || usage
  local findings
  findings="$(python3 -I "$(dirname "$0")/check_cask_json.py" "$1")" || {
    refuse checker-failed "$1"
    return 1
  }
  local code where
  while read -r code where
  do
    [[ -n "${code}" ]] && refuse "${code}" "${where}"
  done <<<"${findings}"
  [[ "${refused}" -eq 0 ]]
}

check_pragmas() {
  [[ "$#" -ge 1 ]] || usage
  local f rc
  for f in "$@"
  do
    rc=0
    grep -Eiq 'rubocop[[:space:]]*:[[:space:]]*(disable|todo)' -- "${f}" || rc=$?
    case "${rc}" in
      0) refuse rubocop-disable "${f}" ;;
      1) ;;
      *) refuse checker-failed "${f}" ;;
    esac
  done
  [[ "${refused}" -eq 0 ]]
}

[[ "$#" -ge 1 ]] || usage
cmd="$1"
shift
case "${cmd}" in
  classify-paths)
    [[ "$#" -eq 0 ]] || usage
    classify_paths
    ;;
  check-cask-json) check_cask_json "$@" ;;
  check-pragmas) check_pragmas "$@" ;;
  *) usage ;;
esac
