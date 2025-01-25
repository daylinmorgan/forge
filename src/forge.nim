import std/[os, osproc, sequtils, strformat, strutils, tables]
import forge/[config, utils, term, zig]

proc genFlags(target: string, args: seq[string] = @[]): seq[string] =
  let triplet = parseTriplet(target)

  addFlag "cpu"
  addFlag "os"

  result &=
    @[
      "--cc:clang",
      &"--clang.exe='forgecc'",
      &"--clang.linkerexe='forgecc'",
      # &"--passC:\"-target {target} -fno-sanitize=undefined\"",
      &"--passC:'-target {triplet}'",
      # &"--passL:\"-target {target} -fno-sanitize=undefined\"",
      &"--passL:'-target {triplet}'",
    ]

proc targets() =
  ## show available targets
  zigExists()
  let targetList = zigTargets()
  termEcho "[bold green]available targets:".bb
  stderr.writeLine targetList.columns

proc cc(target: string, dryrun: bool = false, nimble: bool = false, args: seq[string]) =
  ## compile with zig cc
  zigExists()
  if args.len == 0:
    termErrQuit "expected additional arguments i.e. -- -d:release src/main.nim"

  checkTargets(@[target])

  let
    rest = parseArgs(args)
    ccArgs = genFlags(target, rest)
    baseCmd = if nimble: "nimble" else: "nim"
    cmd = (@[baseCmd] & @["c"] & ccArgs & rest).join(" ")

  if dryrun:
    stderr.writeLine cmd
  else:
    quit(execCmd cmd)

proc release(
    target: seq[string] = @[],
    bin: seq[string] = @[],
    args: seq[string],
    outdir: string = "dist",
    format: string = "",
    name: string = "",
    version: string = "",
    dryrun: bool = false,
    nimble: bool = false,
    configFile: string = ".forge.cfg",
    noConfig: bool = false,
    verbose: bool = false,
) =
  zigExists()

  let cfg =
    newConfig(target, bin, outdir, format, name, version, nimble, configFile, noConfig)

  if cfg.targets.len == 0:
    termErrQuit "expected at least 1 target"
  if cfg.bins.len == 0:
    termErrQuit "expected at least 1 bin"

  checkTargets(cfg.targets.keys.toSeq())

  if verbose:
    cfg.showConfig

  if dryrun:
    termEcho "[bold blue]dry run...see below for commands".bb

  let
    baseCmd = if nimble or cfg.nimble: "nimble" else: "nim"
    rest = parseArgs(args)

  termEcho fmt"[bold yellow]compiling {cfg.bins.len} binaries for {cfg.targets.len} targets".bb

  for t, tArgs in cfg.targets:
    for b, bArgs in cfg.bins:
      var cmdParts: seq[string] = @[]
      let outFlag =
        &"--outdir:'" &
        (cfg.outdir / formatDirName(cfg.format, cfg.name, cfg.version, t)) & "'"

      cmdParts &= @[baseCmd, "c"]
      cmdParts.add genFlags(t, rest)
      cmdParts.add "-d:release"
      cmdParts.add rest
      cmdParts.add outFlag
      for a in @[targs, bargs]:
        if a != "":
          cmdParts.add a
      cmdParts.add b

      let cmd = cmdParts.join(" ")
      if dryrun:
        stderr.writeLine cmd
      else:
        if verbose:
          termEcho fmt"[bold]cmd[/]: {cmd}".bb
        let errCode = execCmd cmd
        if errCode != 0:
          termErr "cmd: ", cmd
          termErrQuit &"exited with code {errCode} see above for error"

when isMainModule:
  import hwylterm/hwylcli
  const vsn{.strDefine.} = staticExec "git describe --tags --always HEAD"

  hwylCli:
    name "forge"
    ... "cross-compile nim binaries with [b yellow]zig[/]"
    V vsn
    flags:
      [shared]
      `dry-run`:
        ? "show command instead of executing"
        - n
      nimble:
        ? "use nimble as base command for compiling"
    subcommands:
      [targets]
      ... "show available targets"
      run: targets()

      [cc]
      ...  "compile with zig cc"
      positionals:
        args seq[string]
      flags:
        ^[shared]
        target:
          T string
          ? "target triple"
          - t
      run:
        cc(target, `dry-run`, nimble, args)

      [release]
      ... """
      generate release assets for n>=1 targets

      format argument:
        format is a template string used for each target directory
        available fields are [b i]name, version, target[/]

      if name or version are not specified they will be inferred from the local .nimble file
      """
      positionals:
        args seq[string]
      flags:
        ^[shared]
        verbose:
          ? "enable verbose"
          - v
        target:
          T seq[string]
          ? "set target, may be repeated"
          * newSeq[string]()
          - t
        bin:
          T seq[string]
          ? "set bin, may be repeated"
          * newSeq[string]()
        format:
          T string
          ? "set format"
          * "${name}-v${version}-${target}"
        `config-file`:
          T string
          ? "path to config"
          * ".forge.cfg"
        `no-config`:
          ? "ignore config file"
        outdir:
          T string
          ? "path to output dir"
          * "dist"
          - o
        name:
          T string
          ? "set name, inferred otherwise"
          * ""
        version:
          T string
          ? "set version, inferred otherwise"
          * ""
      run:
        release(
            target,
            bin,
            args,
            outdir,
            format,
            name,
            version,
            `dry-run`,
            nimble,
            `config-file`,
            `no-config`,
            verbose,
        )

