#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)"
fixtures="$repo_root/tests/fixtures"
test_tmp="$(mktemp -d)"

cleanup() {
    rm -rf -- "$test_tmp"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local text="$1"
    local expected="$2"
    printf '%s' "$text" | grep -Fq -- "$expected" || fail "missing '$expected'"
}

printf '%s\n' '[1/11] shell syntax'
bash -n "$repo_root"/scripts/* "$repo_root/tests/test.sh"

printf '%s\n' '[2/11] manifest syntax and invariants'
jq -e '
    .id == "gazeAuth"
    and .type == "widget"
    and (.capabilities | index("control-center") != null)
    and .component == "./GazeAuth.qml"
    and (.permissions | index("process") != null)
' "$repo_root/plugin.json" >/dev/null
if [ -n "${DMS_SOURCE:-}" ] && python3 -c 'import jsonschema' >/dev/null 2>&1; then
    python3 - "$DMS_SOURCE/quickshell/PLUGINS/plugin-schema.json" "$repo_root/plugin.json" <<'PY'
import json
import sys

import jsonschema

with open(sys.argv[1], encoding="utf-8") as schema_file:
    schema = json.load(schema_file)
with open(sys.argv[2], encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)
jsonschema.validate(manifest, schema)
PY
fi

printf '%s\n' '[3/11] Debian and Ubuntu plans'
ubuntu_plan="$("$repo_root/scripts/install-gaze.sh" --plan --os-release "$fixtures/os-release-ubuntu")"
assert_contains "$ubuntu_plan" 'debian family'
assert_contains "$ubuntu_plan" 'Repository suite: noble'
debian_plan="$("$repo_root/scripts/install-gaze.sh" --plan --os-release "$fixtures/os-release-debian")"
assert_contains "$debian_plan" 'Repository suite: trixie'

printf '%s\n' '[4/11] Fedora plan'
fedora_plan="$("$repo_root/scripts/install-gaze.sh" --plan --os-release "$fixtures/os-release-fedora")"
assert_contains "$fedora_plan" 'Fedora'
assert_contains "$fedora_plan" 'Packages: gaze gaze-gui'

printf '%s\n' '[5/11] unsupported Fedora release refusal'
if "$repo_root/scripts/install-gaze.sh" --plan --os-release "$fixtures/os-release-unsupported-fedora" >"$test_tmp/fedora-unsupported.out" 2>&1; then
    fail 'Fedora 41 should be rejected'
fi
assert_contains "$(cat "$test_tmp/fedora-unsupported.out")" 'Supported Fedora releases: 42, 43, 44.'

printf '%s\n' '[6/11] Arch-compatible plan'
arch_plan="$("$repo_root/scripts/install-gaze.sh" --plan --os-release "$fixtures/os-release-cachyos")"
assert_contains "$arch_plan" 'arch family'
assert_contains "$arch_plan" 'gaze-bin gaze-gui-bin'

printf '%s\n' '[7/11] unsupported suite refusal and status protocol'
if "$repo_root/scripts/install-gaze.sh" --plan --os-release "$fixtures/os-release-unsupported-ubuntu" >/dev/null 2>&1; then
    fail 'unsupported Ubuntu suite was accepted'
fi
status_output="$("$repo_root/scripts/gaze-status" status)"
for key in installed daemon_active enrolled pam_lock dms_path_selected distro_id; do
    printf '%s\n' "$status_output" | grep -Eq "^${key}=" || fail "status key $key missing"
done

printf '%s\n' '[8/11] missing-Gaze status'
mkdir -p "$test_tmp/bin" "$test_tmp/pam"
for required_command in bash cut grep head sed tr; do
    ln -s "$(command -v "$required_command")" "$test_tmp/bin/$required_command"
done
missing_status="$(
    PATH="$test_tmp/bin" \
    GAZE_AUTH_PAM_DIR="$test_tmp/pam" \
    GAZE_AUTH_DMS_SETTINGS="$test_tmp/missing-settings.json" \
    GAZE_AUTH_OS_RELEASE="$fixtures/os-release-ubuntu" \
        "$repo_root/scripts/gaze-status" status
)"
assert_contains "$missing_status" 'installed=0'
assert_contains "$missing_status" 'daemon_active=0'
assert_contains "$missing_status" 'enrolled=unknown'
assert_contains "$missing_status" 'pam_lock=0'
assert_contains "$missing_status" 'dms_path_selected=0'

printf '%s\n' '[9/11] missing DMS PAM base is actionable'
pam_test_dir="$test_tmp/configure-pam"
mkdir -p "$pam_test_dir"
plan_output="$(GAZE_AUTH_PAM_DIR="$pam_test_dir" "$repo_root/scripts/configure-dms-pam.sh" --plan)"
assert_contains "$plan_output" "Prerequisite missing: $pam_test_dir/dankshell"
assert_contains "$plan_output" 'On --apply, this script will run `dms auth sync`'

printf '%s\n' '[10/11] apply recovers a missing DMS PAM base through official sync'
mkdir -p "$test_tmp/configure-bin"
ln -s "$fixtures/sudo-stub" "$test_tmp/configure-bin/sudo"
apply_output="$(
    PATH="$test_tmp/configure-bin:$PATH" \
    GAZE_AUTH_PAM_DIR="$pam_test_dir" \
    GAZE_AUTH_DMS_BIN="$fixtures/dms-stub" \
        "$repo_root/scripts/configure-dms-pam.sh" --apply
)"
assert_contains "$apply_output" 'DMS base service is missing; running'
[ -r "$pam_test_dir/dankshell" ] || fail 'DMS base stub was not synced'
installed_target="$pam_test_dir/dankshell-gaze-grosshack"
[ -r "$installed_target" ] || fail 'Gaze PAM target was not installed'
cmp -s "$repo_root/examples/pam/dankshell-gaze-grosshack" "$installed_target" || fail 'installed Gaze PAM policy differs'

printf '%s\n' '[11/12] simultaneous service is detected by the status probe'
grosshack_pam_dir="$test_tmp/grosshack-pam"
mkdir -p "$grosshack_pam_dir"
cp "$repo_root/examples/pam/dankshell-gaze-grosshack" "$grosshack_pam_dir/dankshell-gaze-grosshack"
grosshack_status="$(
    PATH="$test_tmp/bin" \
    GAZE_AUTH_PAM_DIR="$grosshack_pam_dir" \
    GAZE_AUTH_DMS_SETTINGS="$test_tmp/grosshack-settings.json" \
    GAZE_AUTH_OS_RELEASE="$fixtures/os-release-ubuntu" \
        "$repo_root/scripts/gaze-status" status
)"
assert_contains "$grosshack_status" 'pam_lock=1'
assert_contains "$grosshack_status" 'pam_sudo=0'

printf '%s\n' '[12/12] local links, optional shellcheck, and optional qmllint'
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning "$repo_root"/scripts/* "$repo_root/tests/test.sh"
fi

if [ -n "${DMS_SOURCE:-}" ] && command -v qmllint >/dev/null 2>&1; then
    qmllint -I "$DMS_SOURCE/quickshell" -I "$DMS_SOURCE/dank-qml-common" "$repo_root/GazeAuth.qml"
fi

while IFS= read -r markdown_file; do
    while IFS= read -r markdown_link; do
        case "$markdown_link" in
            http*|'#'*|'mailto:'*) continue ;;
        esac
        link_target="${markdown_link%%#*}"
        [ -n "$link_target" ] || continue
        if [[ "$link_target" = /* ]]; then
            resolved="$link_target"
        else
            resolved="$(dirname -- "$markdown_file")/$link_target"
        fi
        [ -e "$resolved" ] || fail "$markdown_file links to missing $markdown_link"
    done < <(rg -o '\[[^]]+\]\([^)]+\)' "$markdown_file" | sed -E 's/^.*\(([^)]+)\)$/\1/')
done < <(find "$repo_root" -type f -name '*.md' -not -path '*/.git/*' -print)

printf '%s\n' 'All tests passed.'
