# DMS Gaze Authentication

A read-only DankMaterialShell Control Center companion for [Gaze](https://github.com/GunduLabs/gaze) facial authentication.

> **Status:** available in the Dank Plugin Registry. The registry entry was accepted through [AvengeMedia/dms-plugin-registry#733](https://github.com/AvengeMedia/dms-plugin-registry/pull/733).

The plugin shows whether Gaze is installed, whether `gazed` is active, whether an enrollment is visible, and which PAM surfaces reference Gaze. It can run `gaze doctor`, open `gaze-gui`, or open the official installation guide. It never edits PAM, enrolls a face, or stores biometric data.

## Control Center surface

![Gaze Authentication detail panel in DankMaterialShell](https://raw.githubusercontent.com/arqueon/dms-gaze-auth/main/assets/screenshot.png)

The `gazeAuth` plugin provides:

- package and daemon status;
- enrollment visibility without exposing templates;
- DMS Lock service and selected-path status;
- `sudo`, Polkit, and `greetd` coverage indicators;
- an explicit read-only `gaze doctor` action;
- an explicit action to open the upstream Gaze GUI.

It is intentionally a Control Center utility rather than a permanent bar indicator. Facial authentication normally needs attention only during setup or troubleshooting.

## Getting started page

Since v0.2.0 the plugin ships a settings page (Settings → Plugins → Gaze Authentication → gear) that walks new users through the four setup steps — install Gaze, enroll a face, connect the DMS lock, verify with the doctor — each with a copyable command and links to this repository and the official install guide. The page is informational only: the plugin never runs installers or edits PAM; every command is reviewed and run by the user in their own terminal. The Control Center tile also shows a contextual "next step" hint until the setup is complete.

## Install Gaze

Review the detected plan first:

```bash
./scripts/install-gaze.sh --plan
```

Then apply it explicitly:

```bash
./scripts/install-gaze.sh --apply
```

The routine uses the official Gundu Labs package source for supported Debian/Ubuntu and Fedora systems, or an existing AUR helper on Arch-compatible systems. It installs `gaze` and `gaze-gui` and enables `gazed` where possible. It does **not** edit PAM, enroll a face, install GNOME integration, or reboot.

Supported documented routes:

| Family | Releases covered by Gaze upstream | Guide |
|---|---|---|
| Arch, CachyOS, Manjaro | Current AUR-compatible systems | [Arch/CachyOS](docs/INSTALL_ARCH.md) |
| Ubuntu | 24.04, 25.10, 26.04 | [Debian/Ubuntu](docs/INSTALL_DEBIAN_UBUNTU.md) |
| Debian | 13 | [Debian/Ubuntu](docs/INSTALL_DEBIAN_UBUNTU.md) |
| Fedora | 42, 43, 44; mutable and OSTree variants | [Fedora](docs/INSTALL_FEDORA.md) |

See the [installation overview](docs/INSTALLATION.md) and always compare it with the [current official Gaze installation guide](https://gaze.gundulabs.com/guide/installation).

## Install the DMS plugin

Install the published plugin from the Dank Plugin Registry:

```bash
dms plugins install gazeAuth
```

The following routes are intended for development or an independent local checkout.

For development, review and create a local symlink:

```bash
./scripts/install-plugin.sh --plan --link
./scripts/install-plugin.sh --apply --link
```

For an independent local copy:

```bash
./scripts/install-plugin.sh --plan --copy
./scripts/install-plugin.sh --apply --copy
```

Then open DMS Settings → Plugins, scan if needed, enable **Gaze Authentication**, and add it to the Control Center grid. The plugin does not provide a DankBar pill.

## Optional DMS Lock integration

Do this only after `gaze auth --verbose` works and password/fingerprint fallback is available:

```bash
./scripts/configure-dms-pam.sh --plan
./scripts/configure-dms-pam.sh --apply
```

If DMS has not created `/etc/pam.d/dankshell` yet, the plan reports that
prerequisite without failing. The apply step runs the official `dms auth sync`
first and continues only after the base service exists.

The dedicated `dankshell-gaze-grosshack` service runs Gaze and DMS's own
`dankshell` service **simultaneously**: the face scan and the password field
race, and whichever succeeds first wins. You can type your password while the
camera is scanning; submitting the right password unlocks and drops the face
flow, and a successful face match unlocks and discards the pending password.
That makes the fallback distribution-aware: DMS retains the host's
`system-auth`, `common-auth`, or equivalent policy.

Requires a Gaze build with the prompt-answering service gate (the
`dankshell-gaze-grosshack` allowlist) and DMS >= 1.6.0 for the simultaneous
input handling and the auth-status HUD.

The routine never starts a lock test. Keep a root-capable terminal or TTY open before testing the real lock screen. Read [Security and rollback](docs/SECURITY.md) first.

## Optional sudo, Polkit, and greetd integrations

The plugin reports whether these three PAM surfaces reference Gaze, but it does not configure them. The settings page includes concise, copy-only guidance, and the complete manual procedure is in [Optional PAM integrations: sudo, Polkit, and greetd](docs/PAM_INTEGRATIONS.md).

Apply one service at a time only after direct `gaze auth --verbose` succeeds. Preserve password and fingerprint fallback, back up each PAM file separately, and validate `greetd` before logging out. Always compare the instructions with the current [upstream Gaze PAM guide](https://gaze.gundulabs.com/guide/pam).

## Registry classification

The best current classification is:

| Registry field | Value |
|---|---|
| Category | **Utilities** |
| Type/filter | **Control Center** |
| DMS manifest type | `widget` |
| Capabilities | `control-center`, `authentication`, `command-execution` |
| Compositor | **Any** |
| Distribution | **Any** for the plugin; installer support is explicitly gated by distribution/version |

It is not Monitoring: service health is secondary to authentication integration. It is not an Event Watcher: no event stream or background daemon is required.

The tile, expanded detail panel, and explicit doctor action were validated with the current DMS QML modules on CachyOS/Niri. The package routines have automated plans for every documented family; applying them on disposable non-Arch systems remains useful follow-up evidence, not a claim made by this release. See [docs/REGISTRY.md](docs/REGISTRY.md).

## Safety boundary

PAM mistakes can lock users out. This project therefore keeps these operations separate:

1. package installation;
2. face enrollment and direct authentication testing;
3. optional PAM preparation;
4. real DMS Lock/login verification.

Configured, applied, PAM-tested, and verified in the real UI are different states. Password and fingerprint fallback must remain available. Liveness must not be disabled merely to make a camera pass.

## Development and validation

```bash
./tests/test.sh
qmllint -I /path/to/DankMaterialShell/quickshell \
  -I /path/to/DankMaterialShell/dank-qml-common GazeAuth.qml
```

The local validation record is in [docs/VALIDATION.md](docs/VALIDATION.md). Contributions should follow [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

- [Installation overview](docs/INSTALLATION.md)
- [Architecture and responsibility boundaries](docs/ARCHITECTURE.md)
- [Security and rollback](docs/SECURITY.md)
- [Optional PAM integrations: sudo, Polkit, and greetd](docs/PAM_INTEGRATIONS.md)
- [Validation record](docs/VALIDATION.md)
- [Dank Plugin Registry publication](docs/REGISTRY.md)
- [Resumen en español](README.es.md)

## Upstream relationship and license

Gaze is maintained by Gundu Labs. DankMaterialShell and the Dank Plugin Registry are maintained by AvengeMedia. This independent integration is not endorsed by either upstream project.

This project is licensed under GPL-3.0-or-later; see [LICENSE](LICENSE).
