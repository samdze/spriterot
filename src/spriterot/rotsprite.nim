import pixie
import common
import options

func scale2X(image: Image): Image =
  let w = image.width
  let h = image.height

  let ww = w * 2
  let hh = h * 2

  result = newImage(ww, hh)

  for y in 0 ..< h:
    var sample = image[0, y]
    var left: Option[ColorRGBX]
    var right = some(image[1, y])

    for x in 0 ..< w:
      let top = some(image[x, y - 1])
      let bottom = some(image[x, y + 1])

      var tl = some(sample)
      var tr: Option[ColorRGBX]
      var bl: Option[ColorRGBX]
      var br: Option[ColorRGBX]

      if left == top and left != bottom and top != right:
        tl = top
      
      if top == right and top != left and right != bottom:
        tr = right

      if bottom == left and bottom != right and left != top:
        bl = left

      if right == bottom and right != top and bottom != left:
        br = bottom
      
      result[x * 2, y * 2] = tl.get(sample)
      result[x * 2 + 1, y * 2] = tr.get(sample)
      result[x * 2, y * 2 + 1] = bl.get(sample)
      result[x * 2 + 1, y * 2 + 1] = br.get(sample)

      left = some(sample)
      sample = right.get(sample)
      right = some(image[x + 2, y])

proc rotsprite*(image: Image, fromAngle: int, step: float, rotations: int, columns: int, rows: int, bounds: IVec2, logger: Logger): Image =
  let w = bounds.x
  let h = bounds.y
  let hw = w.float64 / 2.0
  let hh = h.float64 / 2.0

  result = newImage(w * columns, h * rows)

  let scaledImage = image.scale2X().scale2X().scale2X()
  
  let fromRadians = degToRad(fromAngle.float64)
  var currentRotation = 0.0
  let scale = scale(dvec2(1.0 / 8.0, 1.0 / 8.0))
  for i in countup(0, rotations - 1):
    let column = i mod columns
    let row = (i / columns).int

    let translation = translate(dvec2(column.float64 * w.float64 + hw, row.float64 * h.float64 + hh))
    let rotation = rotate(fromRadians - currentRotation)
    let transform = translation * scale * rotation * translate(dvec2(-scaledImage.width.float / 2.0, -scaledImage.height.float / 2.0))
    
    logger.echoFrame(i + 1, ivec2(column.int32, row.int32), radToDeg(fromRadians + currentRotation))
    result.draw(scaledImage, transform, blendMode = NormalBlend, DrawMethod.nearest, mask = some(IRect(x: column * w, y: row * h, w: w, h: h)))
    
    currentRotation += step