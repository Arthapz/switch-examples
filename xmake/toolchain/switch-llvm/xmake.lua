toolchain("switch-llvm")
    set_homepage("https://llvm.org/")
    set_description("A collection of modular and reusable compiler and toolchain technologies")

    set_kind("standalone")

    set_toolset("cc", "clang")
    set_toolset("cxx", "clang++", "clang")
    set_toolset("cpp", "clang -E")
    set_toolset("as", "clang++")

    set_toolset("ld", "clang++")
    set_toolset("sh", "clang++")
    set_toolset("ar", "llvm-ar")

    set_toolset("nm", "llvm-nm")
    set_toolset("ranlib", "llvm-ranlib")
    set_toolset("strip", "llvm-strip")
    set_toolset("mrc", "llvm-rc")

    on_check(function(toolchain)
        import("detect.sdks.find_cross_toolchain")

        local sdkdir = toolchain:sdkdir()
        local bindir = toolchain:bindir()
        local cross_toolchain = find_cross_toolchain(sdkdir, {bindir = bindir})
        if not cross_toolchain then
            -- find it from packages
            for _, package in ipairs(toolchain:packages()) do
                local installdir = package:installdir()
                if installdir and os.isdir(installdir) then
                    cross_toolchain = find_cross_toolchain(installdir)
                    if cross_toolchain then
                        break
                    end
                end
            end
        end
        if cross_toolchain then
            toolchain:config_set("bindir", cross_toolchain.bindir)
            toolchain:config_set("sdkdir", cross_toolchain.sdkdir)
            toolchain:configs_save()
        else
            raise("llvm switch toolchain not found!")
        end

        return cross_toolchain
    end)

    on_load(function(toolchain)
        if toolchain:is_plat("switch") then
            local buildflags = {
                "-march=armv8-a+crc+crypto+simd",
                "-mcpu=cortex-a57",
                "-mtune=cortex-a57",
                "-ftls-model=local-exec",
                "-ffunction-sections",
                "-fdata-sections",
                "-fstack-protector-strong",
                "-fPIC",
                "-fexceptions"
            }

            local sharedlinkflags = {
                "-Wl,-Bdynamic",
                "-fPIC",
                "-Wl,--gc-sections",
                "-Wl,-z,text",
                "-Wl,--build-id=sha1",
                "-Wl,--no-undefined",
                "-Wl,--no-dynamic-linker",
                "-Wl,--as-needed",
                "-Wl,--eh-frame-hdr"
            }

            local executablelinkflags = {
                "-Wl,-Bsymbolic",
                "-fPIE",
                "-Wl,-pie",
                "-Wl,--gc-sections",
                "-Wl,-z,text",
                "-Wl,--build-id=sha1",
                "-Wl,--no-undefined",
                "-Wl,--no-dynamic-linker",
                "-Wl,--as-needed",
                "-Wl,--eh-frame-hdr"
            }

            local defines = {
                "-D__SWITCH__=1",
                "-D__SWITCH=1"
            }

            toolchain:add("cxflags", buildflags, {force = true})
            toolchain:add("asflags", buildflags, {force = true})

            toolchain:add("cxflags", defines, {force = true})
            toolchain:add("asflags", defines, {force = true})

            toolchain:add("ldflags", "-fuse-ld=lld", table.unwrap(executablelinkflags), {force = true})
            toolchain:add("shflags", "-fuse-ld=lld", table.unwrap(sharedlinkflags), {force = true})
        end
    end)
toolchain_end()
