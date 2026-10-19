---
name: CH32V003F4P6 con WCH-Link CH549
description: Trabajar con el CH32V003F4P6 programado con un WCH-Link antiguo (CH549) reflasheado con el firmware SWIO de ch549-link. Úsala para compilar y grabar sketches en el chip, crear un proyecto nuevo con el platformio.ini correcto, escribir código que toque pines (reglas de PD1/SWIO y NRST/PD7), recuperar el chip si deja de responder, y para el flujo de trabajo en VSCode con PlatformIO y la extensión de OpenCode.
---

# CH32V003F4P6 programado con un WCH-Link CH549 reflasheado

Este repositorio documenta cómo **compilar y grabar** una placa **CH32V003F4P6**
desde Linux usando un **WCH-Link antiguo (CH549) reflasheado** con el firmware
SWIO del proyecto [`ch549-link`](https://github.com/e-labInnovations/ch549-link)
(licencia MIT), manejado con `minichlink` (de
[ch32v003fun](https://github.com/cnlohr/ch32v003fun), MIT) por el protocolo
*ardulink*.

## Documentos de apoyo

| Documento | Cuándo leerlo |
|---|---|
| `references/hardware.md` | Pines, cableado, el LED rojo de PD1, trampas del chip y del depurador |
| `references/grabacion.md` | Compilar, grabar, verificar la grabación y recuperar el chip |
| `references/proyecto-nuevo.md` | **Crear un proyecto nuevo**: el `platformio.ini` correcto y `flash.sh` |
| `templates/platformio.ini` | Plantilla lista para copiar a un proyecto nuevo |
| `references/vscode.md` | Flujo de trabajo en VSCode (PlatformIO + extensión de OpenCode) |
| `scripts/diagnostico.sh` | Comprobación rápida del entorno **antes** de grabar |
| `scripts/nuevo-proyecto.sh` | Crea un proyecto nuevo ya listo para grabar |
| `templates/platformio.ini` | Plantilla del `platformio.ini` para un proyecto nuevo |
| `templates/flash.sh` | Plantilla del grabador (copia exacta de `ch32v003-blink/flash.sh`) |

## 1. Estructura del repositorio

```text
RiscV/
├── README_ES.md              informe completo (ES)  <- la fuente de la verdad
├── README.md                 informe completo (EN)
├── CH32V003F4P6_PCB.jpg      imagen de portada
├── LICENSE                   MIT
├── RiscV.code-workspace      espacio de trabajo de VSCode (informe + proyecto)
├── ch32v003-blink/           proyecto PlatformIO
│   ├── platformio.ini        board = genericCH32V003F4P6, core openwch
│   ├── flash.sh              grabador (lo llama "pio run -t upload")
│   ├── src/main.cpp          FIRMWARE ACTIVO: parpadeo de PC0 (100/100 ms)
│   ├── extras/               archivos de referencia, NO se compilan
│   │   ├── led_rojo_pd1.cpp      experimento del LED rojo (PD1), verificado
│   │   └── escaneo_pines.cpp     escaneo de los 16 GPIO
│   ├── README.md             guía rápida del proyecto
│   └── .vscode/              configuración de VSCode (tareas, ajustes)
└── tools/                    herramientas de terceros (ch32v003fun, ch549-link,
                              wlink-iap, isp55e0) - ver licencias en el informe
```

**PlatformIO solo compila `src/`.** Los ficheros de `extras/` son de referencia:
para probar uno hay que copiarlo encima de `src/main.cpp`.

## 2. Las diez reglas de oro

1. **`PD1` es SWIO *y* el LED rojo de la placa a la vez.** Es la línea de
   programación. No lo pongas como salida "a lo loco".
2. **`PD7` es NRST** (reset del chip). No lo uses como GPIO.
3. **No leas `GPIOD->INDR` para averiguar el nivel de PD1 mientras SDI está
   activo: devuelve 0.** Eso provoca un falso "modo seguro" (fue el fallo de la
   versión 1 del experimento del LED rojo).
4. **`LED_BUILTIN` no existe** en esta placa/core: hay que definir el pin a mano.
5. **`Serial` es PD5 (TX) / PD6 (RX), no el USB del programador.** El USB del
   WCH-Link **es el programador**, no el puerto serie del chip.
6. **Con SDI activo (estado por defecto tras un reset) grabar funciona siempre**,
   sin ventanas de tiempo. Es el modo que hay que mantener por defecto.
7. **Si se desactiva SDI, el programador no puede engancharse.** Entonces hay que
   abrir una ventana de arranque en el firmware (patrón v2: 2,5 s al arrancar más
   2 s cada 5 s) y, si sale mal, pulsar RESET y grabar dentro de la ventana, o
   hacer `minichlink ... -u` (borrado completo del chip). Ver `references/hardware.md`.
8. **16 kB de flash y 2 kB de RAM.** Es un RV32EC (sin multiplicación por
   hardware, `float` caro). Evita `String` y `Serial` si no hacen falta.
9. **Nunca grabes con el monitor serie (o cualquier otro programa) abierto sobre
   `/dev/ttyACM0`:** el puerto está ocupado y la grabación falla.
10. **Graba solo cuando `pio run` pase.** Si no compila, no toques la placa.

## 3. Lo más rápido: compilar y grabar

```sh
cd ch32v003-blink
pio run                # compilar
pio run -t upload      # grabar  (platformio.ini -> ./flash.sh -> minichlink)
```

`flash.sh` busca la placa por su **ID de USB**, no por número de puerto
(`/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00`), así que da igual si el
`ttyACM` cambia. Se puede forzar otro puerto con la variable `PUERTO`.

Grabación a mano, sin PlatformIO:

```sh
tools/ch32v003fun/minichlink/minichlink -C ardulink \
  -c /dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00 \
  -w ch32v003-blink/.pio/build/ch32v003f4p6/firmware.bin flash -b
```

## 4. Si te piden crear un proyecto nuevo

`platformio.ini` **NO viene listo** desde el asistente de PlatformIO: solo pone
`platform`, `board` y `framework`, y con eso **compila pero no graba** (usaría
`wch-link`, que espera un WCH-LinkE original).

**No improvises: usa las plantillas de esta skill.** Lo más rápido:

```sh
.opencode/skills/ch32v003-wchlink-ch549/scripts/nuevo-proyecto.sh /ruta/al/proyecto-nuevo
```

Deja el proyecto listo y **autocontenido**: `platformio.ini` sin rutas,
`flash.sh` ejecutable, `src/main.cpp` con el blink seguro de PC0, `.vscode/`
(tareas y ajustes), `.gitignore` y `minichlink` descargado dentro de
`<proyecto>/tools/`. (No sobreescribe nada.)

🚫 **Nunca pongas rutas absolutas en `upload_command`** (ni `MINICHLINK=/home/…`).
Las dos líneas correctas son siempre estas dos, tal cual:

```ini
upload_protocol = custom
upload_command  = ./flash.sh $SOURCE
```

Si el proyecto necesita una herramienta, **se descarga dentro del propio
proyecto**: de eso se encarga `flash.sh` (`--preparar` para forzarlo).

Tampoco uses `upload_protocol = wch-link` / `minichlink` / `wlink` / `isp`:
ninguno entiende nuestro programador (comprobado: minichlink sin `-C ardulink`
responde `Could not initialize any supported programmers`).

Antes de dar el trabajo por hecho: `pio run` (tiene que decir `SUCCESS`),
`SIMULAR=1 ./flash.sh`, y que el `.ini` **no** tenga rutas absolutas:

```sh
grep -nE "/(home|Users|root)/" platformio.ini && echo "MAL: hay rutas absolutas"
```

Receta completa, trampas y cómo mantener la plantilla sincronizada, en
`references/proyecto-nuevo.md`.

## 5. Antes de tocar nada de hardware: comprueba el entorno

```sh
.opencode/skills/ch32v003-wchlink-ch549/scripts/diagnostico.sh
```

Comprueba que la placa aparece, que el usuario está en `dialout`, que
`minichlink` existe y que el puerto está libre.

## 6. Dónde está la verdad

El informe [`README_ES.md`](../../../../README_ES.md) (y su traducción
[`README.md`](../../../../README.md)) es la **fuente de la verdad**: contiene el
diagnóstico completo del programador, el porqué de cada decisión y las
referencias. Antes de contradecir algo de estas referencias, comprueba el
informe. La versión del chip, el pinout y el protocolo están documentados allí
con evidencia de hardware.

## 7. Al publicar o cambiar el repositorio

- Se publica **todo excepto `.pio/`** (única entrada del `.gitignore`).
- Los **UID de hardware** que aparezcan en texto deben ir **anonimizados**.
- Hay que mantener la **atribución** a `ch549-link` (MIT) y la tabla de
  licencias de terceros de `tools/` en los dos informes.
- `tools/` contiene copias de herramientas de terceros con sus propias
  licencias; ojo: **`isp55e0` es GPL-3.0**.
