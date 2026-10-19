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

## 3. Procedimiento para el agente ⭐

Cuando te pidan **crear un proyecto nuevo** para el CH32V003F4P6, haz esto.
No improvises un `platformio.ini`: usa las plantillas de esta skill.

### 3.1 Vía rápida (recomendada): el script

```sh
.opencode/skills/ch32v003-wchlink-ch549/scripts/nuevo-proyecto.sh /ruta/al/proyecto-nuevo
```

Deja el proyecto listo: `platformio.ini` con la grabación puesta, `flash.sh`
ejecutable y un `src/main.cpp` con el blink seguro de PC0. **No sobreescribe
nada**: si ya existe un `platformio.ini`, se planta.

### 3.2 Vía manual (si el script no encaja)

```sh
DESTINO=/ruta/al/proyecto-nuevo
SK=.opencode/skills/ch32v003-wchlink-ch549

mkdir -p "$DESTINO/src"
cp "$SK/templates/platformio.ini" "$DESTINO/platformio.ini"
cp "$SK/templates/flash.sh"       "$DESTINO/flash.sh"
chmod +x "$DESTINO/flash.sh"
```

Y añadir a mano en el `[env:...]` del `platformio.ini`, si no viene de la
plantilla:

```ini
upload_protocol = custom
upload_command  = ./flash.sh $SOURCE
```

### 3.3 Verificar **antes** de dar el trabajo por hecho

```sh
cd "$DESTINO"
pio run                   # tiene que poner SUCCESS
SIMULAR=1 ./flash.sh      # dice que grabaria, sin grabar nada
```

`SIMULAR=1` es la comprobación clave: si ahí aparece la ruta de `minichlink`, el
puerto y el `firmware.bin`, la grabación real va a funcionar.

### 3.4 Después, avisar de dos cosas

- **Dónde está el proyecto**: si queda **dentro** de este repositorio, `flash.sh`
  encuentra `minichlink` solo. Si está **fuera**, hay que indicárselo (ver §5).
- **El hardware**: hace falta la resistencia de 1 kΩ en `SWDIO`↔`3V3` (ver §6).

### 3.5 Lo que NO hay que hacer

- **No** poner `upload_protocol = wch-link`, `minichlink`, `wlink` ni `isp`.
- **No** escribir un `c_cpp_properties.json` a mano (lo gestiona PlatformIO IDE).
- **No** tocar `board_build.core`: el board ya trae `openwch` (es lo correcto).

---

## 4. Las plantillas (qué contienen)

`templates/platformio.ini` — esto, tal cual:

```ini
[env:genericCH32V003F4P6]
platform  = ch32v
board     = genericCH32V003F4P6
framework = arduino

; Opcional pero explicito: el board ya trae build.core = openwch.
; El core "arduino" clasico NO soporta el CH32V003.
board_build.core = openwch

monitor_speed    = 115200

; --- Grabacion (WCH-Link CH549 con firmware SWIO) --------------------------
upload_protocol = custom
upload_command  = ./flash.sh $SOURCE
```

`templates/flash.sh` — el **mismo** fichero que usa este repositorio
(`ch32v003-blink/flash.sh`), copiado byte a byte. Sus variables de entorno
opcionales: `PUERTO`, `MINICHLINK`, `OBJCOPY`, `SIMULAR=1`.

## 5. Dos trampas concretas

### El nombre del entorno decide la carpeta de compilación

El asistente nombra el entorno como la **placa**: `[env:genericCH32V003F4P6]`,
así que el firmware sale en:

```text
.pio/build/genericCH32V003F4P6/firmware.elf
```

…y **no** en `.pio/build/ch32v003f4p6/` como en este repositorio. `flash.sh` no
tiene ese problema: usa el `.elf` que le pasa PlatformIO con `$SOURCE`, y si se
llama a mano busca `.pio/build/*/firmware.elf`.

### Un proyecto fuera de este repositorio necesita minichlink

`flash.sh` busca `tools/ch32v003fun/minichlink/minichlink` **hacia arriba** desde
el proyecto, y si no, en el `PATH`. Si el proyecto está fuera del repositorio:

```ini
; opcion A: decirlo en la linea de grabacion
upload_command = MINICHLINK=/ruta/a/tools/ch32v003fun/minichlink/minichlink ./flash.sh $SOURCE
```

```sh
# opcion B: poner minichlink en el PATH
```

## 6. Recordatorio de hardware

Ninguna configuración de software arregla esto:

- los **3 hilos** (GND, 3V3, SWIO) — `SWCLK` no se conecta,
- la **resistencia de 1 kΩ** entre `SWDIO` y `3V3` en el lado del programador,
- el selector de tensión del programador en **3V3**.

## 7. Mantener las plantillas sincronizadas

`templates/flash.sh` es una copia de `ch32v003-blink/flash.sh`. **Si se cambia
uno, hay que actualizar el otro**, o la skill creará proyectos con una versión
vieja:

```sh
# desde la raíz del repositorio
cp ch32v003-blink/flash.sh .opencode/skills/ch32v003-wchlink-ch549/templates/flash.sh
diff ch32v003-blink/flash.sh .opencode/skills/ch32v003-wchlink-ch549/templates/flash.sh
```
