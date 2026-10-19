#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  nuevo-proyecto.sh - deja un proyecto PlatformIO listo para compilar y
#  grabar el CH32V003F4P6 con el WCH-Link CH549 (firmware SWIO).
#
#  Uso:  .opencode/skills/ch32v003-wchlink-ch549/scripts/nuevo-proyecto.sh <ruta>
#
#  Crea:
#     <ruta>/platformio.ini   con upload_protocol = custom ya puesto
#     <ruta>/flash.sh         ejecutable
#     <ruta>/src/main.cpp     blink de PC0 (seguro: no toca PD1/SWIO)
#
#  No sobreescribe nada: si ya hay un platformio.ini, se planta.
# ---------------------------------------------------------------------------
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd "$AQUI/.." && pwd)"        # .opencode/skills/ch32v003-wchlink-ch549
REPO="$(cd "$SKILL/../../.." && pwd)"  # raiz del repositorio

DESTINO="${1:-}"
if [[ -z "$DESTINO" ]]; then
    echo "Uso: $0 <ruta-del-proyecto-nuevo>" >&2
    exit 1
fi
if [[ -e "$DESTINO/platformio.ini" ]]; then
    echo "ERROR: ya existe $DESTINO/platformio.ini" >&2
    echo "       No lo sobreescribo. Borralo o elige otra ruta." >&2
    exit 1
fi
for f in "$SKILL/templates/platformio.ini" "$SKILL/templates/flash.sh"; do
    [[ -f "$f" ]] || { echo "ERROR: falta la plantilla $f" >&2; exit 1; }
done

mkdir -p "$DESTINO/src"
cp "$SKILL/templates/platformio.ini" "$DESTINO/platformio.ini"
cp "$SKILL/templates/flash.sh"       "$DESTINO/flash.sh"
chmod +x "$DESTINO/flash.sh"

# Sketch inicial: el blink seguro de PC0 del repositorio si esta a mano.
BLINK="$REPO/ch32v003-blink/src/main.cpp"
if [[ -f "$BLINK" ]]; then
    cp "$BLINK" "$DESTINO/src/main.cpp"
else
    cat > "$DESTINO/src/main.cpp" <<'CPP'
#include <Arduino.h>
/* Parpadeo de PC0 a 5 Hz.
   No toca PD1 (SWIO + LED rojo) ni PD7 (NRST): asi el programador
   engancha siempre y no hacen falta ventanas de arranque. */
void setup() { pinMode(PC0, OUTPUT); digitalWrite(PC0, LOW); }
void loop()
{
    digitalWrite(PC0, HIGH); delay(100);
    digitalWrite(PC0, LOW);  delay(100);
}
CPP
fi

echo "Proyecto creado en: $DESTINO"
echo
echo "  platformio.ini   upload_protocol = custom  (ya puesto)"
echo "  flash.sh         ejecutable"
echo "  src/main.cpp     blink de PC0"
echo
echo "Siguientes pasos:"
echo "  cd $DESTINO"
echo "  pio run                 # compilar"
echo "  SIMULAR=1 ./flash.sh    # comprobar sin grabar"
echo "  pio run -t upload       # grabar"
