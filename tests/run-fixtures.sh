#!/usr/bin/env bash
# Fixture test for scripts/tap-check.sh. Needs bash, git and python3; no brew.
#
#   tests/run-fixtures.sh            run every fixture, a live-git arm, and the positive control
#   tests/run-fixtures.sh <checker>  run the fixtures against <checker> only (used by the control)
#
# Each fixture has a .expect file: `exit=<code>`, optional `refuse=<code>` (that REFUSE code must be
# on stderr) and optional `stdout=<line>` (stdout must equal it exactly; `stdout=` means empty).
# A fixture with exit=0 must print no REFUSE line. A .raw paths fixture holds one NUL-separated
# field per line, exactly as `git diff --raw -z --no-renames --no-abbrev` emits them.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
fx="${root}/tests/fixtures"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
cases=0
fail() {
  printf 'FAIL %s: %s\n' "$1" "$2"
  failures=$((failures + 1))
}

# check_case <name> <expect file> <exit code> <stdout file> <stderr file>
check_case() {
  local name="$1" expect="$2" rc="$3" out="$4" err="$5" want_rc="" want_refuse="" want_out="" has_out=0 line
  cases=$((cases + 1))
  while IFS= read -r line
  do
    case "${line}" in
      exit=*) want_rc="${line#exit=}" ;;
      refuse=*) want_refuse="${line#refuse=}" ;;
      stdout=*)
        want_out="${line#stdout=}"
        has_out=1
        ;;
      *)
        # An unread line would silently drop an assertion.
        fail "${name}" "unknown line in ${expect}: ${line}"
        return
        ;;
    esac
  done <"${expect}"
  [[ -n "${want_rc}" ]] || {
    fail "${name}" "no exit= line in ${expect}"
    return
  }
  [[ "${rc}" = "${want_rc}" ]] || {
    fail "${name}" "exit ${rc}, want ${want_rc}; stderr: $(tr '\n' ' ' <"${err}" || true)"
    return
  }
  if [[ -n "${want_refuse}" ]]
  then
    grep -Fq -- "::error::REFUSE ${want_refuse}:" "${err}" || {
      fail "${name}" "no REFUSE ${want_refuse}; stderr: $(tr '\n' ' ' <"${err}" || true)"
      return
    }
  elif [[ "${want_rc}" = 0 ]] && grep -Fq -- "REFUSE" "${err}"
  then
    fail "${name}" "accepted but printed a refusal: $(tr '\n' ' ' <"${err}" || true)"
    return
  fi
  if [[ "${has_out}" -eq 1 ]] && [[ "$(<"${out}")" != "${want_out}" ]]
  then
    fail "${name}" "stdout '$(tr '\n' '|' <"${out}" || true)', want '${want_out}'"
    return
  fi
  printf 'ok   %s (exit %s%s)\n' "${name}" "${rc}" "${want_refuse:+, ${want_refuse}}"
}

run_fixtures() { # run_fixtures <checker>
  local chk="$1" f name rc
  for f in "${fx}"/paths/*.raw
  do
    name="paths/$(basename "${f}" .raw)"
    tr '\n' '\0' <"${f}" >"${work}/in"
    rc=0
    bash "${chk}" classify-paths <"${work}/in" >"${work}/out" 2>"${work}/err" || rc=$?
    check_case "${name}" "${f%.raw}.expect" "${rc}" "${work}/out" "${work}/err"
  done
  for f in "${fx}"/cask-json/*.json
  do
    name="cask-json/$(basename "${f}" .json)"
    rc=0
    bash "${chk}" check-cask-json "${f}" >"${work}/out" 2>"${work}/err" || rc=$?
    check_case "${name}" "${f%.json}.expect" "${rc}" "${work}/out" "${work}/err"
  done
  for f in "${fx}"/pragmas/*.cask.txt
  do
    name="pragmas/$(basename "${f}" .cask.txt)"
    rc=0
    bash "${chk}" check-pragmas "${f}" >"${work}/out" 2>"${work}/err" || rc=$?
    check_case "${name}" "${f%.cask.txt}.expect" "${rc}" "${work}/out" "${work}/err"
  done
}

# The .raw fixtures are hand-written; this arm proves the parser reads what git really emits.
run_live_git() { # run_live_git <checker>
  local chk="$1" repo="${work}/repo" rc
  local -a g=(git -C "${repo}" -c user.name=fixture -c user.email=fixture@invalid -c commit.gpgsign=false)
  git init -q "${repo}"
  mkdir -p "${repo}/Casks"
  : >"${repo}/Casks/.keep"
  "${g[@]}" add -A && "${g[@]}" commit -qm base
  printf 'cask "snipdash" do\nend\n' >"${repo}/Casks/snipdash.rb"
  "${g[@]}" add -A && "${g[@]}" commit -qm clean
  git -C "${repo}" diff --raw -z --no-renames --no-abbrev HEAD^1 HEAD >"${work}/in"
  rc=0
  bash "${chk}" classify-paths <"${work}/in" >"${work}/out" 2>"${work}/err" || rc=$?
  printf 'exit=0\nstdout=cask snipdash\n' >"${work}/expect"
  check_case live-git/clean-cask "${work}/expect" "${rc}" "${work}/out" "${work}/err"
  ln -s snipdash.rb "${repo}/Casks/other.rb"
  "${g[@]}" add -A && "${g[@]}" commit -qm symlink
  git -C "${repo}" diff --raw -z --no-renames --no-abbrev HEAD^1 HEAD >"${work}/in"
  rc=0
  bash "${chk}" classify-paths <"${work}/in" >"${work}/out" 2>"${work}/err" || rc=$?
  printf 'exit=1\nrefuse=symlink\n' >"${work}/expect"
  check_case live-git/symlink "${work}/expect" "${rc}" "${work}/out" "${work}/err"
}

if [[ "$#" -eq 1 ]]
then
  run_fixtures "$1"
  printf '%d cases, %d failures\n' "${cases}" "${failures}"
  [[ "${failures}" -eq 0 ]]
  exit
fi
[[ "$#" -eq 0 ]] || {
  echo "usage: tests/run-fixtures.sh [checker]" >&2
  exit 2
}

run_fixtures "${root}/scripts/tap-check.sh"
run_live_git "${root}/scripts/tap-check.sh"
printf '%d cases, %d failures\n' "${cases}" "${failures}"
[[ "${failures}" -eq 0 ]] || exit 1

# Positive control: a broken checker that accepts everything must make this harness fail.
printf '#!/usr/bin/env bash\nexit 0\n' >"${work}/accept-all.sh"
rc=0
bash "$0" "${work}/accept-all.sh" >"${work}/control.log" 2>&1 || rc=$?
if [[ "${rc}" -eq 0 ]]
then
  echo "FAIL positive-control: the harness passed an accept-everything checker"
  exit 1
fi
printf 'ok   positive-control (accept-all checker rejected: %s)\n' "$(tail -n 1 "${work}/control.log" || true)"
