# Flujo de trabajo en VSCode (PlatformIO + OpenCode)

## 1. Lo único que hay que configurar: **qué carpeta se abre**

PlatformIO IDE busca el `platformio.ini` **en la raíz de cada carpeta del
espacio de trabajo**. Aquí el proyecto está en `ch32v003-blink/`, no en la raíz
del repositorio, así que **si abres la carpeta `RiscV` a secas, la barra de
PlatformIO sale vacía y no hay botones de Build/Upload.**

Hay dos formas correctas:

### Opción A — abrir el proyecto directamente (lo más simple)

`File → Open Folder… → RiscV/ch32v003-blink`

Ya está: aparece el icono de PlatformIO (la hormiga) en la barra lateral y los
botones en la barra inferior. Nada más que configurar.

### Opción B — espacio de trabajo multi-raíz (ver informe y proyecto a la vez)

`File → Open Workspace from File… → RiscV/RiscV.code-workspace`

Ese fichero ya está creado y declara dos carpetas: el repositorio (informe) y el
proyecto. PlatformIO detecta `ch32v003-blink` como proyecto y el resto lo tienes
para editar `README_ES.md`. Es un espacio de trabajo **multi-raíz**, que
PlatformIO soporta oficialmente.

## 2. Cómo compilar y grabar desde VSCode

Una vez la carpeta correcta está abierta, **no hay que configurar nada**: el
`upload_protocol = custom` + `upload_command = ./flash.sh $SOURCE` de
`platformio.ini` ya están puestos.

| Acción | Cómo |
|---|---|
| **Compilar** | Icono ✓ en la barra inferior · `Ctrl+Alt+B` |
| **Grabar** | Icono → en la barra inferior · `Ctrl+Alt+U` |
| **Limpiar** | Icono 🗑 en la barra inferior |
| **Tareas del proyecto** | Icono de la hormiga → *PROJECT TASKS* |
| **Terminal de PlatformIO** | Icono ▷_ en la barra inferior |
| **Elegir entorno** | Conmutador al lado de los iconos (solo si hay varios `[env:...]`) |

La salida de la grabación aparece en el panel *Terminal*, con el texto de
`minichlink` (igual que en la terminal normal).

## 3. ⚠️ El monitor serie: no sirve para este montaje

El botón *Serial Monitor* (`Ctrl+Alt+S`) abre un monitor sobre
`/dev/ttyACM0`... **que es el programador, no el chip**. El `Serial` del
CH32V003 está en **PD5/PD6** y no llega al USB del WCH-Link.

- El monitor no mostrará nada útil.
- Sí puede **bloquear la grabación** mientras esté abierto (puerto ocupado).
  Por suerte `platformio-ide.autoCloseSerialMonitor` viene en `true` y lo cierra
  antes de cada subida.

Si quieres leer `Serial`, hace falta un **adaptador USB-TTL aparte** conectado a
PD5/PD6, y entonces sí tiene sentido `monitor_port` en `platformio.ini`.

Se puede quitar el botón del monitor y sustituirlo por algo útil con
`platformio-ide.toolbar` (ver la documentación de PlatformIO IDE).

## 4. IntelliSense / autocompletado

Todo lo gestiona la extensión de PlatformIO. Si al principio aparecen subrayados
rojos en `#include <Arduino.h>`:

1. Lanza un **Build** (`Ctrl+Alt+B`) una vez: genera el índice del proyecto.
2. Espera a que termine *C/C++ Project Index* (abajo a la izquierda).

No hace falta escribir un `c_cpp_properties.json` a mano (PlatformIO IDE se
registra como proveedor de configuración de la extensión de C/C++).

## 5. La extensión de OpenCode (`sst-dev.opencode`)

Es un envoltorio mínimo: **abre el TUI de `opencode` dentro de un terminal
integrado**. No tiene ajustes ni aporta nada más.

| Comando | Atajo (por defecto) |
|---|---|
| Open opencode | `Cmd+Esc` → en Linux, la tecla **Meta/Super + Esc** |
| Open opencode in new tab | `Cmd+Shift+Esc` |
| Add Filepath to Terminal | `Cmd+Alt+K` |

- Requiere que `opencode` esté en el PATH (aquí está en `~/.local/bin/opencode`).
- El atajo por defecto es de macOS; en Linux, `Super+Esc` suele estar cogido por
  el escritorio. Se puede reasignar en
  `File → Preferences → Keyboard Shortcuts` buscando `opencode.openTerminal`.
- La sesión arranca **con el directorio de trabajo = la carpeta abierta en
  VSCode**. Eso decide qué configuración de proyecto y qué *skills* descubre
  OpenCode, así que conviene abrir la carpeta del repositorio (o el espacio de
  trabajo multi-raíz) y no un subdirectorio suelto.

## 6. Archivos de configuración incluidos

En `ch32v003-blink/.vscode/`:

| Fichero | Para qué |
|---|---|
| `settings.json` | Oculta `.pio/` del explorador y de las búsquedas, ajustes de PlatformIO y del corrector ortográfico |
| `tasks.json` | Tareas extra que PlatformIO no trae: **grabar sin recompilar** y **ver la info del chip** |
| `extensions.json` | Extensiones recomendadas al abrir el proyecto |

Para usar las tareas: `Terminal → Run Task… → Grabar solo (sin recompilar)`.

## 7. Problemas típicos

| Síntoma | Causa / solución |
|---|---|
| No aparece la hormiga de PlatformIO | Estás abriendo la carpeta equivocada: abre `ch32v003-blink` o el `.code-workspace` |
| `Permission denied: /dev/ttyACM0` | Falta el grupo `dialout`, o VSCode se abrió antes de añadirse al grupo: **cierra VSCode del todo** y vuelve a abrirlo |
| `pio: command not found` en una tarea | VSCode lanzado desde el menú del escritorio no hereda el PATH del shell. Solución: ajuste `platformio-ide.customPATH`, o las tareas nativas de PlatformIO (que no dependen del PATH) |
| La grabación falla con el puerto ocupado | Cierra el monitor serie u otro programa sobre `/dev/ttyACM0` |
| `Ardulink: synced` pero no detecta el chip | Revisa la resistencia de 1 kΩ en SWDIO, el selector en 3V3 y que el chip no tenga SDI desactivado (ver `hardware.md`) |
| PlatformIO Home se abre solo cada vez | Ajuste `platformio-ide.disablePIOHomeStartup: true` |
