# Dank Plugin Registry publication

Assessment date: 2026-08-08
Published: 2026-08-09

## Current answer

The repository now contains a real DMS plugin:

- root `plugin.json`;
- `GazeAuth.qml` based on `PluginComponent`;
- Control Center detail surface;
- a read-only runtime helper;
- GPL-3.0-or-later licensing;
- installation and validation documentation.

The plugin is available in the official Dank Plugin Registry. [AvengeMedia/dms-plugin-registry#733](https://github.com/AvengeMedia/dms-plugin-registry/pull/733) passed the registry schema, link, manifest-identity, and preview checks and was merged on 2026-08-09.

## Classification

| Field | Value |
|---|---|
| Plugin ID | `gazeAuth` |
| Name | `Gaze Authentication` |
| DMS manifest type | `widget` |
| Registry category | `utilities` |
| Registry type/filter | `control-center` |
| Additional capabilities | `authentication`, `command-execution` |
| Compositors | `any` |
| Distribution metadata | `any` |
| Runtime dependency | `gaze` |
| Minimum DMS | `>=1.6.0` |

The manifest type is `widget` because DMS exposes Control Center plugins through `PluginComponent`. The visible **Control Center** filter comes from the `control-center` capability.

## Why Utilities

Authentication is neither an appearance feature nor the monitoring of a continuous resource. The panel's health information supports setup and troubleshooting; it is not the product's primary purpose. Utilities is also consistent with the registry's existing authentication precedent.

## Why Control Center

The plugin is an on-demand status and action surface. It does not need a permanent DankBar pill, desktop widget, launcher provider, event watcher, or second daemon: `gazed` already owns the authentication runtime.

## Why distribution `any`

The QML component and status helper do not assume a package manager or PAM base stack. They remain useful whenever a compatible `gaze` command is installed. The bundled installer is stricter and only applies package changes on versions explicitly supported by Gaze upstream.

## Publication checklist and follow-up evidence

- [x] Choose a license and add a root license file.
- [x] Implement `plugin.json` and the Control Center QML component.
- [x] Keep privileged package/PAM installation outside QML.
- [x] Handle missing package, inactive daemon, no enrollment, and missing PAM integration.
- [x] Verify the rendered Control Center tile in a real DMS session.
- [x] Verify the expanded detail panel and explicit doctor action with the current DMS QML modules.
- [x] Verify missing-dependency behavior in an isolated command environment.
- [x] Exercise dry package plans for Ubuntu, Debian, Fedora mutable, and Arch-compatible systems.
- [ ] Exercise apply paths on disposable Ubuntu, Debian, Fedora mutable, and Fedora OSTree systems (follow-up evidence; not claimed by this release).
- [x] Capture a representative screenshot on the default DMS theme.
- [x] Publish the repository and verify the final raw screenshot URL.
- [x] Add registry JSON and run `generate.py --validate` plus `validate_links.py`.
- [x] Submit a registry PR without claiming first-party status.
- [x] Pass registry validation and preview checks.
- [x] Receive maintainer review and merge into the official registry.

## Registry metadata reference

The metadata in [`../packaging/arqueon-dms-gaze-auth.json.example`](../packaging/arqueon-dms-gaze-auth.json.example) is a repository-side reference for the published entry. The registry remains the source of truth for its catalog metadata.
