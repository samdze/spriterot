import pixie
import pixie/[blends, internal]
import options
import strformat

const h = 0.5.float64

type Logger* = ref object
  verbose*: bool

proc echo*(logger: Logger, str: string) =
  if logger.verbose:
    echo str

proc echoFrame*(logger: Logger, index: int, cell: IVec2, degrees: float) =
  let cellString = fmt"({cell.x}, {cell.y})"
  logger.echo(&"Frame: {index:>4} \tcell: {cellString:>10} \tdegrees: {degrees:>10.3f}")

type
  DLine* = object
    a*: DVec2
    b*: DVec2
  
  DSegment* = object
    at*: DVec2
    to*: DVec2
  
  IRect* = object
    x*: int
    y*: int
    w*: int
    h*: int

type DrawMethod* = enum
  linear, nearest

proc dsegment(at, to: DVec2): DSegment {.inline.} =
  DSegment(at: at, to: to)

proc intersects(l: DLine, s: DSegment, at: var DVec2): bool {.inline.} =
  ## Checks if the line intersects the segment.
  ## If it returns true, at will have point of intersection
  let
    s1 = l.b - l.a
    s2 = s.to - s.at
    denominator = (-s2.x * s1.y + s1.x * s2.y)
    numerator = s1.x * (l.a.y - s.at.y) - s1.y * (l.a.x - s.at.x)
    u = numerator / denominator

  if u >= 0 and u <= 1:
    at = s.at + (u * s2)
    return true

proc blendLine(
  a, b: ptr UncheckedArray[ColorRGBX], len: int, blender: Blender
) {.inline.} =
  for i in 0 ..< len:
    a[i] = blender(a[i], b[i])

proc blendLineOverwrite(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) {.inline.} =
  copyMem(a[0].addr, b[0].addr, len * 4)

proc blendLineNormal(
  a, b: ptr UncheckedArray[ColorRGBX], len: int
) =
  for i in 0 ..< len:
    a[i] = blendNormal(a[i], b[i])

proc blendLineMask(a, b: ptr UncheckedArray[ColorRGBX], len: int) =
  for i in 0 ..< len:
    a[i] = blendMask(a[i], b[i])

