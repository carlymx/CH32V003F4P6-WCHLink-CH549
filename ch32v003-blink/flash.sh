#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  flash.sh - graba el firmware del proyecto en el CH32V003F4P6
#
#  Se usa desde PlatformIO:   pio run -t upload
#  O a mano:                  ./flash.sh [ruta/al/firmware.elf | .bin]
#
#  Requiere que el WCH-Link con firmware SWIO (ch549-link) este conectado y
#  aparezca como /dev/ttyACM0 (VID:PID 1209:c550).
#
#  Variables de entorno, todas opcionales:
#     PUERTO      puerto serie del programador
#     MINICHLINK  ruta a minichlink
#     OBJCOPY     ruta a riscv-wch-elf-objcopy
#     SIMULAR=1   no graba: solo informa de lo que haria
# ---------------------------------------------------------------------------
set -euo pipefail

PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Localizar minichlink --------------------------------------------------
#   1) la variable MINICHLINK
#   2) buscando tools/ch32v003fun/minichlink/minichlink hacia arriba desde el
#      proyecto (asi funciona tanto en este repositorio como en un proyecto
#      nuevo creado en cualquier subcarpeta)
#   3) en el PATH
localizar_minichlink() {
    if [[ -n "${MINICHLINK:-}" ]]; then
        printf '%s' "$MINICHLINK"; return
    fi
    local d="$PROYECTO"
    while :; do
        if [[ -x "$d/tools/ch32v003fun/minichlink/minichlink" ]]; then
            printf '%s' "$d/tools/ch32v003fun/minichlink/minichlink"; return
        fi
        if [[ "$d" == "/" ]]; then break; fi
        d="$(dirname "$d")"
    done
    command -v minichlink 2>/dev/null || true
}
MINICHLINK="$(localizar_minichlink)"

# --- Localizar el puerto ---------------------------------------------------
# Por ID de USB y no por numero: si hay mas de un ttyACM el numero cambia.
BYID="/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00"
if [[ "${PUERTO:-}" == "" ]]; then
    if [[ -e "$BYID" ]]; then PUERTO="$BYID"; else PUERTO="/dev/ttyACM0"; fi
fi

# --- Localizar el firmware -------------------------------------------------
# PlatformIO pasa $SOURCE (el .elf). Si se llama a mano sin argumentos,
# se busca el .elf del build, sea cual sea el nombre del entorno.
ENTRADA="${1:-}"
ELF=""
if [[ -n "$ENTRADA" && "$ENTRADA" == *.elf ]]; then
    ELF="$ENTRADA"
elif [[ -z "$ENTRADA" && -d "$PROYECTO/.pio/build" ]]; then
    ELF="$(ls -1 "$PROYECTO"/.pio/build/*/firmware.elf 2>/dev/null | head -1 || true)"
fi

if [[ -n "$ELF" ]]; then
    BIN="${ELF%.elf}.bin"
    OBJCOPY="${OBJCOPY:-$HOME/.platformio/packages/toolchain-riscv/bin/riscv-wch-elf-objcopy}"
    if [[ ! -x "$OBJCOPY" ]]; then
        OBJCOPY="$(command -v riscv-wch-elf-objcopy 2>/dev/null || true)"
    fi
else
    BIN="$ENTRADA"
fi

# --- Comprobaciones --------------------------------------------------------
if [[ ! -x "$MINICHLINK" ]]; then
    echo "ERROR: no encuentro minichlink." >&2
    echo "       Indica su ruta asi:  MINICHLINK=/ruta/a/minichlink $0" >&2
    exit 1
fi
if [[ -z "$BIN" || ! -f "$BIN" ]]; then
    echo "ERROR: no encuentro el firmware." >&2
    echo "       Compila primero con: pio run" >&2
    exit 1
fi
if [[ ! -e "$PUERTO" ]]; then
    echo "ERROR: no existe $PUERTO" >&2
    echo "       ¿Esta el WCH-Link conectado? Debe salir en 'lsusb' como 1209:c550." >&2
    exit 1
fi
if [[ -n "$ELF" ]]; then
    if [[ ! -x "$OBJCOPY" ]]; then
        echo "ERROR: no encuentro riscv-wch-elf-objcopy." >&2
        echo "       Indicalo asi:  OBJCOPY=/ruta/a/riscv-wch-elf-objcopy $0" >&2
        exit 1
    fi
    "$OBJCOPY" -O binary "$ELF" "$BIN"
fi

if [[ "${SIMULAR:-0}" == "1" ]]; then
    echo "SIMULACION (no se graba nada):"
    echo "  minichlink : $MINICHLINK"
    echo "  puerto     : $PUERTO"
    echo "  firmware   : $BIN ($(stat -c%s "$BIN") bytes)"
    exit 0
fi

echo "Grabando $BIN en $PUERTO ..."
exec "$MINICHLINK" -C ardulink -c "$PUERTO" -w "$BIN" flash -b
