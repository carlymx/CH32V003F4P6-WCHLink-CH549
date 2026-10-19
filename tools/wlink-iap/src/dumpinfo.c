/* dumpinfo - prueba de conexion con WCH-Link: envia ordenes y muestra la
 * respuesta cruda en hexadecimal.  Usa los helpers de usb.c de wlink-iap.
 *
 * Uso: ./dumpinfo [comando_hex]
 *   Sin argumentos prueba una lista de comandos conocidos.
 *   Ej: ./dumpinfo 810d0101
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libusb.h>
#include "usb.h"

static void hexdump(const char *tag, unsigned char *buf, int n)
{
    int i;
    printf("  %-28s -> %2d bytes:", tag, n);
    for (i = 0; i < n; i++)
        printf(" %02x", buf[i]);
    printf("\n");
}

static int hex2bin(const char *hex, unsigned char *out)
{
    int n = 0;
    while (hex[0] && hex[1]) {
        unsigned v;
        if (sscanf(hex, "%2x", &v) != 1)
            break;
        out[n++] = (unsigned char)v;
        hex += 2;
    }
    return n;
}

static int find_ep(libusb_device_handle *h, int *ep_out, int *ep_in)
{
    struct libusb_config_descriptor *cfg;
    int i, j, k;
    if (libusb_get_active_config_descriptor(libusb_get_device(h), &cfg) != 0)
        return -1;
    printf("Interfaces y endpoints:\n");
    for (i = 0; i < cfg->bNumInterfaces; i++) {
        const struct libusb_interface *itf = &cfg->interface[i];
        for (j = 0; j < itf->num_altsetting; j++) {
            const struct libusb_interface_descriptor *al = &itf->altsetting[j];
            printf("  iface %d alt %d: class %02x sub %02x proto %02x, %d eps\n",
                   al->bInterfaceNumber, al->bAlternateSetting,
                   al->bInterfaceClass, al->bInterfaceSubClass,
                   al->bInterfaceProtocol, al->bNumEndpoints);
            for (k = 0; k < al->bNumEndpoints; k++) {
                const struct libusb_endpoint_descriptor *ep = &al->endpoint[k];
                printf("    ep 0x%02x %s maxpkt %d\n", ep->bEndpointAddress,
                       (ep->bEndpointAddress & 0x80) ? "IN " : "OUT",
                       ep->wMaxPacketSize);
            }
        }
    }
    libusb_free_config_descriptor(cfg);
    return 0;
}

int main(int argc, char **argv)
{
    const uint16_t vids[] = {0x1a86, 0};
    const uint16_t pids[] = {0x8010, 0x8012, 0};
    libusb_device_handle *h = NULL;
    int ep_out = 1, ep_in = 1;
    unsigned char buf[64];
    unsigned int len;
    int r, i;

    static const unsigned char cmds[][4] = {
        {0x81, 0x0d, 0x01, 0x01},  /* ProbeInfo / quitar estado (wlink-iap) */
        {0x81, 0x0d, 0x01, 0xff},  /* "clear programmer state" (minichlink) */
        {0x81, 0x0f, 0x01, 0x01},  /* switch a modo IAP                   */
    };
    static const char *names[] = { "ProbeInfo 81 0d 01 01",
                                  "ClearEst  81 0d 01 ff",
                                  "GoIAP     81 0f 01 01" };

    if (jtag_libusb_open(vids, pids, &h) != 0) {
        fprintf(stderr, "No encuentro el WCH-Link (1a86:8010/8012).\n");
        return 1;
    }

    jtag_libusb_set_configuration(h, 1);
    if (libusb_kernel_driver_active(h, 0) == 1)
        libusb_detach_kernel_driver(h, 0);
    r = libusb_claim_interface(h, 0);
    if (r != 0) {
        fprintf(stderr, "No puedo reclamar la interfaz 0: %s\n", libusb_error_name(r));
        jtag_libusb_close(h);
        return 1;
    }
    printf("WCH-Link abierto (interfaz 0 reclamada).\n");
    find_ep(h, &ep_out, &ep_in);

    if (device_exists(0x1a86, 0x8012) == 0) {
        printf("Modo DAP detectado (8012): endpoints OUT=2 IN=3\n");
        ep_out = 2; ep_in = 3;
    }

    if (argc > 1) {
        unsigned char custom[16];
        int n = hex2bin(argv[1], custom);
        if (argc > 2)
            ep_out = (int)strtol(argv[2], NULL, 0);
        ep_in = ep_out;
        if (n < 4) {
            fprintf(stderr, "Comando hex demasiado corto.\n");
            jtag_libusb_close(h);
            return 1;
        }
        int escrito = 0, leido = 0;
        printf("Usando EP OUT 0x%02x / EP IN 0x%02x\n", ep_out, ep_in | 0x80);
        printf("clear_halt OUT: %s | clear_halt IN: %s\n",
               libusb_error_name(libusb_clear_halt(h, ep_out)),
               libusb_error_name(libusb_clear_halt(h, ep_in | 0x80)));
        len = n;
        printf("Enviando comando de %d bytes a EP 0x%02x (timeout 5s)...\n", n, ep_out);
        r = libusb_bulk_transfer(h, ep_out, custom, n, &escrito, 5000);
        if (r != 0) {
            printf("  escritura FALLO: %s (escritos=%d)\n", libusb_error_name(r), escrito);
        } else {
            usleep(5000);
            memset(buf, 0, sizeof(buf));
            r = libusb_bulk_transfer(h, ep_in | 0x80, buf, 64, &leido, 5000);
            if (r != 0)
                printf("  lectura FALLO: %s (leidos=%d)\n", libusb_error_name(r), leido);
            else
                hexdump("respuesta", buf, leido);
        }
        jtag_libusb_close(h);
        return 0;
    }

    for (i = 0; i < 3; i++) {
        printf("[%d] %s: enviando...\n", i + 1, names[i]);
        len = 4;
        memcpy(buf, cmds[i], 4);
        r = pWriteData(h, ep_out, buf, &len);
        if (r != 0) {
            printf("  escritura FALLO\n");
            continue;
        }
        usleep(3000);
        len = 64;
        memset(buf, 0, sizeof(buf));
        r = pReadData(h, ep_in, buf, &len);
        if (r != 0)
            printf("  lectura FALLO\n");
        else
            hexdump(names[i], buf, len);
        usleep(2000);
    }

    jtag_libusb_close(h);
    return 0;
}
