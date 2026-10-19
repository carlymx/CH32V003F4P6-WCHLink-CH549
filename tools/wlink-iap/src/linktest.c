/* linktest - Prueba de conexion con el WCH-Link.
 *
 *  1. Comprueba que el dispositivo aparece en USB y muestra sus datos.
 *  2. Intenta hablar con el firmware (comando ProbeInfo en EP1).
 *  3. Si no responde: hace un reset USB del Link y lo reintenta.
 *
 * Todo es solo lectura/consulta: no escribe flash.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libusb.h>

static libusb_context *ctx = NULL;

struct link {
    libusb_device_handle *h;
    int ep_out, ep_in;
};

static int abrir(struct link *l)
{
    libusb_device **list;
    ssize_t n;
    int i;

    l->h = NULL;
    l->ep_out = 1;
    l->ep_in = 1;

    n = libusb_get_device_list(ctx, &list);
    for (i = 0; i < n; i++) {
        struct libusb_device_descriptor d;
        if (libusb_get_device_descriptor(list[i], &d) != 0)
            continue;
        if (d.idVendor == 0x1a86 && (d.idProduct == 0x8010 || d.idProduct == 0x8012)) {
            printf("  encontrado %04x:%04x en bus %d dir %d\n",
                   0x1a86, d.idProduct,
                   libusb_get_bus_number(list[i]),
                   libusb_get_device_address(list[i]));
            if (d.idProduct == 0x8012) {
                l->ep_out = 2;
                l->ep_in = 3;
            }
            if (libusb_open(list[i], &l->h) != 0) {
                printf("  libusb_open fallo\n");
                l->h = NULL;
            }
            break;
        }
    }
    libusb_free_device_list(list, 1);

    if (!l->h)
        return 1;

    if (libusb_kernel_driver_active(l->h, 0) == 1)
        libusb_detach_kernel_driver(l->h, 0);
    if (libusb_claim_interface(l->h, 0) != 0) {
        printf("  no puedo reclamar interfaz 0\n");
        libusb_close(l->h);
        l->h = NULL;
        return 1;
    }
    return 0;
}

static void cerrar(struct link *l)
{
    if (l->h) {
        libusb_release_interface(l->h, 0);
        libusb_close(l->h);
        l->h = NULL;
    }
}

/* envia cmdn bytes a EP out, espera respuesta; devuelve nº de bytes o -1 */
static int comando(struct link *l, unsigned char *cmd, int cmdn,
                   unsigned char *resp, int respsz, const char *etiqueta)
{
    int escrito = 0, leido = 0, r;

    r = libusb_bulk_transfer(l->h, l->ep_out, cmd, cmdn, &escrito, 1500);
    if (r != 0) {
        printf("  %-22s escritura: FALLO (%s)\n", etiqueta, libusb_error_name(r));
        return -1;
    }
    usleep(5000);
    r = libusb_bulk_transfer(l->h, l->ep_in | 0x80, resp, respsz, &leido, 1500);
    if (r != 0) {
        printf("  %-22s lectura:   FALLO (%s)\n", etiqueta, libusb_error_name(r));
        return -1;
    }
    printf("  %-22s respuesta (%d bytes):", etiqueta, leido);
    for (int i = 0; i < leido; i++)
        printf(" %02x", resp[i]);
    printf("\n");
    return leido;
}

int main(void)
{
    struct link l;
    unsigned char cmd[4] = {0x81, 0x0d, 0x01, 0x01};
    unsigned char resp[64];
    int n;

    libusb_init(&ctx);

    printf("PASO 1: busqueda del dispositivo\n");
    if (abrir(&l) != 0) {
        printf("RESULTADO: el WCH-Link no aparece en USB.\n");
        return 1;
    }
    printf("  dispositivo abierto (EP OUT=%d, EP IN=%d)\n", l.ep_out, l.ep_in);

    printf("PASO 2: comando de identificacion (sin tocar nada)\n");
    n = comando(&l, cmd, 4, resp, sizeof(resp), "ProbeInfo");

    if (n < 7) {
        cerrar(&l);
        printf("PASO 3: reset USB del Link (equivale a desenchufar/enchufar)\n");
        if (abrir(&l) != 0) {
            printf("RESULTADO: no puedo reabrir el dispositivo tras el reset.\n");
            return 1;
        }
        int r = libusb_reset_device(l.h);
        printf("  libusb_reset_device: %s\n", r == 0 ? "OK" : libusb_error_name(r));
        cerrar(&l);
        sleep(2);
        printf("  reabriendo...\n");
        if (abrir(&l) != 0) {
            printf("RESULTADO: el Link no ha vuelto tras el reset. Necesita desenchufar/enchufar a mano.\n");
            return 1;
        }
        printf("PASO 4: comando de identificacion (tras el reset)\n");
        n = comando(&l, cmd, 4, resp, sizeof(resp), "ProbeInfo");
    }

    printf("\nRESULTADO: ");
    if (n >= 7) {
        printf("el Link RESPONDE. Respuesta =");
        for (int i = 0; i < n; i++)
            printf(" %02x", resp[i]);
        printf("\n  version firmware = %d.%d, variante = 0x%02x\n",
               resp[3], resp[4], resp[5]);
    } else if (n >= 0) {
        printf("el Link responde pero con datos insuficientes (%d bytes).\n", n);
    } else {
        printf("el Link esta colgado: no responde a los comandos.\n");
    }

    cerrar(&l);
    libusb_exit(ctx);
    return 0;
}
