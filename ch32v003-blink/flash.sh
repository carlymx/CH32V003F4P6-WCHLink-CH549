#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  flash.sh - graba el firmware del proyecto en el CH32V003F4P6
#
#  Se usa desde PlatformIO:   pio run -t upload
#  O a mano:                  ./flash.sh [ruta/al/firmware.bin]
#
#  Requiere que el WCH-Link con firmware SWIO (ch549-link) esté conectado
#  y aparezca como /dev/ttyACM0 (VID:PID 1209:c550).
# ---------------------------------------------------------------------------
set -euo pipefail

PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(cd "$PROYECTO/.." && pwd)"   # raíz del repositorio = carpeta padre del proyecto
MINICHLINK="${MINICHLINK:-$RAIZ/tools/ch32v003fun/minichlink/minichlink}"
# Buscamos el puerto por su ID de USB (no por número): si hay más de un
# ttyACM, el número puede cambiar.  Si no existe el enlace by-id, usamos
# /dev/ttyACM0.
BYID="/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00"
if [[ -z "${PUERTO:-}" ]]; then
    if [[ -e "$BYID" ]]; then
        PUERTO="$BYID"
    else
        PUERTO="/dev/ttyACM0"
    fi
fi

# Si no nos pasan el .bin, lo tomamos del build de PlatformIO.
BIN="${1:-}"
if [[ -z "$BIN" || "$BIN" == *.elf ]]; then
    ELF="$PROYECTO/.pio/build/ch32v003f4p6/firmware.elf"
    BIN="$PROYECTO/.pio/build/ch32v003f4p6/firmware.bin"
    # PlatformIO puede pasar el .elf: lo convertimos a .bin si hace falta.
    if [[ -f "$ELF" ]]; then
        OBJCOPY="${OBJCOPY:-$HOME/.platformio/packages/toolchain-riscv/bin/riscv-wch-elf-objcopy}"
        "$OBJCOPY" -O binary "$ELF" "$BIN"
    fi
fi

if [[ ! -x "$MINICHLINK" ]]; then
    echo "ERROR: no encuentro minichlink en: $MINICHLINK" >&2
    echo "       Compílalo con: cd <ch32v003fun>/minichlink && make" >&2
    exit 1
fi
if [[ ! -f "$BIN" ]]; then
    echo "ERROR: no existe el firmware: $BIN" >&2
    echo "       Compila primero con: pio run" >&2
    exit 1
fi
if [[ ! -e "$PUERTO" ]]; then
    echo "ERROR: no existe $PUERTO" >&2
    echo "       ¿Está el WCH-Link conectado? Debe salir en 'lsusb' como 1209:c550." >&2
    exit 1
fi

echo "Grabando $BIN en $PUERTO ..."
exec "$MINICHLINK" -C ardulink -c "$PUERTO" -w "$BIN" flash -b
