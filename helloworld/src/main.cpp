#include <switch.h>

#include <iostream>
#include <format>

int main(int argc, char **argv) {
    consoleInit(nullptr);

    padConfigureInput(1, HidNpadStyleSet_NpadStandard);

    PadState pad;
    padInitializeDefault(&pad);

    std::cout << std::format("Hello World!\n    cpp standard: {}\n    llvm version: {}\n    newlib version: {}\n", __cplusplus,__clang_version__, __NEWLIB__) << std::endl;

    while(appletMainLoop()) {
        padUpdate(&pad);

        const int kdown = padGetButtonsDown(&pad);

        if(kdown & HidNpadButton_Plus) break;

        consoleUpdate(nullptr);
    }

    consoleExit(nullptr);

    return 0;
}