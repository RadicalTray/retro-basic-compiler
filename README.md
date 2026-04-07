# Retro Basic Compiler

- Requires [Zig 0.15.2](https://ziglang.org/download/)

Build, the compiler and lister binary are located inside `zig-out/bin`
```
zig build
```

Run
```
# Print to stdout
zig build run -- ./tests/ex3.basic

# Write to file
zig build run -- ./tests/ex3.basic ./tests/ex3.bcode

# Run lister
zig build lister -- ./tests/ex3.bcode
```
