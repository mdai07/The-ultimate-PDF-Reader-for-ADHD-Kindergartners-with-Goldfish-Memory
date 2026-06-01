import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 || arguments.count == 3 else {
    fputs("usage: generate_release_assets.swift [source-image] <output-dir>\n", stderr)
    exit(64)
}

let sourceURL: URL?
let outputURL: URL
if arguments.count == 3 {
    sourceURL = URL(fileURLWithPath: arguments[1])
    outputURL = URL(fileURLWithPath: arguments[2])
} else {
    sourceURL = nil
    outputURL = URL(fileURLWithPath: arguments[1])
}
let optionsURL = outputURL.appendingPathComponent("icon-options", isDirectory: true)
let iconsetURL = outputURL.appendingPathComponent("AIReader.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: optionsURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
for staleOption in [
    "AIReaderIcon-02-slate-paper.png",
    "AIReaderIcon-03-light-paper.png"
] {
    try? FileManager.default.removeItem(at: optionsURL.appendingPathComponent(staleOption))
}

let sourceImage: NSImage?
if let sourceURL {
    guard let image = NSImage(contentsOf: sourceURL) else {
        fputs("could not read source image at \(sourceURL.path)\n", stderr)
        exit(66)
    }
    sourceImage = image
} else {
    sourceImage = nil
}

let canvasSize = NSSize(width: 1024, height: 1024)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func savePNG(_ image: NSImage, to url: URL, size: NSSize? = nil) throws {
    let targetSize = size ?? image.size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(targetSize.width),
        pixelsHigh: Int(targetSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    rep.size = targetSize

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: targetSize).fill()
    image.draw(
        in: NSRect(origin: .zero, size: targetSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

func makeCanvas(_ draw: () -> Void) -> NSImage {
    let image = NSImage(size: canvasSize)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    image.unlockFocus()
    return image
}

func roundedClip(_ rect: NSRect, radius: CGFloat = 224) {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
}

func drawRoundedBackground(
    top: NSColor,
    bottom: NSColor,
    stroke: NSColor = NSColor.white.withAlphaComponent(0.18)
) {
    let rect = NSRect(origin: .zero, size: canvasSize)
    roundedClip(rect)
    NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -35)

    let vignette = NSGradient(colorsAndLocations:
        (NSColor.clear, 0),
        (NSColor.black.withAlphaComponent(0.28), 1)
    )
    vignette?.draw(in: rect.insetBy(dx: -180, dy: -180), relativeCenterPosition: NSPoint(x: -0.18, y: -0.28))

    let border = NSBezierPath(roundedRect: rect.insetBy(dx: 10, dy: 10), xRadius: 210, yRadius: 210)
    stroke.setStroke()
    border.lineWidth = 10
    border.stroke()
}

func drawSparkle(center: NSPoint, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    path.line(to: NSPoint(x: center.x + radius * 0.24, y: center.y + radius * 0.24))
    path.line(to: NSPoint(x: center.x + radius, y: center.y))
    path.line(to: NSPoint(x: center.x + radius * 0.24, y: center.y - radius * 0.24))
    path.line(to: NSPoint(x: center.x, y: center.y - radius))
    path.line(to: NSPoint(x: center.x - radius * 0.24, y: center.y - radius * 0.24))
    path.line(to: NSPoint(x: center.x - radius, y: center.y))
    path.line(to: NSPoint(x: center.x - radius * 0.24, y: center.y + radius * 0.24))
    path.close()
    color.setFill()
    path.fill()
}

func drawPaperGlyph(rect: NSRect, color: NSColor, stroke: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 34, yRadius: 34)
    color.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = 10
    path.stroke()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: rect.maxX - 132, y: rect.maxY))
    fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 132))
    fold.line(to: NSPoint(x: rect.maxX - 132, y: rect.maxY - 132))
    fold.close()
    NSColor.white.withAlphaComponent(0.45).setFill()
    fold.fill()

    stroke.withAlphaComponent(0.55).setStroke()
    for offset in [0, 1, 2] {
        let y = rect.maxY - 250 - CGFloat(offset) * 80
        let line = NSBezierPath()
        line.move(to: NSPoint(x: rect.minX + 110, y: y))
        line.line(to: NSPoint(x: rect.maxX - 115, y: y))
        line.lineWidth = 14
        line.lineCapStyle = .round
        line.stroke()
    }
}

