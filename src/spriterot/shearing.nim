import pixie
import common
import options

proc shearing*(image: Image, fromAngle: int, step: float, rotations: int, columns: int, rows: int, bounds: IVec2, logger: Logger): Image =
  let w = bounds.x
  let h = bounds.y
  let hw = w.float64 / 2.0
  let hh = h.float64 / 2.0

  result = newImage(w * columns, h * rows)
  
  let fromRadians = degToRad(fromAngle.float64)
  var currentRotation = 0.0
  for i in countup(0, rotations - 1):
    let column = i mod columns
    let row = (i / columns).int

    let angle = fromRadians + currentRotation
    let xShear = -tan(angle / 2.0)
    let yShear = sin(angle)
    let xShearMatrix = dmat3(1, 0, 0, xShear, 1, 0, 0, 0, 1)
    let shearMat = xShearMatrix * dmat3(1, yShear, 0, 0, 1, 0, 0, 0, 1) * xShearMatrix

    let translation = translate(dvec2(column.float64 * w.float64 + hw, row.float64 * h.float64 + hh))
    let transform = translation * shearMat * translate(dvec2(-image.width.float / 2.0, -image.height.float / 2.0))
    
    logger.echoFrame(i + 1, ivec2(column.int32, row.int32), radToDeg(fromRadians + currentRotation))
    result.draw(image, transform, blendMode = NormalBlend, DrawMethod.nearest, mask = some(IRect(x: column * w, y: row * h, w: w, h: h)))
    
    currentRotation += step