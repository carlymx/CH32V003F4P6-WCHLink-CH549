# Compilar, grabar y recuperar el chip

## 0. Comprobación previa (10 segundos)

```sh
cd ch32v003-blink

ls -l /dev/serial/by-id/          # debe aparecer usb-Deqing_CH55xduino_CH55x-if00
lsusb | grep 1209:c550            # debe aparecer el programador
id -nG | tr ' ' '\n' | grep dialout   # el usuario debe estar en dialout
```

Si `dialout` no aparece, hay que añadirse (`sudo usermod -aG dialout $USER`) y
**cerrar sesión** para que el escritorio (y por tanto VSCode) lo hereden.

## 1. Compilar

```sh
pio run
```

Salida esperada (firmware de PC0, ya verificado):

```text
RAM:   [==        ]  23.0% (used 472 bytes from 2048 bytes)
Flash: [====      ]  38.0% (used 6224 bytes from 16384 bytes)
========================= [SUCCESS] =========================
```

**Graba solo si pone `SUCCESS`.** Si no compila, no toques la placa.

## 2. Grabar

```sh
pio run -t upload
```

`platformio.ini` está configurado con `upload_protocol = custom` y
`upload_command = ./flash.sh $SOURCE`, así que el botón **Upload** de VSCode y
este comando hacen exactamente lo mismo.

### Qué hace `flash.sh`

1. Averigua su propia ruta (funciona desde cualquier directorio).
2. **Localiza `minichlink`**: `$MINICHLINK` → `<proyecto>/tools/minichlink/` →
   `tools/ch32v003fun/minichlink/` subiendo carpetas → `PATH` → y si no lo
   encuentra, **lo descarga dentro del proyecto** en `<proyecto>/tools/minichlink/`.
   El binario va fijado a un commit concreto y con `sha256` conocido, y se
   verifica antes de usarlo. Así el proyecto es **autocontenido** (ver
   `proyecto-nuevo.md`).
3. Elige el puerto: `$PUERTO` si está definido, si no el enlace `by-id`
   `usb-Deqing_CH55xduino_CH55x-if00`, y si no `/dev/ttyACM0`.
4. Si le pasan un `.elf` (lo normal desde PlatformIO) lo convierte a `.bin` con
   `~/.platformio/packages/toolchain-riscv/bin/riscv-wch-elf-objcopy`.
5. Ejecuta `minichlink -C ardulink -c <puerto> -w <bin> flash -b`.

### Opciones de `flash.sh`

| Uso | Efecto |
|---|---|
| `./flash.sh` | Graba el último firmware compilado |
| `./flash.sh firmware.elf` | Graba ese firmware (PlatformIO pasa `$SOURCE`) |
| `./flash.sh --preparar` | Asegura `minichlink` (lo descarga si falta) |
| `./flash.sh --info` | Muestra la información del chip |
| `./flash.sh --simular` | Dice lo que haría, sin grabar nada |
| `./flash.sh --help` | Ayuda |

Variables que se pueden forzar: `PUERTO`, `MINICHLINK`, `MINICHLINK_URL`,
`OBJCOPY`, `SIMULAR=1`.

## 3. Grabar a mano (sin PlatformIO)

```sh
ML=tools/ch32v003fun/minichlink/minichlink
PORT=/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00
BIN=ch32v003-blink/.pio/build/ch32v003f4p6/firmware.bin

"$ML" -C ardulink -c "$PORT" -w "$BIN" flash -b
```

## 4. Comandos de `minichlink` que se usan de verdad

| Para qué | Comando |
|---|---|
| Grabar y verificar | `$ML -C ardulink -c $PORT -w fw.bin flash -b` |
| Información del chip | `$ML -C ardulink -c $PORT -i` |
| Leer la flash | `$ML -C ardulink -c $PORT -r salida.bin 0x08000000 8192` |
| Borrado completo (desbrick) | `$ML -C ardulink -c $PORT -u` |
| Servidor GDB (terminal) | `$ML -C ardulink -c $PORT -G` *(debe ir como último argumento)* |

Salida normal de una grabación correcta:

```text
Ardulink: synced.
Ardulink: target power 1
Detected CH32V003
Flash Storage: 16 kB
Read protection: disabled
Interface Setup
Writing image

Image written.
```

## 5. Verificar que se ha grabado de verdad

Leer la flash y compararla con el binario (esto es lo que se hizo la última vez):

```sh
"$ML" -C ardulink -c "$PORT" -r /tmp/readback.bin 0x08000000 8192
head -c "$(stat -c%s "$BIN")" /tmp/readback.bin > /tmp/readback_trunc.bin
cmp "$BIN" /tmp/readback_trunc.bin && echo "OK: coincide"
```

## 6. Recuperación (el chip no responde)

Por orden, de menos a más agresivo:

1. **¿Está ocupado el puerto?** Cierra el monitor serie o cualquier proceso que
   tenga abierto `/dev/ttyACM0` (`fuser /dev/ttyACM0`).
2. **¿El firmware desactiva SDI?** Entonces hay que enganchar dentro de la
   ventana de arranque: pulsa RESET y graba inmediatamente.
3. **`-u` (borrado completo):** deja la flash vacía y SDI activo otra vez.
   ```sh
   "$ML" -C ardulink -c "$PORT" -u
   ```
4. **Reconectar el USB** del programador (y la alimentación de la placa).
5. Si aparece en `lsusb` pero no engancha, prueba con otro cable USB (los cables
   "solo carga" son una causa clásica).

## 7. Rutas de las herramientas

| Cosa | Ruta |
|---|---|
| `minichlink` | 1.º `<proyecto>/tools/minichlink/minichlink`; si no, `tools/ch32v003fun/minichlink/minichlink`; si no, en el `PATH`; si no, **se descarga** |
| `objcopy` | `~/.platformio/packages/toolchain-riscv/bin/riscv-wch-elf-objcopy` |
| Firmware compilado | `ch32v003-blink/.pio/build/ch32v003f4p6/firmware.{elf,bin}` |
| PlatformIO Core | `~/.platformio/penv/bin/pio` (o `pio` en el PATH) |
| Programador (firmwares) | `tools/wch-link-ch549/firmware/{swio,wch-riscv,wch-arm}.bin` |

## 8. Probar los experimentos de `extras/`

PlatformIO **solo compila `src/`**, así que los extras no entran en el binario:

```sh
cd ch32v003-blink
cp extras/led_rojo_pd1.cpp src/main.cpp     # ojo: este desactiva SDI
pio run -t upload                            # puede necesitar la ventana de arranque

git checkout src/main.cpp                    # volver al blink seguro de PC0
pio run -t upload
```

> Al volver del experimento del LED rojo conviene **recompilar y grabar** el
> blink de PC0 para dejar SDI activo otra vez. Así el programador engancha
> siempre.
