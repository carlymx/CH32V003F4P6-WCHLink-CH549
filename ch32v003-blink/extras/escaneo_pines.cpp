/* =====================================================================
 *  Escaneo de pines GPIO  -  CH32V003F4P6
 *
 *  ARCHIVO DE REFERENCIA - NO SE COMPILA (PlatformIO solo mira src/).
 *  Para usarlo:
 *      cp extras/escaneo_pines.cpp src/main.cpp
 *      pio run -t upload
 *
 *  Enciende los 16 GPIO uno a uno para descubrir en que pin esta un LED.
 *  NO toca PD1 (SWIO + LED rojo de la placa) ni PD7 (NRST).
 *  Por tanto NO iluminara el LED rojo onboard: usa un LED externo.
 *
 *  Temporizacion:
 *      1 s encendido  + 0,5 s apagado por pin
 *      3 s de pausa al terminar la vuelta (referencia para contar)
 *
 *  Orden (paso 1..16):
 *      PC0 PC1 PC2 PC3 PC4 PC5 PC6 PC7
 *      PD0 PD2 PD3 PD4 PD5 PD6 PA1 PA2
 * ===================================================================== */

#include <Arduino.h>

static const uint8_t PINES[] = {
    PC0, PC1, PC2, PC3, PC4, PC5, PC6, PC7,   /*  1.. 8 */
    PD0, PD2, PD3, PD4, PD5, PD6,              /*  9..14 */
    PA1, PA2                                   /* 15..16 */
};
static const uint8_t N_PINES = sizeof(PINES) / sizeof(PINES[0]);

#define MS_ON    1000
#define MS_OFF    500
#define MS_PAUSA 3000

void setup()
{
    /* Todos en alta impedancia: no forzamos ningun nivel entre pasos */
    for (uint8_t i = 0; i < N_PINES; i++)
        pinMode(PINES[i], INPUT);
}

void loop()
{
    for (uint8_t i = 0; i < N_PINES; i++)
    {
        pinMode(PINES[i], OUTPUT);

        digitalWrite(PINES[i], HIGH);   /* probamos nivel alto */
        delay(MS_ON);

        digitalWrite(PINES[i], LOW);
        delay(MS_OFF);

        pinMode(PINES[i], INPUT);       /* y lo liberamos */
    }

    delay(MS_PAUSA);                    /* fin de vuelta */
}
