import std/[os, osproc, strformat, strutils, sequtils, strtabs]
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
      "--clang.exe=" & getAppFilename(),
      "--clang.linkerexe=" & getAppFilename() ,
      "--clang.cpp.exe=" & getAppFilename(),
      "--clang.cpp.linkerexe=" & getAppFilename() ,
      # &"--passC:\"-target {target} -fno-sanitize=undefined\"",
      fmt("--passC=-target {triplet}"),
      # &"--passL:\"-target {target} -fno-sanitize=undefined\"",
      fmt("--passL=-target {triplet}"),
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

proc envWithBackend(backend: string): StringTableRef =
  result = newStringTable(mode = modeCaseSensitive)
  for k, v in envPairs():
    result[k] = v
  result["FORGE_BACKEND"] = backend

proc forgeCompile(baseCmd: string, args: openArray[string], backend: string): int =
  let p = startProcess(
    baseCmd,
    args = args,
    options = {poUsePath, poParentStreams},
    env = envWithBackend(backend)
  )
  result = p.waitForExit()

proc compile(target: string, dryrun: bool = false, nimble: bool = false, args: seq[string], backend = "cc") =
  ## compile with zig cc
  zigExists()
  if args.len == 0:
    errQuit "expected additional arguments i.e. -- -d:release src/main.nim"

  checkTargets(@[target])

  let
    rest = parseArgs(args)
    ccArgs = genFlags(target, rest)
    baseCmd = if nimble: "nimble" else: "nim"
    compileArgs = @[backend] & ccArgs & rest

  if dryrun:
    stderr.writeLine (@[baseCmd] & @[backend] & ccArgs & rest).join(" ")
  else:
    quit forgeCompile(baseCmd, compileArgs, backend)

proc outDirFlag(cfg: Config, build: Build): string =
  result.add "--outdir:"
  result.add cfg.outdir / formatDirName(build.params.format, cfg.name, cfg.version, build.triple)

proc newCompileArgs(cfg: Config, backend: string, build: Build, rest: seq[string]): seq[string] =
  result.add backend
  result.add genFlags(build.triple, rest)
  result.add "-d:release"
  result.add rest
  result.add cfg.outDirFlag(build)
  if build.params.args.len > 0:
    result.add build.params.args
  result.add build.path.normalizedPath()

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
    backend: string = "cc"
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

  let rest = parseArgs(args)

  info bbfmt"[bold cyan]{cfg.buildPlan}"

  for build in cfg.builds:
    let compileArgs = newCompileArgs(cfg, backend, build, rest)
    let cmd = (@[cfg.baseCmd] & compileArgs).join(" ")
    if dryrun or verbose:
      info fmt"[bold]cmd[/]: {cmd}".bb
      if dryrun: continue

    let errCode = forgeCompile(cfg.baseCmd, args = compileArgs, backend = backend)
    if errCode != 0:
      err "cmd: ", cmd
      errQuit &"exited with code {errCode} see above for error"


const vsn{.strDefine.} = staticExec "git describe --tags --always HEAD"
const forgeArgs= ["+cc", "+cpp", "+targets", "+release", "+r", "-h", "--help", "-V", "--version"]

let params = commandLineParams()
if params.len > 0 and params[0] notin forgeArgs:
  let zigParams =
    if params[0] == "+zig": params[1..^1]
    else: @[getForgeBackend()] & params
  quit callZig(zigParams)

type
  NimBackend = enum
    cc = "cc"
    cpp = "cpp"

proc `$`(t: typedesc[NimBackend]): string {.inline.} = "[cc|cpp]"

hwylCli:
  name "forge"
  ... """
  cross-compile nim binaries with [b yellow]zig[/]
 
  example usages:
    forge +release
    forge +zig version
    forge +cc --target x86_64-linux-musl -- -d:release src/forge.nim
    forge +release --backend cpp

  forge is also a wrapper around zig:
    for zig cc:
      forge -o hello hello.c
      forge +zig cc -o hello hello.c
    for zig c++:
      FORGE_BACKEND=cpp forge -o hello hello.cpp
      forge +zig c++ -o hello hello.cpp
  """
  settings ShowHelp
  V vsn
  flags:
    [shared]
    n|`dry-run` "show command instead of executing"
    nimble "use nimble as base command for compiling"
    [single]
    t|target(string, "target triple"):
        settings Required
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
      ^[single]
    run:
      compile(target, `dry-run`, nimble, args)

    ["+cpp"]
    ... "compile a single binary with zig c++"
    positionals:
      args seq[string]
    flags:
      ^[shared]
      ^[single]
    run:
      compile(target, `dry-run`, nimble, args, backend = "cpp")

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
      b|backend(NimBackend.cc, NimBackend, "backend")
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
          backend = $backend
      )

    # added so it's included in overall CLI help documentation
    ["+zig"]
    ... "invoke the zig binary used by forge"
