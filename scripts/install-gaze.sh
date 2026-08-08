#!/usr/bin/env bash
set -Eeuo pipefail

apply=0
os_release="/etc/os-release"

usage() {
    cat <<'EOF'
Usage: scripts/install-gaze.sh [--plan|--apply] [--os-release PATH]

Installs official Gundu Labs packages for supported Debian/Ubuntu, Fedora, or
Arch-family systems. The default is a dry plan. It does not edit PAM, enroll a
face, install GNOME integration, or reboot the machine.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --plan) apply=0 ;;
        --apply) apply=1 ;;
        --os-release)
            [ "$#" -ge 2 ] || { printf '%s\n' '--os-release requires a path' >&2; exit 2; }
            os_release="$2"
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[ -r "$os_release" ] || { printf 'Cannot read %s\n' "$os_release" >&2; exit 1; }

read_os_value() {
    local key="$1"
    sed -nE "s/^${key}=(.*)$/\\1/p" "$os_release" \
        | head -n 1 \
        | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/'
}

distro_id="$(read_os_value ID)"
distro_like="$(read_os_value ID_LIKE)"
codename="$(read_os_value VERSION_CODENAME)"
version_id="$(read_os_value VERSION_ID)"
pretty_name="$(read_os_value PRETTY_NAME)"
if [ -z "$codename" ]; then
    codename="$(read_os_value UBUNTU_CODENAME)"
fi
distro_id="${distro_id:-unknown}"
family=""

case " $distro_id $distro_like " in
    *' arch '*|*' manjaro '*) family="arch" ;;
    *' ubuntu '*|*' debian '*) family="debian" ;;
    *' fedora '*|*' rhel '*) family="fedora" ;;
esac

[ -n "$family" ] || {
    printf 'Unsupported distribution family: ID=%s ID_LIKE=%s\n' "$distro_id" "$distro_like" >&2
    exit 1
}

printf 'Detected: %s (%s family)\n' "${pretty_name:-$distro_id}" "$family"

plan_debian() {
    case "$codename" in
        noble|questing|resolute|trixie) ;;
        *)
            printf 'Unsupported Debian/Ubuntu suite: %s\n' "${codename:-unknown}" >&2
            printf '%s\n' 'Supported suites: noble, questing, resolute, trixie.' >&2
            exit 1
            ;;
    esac
    printf '%s\n' 'Will install the Gundu Labs signing key and apt source.'
    printf 'Repository suite: %s\n' "$codename"
    printf '%s\n' 'Packages: gaze gaze-gui'
}

plan_fedora() {
    case "$version_id" in
        42|43|44) ;;
        *)
            printf 'Unsupported Fedora release: %s\n' "${version_id:-unknown}" >&2
            printf '%s\n' 'Supported Fedora releases: 42, 43, 44.' >&2
            exit 1
            ;;
    esac
    if [ -e /run/ostree-booted ] || command -v rpm-ostree >/dev/null 2>&1; then
        printf '%s\n' 'Fedora immutable/OSTree path detected.'
        printf '%s\n' 'Packages will be layered with rpm-ostree; reboot remains manual.'
    else
        printf '%s\n' 'Fedora DNF path detected.'
    fi
    printf '%s\n' 'Will install the signed Gundu Labs RPM repository.'
    printf '%s\n' 'Packages: gaze gaze-gui'
}

plan_arch() {
    printf '%s\n' 'Will use an existing AUR helper (paru preferred, then yay).'
    printf '%s\n' 'Packages: gaze-bin gaze-gui-bin'
}

case "$family" in
    debian) plan_debian ;;
    fedora) plan_fedora ;;
    arch) plan_arch ;;
esac

printf '%s\n' 'PAM files, biometric enrollment, GNOME extensions, and reboot are out of scope.'

if [ "$apply" -ne 1 ]; then
    printf '%s\n' 'Plan only. Re-run with --apply when ready.'
    exit 0
fi

command -v sudo >/dev/null 2>&1 || { printf '%s\n' 'sudo is required.' >&2; exit 1; }
sudo -v

tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

case "$family" in
    debian)
        command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
        command -v dpkg >/dev/null 2>&1 || { printf '%s\n' 'dpkg is required.' >&2; exit 1; }
        curl -fsSL -o "$tmp_dir/gundulabs-archive-keyring.gpg" https://packages.gundulabs.com/keys/gundulabs-repo.gpg
        repo_line="deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gundulabs-archive-keyring.gpg] https://packages.gundulabs.com/deb $codename main"
        printf '%s\n' "$repo_line" > "$tmp_dir/gundulabs.list"
        sudo install -d -o root -g root -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
        sudo install -o root -g root -m 0644 "$tmp_dir/gundulabs-archive-keyring.gpg" /usr/share/keyrings/gundulabs-archive-keyring.gpg
        sudo install -o root -g root -m 0644 "$tmp_dir/gundulabs.list" /etc/apt/sources.list.d/gundulabs.list
        sudo apt-get update
        sudo apt-get install -y gaze gaze-gui
        ;;
    fedora)
        command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
        command -v rpm >/dev/null 2>&1 || { printf '%s\n' 'rpm is required.' >&2; exit 1; }
        curl -fsSL -o "$tmp_dir/gundulabs-repo.asc" https://packages.gundulabs.com/keys/gundulabs-repo.asc
        cat > "$tmp_dir/gundulabs.repo" <<'EOF'
[gundulabs]
name=Gundu Labs
baseurl=https://packages.gundulabs.com/rpm/fedora/$releasever/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.gundulabs.com/keys/gundulabs-repo.asc
EOF
        sudo rpm --import "$tmp_dir/gundulabs-repo.asc"
        sudo install -d -o root -g root -m 0755 /etc/yum.repos.d
        sudo install -o root -g root -m 0644 "$tmp_dir/gundulabs.repo" /etc/yum.repos.d/gundulabs.repo
        if [ -e /run/ostree-booted ] || command -v rpm-ostree >/dev/null 2>&1; then
            sudo rpm-ostree install gaze gaze-gui
            printf '%s\n' 'Packages are staged. Reboot before enabling gazed.'
            exit 0
        fi
        sudo dnf makecache
        sudo dnf install -y gaze gaze-gui
        ;;
    arch)
        if command -v paru >/dev/null 2>&1; then
            aur_helper="paru"
        elif command -v yay >/dev/null 2>&1; then
            aur_helper="yay"
        else
            printf '%s\n' 'Install paru or yay, then re-run this script.' >&2
            exit 1
        fi
        "$aur_helper" -S --needed gaze-bin gaze-gui-bin
        ;;
esac

sudo systemctl enable --now gazed
printf '%s\n' 'Gaze packages installed and gazed enabled.'
printf '%s\n' 'Next: gaze add-face default; gaze auth --verbose; gaze doctor'
printf '%s\n' 'A reboot is recommended by Gaze upstream but is never performed by this script.'
