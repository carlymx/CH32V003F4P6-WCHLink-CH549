#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  nuevo-proyecto.sh - deja un proyecto PlatformIO listo para compilar y
#  grabar el CH32V003F4P6 con el WCH-Link CH549 (firmware SWIO).
#
#  Uso:  .opencode/skills/ch32v003-wchlink-ch549/scripts/nuevo-proyecto.sh <ruta>
#
#  Crea (todo DENTRO del proyecto, sin rutas absolutas a ningun repositorio):
#     <ruta>/platformio.ini      con upload_protocol = custom ya puesto
#     <ruta>/flash.sh            ejecutable, autocontenido
#     <ruta>/src/main.cpp        blink de PC0 (seguro: no toca PD1/SWIO)
#     <ruta>/.vscode/            tareas y ajustes del proyecto
#     <ruta>/.gitignore          ignora .pio/ y tools/
#     <ruta>/tools/minichlink/   descargado (si hay red)
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

# Configuracion de VSCode del propio proyecto (tareas y ajustes)
if [[ -d "$SKILL/templates/vscode" ]]; then
    mkdir -p "$DESTINO/.vscode"
    cp "$SKILL/templates/vscode/"*.json "$DESTINO/.vscode/"
fi

# .gitignore del proyecto, si no lo ha puesto ya PlatformIO
if [[ ! -e "$DESTINO/.gitignore" ]]; then
    cat > "$DESTINO/.gitignore" <<'GI'
# Compilacion de PlatformIO (se regenera con "pio run")
.pio/

# Herramienta descargada por flash.sh; se vuelve a descargar sola
tools/
GI
fi

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

# Deja el proyecto AUTOCONTENIDO: minichlink dentro de <proyecto>/tools/.
# Si ahora no hay red, flash.sh lo volvera a intentar en la primera grabacion.
echo "Preparando minichlink dentro del propio proyecto..."
if (cd "$DESTINO" && ./flash.sh --preparar); then
    echo "  -> el proyecto ya no depende de ningun otro repositorio ni de rutas"
else
    echo "  AVISO: no se ha podido descargar ahora."
    echo "         Se volvera a intentar en la primera grabacion (pio run -t upload)."
fi
echo
echo "Proyecto creado en: $DESTINO"
echo
echo "  platformio.ini   upload_protocol = custom  (ya puesto, sin rutas)"
echo "  flash.sh         ejecutable y autocontenido"
echo "  src/main.cpp     blink de PC0"
echo "  .vscode/         tareas y ajustes del proyecto"
echo "  .gitignore       ignora .pio/ y tools/"
echo "  tools/minichlink minichlink propio del proyecto (si se descargo)"
echo
echo "Siguientes pasos:"
echo "  Abrir la carpeta del proyecto en VSCode, o:"
echo "  cd $DESTINO"
echo "  pio run                 # compilar   (o Ctrl+Alt+B en VSCode)"
echo "  SIMULAR=1 ./flash.sh    # comprobar sin grabar"
echo "  pio run -t upload       # grabar     (o Ctrl+Alt+U en VSCode)"
