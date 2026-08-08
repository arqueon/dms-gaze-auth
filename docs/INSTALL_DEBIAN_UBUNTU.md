# Debian and Ubuntu installation

The supported official package suites are Ubuntu 24.04 (`noble`), Ubuntu 25.10 (`questing`), Ubuntu 26.04 (`resolute`), and Debian 13 (`trixie`). The helper refuses other suites instead of silently mixing repositories.

## Review and install

```bash
./scripts/install-gaze.sh --plan
./scripts/install-gaze.sh --apply
```

Apply mode performs the equivalent of the current official manual route:

1. downloads the Gundu Labs repository key over HTTPS;
2. installs it as `/usr/share/keyrings/gundulabs-archive-keyring.gpg`;
3. writes a suite-specific `signed-by` apt source;
4. installs `gaze` and `gaze-gui`;
5. enables `gazed`.

It does not pipe a remote script into a shell and does not modify PAM.

## Verify before PAM

```bash
gaze --version
systemctl is-active gazed
gaze add-face default
gaze auth --verbose
gaze doctor
```

Run `gaze doctor` as the desktop user so it can inspect the user's camera/PipeWire context.

## DMS Lock fallback

Debian-family shared PAM policy normally uses `common-auth`. Do not hard-code or overwrite that system file. First let DMS produce `/etc/pam.d/dankshell`, then use:

```bash
./scripts/configure-dms-pam.sh --plan
./scripts/configure-dms-pam.sh --apply
```

The dedicated service calls `pam_gaze.so` and falls back to DMS's generated service, which retains the distribution's own PAM includes.

## Version-specific note

Ubuntu 26.04 moved the PAM module search path to `/usr/lib/security`. Current Gaze packages include that fix. If logs report that `pam_gaze.so` cannot be loaded, update from the official repository rather than copying a module from another distribution.

## Recovery

Keep a root-capable terminal or TTY open while testing. If the custom DMS service fails, restore DMS's `lockPamPath` to its previous value and remove or restore only `/etc/pam.d/dankshell-gaze`; do not edit `common-auth` as a recovery shortcut.
