# Security and rollback

Facial authentication improves convenience; it does not remove the need for a known-good password recovery path.

The QML plugin is read-only. It may run status commands, `gaze doctor`, `gaze-gui`, and `xdg-open`; it never invokes the privileged installation routines.

## Threat model

The integration assumes a local workstation and a user physically present at the camera. It does not claim protection against a determined attacker with high-quality 3D presentation equipment, camera compromise, root access, or a modified PAM stack.

An RGB webcam provides less spoof resistance than a supported RGB+IR setup. Keep upstream liveness enabled and test realistic photo/screen attacks on the actual camera.

## Mandatory controls

- Keep password authentication in every PAM stack.
- Keep fingerprint authentication where it is already configured.
- Use `pam_gaze.so` sequentially by default.
- Use `pam_gaze_grosshack.so` only when the PAM client requires simultaneous graphical behavior.
- Set elevation confirmation when unattended authorization is a concern.
- Abort authentication over SSH.
- Encrypt templates with TPM when the machine supports it.
- Never commit face images, embeddings, Gaze databases, TPM material, or `/var/lib/gaze/users`.

## Change discipline

For every PAM target:

1. Read the actual current file and its include chain.
2. Create a root-only copy with preserved metadata.
3. Record a SHA-256 for the copy.
4. Validate the candidate file.
5. Apply only that service.
6. Test face success and fallback failure/success paths.
7. Retain the backup after validation.

Run every bundled installer in its default `--plan` mode before `--apply`. Do not add a future “install now” or “enable PAM” Control Center button without a separately reviewed privilege boundary and recovery design.

DMS Lock and `greetd` deserve a timed watchdog because a mistake can remove the normal graphical recovery path.

## Rollback order

Recover access before uninstalling software:

1. Restore the affected PAM file from its exact backup.
2. For DMS Lock, return `lockPamPath` to its previous value and verify password/fingerprint.
3. For `greetd`, verify the file and keep the current session open until the next login succeeds.
4. Run `gaze doctor` and a real fallback authentication.
5. Only then disable `gazed` or remove Gaze packages if removal is desired.

Deleting enrollment data first does not repair a broken PAM stack and can make diagnosis harder.

## Plugin boundary

The Control Center plugin displays status and starts explicit read-only actions, but it must not silently:

- install packages;
- edit `/etc/pam.d`;
- weaken liveness or thresholds;
- enroll or remove faces;
- restart `greetd`;
- log the contents of biometric storage.

Privileged changes need a separate, reviewable, user-confirmed flow with exact targets and rollback evidence.
