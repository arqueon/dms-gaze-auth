# Contributing

This repository contains an installable DMS Control Center plugin and separate system-integration helpers.

Do not submit:

- face images or videos;
- embeddings, enrollment databases, TPM material, or biometric logs;
- credentials or host-specific secrets;
- PAM examples that remove password fallback;
- claims of login/lock support without a real test of that surface.

Before proposing a change:

- keep PAM and package changes explicit, reversible, and outside QML/plugin startup;
- preserve password and fingerprint fallback;
- run `./tests/test.sh`, `shellcheck`, and `qmllint` against a current DMS checkout;
- document the exact DMS/Gaze and distribution versions used for runtime QA;
- distinguish static validation from a real lock or login test.

Do not add privileged command execution to `GazeAuth.qml`. New package managers or PAM layouts belong in the terminal helpers and require a dry plan plus rollback analysis.

Registry publication is a separate step. Do not add a registry entry until the screenshot, public URL, cross-distribution evidence, and final runtime QA are complete.
