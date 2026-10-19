/* =====================================================================
 *  EXPERIMENTO (v2): LED rojo de la placa CH32V003F4P6  ->  PD1
 *
 *  >>> VERIFICADO EN HARDWARE (v2): el LED rojo se enciende y se apaga
 *  >>> alternando 1,5 s / 1,5 s, justo cuando PD1 esta a LOW.
 *  >>> -> Pin = PD1, polaridad = ACTIVO-BAJO.  Confirmado.
 *  >>> (La grabacion del experimento y la restauracion posterior del blink
 *  >>>  seguro de PC0 engancharon al primer intento con las ventanas.)
 *
 *  ARCHIVO DE REFERENCIA - NO SE COMPILA (PlatformIO solo mira src/).
 *  Para probarlo:  cp extras/led_rojo_pd1.cpp src/main.cpp && pio run -t upload
 *
 *  ---------------------------------------------------------------------
 *  QUE SE SABE YA (confirmado en hardware)
 *  ---------------------------------------------------------------------
 *  - El LED rojo esta EN LA PLACA DEL MICROCONTROLADOR (no en el programador).
 *  - No responde a PC0.
 *  - Parpadea SOLO durante las grabaciones -> cuelga de SWIO = PD1, porque
 *    de los 3 cables que llegan del programador (VCC/GND/SWIO) es el unico
 *    que conmuta.
 *  - Documentacion Zephyr de la placa oficial de WCH:
 *        red_led: led0 { gpios = <&gpiod 1 GPIO_ACTIVE_LOW>; };
 *        "PD1 is wired to led and to SWDIO pin."
 *
 *  ---------------------------------------------------------------------
 *  POR QUE NO BASTA pinMode(PD1, OUTPUT)
 *  ---------------------------------------------------------------------
 *  Mientras SDI/SWD esta activo, el modulo de depuracion es el dueno fisico
 *  del pin y las escrituras GPIO se ignoran.  Hay que desactivar SDI
 *  escribiendo SWJ_CFG = 0b100 en AFIO->PCFR1 (exactamente lo que hace el
 *  board.c de Zephyr y lo que hace GPIO_Remap_SDI_Disable del SPL de WCH).
 *
 *  ---------------------------------------------------------------------
 *  QUE CAMBIA RESPECTO A LA v1 (que no encendio el LED)
 *  ---------------------------------------------------------------------
 *  1) NO se lee GPIOD->INDR para decidir el modo.  Con SDI activo el pin esta
 *     en modo alternate-function y esa lectura puede devolver 0 siempre, con
 *     lo que la v1 se quedaba en "modo seguro" y nunca liberaba PD1.
 *     Aqui la decision es por VENTANA DE TIEMPO, que es determinista.
 *  2) La prueba es INDEPENDIENTE DE LA POLARIDAD: PD1 conmuta despacio
 *     (1,5 s en un nivel, 1,5 s en el otro), asi que el LED se ve encendido
 *     1,5 s y apagado 1,5 s, sea activo-bajo o activo-alto.
 *
 *  ---------------------------------------------------------------------
 *  ADVERTENCIA
 *  ---------------------------------------------------------------------
 *  Con SDI desactivado el programador no entra.  El sketch abre una ventana
 *  de 2 s cada 5 s (LED amarillo fijo) en la que PD1 vuelve a ser SWIO, pero
 *  puede coincidir mal y fallar la grabacion.
 *
 *  RECUPERACION (probada):
 *      1) Pulsar RESET (si la placa tiene boton) o desconectar/enchufar la
 *         alimentacion: al arrancar SDI queda activo por defecto durante la
 *         ventana inicial de 2,5 s -> grabar de inmediato.
 *      2) 'minichlink -C ardulink -c /dev/ttyACM0 -u'  (modo unbrick: borra
 *         toda la flash). Puede necesitar varios intentos.
 *
 *  CONCLUSION: sirve para confirmar el pin y aprender, pero para uso normal
 *  usa un LED externo en PC0 (activo-alto, sin riesgos).
 * ===================================================================== */

#include <Arduino.h>

#define PIN_ROJO      PD1     /* LED rojo de la PCB                 */
#define PIN_AMARILLO  PC0     /* LED externo (testigo / ventana)    */

#define SWJ_CFG_MASK    0x07000000u
#define SWJ_CFG_SDI_OFF 0x04000000u

#define MS_ARRANQUE   2500    /* al reset: SDI activo (ventana)     */
#define MS_LED        3000    /* fase en que PD1 es GPIO            */
#define MS_VENTANA    2000    /* fase en que PD1 vuelve a ser SWIO  */
#define MS_MEDIO_LED  1500    /* 1,5 s ON + 1,5 s OFF (sin importar
                                 la polaridad)                      */

static inline void sdi_off(void)
{
    RCC->APB2PCENR |= RCC_AFIOEN;
    AFIO->PCFR1 = (AFIO->PCFR1 & ~SWJ_CFG_MASK) | SWJ_CFG_SDI_OFF;
}

static inline void sdi_on(void)
{
    RCC->APB2PCENR |= RCC_AFIOEN;
    AFIO->PCFR1 &= ~SWJ_CFG_MASK;
}

/* PD1 -> GPIO, listo para escribir */
static void pd1_como_gpio(void)
{
    sdi_off();
    pinMode(PIN_ROJO, OUTPUT);
    digitalWrite(PIN_ROJO, HIGH);         /* estado de reposo seguro */
}

/* PD1 -> SWIO, para que el programador pueda entrar */
static void pd1_como_swio(void)
{
    pinMode(PIN_ROJO, INPUT);             /* soltar el pin primero   */
    sdi_on();
}

void setup()
{
    RCC->APB2PCENR |= RCC_AFIOEN | RCC_IOPDEN;

    pinMode(PIN_AMARILLO, OUTPUT);
    digitalWrite(PIN_AMARILLO, LOW);

    /* Ventana de arranque: tras un reset SDI esta activo por defecto.
       La dejamos asi MS_ARRANQUE para que grabar sea facil.
       El amarillo parpadea rapido = "puedes grabar ahora". */
    uint32_t ini = millis();
    while (millis() - ini < MS_ARRANQUE) {
        digitalWrite(PIN_AMARILLO, HIGH); delay(80);
        digitalWrite(PIN_AMARILLO, LOW);  delay(80);
    }

    digitalWrite(PIN_AMARILLO, LOW);
    pd1_como_gpio();
}

void loop()
{
    /* --- Fase 1: PD1 es GPIO. El rojo conmuta despacio (1,5 s / 1,5 s) --- */
    uint32_t ini = millis();
    bool nivel = true;
    while (millis() - ini < MS_LED) {
        digitalWrite(PIN_ROJO, nivel ? HIGH : LOW);
        digitalWrite(PIN_AMARILLO, nivel ? LOW : HIGH);   /* espejo      */
        delay(MS_MEDIO_LED);
        nivel = !nivel;
    }
    digitalWrite(PIN_AMARILLO, LOW);

    /* --- Fase 2: devolvemos PD1 a SWIO (ventana de programacion) --- */
    digitalWrite(PIN_AMARILLO, HIGH);     /* amarillo fijo = ventana     */
    pd1_como_swio();
    delay(MS_VENTANA);

    /* --- Fase 3: otra vez GPIO --- */
    digitalWrite(PIN_AMARILLO, LOW);
    pd1_como_gpio();
}
