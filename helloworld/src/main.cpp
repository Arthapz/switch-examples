#include <stdlib.h>
#include <switch.h>

#include <iostream>
#include <format>

thread_local auto foo = 5;

auto main(int argc, char **argv) -> int {
    consoleInit(nullptr);

    padConfigureInput(1, HidNpadStyleSet_NpadStandard);

    PadState pad;
    padInitializeDefault(&pad);

    std::cout << std::format("Hello World!\n    cpp standard: {}\n    llvm version: {}\n    newlib version: {}\n    thread_local test: {}\n", __cplusplus,__clang_version__, __NEWLIB__, foo) << std::endl;

    while(appletMainLoop()) {
        padUpdate(&pad);

        const int kdown = padGetButtonsDown(&pad);

        if(kdown & HidNpadButton_Plus) break;

        consoleUpdate(nullptr);
    }

    consoleExit(nullptr);

    return EXIT_SUCCESS;
}