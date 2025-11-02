import std/[
  os, strformat, strutils, distros
]

import ./[config, term, zig, macos_sdk]
export config, term, zig, macos_sdk

type
  Build* = object
    outDir*: string
    triple*: string
    bin*: string
    params*: Params

# TODO: better name
proc genFlags*(target: string, args: openArray[string] = @[]): seq[string] =
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

  if triplet.inferOs == "FreeBSD" and detectOs(MacOSX):
    # Required for macos_sdk to properly target the FreeBSD cpu types supported by forge;
    # Remove this, trigger an error about the compiler being unknown
    if triplet.inferCPU == "amd64":
      result.add "-d:TARGET_CPU_X86_64"
    else:
      result.add "-d:TARGET_CPU_X86"

    # The linker and compiler fail without this flag passed;
    # See here for workaround and why it happens: https://github.com/tpoechtrager/osxcross/blob/master/KNOWN_BUGS.md
    result.add "--passC=-c"
    result.add "--passL=-c"

proc formatDirName*(
    formatstr: string,
    name: string,
    version: string,
    target: string
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

proc newBuild*(c: Config, target: string, bin: string): Build =
  let params = c.params(target, bin)
  result.bin = bin
  result.triple = target
  result.params = params
  result.outDir = c.outDir / formatDirName(params.format, c.name, c.version, target)

proc args*(b: Build, backend: string, noMacosSdk: bool, rest: openArray[string]): seq[string] =

  result.add backend
  result.add genFlags(b.triple, rest)
  result.add "-d:release"
  result.add rest
  result.add "--outdir:" & b.outDir

  if (parseTriple(b.triple).inferOs == "MacOSX" and not defined(macosx)) or (detectOs(MacOSX) and parseTriple(b.triple).inferOs == "FreeBSD"):
    if not noMacosSdk:
      result.add sdkFlags()

  if b.params.args.len > 0:
    result.add b.params.args

  result.add b.bin.normalizedPath()

iterator builds*(c: Config): Build =
  for t in c.targets.triples:
    for b in c.bins.paths:
      yield newBuild(c, t, b)