func drawDocumentLines(origin: NSPoint, width: CGFloat, color: NSColor) {
    color.setStroke()
    for index in 0..<5 {
        let y = origin.y + CGFloat(index) * 72
        let line = NSBezierPath()
        line.move(to: NSPoint(x: origin.x, y: y))
        line.line(to: NSPoint(x: origin.x + width * (index == 2 ? 0.72 : 1), y: y))
        line.lineWidth = index == 0 ? 20 : 14
        line.lineCapStyle = .round
        line.stroke()
    }
}

func drawWandGlyph(
    from start: NSPoint,
    to end: NSPoint,
    width: CGFloat,
    body: NSColor,
    glow: NSColor,
    orbColors: [NSColor]
) {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let length = hypot(dx, dy)
    let nx = -dy / length
    let ny = dx / length
    let cap: CGFloat = width * 0.52

    let wand = NSBezierPath()
    wand.move(to: NSPoint(x: start.x + nx * width, y: start.y + ny * width))
    wand.curve(
        to: NSPoint(x: end.x + nx * cap, y: end.y + ny * cap),
        controlPoint1: NSPoint(x: start.x + dx * 0.35 + nx * width * 1.6, y: start.y + dy * 0.35 + ny * width * 1.4),
        controlPoint2: NSPoint(x: start.x + dx * 0.70 + nx * width * 1.0, y: start.y + dy * 0.70 + ny * width * 1.0)
    )
    wand.line(to: NSPoint(x: end.x - nx * cap, y: end.y - ny * cap))
    wand.curve(
        to: NSPoint(x: start.x - nx * width, y: start.y - ny * width),
        controlPoint1: NSPoint(x: start.x + dx * 0.70 - nx * width * 1.0, y: start.y + dy * 0.70 - ny * width * 1.0),
        controlPoint2: NSPoint(x: start.x + dx * 0.35 - nx * width * 1.5, y: start.y + dy * 0.35 - ny * width * 1.5)
    )
    wand.close()

    glow.withAlphaComponent(0.22).setStroke()
    wand.lineWidth = 42
    wand.stroke()
    body.setFill()
    wand.fill()

    let positions: [CGFloat] = [0.30, 0.55, 0.78]
    let radii: [CGFloat] = [78, 66, 58]
    for (index, t) in positions.enumerated() {
        let center = NSPoint(x: start.x + dx * t, y: start.y + dy * t)
        let circle = NSBezierPath(ovalIn: NSRect(
            x: center.x - radii[index],
            y: center.y - radii[index],
            width: radii[index] * 2,
            height: radii[index] * 2
        ))
        NSShadow().apply {
            $0.shadowBlurRadius = 30
            $0.shadowColor = glow.withAlphaComponent(0.42)
            $0.shadowOffset = .zero
        }
        NSGradient(colors: orbColors)?.draw(in: circle, angle: 45)
        NSShadow().set()
        NSColor.white.withAlphaComponent(0.36).setStroke()
        circle.lineWidth = 5
        circle.stroke()
    }
}

