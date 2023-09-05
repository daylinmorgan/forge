import std/[parsecfg, tables, os, strutils, strformat]

type
  Config* = object
    targets*: OrderedTableRef[string, string]
    bins*: OrderedTableRef[string, string]
    outdir*: string
    format*: string
    name*: string
    version*: string
    nimble*: bool

proc `$`*(c: Config): string =
  var lines: seq[string] = @[]
  lines.add "config ="
  lines.add "| nimble  " & $c.nimble
  lines.add "| outdir  " & c.outdir
  lines.add "| format  " & c.format
  lines.add "| version " & c.version
  lines.add "| targets:"
  for target, args in c.targets:
    lines.add "|   " & target & (if args != "": "|" & args else: "")
  lines.add "| bins:"
  for bin, args in c.bins:
    lines.add "|   " & bin & (if args != "": "|" & args else: "")

  lines.join("\n")

proc loadConfigFile*(f: string): Config =
  let
    dict = loadConfig(f)
    base = dict.getOrDefault("")

  result.targets = newOrderedTable[string, string]()
  result.bins = newOrderedTable[string, string]()

  result.nimble = base.hasKey("nimble")
  result.outdir = base.getOrDefault("outdir")
  result.name = base.getOrDefault("name")
  result.version = base.getOrDefault("version")
  result.format = base.getOrDefault("format")
  if dict.hasKey("target"):
    result.targets = dict.getOrDefault("target")
  if dict.hasKey("bin"):
    result.bins = dict.getOrDefault("bin")

proc inferName(s: string, nimbleFile: string): string =
  if s != "":
    return s
  elif nimbleFile != "":
    return nimbleFile.rsplit(".", maxsplit = 1)[0]

proc findNimbleFile(): string =
  var candidates: seq[string]
  for kind, path in walkDir(getCurrentDir(), relative = true):
    case kind:
      of pcFile, pcLinkToFile:
        if path.endsWith(".nimble"):
          candidates.add path
      else: discard

  # nimble will probably prevent this,
  # but not sure about atlas or bespoke builds
  if candidates.len > 1:
    echo "found multiple nimble files: " & candidates.join(", ")
    echo "cannot infer name or version"
  elif candidates.len == 1:
    return candidates[0]

proc inferVersion(s: string, nimbleFile: string): string =
  if s != "": return s

  # TODO: catch io errors?
  let nimbleCfg = loadConfig(nimbleFile)
  return nimbleCfg.getSectionValue("", "version")

proc inferBin(nimbleFile: string): string =
  let
    pkgName = nimbleFile.split(".")[0]
    default = "src" / &"{pkgName}.nim"
    backup = &"{pkgName}.nim"

  if default.fileExists(): return default
  if backup.fileExists(): return backup


proc newConfig*(
            targets: seq[string],
             bins: seq[string],
             outdir: string,
            format: string,
            name: string,
            version: string,
             nimble: bool,
            configFile: string
             ): Config =

  let nimbleFile = findNimbleFile()

  if configFile.fileExists:
    result = loadConfigFile(configFile)
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
    if format != "": result.format = format
    else: result.format = "${name}-v${version}-${target}"

  for t in targets:
    result.targets[t] = ""
  for b in bins:
    result.bins[b] = ""

  if result.bins.len == 0 and nimbleFile != "":
    let bin = inferBin(nimbleFile)
    if bin != "":
      result.bins[bin] = ""
