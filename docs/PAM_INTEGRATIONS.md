# Optional PAM integrations: sudo, Polkit, and greetd

These integrations are optional and manual. The DMS plugin only reports their
status: it never edits PAM or runs the commands below. First make sure
`gaze auth --verbose` succeeds, keep password authentication enabled, and keep
a root-capable terminal or TTY available for recovery.

Use the sequential `pam_gaze.so` module by default. It tries facial
authentication first and then falls back to the existing stack. Do not replace
the distribution's password, fingerprint, account, password, or session rules.

## Before each change

Back up each target separately, preserving ownership and permissions. For
example, before changing `sudo`:

```bash
sudo install -d -o root -g root -m 700 /var/backups/dms-gaze-auth
sudo cp -a -- /etc/pam.d/sudo /var/backups/dms-gaze-auth/sudo.before
sudo sha256sum /var/backups/dms-gaze-auth/sudo.before
```

Repeat the backup and test cycle for one service at a time.

## sudo

On Arch, CachyOS, and Manjaro, add this line before the existing
`auth include system-auth` line in `/etc/pam.d/sudo`:

```text
auth        sufficient    pam_gaze.so
```

Keep existing fingerprint and password rules. Test a fresh PAM transaction:

```bash
sudo -k
sudo -v
```

Verify both facial success and fallback with the camera unavailable or your
face out of frame.

Other distributions may use a shared PAM stack. Follow the current upstream
[Gaze PAM guide](https://gaze.gundulabs.com/guide/pam) instead of copying the
Arch include name.

## Polkit

Arch-compatible systems normally need a local `/etc/pam.d/polkit-1` override:

```text
#%PAM-1.0
auth       sufficient   pam_gaze.so
auth       include      system-auth
account    include      system-auth
password   include      system-auth
session    include      system-auth
```

After backing up any existing override, install the reviewed file as
`root:root` mode `0644`. Restart Polkit and test a real graphical request:

```bash
sudo systemctl restart polkit
pkexec /usr/bin/true
```

Use `pam_gaze_grosshack.so` only if the graphical agent genuinely requires
face authentication and its password UI to run simultaneously. A local
override shadows the vendor PAM file, so compare it with the vendor version
after Polkit upgrades.

## greetd / DMS Greeter

Read the active `/etc/pam.d/greetd` file first. Add the following line outside
the block managed by DMS Greeter and before its fallback authentication stack:

```text
auth        sufficient    pam_gaze.so
```

Do not replace the rest of the file and do not put the line between DMS's
`BEGIN DMS GREETER AUTH` and `END DMS GREETER AUTH` markers. Validate the
result before logging out:

```bash
dms auth validate --path /etc/pam.d/greetd --purpose password --json
```

Keep the current graphical session open while testing with a PAM probe or a
second TTY. Only a later real login verifies the complete `dms-greeter` flow.
After running `dms greeter sync`, confirm that the Gaze line remains present
outside the managed block.

## Final checks and rollback

```bash
gaze doctor
```

For every surface, test facial success and password/fingerprint fallback. If a
service fails, restore only that service's exact backup from a root-capable
terminal before changing or uninstalling Gaze. See [Security and
rollback](SECURITY.md) for the complete recovery order.
