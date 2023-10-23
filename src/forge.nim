import std/[os, osproc, sequtils, strformat, strutils, tables, terminal]

import forge/[config, utils, term, zig]

proc genFlags(target: string, args: seq[string] = @[]): seq[string] =
  let triplet = parseTriplet(target)

  addFlag "cpu"
  addFlag "os"

  result &= @[
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
  let targetList = zigTargets()
  termEcho styleBright, fgGreen, "available targets:"
  stderr.writeLine targetList.columns

proc cc(target: string, dryrun: bool = false, nimble: bool = false, args: seq[string]) =
  ## compile with zig cc
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
  ## generate release assets for n>=1 targets
  ##
  ## format argument:
  ##  format is a template string used for each target directory
  ##  available fields are name, version, target
  ##  default: ${name}-v${verison}-${target}
  ##
  ## if name or version are not specified they will be inferred from the local .nimble file

  let cfg = newConfig(
            target,
            bin,
            outdir,
            format,
            name,
            version,
            nimble,
            configFile,
            noConfig
  )

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
      let outFlag = &"--outdir:'" & (
        cfg.outdir / formatDirName(cfg.format, cfg.name, cfg.version, t)
      ) & "'"

      cmdParts &= @[baseCmd, "c"]
      cmdParts.add genFlags(t, rest)
      cmdParts.add "-d:release"
      cmdParts.add rest
      cmdParts.add outFlag
      for a in @[targs, bargs]:
        if a != "": cmdParts.add a
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
  import cligen
  zigExists()

  const
    customMulti = "${doc}Usage:\n  $command {SUBCMD} [sub-command options & parameters]\n\nsubcommands:\n$subcmds"
    vsn = staticExec "git describe --tags --always HEAD"


  if clCfg.useMulti == "": clCfg.useMulti = customMulti
  if clCfg.helpAttr.len == 0:
    clCfg.helpAttr = {"cmd": "\e[1;36m", "clDescrip": "", "clDflVal": "\e[33m",
        "clOptKeys": "\e[32m", "clValType": "\e[31m", "args": "\e[3m"}.toTable
    clCfg.helpAttrOff = {"cmd": "\e[m", "clDescrip": "\e[m", "clDflVal": "\e[m",
        "clOptKeys": "\e[m", "clValType": "\e[m", "args": "\e[m"}.toTable

  var vsnCfg = clCfg
  vsnCfg.version = vsn


  dispatchMulti(
    ["multi", cf = vsnCfg],
    [cc, help = {
      "dryrun": "show command instead of executing",
      "nimble": "use nimble as base command for compiling"
    }],
    [targets],
    [release,
      help = {
      "target": "set target, may be repeated",
      "bin": "set bin, may be repeated",
      "dryrun": "show command instead of executing",
      "format": "set format, see help above",
      "nimble": "use nimble as base command for compiling",
      "config-file": "path to config",
      "no-config": "ignore config file"
      },
    short = {"verbose": 'V'}
    ]
  )
