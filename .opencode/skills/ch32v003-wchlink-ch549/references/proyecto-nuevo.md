# Crear un proyecto nuevo para el CH32V003F4P6

## 1. El problema: el asistente no pregunta por el programador

Al crear un proyecto desde la interfaz de PlatformIO (*Home → New Project*) solo
se eligen **nombre, placa y framework**. Con `CH32V003F4P6` + `Arduino` genera
exactamente esto:

```ini
[env:genericCH32V003F4P6]
platform = ch32v
board = genericCH32V003F4P6
framework = arduino
```

Eso **compila**, pero **no graba**. Nuestro programador no es un WCH-Link
original, así que ninguno de los protocolos que PlatformIO conoce de serie sirve.

## 2. Por qué no sirve ningún protocolo de serie

El board trae `upload.protocol = wch-link` por defecto y admite
`wch-link`, `minichlink`, `isp` y `wlink`. Ninguno vale aquí:

| Protocolo | Por qué NO sirve |
|---|---|
| `wch-link` *(el que trae el board)* | Espera un WCH-LinkE original con el firmware oficial de WCH |
| `wlink` | Solo lo entiende un WCH-LinkE original |
| `isp` | Es para el bootloader USB de otros CH32, no para SWIO |
| `minichlink` | Llama a minichlink **sin `-C ardulink`** → `Error: Could not initialize any supported programmers` (**comprobado en hardware**) |
| `custom` + `flash.sh` | ✅ **Este es el nuestro** |

---

## 3. Regla de oro: el proyecto es **autocontenido** ⭐

El proyecto nuevo **no debe depender de este repositorio** ni de rutas absolutas.

- ✅ `upload_command  = ./flash.sh $SOURCE` → ruta **relativa al proyecto**.
- ❌ `upload_command  = MINICHLINK=/home/tu-usuario/.../minichlink ./flash.sh $SOURCE`
- ❌ Cualquier `/home/...`, `~/...` o ruta al repositorio RiscV.

Si hace falta una herramienta, se **descarga dentro del propio proyecto**
(`<proyecto>/tools/`). De eso se encarga `flash.sh` solo.

## 4. Procedimiento para el agente

Cuando te pidan **crear un proyecto nuevo** para el CH32V003F4P6, haz esto. No
improvises un `platformio.ini`: usa las plantillas de esta skill.

### 4.1 Vía rápida (recomendada): el script

```sh
.opencode/skills/ch32v003-wchlink-ch549/scripts/nuevo-proyecto.sh /ruta/al/proyecto-nuevo
```

Deja el proyecto **listo y autocontenido**:

| Crea | Qué es |
|---|---|
| `platformio.ini` | Con la grabación ya puesta y **sin ninguna ruta absoluta** |
| `flash.sh` | Copia de la plantilla, ejecutable |
| `src/main.cpp` | Blink seguro de PC0 (no toca PD1/SWIO ni PD7/NRST) |
| `.vscode/` | `tasks.json` + `settings.json` + `extensions.json` del proyecto |
| `.gitignore` | Ignora `.pio/` y `tools/` |
| `tools/minichlink/minichlink` | Descargado **dentro del proyecto** (si hay red) |

No sobreescribe nada: si ya existe un `platformio.ini`, se planta.

### 4.2 Vía manual

```sh
DESTINO=/ruta/al/proyecto-nuevo
SK=.opencode/skills/ch32v003-wchlink-ch549

mkdir -p "$DESTINO/src" "$DESTINO/.vscode"
cp "$SK/templates/platformio.ini" "$DESTINO/platformio.ini"
cp "$SK/templates/flash.sh"       "$DESTINO/flash.sh"
cp "$SK/templates/vscode/"*.json  "$DESTINO/.vscode/"
chmod +x "$DESTINO/flash.sh"
cd "$DESTINO" && ./flash.sh --preparar     # descarga minichlink en el proyecto
```

### 4.3 Verificar **antes** de dar el trabajo por hecho

```sh
cd "$DESTINO"
./flash.sh --help          # el script responde
./flash.sh --preparar      # minichlink esta dentro del proyecto
pio run                    # tiene que poner SUCCESS
SIMULAR=1 ./flash.sh       # dice que grabaria, sin grabar nada
```

Y comprobar que el `platformio.ini` **no tiene rutas absolutas**:

```sh
grep -nE "/(home|Users|root)/" "$DESTINO/platformio.ini" && echo "MAL: hay rutas absolutas"
```

### 4.4 Lo que NO hay que hacer

- **No** poner rutas absolutas ni `MINICHLINK=...` en `upload_command`.
- **No** poner `upload_protocol = wch-link`, `minichlink`, `wlink` ni `isp`.
- **No** escribir un `c_cpp_properties.json` a mano (lo gestiona PlatformIO IDE).
- **No** tocar `board_build.core`: el board ya trae `openwch` (es lo correcto).

---

