import std/[parsecfg, paths, os, sequtils, sets, strutils, strformat, tables]
import usu

import ./term

export tables, sets

type ForgeConfig* = object
  targets*: OrderedTableRef[string, string]
  bins*: OrderedTableRef[string, string]
  outdir*: string
  format*: string
  name*: string
  version*: string
  nimble*: bool

type
  Params* = object
    args*: seq[string]
    format*: string
  Target* = object
    triple*: string
    params*: Params
  Bin* = object
    path*: string
    params*: Params
  Config* = object
    name*, version*, format*, outdir*: string
    nimble*: bool
    targets*: seq[Target]
    bins*: seq[Bin]


proc init(_: typedesc[Bin], path: string): Bin =
  result.path = path
proc init(_: typedesc[Target], triple: string): Target =
  result.triple = triple

proc fromUsu[T: Target | Bin](target: var seq[T], u: UsuNode) =
  ## take advantage of Usu's loosing parse the same name twice
  checkKind u, UsuArray
  for e in u.elems:
    checkKind e, {UsuMap, UsuValue}
    case e.kind
    of UsuMap:
      var v: T
      fromUsu(v, e)
      if "params" notin e.fields:
        fromUsu(v.params, e)
      target.add v
    of UsuValue:
      var v: string
      fromUsu(v, e)
      target.add T.init(v)
    else: assert false

func hasTargets*(c: Config): bool {.inline.} =
  c.targets.len > 0
func hasBins*(c: Config): bool {.inline.} =
  c.bins.len > 0

func params*(c: Config, target: Target, bin: Bin): Params =
  result.format = c.format
  for p in [target.params, bin.params]:
    if p.format != "":
      result.format = p.format
    result.args.add p.args

func buildPlan*(c: Config): string =
  fmt"compiling {c.bins.len} binaries for {c.targets.len} targets"


proc showConfig*(c: ForgeConfig) {.deprecated.} =
  var lines: string = ""
  template addLine(l: string) =
    lines.add(l & "\n")

  proc addNameArgs(name, args: string): string =
    result.add fmt"|  {name}"
    if args != "":
      result.add fmt" | " & $args.bb("faint")

  addLine $bbfmt"""
config =
| [blue]nimble[/]  {c.nimble}
| [blue]outdir[/]  {c.outdir}
| [blue]format[/]  {c.format}
| [blue]version[/] {c.version}"""

  addLine $bb"| [green]targets[/]:"
  for target, args in c.targets:
    addLine addNameArgs(target, args)

  addLine $bb"| [green]bins[/]:"
  for bin, args in c.bins:
    addline addNameArgs(bin, args)
  info lines

proc bbImpl(p: Params): string =
  ## returns a string with markup for bbansi
  result.add fmt" | [faint]"
  if p.format != "":
    result.add fmt"[i]format[/]: {p.format}"
  if p.args.len > 0:
    result.add fmt"[i]args[/]: {bbEscape($p.args)}"
  result.add "[/]"

proc empty(p: Params): bool = p.args.len == 0 and p.format == ""

proc bbImpl(c: Config): string =
  template addLine(l: string) =
    result.add(l & "\n")

  addLine fmt"""
| [blue]nimble[/]  {c.nimble}
| [blue]outdir[/]  {c.outdir}
| [blue]format[/]  {c.format}
| [blue]version[/] {c.version}"""

  addLine "| [green]targets[/]:"
  for t in c.targets:
    result.add fmt"|   {t.triple}"
    if not t.params.empty:
      result.add bbImpl(t.params)
    result.add "\n"

  addLine "| [green]bins[/]:"
  for b in c.bins:
    result.add fmt"|   {b.path}"
    if not b.params.empty:
      result.add bbImpl(b.params)
    result.add "\n"
  result.strip()

proc bb*(c: Config): BbString =
  bb(bbImpl(c))

proc fromFile(f: string, load_targets: bool, load_bins: bool): ForgeConfig =
  let dict = loadConfig(f)

  # get the top level flags
  if dict.hasKey(""):
    let base = dict[""]
    result.nimble = base.hasKey("nimble")
    result.outdir = base.getOrDefault("outdir")
    result.name = base.getOrDefault("name")
    result.version = base.getOrDefault("version")
    result.format = base.getOrDefault("format")

  result.targets = newOrderedTable[string, string]()
  result.bins = newOrderedTable[string, string]()

  if dict.hasKey("target") and load_targets:
    result.targets = dict.getOrDefault("target")
  if dict.hasKey("bin") and load_bins:
    result.bins = dict.getOrDefault("bin")

proc inferName(s: string, nimbleFile: string): string =
  if s != "":
    return s
  elif nimbleFile != "":
    return nimbleFile.rsplit(".", maxsplit = 1)[0]

