#!/usr/bin/env python3
"""Structural cask check for scripts/tap-check.sh check-cask-json.

argv[1]: `brew info --cask --json=v2 --variations <tap/token>` output for exactly one cask.
stdout: one `<refusal code> <where>` line per refusal; nothing when the cask is accepted.
The codes and locations are fixed strings chosen here, never cask-supplied text.
"""
import json, re, sys

ALLOWED_ARTIFACTS = {"app", "zap", "uninstall"}
ALLOWED_DIRECTIVES = {"quit", "delete", "trash"}
out = []

def refuse(code, where):
    out.append(f"{code} {where}")

def check_fields(c, where):
    if "sha256" in c:
        s = c["sha256"]
        if s == "no_check":
            refuse("sha256-no-check", where)
        elif not (isinstance(s, str) and re.fullmatch(r"[0-9a-f]{64}", s)):
            refuse("sha256-not-pinned", where)
    if "version" in c:
        v = c["version"]
        if v == "latest":
            refuse("version-latest", where)
        elif not (isinstance(v, str) and v):
            refuse("version-missing", where)
    if "artifacts" in c:
        arts = c["artifacts"]
        if not isinstance(arts, list):
            refuse("bad-json", where + ".artifacts")
            return
        apps = 0
        for a in arts:
            if not isinstance(a, dict) or len(a) != 1:
                refuse("bad-json", where + ".artifacts")
                continue
            (key, val), = a.items()
            if key not in ALLOWED_ARTIFACTS:
                # preflight, postflight, uninstall_preflight, uninstall_postflight, pkg, installer,
                # binary, ... -- every artifact that is not app/zap/uninstall.
                refuse("artifact-" + re.sub(r"[^a-z0-9_]", "?", str(key))[:40], where)
                continue
            if key == "app":
                apps += 1
                continue
            for d in (val if isinstance(val, list) else [val]):
                if not isinstance(d, dict):
                    refuse("bad-json", f"{where}.{key}")
                    continue
                for dk in d:
                    if dk not in ALLOWED_DIRECTIVES:
                        refuse(f"{key}-" + re.sub(r"[^a-z0-9_]", "?", str(dk))[:40], where)
        if apps == 0:
            refuse("no-app-artifact", where)

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        doc = json.load(f)
    casks = doc["casks"]
    if not isinstance(casks, list) or len(casks) != 1 or not isinstance(casks[0], dict):
        raise ValueError
except Exception:
    print("bad-json not a brew info --cask --json=v2 document for exactly one cask")
    sys.exit(0)

cask = casks[0]
for k in ("sha256", "version", "artifacts"):
    if k not in cask:
        refuse(k + "-missing", "cask")
check_fields(cask, "cask")
# on_arm/on_intel/on_<macos> blocks surface as variations: each may override sha256, version or
# artifacts, and the top level shows only the runner's own platform.
variations = cask.get("variations") or {}
if not isinstance(variations, dict):
    refuse("bad-json", "variations")
else:
    for name, v in sorted(variations.items()):
        if isinstance(v, dict):
            check_fields(v, "variation")
        else:
            refuse("bad-json", "variation")
print("\n".join(out))
