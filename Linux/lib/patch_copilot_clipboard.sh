#!/usr/bin/env bash
#
# patch_copilot_clipboard.sh — fix Copilot CLI /copy on WSL.
#
# The GitHub Copilot CLI (which Agency wraps) copies to the Windows clipboard
# on WSL by spawning:
#
#     cmd.exe /d /c  chcp 65001 >nul & "<SYSTEMROOT>\System32\clip.exe"
#
# The double quotes around the clip.exe path get mangled by the WSL->Windows
# interop argument escaping (the quote becomes a literal \"), so cmd.exe can't
# find clip.exe and exits 1. The CLI surfaces this as:
#
#     Failed to copy to clipboard: Error: clip.exe exited with code 1
#
# Inside Agency stdout is not a TTY, so the CLI's OSC-52 clipboard fallback is
# disabled and the error is fatal instead of silently ignored.
#
# clip.exe path has no spaces (C:\Windows\System32\clip.exe), so the quotes are
# unnecessary. This script removes them from the extracted CLI bundle:
#
#     chcp 65001 >nul & "${e}"   ->   chcp 65001 >nul & ${e}
#
# The CLI is shipped as a launcher binary that extracts plain JS into
# ~/.cache/copilot/pkg/<platform>/<version>/. A new version extracts a fresh
# (unpatched) bundle, so re-run this after a Copilot/Agency update.
#
# Idempotent. Invoked by install_copilot.sh, or standalone:
#   bash lib/patch_copilot_clipboard.sh

set -euo pipefail
LOG_TAG="copilot-clip"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_LINUX_DIR/lib/common.sh"

# Only relevant on WSL.
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    log "not WSL; clipboard patch not needed."
    exit 0
fi

PKG_ROOT="$HOME/.cache/copilot/pkg"
if [ ! -d "$PKG_ROOT" ]; then
    log "no Copilot CLI bundle found at $PKG_ROOT; nothing to patch."
    exit 0
fi

OLD='chcp 65001 >nul & "${e}"'
NEW='chcp 65001 >nul & ${e}'

patched_any=0
found_any=0

while IFS= read -r -d '' f; do
    found_any=1
    if grep -qF "$NEW" "$f" && ! grep -qF "$OLD" "$f"; then
        log "already patched: ${f#"$HOME"/}"
        continue
    fi
    if ! grep -qF "$OLD" "$f"; then
        # Neither the buggy nor the patched form: upstream changed the code.
        warn "clipboard template not found in ${f#"$HOME"/} (upstream may have changed); skipping."
        continue
    fi
    cp -n "$f" "$f.clip-backup" 2>/dev/null || true
    # Use a literal, delimiter-safe replacement via a tiny node helper so we
    # never have to escape the template for sed.
    OLD="$OLD" NEW="$NEW" node -e '
        const fs=require("fs");
        const f=process.argv[1];
        const from=process.env.OLD, to=process.env.NEW;
        let s=fs.readFileSync(f,"utf8");
        const n=s.split(from).length-1;
        if(n!==1){console.error("expected 1 match, got "+n);process.exit(2);}
        fs.writeFileSync(f, s.split(from).join(to));
    ' "$f"
    log "patched ${f#"$HOME"/}"
    patched_any=1
done < <(find "$PKG_ROOT" -type f \( -name app.js -o -path '*/sdk/index.js' \) -print0 2>/dev/null)

if [ "$found_any" = "0" ]; then
    log "no app.js / sdk/index.js bundles found; nothing to patch."
elif [ "$patched_any" = "1" ]; then
    log "done. Restart Agency / Copilot CLI for the fix to load."
else
    log "done. Nothing to change."
fi