proc findNimbleFile(): string =
  var candidates: seq[string]
  for kind, path in walkDir(os.getCurrentDir(), relative = true):
    case kind
    of pcFile, pcLinkToFile:
      if path.endsWith(".nimble"):
        candidates.add path
    else:
      discard

  # nimble will probably prevent this,
  # but not sure about atlas or bespoke builds
  if candidates.len > 1:
    # should this be an errQuit?
    warn "found multiple nimble files: " & candidates.join(", ")
    warn "cannot infer name or version"
  elif candidates.len == 1:
    return candidates[0]

proc inferVersion(s: string, nimbleFile: string): string =
  if s != "":
    return s

  if nimbleFile.fileExists:
    let nimbleCfg = loadConfig(nimbleFile)
    return nimbleCfg.getSectionValue("", "version")

proc inferBin(nimbleFile: string): string =
  let
    pkgName = nimbleFile.split(".")[0]
    default = "src" / &"{pkgName}.nim"
    backup = &"{pkgName}.nim"

  if default.fileExists():
    return default
  if backup.fileExists():
    return backup

proc newForgeConfig*(
    targets: seq[string],
    bins: seq[string],
    outdir: string,
    format: string,
    name: string,
    version: string,
    nimble: bool,
    configFile: string,
    noConfig: bool,
): ForgeConfig {.deprecated.} =
  let nimbleFile = findNimbleFile()

  if configFile.fileExists and not noConfig:
    if Path(configFile).splitFile.ext in [".ini", ".cfg"]:
      warn "ini format config may be deprecated in a future release"
    result = fromFile(configFile, targets.len == 0, bins.len == 0)
  else:
    # no seg faults here...
    result.targets = newOrderedTable[string, string]()
    result.bins = newOrderedTable[string, string]()

  result.nimble = result.nimble or nimble

  if result.outdir == "" or (result.outdir != "dist" and outdir != "dist"):
    result.outdir = outdir

  if result.name == "":
    result.name = inferName(name, nimbleFile)
  if result.version == "":
    result.version = inferVersion(version, nimbleFile)
  if result.format == "":
    result.format = format

  for t in targets:
    result.targets[t] = ""
  for b in bins:
    result.bins[b] = ""

  if result.bins.len == 0 and nimbleFile != "":
    let bin = inferBin(nimbleFile)
    if bin != "":
      result.bins[bin] = ""


proc to(old: ForgeConfig, _: typedesc[Config]): Config =
  ## convert deprecated config to new config

  result.name = old.name
  result.version = old.version
  result.nimble = old.nimble
  result.format = old.format
  result.outdir = old.outdir

  for triple, args in old.targets.pairs:
    result.targets.add Target(triple: triple, params: Params(args: args.split(" ")))
  for path, args in  old.bins.pairs:
    result.bins.add Bin(path: path, params: Params(args: args.split(" ")))

proc newConfig*(
    targets: seq[string],
    bins: seq[string],
    outdir: string,
    format: string,
    name: string,
    version: string,
    nimble: bool,
    configFile: string,
    noConfig: bool,
): Config =
  let nimbleFile = findNimbleFile()

  if configFile.fileExists and not noConfig:
    let ext = Path(configFile).splitFile.ext
    case ext
    of ".ini",".cfg":
      result = fromFile(configFile, targets.len == 0, bins.len == 0).to(Config)
    of ".usu":
      result = parseUsu(configFile.readFile).to(Config)
    else:
      errQuit "unexpected config file format: ", ext, "supported formats: ini, cfg, usu"

  result.nimble = result.nimble or nimble

  # TODO: make sure this is consistent?
  if result.outdir == "" or (result.outdir != "dist" and outdir != "dist"):
    result.outdir = outdir

  if result.name == "":
    result.name = inferName(name, nimbleFile)
  if result.version == "":
    result.version = inferVersion(version, nimbleFile)
  if result.format == "":
    result.format = format

  for t in targets:
    result.targets.add Target.init(t)
  for b in bins:
    result.bins.add Bin.init(b)

  if result.bins.len == 0 and nimbleFile != "":
    let bin = inferBin(nimbleFile)
    if bin != "":
      result.bins.add Bin.init(bin)

func getTriples*(c: Config): seq[string] {.inline.} =
  c.targets.mapIt(it.triple)

func baseCmd*(c: Config): string =
  if c.nimble: "nimble"
  else: "nim"

proc chooseConfig*(): string =
  ## select a default file from the current directory
  const candidates = [
    "forge.usu", ".forge.usu",
    "forge.cfg", "forge.ini",
    ".forge.cfg", ".forge.ini"
  ]
  for p in candidates:
    if p.fileExists:
      return p

when isMainModule:
  const configStr = """
#.nimble true
.format "${name}-${target}"
.outdir forge-dist

.targets [
  x86_64-linux-musl
  {.triple x86_64-macos-none .args [--opt:speed]}
  {.triple x86_64-linux-gnu .format "${name}-x86_64-linux-not-musl"}
]

.bins [
  src/forge
  {
    .path src/forgecc
    .params {.args [--opt:size]}
  }
]
"""

  let c = parseUsu(configStr).to(Config2)
  echo c
  # echo c.bins.settings
  # echo c.params("x86_64-linux-musl", "src/forge")
