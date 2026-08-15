#!/usr/bin/env bash
set -Eeuo pipefail

apply=0
replace=0
pam_dir="${GAZE_AUTH_PAM_DIR:-/etc/pam.d}"
base_service="$pam_dir/dankshell"
target="$pam_dir/dankshell-gaze-grosshack"
dms_bin="${GAZE_AUTH_DMS_BIN:-dms}"

same_policy() {
    local left="$1"
    local right="$2"
    diff -q \
        <(sed -E '/^[[:space:]]*($|#)/d; s/[[:space:]]+/ /g; s/^ //; s/ $//' "$left") \
        <(sed -E '/^[[:space:]]*($|#)/d; s/[[:space:]]+/ /g; s/^ //; s/ $//' "$right") \
        >/dev/null 2>&1
}

usage() {
    cat <<'EOF'
Usage: scripts/configure-dms-pam.sh [--plan|--apply] [--replace]

Installs the dedicated dankshell-gaze-grosshack PAM service (simultaneous
face/password mode) and selects it in DMS. The default is a dry plan. If DMS
has not created its base service yet, --plan explains the prerequisite and
--apply runs the official `dms auth sync` first. An existing different target
is preserved unless both --apply and --replace are given. This script never
locks the session.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --plan) apply=0 ;;
        --apply) apply=1 ;;
        --replace) replace=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
source_file="$script_dir/../examples/pam/dankshell-gaze-grosshack"

[ -r "$source_file" ] || { printf 'Missing source: %s\n' "$source_file" >&2; exit 1; }

printf 'Source: %s\nTarget: %s\n' "$source_file" "$target"
printf 'Fallback: the distro-specific DMS service %s\n' "$base_service"

if [ ! -r "$base_service" ]; then
    command -v "$dms_bin" >/dev/null 2>&1 || {
        printf '%s\n' 'The DMS CLI is required to create the missing base PAM service.' >&2
        exit 1
    }
    if [ "$apply" -ne 1 ]; then
        printf 'Prerequisite missing: %s\n' "$base_service"
        printf '%s\n' 'On --apply, this script will run `dms auth sync` before installing the Gaze service.'
        printf '%s\n' 'Plan only. Re-run with --apply when ready.'
        exit 0
    fi

    printf 'DMS base service is missing; running `%s auth sync` first.\n' "$dms_bin"
    "$dms_bin" auth sync
    [ -r "$base_service" ] || {
        printf 'DMS authentication sync completed but did not create %s. No Gaze PAM file was installed.\n' "$base_service" >&2
        exit 1
    }
fi

if command -v "$dms_bin" >/dev/null 2>&1; then
    "$dms_bin" auth validate --path "$source_file" --purpose password --json
fi

if [ -e "$target" ] && ! same_policy "$source_file" "$target" && [ "$replace" -ne 1 ]; then
    printf '%s\n' 'A different target already exists. Review it, then use --replace explicitly.' >&2
    exit 1
fi

if [ "$apply" -ne 1 ]; then
    printf '%s\n' 'Plan only. Re-run with --apply when ready.'
    exit 0
fi

command -v sudo >/dev/null 2>&1 || { printf '%s\n' 'sudo is required.' >&2; exit 1; }
sudo -v

if [ -e "$target" ] && ! same_policy "$source_file" "$target"; then
    backup_dir="/var/backups/dms-gaze-auth-$(date +%Y%m%d-%H%M%S)"
    sudo install -d -o root -g root -m 0700 "$backup_dir"
    sudo cp -a -- "$target" "$backup_dir/dankshell-gaze-grosshack.before"
    printf 'Existing target backed up to %s\n' "$backup_dir/dankshell-gaze-grosshack.before"
fi

sudo install -o root -g root -m 0644 "$source_file" "$target"

if "$dms_bin" ipc call settings set lockPamPath "$target" \
    && "$dms_bin" ipc call settings set lockPamInlineFprint false \
    && "$dms_bin" ipc call settings set lockPamExternallyManaged false; then
    printf 'DMS now selects %s.\n' "$target"
else
    printf '%s\n' 'PAM service installed, but the DMS setting could not be updated automatically.' >&2
    printf 'Set lockPamPath manually to %s before testing.\n' "$target" >&2
    exit 1
fi

printf '%s\n' 'No lock test was started. Keep a recovery terminal open before testing DMS Lock.'
