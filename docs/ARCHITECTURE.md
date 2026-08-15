# Architecture

The project has four deliberately separate layers.

## 1. Gaze owns authentication

Upstream Gaze owns camera access, face detection, matching, liveness, enrollment, encrypted template storage, the system daemon, and PAM modules. This repository does not duplicate or proxy biometric data.

## 2. The DMS plugin owns presentation

`GazeAuth.qml` is a `PluginComponent` exposed only through Control Center. It:

- invokes the local `scripts/gaze-status` helper;
- presents package, daemon, enrollment, DMS Lock, and PAM-reference state;
- runs `gaze doctor` only after an explicit click;
- launches `gaze-gui` or the official web guide after an explicit click.

The component has no background daemon and no bar pill. It uses the DMS theme and declares only the `process` permission.

## 3. The status helper is read-only

`scripts/gaze-status` emits simple `key=value` records. It reads:

- `/etc/os-release`;
- command availability and `gaze --version`;
- `systemctl` state for `gazed`;
- command availability and version information only during the fast status path;
- explicit PAM files for references to `pam_gaze.so`;
- the DMS `lockPamPath` setting.

It never reads face-template files or image data. The fast status path deliberately reports enrollment as unknown; only the explicit `gaze doctor` action returns the ordinary diagnostic summary and enrolled-profile count.

## 4. Installation remains outside QML

The shell routines are reviewable terminal workflows:

- `install-gaze.sh` installs upstream packages by supported distribution family;
- `install-plugin.sh` installs the DMS component by symlink or copy;
- `configure-dms-pam.sh` optionally installs a dedicated DMS Lock service.

The QML component never runs those privileged routines. This prevents a Control Center click from silently changing package sources, PAM, or biometric state.

## DMS Lock

The dedicated service (`examples/pam/dankshell-gaze-grosshack`) runs in
simultaneous mode:

1. `pam_gaze_grosshack.so` is sufficient and races the face scan against the
   password conversation;
2. DMS's existing `/etc/pam.d/dankshell` is included as fallback;
3. account, password, and session policies are inherited from `dankshell`.

DMS submits the password only on an explicit Enter (`submitPassword`), never
automatically, so the typed buffer stays intact while the scan runs; an empty
Enter is a no-op, and Esc aborts the attempt without clearing the buffer. A
successful face match unlocks and discards the pending password.

This avoids embedding a Debian `common-auth` or Fedora/Arch `system-auth`
assumption in the plugin. DMS remains responsible for deriving its base stack
from the host. DMS selects the custom service through `lockPamPath`. Starting
the attempt still requires a user action (Enter or the unlock button).

The grosshack race needs a Gaze build with the prompt-answering service gate:
`dankshell-gaze-grosshack` is allowlisted upstream so the race runs without a
controlling terminal.

## Auth-phase observer

The daemon broadcasts a scrubbed `auth_phase` signal (phase, camera status
codes, surface class — never face names or scores) to uid-checked registered
observers. The `gaze-observe` helper binary (shipped with DMS) subscribes and
prints `key=value` records; the shell's AuthHudPill and this plugin's Control
Center tile consume them. Surfaces DMS already sees in-process (lock screen,
polkit modal) render their own feedback and do not depend on the observer.

## DMS Greeter and greetd

The plugin only reports whether `/etc/pam.d/greetd` references Gaze. It does not modify the block managed by DMS Greeter. Login integration remains a separate, high-risk operation because a successful parser or PAM probe does not verify the complete graphical greeter.
