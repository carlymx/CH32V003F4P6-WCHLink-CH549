#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  diagnostico.sh - comprueba que se puede compilar y grabar el CH32V003F4P6
#
#  Uso:  .opencode/skills/ch32v003-wchlink-ch549/scripts/diagnostico.sh
#
#  No toca el chip ni graba nada: solo mira. Devuelve 0 si todo esta listo.
# ---------------------------------------------------------------------------
set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(cd "$AQUI/../../../.." && pwd)"     # raiz del repositorio
PROYECTO="$RAIZ/ch32v003-blink"
BYID="/dev/serial/by-id/usb-Deqing_CH55xduino_CH55x-if00"
MINICHLINK="$RAIZ/tools/ch32v003fun/minichlink/minichlink"
OBJCOPY="${OBJCOPY:-$HOME/.platformio/packages/toolchain-riscv/bin/riscv-wch-elf-objcopy}"

if [[ -t 1 ]]; then V=$'\e[32m'; R=$'\e[31m'; A=$'\e[33m'; N=$'\e[0m'; else V=; R=; A=; N=; fi
fallos=0
ok()   { printf "  %s OK  %s %s\n"   "$V" "$N" "$1"; }
mal()  { printf "  %sFALLA%s %s\n"   "$R" "$N" "$1"; fallos=$((fallos+1)); }
aviso(){ printf "  %sAVISO%s %s\n"   "$A" "$N" "$1"; }

echo "Repositorio : $RAIZ"
echo "Proyecto    : $PROYECTO"
echo

echo "1. Herramientas"
[[ -x "$MINICHLINK" ]] && ok "minichlink: $MINICHLINK" \
                       || mal "no encuentro minichlink en $MINICHLINK"
command -v pio >/dev/null && ok "pio: $(command -v pio)" \
                          || mal "pio no esta en el PATH"
[[ -x "$OBJCOPY" ]] && ok "objcopy: $(basename "$OBJCOPY")" \
                    || mal "no encuentro objcopy en $OBJCOPY"
[[ -f "$PROYECTO/platformio.ini" ]] && ok "platformio.ini presente" \
                                    || mal "falta $PROYECTO/platformio.ini"
echo

echo "2. Programador WCH-Link CH549 (firmware SWIO)"
if command -v lsusb >/dev/null; then
    if lsusb | grep -q "1209:c550"; then
        ok "detectado en USB como 1209:c550 (CH55xduino)"
    else
        mal "no aparece 1209:c550 en lsusb. ¿Conectado? ¿Con firmware SWIO?"
    fi
else
    aviso "lsusb no disponible, no puedo comprobar el USB"
fi

PUERTO=""
if [[ -e "$BYID" ]]; then
    PUERTO="$BYID";  ok "puerto por ID: $BYID"
else
    CAND=$(ls /dev/ttyACM* 2>/dev/null | head -1 || true)
    if [[ -n "$CAND" ]]; then
        PUERTO="$CAND"
        aviso "no existe el enlace by-id; usare $CAND (el numero puede cambiar)"
    else
        mal "no hay ningun /dev/ttyACM*"
    fi
fi

if [[ -n "$PUERTO" ]]; then
    if command -v fuser >/dev/null && fuser "$PUERTO" >/dev/null 2>&1; then
        mal "$PUERTO esta OCUPADO (¿monitor serie abierto?). Grabacion fallara."
    else
        ok "$PUERTO libre"
    fi
    [[ -r "$PUERTO" && -w "$PUERTO" ]] && ok "permisos de lectura/escritura" \
                                       || mal "sin permisos sobre $PUERTO (¿grupo dialout?)"
fi
echo

echo "3. Permisos del usuario"
if id -nG | tr ' ' '\n' | grep -qx dialout; then
    ok "el usuario esta en el grupo dialout"
else
    mal "el usuario NO esta en dialout:  sudo usermod -aG dialout \$USER  y cerrar sesion"
fi
echo

echo "4. Firmware compilado"
for f in "$PROYECTO/.pio/build/ch32v003f4p6/firmware.elf" \
         "$PROYECTO/.pio/build/ch32v003f4p6/firmware.bin"; do
    if [[ -f "$f" ]]; then
        ok "$(basename "$f")  ($(stat -c%s "$f") bytes)"
    else
        aviso "no existe $(basename "$f"): compila con 'pio run'"
    fi
done
echo

if (( fallos == 0 )); then
    printf "%sTodo listo para: pio run -t upload%s\n" "$V" "$N"
else
    printf "%s%d comprobacion(es) fallida(s)%s\n" "$R" "$fallos" "$N"
fi
exit $(( fallos > 0 ))
