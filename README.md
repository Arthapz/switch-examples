```
xrepo add-repo switch-repo https://github.com/Arthapz/switch-llvm-toolchain.git
xmake f --yes -p switch -m release -a aarch64; xmake b
```

if yuzu in in the PATH you can run

```
xmake run
```

to run the homebrew on yuzu

or

```
xmake run -d
```

to debug the homebrew on yuzu (using gdbserver)