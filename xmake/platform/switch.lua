local yuzu_gdbstub_conf = [[
[Debugging]
record_frame_times=false
use_gdbstub\default=true
use_gdbstub=true
gdbstub_port\default=6543
gdbstub_port=6543
program_args\default=true
program_args=
dump_exefs\default=true
dump_exefs=false
dump_nso\default=true
dump_nso=false
enable_fs_access_log\default=true
enable_fs_access_log=false
quest_flag\default=true
quest_flag=false
use_debug_asserts\default=true
use_debug_asserts=false
disable_macro_jit\default=true
disable_macro_jit=false
disable_macro_hle\default=true
disable_macro_hle=false
enable_all_controllers\default=true
enable_all_controllers=false
create_crash_dumps\default=true
create_crash_dumps=false
perform_vulkan_check\default=true
perform_vulkan_check=false
]]

rule("switch")
    add_deps("asm")
    on_load(function(target)
        target:add("packages", "switch-llvm")

        target:add("packages", "switch-newlib", "switch-libnx", "switch-llvm-runtimes", "switch-tools", "switch-support-files")

        if target:kind() == "binary" then
            target:add("cxflags", "-fPIE")
        end

        if target:kind() == "binary" or target:kind() == "shared" then
            local link_scripts_dir = path.join(import("core.project.project").required_package("switch-support-files"):installdir(), "share", "link-scripts")
            local object_dir = path.join(import("core.project.project").required_package("switch-support-files"):installdir(), "lib", "switch-support-files", "switch", "aarch64", is_mode("debug") and "debug" or "release", "src")

            local ldflags = target:get("ldflags")
            target:set("ldflags", path.join(object_dir, "crti.S.o"), {force = true})
            target:add("ldflags", ldflags, {force = true})

            local linker_script = path.join(link_scripts_dir, "nro.ld")
            target:add("ldflags", path.join(object_dir, "crtn.S.o"), "-Wl,-T " .. linker_script, {force = true})

            linker_script = path.join(link_scripts_dir, "nso.ld")
            target:add("shflags", "-Wl,-T " .. linker_script, {force = true})
        end
    end)

    after_build(function(target)
        if not target:kind() == "binary" then
            return
        end

        import("lib.detect.find_tool")
        import("core.project.config")

        local switch_tools = import("core.project.project").required_package("switch-tools"):installdir()
        local elf2nro = find_tool("elf2nro", {require_version = path.filename(path.directory(switch_tools)),
                                              buildhash = path.filename(switch_tools),
                                              installdir = switch_tools,
                                              system = false,
                                              norun = true})
        -- local elf2nro = find_tool("elf2nro", {norun = true})
        assert(elf2nro and elf2nro.program, "elf2nro not in PATH, can't bake nro file")

        local nacptool = find_tool("nacptool", {require_version = path.filename(path.directory(switch_tools)),
                                                buildhash = path.filename(switch_tools),
                                                installdir = switch_tools,
                                                system = false,
                                                norun = true})
        assert(nacptool and nacptool.program, "nacptool not in PATH, can't generate nro metadata")

        local name = target:values("switch.name")
        name = name or "a"

        local author = target:values("switch.author")
        author = author or "unknown"

        local version = target:values("switch.version")
        version = version or "1.0.0"

        local titleid = target:values("switch.titleid")
        titleid = titleid or name

        cprint("${color.build.target}Generating nacp metadata")

        local nacpfile = path.absolute(path.join(target:autogendir(), "metadata.nacp"))

        if not os.isdir(path.directory(nacpfile)) then
            os.mkdir(path.directory(nacpfile))
        end

        local nacp_args = {"--create", name, author, version, nacpfile, "--titleid=" .. titleid}

        vprint(nacptool, table.unpack(nacp_args))
        local outdata, errdata = os.iorunv(nacptool.program, nacp_args)
        vprint(outdata)
        assert(errdata, errdata)

        local target_file = target:targetfile()
        local nro_file = target_file .. ".nro"

        cprint("${color.build.target}Generating nro file")

        local elf2nro_args = {target_file, nro_file, "--nacp=" .. nacpfile}

        vprint(elf2nro, table.unpack(elf2nro_args))
        outdata, errdata = os.iorunv(elf2nro.program, elf2nro_args)
        vprint(outdata)
        assert(errdata, errdata)
    end)

    on_run(function(target)
        if not target:kind() == "binary" then
            return
        end

        import("core.base.option")
        import("core.project.config")

        local yuzu = "yuzu-cmd"-- find_tool("yuzu-cmd")
        assert(yuzu, "yuzu-cmd not in PATH, can't run switch executable")

        local target_file = target:targetfile()
        local executable = target_file .. ".nro"

        local args = {"-g", executable}
        if option.get("debug") then
            config.load()
            local conf_path = path.translate(path.join(config.buildir(), "config", "debug.conf"))

            if not os.exists(conf_path) then
                io.writefile(conf_path, yuzu_gdbstub_conf)
            end

            table.join2(args, {"-c", conf_path})
        end

        os.runv(yuzu, args)
    end)
