# Arch and CachyOS integration guide

This guide is for review and controlled local deployment. PAM errors can prevent login. Keep a working password, a root-capable terminal or TTY, and verified backups before changing anything.

## 1. Install and verify upstream Gaze

Use the current [official Gaze installation documentation](https://gaze.gundulabs.com/guide/installation). The repository helper uses `paru` or `yay` to install `gaze-bin` and `gaze-gui-bin`:

```bash
./scripts/install-gaze.sh --plan
./scripts/install-gaze.sh --apply
```

Verify the package version before continuing because repository and AUR publication can lag behind the latest release.

```bash
gaze --version
systemctl is-active gazed
systemctl is-enabled gazed
gaze doctor
```

Do not continue to PAM integration until the daemon, camera, configuration, and TPM checks are understood.

## 2. Configure camera and security

Prefer a stable USB selector over a volatile `/dev/videoN` path when the camera supports it:

```toml
[security]
level = "medium"

[cameras]
rgb = "usb:VVVV:PPPP"

[auth]
abort_if_ssh = true
require_confirmation_lock_screen = false
require_confirmation_elevation = true

[liveness]
enabled = true
threshold = 0.8

[storage]
encrypt_templates = true
```

Use the actual vendor/product IDs reported by the machine. TPM encryption requires TPM 2.0 and an accessible resource-manager device.

## 3. Enroll and test before PAM

```bash
gaze add-face default
gaze auth --verbose
gaze doctor
```

Test several head positions and lighting conditions. Also test a photograph or screen presentation. A face similarity result alone is not success: the final authentication must be rejected when liveness fails.

## 4. Back up each PAM target

Use a root-only directory and retain permissions, ownership, and hashes. Name the backup explicitly; do not rely on an unresolved variable or wildcard during recovery.

Example for one file:

```bash
sudo install -d -o root -g root -m 700 /var/backups/dms-gaze-auth-sudo
sudo cp -a -- /etc/pam.d/sudo /var/backups/dms-gaze-auth-sudo/sudo.before
sudo sha256sum /var/backups/dms-gaze-auth-sudo/sudo.before
```

Repeat for every file before its own change. Do not group untested PAM changes into one transaction.

## 5. sudo

Add the line from [`examples/pam/sudo-gaze.snippet`](../examples/pam/sudo-gaze.snippet) before the existing password stack. Keep the existing fingerprint and password lines.

Test both routes:

```bash
sudo -k
sudo -v
```

Test once with face authentication and once with the camera unavailable or the face out of frame, then complete the fallback with fingerprint or password.

## 6. Polkit

Arch may require a local `/etc/pam.d/polkit-1` override. The sequential example follows the normal Gaze model. The simultaneous example is for graphical agents where face authentication must run alongside the visible password dialog.

- [`polkit-1-sequential.example`](../examples/pam/polkit-1-sequential.example)
- [`polkit-1-simultaneous.example`](../examples/pam/polkit-1-simultaneous.example)

Test with a real graphical request:

```bash
pkexec /usr/bin/true
```

## 7. DMS Lock

Install the standalone service only after reviewing the active DMS stack:

```bash
./scripts/configure-dms-pam.sh --plan
./scripts/configure-dms-pam.sh --apply
```

Arm a timed rollback before the first real lock. On the lock screen, press Enter with an empty field to start the PAM transaction, then look at the camera. Confirm that fingerprint and password still work before treating the integration as complete.

## 8. greetd and DMS Greeter

Do not replace the entire `greetd` file with an example from another machine. Insert [`greetd-gaze.snippet`](../examples/pam/greetd-gaze.snippet) outside the DMS-managed markers and before the existing fallback stack.

Do not restart or log out until a TTY/root recovery path is available. A PAM test harness can verify that the `greetd` service invokes Gaze, but only a later real login verifies the complete `dms-greeter` interface.

## 9. Final checks

```bash
gaze doctor
dms auth validate --path /etc/pam.d/dankshell-gaze --purpose password --json
dms auth validate --path /etc/pam.d/greetd --purpose password --json
```

Record separately:

- configured;
- applied;
- tested through PAM;
- tested through the real lock/login interface.

Those states are not interchangeable.
