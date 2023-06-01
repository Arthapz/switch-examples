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

        if (kdown & HidNpadButton_A)
            std::cout << "A Pressed\n";
        if (kdown & HidNpadButton_B)
            std::cout << "B Pressed\n";

        consoleUpdate(nullptr);
    }

    consoleExit(nullptr);

    return EXIT_SUCCESS;
}

static int s_nxlinkSock = -1;

static void initNxLink()
{
    if (R_FAILED(socketInitializeDefault()))
        return;

    s_nxlinkSock = nxlinkStdio();
    if (s_nxlinkSock >= 0)
        std::cout << "printf output now goes to nxlink server";
    else
        socketExit();
}

static void deinitNxLink()
{
    if (s_nxlinkSock >= 0)
    {
        close(s_nxlinkSock);
        socketExit();
        s_nxlinkSock = -1;
    }
}

extern "C" void userAppInit()
{
    initNxLink();
}

extern "C" void userAppExit()
{
    deinitNxLink();
}