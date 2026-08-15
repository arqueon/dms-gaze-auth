# Fedora installation

Gaze upstream currently publishes packages for Fedora 42, 43, and 44, including a route for OSTree systems such as Silverblue, Kinoite, and compatible images.

## Review and install

```bash
./scripts/install-gaze.sh --plan
./scripts/install-gaze.sh --apply
```

On mutable Fedora, apply mode installs the signed Gundu Labs repository, runs `dnf makecache`, installs `gaze` and `gaze-gui`, and enables `gazed`.

On an OSTree system, it writes the same signed repository and layers the packages with `rpm-ostree`. The script then stops and asks for a manual reboot; it does not pretend the daemon is available before the deployment is booted.

## Verify before PAM

```bash
gaze --version
systemctl is-active gazed
gaze add-face default
gaze auth --verbose
gaze doctor
```

Do not disable SELinux to make authentication pass. Use `gaze doctor`, `journalctl -u gazed`, and the package's policy before diagnosing an SELinux issue.

## DMS Lock fallback

Fedora authentication policy is normally managed through authselect and shared services such as `system-auth` or `password-auth`. Do not hand-edit those generated files for this plugin.

After DMS has generated `/etc/pam.d/dankshell`, use the dedicated service:

```bash
./scripts/configure-dms-pam.sh --plan
./scripts/configure-dms-pam.sh --apply
```

`dankshell-gaze-grosshack` tries Gaze and then includes the DMS service, preserving the active Fedora policy. Keep a recovery TTY and verify password fallback before considering the integration complete.

## Immutable systems

Package removal or replacement on OSTree becomes effective only after a new deployment and reboot. Record the deployment state separately from the plugin state; a staged package is not a running daemon.
