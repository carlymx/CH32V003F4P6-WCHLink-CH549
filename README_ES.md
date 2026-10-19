# Programar un CH32V003F4P6 desde Linux con un WCH-Link antiguo (CH549)

**Informe técnico completo — hallazgos, procedimiento y estado final**

> 🌐 **Idioma:** Español · **[Read this document in English →](README.md)**

![Placa CH32V003F4P6 — diagrama de pines](CH32V003F4P6_PCB.jpg)

| | |
|---|---|
| **Fecha** | 19 de octubre de 2026 |
| **Sistema** | Linux Mint 22.3 (x86_64), kernel 6.14.0-37 |
| **Placa objetivo** | CH32V003F4P6 "core board" (AliExpress 1005008860345338) |
| **Programador** | WCH-Link antiguo con MCU **CH549** (AliExpress 1005010743352061) |
| **Resultado** | ✅ Programa compilado, grabado y ejecutándose |
| **Coste extra** | 0 € (solo una resistencia de 1 kΩ y un jumper) |

---

## Créditos y atribución

**Este trabajo no habría sido posible sin [`ch549-link`](https://github.com/e-labInnovations/ch549-link)**
([e-labInnovations](https://github.com/e-labInnovations), licencia MIT).

Ese proyecto es el que descubrió y demostró que el CH549 **sí puede** programar el
CH32V003, escribió el firmware SWIO, documentó el protocolo ISP del bootloader y
publicó el flasheador web. Todo el mérito técnico de la solución es suyo.

| Aportación | Autor |
|---|---|
| Firmware SWIO para CH549 (`swio.bin`), protocolo y documentación | **ch549-link** (MIT) |
| Herramienta `minichlink` y protocolo ardulink | [ch32v003fun](https://github.com/cnlohr/ch32v003fun) (MIT) / [arduino-ch32v003-swio](https://gitlab.com/BlueSyncLine/arduino-ch32v003-swio) |
| Flasheador del bootloader CH55x | [isp55e0](https://github.com/frank-zago/isp55e0) (GPL-3.0) |
| Plataforma y core Arduino | [platform-ch32v](https://github.com/Community-PIO-CH32V/platform-ch32v) / [arduino_core_ch32](https://github.com/openwch/arduino_core_ch32) |
| **Este informe**: verificación en hardware real, procedimiento reproducible, integración con PlatformIO (`flash.sh`) y notas de diagnóstico | Documentación derivada — **licencia MIT** (ver [`LICENSE`](LICENSE)) |

> Si reutilizas o publicas este informe, **mantén el enlace a `ch549-link`**. La
> parte difícil la hicieron ellos.

## Licencia

Este informe se publica bajo la **[licencia MIT](LICENSE)**.

Puedes usarlo, copiarlo, modificarlo y redistribuirlo (incluso comercialmente)
siempre que conserves el aviso de copyright y **mantengas el enlace a
[`ch549-link`](https://github.com/e-labInnovations/ch549-link)**, cuyo trabajo es
la base técnica de todo esto.

```
MIT License
Copyright (c) 2026 carlymx
```

> ℹ️ **Nota:** el texto completo y legal está en [`LICENSE`](LICENSE). Este
> informe *documenta* el uso de herramientas de terceros con sus propias licencias
> (`ch549-link` y `minichlink` son MIT; `isp55e0` es GPL-3.0); la licencia MIT de
> arriba cubre **este documento y los scripts propios del proyecto**.

### Licencias de las herramientas incluidas (`tools/`)

El repositorio **incluye copias** de herramientas de terceros dentro de `tools/`.
**No son mías**: conservan su licencia, su aviso de copyright y, cuando existe, su
propio fichero `LICENSE` en su carpeta.

| Herramienta | Ubicación | Autor | Licencia | Fuente original |
|---|---|---|---|---|
| `ch32v003fun` / `minichlink` | `tools/ch32v003fun/` | [CNLohr](https://github.com/cnlohr) | MIT | <https://github.com/cnlohr/ch32v003fun> |
| `isp55e0` (binario) | `tools/wch-link-ch549/isp55e0` | [frank-zago](https://github.com/frank-zago) | **GPL-3.0** | <https://github.com/frank-zago/isp55e0> |
| `wlink-iap` | `tools/wlink-iap/` | [cjacker](https://github.com/cjacker) | MIT | <https://github.com/cjacker/wlink-iap> |
| `ch549-link` (copia) | `tools/wch-link-ch549/ch549-link/` | [e-labInnovations](https://github.com/e-labInnovations) | MIT | <https://github.com/e-labInnovations/ch549-link> |
| Firmwares del WCH-Link (`swio.bin`, `wch-riscv.bin`, `wch-arm.bin`) | `tools/wch-link-ch549/firmware/` | WCH / ch549-link | según su origen | — |

> ⚖️ **Sobre `isp55e0` (GPL-3.0):** se incluye ya compilado por comodidad, pero su
> **código fuente completo** está en el enlace de la tabla y cualquiera puede
> obtenerlo y recompilarlo desde ahí. Si redistribuyes este repositorio, **mantén
> esta tabla y los enlaces**.
>
> 🏷️ **Marca y firmware:** los nombres *WCH*, *WCH-Link* y los firmwares del
> programador pertenecen a **WCH (Nanjing Qinheng Microelectronics)**. Aquí solo se
> documenta su uso y se redistribuyen copias a las que se tuvo acceso legítimo.

---


## Índice

0. [Créditos y atribución](#créditos-y-atribución)
   - [Licencia](#licencia)
   - [Licencias de las herramientas incluidas](#licencias-de-las-herramientas-incluidas-tools)
1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [El problema](#2-el-problema)
3. [Diagnóstico: cómo identificamos el programador](#3-diagnóstico-cómo-identificamos-el-programador)
4. [La solución: reflashear el CH549](#4-la-solución-reflashear-el-ch549)
5. [Hardware: modificaciones necesarias](#5-hardware-modificaciones-necesarias)
6. [Procedimiento paso a paso](#6-procedimiento-paso-a-paso)
7. [Verificación y resultado](#7-verificación-y-resultado)
8. [Uso diario: compilar y grabar](#8-uso-diario-compilar-y-grabar)
9. [Referencia de pines de la placa](#9-referencia-de-pines-de-la-placa)
10. [Guía para agentes de IA](#10-guía-para-agentes-de-ia)
11. [Solución de problemas](#11-solución-de-problemas)
12. [Reversión y recuperación](#12-reversión-y-recuperación)
13. [Hallazgos técnicos y notas](#13-hallazgos-técnicos-y-notas)
14. [Referencias](#14-referencias)
15. [Inventario de archivos](#15-inventario-de-archivos)

### Novedades de la revisión del 19/10/2026

- **[§9.3](#93-leds-de-la-placa) / [§9.4](#94-identificación-de-la-placa) / [§13.10](#1310-usar-pd1-como-gpio-por-qué-no-basta-pinmode-y-por-qué-no-conviene)**
  — **LED rojo de la placa confirmado y probado: está en `PD1`, activo-bajo y
  compartido con `SWIO`.** Incluye el conflicto entre el esquemático de la familia
  (`PC0`) y la documentación de WCH (`PD1`), las **tres pruebas** que lo resolvieron,
  **por qué falló el primer experimento** (leer `PD1` con SDI activo) y cómo
  **liberar `PD1` de SDI** (`AFIO->PCFR1` / `GPIO_Remap_SDI_Disable`) y recuperar la
  placa con `minichlink -u`.
- **[§7.1.1](#711-prueba-de-frecuencia)** — Validación con LED externo en `PC0`
  (1 Hz y 5 Hz).
- **[§10.4](#104-receta-descubrir-el-pin-de-un-led) / [§15](#15-inventario-de-archivos)**
  — El escaneo de pines pasa a `extras/escaneo_pines.cpp`; el experimento del LED
  rojo vive en `extras/led_rojo_pd1.cpp`.
- **[§12.4](#124-desbloquear-el-ch32v003-unbrick)** — Procedimiento de *unbrick*
  probado en hardware real.

---

## 1. Resumen ejecutivo

Se consiguió programar un **CH32V003F4P6** desde Linux usando un **WCH-Link antiguo basado en CH549**, un programador que WCH marca oficialmente como **no compatible** con ese microcontrolador.

La clave: el **hardware sí es capaz**; lo que no sirve es el **firmware de fábrica**. El CH549 implementa el protocolo de depuración **SDI de 2 hilos** (SWDIO + SWCLK), pero el CH32V003 usa **SWIO de 1 solo hilo** y no tiene pin de reloj. Sustituyendo el firmware del programador por el del proyecto [`ch549-link`](https://github.com/e-labInnovations/ch549-link), el CH549 pasa a ser un programador SWIO que habla el protocolo **ardulink** por USB-CDC, y `minichlink` lo maneja sin modificaciones.

**Requisitos reales:**

- Una resistencia de **1 kΩ** entre `SWDIO` y `3V3` en el programador (obligatoria).
- Un **jumper en J1** del programador (modo BOOT) solo durante el reflasheo.
- 3 cables al microcontrolador: `GND`, `3V3`, `SWDIO`→`SWIO`.
- **Nada de software propietario**: todo con herramientas libres (`isp55e0`, `minichlink`, PlatformIO).

**Hallazgos adicionales (detalle en §9.3, §9.4 y §13.10):**

- El **LED rojo** de la placa **no está en `PC0`** como dicen muchos pinouts: está
  en **`PD1`**, es **activo-bajo** y **comparte pin con `SWIO`**, la línea de
  programación (por eso parpadea solo durante las grabaciones). **Confirmado en
  hardware** con tres pruebas: no responde a `PC0` a 1 Hz; el LED que parpadea al
  grabar está en la PCB **del microcontrolador**; y el sketch que libera `PD1` de SDI
  **enciende el LED rojo a voluntad** (§9.3, §13.10).
- Para cualquier prueba visual, **usa un LED externo en `PC0`** (activo-alto):
  funciona a la primera y es 100 % seguro.
- Se documenta además **cómo liberar `PD1` del módulo de depuración** (desactivando
  SDI vía `AFIO->PCFR1` / `GPIO_Remap_SDI_Disable`), **por qué el primer intento
  falló** (leer `GPIOD->INDR` con SDI activo devuelve siempre `0`) y **cómo
  recuperar la placa con `minichlink -u`** si se bloquea (§12.4, §13.10).

---

## 2. El problema

### 2.1 Síntomas iniciales

Con el programador de fábrica, cualquier intento de comunicación fallaba:

| Herramienta | Error |
|---|---|
| `wlink status` | `Error: USB error: Input/Output Error` |
| `minichlink` (ch32v003fun) | `Error sending WCH command (on send): 81 0d 01 ff` |
| `openocd` (fork WCH) | `libusb_bulk_write error: LIBUSB_ERROR_TIMEOUT` + `Error: unknow WCH-LINK` |
| Escritura directa libusb (EP1 y EP2) | `LIBUSB_ERROR_TIMEOUT`, 0 bytes transferidos |
| `wlink-iap -i` | `Found device : Unknown adapter` |

### 2.2 Por qué fallaba

El programador se identificaba correctamente por USB:

```
idVendor     0x1a86  (QinHeng Electronics)
idProduct    0x8010  (WCH-Link)
bcdUSB       1.10
bcdDevice    2.01    ← firmware v2.01
iProduct     "WCH-Link"
iSerial      "0001A0000001"
```

Pero su firmware **no respondía a ninguna orden** en ninguno de los endpoints del fabricante. No era un problema de permisos, ni de cable, ni del microcontrolador: el firmware era demasiado antiguo (v2.01, la versión "combinada ARM+RV") y hablaba un protocolo que ninguna herramienta moderna entiende.

### 2.3 La incompatibilidad de fondo

El manual oficial de WCH (*WCH-Link 使用说明*, tabla "Link 支持芯片型号") es tajante:

| Chip | WCH-Link (CH549) | WCH-LinkE | WCH-DAPLink | WCH-LinkW |
|---|:---:|:---:|:---:|:---:|
| **CH32V003** / CH32V002_004_005_006_007 / CH32X035 / CH32L103 / CH643 / CH32V317 / CH32M007 | ❌ | ✅ | ❌ | ✅ |
| CH32V10x / CH32V20x / CH32V30x | ✅ | ✅ | ❌ | ✅ |
| CH569 / CH573 / CH583 | ✅ | ✅ | ❌ | ❌ |

La causa técnica la explica el propio proyecto `ch549-link`:

> El CH32V003 se depura por **SWIO de 1 hilo** en `PD1`. **No hay pin de reloj.** El firmware de WCH para el CH549 solo implementa **SDI de 2 hilos** (`SWDIO` + `SWCLK`), y por eso WCH marca el CH32V003 como no soportado en este hardware.

Y lo verificaron experimentalmente: en modo RISC-V el firmware de fábrica **acepta** `CHIP_CH32V003` (0x09) y responde `82 0c 01 01`, lo que parece un reconocimiento correcto. Pero **no lo es**: devuelve exactamente la misma respuesta para cualquier byte, válido o sin sentido. El firmware "estampa" el tipo de chip sin comprobarlo; después el *attach* falla igual con piezas de 1 y de 2 hilos.

**Conclusión del diagnóstico:** el hardware no es el problema; el firmware sí. Y como el bootloader del CH549 vive en **ROM**, es imposible "brickearlo" y se puede reflashear siempre.

---

## 3. Diagnóstico: cómo identificamos el programador

Estas pruebas fueron las que permitieron llegar al diagnóstico. Se conservan aquí porque son reutilizables.

### 3.1 Descriptor USB

```bash
lsusb -d 1a86:8010 -v
```

Claves para identificar el modelo:

| Campo | Valor observado | Interpretación |
|---|---|---|
| `bcdUSB` | `1.10` | USB full-speed de 8051 (el CH32V305 usa `2.00`) |
| `bcdDevice` | `2.01` | firmware v2.01 "combinado ARM+RV" (solo existió para CH549) |
| `iSerial` | `0001A0000001` | serie genérica de los WCH-Link antiguos |
| `bMaxPacketSize0` | `8` | típico de 8051 |
| Interfaces | 3: vendor (EP1/EP2 64 B), CDC control, CDC data | estructura del firmware antiguo |

### 3.2 Entrar en el bootloader y preguntarle al chip

Con el jumper **J1** puesto al arrancar, el dispositivo pasa a `4348:55e0` y responde al protocolo ISP de WCH:

```bash
./isp55e0
```

```
Found device CH549
Bootloader version 2.4.0
Unique chip ID XX-XX-XX-XX-XX-XX-XX-XX
Current config-bits    00-00-00-00-20-00-00-00-00-d2-c7-b1
```

**Esta es la prueba definitiva:** el MCU del programador es un **CH549** con bootloader **2.4.0**.

> 🔒 **Nota de privacidad:** el `Unique chip ID` va enmascarado a propósito (es único
> de cada unidad). Los `config-bits`, en cambio, **no identifican al chip**: son sus
> opciones de configuración (arranque/protección) junto con el *checksum* que calcula
> el propio bootloader, y los reporta igual cualquier CH549 con la misma configuración.
> El `iSerial` del descriptor USB (`0001A0000001`) tampoco es único: es una constante
> fija del firmware de WCH, idéntica en todas las unidades.

### 3.3 Tabla de identificación por USB

Útil para saber en qué estado está el programador en cualquier momento:

| VID:PID | Estado |
|---|---|
| `1a86:8010` | WCH-Link de fábrica, modo RISC-V (firmware antiguo) |
| `1a86:8011` | WCH-Link de fábrica, modo ARM/DAP |
| `1a86:8012` | WCH-Link en modo DAP (modelos nuevos) |
| `4348:55e0` | **Bootloader ISP** (jumper J1 puesto al arrancar) |
| `1209:c550` | **Firmware SWIO de ch549-link** (el que queremos) |

### 3.4 Comando para preguntar la variante (si el firmware responde)

En un WCH-Link que sí conteste, el comando `81 0d 01 01` devuelve `82 0d 04 <mayor> <menor> <variante>`:

| Variante | Modelo |
|---|---|
| `0x01` | CH549 (WCH-Link antiguo) |
| `0x02` | CH32V307 |
| `0x03` | CH32V203 (WCH-LinkS) |
| `0x12` | **WCH-LinkE** (ya soporta CH32V003, no hay que hacer nada) |

---

## 4. La solución: reflashear el CH549

### 4.1 Qué es `ch549-link`

[`e-labInnovations/ch549-link`](https://github.com/e-labInnovations/ch549-link) (MIT) sustituye el firmware del CH549 por un depurador SWIO escrito en C para SDCC. El resultado:

- Enumera como **USB-CDC** (`1209:c550`).
- Habla el protocolo **ardulink** (de [`arduino-ch32v003-swio`](https://gitlab.com/BlueSyncLine/arduino-ch32v003-swio)).
- `minichlink` **estándar** lo maneja sin modificaciones.
- Usa `P1.1` del CH549 (pad `SWDIO`) para bit-bang del SWIO a 48 MHz.

### 4.2 Por qué funciona si WCH decía que no

El CH549 es un **E8051 a 48 MHz** = 20,8 ns por ciclo, **3× más fino** que el AVR a 16 MHz que ya hacía bit-bang de SWIO con éxito. La velocidad nunca fue el obstáculo: era solo que el firmware de WCH no implementaba el protocolo de 1 hilo.

Tiempos medidos en el CH549 (documentados por el proyecto):

| | total | fase baja | en T (125 ns) |
|---|---|---|---|
| pulso corto | 28 ciclos (583 ns) | ~10 ciclos (208 ns) | 1,7 T |
| pulso largo | 70 ciclos (1458 ns) | ~50 ciclos (1042 ns) | 8,3 T |
| alto entre bits | — | ~18 ciclos (375 ns) | 3 T |

### 4.3 El firmware

| Archivo | Tamaño | SHA-256 | Uso |
|---|---|---|---|
| `swio.bin` | 4345 B | `bbfc3b39063336a1c4b6ae0286c573e7b90c294005359338c2e7c1a04c212d23` | **Programador SWIO** |
| `wch-riscv.bin` | 45784 B | `eee8b4709ad5080a84ac2da80fbdbea868a64bb280f2ed80943f005c50463cba` | Restaurar de fábrica (RISC-V) |
| `wch-arm.bin` | 27734 B | `3cf143a3b6061e8f6a4ca7ee809fffe007219cad062adca259d245f996662284` | Restaurar modo ARM/CMSIS-DAP |

Verificación del vector de reset de `swio.bin`: primeros bytes `02 00 b6` = `LJMP 0x00b6` (válido).

---

## 5. Hardware: modificaciones necesarias

### 5.1 Resistencia de 1 kΩ (obligatoria)

```
        SWDIO (pad del conector)
             │
            1 kΩ
             │
           +3V3
```

**Sin ella el programador es inestable:** IDs de chip basura y escrituras fallidas. El proyecto lo verificó quitándola y volviéndola a poner.

- Se suelda **entre el pin `SWDIO` y el pin `3V3`** del conector del programador.
- **Nunca** al 5V.
- Es un *pull-up* normal de la línea; dejarla puesta de forma permanente es correcto.

### 5.2 Jumper J1 (modo BOOT)

El manual oficial de WCH lo confirma:

> *"To update the Link into BOOT mode (short connect **J1** in Figure 1 **or** long press BOOT key and then power up the Link)"*

En esta variante de placa, el pulsador táctil de otros clones se sustituyó por el conector **J1** (serigrafiado justo debajo del chip principal). **No hace falta ningún pulsador**: basta un jumper de 2 pines.

- El estado de J1 **solo se lee al arrancar** (el *pull-up* de D+ se muestrea en el reset).
- Se pone con el USB desenchufado, se enchufa, y ya se puede quitar.
- **Con J1 puesto y el firmware SWIO ya grabado no pasa nada**: el firmware SWIO no usa ese pin.

### 5.3 Selector de tensión

Poner en **3V3**, nunca en 5V. El CH549 maneja lógica de 3,3 V y el CH32V003 también.

### 5.4 Cableado al CH32V003 (solo 3 hilos)

| Placa CH32V003F4P6 | Programador WCH-Link | Nota |
|---|---|---|
| `GND` | `GND` | |
| `VCC` | `3V3` | la placa se alimenta del programador |
| `SWIO` (PD1) | `SWDIO` | línea de 1 hilo |
| — | `SWCLK` | **NO conectar** (el CH32V003 no tiene reloj) |

---

## 6. Procedimiento paso a paso

> 📁 **Rutas de ejemplo:** en todo el informe se supone que el repositorio está en
> `~/RiscV`. Ajusta esa ruta a la tuya. El script `flash.sh` **no** depende de ella:
> localiza las herramientas a partir de su propia ubicación.

### 6.1 Preparar las herramientas

```bash
# 1) minichlink (soporta ardulink)
git clone --depth 1 https://github.com/cnlohr/ch32v003fun
cd ch32v003fun/minichlink

# Compilar SIN libudev (evita el paquete libudev-dev):
gcc -o minichlink minichlink.c pgm-wch-linke.c pgm-wch-isp.c nhc-link042.c \
    ardulink.c serial_dev.c minichgdb.c chips.c ch5xx.c stub_programmers.c \
    -lpthread -lusb-1.0 -O0 -g3 -Wall -Wno-unused-function \
    -DCH32V003 -I. -DMINICHLINK -DVERSION='"local"'

# 2) isp55e0 (flasheador del bootloader CH549)
git clone --depth 1 https://github.com/frank-zago/isp55e0
cd isp55e0 && make
```

> **Nota sobre `libudev`:** el `make` estándar de minichlink falla si no está
> `libudev-dev`. El comando de arriba omite `pgm-esp32s2-ch32xx.c` y
> `pgm-b003fun.c` (los programadores ESP32-S2 y B003Fun, que no necesitamos) y
> los sustituye por `stub_programmers.c` con dos funciones que devuelven 0.
> También se puede instalar `libudev-dev` y usar `make` directamente.

### 6.2 Grabar el firmware SWIO en el CH549

```bash
# 1) Con el USB DESENCHUFADO: poner el jumper en J1
# 2) Enchufar el USB (en un puerto que funcione)
# 3) Comprobar que aparece el bootloader:
lsusb | grep 4348:55e0
#    -> Bus 001 Device 043: ID 4348:55e0 WinChipHead

# 4) Confirmar que es un CH549:
cd isp55e0 && ./isp55e0
#    -> Found device CH549
#    -> Bootloader version 2.4.0

# 5) Grabar (borra, escribe y verifica):
./isp55e0 -f /ruta/a/swio.bin
#    -> Code flashing successful
#    -> Firmware is good

# 6) Quitar el jumper J1 y reenchufar el USB
```

Tras el reflasheo, el dispositivo debe aparecer como:

```bash
lsusb | grep 1209:c550
# -> Bus 001 Device 044: ID 1209:c550 Generic CH55xduino
ls -la /dev/ttyACM0
# -> crw-rw----+ 1 root dialout 166, 0 /dev/ttyACM0
```

### 6.3 Verificar que ve el microcontrolador

```bash
MINICHLINK=~/RiscV/tools/ch32v003fun/minichlink/minichlink
$MINICHLINK -C ardulink -c /dev/ttyACM0 -i
```

Salida esperada:

```
minichlink version - local
Opening serial port /dev/ttyACM0 at 115200 baud.
Ardulink: synced.
Ardulink: target power 1
Detected CH32V003
Flash Storage: 16 kB
Part UUID: XX-XX-XX-XX-XX-XX-XX-XX
Part Type: 00-30-05-10
Read protection: disabled
Interface Setup
USER/RDPR  : 08f7/5aa5
DATA1/DATA0: 00ff/00ff
WRPR1/WRPR0: 00ff/00ff
WRPR3/WRPR2: 00ff/00ff
R32_ESIG_UNIID1: XXXXXXXX
R32_ESIG_UNIID2: XXXXXXXX
R32_ESIG_UNIID3: ffffffff
```

### 6.4 Grabar el programa

```bash
$MINICHLINK -C ardulink -c /dev/ttyACM0 \
    -w .pio/build/ch32v003f4p6/firmware.bin flash -b
```

Salida esperada:

```
Detected CH32V003
Flash Storage: 16 kB
Read protection: disabled
Interface Setup
Writing image

Image written.
```

O, si el proyecto está configurado (ver §8): **`pio run -t upload`**.

---

## 7. Verificación y resultado

### 7.1 Datos reales de la sesión

| Dato | Valor |
|---|---|
| Programador | CH549, bootloader **2.4.0** |
| UID del CH549 | *(omitido a propósito)* |
| Firmware grabado en el CH549 | `swio.bin`, 4345 B, verificado |
| Estado tras reflasheo | `1209:c550`, `/dev/ttyACM0` |
| Chip objetivo | CH32V003, **16 kB** flash |
| UID del CH32V003 | *(omitido a propósito)* |
| Part Type | `00-30-05-10` |
| **Protección de lectura** | **desactivada** (`RDPR 08f7/5aa5`) |
| Firmware del proyecto | 6224 B (blink de `PC0`) |
| Uso de flash | 6224 / 16384 B (**38,0 %**) |
| Uso de RAM | 472 / 2048 B (**23,0 %**) |
| Resultado | `Image written.` + LED parpadeando |

### 7.1.1 Prueba de frecuencia

Se probaron dos ritmos sobre un **LED amarillo externo** conectado a `PC0` con una
resistencia de 680 Ω a `GND` (`PC0 ── 680 Ω ── ánodo LED ── cátodo ── GND`):

| `T_ON_MS` / `T_OFF_MS` | Frecuencia | Resultado |
|---|---|---|
| 500 / 500 | 1 Hz | ✅ visible |
| 100 / 100 | **5 Hz** | ✅ visible, ritmo claramente más rápido |

Esto confirma que la cadena completa (compilación → `flash.sh` → minichlink →
ejecución) funciona. **El pin `PC0` responde correctamente como GPIO.**

### 7.2 Verificación de la escritura

Se releyó el chip y se comparó con el binario compilado:

```bash
$MINICHLINK -C ardulink -c /dev/ttyACM0 -r /tmp/leido.bin flash 64
$MINICHLINK -C ardulink -c /dev/ttyACM0 -b     # <- imprescindible: reanudar
xxd -l 32 /tmp/leido.bin
```

```
00000000: 6f10 a002 0000 0000 380c 0000 3c0c 0000  o.......8...<...
```

Idéntico al inicio de `firmware.bin`. **La grabación es correcta.**

> ⚠️ **Importante:** leer la flash **detiene la CPU** del CH32V003 y la deja en *halt*.
> Hay que terminar siempre con `minichlink -b` (reboot out of halt) o el programa
> no se ejecutará. El `-b` final del comando de grabación hace justo eso.

### 7.3 La nota sobre protección de código

Existía la sospecha (habitual en CH32V003 comprados en AliExpress) de que el chip
viniera con **protección de lectura activada**, lo que obligaría a un paso previo de
`unprotect`/borrado. **En esta unidad no fue el caso:**

```
Read protection: disabled
USER/RDPR  : 08f7/5aa5
```

Si en el futuro aparece `Read protection: enabled`, el borrado completo lo resuelve:

```bash
$MINICHLINK -C ardulink -c /dev/ttyACM0 -E    # borrar todo el chip
```

---

## 8. Uso diario: compilar y grabar

### 8.1 Configuración del proyecto

`ch32v003-blink/platformio.ini`:

```ini
[env:ch32v003f4p6]
platform  = ch32v
board     = genericCH32V003F4P6
framework = arduino
board_build.core = openwch
monitor_speed    = 115200

; "custom" + upload_command: PlatformIO llama a nuestro script, que usa
; minichlink con el protocolo ardulink.  No usamos "wlink" porque ese
; protocolo solo lo entiende un WCH-LinkE original, no nuestro CH549.
upload_protocol = custom
upload_command  = ./flash.sh $SOURCE
```

> **Por qué `custom` y no `wlink`:** la plataforma ch32v ofrece los protocolos
> `wlink`, `wch-link`, `minichlink` e `isp`. Ninguno sirve tal cual con este
> programador:
> - `wlink` habla el protocolo del WCH-LinkE → falla.
> - `wch-link` usa el OpenOCD de WCH → falla.
> - `minichlink` invoca `~/.platformio/packages/tool-minichlink/minichlink`, que
>   **no está instalado** (el paquete existe pero vacío) y además no pasa `-C ardulink`.
> - `isp` espera el bootloader del CH32V003, que no tiene.
>
> Con `custom` controlamos el comando exacto y el proyecto queda autocontenido.

`flash.sh` (incluido en el proyecto) hace:

1. Localiza `minichlink` y el firmware (convierte `.elf` → `.bin` si hace falta).
2. Busca el puerto por su **ID USB** (`/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00`)
   en lugar de por número, para que no falle si el `ttyACM` cambia.
3. Ejecuta `minichlink -C ardulink -c <puerto> -w <bin> flash -b`.

### 8.2 Comandos

```bash
cd ~/RiscV/ch32v003-blink

pio run                  # compilar
pio run -t upload        # compilar + grabar
pio run -t clean         # limpiar
pio device monitor       # monitor serie (115200)
```

### 8.3 Uso directo de minichlink

```bash
M=~/RiscV/tools/ch32v003fun/minichlink/minichlink

$M -C ardulink -c /dev/ttyACM0 -i                    # info del chip
$M -C ardulink -c /dev/ttyACM0 -w fw.bin flash -b    # grabar
$M -C ardulink -c /dev/ttyACM0 -E                    # borrar todo
$M -C ardulink -c /dev/ttyACM0 -b                    # reanudar tras halt
$M -C ardulink -c /dev/ttyACM0 -u                    # desbloquear (unbrick)
$M -C ardulink -c /dev/ttyACM0 -r out.bin flash 4096 # leer 4 kB de flash
```

---

## 9. Referencia de pines de la placa

### 9.1 Layout físico

```
        ┌───────────────────────────────┐
        │  [USB-C]        CH32V003F4P6  │
        │                               │
        │  GND  SWIO  NC  VCC   ← pads  │
        │                               │
        │  PD4  PD5  PD6  PD7  PA1  PA2 │
        │  GND  PD0  VIN  PC0           │
        │                               │
        │  PD3  PD2  PD1  PC7  PC6  PC5 │
        │  PC4  PC3  PC2  PC1           │
        └───────────────────────────────┘
```

- `VCC` / `VIN`: alimentación (3,3 V / 5 V).
- `GND`: masa.
- `SWIO`: **PD1**, línea de programación (no usar como GPIO si se quiere reprogramar).
- `NC`: sin conexión.
- Cristal de **24,000 MHz** a bordo; regulador **AMS1117-3.3**.

### 9.2 Mapa de pines Arduino (core `openwch`)

| Pin Arduino | Puerto | Analógico | Notas |
|---|---|---|---|
| `D0` | `PA1` | A1 | |
| `D1` | `PA2` | A0 | |
| `D2` | `PC0` | | |
| `D3` | `PC1` | | |
| `D4` | `PC2` | | |
| `D5` | `PC3` | | |
| `D6` | `PC4` | A2 | |
| `D7` | `PC5` | | |
| `D8` | `PC6` | | |
| `D9` | `PC7` | | |
| `D10` | `PD0` | | |
| `D11` | `PD1` | | **SWIO + LED rojo** — ver §9.3 |
| `D12` | `PD2` | A3 | |
| `D13` | `PD3` | A4 | |
| `D14` | `PD4` | A7 | |
| `D15` | `PD5` | A5 | **TX** del Serial |
| `D16` | `PD6` | A6 | **RX** del Serial |
| `D17` | `PD7` | | **NRST** — evitar |

**Periféricos por defecto del core:**

| Función | Pines |
|---|---|
| `Serial` (UART1) | TX = `PD5`, RX = `PD6` |
| SPI | SS=`PC4`, MOSI=`PC6`, MISO=`PC7`, SCK=`PC5` |
| I2C | SDA=`PC1`, SCL=`PC2` |
| ADC | A0=`PA2`, A1=`PA1`, A2=`PC4`, A3=`PD2`, A4=`PD3`, A5=`PD5`, A6=`PD6`, A7=`PD4` |
| `LED_BUILTIN` | **no definido** (`PNUM_NOT_DEFINED`) |

**Pines a evitar:**

- `PD1` — **SWIO** (programación) **y LED rojo de la placa**. No se puede usar a la
  vez para las dos cosas: si se quiere el LED hay que desactivar SDI, y entonces se
  pierde el acceso del programador mientras el sketch corre (ver §9.3 y §13.10).
- `PD7` — NRST: reset del chip.

### 9.3 LEDs de la placa

| LED | Estado | Comportamiento observado |
|---|---|---|
| Verde | — | Alimentación (siempre encendido, **no** es GPIO) |
| Rojo | **placa** | Parpadea **durante cada grabación**; **no** responde a `PC0` |

Aquí hay un **conflicto entre las fuentes documentales y lo observado** que conviene
dejar registrado tal cual, porque es el tipo de trampa que cuesta una tarde.

#### Fuente A — esquemático de la familia (dice `PC0`)

El esquemático que se encuentra buscando esta placa (diseño de **wagiminator**,
rev 1.1, licencia CC-BY-SA; **no se incluye en este repositorio**, se descartó por no
corresponder a esta unidad) dibuja:

```
   +3V3                +3V3                 +3V3
     │                   │                    │
   LED1 (verde)        LED2 (rojo)          R3 10k
     │                   │                    ├─── PD7
   R1 1k               R2 1k                 SW1 (RST)
     │                   │                    │
    GND                 PC0                  GND
```

Es decir: **verde = alimentación** y **rojo = `PC0`, activo-bajo, con 1 kΩ**.

#### Fuente B — documentación de WCH (dice `PD1`)

La página de Zephyr para la placa **oficial de WCH** declara otra cosa:

> *"The board is equipped with one LED, wired to **PD1** and SWIO pins."*
> `LED1 (red) = PD1` — `gpios = <&gpiod 1 GPIO_ACTIVE_LOW>`

#### Qué se observó en esta unidad

| Prueba | Resultado |
|---|---|
| Firmware que parpadea `PC0` a **1 Hz** (500 ms on / off) | El LED rojo **no** se enciende |
| LED externo en `PC0` (`PC0 ── 680 Ω ── LED ── GND`) | ✅ Funciona |
| Durante cualquier grabación con `minichlink` | El LED rojo **parpadea** |

#### Veredicto: el LED está en la placa, en `PD1`, y es activo-bajo ✅

Tres pruebas independientes; la última es concluyente:

| # | Prueba | Resultado | Conclusión |
|---|---|---|---|
| 1 | Desconectar los 3 cables y alimentar la placa por su propio USB | Solo brilla el LED amarillo (`PC0`) | El LED rojo **no** lo controla el firmware por `PC0` |
| 2 | ¿Cuál de las dos placas parpadea al grabar? | **La del microcontrolador** | El LED está **en la PCB del CH32V003** |
| 3 | `extras/led_rojo_pd1.cpp`: liberar `PD1` de SDI y conmutarlo despacio | **El LED rojo se enciende y se apaga alternando 1,5 s / 1,5 s** | **Es `PD1` y es activo-bajo** |

La prueba 2 ya era casi concluyente por eliminación: de los 3 cables que llegan del
programador (`VCC`, `GND`, `SWIO`), **solo `SWIO` conmuta**. Si el LED parpadea *solo*
al grabar y está en la PCB del micro, tiene que colgar de `SWIO`, es decir de `PD1`.

La prueba 3 lo cerró del todo. La secuencia observada encajó **milímetro a milímetro**
con el programa:

| Lo que se observó | Lo que hacía el código | Fase |
|---|---|---|
| Los dos LEDs apagados unos segundos | `PD1=HIGH` (rojo off) + `PC0=LOW` (amarillo off) | 1a · 1,5 s |
| **Se encienden los dos** | `PD1=LOW` (**rojo ON**) + `PC0=HIGH` | 1b · 1,5 s |
| El rojo se apaga, el amarillo sigue | `PD1` vuelve a `SWIO` (flota alto) + `PC0=HIGH` | ventana · 2 s |
| Se apaga el amarillo y ambos siguen apagados | reinicio del ciclo | 1a · 1,5 s |

El LED rojo se encendía **exactamente cuando `PD1` estaba a `LOW`** → **activo-bajo
confirmado** en hardware real.

**Conclusión (firme):**

| LED | Puerto | Polaridad | Nota |
|---|---|---|---|
| Verde | — | — | Alimentación (no es GPIO) |
| Rojo | **`PD1`** / `D11` | **activo-bajo** (`LOW` = encendido) | Comparte pin con `SWIO` |

La polaridad activo-bajo encaja además con lo observado: `SWIO` en reposo está
*tirando a alto* (pull-up de 1 kΩ del programador), y **solo baja** durante la
comunicación → por eso el LED parpadea únicamente durante las grabaciones.

> ⚠️ **Recomendación práctica:** para tus pruebas **usa un LED externo en `PC0`**
> (`PC0 ── 680 Ω ── ánodo ── cátodo ── GND`). Funciona, es activo-alto, no depende
> de la depuración y no compromete la programación. El LED de `PD1` es accesible
> pero cuesta la depuración mientras el sketch corre (§13.10).

**¿Y por qué `pinMode(PD1, OUTPUT)` no enciende nada?** Porque mientras SDI (el
depurador de 1 hilo) está activo, **el módulo de depuración es el dueño físico del
pin** y las escrituras GPIO se ignoran. Liberarlo es posible (§13.10), pero tiene
un coste alto y *no* se recomienda.

### 9.4 Identificación de la placa

Se consultaron **dos fuentes gráficas** y **ninguna describe exactamente** la unidad
usada aquí. Conviene no mezclarlas:

| Fuente | Placa | Qué describe |
|---|---|---|
| Esquemático de la familia (**no incluido**; se descartó) | **wagiminator** *CH32V003F4P6 Development Board* rev 1.1 (CC-BY-SA, OSHW) | MCU, regulador **AP2112K-3.3**, MicroUSB, 2 LEDs, botón RST en `PD7`, headers H1/H2/H3 |
| `CH32V003F4P6_PCB.jpg` (imagen de portada) | **Twen-CH32V003** v1.0 (core board) | Diagrama de pines serigrafiado (otra disposición) |

**Datos útiles del esquemático (válidos si tu clon lo respeta):**

| Elemento | Detalle |
|---|---|
| Regulador | `AP2112K-3.3TRG1` (no AMS1117) |
| Cristal | **no hay**: el chip usa el `HSI` interno |
| Decoupling | `C1` 100 nF + `C2` 10 µF |
| `LED1` | Verde, ánodo a `+3V3`, `R1` 1 kΩ a `GND` → **alimentación** |
| `LED2` | Rojo, ánodo a `+3V3`, `R2` 1 kΩ a **`PC0`** → activo-bajo |
| `SW1` | Botón **RST** sobre `PD7`, con `R3` 10 kΩ de pull-up a `+3V3` |
| `H3` | Header `SWIO` (PD1 / +3V3 / GND) |
| Headers | `H1` = PD4 PD5 PD6 PD7 PA1 PA2 PD0 PC0 3V3 GND · `H2` = PC1 PC2 PC3 PC4 PC5 PC6 PC7 PD1 PD2 PD3 |

> ⚠️ La disposición de `H1`/`H2` se parece mucho a la de la placa usada aquí, pero
> la posición de `GND`/`VIN` difiere y **el LED no se comporta como dice el
> esquemático**. Es un recordatorio de que los clones cambian detalles: **lo
> observado gana a lo documentado**.

---

## 10. Guía para agentes de IA

Sección pensada para que otra sesión (humana o de IA) pueda continuar el trabajo
sin repetir el diagnóstico.

### 10.1 Estado del sistema

```
Programador : WCH-Link antiguo (CH549) REFLASHEADO con swio.bin
USB         : 1209:c550  →  /dev/ttyACM0 (y /dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00)
Herramienta : minichlink + protocolo ardulink
Objetivo    : CH32V003F4P6, 16 kB flash / 2 kB RAM, RV32EC @ 48 MHz
Proyecto    : ~/RiscV/ch32v003-blink
```

### 10.2 Rutas clave

| Qué | Ruta |
|---|---|
| Proyecto | `~/RiscV/ch32v003-blink` |
| Firmware del proyecto | `.pio/build/ch32v003f4p6/firmware.bin` |
| Script de grabación | `~/RiscV/ch32v003-blink/flash.sh` |
| minichlink | `~/RiscV/tools/ch32v003fun/minichlink/minichlink` |
| isp55e0 | `~/RiscV/tools/wch-link-ch549/isp55e0` |
| Firmwares del Link | `~/RiscV/tools/wch-link-ch549/firmware/` |
| Copia de ch549-link | `~/RiscV/tools/wch-link-ch549/ch549-link/` |
| Toolchain | `~/.platformio/packages/toolchain-riscv/bin/riscv-wch-elf-*` |
| Core Arduino | `~/.platformio/packages/framework-arduino-openwch-ch32` |

### 10.3 Receta: crear un sketch nuevo

1. Crear `src/main.cpp` con `#include <Arduino.h>`, `setup()` y `loop()`.
2. Compilar: `pio run`
3. Grabar: `pio run -t upload`
4. Si falla la grabación, comprobar `lsusb | grep 1209:c550`.

**Restricciones del entorno:**

- No usar `PD1` (SWIO + LED rojo) ni `PD7` (NRST) como GPIO.
- El LED onboard **no es accesible sin desactivar la depuración** (§13.10): para
  pruebas visuales usa un LED externo en `PC0`.
- `LED_BUILTIN` no está definido: declarar el pin a mano.
- El core es **openwch**, no ch32v003fun. Usa el API Arduino estándar
  (`pinMode`, `digitalWrite`, `delay`, `millis`, `Serial`, `analogRead`…).
- `Serial` va por `PD5`/`PD6` a 115200; el programador **no** hace de puente
  serie, así que para ver la salida hace falta un USB-TTL aparte en esos pines.
- El espacio es limitado: ~10 kB de flash libres con el core Arduino.

### 10.4 Receta: descubrir el pin de un LED

El proyecto trae un sketch de escaneo en **`extras/escaneo_pines.cpp`** (fuera de
`src/`, así que no se compila por defecto). Para usarlo, cópialo sobre
`src/main.cpp` y graba:

```bash
cp extras/escaneo_pines.cpp src/main.cpp
pio run -t upload
```

El escaneo enciende los 16 GPIO uno a uno y **omite `PD1` y `PD7` a propósito**:

- Cada pin: **1 s** encendido, **0,5 s** apagado.
- Entre vueltas: **3 s** de pausa (referencia para contar).
- Orden: `PC0 PC1 PC2 PC3 PC4 PC5 PC6 PC7 PD0 PD2 PD3 PD4 PD5 PD6 PA1 PA2`.

Si el LED se enciende en el paso *n*, ese es el pin.

> **Ojo:** este escaneo **no iluminará el LED rojo de la placa**, porque está en
> `PD1` y el escaneo lo salta (ver §9.3). El escaneo sirve para LEDs externos.

### 10.5 Receta: recuperar el programador

Si el CH549 se queda en un estado raro:

```bash
# 1) USB fuera, jumper en J1, USB dentro  -> debe salir 4348:55e0
# 2) Regrabar el firmware SWIO:
cd ~/RiscV/tools/wch-link-ch549
./isp55e0 -f firmware/swio.bin
# 3) Quitar jumper y reenchufar
```

Si se quiere volver al WCH-Link de fábrica:

```bash
./isp55e0 -f firmware/wch-riscv.bin    # modo RISC-V (CH32V10x/20x/30x)
./isp55e0 -f firmware/wch-arm.bin      # modo ARM/CMSIS-DAP
```

> ⚠️ Volver al firmware de fábrica **pierde** la capacidad de programar el
> CH32V003. Es reversible en cualquier momento.

### 10.6 Errores conocidos y su significado

| Mensaje | Significado | Solución |
|---|---|---|
| `Ardulink: synced` + `Got code ffffffff` | El programador funciona pero **no ve el chip** | Revisar los 3 cables, la resistencia de 1 kΩ, que el chip tenga alimentación |
| `Could not initialize any supported programmers` | minichlink no encuentra nada | Falta `-C ardulink -c /dev/ttyACM0` |
| `Error: USB error: Input/Output Error` | El Link tiene el firmware de fábrica | Reflashear con `swio.bin` |
| `LIBUSB_ERROR_TIMEOUT` | Firmware antiguo colgado | Reflashear con `swio.bin` |
| `Read protection: enabled` | Chip bloqueado | `minichlink ... -E` |
| Tras leer flash no corre el programa | La CPU quedó en *halt* | `minichlink ... -b` |
| `Could not setup interface` | El chip no responde en ese instante | Reintentar; si el firmware desactivó SDI, ver §13.10 |
| `HARTINFO: ffffffff` / `Got code ffffffff` | No hay comunicación con la CPU | Reintentar, `-u`, o apagar/encender (§13.10) |

---

## 11. Solución de problemas

### El Link no aparece en `lsusb`

1. **Probar otro puerto USB y otro cable.** Fue la causa real en esta sesión:
   un puerto concreto no enumeraba (`error -71`), y en otro funcionó a la primera.
   El síntoma en `dmesg` era:
   ```
   usb 1-13: Device not responding to setup address.
   usb 1-13: device not accepting address 26, error -71
   usb 1-13: unable to enumerate USB device
   ```
2. Comprobar el cable: muchos USB-C son **solo carga**.
3. Revisar con lupa las soldaduras de J1 y del conector USB-C (puentes de estaño).

### Los LEDs están apagados

- **Con J1 puesto** (modo BOOT): es **normal**. El bootloader de ROM no controla
  los LEDs; estos los maneja el firmware de aplicación (`LED_RUN` = P1.6,
  `LED_CON` = P1.7 del CH549).
- **Sin J1**: debería encenderse al menos el LED `RUN`. Si no, el firmware no corre.

### `Ardulink: synced` pero `Got code ffffffff`

El programador está bien; el problema es la conexión con el CH32V003. Revisar en
este orden:

1. `GND` ↔ `GND` (imprescindible).
2. `3V3` ↔ `VCC`.
3. `SWDIO` ↔ `SWIO` (PD1).
4. **La resistencia de 1 kΩ** entre `SWDIO` y `3V3`.
5. Que el chip tenga alimentación (LED verde de la placa).
6. `SWCLK` **no** debe estar conectado.

> Este error también aparece si se lee la flash y no se reanuda la CPU: el
> objetivo queda en *halt* y la siguiente operación falla.

### `pio run -t upload` falla

- Comprobar `lsusb | grep 1209:c550`.
- Comprobar que `/dev/ttyACM0` existe y que el usuario está en el grupo `dialout`.
- Ejecutar `./flash.sh` a mano para ver el error completo.

### El chip deja de responder tras grabar un sketch que usa `PD1`

Si has grabado el sketch experimental de `extras/led_rojo_pd1.cpp` (o cualquier
código que desactive SDI), el programador puede dejar de ver el chip. Síntomas:

```
Could not setup interface.
HARTINFO: ffffffff
Error: Setup chip failed. Got code ffffffff
```

**Recuperación, en este orden:**

1. Reintentar la grabación varias veces (si el sketch abre ventanas periódicas de
   programación, algunas pasarán).
2. **Modo unbrick**, que engancha y borra toda la flash:
   ```bash
   cd ~/RiscV/tools/ch32v003fun/minichlink
   for i in $(seq 1 10); do
     ./minichlink -C ardulink -c /dev/ttyACM0 -u && break
   done
   ```
   Cuando engancha imprime `DMStatus After Halt: /0/004c0382` y
   `Whole-chip erase`. Al quedar la flash vacía, en el siguiente arranque **SDI
   vuelve a estar activo** y la placa es programable otra vez.
3. Como último recurso, **apagar y encender la placa con `PD1` a `GND`**. Sin
   firmware que lo desactive, SDI está activo por defecto en el reset.

> El caso 2 ocurrió en esta sesión y se resolvió al primer intento de `-u`.

---

## 12. Reversión y recuperación

### 12.1 El bootloader es ROM

El bootloader del CH549 **vive en ROM y no se puede borrar**. Por eso:

- Un firmware mal grabado **siempre** se recupera.
- El modo BOOT (`4348:55e0`) está siempre disponible con el jumper J1.

### 12.2 Volver al firmware de fábrica

```bash
cd ~/RiscV/tools/wch-link-ch549
# USB fuera, J1 puesto, USB dentro
./isp55e0 -f firmware/wch-riscv.bin
```

### 12.3 Restaurar el chip CH32V003

```bash
M=~/RiscV/tools/ch32v003fun/minichlink/minichlink
$M -C ardulink -c /dev/ttyACM0 -E      # borrado completo
$M -C ardulink -c /dev/ttyACM0 -b      # reanudar
```

### 12.4 Desbloquear el CH32V003 (unbrick)

Si el chip no responde (`HARTINFO: ffffffff`, `Could not setup interface`), el modo
*unbrick* engancha por fuerza y borra toda la flash:

```bash
for i in $(seq 1 10); do
  $M -C ardulink -c /dev/ttyACM0 -u && break
done
```

Salida cuando funciona:

```
Entering Unbrick Mode
Connection starting
DMStatus After Halt: /0/004c0382
Chip Type: CH32V003
Whole-chip erase
```

Con la flash vacía, el chip arranca sin código y **SDI queda activo**: ya se puede
volver a grabar. Si `-u` tampoco engancha, apagar y encender la placa con `PD1`
a `GND`.

> Esta secuencia fue necesaria tras probar el sketch de `PD1` (§13.10) y funcionó
> al primer intento.

---

## 13. Hallazgos técnicos y notas

### 13.1 El puerto USB importa

Un mismo Link que no enumeraba en un puerto funcionó perfectamente en otro. Antes
de sospechar del hardware, **cambiar de puerto y de cable**. El registro del kernel
(`error -71`, `Device not responding to setup address`) era idéntico al de un
dispositivo defectuoso, lo que llevó a una hora de diagnóstico innecesario.

### 13.2 El firmware v2.01 no responde a nada

El firmware "combinado ARM+RV" del CH549 (v2.01/2.03) no implementa el comando de
*probe* moderno. Ninguna herramienta actual (wlink, minichlink, OpenOCD de WCH,
`wlink-iap`) puede hablar con él. La única salida es el bootloader ISP.

### 13.3 `bcdUSB 1.10` como pista de identificación

El CH549 es un 8051 con USB full-speed y su firmware declara `bcdUSB 1.10`. Los
CH32V203/CH32V305 (WCH-LinkE/S) declaran `2.00`. Es un indicador rápido y fiable
del modelo, junto con `bcdDevice` (2.0x = firmware antiguo).

### 13.4 La respuesta "correcta" que no lo era

El firmware de fábrica responde `82 0c 01 01` a **cualquier** `CHIP_CH32V003`,
lo que simula un reconocimiento exitoso. El proyecto `ch549-link` lo probó con
bytes sin sentido y obtuvo la misma respuesta: el firmware no valida nada. Es una
trampa de diagnóstico: parece que funciona hasta que el *attach* falla.

### 13.5 Leer la flash detiene la CPU

`minichlink -r` deja el CH32V003 en *halt*. Hay que salir con `-b`. El comando de
grabación ya termina con `-b`, por eso el flujo normal no se ve afectado.

### 13.6 `libudev-dev` y minichlink

El `make` de minichlink requiere `libudev-dev` para compilar los programadores
ESP32-S2 y B003Fun. Si no se quiere instalar el paquete, se pueden omitir esos dos
archivos y aportar dos *stubs* (ver §6.1). El programador WCH-Link/ardulink no usa
`libudev`.

### 13.7 `tool-minichlink` de PlatformIO está vacío

El paquete `~/.platformio/packages/tool-minichlink` existe pero **no contiene el
binario**, solo un `.git` y un `package.json`. Por eso el protocolo `minichlink` de
la plataforma ch32v no funciona de serie. Nuestra solución (`upload_protocol =
custom`) evita el problema apuntando a un minichlink compilado a mano.

### 13.8 El core Arduino ocupa bastante

Con el core `openwch`, un sketch trivial (parpadeo) ocupa **6208 B de 16384**
(37,9 %). Quedan ~10 kB para lógica de usuario. Para proyectos grandes conviene
considerar el framework `ch32v003fun`, que es mucho más ligero.

### 13.9 Alternativas si no se quiere reflashear

| Alternativa | Coste | Comentario |
|---|---|---|
| Comprar un **WCH-LinkE** | ~5-10 € | Lo más sencillo; soporta CH32V003 de fábrica |
| Usar un **ESP32-S2/S3** con minichlink | 0 € si se tiene | Programador `esp32s2chfun` |
| Bit-bang con **otro MCU** | 0 € | `arduino-ch32v003-swio` en un AVR/ESP |
| **Reflashear el CH549** | 0 € | La solución de este informe |

### 13.10 Usar `PD1` como GPIO: por qué no basta `pinMode()` y por qué no conviene

Este es el hallazgo más contraintuitivo de la sesión y merece detalle.

#### El hecho

El LED rojo de la placa cuelga de **`PD1`**, la misma línea con la que se
**programa** el chip (`SWIO`). Está **confirmado** con dos pruebas directas (§9.3):
no responde a `PC0`, y es la **placa del microcontrolador** la que parpadea durante
las grabaciones. Como de las 3 líneas que llegan del programador (`VCC`, `GND`,
`SWIO`) solo `SWIO` conmuta, el LED tiene que estar necesariamente en `PD1`.

Y coincide con la documentación oficial de Zephyr para la **placa oficial de WCH**,
que lo declara literalmente:

> *"The board is equipped with one LED, wired to **PD1** and SWIO pins."*
> `LED1 (red) = PD1`

```dts
leds {
    compatible = "gpio-leds";
    red_led: led0 {
        gpios = <&gpiod 1 GPIO_ACTIVE_LOW>;   /* PD1, activo-bajo */
        label = "LED";
    };
};
```

> ℹ️ **Sobre el esquemático wagiminator:** sitúa el LED en `PC0` (§9.3), pero
> **no describe esta unidad**. En este clon el LED se movió a `PD1` (o el
> esquemático corresponde a otra revisión). Es un buen recordatorio de que
> **lo observado gana a lo documentado**.
>
> **El mecanismo de WCH es exactamente el mismo que usé**, así que la vía era
> correcta. El valor del SPL lo confirma:
> `#define GPIO_Remap_SDI_Disable ((uint32_t)0x00300400)` — su descriptor de
> posición (`bits 20-21`) y máscara (`0x0400`) acaban escribiendo `SWJ_CFG = 0b100`
> igual que en el código de abajo.

#### El problema: el depurador es el dueño del pin

Lo natural sería escribir:

```cpp
pinMode(PD1, OUTPUT);
digitalWrite(PD1, LOW);      // ¡no hace nada!
```

**No funciona.** El pin se queda igual y el LED no se enciende. El motivo lo explica
el `board.c` de Zephyr:

> *"PD1 is wired to led and to SWDIO pin."*

Mientras **SDI/SWD está activo**, el **módulo de depuración controla físicamente el
pin** y las escrituras GPIO se ignoran. `PD1` no es un GPIO normal hasta que se
**desactiva la depuración**, escribiendo los bits `SWJ_CFG` de `AFIO->PCFR1`:

```c
/* Equivalente a lo que hace Zephyr en board_late_init_hook() */
#define AFIO_SWCFG_MASK    0x07000000u
#define AFIO_SWCFG_SWD_OFF 0x04000000u

RCC->APB2PCENR |= RCC_AFIOEN;
AFIO->PCFR1 = (AFIO->PCFR1 & ~AFIO_SWCFG_MASK) | AFIO_SWCFG_SWD_OFF;
pinMode(PD1, OUTPUT);
digitalWrite(PD1, LOW);      /* ahora sí: LOW = encendido (activo-bajo) */
```

Existe incluso una función oficial en la SPL de WCH que hace lo mismo:

```c
GPIO_PinRemapConfig(GPIO_Remap_SDI_Disable, ENABLE);   /* libera PD1 */
```

#### El precio: se pierde el programador mientras el sketch corre

Con SDI desactivado, el programador **no puede entrar** en el chip. En la prueba
real, con una versión que abría una «ventana de programación» de 1,5 s cada 3,5 s:

```
--- intento 1 ---  Image written.                        ✅
--- intento 2 ---  Could not setup interface.            ❌
--- intento 3 ---  HARTINFO: ffffffff                     ❌
```

Y lo peor: **un intento fallido puede dejar la CPU en *halt* justo cuando el pin ya
no es SDI**. Entonces ni se ejecuta la ventana de rescate del propio sketch ni el
programador puede volver a entrar: la placa queda **bloqueada**.

**Recuperación (probada, funcionó al primer intento):**

```bash
minichlink -C ardulink -c /dev/ttyACM0 -u
# -> DMStatus After Halt: /0/004c0382
# -> Chip Type: CH32V003
# -> Whole-chip erase
```

El *unbrick* borra toda la flash; sin firmware que desactive SDI, en el siguiente
arranque la depuración vuelve a estar activa por defecto.

#### Por qué falló el primer intento (causa encontrada)

El primer experimento desactivaba SDI solo si detectaba que `PD1` **no** estaba a
masa, siguiendo el mismo criterio que el `board.c` de Zephyr (si alguien puentea
`PD1` a `GND` al arrancar, se respeta `SWIO` para poder programar). El código era:

```c
pinMode(PD1, INPUT);
delay(20);
if ((GPIOD->INDR & (1u << 1)) == 0) return;   /* ¿a masa? -> modo seguro */
sdi_off();                                    /* si no, libérame el pin */
```

Había **dos causas candidatas**, y la v2 corregida las separó:

1. **La lectura de `PD1` daba falso positivo** ← *causa real*. Con SDI activo el pin
   está en modo *alternate function*, y `GPIOD->INDR` en ese estado puede devolver
   `0` en vez del nivel real. Así, la condición de «modo seguro» se cumplía siempre
   y **el sketch nunca desactivaba SDI** → el LED rojo jamás se tocaba (solo
   parpadeaba el amarillo). Encaja exactamente con lo observado.
2. **La polaridad o el momento** ← *descartada*. La v2, que conmuta despacio
   (independiente de la polaridad) y elimina esa lectura, **encendió el LED rojo a la
   primera grabación**. Por tanto la polaridad activo-bajo era correcta y el problema
   era solo la lectura de `PD1`.

**Correcciones aplicadas al experimento de `extras/` (probadas con éxito):**

- **Se elimina la lectura de `PD1`**: la detección de «modo seguro» pasa a ser por
  **ventana de tiempo** (no por nivel del pin), que es determinista.
- **Prueba independiente de la polaridad:** `PD1` conmuta despacio (1,5 s en un
  nivel, 1,5 s en el otro). Así el LED rojo se vea **encendido 1,5 s y apagado
  1,5 s**, sea activo-bajo o activo-alto. Si el LED hace eso, es de `PD1` sin
  discusión.
- Se mantienen **ventanas periódicas** en las que `PD1` vuelve a ser `SWIO`, para
  que la grabación no dependa del instante exacto.

#### Conclusión

**Funciona, pero sigue sin merecer la pena.** El LED rojo **se puede** encender y
apagar desde `PD1` (confirmado). Aun así, no lo recomiendo como LED de trabajo:
`PD1` es la línea de programación compartida con el LED, usarla como GPIO obliga a
cegar al programador mientras el sketch corre y un fallo de grabación puede dejar la
placa en un estado que hay que rescatar a mano.

**Dato práctico:** con el diseño de ventanas de la v2, en esta sesión la grabación fue
**fiable**: tanto al cargar el experimento como al restaurar después el blink seguro
de `PC0`, `minichlink` enganchó **al primer intento**. Las ventanas periódicas bastan.
El bloqueo sufrido con la v1 fue un caso aparte (§ arriba, la lectura de `PD1`).

El código se conserva, **fuera de la compilación**, en `extras/led_rojo_pd1.cpp`,
**ya probado en hardware** y con el procedimiento de rescate documentado en §12.4.

### 13.11 Ni los pinouts ni los esquemáticos son infalibles

Se consultaron **cuatro fuentes** para el pin del LED rojo, y solo una acertó:

| Fuente | Dice | ¿Acertó? |
|---|---|---|
| Pinouts genéricos de AliExpress | `PC0` o `PC1` | ❌ |
| Esquemático de la familia (wagiminator rev 1.1) | `PC0`, activo-bajo, 1 kΩ | ❌ (es otra placa) |
| **Documentación Zephyr de la placa oficial de WCH** | **`PD1`, activo-bajo** | ✅ |
| **Esta unidad (observación)** | No es `PC0` (probado a 1 Hz) · parpadea en cada grabación · **está en la PCB del micro** | → `PD1` |

**Lección:** cuando una fuente documental contradice el comportamiento observado en
tu hardware concreto, **gana la observación**. Y la forma más rápida y barata de
zanjarlo es un LED externo con resistencia en el pin candidato:

```
PC0 ── 680 Ω ── (ánodo) LED (cátodo) ── GND
```

Ese montaje funcionó a la primera, es **activo-alto** (se enciende con `HIGH`), no
interfiere con la programación y permitió validar toda la cadena de trabajo. Es la
opción recomendada frente a pelear con el LED onboard.

### 13.12 Un LED en la línea de programación es una mala idea (de diseño)

Si tu unidad tiene el LED de usuario sobre `PD1` (como la placa oficial de WCH),
tiene dos consecuencias inevitables:

1. El LED **parpadea sin control** en cada grabación, porque es la línea que se usa
   para hablar con el chip.
2. Para usarlo desde el programa hay que **desactivar la depuración**, lo que crea
   un estado frágil y difícil de recuperar.

Es un compromiso de diseño del fabricante, no un fallo. Simplemente conviene saberlo
antes de perder una tarde intentando encenderlo con `pinMode()`.

**Regla práctica:** antes de dar por bueno cualquier pinout o esquemático, comprueba
el pin candidato con un **LED externo y una resistencia de 680 Ω a `GND`**. Son dos
minutos y descartan suposiciones.

---

## 14. Referencias

### Proyectos

- **ch549-link** — firmware SWIO para CH549: <https://github.com/e-labInnovations/ch549-link>
  - `docs/how-it-works.md` — por qué funciona, tiempos, trampas
  - `docs/isp-protocol.md` — protocolo ISP del bootloader CH549
  - Demo web (WebUSB): <https://utils.elabins.com/ch549-link/>
- **ch32v003fun / minichlink** — <https://github.com/cnlohr/ch32v003fun>
- **isp55e0** — flasheador del bootloader CH55x: <https://github.com/frank-zago/isp55e0>
- **arduino-ch32v003-swio** — implementación original del protocolo: <https://gitlab.com/BlueSyncLine/arduino-ch32v003-swio>
- **platform-ch32v** — plataforma de PlatformIO: <https://github.com/Community-PIO-CH32V/platform-ch32v>
- **arduino_core_ch32** — core Arduino de WCH: <https://github.com/openwch/arduino_core_ch32>

### Esta placa en concreto

- **WCH CH32V003F4P6 Development Board** (Zephyr Project) — documentación de la placa:
  <https://docs.zephyrproject.org/latest/boards/wch/ch32v003f4p6_dev_board/doc/index.html>
  - Confirma `LED1 (red) = PD1` y *"SWIO pin is connected to PD1 and also to led"*.
  - `board.c`: <https://github.com/zephyrproject-rtos/zephyr/blob/main/boards/wch/ch32v003f4p6_dev_board/board.c>
    (el código que desactiva `SWJ_CFG` para liberar `PD1`).
  - `ch32v003f4p6_dev_board.dts`: <https://github.com/zephyrproject-rtos/zephyr/blob/main/boards/wch/ch32v003f4p6_dev_board/ch32v003f4p6_dev_board.dts>
    (`gpios = <&gpiod 1 GPIO_ACTIVE_LOW>`).
- **TENSTAR CH32V003F4P6 Board Guide** (Dillon Simeone) — notas prácticas sobre los
  pads de depuración y el etiquetado `SWD`/`SWIO`:
  <https://dillonsimeone.com/ESP32Codes/PlatformIO/02_Audio_Haptics/CH32V003Haptics/board-guide.html>
- **wagiminator — CH32V003F4P6 Development Board** (diseño abierto, CC-BY-SA, OSHW;
  origen del esquemático de familia comentado en §9.3, **descartado para esta unidad**):
  <https://oshwlab.com/wagiminator/ch32v003f4p6-development-board>
- **Twen-CH32V003** (core board china; es la de `CH32V003F4P6_PCB.jpg`):
  diagrama de pines serigrafiado en la propia placa.

### Documentación oficial

- **WCH-Link 使用说明** (manual chino, 2025): <https://www.wch.cn/uploads/file/20250124/1737704462135866.pdf>
  - Tabla de chips soportados por modelo (la que descarta el CH32V003 en el WCH-Link).
  - Procedimiento de actualización por USB con J1.
- **WCH-Link User Manual** (inglés, V2.4): <https://www.olimex.com/Products/RISC-V/WCH/WCH-LinkE/resources/WCH-LinkUserManual.PDF>
- **CH32V003** — página del producto: <http://www.wch-ic.com/products/CH32V003.html>
- **WCH-LinkUtility** (firmwares oficiales): <https://www.wch.cn/downloads/WCH-LinkUtility_ZIP.html>

### Hilos y artículos relevantes

- *Programming CH32v003 with WCH-Link* (mitxela forum) — mismo clon, mismo firmware 2.1, misma conclusión: <https://mitxela.com/forum/topic/programming-ch32v003-with-wch-link>
- *WCH Link Failed to configure MCU* (Stack Overflow): <https://stackoverflow.com/questions/75925108/wch-link-failed-to-configure-mcu>
- *How to flash fresh-bought WCH microcontrollers* (r/RISCV): <https://www.reddit.com/r/RISCV/comments/1ghrwon/>
- *opensource-toolchain-ch32v* (cjacker) — nota sobre SDI y WCH-LinkE: <https://github.com/cjacker/opensource-toolchain-ch32v>

---

## 15. Inventario de archivos

### 15.1 Proyecto (`~/RiscV/ch32v003-blink/`)

| Archivo | Descripción |
|---|---|
| `platformio.ini` | Configuración de PlatformIO (protocolo `custom`) |
| `src/main.cpp` | Sketch activo: parpadeo de `PC0` a 5 Hz |
| `extras/escaneo_pines.cpp` | Referencia: escaneo de los 16 GPIO (no se compila) |
| `extras/led_rojo_pd1.cpp` | Referencia: experimento del LED en `PD1` (v2, **verificado en hardware**) + cómo liberarlo de SDI |
| `flash.sh` | Script de grabación vía minichlink |
| `README.md` | Guía rápida **del proyecto** (dentro de `ch32v003-blink/`) |
| `.pio/build/ch32v003f4p6/firmware.bin` | Firmware compilado (6224 B) |

### 15.2 Herramientas (`~/RiscV/tools/`)

| Ruta | Descripción |
|---|---|
| `ch32v003fun/minichlink/minichlink` | Programador compilado (soporta ardulink) |
| `ch32v003fun/minichlink/stub_programmers.c` | Stubs para compilar sin libudev |
| `wch-link-ch549/isp55e0` | Flasheador del bootloader CH549 |
| `wch-link-ch549/firmware/swio.bin` | **Firmware SWIO** (el que está grabado) |
| `wch-link-ch549/firmware/wch-riscv.bin` | Firmware de fábrica (RISC-V) |
| `wch-link-ch549/firmware/wch-arm.bin` | Firmware de fábrica (ARM) |
| `wch-link-ch549/ch549-link/` | Copia del proyecto ch549-link (fuentes y docs) |
| `wch-link-ch549/docs/` | Manuales de WCH y tabla de compatibilidad |
| `wlink-iap/` | Herramienta para el protocolo IAP del WCH-Link |

### 15.3 Reproducir desde cero

```bash
# 1. Herramientas
git clone --depth 1 https://github.com/cnlohr/ch32v003fun
git clone --depth 1 https://github.com/frank-zago/isp55e0
cd isp55e0 && make

# 2. Firmware SWIO
curl -LO https://utils.elabins.com/ch549-link/firmware/swio.bin

# 3. Reflashear el CH549 (J1 puesto al arrancar)
./isp55e0 -f swio.bin

# 4. Proyecto
cd ~/RiscV/ch32v003-blink
pio run -t upload
```

### 15.4 Documentación, portada y licencia (raíz del proyecto)

| Archivo | Contenido |
|---|---|
| `README_ES.md` | Este informe (español) |
| `README.md` | Traducción al inglés de este informe |
| `CH32V003F4P6_PCB.jpg` | Diagrama de pines serigrafiado de la placa *Twen-CH32V003* — **imagen de portada** |
| `LICENSE` | Licencia **MIT** del informe y de los scripts propios |
| `.gitignore` | Exclusiones para Git (build de PlatformIO, binarios, temporales) |

---

## Apéndice A — Salida completa de referencia

### `minichlink ... -i`

```
minichlink version - local
Opening serial port /dev/ttyACM0 at 115200 baud.
Ardulink: synced.
Ardulink: target power 1
Detected CH32V003
Flash Storage: 16 kB
Part UUID: XX-XX-XX-XX-XX-XX-XX-XX
Part Type: 00-30-05-10
Read protection: disabled
Interface Setup
USER/RDPR  : 08f7/5aa5
DATA1/DATA0: 00ff/00ff
WRPR1/WRPR0: 00ff/00ff
WRPR3/WRPR2: 00ff/00ff
R32_ESIG_UNIID1: XXXXXXXX
R32_ESIG_UNIID2: XXXXXXXX
R32_ESIG_UNIID3: ffffffff
```

### `isp55e0 -f swio.bin`

```
Found device CH549
Bootloader version 2.4.0
Unique chip ID XX-XX-XX-XX-XX-XX-XX-XX
Current config-bits    00-00-00-00-20-00-00-00-00-d2-c7-b1
Write new config-bits  00-00-00-00-20-00-00-00-00-d2-c7-b1
10%20%30%41%50%60%70%81%90%100%Code flashing successful
10%20%30%41%50%60%70%81%90%100%Firmware is good
```

### `pio run -t upload`

```
RAM:   [==        ]  23.0% (used 472 bytes from 2048 bytes)
Flash: [====      ]  37.9% (used 6208 bytes from 16384 bytes)
Configuring upload protocol...
CURRENT: upload_protocol = custom
Uploading .pio/build/ch32v003f4p6/firmware.elf
minichlink version - local
Opening serial port /dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00 at 115200 baud.
Ardulink: synced.
Ardulink: target power 1
Detected CH32V003
Flash Storage: 16 kB
Read protection: disabled
Interface Setup
Writing image

Image written.
========================= [SUCCESS] Took 5.42 seconds =========================
```

---

## Apéndice B — Mapa de memoria del firmware

```
section             size        addr
.init                160         0x0
.text               5848        0xa0
.fini                  0      0x1778
.init_array            4      0x1778
.dalign                0    0x20000000
.dlalign               0      0x177c
.data                200    0x20000000
.bss                 272    0x200000c8
.stack               448    0x20000640
.comment              51         0x0
.riscv.attributes     39         0x0
Total               7022
```

- **Flash**: 16 384 B (`.init` + `.text` + datos inicializados) → 6208 B usados.
- **RAM**: 2048 B (`.data` + `.bss` + `.stack`) → 472 B usados.

---

*Informe generado el 19 de octubre de 2026. Todos los datos de hardware y las
salidas de comandos son de la sesión real en el equipo descrito.*

*Publicado bajo la [licencia MIT](LICENSE). Copyright (c) 2026 `carlymx`.*
