local triple = "aarch64-unknown-none-elf"

local buildflags = {
    "-march=armv8-a+crc+crypto+simd",
    "--target=" .. triple,
    "-mcpu=cortex-a57",
    "-mtune=cortex-a57",
    "-ftls-model=local-exec",
    "-ffunction-sections",
    "-fdata-sections",
    "-fstack-protector-strong",
    "-fPIC",
    "-mtp=el0",
    "-fvectorize",
    "--rtlib=compiler-rt",
    "-D__SWITCH__=1",
    "-D__SWITCH=1",
    "-DLIBNX_NO_DEPRECATION",
    "-D_GNU_SOURCE=1",
    "-D_LIBC",
    "-D_NEWLIB_VERSION=4.3.0",
    "-D__NEWLIB__=4"
}

local sharedlinkflags = {
    "-fuse-ld=lld",
    "--target=" .. triple,
    "-Wl,-Bdynamic",
    "-fPIC",
    "-Wl,--gc-sections",
    "-Wl,-z,text",
    "-Wl,--build-id=sha1",
    "-Wl,--no-dynamic-linker",
    "-Wl,--as-needed",
    "-Wl,--eh-frame-hdr",
    "-fvisibility=hidden",
    "--rtlib=compiler-rt"
}

local executablelinkflags = {
    "-fuse-ld=lld",
    "--target=" .. triple,
    "-Wl,-Bsymbolic",
    "-fPIE",
    "-Wl,-pie",
    "-Wl,--gc-sections",
    "-Wl,-z,text",
    "-Wl,--build-id=sha1",
    "-Wl,--no-dynamic-linker",
    "-Wl,--as-needed",
    "-Wl,--eh-frame-hdr",
    "-fvisibility=hidden",
    "--rtlib=compiler-rt"
}

local defines = {
}


toolchain("switch")
    set_kind("standalone")
    set_toolset("cc",     "clang")
    set_toolset("cxx",    "clang", "clang++")
    set_toolset("cpp",    "clang -E")
    set_toolset("as",     "clang")
    set_toolset("ld",     "clang++", "clang")
    set_toolset("sh",     "clang++", "clang")
    set_toolset("ar",     "llvm-ar")
    set_toolset("ranlib", "llvm-ranlib")
    set_toolset("strip",  "llvm-strip")
    set_toolset("mrc",    "llvm-rc")

    add_cxflags(buildflags)
    add_asflags(buildflags)
    add_ldflags(executablelinkflags)
    add_shflags(sharedlinkflags)
    add_defines(defines)

    on_load(function (toolchain)

        -- add march flags
        local march
        if toolchain:is_plat("windows") and not is_host("windows") then
            -- cross-compilation for windows
            if toolchain:is_arch("i386", "x86") then
                march = "-target i386-pc-windows-msvc"
            else
                march = "-target x86_64-pc-windows-msvc"
            end
            toolchain:add("ldflags", "-fuse-ld=lld")
            toolchain:add("shflags", "-fuse-ld=lld")
        elseif toolchain:is_arch("x86_64", "x64") then
            march = "-m64"
        elseif toolchain:is_arch("i386", "x86") then
            march = "-m32"
        end
        if march then
            toolchain:add("cxflags", march)
            toolchain:add("mxflags", march)
            toolchain:add("asflags", march)
            toolchain:add("ldflags", march)
            toolchain:add("shflags", march)
        end

        -- init flags for macOS
        if toolchain:is_plat("macosx") then
            local xcode_dir     = get_config("xcode")
            local xcode_sdkver  = toolchain:config("xcode_sdkver")
            local xcode_sdkdir  = nil
            if xcode_dir and xcode_sdkver then
                xcode_sdkdir = xcode_dir .. "/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX" .. xcode_sdkver .. ".sdk"
                toolchain:add("cxflags", "-isysroot " .. xcode_sdkdir)
                toolchain:add("mxflags", "-isysroot " .. xcode_sdkdir)
                toolchain:add("ldflags", "-isysroot " .. xcode_sdkdir)
                toolchain:add("shflags", "-isysroot " .. xcode_sdkdir)
            else
                -- @see https://github.com/xmake-io/xmake/issues/1179
                local macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
                if os.exists(macsdk) then
                    toolchain:add("cxflags", "-isysroot " .. macsdk)
                    toolchain:add("mxflags", "-isysroot " .. macsdk)
                    toolchain:add("ldflags", "-isysroot " .. macsdk)
                    toolchain:add("shflags", "-isysroot " .. macsdk)
                end
            end
            toolchain:add("mxflags", "-fobjc-arc")
        end

        -- add bin search library for loading some dependent .dll files windows
        local bindir = toolchain:bindir()
        if bindir and is_host("windows") then
            toolchain:add("runenvs", "PATH", bindir)
        end

        local sysroot = import("core.project.project").required_package("switch-llvm-sysroot")
        if sysroot:installdir() then
            toolchain:add("ldflags", "-Wl,-T," .. path.join(sysroot:installdir(), "share", "nro.ld"), {force = true})

            toolchain:add("cxflags", "--sysroot=" .. sysroot:installdir(), {force = true})
            toolchain:add("asflags", "--sysroot=" .. sysroot:installdir(), {force = true})
            toolchain:add("ldflags", "-Wl,--sysroot=" .. sysroot:installdir(), {force = true})
            toolchain:add("shflags", "-Wl,--sysroot=" .. sysroot:installdir(), {force = true})

            toolchain:add("ldflags", "-L" .. path.join(sysroot:installdir(), "lib"), {force = true})
            toolchain:add("shflags", "-L" .. path.join(sysroot:installdir(), "lib"), {force = true})
            toolchain:add("ldflags", "-L" .. path.join(sysroot:installdir(), "lib", "nxos"), {force = true})
            toolchain:add("shflags", "-L" .. path.join(sysroot:installdir(), "lib", "nxos"), {force = true})

            toolchain:add("ldflags", "-Wl," .. path.join(sysroot:installdir(), "lib", "nxos", "crti.o"), {force = true})
            toolchain:add("ldflags", "-Wl," .. path.join(sysroot:installdir(), "lib", "nxos", "crtn.o"), {force = true})

            toolchain:add("ldflags", "-lsysbase", "-lnx", "-lpthread")
        end
    end)

toolchain_end()