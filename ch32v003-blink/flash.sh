#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  flash.sh - graba el firmware del proyecto en el CH32V003F4P6
#
#  Uso normal (asi lo llama PlatformIO):
#      ./flash.sh <firmware.elf | firmware.bin>
#
#  Uso a mano:
#      ./flash.sh                 usa el ultimo firmware compilado
#      ./flash.sh --preparar      asegura minichlink (lo descarga si falta)
#      ./flash.sh --info          muestra la informacion del chip
#      ./flash.sh --simular       dice lo que haria, sin grabar nada
#      ./flash.sh --help
#
#  El proyecto es AUTOCONTENIDO: si no encuentra minichlink lo descarga en
#  <proyecto>/tools/minichlink/. No depende de ningun otro repositorio ni de
#  rutas absolutas.
#
#  Variables de entorno, todas opcionales:
#      MINICHLINK      ruta a minichlink (tiene prioridad sobre todo lo demas)
#      MINICHLINK_URL  de donde descargarlo si falta
#      OBJCOPY         ruta a riscv-wch-elf-objcopy
#      PUERTO          puerto serie del programador
#      SIMULAR=1       no graba: solo informa de lo que haria
# ---------------------------------------------------------------------------
set -euo pipefail

PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINICHLINK_URL="${MINICHLINK_URL:-https://raw.githubusercontent.com/Community-PIO-CH32V/tool-minichlink/linux/minichlink}"
MINICHLINK_LOCAL="$PROYECTO/tools/minichlink/minichlink"
BYID="/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00"

ACCION="grabar"
ENTRADA=""
for arg in "$@"; do
    case "$arg" in
        --preparar) ACCION="preparar" ;;
        --info)     ACCION="info" ;;
        --simular)  SIMULAR=1 ;;
        --help|-h)  ACCION="ayuda" ;;
        -*)         echo "ERROR: opcion desconocida: $arg" >&2; exit 2 ;;
        *)          ENTRADA="$arg" ;;
    esac
done

uso() {
    cat <<'TXT'
Uso: flash.sh [opciones] [firmware.elf|firmware.bin]

  (sin opciones)   graba; sin argumento usa el ultimo firmware compilado
  --preparar       asegura minichlink (lo descarga en tools/minichlink si falta)
  --info           muestra la informacion del chip
  --simular        dice lo que haria, sin grabar nada
  --help           esto

Variables de entorno: MINICHLINK  MINICHLINK_URL  OBJCOPY  PUERTO  SIMULAR=1
TXT
}
if [[ "$ACCION" == "ayuda" ]]; then uso; exit 0; fi

# --- Localizar minichlink --------------------------------------------------
# Orden:
#   1) $MINICHLINK
#   2) <proyecto>/tools/minichlink/minichlink      (proyecto autocontenido)
#   3) tools/ch32v003fun/minichlink/minichlink     subiendo desde el proyecto
#   4) minichlink en el PATH
#   5) descargarlo en <proyecto>/tools/minichlink/
localizar_minichlink() {
    if [[ -n "${MINICHLINK:-}" ]]; then printf '%s' "$MINICHLINK"; return; fi
    if [[ -x "$MINICHLINK_LOCAL" ]]; then printf '%s' "$MINICHLINK_LOCAL"; return; fi
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

descargar_minichlink() {
    echo "No encuentro minichlink. Lo descargo dentro del propio proyecto:"
    echo "  destino : $MINICHLINK_LOCAL"
    echo "  origen  : $MINICHLINK_URL"
    mkdir -p "$(dirname "$MINICHLINK_LOCAL")"
    local tmp="$MINICHLINK_LOCAL.parcial"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$MINICHLINK_URL" -o "$tmp"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp" "$MINICHLINK_URL"
    else
        rm -f "$tmp"
        echo "ERROR: necesito 'curl' o 'wget' para descargarlo." >&2
        echo "       Instala uno, o pasame la ruta:  MINICHLINK=/ruta/a/minichlink" >&2
        return 1
    fi
    # Comprobar que lo descargado es un ejecutable ELF y no una pagina de error
    if [[ "$(head -c 4 "$tmp" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]]; then
        rm -f "$tmp"
        echo "ERROR: lo descargado no es un ejecutable ELF." >&2
        echo "       ¿Ha cambiado la URL de MINICHLINK_URL?" >&2
        return 1
    fi
    chmod +x "$tmp"
    mv "$tmp" "$MINICHLINK_LOCAL"
    echo "  descargado: $(stat -c%s "$MINICHLINK_LOCAL") bytes"
    echo "  sha256    : $(sha256sum "$MINICHLINK_LOCAL" | cut -d' ' -f1)"
}

MINICHLINK="$(localizar_minichlink)"
if [[ ! -x "$MINICHLINK" ]]; then
    descargar_minichlink
    MINICHLINK="$MINICHLINK_LOCAL"
fi

if [[ "$ACCION" == "preparar" ]]; then
    echo "minichlink listo: $MINICHLINK"
    exit 0
fi

# --- Localizar el puerto ---------------------------------------------------
# Por ID de USB y no por numero: si hay mas de un ttyACM el numero cambia.
if [[ "${PUERTO:-}" == "" ]]; then
    if [[ -e "$BYID" ]]; then PUERTO="$BYID"; else PUERTO="/dev/ttyACM0"; fi
fi
if [[ ! -e "$PUERTO" ]]; then
    echo "ERROR: no existe $PUERTO" >&2
    echo "       ¿Esta el WCH-Link conectado? Debe salir en 'lsusb' como 1209:c550." >&2
    exit 1
fi

if [[ "$ACCION" == "info" ]]; then
    exec "$MINICHLINK" -C ardulink -c "$PUERTO" -i
fi

# --- Localizar el firmware -------------------------------------------------
# PlatformIO pasa $SOURCE (el .elf). Si se llama a mano sin argumentos, se
# busca el .elf del build, sea cual sea el nombre del entorno.
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

if [[ -z "$BIN" || ! -f "$BIN" ]]; then
    echo "ERROR: no encuentro el firmware." >&2
    echo "       Compila primero con: pio run" >&2
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
