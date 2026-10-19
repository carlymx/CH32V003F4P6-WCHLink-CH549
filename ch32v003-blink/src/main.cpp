#include <Arduino.h>

/* =====================================================================
 *  Parpadeo simple del pin PC0  -  CH32V003F4P6
 *
 *  Compilar:  pio run
 *  Grabar:    pio run -t upload
 *
 *  Solo se toca PC0. No se configura ningún otro pin.
 *
 *  NOTA: el LED rojo de la PCB NO esta en PC0. Esta en PD1 y comparte
 *  pin con SWIO, por lo que no se puede usar como GPIO normal sin
 *  desactivar la depuracion (ver extras/led_rojo_pd1.cpp).
 * ===================================================================== */

#define LED_PIN   PC0     /* pin que parpadea                        */
#define T_ON_MS   100     /* tiempo encendido                        */
#define T_OFF_MS  100     /* tiempo apagado                          */

void setup()
{
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);      /* empezamos apagado */
}

void loop()
{
    digitalWrite(LED_PIN, HIGH);
    delay(T_ON_MS);
    digitalWrite(LED_PIN, LOW);
    delay(T_OFF_MS);
}
