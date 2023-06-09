add_rules("mode.debug", "mode.release")

set_allowedplats("switch")
set_allowedarchs("switch|aarch64")

set_policy("check.auto_ignore_flags", false)

if is_plat("switch") then
    set_policy("check.auto_ignore_flags", false)
    add_requires("switch-llvm-sysroot")
    add_requires("switch-tools", {host = true})
    includes("xmake/platform/switch.lua")
end

includes("helloworld/xmake.lua")
includes("nxlink/xmake.lua")
includes("opengl/xmake.lua")
