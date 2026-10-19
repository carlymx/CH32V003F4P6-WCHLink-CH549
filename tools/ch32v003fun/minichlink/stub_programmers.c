/* Stubs para poder compilar minichlink sin la dependencia de hidapi/libudev.
 * Los "programadores" ESP32-S2 y B003Fun no los necesitamos para el WCH-LinkE.
 */
#include <stdint.h>
#include "minichlink.h"

void * TryInit_ESP32S2CHFUN(uint32_t id)
{
	(void)id;
	return 0;
}

void * TryInit_B003Fun(uint32_t id)
{
	(void)id;
	return 0;
}
