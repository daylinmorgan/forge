import std/[osproc, strformat, strutils, tables, terminal]
import ccnz/utils

proc genFlags(target: string, args: seq[string]): seq[string] =
  let targetList = zigTargets()
  if target notin targetList:
    errQuit &"unknown target: {target}", "", "must be one of:",
        targetList.columns

  addFlag "cpu"
  addFlag "os"

  result &= @[
    "--cc:clang",
    &"--clang.exe='ccnzcc'",
    &"--clang.linkerexe='ccnzcc'",
    # &"--passC:\"-target {target} -fno-sanitize=undefined\"",
    &"--passC:'-target {target}'",
    # &"--passL:\"-target {target} -fno-sanitize=undefined\"",
    &"--passL:'-target {target}'",
  ]

proc targets() =
  ## show available targets
  let targetList = zigTargets()
  styledEcho styleBright, fgGreen, "available targets:"
  echo targetList.columns

proc cc(target: string, dryrun: bool = false, nimble: bool = false, args: seq[string]) =
  ## compile with zig cc
  let ccArgs = genFlags(target, args)
  if args.len == 0:
    errQuit "expected additional arguments i.e. -- -d:release src/main.nim\n"

  let rest =
    if args[0] == "c":
      args[1..^1]
    else:
      args

  let baseCmd = if nimble: "nimble" else: "nim"
  let cmd = (@[baseCmd] & @["c"] & ccArgs & rest).join(" ")
  if dryrun:
    stderr.write cmd, "\n"
  else:
    quit(execCmd cmd)

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


  dispatchMulti(["multi", cf = vsnCfg], [cc, help = {
      "dryrun": "show command instead of executing",
      "nimble": "use nimble as base command for compiling"
    }, short = {"dryrun": 'n'}],
    [targets])
