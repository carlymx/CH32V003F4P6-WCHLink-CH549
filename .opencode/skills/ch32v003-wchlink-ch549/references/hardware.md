# Hardware: placa, programador, pines y trampas

## 1. La placa

| Dato | Valor |
|---|---|
| Chip | **CH32V003F4P6** (WCH / Nanjing Qinheng) |
| Núcleo | **RV32EC** @ 48 MHz (RISC-V, sin multiplicación por hardware) |
| Flash / RAM | **16 kB** / **2 kB** |
| Encapsulado | LQFP20 (Twen-CH32V003F4P6 y similares) |
| Framework | Arduino sobre el core de WCH (`board_build.core = openwch`) |
| Entorno PlatformIO | `board = genericCH32V003F4P6`, `platform = ch32v` |

## 2. El programador

Un **WCH-Link antiguo basado en CH549**, reflasheado con el firmware **SWIO** del
proyecto [`ch549-link`](https://github.com/e-labInnovations/ch549-link).

- Se enumera como USB **`1209:c550`** ("CH55xduino", del proyecto *CH55xduino*)
  y aparece como `/dev/ttyACM*` (aquí `/dev/ttyACM0`).
- Habla el protocolo **ardulink** por USB-CDC; se maneja con `minichlink -C ardulink`.
- **No** es un WCH-LinkE: el protocolo `wlink` **no** funciona con él.
- Enlace estable del puerto:
  `/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00`

> Restaurar el firmware de fábrica (`wch-riscv.bin` con `isp55e0`) **pierde el
> soporte del CH32V003**. El SWIO es lo que hace que este programador sirva.

## 3. Cableado (solo 3 hilos)

```text
   CH32V003F4P6            WCH-Link CH549 (SWIO)
   ┌────────────┐          ┌──────────────┐
   │   GND  ────┼──────────┼──── GND      │
   │   VCC  ────┼──────────┼──── 3V3      │   (la placa se alimenta del Link)
   │   SWIO ────┼────+─────┼──── SWDIO    │
   └────────────┘    │     │              │
                     │     │  SWCLK  (no se conecta)
                  [1 kΩ]
                     │
                   3V3     (pull-up en el lado del programador)
```

- **`SWCLK` no se conecta**: el CH32V003 usa depuración de un solo hilo.
- Selector de tensión del programador en **3V3**, nunca 5 V.
- Hace falta una **resistencia de 1 kΩ entre `SWDIO` y `3V3`** en el lado del
  programador. Sin ella aparecen IDs basura y las escrituras fallan.

## 4. Mapa de pines útil

| Pin | Nombre en la placa | Uso | ¿Se puede usar? |
|---|---|---|---|
| `PC0` | D2 | GPIO libre | **Sí** — aquí está el LED externo del firmware por defecto |
| `PD1` | D11 | **SWIO** + **LED rojo** | **No**, salvo que desactives SDI (ver §5) |
| `PD7` | D17 | **NRST** (reset) | **No** |
| `PD5` | D5 | `Serial` TX | Sí, si no usas `Serial` |
| `PD6` | D6 | `Serial` RX | Sí, si no usas `Serial` |

- **`LED_BUILTIN` no está definido** en esta placa/core.
- El LED rojo **no** está en PC0: está en **PD1**.

### Test de LED recomendado (activo-alto, sin sustos)

```text
PC0 ── 680 Ω ── ánodo ── cátodo ── GND
```

## 5. El LED rojo y PD1 (la parte con trampa)

El LED rojo de la placa está en **`PD1`**, **activo-bajo** (se enciende cuando
PD1 está a LOW), y **comparte pin con la línea SWIO**.

### Desactivar SDI para liberar PD1

Sin desactivar SDI, PD1 no se comporta como GPIO normal. Para liberarlo:

```c
/* Registros directos */
RCC->APB2PCENR |= RCC_AFIOEN;
AFIO->PCFR1 = (AFIO->PCFR1 & ~0x07000000) | 0x04000000;   /* SWJ_CFG = 0b100 */

/* Equivalente con la SPL (Standard Peripheral Library) */
GPIO_PinRemapConfig(GPIO_Remap_SDI_Disable, ENABLE);      /* valor 0x00300400 */
```

### ⚠️ La trampa: leer `GPIOD->INDR` con SDI activo devuelve 0

**No** se puede leer `GPIOD->INDR` para saber el nivel de PD1 mientras SDI está
activo: devuelve `0` siempre. Eso producía un **falso "modo seguro"** en la
versión 1 del experimento. La versión 2 (en
`ch32v003-blink/extras/led_rojo_pd1.cpp`, **verificada en hardware**) lo resuelve
desactivando SDI primero.

### Si desactivas SDI, el programador deja de engancharse

Con SDI desactivado el chip ya no responde al programador hasta que el firmware
le devuelva el control. El patrón que funciona (v2) es abrir **ventanas de
arranque** en las que el chip esté "escuchando":

| Ventana | Cuándo |
|---|---|
| **2,5 s** | justo al arrancar (tras reset o encendido) |
| **2 s cada 5 s** | después, de forma indefinida |

Así siempre hay margen para grabar. Si aun así no engancha:

1. Pulsa **RESET** (o quita y pon alimentación) y graba **dentro** de la ventana.
2. Si sigue sin responder: `minichlink ... -u` (borrado completo; el chip queda
   con la flash vacía y SDI activo de nuevo).

## 6. Alimentación y consumo

- La placa puede alimentarse **del propio programador** por el pin `3V3`.
- Si algo se calienta o el programador se reinicia solo, revisa que **no** haya
  cortocircuito en SWIO→GND y que el selector esté en 3V3.
