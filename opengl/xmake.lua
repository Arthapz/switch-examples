add_requires("switch-mesa", "glad")

target("opengl")
    set_kind("binary")
    add_rules("mode.debug", "mode.release")

    if is_plat("switch") then
        add_rules("@switch-llvm-sysroot/switch")
    end

    set_languages("c++2b")
    add_files("src/*.cpp")

    add_cxxflags("clangxx::-fexperimental-library", {force = true})
    add_ldflags("clangxx::-fexperimental-library", {force = true})

    set_values("switch.name", "opengl")
    set_values("switch.author", "arthapz")
    set_values("switch.version", "1.33.7")

    add_packages("switch-mesa", "glad")