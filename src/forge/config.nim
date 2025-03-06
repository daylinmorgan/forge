import std/[parsecfg, paths, os, sequtils, sets, strutils, strformat, tables]
import term
import usu
from usu/parser import UsuParserError, UsuNodeKind

export tables

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
    args*: string
    format*: string
  Settings = OrderedTableRef[string, Params]
  Targets = object
    triples: HashSet[string]
    settings: Settings
  Bins = object
    paths: HashSet[string]
    settings: Settings
  Config* = object
    name*, version*, format*, outdir*: string
    nimble*: bool
    targets: Targets
    bins: Bins

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
  if p.args != "":
    result.add fmt"[i]args[/]: {p.args}"
  result.add "[/]"

proc bbImpl(c: Config): string =
  template addLine(l: string) =
    result.add(l & "\n")

  addLine fmt"""
| [blue]nimble[/]  {c.nimble}
| [blue]outdir[/]  {c.outdir}
| [blue]format[/]  {c.format}
| [blue]version[/] {c.version}"""

  addLine "| [green]targets[/]:"
  for triple in c.targets.triples:
    result.add fmt"|   {triple}"
    if triple in c.targets.settings:
      result.add bbImpl(c.targets.settings[triple])
    result.add "\n"

  addLine "| [green]bins[/]:"
  for bin in c.bins.paths:
    result.add fmt"|   {bin}"
    if bin in c.bins.settings:
      result.add bbImpl(c.bins.settings[bin])
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

template checkKind(node: UsuNode, k: UsuNodeKind) =
  if node.kind != k:
    raise newException(UsuParserError, "Expected node kind: " & $k & ", got: " & $node.kind & ", node: " & $node)

proc parseHook(s: var string, node: UsuNode) =
  checkKind node, UsuValue
  s = node.value

proc parseHook(s: var bool, node: UsuNode) =
  checkKind node, UsuValue
  s = parseBool(node.value)

proc parseHook[T](s: var seq[T], node: UsuNode) =
  checkKind node, UsuArray
  for n in node.elems:
    var e: T
    parseHook(e, n)
    s.add e

proc parseHook[T](s: var HashSet[T], node: UsuNode) =
  checkKind node, UsuArray
  for n in node.elems:
    var e: T
    parseHook(e, n)
    s.incl e

proc parseHook[K,V](t: var OrderedTableRef[K, V], node: UsuNode) =
  checkKind node, UsuMap
  new t
  for k, v in node.fields.pairs:
    var p: Params
    parseHook(p, v)
    t[k] = p

proc parseHook(o: var object, node: UsuNode) =
  checkKind node, UsuMap
  for name, value in o.fieldPairs:
    if name in node.fields:
      parseHook(value, node.fields[name])

proc to[T](node: UsuNode, t: typedesc[T]): T =
  parseHook(result, node)

proc to(old: ForgeConfig, _: typedesc[Config]): Config =
  ## convert deprecated config to new config
  result.nimble = old.nimble
  result.format = old.format
  result.outdir = old.outdir
  result.targets.triples = old.targets.keys().toSeq().toHashSet()
  new result.targets.settings
  for k, v in old.targets.pairs:
    if v != "":
      result.targets.settings[k] = Params(args: v)
  result.bins.paths = old.bins.keys().toSeq().toHashSet()
  new result.bins.settings
  for k, v in old.bins.pairs:
    if v != "":
      result.bins.settings[k] = Params(args: v)

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
      warn "usu handling is unstable and may be replaced in a future release"
      # TODO: gracefully handle failures
      result = parseUsu(configFile.readFile).to(Config)
    else:
      errQuit "unexpected config file format: ", ext, "supported formats: ini, cfg, usu"

  else:
    new result.targets.settings
    new result.bins.settings

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
    result.targets.triples.incl t
  for b in bins:
    result.bins.paths.incl b

  if result.bins.paths.len == 0 and nimbleFile != "":
    let bin = inferBin(nimbleFile)
    if bin != "":
      result.bins.paths.incl bin

func hasTargets*(c: Config): bool {.inline.} =
  c.targets.triples.len > 0
func hasBins*(c: Config): bool {.inline.} =
  c.bins.paths.len > 0

func getParams(x: Targets | Bins, item: string): Params =
  if item in x.settings:
    result = x.settings[item]

func params(c: Config, triple: string, path: string): Params =
  result.format = c.format
  let tripleParams = c.targets.getParams(triple)
  let binParams = c.bins.getParams(path)

  for p in [tripleParams, binParams]:
    if p.format != "":
      result.format = p.format
    if p.args != "":
      result.args.add " " & p.args & " "

iterator builds*(c: Config): tuple[triple: string, bin: string, params: Params] =
  for t in c.targets.triples:
    for b in c.bins.paths:
      yield (t, b, c.params(t, b))

func getTriples*(c: Config): seq[string] {.inline.} =
  c.targets.triples.toSeq()

func buildPlan*(c: Config): string =
  fmt"compiling {c.bins.paths.len} binaries for {c.targets.triples.len} targets"

proc chooseConfig*(): string =
  ## select a default file from the current directory
  template exists(p: string): untyped =
    if p.fileExists: return p 
  exists "forge.usu"
  exists ".forge.usu"
  exists "forge.cfg"
  exists "forge.ini"
  exists ".forge.cfg"
  exists ".forge.ini"

when isMainModule:
  const configStr = """
#:nimble true
#:outdir forge-dist
:format ${name}-${target}
:targets (
  :triples (
    x86_64-linux-musl
    x86_64-linux-gnu
    x86_64-windows-gnu
    x86_64-macos-none
    aarch64-macos-none
    aarch64-linux-gnu
  )
  :settings (
    :x86_64-linux-musl (:args "--opt:speed")
    :x86-linux-gnu (:format "${name}-x86_64-linux-not-musl")
  )
)

:bins (
  :paths (src/forge src/forgecc)
  :settings (
    :src/forge (:args "--opt:size")
  )
)
"""
  let c = parseUsu(configStr).to(Config)
  echo c.params("x86_64-linux-musl", "src/forge")
  for triple, path, params in c.builds:
    echo fmt"{triple=}, {path=}, {params=}"
    echo params.format
