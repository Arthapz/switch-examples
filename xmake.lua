add_rules("mode.debug", "mode.release")

set_allowedplats("switch")
set_allowedarchs("switch|aarch64")

set_policy("check.auto_ignore_flags", false)

if is_plat("switch") then
    includes("xmake/toolchain/switch-llvm")
    includes("xmake/platform/switch.lua")

    add_requires("switch-llvm", "switch-tools", {host = true})
    set_arch("aarch64")

    set_toolchains("switch-llvm@switch-llvm")
    add_requires("switch-support-files", "switch-llvm-runtimes", "libnx", "switch-newlib", {debug = is_mode("debug")})
end

includes("helloworld/xmake.lua")
includes("opengl/xmake.lua")
includes("opengl/xmake.lua")
