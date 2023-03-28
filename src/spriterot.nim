import pixie
import options
import strformat
import argparse
import strutils
import os
import regex
import spriterot/common
import spriterot/[rotsprite, shearing, nearest, linear]

type Algorithm {.pure.} = enum
  rotsprite = "rotsprite"
  shearing = "shearing"
  nearest = "nearest"
  linear = "linear"

type ValueMode {.pure.} = enum
  none, min, max, clamp, value

type ValueOption = object
  mode: ValueMode
  a: int
  b: int

const algorithms: array[Algorithm, auto] = [
  # rotsprite
  rotsprite.rotsprite,
  # shearing
  shearing.shearing,
  # nearest
  nearest.nearest,
  # linear
  linear.linear
]

var logger: Logger

proc generate(filename: string, rotations: int, fromAngle: int, toAngle: int, keepSize: bool, frameWidth: int32, frameHeight: int32,
    columnsOption, rowsOption: ValueOption, margin: int, algorithm: Algorithm, output: Option[string] = none(string), outdir: Option[string] = none(string)) =
  # Get the source filename without extension.
  var groups: RegexMatch
  let match = filename.match(re"(.+)\..{1,4}$", groups)
  var imagePath: string
  if match:
    imagePath = groups.group(0, filename)[0]
  else:
    raise newException(ShortCircuit, "Source filename is not valid.")
  
  # Calculate whether fromAngle and toAngle are really the same.
  var clampedFrom = 0
  if fromAngle mod 360 < 0:
    clampedFrom = 360 + (fromAngle mod 360)
  else:
    clampedFrom = fromAngle mod 360
  
  var clampedTo = 0
  if toAngle mod 360 < 0:
    clampedTo = 360 + (toAngle mod 360)
  else:
    clampedTo = toAngle mod 360
  # If they are not the same angle, the last frame will be properly rendered.
  let generateLastRotation = clampedFrom != clampedTo

  # Calculate the rotation to apply to each frame. Clockwise if fromAngle < toAngle.
  let step = degToRad((toAngle - fromAngle).float64) / (rotations - (if generateLastRotation: 1 else: 0)).float64

  let image = pixie.readImage(filename)

  # Calculate the new bounds of the rotated images, or some frames could be cropped during rotation.
  var bounds: IVec2
  if keepSize:
    bounds = ivec2(image.width.int32, image.height.int32)
  else:
    bounds = image.opaqueSquareBounds() + ivec2(margin.int32, margin.int32) * 2
  if frameWidth > 0:
    bounds.x = frameWidth
  if frameHeight > 0:
    bounds.y = frameHeight
  
  let rowColumn = nearestFactors(rotations)
  var columns = rowColumn.b
  var rows = rowColumn.a

  # Adjust columns amount based on columnsOption.
  var maxColumns = high(int)
  var minColumns = 0
  case columnsOption.mode:
  of ValueMode.none:
    discard
  of ValueMode.min:
    columns = max(columnsOption.a, columns)
    minColumns = columnsOption.a
    rows = (rotations / columns).ceil().int
  of ValueMode.max:
    columns = min(columnsOption.a, columns)
    maxColumns = columnsOption.a
    rows = (rotations / columns).ceil().int
  of ValueMode.clamp:
    columns = clamp(columns, columnsOption.a, columnsOption.b)
    minColumns = columnsOption.a
    maxColumns = columnsOption.b
    rows = (rotations / columns).ceil().int
  of ValueMode.value:
    columns = columnsOption.a
    maxColumns = columns
    minColumns = columns
    rows = (rotations / columns).ceil().int
  
  # Adjust rows amount based on rowsOption.
  case rowsOption.mode:
  of ValueMode.none:
    discard
  of ValueMode.min:
    rows = max(rowsOption.a, rows)
    columns = clamp((rotations / rows).ceil().int, minColumns, maxColumns)
  of ValueMode.max:
    rows = min(rowsOption.a, rows)
    columns = clamp((rotations / rows).ceil().int, minColumns, maxColumns)
  of ValueMode.clamp:
    rows = clamp(rows, rowsOption.a, rowsOption.b)
    columns = clamp((rotations / rows).ceil().int, minColumns, maxColumns)
  of ValueMode.value:
    rows = rowsOption.a
    columns = clamp((rotations / rows).ceil().int, minColumns, maxColumns)

  logger.echo(fmt"Generating a {bounds.x * columns}x{bounds.y * rows} spritesheet with {rotations} ({bounds.x}x{bounds.y}) rotation(s) in a {columns}x{rows} grid, from {fromAngle} to {toAngle} degrees")

  # Call the chosen algorithm.
  let newImage = algorithms[algorithm](image, fromAngle, step, rotations, columns, rows, bounds, logger)

  var outputPath: string
  if output.isSome():
    outputPath = output.get()
  elif outdir.isSome():
    let outputDir = normalizePathEnd(outdir.get(), trailingSep = true)
    if not dirExists(outputDir):
      createDir(outputDir)
    let imageName = splitPath(imagePath).tail
    outputPath = fmt"{outputDir}{imageName}-table-{bounds.x.int}-{bounds.y.int}.png"
  else:
    outputPath = fmt"{imagePath}-table-{bounds.x.int}-{bounds.y.int}.png"
  
  logger.echo(fmt"Output file: {outputPath}")
  newImage.writeFile(outputPath)

