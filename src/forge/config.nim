import std/[parsecfg, tables, paths, os, strutils, strformat]
import term

type ForgeConfig* = object
  targets*: OrderedTableRef[string, string]
  bins*: OrderedTableRef[string, string]
  outdir*: string
  format*: string
  name*: string
  version*: string
  nimble*: bool

proc showConfig*(c: ForgeConfig) =
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

proc loadConfigFile*(f: string, load_targets: bool, load_bins: bool): ForgeConfig =
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
): ForgeConfig =
  let nimbleFile = findNimbleFile()

  if configFile.fileExists and not noConfig:
    if Path(configFile).splitFile.ext in [".ini", ".cfg"]:
      warn "ini format config may be deprecated in a future release"
    result = loadConfigFile(configFile, targets.len == 0, bins.len == 0)
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