proc draw*(a, b: Image, transform: GMat3[float64], blendMode: BlendMode, drawMethod: DrawMethod, mask: Option[IRect] = none(IRect)) =
  var corners = [
    transform * dvec2(0, 0),
    transform * dvec2(b.width.float32, 0),
    transform * dvec2(b.width.float32, b.height.float32),
    transform * dvec2(0, b.height.float32)
  ]
  let perimeter = [
      dsegment(corners[0], corners[1]),
      dsegment(corners[1], corners[2]),
      dsegment(corners[2], corners[3]),
      dsegment(corners[3], corners[0])
    ]
  let inverseTransform = transform.inverse()
  # Compute movement vectors
  let p = inverseTransform * dvec2(0 + h, 0 + h)
  let dx = inverseTransform * dvec2(1 + h, 0 + h) - p
  let dy = inverseTransform * dvec2(0 + h, 1 + h) - p

  # Determine where we should start and stop drawing in the y dimension
  var
    yStart = a.height
    yEnd = 0
  for segment in perimeter:
    yStart = min(yStart, segment.at.y.floor.int)
    yEnd = max(yEnd, segment.at.y.ceil.int)
  yStart = yStart.clamp(0, a.height)
  yEnd = yEnd.clamp(0, a.height)

  if blendMode == MaskBlend and yStart > 0:
    zeroMem(a.data[0].addr, yStart * a.width * 4)

  var sampleLine = newSeq[ColorRGBX](a.width)
  for y in yStart ..< yEnd:
    # Determine where we should start and stop drawing in the x dimension
    var
      xMin = a.width.float32
      xMax = 0.float32
    for yOffset in [0.float32, 1]:
      let scanLine = DLine(
        a: dvec2(-1000, y.float64 + yOffset),
        b: dvec2(1000, y.float64 + yOffset)
      )
      for segment in perimeter:
        var at: DVec2
        if scanline.intersects(segment, at) and segment.to != at:
          xMin = min(xMin, at.x)
          xMax = max(xMax, at.x)

    let
      xStart = clamp(xMin.floor.int, 0, a.width)
      xEnd = clamp(xMax.ceil.int, 0, a.width)

    if xEnd - xStart == 0:
      continue

    var srcPos = p + dx * xStart.float64 + dy * y.float64
    srcPos = dvec2(srcPos.x - h, srcPos.y - h)
    for x in xStart ..< xEnd:
      case drawMethod:
      of linear:
        sampleLine[x] = b.getRgbaSmooth(srcPos.x, srcPos.y)
      of nearest:
        sampleLine[x] = b[floor(srcPos.x).int, floor(srcPos.y).int]
      srcPos += dx

    case blendMode:
    of NormalBlend:
      var maskedXStart = xStart
      var maskedXEnd = xEnd
      if mask.isSome():
        let mask = mask.get()
        maskedXStart = max(maskedXStart, mask.x)
        maskedXEnd = min(maskedXEnd, mask.x + mask.w)

        if y < mask.y or y >= (mask.y + mask.h):
          continue
      
      blendLineNormal(
        a.getUncheckedArray(maskedXStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[maskedXStart].addr),
        maskedXEnd - maskedXStart
      )

    of OverwriteBlend:
      blendLineOverwrite(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart
      )

    of MaskBlend:
      {.linearScanEnd.}
      if blendMode == MaskBlend and xStart > 0:
        zeroMem(a.data[a.dataIndex(0, y)].addr, xStart * 4)

      blendLineMask(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart
      )

      if blendMode == MaskBlend and a.width - xEnd > 0:
        zeroMem(a.data[a.dataIndex(xEnd, y)].addr, (a.width - xEnd) * 4)
    else:
      blendLine(
        a.getUncheckedArray(xStart, y),
        cast[ptr UncheckedArray[ColorRGBX]](sampleLine[xStart].addr),
        xEnd - xStart,
        blendMode.blender()
      )

  if blendMode == MaskBlend and a.height - yEnd > 0:
    zeroMem(
      a.data[a.dataIndex(0, yEnd)].addr,
      a.width * (a.height - yEnd) * 4
    )

proc opaqueSquareBounds*(image: Image): IVec2 =
  ## Calculate the size of the square just large enough to hold all the
  ## non-transparent pixels of all the possible rotations of `ìmage` around its center point.
  let w = image.width
  let hw = w.float64 / 2.0
  let h = image.height
  let hh = h.float64 / 2.0

  var maxSquaredDistance = 0.0

  for y in 0 ..< h:
    for x in 0 ..< w:
      let pixel = image[x, y]

      if pixel.a > 0:
        # Opaque or semi-opaque pixel
        let squaredDistanceFromCenter = ((x.float64 - hw) * (x.float64 - hw) +
          (y.float64 - hh) * (y.float64 - hh))
        if squaredDistanceFromCenter > maxSquaredDistance:
          maxSquaredDistance = squaredDistanceFromCenter
  
  let maxDistanceFromCenter = sqrt(maxSquaredDistance).ceil().int32
  return ivec2(maxDistanceFromCenter * 2, maxDistanceFromCenter * 2)

func nearestFactors*(number: int): tuple[a: int, b: int] =
  ## Calculate the closest two factors of `number`.
  ## 
  ## Returns a tuple containing the two factors of `number` that are closest; in other words, the
  ## closest two integers for which `a` * `b` = `number`.
  ## 
  ## If `number` is a perfect square, the result will be [sqrt(`number`), sqrt(`number`)].
  ## 
  ## If `number` is a prime number, the result will be [1, `number`].
  ## 
  ## The first number will always be the smallest, if they are not equal.
  var
    a = 1
    b = number
    i = 0
  while a < b:
      i += 1
      if number mod i == 0:
          a = i
          b = number div a
  
  return (b, a)