# Entrypoint.
when isMainModule:
  let params = commandLineParams()

  var p = newParser:
    flag("-v", "--verbose", help = "Show details about the image(s) being processed.")
    flag("-k", "--keep-size", help = "Keep the size of the source image for generated rotations, could lead to cropped frames.")
    option("--columns", help = "Configure the number of columns the generated spritesheet should have. Could lead to wasted space or a cropped spritesheet. Possible values: [min:<number>, max:<number>, clamp:<min>-<max>, <number>]", default = none(string))
    option("--rows", help = "Configure the number of rows the generated spritesheet should have. Could lead to wasted space or a cropped spritesheet. Possible values: [min:<number>, max:<number>, clamp:<min>-<max>, <number>]", default = none(string))
    option("--width", help = "Manual width of each generated frame. Could lead to wasted space or cropped frames.")
    option("--height", help = "Manual height of each generated frame. Could lead to wasted space or cropped frames.")
    option("-m", "--margin", help = "Margin around frames, in pixels. Inapplicable when --width or --height are manually set or when --keep-size is enabled.", default = some("0"))
    option("-a", "--algorithm", help = "Algorithm used to rotate the image.", choices = @["rotsprite", "shearing", "nearest", "linear"], default = some("rotsprite"))
    option("-r", "--rotations", help = "Amount of rotations to generate.")
    option("-f", "--from", help = "Angle in degrees from which to start generating rotations.", default = some("0"))
    option("-t", "--to", help = "Angle in degrees up to which to generate rotations.", default = some("360"))
    option("-o", "--output", help = "Output filename.")
    option("-d", "--outdir", help = "Output directory.")
    arg("source", help = "Image to generate the rotations of.")
  
  try:
    var opts = p.parse(params)
    logger = Logger(verbose: opts.verbose)
    let filename = opts.source
    let output = if opts.output != "": some(opts.output) else: none(string)
    let outdir = if opts.outdir != "": some(opts.outdir) else: none(string)

    var rotations = 0
    if opts.rotations != "":
      rotations = opts.rotations.parseInt
      logger.echo(fmt"Using command line rotations option")
    else:
      var groups: RegexMatch
      let match = filename.match(re".*-rotations-(\d+)\..{1,4}", groups)
      if match:
        rotations = groups.group(0, filename)[0].parseInt
        logger.echo(fmt"Using filename rotations definition")
      else:
        raise newException(ShortCircuit, "No valid definition on how many rotations to generate found.")
    
    var fromAngle = 0
    var toAngle = 360
    if opts.from != "":
      fromAngle = opts.from.parseInt
    if opts.to != "":
      toAngle = opts.to.parseInt

    # Resolve columns rule.
    var columnsOption: ValueOption
    if opts.columns == "":
      columnsOption = ValueOption(mode: ValueMode.none, a: 0, b: 0)
    else:
      var groups: RegexMatch
      if opts.columns.match(re"min:(\d+)$", groups):
        let value = groups.group(0, opts.columns)[0].parseInt
        columnsOption = ValueOption(mode: ValueMode.min, a: value, b: 0)
      elif opts.columns.match(re"max:(\d+)$", groups):
        let value = groups.group(0, opts.columns)[0].parseInt
        columnsOption = ValueOption(mode: ValueMode.max, a: value, b: 0)
      elif opts.columns.match(re"clamp:(\d+)-(\d+)$", groups):
        let valueA = groups.group(0, opts.columns)[0].parseInt
        let valueB = groups.group(1, opts.columns)[0].parseInt
        columnsOption = ValueOption(mode: ValueMode.clamp, a: valueA, b: valueB)
      elif opts.columns.match(re"(\d+)$", groups):
        let value = groups.group(0, opts.columns)[0].parseInt
        columnsOption = ValueOption(mode: ValueMode.value, a: value, b: 0)
      else:
        raise newException(ShortCircuit, "Invalid columns option.")
    
    # Resolve rows rule.
    var rowsOption: ValueOption
    if opts.rows == "":
      rowsOption = ValueOption(mode: ValueMode.none, a: 0, b: 0)
    else:
      var groups: RegexMatch
      if opts.rows.match(re"min:(\d+)$", groups):
        let value = groups.group(0, opts.rows)[0].parseInt
        rowsOption = ValueOption(mode: ValueMode.min, a: value, b: 0)
      elif opts.rows.match(re"max:(\d+)$", groups):
        let value = groups.group(0, opts.rows)[0].parseInt
        rowsOption = ValueOption(mode: ValueMode.max, a: value, b: 0)
      elif opts.rows.match(re"clamp:(\d+)-(\d+)$", groups):
        let valueA = groups.group(0, opts.rows)[0].parseInt
        let valueB = groups.group(1, opts.rows)[0].parseInt
        rowsOption = ValueOption(mode: ValueMode.clamp, a: valueA, b: valueB)
      elif opts.rows.match(re"(\d+)$", groups):
        let value = groups.group(0, opts.rows)[0].parseInt
        rowsOption = ValueOption(mode: ValueMode.value, a: value, b: 0)
      else:
        raise newException(ShortCircuit, "Invalid rows option.")

    let width = if opts.width != "": opts.width.parseInt.int32 else: 0
    let height = if opts.height != "": opts.height.parseInt.int32 else: 0
    let margin = opts.margin.parseInt
    let algorithm = parseEnum[Algorithm](opts.algorithm)

    generate(filename, rotations, fromAngle, toAngle, opts.keepSize,
      width, height, columnsOption, rowsOption, margin, algorithm, output, outdir)

  except ShortCircuit as err:
    if err.flag == "argparse_help":
      echo err.help
    else:
      stderr.writeLine getCurrentExceptionMsg()
      quit(1)
  except:
    stderr.writeLine getCurrentExceptionMsg()
    quit(1)