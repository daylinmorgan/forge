# forge

[![nimble][nimble-shield]][nimpkgs-link]

A basic toolchain to forge (cross-compile) your multi-platform `nim` binaries.

## Why?

`Nim` is a great language and the code is as portable as any other code written in C.
But who wants to manage C toolchains or CI/CD DSL's to cross-compile your code into easily shareable native executable binaries

## Installation

In order to use `forge` you must first install [`zig`](https://ziglang.org/) as all compilation
is done using a thin wrapper around `zig cc`.

> [!NOTE]
> Future versions may use an automated/isolated `zig` installation.

```sh
nimble install forge
```

## Usage

`forge` has a number of subcommands to facilitate compiling `nim` binaries (see `forge --help` for more info.)

### `forge +cc`

To compile a single binary for a platform you can use `forge +cc`.

Example:

```sh
forge +cc --target x86_64-linux-musl -- -d:release src/forge.nim -o:forge
```

### `forge +release`

This command is useful for generating many compiled binaries like you may be accustomed to seeing from `go` or `rust` cli's.
`forge +release` will make attempts to infer many values based on the assumption that it's
likely run from the root directory of a `nim` project with a `<project>.nimble`

You can either specify all commands on the CLI or use a [config](#configuration) file.

### `forge +release` w/configuration

Example:

```sh
forge +release --target,=x86_64-linux-musl,x86_64-macos-none --bin src/forge.nim
```

Result:
```
dist
├── forge-v2023.1001-x86_64-linux-musl
│   └── forge
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
forge +release --verbose --dryrun
```

### `forge +nims`

If you prefer to invoke `nim` directly to compile your program, you can easily extend your existing configuration to rely on `forge`.

`forge +nims` will print a nimscript snippet that will interpret compile time defines (`--os`, `--cpu`, `--d:libc`) to inject the necessary compiler/linker flags to `forge` (`zig cc`).

Example to optionally enable it for your project:

```sh
cat >> config.nims <<EOF
when withDir(thisDir(), fileExists(".forge.nims")):
  when defined(forge): include ".forge.nims"
EOF
forge +nims >  .forge.nims
```

Then to compile you can define `forge` and pass the os and cpu flags to `nim` and a `forge` specific `libc` flag.

```sh
nim c -d:forge --os:Macosx --cpu:aarch64 src/forge.nim
nim c -d:forge --d:libc:musl src/forge.nim
nim c -d:forge -d:target:x86_64-linux-musl src/forge.nim
```

### `forge +zig`

`forge` is a wrapper around `zig` and `zig cc`.
If it's called without any of it's known subcommands (all prefixed by "+") or global flags then it will fall back to `zig cc`.
This way we can deploy a single self-invoking binary since the `clang.exe` specified to `nim` can't have subcommands.

To invoke the same `zig` used by `forge` directly, forwarding all other args, see `forge +zig`.

## Acknowledgements

Thanks to [Andrew Kelley](https://github.com/andrewrk) and the many `zig` [contributors](https://github.com/ziglang/zig/graphs/contributors).


<!-- shields/links -->

[nimble-shield]: https://img.shields.io/github/v/tag/daylinmorgan/forge?filter=v*&logo=Nim&label=nimble&labelColor=black&color=%23f3d400
[nimpkgs-link]: https://nimpkgs.dayl.in/#/pkg/forge