func drawEmojiFace(
    center: NSPoint,
    radius: CGFloat,
    faceTop: NSColor,
    faceBottom: NSColor,
    tongue: NSColor,
    tilt: CGFloat = 0
) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: tilt)
    transform.translateX(by: -center.x, yBy: -center.y)
    transform.concat()

    let faceRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let facePath = NSBezierPath(ovalIn: faceRect)
    NSShadow().apply {
        $0.shadowBlurRadius = 28
        $0.shadowColor = NSColor.black.withAlphaComponent(0.22)
        $0.shadowOffset = NSSize(width: 0, height: -12)
    }
    NSGradient(starting: faceTop, ending: faceBottom)?.draw(in: facePath, angle: -45)
    NSShadow().set()

    NSColor.white.withAlphaComponent(0.28).setStroke()
    facePath.lineWidth = 7
    facePath.stroke()

    let leftEye = NSBezierPath(ovalIn: NSRect(x: center.x - radius * 0.45, y: center.y + radius * 0.20, width: radius * 0.36, height: radius * 0.42))
    NSColor.white.setFill()
    leftEye.fill()
    NSColor.black.withAlphaComponent(0.84).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - radius * 0.33, y: center.y + radius * 0.32, width: radius * 0.15, height: radius * 0.15)).fill()

    NSColor.black.withAlphaComponent(0.82).setStroke()
    let rightEye = NSBezierPath()
    rightEye.move(to: NSPoint(x: center.x + radius * 0.12, y: center.y + radius * 0.52))
    rightEye.line(to: NSPoint(x: center.x + radius * 0.42, y: center.y + radius * 0.24))
    rightEye.move(to: NSPoint(x: center.x + radius * 0.41, y: center.y + radius * 0.52))
    rightEye.line(to: NSPoint(x: center.x + radius * 0.13, y: center.y + radius * 0.24))
    rightEye.lineWidth = radius * 0.075
    rightEye.lineCapStyle = .round
    rightEye.stroke()

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: center.x - radius * 0.38, y: center.y - radius * 0.12))
    mouth.curve(
        to: NSPoint(x: center.x + radius * 0.48, y: center.y - radius * 0.04),
        controlPoint1: NSPoint(x: center.x - radius * 0.12, y: center.y - radius * 0.46),
        controlPoint2: NSPoint(x: center.x + radius * 0.26, y: center.y - radius * 0.42)
    )
    mouth.lineWidth = radius * 0.12
    mouth.lineCapStyle = .round
    NSColor.black.withAlphaComponent(0.78).setStroke()
    mouth.stroke()

    let tonguePath = NSBezierPath()
    tonguePath.move(to: NSPoint(x: center.x + radius * 0.08, y: center.y - radius * 0.21))
    tonguePath.curve(
        to: NSPoint(x: center.x + radius * 0.35, y: center.y - radius * 0.64),
        controlPoint1: NSPoint(x: center.x + radius * 0.20, y: center.y - radius * 0.38),
        controlPoint2: NSPoint(x: center.x + radius * 0.44, y: center.y - radius * 0.43)
    )
    tonguePath.curve(
        to: NSPoint(x: center.x + radius * 0.14, y: center.y - radius * 0.42),
        controlPoint1: NSPoint(x: center.x + radius * 0.17, y: center.y - radius * 0.72),
        controlPoint2: NSPoint(x: center.x + radius * 0.05, y: center.y - radius * 0.56)
    )
    tonguePath.close()
    tongue.setFill()
    tonguePath.fill()

    NSColor.white.withAlphaComponent(0.42).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - radius * 0.48, y: center.y + radius * 0.50, width: radius * 0.28, height: radius * 0.12)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawRotatedOval(
    center: NSPoint,
    width: CGFloat,
    height: CGFloat,
    rotation: CGFloat,
    lineWidth: CGFloat,
    color: NSColor
) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -center.x, yBy: -center.y)
    transform.concat()
    color.setStroke()
    let oval = NSBezierPath(ovalIn: NSRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    oval.lineWidth = lineWidth
    oval.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func drawMagnifier(center: NSPoint, radius: CGFloat, handleEnd: NSPoint, color: NSColor, glass: NSColor) {
    let dx = handleEnd.x - center.x
    let dy = handleEnd.y - center.y
    let length = hypot(dx, dy)
    let start = NSPoint(x: center.x + dx / length * radius * 0.74, y: center.y + dy / length * radius * 0.74)
    color.setStroke()
    let handle = NSBezierPath()
    handle.move(to: start)
    handle.line(to: handleEnd)
    handle.lineWidth = radius * 0.22
    handle.lineCapStyle = .round
    handle.stroke()

    let lens = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    glass.setFill()
    lens.fill()
    color.setStroke()
    lens.lineWidth = radius * 0.09
    lens.stroke()
    NSColor.white.withAlphaComponent(0.48).setStroke()
    let glint = NSBezierPath()
    glint.move(to: NSPoint(x: center.x - radius * 0.48, y: center.y + radius * 0.36))
    glint.curve(
        to: NSPoint(x: center.x + radius * 0.12, y: center.y + radius * 0.60),
        controlPoint1: NSPoint(x: center.x - radius * 0.28, y: center.y + radius * 0.56),
        controlPoint2: NSPoint(x: center.x - radius * 0.08, y: center.y + radius * 0.64)
    )
    glint.lineWidth = radius * 0.06
    glint.lineCapStyle = .round
    glint.stroke()
}

func drawStackedSheets(origin: NSPoint, size: NSSize, fill: NSColor, stroke: NSColor) {
    for offset in stride(from: 2, through: 0, by: -1) {
        let dx = CGFloat(offset) * 42
        let dy = CGFloat(offset) * 36
        let rect = NSRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
        let path = NSBezierPath(roundedRect: rect, xRadius: 42, yRadius: 42)
        fill.withAlphaComponent(0.58 + CGFloat(2 - offset) * 0.14).setFill()
        path.fill()
        stroke.withAlphaComponent(0.30).setStroke()
        path.lineWidth = 7
        path.stroke()
    }
}

func drawPixelBlock(x: Int, y: Int, size: CGFloat, color: NSColor) {
    color.setFill()
    NSRect(x: CGFloat(x) * size, y: CGFloat(y) * size, width: size, height: size).fill()
}

func drawPixelFace(origin: NSPoint, block: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: origin.x, yBy: origin.y)
    transform.concat()
    for row in 0..<13 {
        for column in 0..<13 {
            let dx = column - 6
            let dy = row - 6
            if dx * dx + dy * dy < 39 {
                drawPixelBlock(x: column, y: row, size: block, color: row > 7 ? color(255, 232, 76) : color(247, 169, 50))
            }
        }
    }
    for point in [(3, 8), (4, 8), (3, 7), (9, 9), (8, 8), (10, 8), (8, 10), (10, 10)] {
        drawPixelBlock(x: point.0, y: point.1, size: block, color: color(16, 18, 20))
    }
    for point in [(5, 4), (6, 3), (7, 3), (8, 4), (9, 5)] {
        drawPixelBlock(x: point.0, y: point.1, size: block, color: color(16, 18, 20))
    }
    for point in [(7, 2), (8, 1)] {
        drawPixelBlock(x: point.0, y: point.1, size: block, color: color(239, 74, 139))
    }
    NSGraphicsContext.restoreGraphicsState()
}

