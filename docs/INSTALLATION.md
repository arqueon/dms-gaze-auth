# Installation overview

Gaze, the DMS plugin, and the optional PAM integration are separate layers. Install and verify them in that order.

## Supported package routes

The helper `scripts/install-gaze.sh` detects `/etc/os-release`, prints a plan by default, and refuses unsupported Debian/Ubuntu suites.

| Family | Supported route | Package source |
|---|---|---|
| Ubuntu 24.04/25.10/26.04 | `apt` | Signed Gundu Labs repository; suites `noble`, `questing`, `resolute` |
| Debian 13 | `apt` | Signed Gundu Labs repository; suite `trixie` |
| Fedora 42/43/44 | `dnf` | Signed Gundu Labs RPM repository |
| Fedora OSTree variants | `rpm-ostree` | Same signed RPM repository; manual reboot required |
| Arch/Manjaro/CachyOS | `paru` or `yay` | AUR packages `gaze-bin`, `gaze-gui-bin` |

The package list and supported releases follow Gaze upstream's current installation documentation. The helper does not use the upstream one-line `curl | sh` route: it exposes the package-manager steps for review instead.

## Stage 1: install Gaze

```bash
./scripts/install-gaze.sh --plan
./scripts/install-gaze.sh --apply
```

The apply mode installs the repository key/configuration, packages, and enables `gazed` on mutable systems. It does not:

- edit PAM;
- enroll or remove a face;
- install a GNOME extension;
- change Gaze security settings;
- reboot.

After package installation:

```bash
gaze --version
systemctl status gazed
gaze add-face default
gaze auth --verbose
gaze doctor
```

Do not proceed to PAM until direct authentication works and liveness behavior has been tested.

## Stage 2: install the DMS companion

Development link:

```bash
./scripts/install-plugin.sh --plan --link
./scripts/install-plugin.sh --apply --link
```

Independent copy:

```bash
./scripts/install-plugin.sh --plan --copy
./scripts/install-plugin.sh --apply --copy
```

The installer refuses to overwrite an existing non-matching plugin directory. After installation, enable `gazeAuth` in DMS Settings and add it to Control Center.

## Stage 3: optional DMS Lock PAM service

```bash
./scripts/configure-dms-pam.sh --plan
./scripts/configure-dms-pam.sh --apply
```

The generated service includes `/etc/pam.d/dankshell` as its fallback instead of guessing the distribution's password stack. DMS already derives that service from the host policy, including `system-auth` or `common-auth` where appropriate.

The routine refuses to overwrite a different existing `dankshell-gaze-grosshack` file unless `--replace` is also supplied. Replacements are backed up under `/var/backups/dms-gaze-auth-YYYYMMDD-HHMMSS/`.

## Stage 4: real verification

Keep a root-capable terminal or TTY open. Verify one surface at a time:

1. direct `gaze auth --verbose`;
2. optional `sudo` or Polkit integration;
3. DMS Lock with password/fingerprint fallback;
4. `greetd`/DMS Greeter only after the lock path is recoverable.

Do not report graphical lock or login as verified based only on a configuration file or PAM parser.
