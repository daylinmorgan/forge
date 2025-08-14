import std/[os, osproc, strformat, strutils]
import hwylterm/hwylcli
import forge/[config, term, zig]

template parseArgs*(args: seq[string]): seq[string] =
  if args.len == 0:
    args
  elif args[0] == "c":
    args[1 ..^ 1]
  else:
    args

proc formatDirName*(
    formatstr: string, name: string, version: string, target: string
): string =
  var vsn = version
  if ("v$version" in formatstr or "v${version}" in formatstr) and vsn.startsWith("v"):
    vsn = vsn[1 ..^ 1]
  try:
    result = formatstr % ["name", name, "version", vsn, "target", target]
  except ValueError as e:
    errQuit e.msg

  if result == "":
    errQuit &"err processing formatstr: {formatstr}"

proc genFlags(target: string, args: seq[string] = @[]): seq[string] =
  let triplet = parseTriple(target)

  addFlag "cpu"
  addFlag "os"

  result &=
    @[
      "--cc:clang",
      fmt"--clang.exe='{getAppFilename()}'",
      fmt"--clang.linkerexe='{getAppFilename()}'",
      # &"--passC:\"-target {target} -fno-sanitize=undefined\"",
      &"--passC:'-target {triplet}'",
      # &"--passL:\"-target {target} -fno-sanitize=undefined\"",
      &"--passL:'-target {triplet}'",
    ]

proc filterStr(os, arch: seq[string]): string =
  if os.len > 0:
    result.add $bb" [b]os[/]: "
    result.add if os.len == 1: os[0]
               else: os.join(", ")
  if arch.len > 0:
    result.add $bb" [b]arch[/]: "
    result.add if arch.len == 1: arch[0]
               else: arch.join(", ")

import std/sequtils
proc targets(os: seq[string], cpu: seq[string]) =
  ## show available targets
  zigExists()
  if os.len > 0 or cpu.len > 0:
    info "[bold green]filter[/]".bb & filterStr(os, cpu)
  let targets = getTargets(os, cpu)
  if targets.len == 0:
    info "no targets matched filter"
  else:
    info "available targets: \n" & targets.columns()

proc cc(target: string, dryrun: bool = false, nimble: bool = false, args: seq[string]) =
  ## compile with zig cc
  zigExists()
  if args.len == 0:
    errQuit "expected additional arguments i.e. -- -d:release src/main.nim"

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
  if not cfg.hasTargets:
    errQuit "expected at least 1 target"
  if not cfg.hasBins:
    errQuit "expected at least 1 bin"

  checkTargets(cfg.getTriples())

  if verbose:
    info "config = \n" & cfg.bb

  if dryrun:
    info "[bold blue]dry run...see below for commands".bb

  let
    baseCmd = if nimble or cfg.nimble: "nimble" else: "nim"
    rest = parseArgs(args)

  info bbfmt"[bold cyan]{cfg.buildPlan}"

  for (triple, path, params) in cfg.builds:
    var cmdParts: seq[string] = @[]
    let outFlag =
      &"--outdir:'" &
      (cfg.outdir / formatDirName(params.format, cfg.name, cfg.version, triple)) & "'"

    cmdParts &= @[baseCmd, "c"]
    cmdParts.add genFlags(triple, rest)
    cmdParts.add "-d:release"
    cmdParts.add rest
    cmdParts.add outFlag
    cmdParts.add params.args
    cmdParts.add path

    let cmd = cmdParts.join(" ")
    if dryrun:
      stderr.writeLine cmd
    else:
      if verbose:
        info fmt"[bold]cmd[/]: {cmd}".bb
      let errCode = execCmd cmd
      if errCode != 0:
        err "cmd: ", cmd
        errQuit &"exited with code {errCode} see above for err"


const vsn{.strDefine.} = staticExec "git describe --tags --always HEAD"
const forgeArgs= ["+cc", "+targets", "+release", "+r", "-h", "--help", "-V", "--version"]

let params = commandLineParams()
if params.len > 0 and params[0] notin forgeArgs:
  let zigParams =
    if params[0] == "+zig": params[1..^1]
    else: @["cc"] & params
  quit callZig(zigParams)


hwylCli:
  name "forge"
  ... """
  cross-compile nim binaries with [b yellow]zig[/]
 
  example usages:
    forge +release
    forge +zig version
    forge -o hello hello.c
    forge +cc --target x86_64-linux-musl -- -d:release src/forge.nim

  if forge is called with something besides its subcommands it falls back to `zig cc`
  """
  settings ShowHelp
  V vsn
  flags:
    [shared]
    n|`dry-run` "show command instead of executing"
    nimble "use nimble as base command for compiling"
  subcommands:
    ["+targets"]
    ... "show available targets"
    flags:
      os(seq[string], "filter by os")
      cpu(seq[string], "filter by cpu")
    run: targets(os, cpu)

    ["+cc"]
    ...  "compile a single binary with zig cc"
    positionals:
      args seq[string]
    flags:
      ^[shared]
      t|target(string, "target triple"):
        settings Required
    run:
      cc(target, `dry-run`, nimble, args)

    ["+release"]
    ... """
    generate release assets for n>=1 targets

    format argument:
      format is a template string used for each target directory
      available fields are [b i]name, version, target[/]

    if name or version are not specified they will be inferred from the local .nimble file
    """
    alias "+r"
    positionals:
      args seq[string]
    flags:
      ^[shared]
      v|verbose "enable verbose"
      # hwylterm should support @[] syntax and try to infer type to change call
      t|target(newSeq[string](), seq[string], "set target, may be repeated")
      bin(newSeq[string](), seq[string], "set bin, may be repeated")
      format("${name}-v${version}-${target}", string, "set format")
      `config-file`(chooseConfig(), string, "path to config")
      `no-config` "ignore config file"
      o|outdir("dist", string, "path to output dir")
      name(string, "set name, inferred otherwise")
      version(string, "set version, inferred otherwise")
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

    # added so it's included in overall CLI help documentation
    ["+zig"]
    ... "invoke the zig binary used by forge"
