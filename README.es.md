# Autenticación Gaze para DMS

Plugin de Control Center para consultar el estado de [Gaze](https://github.com/GunduLabs/gaze) dentro de DankMaterialShell.

> **Estado:** disponible en Dank Plugin Registry. La entrada fue aceptada mediante [AvengeMedia/dms-plugin-registry#733](https://github.com/AvengeMedia/dms-plugin-registry/pull/733).

![Panel detallado de Gaze Authentication en DankMaterialShell](https://raw.githubusercontent.com/arqueon/dms-gaze-auth/main/assets/screenshot.png)

## Qué hace

- Muestra paquete, daemon, enrolamiento y cobertura PAM.
- Distingue si `dankshell-gaze` existe y si DMS lo tiene seleccionado.
- Ejecuta `gaze doctor` únicamente cuando se pulsa el botón.
- Abre `gaze-gui` para gestionar rostros.
- No modifica PAM, no enrola rostros y no guarda información biométrica.

## Página de primeros pasos

Desde la v0.2.0 el plugin incluye una página de ajustes (Settings → Plugins → Gaze Authentication → engranaje) que guía a quien llega por primera vez por los cuatro pasos: instalar Gaze, enrolar un rostro, conectar el bloqueo de DMS y verificar con el doctor — cada uno con su comando copiable y enlaces al repositorio y a la guía oficial. La página es solo informativa: el plugin nunca ejecuta instaladores ni edita PAM; cada comando lo revisa y lo corre el usuario en su propia terminal. El panel del Control Center muestra además una pista de «siguiente paso» hasta completar la configuración.

## Instalación

Para instalar la versión publicada desde Dank Plugin Registry:

```bash
dms plugins install gazeAuth
```

Los scripts siguientes son para revisar la instalación de Gaze o trabajar con un checkout local del plugin.

Primero revisa cualquier plan:

```bash
./scripts/install-gaze.sh --plan
./scripts/install-plugin.sh --plan --link
```

Después, si el resultado es correcto:

```bash
./scripts/install-gaze.sh --apply
./scripts/install-plugin.sh --apply --link
```

La rutina de Gaze cubre Arch/CachyOS/Manjaro, Ubuntu 24.04/25.10/26.04, Debian 13 y Fedora 42/43/44. Usa paquetes y repositorios oficiales de Gundu Labs. No reinicia el equipo ni toca PAM.

La integración opcional de DMS Lock se mantiene separada:

```bash
./scripts/configure-dms-pam.sh --plan
./scripts/configure-dms-pam.sh --apply
```

Solo debe aplicarse después de comprobar `gaze auth --verbose` y conservar contraseña o huella como respaldo.

## Integraciones opcionales con sudo, Polkit y greetd

El plugin únicamente detecta si estas tres superficies PAM usan Gaze; no las configura. La página de ajustes muestra indicaciones breves y copiables. El procedimiento manual completo, con respaldos, fallback, validación y reversión, está en [Integraciones PAM opcionales: sudo, Polkit y greetd](docs/PAM_INTEGRATIONS.md).

Debe aplicarse una superficie a la vez, únicamente después de que `gaze auth --verbose` funcione. Hay que conservar contraseña y huella, validar `greetd` antes de cerrar sesión y contrastar siempre las indicaciones con la [guía PAM oficial de Gaze](https://gaze.gundulabs.com/guide/pam).

## Clasificación en el registro

- **Categoría:** Utilities.
- **Tipo:** Control Center.
- **Manifiesto DMS:** `widget`.
- **Compositor:** Any.
- **Capacidades:** `control-center`, `authentication`, `command-execution`.

No es Monitoring porque su función principal es la integración de autenticación. Tampoco es Event Watcher: no mantiene un flujo de eventos ni añade otro daemon.

Consulta [README.md](README.md), [la guía general de instalación](docs/INSTALLATION.md), [las integraciones PAM opcionales](docs/PAM_INTEGRATIONS.md) y [el expediente para Dank Plugins](docs/REGISTRY.md). La tarjeta, el panel expandido y la acción de diagnóstico ya se validaron con los módulos actuales de DMS sobre CachyOS/Niri. Los planes automatizados cubren todas las familias documentadas; aplicar las rutinas en sistemas desechables no Arch queda como evidencia posterior y no como una prueba ya realizada.
