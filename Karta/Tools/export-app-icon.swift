import AppKit
import CoreText
import ImageIO

private let canvasSize = 1024
private let designSize: CGFloat = 180
private let scale = CGFloat(canvasSize) / designSize

private func color(_ hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

private func drawCard(
    in context: CGContext,
    rect: CGRect,
    radius: CGFloat,
    fill: CGColor,
    angle: CGFloat,
    center: CGPoint
) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: angle * .pi / 180)
    context.translateBy(x: -center.x, y: -center.y)
    context.addPath(CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    ))
    context.setFillColor(fill)
    context.fillPath()
    context.restoreGState()
}

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: export-app-icon.swift <Fraunces.ttf> <AppIcon.png>")
}

let fontURL = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard
    let provider = CGDataProvider(url: fontURL),
    let graphicsFont = CGFont(provider)
else {
    fatalError("could not load Fraunces")
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("could not create image context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.setFillColor(color(0xF3EBDD))
context.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
context.translateBy(x: 0, y: CGFloat(canvasSize))
context.scaleBy(x: scale, y: -scale)

drawCard(
    in: context,
    rect: CGRect(x: 32, y: 44, width: 68, height: 96),
    radius: 13,
    fill: color(0x7C9A6D),
    angle: -14,
    center: CGPoint(x: 66, y: 92)
)
drawCard(
    in: context,
    rect: CGRect(x: 54, y: 38, width: 68, height: 96),
    radius: 13,
    fill: color(0xE3A33B),
    angle: -2,
    center: CGPoint(x: 88, y: 86)
)

context.saveGState()
context.translateBy(x: 110, y: 90)
context.rotate(by: 12 * .pi / 180)
context.translateBy(x: -110, y: -90)
context.addPath(CGPath(
    roundedRect: CGRect(x: 76, y: 44, width: 68, height: 96),
    cornerWidth: 13,
    cornerHeight: 13,
    transform: nil
))
context.setFillColor(color(0xD5C1A2))
context.fillPath()
context.addPath(CGPath(
    roundedRect: CGRect(x: 76, y: 42, width: 68, height: 96),
    cornerWidth: 13,
    cornerHeight: 13,
    transform: nil
))
context.setFillColor(color(0xFFFAF0))
context.fillPath()

let font = CTFontCreateWithGraphicsFont(graphicsFont, 54, nil, nil)
var character = Array("k".utf16)[0]
var glyph = CGGlyph()
guard CTFontGetGlyphsForCharacters(font, &character, &glyph, 1) else {
    fatalError("could not create k glyph")
}
var advance = CGSize.zero
CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
guard let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) else {
    fatalError("could not outline k glyph")
}

context.translateBy(x: 110 - advance.width / 2, y: 104)
context.scaleBy(x: 1, y: -1)
context.addPath(glyphPath)
context.setFillColor(color(0xA5432D))
context.fillPath()
context.restoreGState()

guard
    let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        "public.png" as CFString,
        1,
        nil
    )
else {
    fatalError("could not create PNG")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("could not write PNG")
}