func drawInsetStroke(_ path: NSBezierPath, width: CGFloat = 18) {
    NSColor.white.withAlphaComponent(0.46).setStroke()
    path.lineWidth = width
    path.stroke()
    NSColor.black.withAlphaComponent(0.36).setStroke()
    path.lineWidth = width * 0.52
    path.stroke()
}

func drawMetalFaceIcon() {
    let rect = NSRect(origin: .zero, size: canvasSize)
    roundedClip(rect)
    NSGradient(
        colorsAndLocations:
            (color(226, 227, 222), 0),
            (color(162, 164, 160), 0.55),
            (color(103, 106, 104), 1)
    )?.draw(in: rect, angle: -35)

    color(255, 255, 255, 0.055).setStroke()
    for index in stride(from: 70, through: 960, by: 18) {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 58, y: CGFloat(index)))
        line.line(to: NSPoint(x: 966, y: CGFloat(index) + 8))
        line.lineWidth = 1
        line.stroke()
    }

    let outer = NSBezierPath(roundedRect: rect.insetBy(dx: 42, dy: 42), xRadius: 130, yRadius: 130)
    NSColor.black.withAlphaComponent(0.38).setStroke()
    outer.lineWidth = 24
    outer.stroke()
    NSColor.white.withAlphaComponent(0.64).setStroke()
    outer.lineWidth = 10
    outer.stroke()

    let inner = NSBezierPath(roundedRect: rect.insetBy(dx: 70, dy: 70), xRadius: 108, yRadius: 108)
    NSColor.white.withAlphaComponent(0.38).setStroke()
    inner.lineWidth = 8
    inner.stroke()

    let face = NSBezierPath(ovalIn: NSRect(x: 220, y: 185, width: 610, height: 650))
    drawInsetStroke(face, width: 22)

    let leftEyeOuter = NSBezierPath(ovalIn: NSRect(x: 315, y: 505, width: 176, height: 194))
    let rightEyeOuter = NSBezierPath(ovalIn: NSRect(x: 550, y: 540, width: 188, height: 194))
    drawInsetStroke(leftEyeOuter, width: 18)
    drawInsetStroke(rightEyeOuter, width: 18)

    color(52, 54, 54, 0.82).setFill()
    NSBezierPath(ovalIn: NSRect(x: 412, y: 545, width: 70, height: 74)).fill()
    NSBezierPath(ovalIn: NSRect(x: 604, y: 594, width: 78, height: 82)).fill()
    color(245, 246, 242, 0.58).setFill()
    NSBezierPath(ovalIn: NSRect(x: 342, y: 625, width: 52, height: 58)).fill()
    NSBezierPath(ovalIn: NSRect(x: 575, y: 655, width: 50, height: 58)).fill()

    let mouthFill = NSBezierPath()
    mouthFill.move(to: NSPoint(x: 280, y: 410))
    mouthFill.curve(
        to: NSPoint(x: 770, y: 455),
        controlPoint1: NSPoint(x: 435, y: 240),
        controlPoint2: NSPoint(x: 610, y: 260)
    )
    mouthFill.curve(
        to: NSPoint(x: 742, y: 400),
        controlPoint1: NSPoint(x: 820, y: 500),
        controlPoint2: NSPoint(x: 818, y: 420)
    )
    mouthFill.curve(
        to: NSPoint(x: 280, y: 410),
        controlPoint1: NSPoint(x: 600, y: 182),
        controlPoint2: NSPoint(x: 390, y: 250)
    )
    mouthFill.close()
    color(61, 63, 63, 0.72).setFill()
    mouthFill.fill()

    let mouthStroke = NSBezierPath()
    mouthStroke.move(to: NSPoint(x: 282, y: 414))
    mouthStroke.curve(
        to: NSPoint(x: 770, y: 455),
        controlPoint1: NSPoint(x: 430, y: 250),
        controlPoint2: NSPoint(x: 620, y: 258)
    )
    mouthStroke.lineCapStyle = .round
    drawInsetStroke(mouthStroke, width: 24)

    let tongue = NSBezierPath()
    tongue.move(to: NSPoint(x: 548, y: 308))
    tongue.curve(
        to: NSPoint(x: 670, y: 170),
        controlPoint1: NSPoint(x: 645, y: 330),
        controlPoint2: NSPoint(x: 735, y: 248)
    )
    tongue.curve(
        to: NSPoint(x: 548, y: 308),
        controlPoint1: NSPoint(x: 560, y: 130),
        controlPoint2: NSPoint(x: 505, y: 215)
    )
    tongue.close()
    NSGradient(starting: color(190, 191, 186), ending: color(117, 120, 119))?.draw(in: tongue, angle: -30)
    drawInsetStroke(tongue, width: 15)

    let centerTongue = NSBezierPath()
    centerTongue.move(to: NSPoint(x: 604, y: 285))
    centerTongue.curve(to: NSPoint(x: 621, y: 185), controlPoint1: NSPoint(x: 645, y: 250), controlPoint2: NSPoint(x: 652, y: 210))
    NSColor.black.withAlphaComponent(0.26).setStroke()
    centerTongue.lineWidth = 11
    centerTongue.lineCapStyle = .round
    centerTongue.stroke()
    NSColor.white.withAlphaComponent(0.38).setStroke()
    centerTongue.lineWidth = 5
    centerTongue.stroke()

    NSColor.white.withAlphaComponent(0.28).setFill()
    NSBezierPath(ovalIn: NSRect(x: 92, y: 860, width: 790, height: 44)).fill()
    NSColor.black.withAlphaComponent(0.22).setFill()
    NSBezierPath(ovalIn: NSRect(x: 150, y: 76, width: 720, height: 58)).fill()
}

extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) {
        configure(self)
        set()
    }
}

let option1 = makeCanvas {
    if let sourceImage {
        let rect = NSRect(origin: .zero, size: canvasSize)
        roundedClip(rect)
        sourceImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.black.withAlphaComponent(0.12).setFill()
        rect.fill(using: .sourceAtop)
        NSColor.white.withAlphaComponent(0.12).setStroke()
        NSBezierPath(roundedRect: rect.insetBy(dx: 10, dy: 10), xRadius: 210, yRadius: 210).stroke()
        drawSparkle(center: NSPoint(x: 875, y: 170), radius: 54, color: NSColor.white.withAlphaComponent(0.72))
    } else {
        drawRoundedBackground(top: color(80, 98, 108), bottom: color(17, 23, 28))
        drawDocumentLines(origin: NSPoint(x: 172, y: 264), width: 420, color: color(178, 205, 213, 0.34))
        drawWandGlyph(
            from: NSPoint(x: 285, y: 195),
            to: NSPoint(x: 810, y: 842),
            width: 34,
            body: color(24, 28, 29),
            glow: color(173, 220, 244),
            orbColors: [color(246, 250, 252), color(120, 133, 137), color(37, 43, 46)]
        )
        drawSparkle(center: NSPoint(x: 798, y: 812), radius: 90, color: color(225, 247, 255, 0.62))
        drawSparkle(center: NSPoint(x: 270, y: 650), radius: 34, color: color(246, 213, 120, 0.8))
    }
}

let option2 = makeCanvas {
    drawRoundedBackground(top: color(80, 98, 108), bottom: color(17, 23, 28))
    drawDocumentLines(origin: NSPoint(x: 172, y: 264), width: 420, color: color(178, 205, 213, 0.34))
    drawWandGlyph(
        from: NSPoint(x: 285, y: 195),
        to: NSPoint(x: 810, y: 842),
        width: 34,
        body: color(24, 28, 29),
        glow: color(173, 220, 244),
        orbColors: [color(246, 250, 252), color(120, 133, 137), color(37, 43, 46)]
    )
    drawSparkle(center: NSPoint(x: 798, y: 812), radius: 90, color: color(225, 247, 255, 0.62))
    drawSparkle(center: NSPoint(x: 270, y: 650), radius: 34, color: color(246, 213, 120, 0.8))
}

