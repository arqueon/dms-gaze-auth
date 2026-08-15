# Design of Record: concurrent face/password auth with a global auth-status HUD

Status: approved design (grilling session, 2026-08-15). Supersedes the
sequential-only assumptions in `ARCHITECTURE.md` where they conflict.

## 1. Problem

With `dankshell-gaze` (`pam_gaze.so` `sufficient` first), every lock-screen PAM
attempt runs the face scan before the password module is reached:

- the scan budget is 12 s (`CAMERA_AUTH_TIMEOUT_SECS`, `pam-gaze-core/src/lib.rs`),
- DMS swallows all input while `passwd.active`
  (`LockScreenContent.qml` `handleKey`: *"PAM is active, ignoring input"`),
- DMS auto-responds to `responseRequired` with the current buffer
  (`Pam.qml` `onResponseRequiredChanged` → `respond(root.buffer)`).

Net effect: typing a password during the scan is impossible, the first typed
characters get submitted as a partial password on fallback, and every retry
pays another full scan. Users cannot reliably choose manual password.

An earlier DMS era made this worse by requiring `passwordBuffer.length > 0`
before Enter ran PAM at all; removed by `64c8e79` (issue #226, 2025-09-21).

## 2. Target behavior

Concurrent mode, exactly matching `pam_gaze_grosshack.so`'s race:

- the face scan runs while the password field stays live and editable,
- submitting the **right password** at any time during the scan unlocks and
  drops the face flow,
- a successful face match unlocks and drops the pending password,
- the auth-status HUD ("waiting for face", "face matched", …) is visible on
  every Gaze-covered surface: lock screen, polkit modal, terminal sudo, and
  mirrored in the plugin's Control Center tile.

## 3. Key facts the design rests on

| Fact | Source |
| --- | --- |
| Scan budget is 12 s + effective start delay | `pam-gaze-core/src/lib.rs` `CAMERA_AUTH_TIMEOUT_SECS` |
| `pam_gaze_grosshack.so` races biometric vs password response via `tokio::select!` | `pam-gaze-grosshack/src/lib.rs` `do_authenticate` |
| The race branch only runs when the caller can open `/dev/tty`, or the service is `polkit-1` | `prompt_is_retirable()` + `is_polkit` exemption |
| Daemon phase signals (`face_status`, `verify_status`, `verify_diagnostic`) are unicast to the claim owner | `daemon.rs` `SignalEmitter::set_destination(claim.sender)` |
| `verify_status` payload includes face names and match scores | `gaze-core/src/dbus.rs` `Gaze` trait |
| `register_extension`/`is_extension_active` is the existing daemon authz pattern | `gaze-core/src/dbus.rs` |
| Quickshell exposes no D-Bus module to QML (`src/dbus/` is a `tryLaunchService` utility only) | quickshell master |
| DMS QML already spawns `Process` and parses stdout (hyprland layout probe; plugin `gaze-status`) | `LockScreenContent.qml`, plugin `scripts/` |
| DMS already receives Gaze's phase strings in-process as `PAM_TEXT_INFO` on lock/polkit | `Pam.qml` `onMessageChanged` → `lockMessage` |
| Lock screen settings UI already selects `lockPamPath` (Auto/Custom) | `Modules/Settings/LockScreenTab.qml` |
| DMS core IPC (`DMSService.sendRequest`) exists but is not needed by this design | `Lock.qml` `loginctl.lockerReady` |

## 4. Decisions (grill record)

| # | Decision |
| --- | --- |
| Q1 | Target state A: scan stays user-triggered but never blocks typing; password submit lands after the scan settles; a face match that already succeeded wins. |
| Q2 | HUD covers the lock screen feedback line *and* every other Gaze-covered prompt (polkit, terminal sudo). |
| Q3 | HUD state sources: **3 (daemon D-Bus phases) + 1 (in-process PAM strings)**. |
| Q4 | The user carries the upstream Gaze patches (observer channel). |
| Q5 | Observer channel: **registered observers (uid-checked), scrubbed payload, surface classification included** (see §6.1). |
| Q6 | Superseded by the concurrent design (§4 Q8) — auto-submit is incompatible with the race. |
| Q7 | Superseded likewise; the partial-submit problem disappears because submits are explicit Enters. |
| Q8 | **Concurrent grosshack design**; race gate by **service-name detection** (allowlist of prompt-answering agents), not config. Wrong password during the race fails the attempt (face cannot rescue); faillock exposure accepted. |
| Q9 | Esc during scan/response = **abort the attempt** (`passwd.abort()` via the `recoverFromAuthStall` path); the typed buffer survives the abort. |
| Q10 | Empty Enter during an active scan = **no-op** (face flow continues; empty Enter only starts an attempt when none is active). Response phase is **untimed** — the stack waits on the user's Enter indefinitely; Esc is the escape. The scan phase keeps the 15 s backstop as a redundant guard behind gaze's own 12 s budget. |
| Q11 | Transport: **standalone `gaze-observe` helper binary** spawned by QML (Process + stdout lines), not DMS-core D-Bus. |
| Q12 | Terminal overlay: **fixed top-center pill**, lifetime = claim-active only (no grace fade); suppressed while DMS's own lock screen is visible; otherwise shows the daemon's active claim. |
| Q13 | Build order: DMS input semantics → Gaze upstream patches → DMS overlay+helper → plugin. |

## 5. Concurrent auth mechanics

### 5.1 PAM service

`/etc/pam.d/dankshell-gaze-grosshack` (replaces `dankshell-gaze` as the
installed lock service):

```text
#%PAM-1.0
auth      sufficient pam_gaze_grosshack.so
auth      include    dankshell
account   include    dankshell
password  include    dankshell
session   include    dankshell
```

The race inside `pam_gaze_grosshack.so`:

1. presents the prompt and issues the password conversation request
   concurrently with the face scan,
2. `tokio::select!`: password response wins → run the password module → verdict;
   biometric match wins → unlock (confirmation paths per upstream),
3. scan fail/timeout → fall back to the password conversation.

### 5.2 DMS response semantics (replaces auto-respond)

- Remove `respond(root.buffer)` from `onResponseRequiredChanged`.
- Respond only when the user presses Enter with a non-empty buffer while a
  response is pending.
- Empty Enter while `passwd.active` and a response pending: **no-op**.
- Empty Enter while no attempt is active: starts the attempt (today's behavior).
- Esc while `passwd.active`: `passwd.abort()` + `recoverFromAuthStall()`; buffer
  is retained.
- `passwdActiveTimeout` (15 s) applies to the **scan phase only**; the response
  phase has no timer.

### 5.3 DMS input changes

- `LockScreenContent.qml` `handleKey`: drop the `pam.passwd.active` swallow
  guard; keep the Escape/abort path.
- `imeCommitSink.onTextChanged`: drop the `pam.passwd.active` gate (IME text
  must reach the buffer during the scan).
- Polkit modal (`PolkitAuthContent.qml`): stop disabling the field while the
  stack is active (`enabled: !root.isLoading`); keep explicit
  Enter-submits (`onAccepted: submitAuth()` already).
- Buffer survives failed attempts and aborts (unchanged today).

## 6. Upstream Gaze changes (carried by this project)

### 6.1 Observer API

```text
register_observer(uid: u32) -> ()
# daemon keeps a LIST of observers per uid; phases broadcast to all of them.

signal auth_phase(phase: u8, rgb_status: u8, ir_status: u8, surface: String)
# surface = existing classification (screen_lock / elevation / other),
# NOT the raw PAM service name.
```

- Phase codes: `0 waiting`, `1 matched`, `2 not-recognized`, `3 unavailable`,
  `4 idle`. `idle` is broadcast when the claim ends (verdict delivered,
  cancelled, superseded) so observers can retire their UI; the claim owner's
  `verify_status` carries the actual verdict. Camera status codes follow
  `CaptureStatus::code()`. Both mappings are part of the D-Bus contract.
- `verify_status` remains claim-owner-only; observers get process state, claim
  owners get biometric data (faces + scores never cross the observer channel).
- Multiple observers per uid required (extension + `gaze-observe` instances);
  dead unique names are pruned via the NameOwnerChanged watcher.

### 6.2 grosshack race gate

- `prompt_is_retirable()` (`/dev/tty` openable) stays for legacy callers.
- Add a **service-name allowlist** of graphical agents that answer prompts
  through their own conversation (includes `dankshell-gaze-grosshack`), which
  gets the race branch even without a tty.
- No config surface; detection only.

## 7. `gaze-observe` helper (ships in DMS)

- Go binary, one dependency (godbus): connect to session bus,
  `register_observer(getuid())`, subscribe `auth_phase`, print one
  `key=value` record per change to stdout:

```text
phase=waiting rgb=ready ir=unknown surface=screen_lock
phase=matched rgb=ready ir=unknown surface=elevation
```

- Exit non-zero when the daemon or the observer API is unavailable; consumers
  fall back (§9). Terminates on stdin close.
- Consumers: DMS terminal overlay (spawns one), plugin CC tile (spawns one).

## 8. HUD surfaces

| Surface | Data source | Rendering |
| --- | --- | --- |
| Lock screen | In-process PAM strings (source 1); observer optional enrichment | Upgrade `authFeedbackText`: phase-colored states (waiting = neutral, matched = success, failed/timeout = error), not blanket error-red |
| Polkit modal | In-process PAM strings | Same state treatment in the prompt slot |
| Terminal sudo | `gaze-observe` | Fixed top-center pill under the bar; visible only while a claim is active; suppressed while the DMS lock screen is visible |
| CC tile (plugin) | `gaze-observe` | Mirror active phase + surface in the widget's secondary text / status rows |

## 9. Degradation matrix

| Condition | Lock HUD | Terminal pill | CC mirror |
| --- | --- | --- | --- |
| Gaze absent | hidden (no strings, no daemon) | hidden | "not installed" (today) |
| Unpatched daemon (no observer API) | full (source 1) | hidden | hidden |
| Daemon running, camera busy | full (source 1) | shows claim phase | shows phase |
| `gaze-observe` exits | n/a | hidden | hidden |

## 10. Plugin changes (`dms-gaze-auth`)

1. `configure-dms-pam.sh` installs `dankshell-gaze-grosshack` and points
   `lockPamPath` at it; keeps the dry-plan/backup/`--replace` discipline.
2. Optional PAM integrations (`sudo`, `polkit-1`) documented with
   `pam_gaze_grosshack.so` and their race semantics; `PAM_INTEGRATIONS.md`
   rewritten accordingly.
3. CC tile: spawn `gaze-observe` (falls back to `gaze-status` polling), show
   live `phase`/`surface` in the widget state.
4. Version floors: `requires_dms` bumped to the release carrying Phase 1 + 3;
   docs note the patched-Gaze requirement for concurrent mode.
5. `docs/ARCHITECTURE.md` updated: concurrent lock service, observer channel,
   helper process; "standard lock flow requires a user action to start PAM"
   note stays true (Enter/button still starts the attempt).

## 11. Build order and tests

1. **DMS input semantics** (independent of Gaze): un-swallow, respond-on-Enter,
   empty-Enter no-op, Esc-abort, timer split. Test target exists:
   `core/internal/qmlchecks/lockscreen_input_test.go`; plus manual matrix
   (type-during-scan, empty-Enter, Esc, timeout).
2. **Gaze upstream**: observer API + scrubbed `auth_phase` + grosshack gate.
   Unit tests: observer fan-out, payload scrubbing, gate allowlist.
3. **DMS overlay + helper**: `gaze-observe`, terminal pill, lock HUD visuals.
   Test: helper stdout contract against a stubbed daemon; pill visibility
   matrix.
4. **Plugin**: service swap, CC mirror, docs, version floors. Existing
   `tests/test.sh` fixtures extended with the grosshack service file.

## 12. Explicitly out of scope

- Greeter (dank-greeter) HUD — separate project; the observer API is reusable
  there later.
- Any change to `require_confirmation_lock_screen` behavior on DMS: with
  confirmation enabled, non-GNOME surfaces still fail closed (upstream
  behavior, unchanged).
- DMS-core D-Bus integration (rejected at Q11).
