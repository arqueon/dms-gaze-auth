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

The dedicated service has this sequence:

1. `pam_gaze.so` is sufficient;
2. DMS's existing `/etc/pam.d/dankshell` is included as fallback;
3. account, password, and session policies are inherited from `dankshell`.

This avoids embedding a Debian `common-auth` or Fedora/Arch `system-auth` assumption in the plugin. DMS remains responsible for deriving its base stack from the host.

DMS selects the custom service through `lockPamPath`. The standard lock flow still requires a user action to start PAM where the DMS UI does not provide a hands-free Gaze channel.

## DMS Greeter and greetd

The plugin only reports whether `/etc/pam.d/greetd` references Gaze. It does not modify the block managed by DMS Greeter. Login integration remains a separate, high-risk operation because a successful parser or PAM probe does not verify the complete graphical greeter.