let option3 = makeCanvas {
    drawRoundedBackground(top: color(241, 246, 246), bottom: color(158, 173, 177), stroke: color(255, 255, 255, 0.6))
    drawDocumentLines(origin: NSPoint(x: 214, y: 300), width: 390, color: color(48, 62, 68, 0.32))
    drawWandGlyph(
        from: NSPoint(x: 260, y: 190),
        to: NSPoint(x: 810, y: 830),
        width: 32,
        body: color(32, 38, 40),
        glow: color(61, 105, 116),
        orbColors: [color(255, 255, 255), color(174, 190, 194), color(84, 96, 100)]
    )
    drawSparkle(center: NSPoint(x: 805, y: 820), radius: 76, color: color(255, 255, 255, 0.8))
    drawSparkle(center: NSPoint(x: 820, y: 235), radius: 42, color: color(45, 54, 58, 0.55))
}

let emojiOption1 = makeCanvas {
    drawRoundedBackground(top: color(52, 64, 71), bottom: color(18, 23, 27), stroke: color(255, 255, 255, 0.18))
    drawDocumentLines(origin: NSPoint(x: 170, y: 250), width: 380, color: color(181, 218, 230, 0.24))
    drawEmojiFace(
        center: NSPoint(x: 505, y: 505),
        radius: 285,
        faceTop: color(255, 222, 79),
        faceBottom: color(248, 158, 47),
        tongue: color(245, 91, 139),
        tilt: -8
    )
    drawWandGlyph(
        from: NSPoint(x: 300, y: 170),
        to: NSPoint(x: 790, y: 840),
        width: 22,
        body: color(24, 28, 29),
        glow: color(232, 245, 255),
        orbColors: [color(255, 255, 255), color(170, 184, 187), color(53, 61, 64)]
    )
    drawSparkle(center: NSPoint(x: 800, y: 830), radius: 64, color: color(235, 249, 255, 0.84))
}

let emojiOption2 = makeCanvas {
    drawRoundedBackground(top: color(246, 222, 97), bottom: color(33, 42, 48), stroke: color(255, 255, 255, 0.26))
    drawEmojiFace(
        center: NSPoint(x: 505, y: 535),
        radius: 320,
        faceTop: color(255, 236, 94),
        faceBottom: color(255, 174, 56),
        tongue: color(242, 77, 127),
        tilt: 5
    )
    drawSparkle(center: NSPoint(x: 776, y: 770), radius: 72, color: color(255, 255, 255, 0.76))
    drawSparkle(center: NSPoint(x: 232, y: 240), radius: 42, color: color(255, 255, 255, 0.46))
}

let emojiOption3 = makeCanvas {
    drawRoundedBackground(top: color(196, 229, 236), bottom: color(43, 56, 62), stroke: color(255, 255, 255, 0.32))
    drawDocumentLines(origin: NSPoint(x: 170, y: 225), width: 500, color: color(255, 255, 255, 0.26))
    drawEmojiFace(
        center: NSPoint(x: 470, y: 565),
        radius: 265,
        faceTop: color(255, 231, 93),
        faceBottom: color(251, 166, 52),
        tongue: color(239, 83, 138),
        tilt: -14
    )
    drawWandGlyph(
        from: NSPoint(x: 420, y: 155),
        to: NSPoint(x: 808, y: 765),
        width: 18,
        body: color(25, 31, 34),
        glow: color(255, 255, 255),
        orbColors: [color(255, 255, 255), color(162, 180, 184), color(55, 67, 71)]
    )
}

let altOption1 = makeCanvas {
    drawRoundedBackground(top: color(238, 247, 249), bottom: color(123, 177, 189), stroke: color(255, 255, 255, 0.64))
    drawStackedSheets(origin: NSPoint(x: 190, y: 165), size: NSSize(width: 440, height: 620), fill: color(255, 255, 255), stroke: color(46, 83, 92))
    drawDocumentLines(origin: NSPoint(x: 280, y: 340), width: 330, color: color(49, 87, 95, 0.42))
    drawMagnifier(
        center: NSPoint(x: 600, y: 470),
        radius: 170,
        handleEnd: NSPoint(x: 825, y: 210),
        color: color(22, 45, 52),
        glass: color(198, 244, 255, 0.46)
    )
    drawSparkle(center: NSPoint(x: 770, y: 760), radius: 58, color: color(255, 255, 255, 0.84))
}