## 5. Cómo se hace autocontenido el proyecto

`flash.sh` busca `minichlink` en este orden y se queda con el primero que
encuentre:

| Orden | Dónde | Cuándo aplica |
|---|---|---|
| 1 | `$MINICHLINK` | Si se indica a mano (anula todo lo demás) |
| 2 | `<proyecto>/tools/minichlink/minichlink` | **Proyecto autocontenido** |
| 3 | `tools/ch32v003fun/minichlink/minichlink`, subiendo carpetas | Proyectos dentro de este repositorio |
| 4 | `minichlink` en el `PATH` | Si ya está instalado en el sistema |
| 5 | **Lo descarga** en `<proyecto>/tools/minichlink/` | Proyecto suelto, sin red antes |

La descarga (paso 5) viene de un **binario precompilado y oficial del
propio platform `ch32v`**
(`Community-PIO-CH32V/tool-minichlink`, rama `linux`). Comprobado que funciona
con nuestro WCH-Link SWIO. El script dice de dónde lo baja y el `sha256` que ha
obtenido, y comprueba que es un `ELF` de verdad antes de aceptarlo.

La URL se puede cambiar con `MINICHLINK_URL`.

## 6. Las plantillas (qué contienen)

`templates/platformio.ini` — genérica, sin rutas:

```ini
[env:genericCH32V003F4P6]
platform  = ch32v
board     = genericCH32V003F4P6
framework = arduino

board_build.core = openwch        ; el board ya lo trae; se deja explicito
monitor_speed    = 115200

; --- Grabacion (WCH-Link CH549 con firmware SWIO) --------------------------
upload_protocol = custom
upload_command  = ./flash.sh $SOURCE
```

`templates/flash.sh` — el **mismo** fichero que usa este repositorio
(`ch32v003-blink/flash.sh`), copiado byte a byte.

`templates/vscode/` — se copia a `<proyecto>/.vscode/`:

| Fichero | Contenido |
|---|---|
| `tasks.json` | Tareas *Grabar solo*, *Preparar minichlink* y *Ver información del chip*. Todas llaman a `./flash.sh`, así que sirven en cualquier proyecto |
| `settings.json` | Cierra el monitor serie al grabar, oculta `.pio/` del explorador, asocia `*.h` con C++ |
| `extensions.json` | Extensiones recomendadas (PlatformIO, C/C++, OpenCode, corrector ortográfico) |

Las tareas **no** incluyen el *Diagnóstico del entorno* de este repositorio: ese
script es de aquí y no se copia al proyecto.

### Opciones de `flash.sh`

| Uso | Efecto |
|---|---|
| `./flash.sh` | Graba el último firmware compilado |
| `./flash.sh firmware.elf` | Graba ese firmware (lo llama PlatformIO con `$SOURCE`) |
| `./flash.sh --preparar` | Asegura `minichlink` (lo descarga si falta) |
| `./flash.sh --info` | Muestra la información del chip |
| `./flash.sh --simular` | Dice lo que haría, sin grabar |
| `./flash.sh --help` | Ayuda |

Variables: `MINICHLINK`, `MINICHLINK_URL`, `OBJCOPY`, `PUERTO`, `SIMULAR=1`.

## 7. Dos trampas concretas

### 7.1 El nombre del entorno decide la carpeta de compilación

El asistente nombra el entorno como la **placa**: `[env:genericCH32V003F4P6]`,
así que el firmware sale en:

```text
.pio/build/genericCH32V003F4P6/firmware.elf
```

…y **no** en `.pio/build/ch32v003f4p6/` como en este repositorio. `flash.sh` no
tiene ese problema: usa el `.elf` que le pasa PlatformIO con `$SOURCE`, y si se
llama a mano busca `.pio/build/*/firmware.elf`.

### 7.2 El `.gitignore` del proyecto nuevo

El generador ya lo deja puesto. Ignora la compilación y la herramienta
descargada: el binario de `minichlink` se vuelve a descargar solo, así que no
hace falta versionarlo.

```gitignore
.pio/
tools/
```

## 8. Recordatorio de hardware

Ninguna configuración de software arregla esto:

- los **3 hilos** (GND, 3V3, SWIO) — `SWCLK` no se conecta,
- la **resistencia de 1 kΩ** entre `SWDIO` y `3V3` en el lado del programador,
- el selector de tensión del programador en **3V3**.

## 9. Mantener las plantillas sincronizadas

`templates/flash.sh` es una copia de `ch32v003-blink/flash.sh`. **Si se cambia
uno, hay que actualizar el otro**, o la skill creará proyectos con una versión
vieja:

```sh
# desde la raíz del repositorio
cp ch32v003-blink/flash.sh .opencode/skills/ch32v003-wchlink-ch549/templates/flash.sh
diff ch32v003-blink/flash.sh .opencode/skills/ch32v003-wchlink-ch549/templates/flash.sh
```
