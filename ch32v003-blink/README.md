# CH32V003F4P6 — parpadeo de PC0

Proyecto mínimo para compilar y **programar** una placa CH32V003F4P6 desde Linux,
usando un **WCH-Link antiguo (CH549) reflasheado** como programador SWIO.

- Placa: `genericCH32V003F4P6` — 16 kB flash / 2 kB RAM, RV32EC @ 48 MHz
- Framework: `arduino` con el core de WCH (`board_build.core = openwch`)
- Grabación: `pio run -t upload` → `flash.sh` → `minichlink` (protocolo ardulink)

> El informe completo del proceso, el diagnóstico del programador y las
> referencias están en [`../README_ES.md`](../README_ES.md) — y su traducción al
> inglés en [`../README.md`](../README.md).

---

## 1. Cableado (solo 3 hilos)

| Placa CH32V003F4P6 | Programador WCH-Link | Nota |
|---|---|---|
| `GND` | `GND` | |
| `VCC` | `3V3` | la placa se alimenta del programador |
| `SWIO` (PD1) | `SWDIO` | línea de 1 hilo |

- **`SWCLK` no se conecta**: el CH32V003 no tiene pin de reloj.
- Selector de tensión del programador en **3V3**, nunca 5V.
- **Hace falta una resistencia de 1 kΩ** entre `SWDIO` y `3V3` en el
  programador. Sin ella aparecen IDs basura y fallan las escrituras.

## 2. Compilar y grabar

```bash
pio run                 # compila
pio run -t upload       # compila y graba
pio device monitor      # monitor serie (115200, requiere USB-TTL en PD5/PD6)
```

El proyecto usa `upload_protocol = custom` con `flash.sh`, porque el protocolo
`wlink` de PlatformIO solo funciona con un WCH-LinkE original.

### Grabar a mano

```bash
M=~/RiscV/tools/ch32v003fun/minichlink/minichlink
$M -C ardulink -c /dev/ttyACM0 -w .pio/build/ch32v003f4p6/firmware.bin flash -b
```

### Comprobar que el programador está listo

```bash
lsusb | grep 1209:c550      # debe aparecer
$M -C ardulink -c /dev/ttyACM0 -i
```

Salida esperada: `Ardulink: synced.` → `Detected CH32V003` → `Read protection: disabled`.

## 3. El programa

`src/main.cpp` parpadea **`PC0`** a 5 Hz (100 ms on / 100 ms off).

### ¿Y el LED de la placa?

**No está en `PC0`.** El LED rojo de la PCB está en **`PD1`**, es **activo-bajo** y
**comparte pin con `SWIO`** (la línea de programación). Por eso parpadea durante cada
grabación. **Confirmado en hardware** (ver §9.3 y §13.10 del informe). Usarlo desde el
programa obliga a desactivar la depuración (ver `extras/led_rojo_pd1.cpp`, ya probado)
y deja la placa en un estado frágil — **no se recomienda**.

Para pruebas visuales, usa un LED externo:

```
PC0 ── 680 Ω ── (ánodo) LED (cátodo) ── GND
```

### Referencias en `extras/` (no se compilan)

| Archivo | Qué hace |
|---|---|
| `extras/escaneo_pines.cpp` | Enciende los 16 GPIO uno a uno para localizar un LED externo |
| `extras/led_rojo_pd1.cpp` | Experimento del LED rojo en `PD1` + cómo liberarlo de SDI |

Para probar uno de ellos:

```bash
cp extras/escaneo_pines.cpp src/main.cpp
pio run -t upload
```

Orden del escaneo:

```
 1 PC0    5 PC4    9 PD0   13 PD5
 2 PC1    6 PC5   10 PD2   14 PD6
 3 PC2    7 PC6   11 PD3   15 PA1
 4 PC3    8 PC7   12 PD4   16 PA2
```

(`PD1` y `PD7` se omiten a propósito.)

## 4. Notas

- **Pines a evitar**: `PD1` (SWIO **y LED rojo**) y `PD7` (NRST).
- `LED_BUILTIN` **no está definido** en este core: declara el pin a mano.
- El LED verde es de alimentación; no es un GPIO.
- `Serial` usa `PD5` (TX) y `PD6` (RX). El programador **no** hace de puente
  serie: para leer la salida hace falta un USB-TTL en esos pines.
- Leer la flash con `minichlink -r` deja la CPU en *halt*; hay que salir con `-b`.
- Si `pio run -t upload` falla, ejecuta `./flash.sh` a mano para ver el error real.
- Si el chip deja de responder (`HARTINFO: ffffffff`), desbloquéalo con
  `minichlink -C ardulink -c /dev/ttyACM0 -u` (§12.4 del informe).

## 5. Recuperar el programador

Si el CH549 se queda en un estado raro, el bootloader está en ROM y siempre se
puede recuperar:

```bash
# 1) USB fuera, jumper en J1, USB dentro  -> debe salir 4348:55e0
# 2) Regrabar el firmware SWIO:
cd ~/RiscV/tools/wch-link-ch549
./isp55e0 -f firmware/swio.bin
# 3) Quitar el jumper y reenchufar
```

Volver al firmware de fábrica (pierde el soporte de CH32V003):

```bash
./isp55e0 -f firmware/wch-riscv.bin   # modo RISC-V
./isp55e0 -f firmware/wch-arm.bin     # modo ARM / CMSIS-DAP
```

---

## 6. Créditos y licencia

La solución técnica de fondo **no es mía**:

| Aportación | Autor | Licencia |
|---|---|---|
| Firmware SWIO del CH549, protocolo ISP y documentación | [`ch549-link`](https://github.com/e-labInnovations/ch549-link) (e-labInnovations) | MIT |
| `minichlink` y el protocolo *ardulink* | [`ch32v003fun`](https://github.com/cnlohr/ch32v003fun) (CNLohr) | MIT |
| Flasheador del bootloader CH55x `isp55e0` | [`frank-zago`](https://github.com/frank-zago/isp55e0) | **GPL-3.0** |
| Plataforma y core Arduino | [`platform-ch32v`](https://github.com/Community-PIO-CH32V/platform-ch32v) / [`arduino_core_ch32`](https://github.com/openwch/arduino_core_ch32) | — |
| **Este proyecto** (código, `flash.sh`, informe) | carlymx | **MIT** (ver [`../LICENSE`](../LICENSE)) |

El repositorio incluye copias de esas herramientas en `../tools/`, **con sus
propias licencias y avisos de copyright** (ver la tabla completa de licencias de
terceros en el informe, §"Licencias de las herramientas incluidas"). Ojo:
`isp55e0` es **GPL-3.0**.