let altOption2 = makeCanvas {
    drawRoundedBackground(top: color(42, 18, 78), bottom: color(6, 8, 22), stroke: color(255, 255, 255, 0.18))
    drawRotatedOval(center: NSPoint(x: 512, y: 512), width: 720, height: 250, rotation: 18, lineWidth: 13, color: color(72, 231, 230, 0.72))
    drawRotatedOval(center: NSPoint(x: 512, y: 512), width: 640, height: 230, rotation: -38, lineWidth: 11, color: color(248, 77, 168, 0.68))
    drawRotatedOval(center: NSPoint(x: 512, y: 512), width: 530, height: 178, rotation: 76, lineWidth: 9, color: color(208, 255, 97, 0.58))
    drawPaperGlyph(rect: NSRect(x: 385, y: 330, width: 250, height: 330), color: color(255, 255, 255, 0.92), stroke: color(97, 246, 241, 0.88))
    drawSparkle(center: NSPoint(x: 736, y: 704), radius: 68, color: color(255, 255, 255, 0.86))
}

let altOption3 = makeCanvas {
    drawRoundedBackground(top: color(252, 248, 232), bottom: color(207, 218, 210), stroke: color(42, 52, 48, 0.18))
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: 255, y: 245))
    mark.curve(to: NSPoint(x: 770, y: 785), controlPoint1: NSPoint(x: 360, y: 640), controlPoint2: NSPoint(x: 580, y: 230))
    mark.lineWidth = 78
    mark.lineCapStyle = .round
    color(23, 29, 29).setStroke()
    mark.stroke()
    color(238, 67, 79).setFill()
    NSBezierPath(roundedRect: NSRect(x: 612, y: 570, width: 106, height: 260), xRadius: 40, yRadius: 40).fill()
    drawDocumentLines(origin: NSPoint(x: 235, y: 250), width: 340, color: color(34, 42, 39, 0.18))
    drawSparkle(center: NSPoint(x: 230, y: 760), radius: 44, color: color(23, 29, 29, 0.62))
}

let altOption4 = makeCanvas {
    drawRoundedBackground(top: color(33, 216, 219), bottom: color(54, 54, 189), stroke: color(255, 255, 255, 0.28))
    drawPixelFace(origin: NSPoint(x: 210, y: 210), block: 46)
    color(255, 255, 255, 0.22).setFill()
    for point in [(3, 15), (5, 15), (15, 5), (16, 5), (16, 13), (17, 13)] {
        NSRect(x: CGFloat(point.0) * 46, y: CGFloat(point.1) * 46, width: 46, height: 46).fill()
    }
}

let altOption5 = makeCanvas {
    drawRoundedBackground(top: color(255, 104, 117), bottom: color(77, 67, 198), stroke: color(255, 255, 255, 0.36))
    let bubble = NSBezierPath(roundedRect: NSRect(x: 164, y: 235, width: 620, height: 520), xRadius: 150, yRadius: 150)
    NSColor.white.setFill()
    bubble.fill()
    color(24, 26, 34, 0.84).setStroke()
    bubble.lineWidth = 16
    bubble.stroke()
    color(24, 26, 34).setStroke()
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 318, y: 460))
    smile.curve(to: NSPoint(x: 618, y: 452), controlPoint1: NSPoint(x: 395, y: 320), controlPoint2: NSPoint(x: 555, y: 315))
    smile.lineWidth = 38
    smile.lineCapStyle = .round
    smile.stroke()
    NSBezierPath(ovalIn: NSRect(x: 290, y: 555, width: 108, height: 108)).fill()
    let xEye = NSBezierPath()
    xEye.move(to: NSPoint(x: 555, y: 650))
    xEye.line(to: NSPoint(x: 650, y: 555))
    xEye.move(to: NSPoint(x: 650, y: 650))
    xEye.line(to: NSPoint(x: 555, y: 555))
    xEye.lineWidth = 28
    xEye.lineCapStyle = .round
    xEye.stroke()
    color(239, 72, 148).setFill()
    NSBezierPath(roundedRect: NSRect(x: 538, y: 330, width: 82, height: 150), xRadius: 40, yRadius: 40).fill()
    drawSparkle(center: NSPoint(x: 805, y: 760), radius: 64, color: color(255, 255, 255, 0.76))
}

let altOption6 = makeCanvas {
    drawRoundedBackground(top: color(123, 222, 194), bottom: color(250, 169, 91), stroke: color(255, 255, 255, 0.38))
    let base = NSBezierPath(roundedRect: NSRect(x: 170, y: 200, width: 680, height: 620), xRadius: 170, yRadius: 170)
    NSGradient(starting: color(255, 252, 235), ending: color(240, 179, 118))?.draw(in: base, angle: -45)
    color(93, 62, 68, 0.26).setStroke()
    base.lineWidth = 12
    base.stroke()
    drawMagnifier(center: NSPoint(x: 420, y: 560), radius: 130, handleEnd: NSPoint(x: 660, y: 305), color: color(66, 51, 64), glass: color(255, 255, 255, 0.38))
    drawDocumentLines(origin: NSPoint(x: 500, y: 520), width: 230, color: color(74, 54, 63, 0.38))
    drawSparkle(center: NSPoint(x: 744, y: 718), radius: 54, color: color(255, 255, 255, 0.82))
}

