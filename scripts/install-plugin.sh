#!/usr/bin/env bash
set -Eeuo pipefail

apply=0
method="link"

usage() {
    cat <<'EOF'
Usage: scripts/install-plugin.sh [--plan|--apply] [--link|--copy]

The default is a dry plan using a development symlink. --copy installs only
the runtime files. Existing non-matching installations are never overwritten.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --plan) apply=0 ;;
        --apply) apply=1 ;;
        --link) method="link" ;;
        --copy) method="copy" ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
source_dir="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)"
target_parent="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
target="$target_parent/gazeAuth"

printf 'Plugin source: %s\n' "$source_dir"
printf 'Install target: %s\n' "$target"
printf 'Method: %s\n' "$method"

if [ "$apply" -ne 1 ]; then
    printf '%s\n' 'Plan only. Re-run with --apply when ready.'
    exit 0
fi

mkdir -p -- "$target_parent"
existing_install=0

if [ -L "$target" ]; then
    existing_install=1
    current_target="$(readlink -f -- "$target")"
    if [ "$method" = "link" ] && [ "$current_target" = "$source_dir" ]; then
        printf '%s\n' 'Development link already installed.'
    else
        printf 'Refusing to replace existing symlink: %s -> %s\n' "$target" "$current_target" >&2
        exit 1
    fi
elif [ -e "$target" ]; then
    existing_install=1
    printf 'Refusing to overwrite existing path: %s\n' "$target" >&2
    exit 1
elif [ "$method" = "link" ]; then
    ln -s -- "$source_dir" "$target"
    printf '%s\n' 'Development link installed.'
else
    mkdir -- "$target"
    install -m 0644 -- "$source_dir/plugin.json" "$source_dir/GazeAuth.qml" "$target/"
    mkdir -- "$target/scripts"
    install -m 0755 -- "$source_dir/scripts/gaze-status" "$target/scripts/gaze-status"
    printf '%s\n' 'Runtime files copied.'
fi

if command -v dms >/dev/null 2>&1; then
    if [ "$existing_install" -eq 1 ]; then
        dms ipc plugin-scan rescan gazeAuth >/dev/null 2>&1 || true
    else
        dms ipc plugin-scan scan >/dev/null 2>&1 || true
    fi

    scan_ok=0
    for _attempt in 1 2 3 4 5 6 7 8 9 10; do
        scan_status="$(dms ipc plugin-scan status gazeAuth 2>&1 || true)"
        if ! printf '%s' "$scan_status" | grep -q "unknown pluginId"; then
            scan_ok=1
            break
        fi
        sleep 0.2
    done
    if [ "$scan_ok" -eq 1 ]; then
        printf 'DMS scan completed: %s\n' "$scan_status"
    else
        printf '%s\n' 'Installed, but DMS did not discover gazeAuth. Use Settings > Plugins > Scan for Plugins.' >&2
        exit 1
    fi
fi
