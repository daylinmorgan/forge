# forge

[![nimble shield](https://img.shields.io/github/v/tag/daylinmorgan/forge?filter=v*&logo=Nim&label=nimble&labelColor=black&color=%23f3d400)](https://nimble.directory/pkg/forge)


A basic toolchain to forge (cross-compile) your multi-platform `nim` binaries.

## Why?

`Nim` is a great language and the code is as portable as any other code written in C.
But who wants to manage C toolchains or CI/CD DSL's to cross-compile your code into easily sharable native executable binaries

## Installation

In order to use `forge` you must first install [`zig`](https://ziglang.org/) as all compilation
is done using a thin wrapper around `zig cc`.

> [!NOTE]
> Future versions may use an automated/isolated `zig` installation.

```sh
nimble install https://github.com/daylinmorgan/forge
```

## Usage

`Forge` provide two key methods to compile your `nim` source `forge cc` and `forge release`.


### `forge cc`

To compile a single binary for a platform you can use `forge cc`.

Example:

```sh
forge cc --target x86_64-linux-musl -- -d:release src/forge.nim -o:forge
```

### `forge release`

This command is useful for generating many compiled binaries like you may be accustomed to seeing from `go` or `rust` cli's.
`Forge release` will make attempts to infer many values based on the assumption that it's
likely run from the root directory of a `nim` project with a `<project>.nimble`

You can either specify all commands on the CLI or use a config file.

Example:
```sh
forge release -t x86_64-linux-musl -t x86_64-macos-none --bin src/forge.nim
```

Result:
```
dist
├── forge-v2023.1001-x86_64-linux-musl
│   └── forge
└── forge-v2023.1001-x86_64-macos-none
    └── forge
```

The output directories used for each binary are determined
by a format string: `${name}-v${version}-${target}`.
You can modify this with additional info at runtime like using
date instead of version string: `--format "\${name}-$(date +'%Y%M%d')-\${target}"`.

You can also create a config file by default at `./.forge.cfg` that controls the behavior of `forge release`:

```dosini
# flags are specified at the top level
nimble # key without value for booleans
format = "${name}-${target}"
outdir = forge-dist

# use sections to list targets/bins with optional args
[target]
x86_64-linux-musl = "--debugInfo:on"
x86_64-linux-gnu

[bin]
src/forge
src/forgecc = "--opt:size" # use a custom flag for this binary
```

Example:
```sh
forge release --verbose --dryrun
```

Output:
```
forge release -V --dryrun
forge || config =
| nimble  true
| outdir  forge-dist
| format  ${name}-${target}
| version 2023.1001
| targets:
|   x86_64-linux-musl|--debugInfo:on
|   x86_64-linux-gnu
| bins:
|   src/forge
|   src/forgecc|--opt:size
forge || dry run...see below for commands
forge || compiling 2 binaries for 2 targets
nimble c --cpu:amd64 --os:Linux --cc:clang --clang.exe='forgecc' --clang.linkerexe='forgecc' --passC:'-target x86_64-linux-musl' --passL:'-target x86_64-linux-musl' -d:release --outdir:'dist/forge-x86_64-linux-musl' --debugInfo:on src/forge
nimble c --cpu:amd64 --os:Linux --cc:clang --clang.exe='forgecc' --clang.linkerexe='forgecc' --passC:'-target x86_64-linux-musl' --passL:'-target x86_64-linux-musl' -d:release --outdir:'dist/forge-x86_64-linux-musl' --debugInfo:on --opt:size src/forgecc
nimble c --cpu:amd64 --os:Linux --cc:clang --clang.exe='forgecc' --clang.linkerexe='forgecc' --passC:'-target x86_64-linux-gnu' --passL:'-target x86_64-linux-gnu' -d:release --outdir:'dist/forge-x86_64-linux-gnu' src/forge
nimble c --cpu:amd64 --os:Linux --cc:clang --clang.exe='forgecc' --clang.linkerexe='forgecc' --passC:'-target x86_64-linux-gnu' --passL:'-target x86_64-linux-gnu' -d:release --outdir:'dist/forge-x86_64-linux-gnu' --opt:size src/forgecc

```

## Acknowledgements

Thanks to [Andrew Kelley](https://github.com/andrewrk) and the many `zig` [contributors](https://github.com/ziglang/zig/graphs/contributors).