let altOption7 = makeCanvas {
    drawMetalFaceIcon()
}

let options: [(String, NSImage)] = [
    ("AIReaderIcon-01-source-refined.png", option1),
    ("AIReaderIcon-02-slate-wand.png", option2),
    ("AIReaderIcon-03-light-wand.png", option3),
    ("AIReaderEmoji-01-wand-face.png", emojiOption1),
    ("AIReaderEmoji-02-close-face.png", emojiOption2),
    ("AIReaderEmoji-03-paper-face.png", emojiOption3),
    ("AIReaderAlt-01-liquid-lens.png", altOption1),
    ("AIReaderAlt-02-neon-orbit.png", altOption2),
    ("AIReaderAlt-03-minimal-mark.png", altOption3),
    ("AIReaderAlt-04-retro-pixel.png", altOption4),
    ("AIReaderAlt-05-comic-sticker.png", altOption5),
    ("AIReaderAlt-06-clay-badge.png", altOption6),
    ("AIReaderAlt-07-metal-face.png", altOption7)
]

for (name, image) in options {
    try savePNG(image, to: optionsURL.appendingPathComponent(name))
}

let preview = NSImage(size: NSSize(width: 1640, height: 620))
preview.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
color(22, 27, 31).setFill()
NSRect(origin: .zero, size: preview.size).fill()
for (index, option) in [option1, option2, option3].enumerated() {
    let x = 70 + CGFloat(index) * 525
    option.draw(in: NSRect(x: x, y: 100, width: 440, height: 440))
}
preview.unlockFocus()
try savePNG(preview, to: optionsURL.appendingPathComponent("AIReaderIcon-options-preview.png"))

let emojiPreview = NSImage(size: NSSize(width: 1640, height: 620))
emojiPreview.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
color(22, 27, 31).setFill()
NSRect(origin: .zero, size: emojiPreview.size).fill()
for (index, option) in [emojiOption1, emojiOption2, emojiOption3].enumerated() {
    let x = 70 + CGFloat(index) * 525
    option.draw(in: NSRect(x: x, y: 100, width: 440, height: 440))
}
emojiPreview.unlockFocus()
try savePNG(emojiPreview, to: optionsURL.appendingPathComponent("AIReaderEmoji-options-preview.png"))

let altPreview = NSImage(size: NSSize(width: 1640, height: 1610))
altPreview.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
color(22, 27, 31).setFill()
NSRect(origin: .zero, size: altPreview.size).fill()
let altImages = [altOption1, altOption2, altOption3, altOption4, altOption5, altOption6, altOption7]
for (index, option) in altImages.enumerated() {
    let column = index % 3
    let row = index / 3
    let x = 70 + CGFloat(column) * 525
    let y = CGFloat(1070 - row * 490)
    option.draw(in: NSRect(x: x, y: y, width: 440, height: 440))
}
altPreview.unlockFocus()
try savePNG(altPreview, to: optionsURL.appendingPathComponent("AIReaderAlt-options-preview.png"))

let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconSizes {
    try savePNG(option1, to: iconsetURL.appendingPathComponent(name), size: NSSize(width: size, height: size))
}

let emojiIconsets: [(String, NSImage)] = [
    ("AIReaderEmoji-01.iconset", emojiOption1),
    ("AIReaderEmoji-02.iconset", emojiOption2),
    ("AIReaderEmoji-03.iconset", emojiOption3)
]

for (directoryName, image) in emojiIconsets {
    let directory = outputURL.appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (name, size) in iconSizes {
        try savePNG(image, to: directory.appendingPathComponent(name), size: NSSize(width: size, height: size))
    }
}

let altIconsets: [(String, NSImage)] = [
    ("AIReaderAlt-01.iconset", altOption1),
    ("AIReaderAlt-02.iconset", altOption2),
    ("AIReaderAlt-03.iconset", altOption3),
    ("AIReaderAlt-04.iconset", altOption4),
    ("AIReaderAlt-05.iconset", altOption5),
    ("AIReaderAlt-06.iconset", altOption6),
    ("AIReaderAlt-07.iconset", altOption7)
]

for (directoryName, image) in altIconsets {
    let directory = outputURL.appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (name, size) in iconSizes {
        try savePNG(image, to: directory.appendingPathComponent(name), size: NSSize(width: size, height: size))
    }
}
