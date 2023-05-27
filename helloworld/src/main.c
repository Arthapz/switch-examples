#include <switch.h>

#include <stdio.h>

int main(int argc, char **argv) {
    consoleInit(NULL);

    padConfigureInput(1, HidNpadStyleSet_NpadStandard);

    PadState pad;
    padInitializeDefault(&pad);

    printf("hello world");

    while(appletMainLoop()) {
        padUpdate(&pad);

        const int kdown = padGetButtonsDown(&pad);

        if(kdown & HidNpadButton_Plus) break;

        consoleUpdate(NULL);
    }

    consoleExit(NULL);

    return 0;
}