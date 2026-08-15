# Validation record

Date: 2026-08-08

## Tested environment

| Component | Validated value |
|---|---|
| Distribution | CachyOS (Arch-compatible) |
| Desktop shell | DankMaterialShell 1.5 development build |
| Compositor | Niri on Wayland |
| Login | `greetd` with `dms-greeter` |
| Gaze | 0.2.9 |
| Camera | RGB UVC webcam selected by USB vendor/product ID |
| Template storage | TPM 2.0 encryption enabled |

No biometric images, templates, usernames, hostnames, or local backup paths are included in this public record.

## Results

- Final `gaze doctor`: 16 passed, 0 warnings, 0 errors.
- Five consecutive direct authentications succeeded in approximately 0.51–0.61 seconds.
- A photograph matched the enrolled face sufficiently to reach the liveness stage but final authentication was denied after the liveness gate timed out.
- `sudo`: face success confirmed; fallback to existing authentication confirmed when no face was detected.
- Polkit: a real `pkexec` request invoked the Polkit PAM service and succeeded through Gaze.
- DMS Lock: a real lock/unlock invoked `dankshell-gaze-grosshack` with the ScreenLock surface and succeeded.
- `greetd`: a PAM probe invoked the `greetd` service with the Login surface and succeeded without closing the active desktop session.
- The Gaze daemon and `greetd` remained active after the tests.

## DMS plugin validation

- `plugin.json` was accepted by DMS and `gazeAuth` reports `loaded` after a real DMS restart.
- The plugin is installed as a development symlink and appears in the real Control Center grid.
- The rendered tile updated from `Checking…` to the installed/active state and reported all four detected PAM surfaces.
- The read-only status helper completed in approximately 23 ms in the host session.
- The final read-only `gaze doctor` run still returned 16 passed, 0 warnings, 0 errors and one enrolled profile.
- `dms auth validate` accepted the bundled `dankshell-gaze-grosshack` service with no warnings or missing modules.
- `qmllint`, `shellcheck`, the trailing-whitespace scan, and all nine repository tests passed.
- Dry-run fixtures cover Ubuntu 24.04, Debian 13, Fedora 43, CachyOS, and refusal of unsupported Ubuntu/Fedora releases. No package operation was performed by these fixture tests.
- The expanded detail surface rendered with the current DMS QML modules in an isolated Quickshell harness; the doctor action completed and reported one enrolled profile.
- The missing-Gaze status path was exercised in an isolated command environment and returned a stable, non-error state.
- The final panel capture is `assets/screenshot.png` (SHA-256 `740569dbbe7540f8e1271805af5daf5d39d1241937055aa793017ab2047f4449`) and contains no username, hostname, biometric image, browser, or background content.
- The official Gaze signing-key, Ubuntu/Debian repository, and Fedora 42–44 metadata endpoints used by the installer returned successfully on the validation date.

## Still pending

- Observe a complete login through the `dms-greeter` interface after the PAM change.
- Test DMS Lock and DMS Greeter with the camera disconnected and complete the fallback manually.
- Test lock after suspend/resume.
- Run a later `dms-greeter sync` and verify the Gaze line remains outside its managed block.
- Validate the eventual QML plugin on more than one compositor and distribution before claiming broad support.
- Exercise the package installers on disposable Ubuntu, Debian, Fedora mutable, and Fedora OSTree systems; current cross-distribution evidence is dry-run only.
- Exercise the GUI and official-guide launch buttons in a complete interactive desktop session; their process definitions have been statically validated.

## Known Gaze 0.2.9 diagnostic issue

`gaze doctor --benchmark` can report a D-Bus reply decoding mismatch (`got a(ssssssdddd), expected v`) even though the daemon and real authentication work. Upstream fixed the CLI decoder after the 0.2.9 release in commit [`aacf937d`](https://github.com/GunduLabs/gaze/commit/aacf937d). Keep the stable package and judge functionality with real authentication plus the non-benchmark doctor checks until a release containing the fix is available.
