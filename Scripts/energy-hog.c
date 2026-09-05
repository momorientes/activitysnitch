/* Demo CPU hog for ActivitySnitch. Burns three cores (~300 energy impact) so
 * it clears the demo threshold with headroom over normal background apps.
 * With --stubborn it ignores SIGTERM, demonstrating the SIGKILL escalation. */
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile sig_atomic_t got_term = 0;

static void on_term(int sig) { got_term = 1; }

static void *burn(void *arg) {
    for (;;) {}
    return NULL;
}

int main(int argc, char **argv) {
    int stubborn = argc > 1 && strcmp(argv[1], "--stubborn") == 0;
    signal(SIGTERM, on_term);

    pthread_t t1, t2;
    pthread_create(&t1, NULL, burn, NULL);
    pthread_create(&t2, NULL, burn, NULL);

    for (;;) {
        if (got_term) {
            got_term = 0;
            fprintf(stderr, "energy-hog: received SIGTERM%s\n",
                    stubborn ? " — ignoring it" : ", exiting");
            fflush(stderr);
            if (!stubborn) exit(0);
        }
    }
}
