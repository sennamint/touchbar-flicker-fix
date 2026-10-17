import AppKit

private struct IconOutput
{
    let filename: String
    let pixels: Int
}

private let outputs =
[
    IconOutput(filename: "icon_16x16.png", pixels: 16),
    IconOutput(filename: "icon_16x16@2x.png", pixels: 32),
    IconOutput(filename: "icon_32x32.png", pixels: 32),
    IconOutput(filename: "icon_32x32@2x.png", pixels: 64),
    IconOutput(filename: "icon_128x128.png", pixels: 128),
    IconOutput(filename: "icon_128x128@2x.png", pixels: 256),
    IconOutput(filename: "icon_256x256.png", pixels: 256),
    IconOutput(filename: "icon_256x256@2x.png", pixels: 512),
    IconOutput(filename: "icon_512x512.png", pixels: 512),
    IconOutput(filename: "icon_512x512@2x.png", pixels: 1024)
]

private let outputDirectory = URL(
    fileURLWithPath:
        CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon.iconset",
    isDirectory: true
)

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

private func color(
    red: CGFloat,
    green: CGFloat,
    blue: CGFloat,
    alpha: CGFloat = 1.0
) -> CGColor
{
    CGColor(
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        components: [red, green, blue, alpha]
    )!
}

private func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath
{
    CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
}

private func drawIcon(size: Int) throws -> Data
{
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else
    {
        fatalError("Could not create the icon bitmap")
    }

    let scale = CGFloat(size)
    let canvas = CGRect(x: 0, y: 0, width: scale, height: scale)
    context.clear(canvas)

    let iconRect = canvas.insetBy(dx: scale * 0.065, dy: scale * 0.065)
    let iconPath = roundedPath(iconRect, radius: scale * 0.205)

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -scale * 0.018),
        blur: scale * 0.045,
        color: color(red: 0, green: 0, blue: 0, alpha: 0.34)
    )
    context.addPath(iconPath)
    context.setFillColor(color(red: 0.08, green: 0.09, blue: 0.11))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(iconPath)
    context.clip()

    let backgroundColors =
    [
        color(red: 0.31, green: 0.33, blue: 0.37),
        color(red: 0.13, green: 0.14, blue: 0.17),
        color(red: 0.055, green: 0.063, blue: 0.078)
    ] as CFArray
    let backgroundLocations: [CGFloat] = [0.0, 0.55, 1.0]
    let backgroundGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: backgroundColors,
        locations: backgroundLocations
    )!
    context.drawLinearGradient(
        backgroundGradient,
        start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
        end: CGPoint(x: iconRect.maxX, y: iconRect.minY),
        options: []
    )

    let highlightColors =
    [
        color(red: 1, green: 1, blue: 1, alpha: 0.27),
        color(red: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray
    let highlightGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: highlightColors,
        locations: [0.0, 1.0]
    )!
    context.drawRadialGradient(
        highlightGradient,
        startCenter: CGPoint(
            x: iconRect.minX + iconRect.width * 0.36,
            y: iconRect.maxY - iconRect.height * 0.08
        ),
        startRadius: 0,
        endCenter: CGPoint(
            x: iconRect.minX + iconRect.width * 0.36,
            y: iconRect.maxY - iconRect.height * 0.08
        ),
        endRadius: scale * 0.52,
        options: []
    )
    context.restoreGState()

    context.addPath(iconPath)
    context.setStrokeColor(
        color(red: 1, green: 1, blue: 1, alpha: 0.20)
    )
    context.setLineWidth(scale * 0.006)
    context.strokePath()

    let barRect = CGRect(
        x: scale * 0.18,
        y: scale * 0.39,
        width: scale * 0.64,
        height: scale * 0.22
    )
    let cyan = color(red: 0.47, green: 0.96, blue: 1.0)
    let barPath = roundedPath(barRect, radius: scale * 0.065)

    context.saveGState()
    context.setShadow(
        offset: .zero,
        blur: scale * 0.055,
        color: color(red: 0.35, green: 0.92, blue: 1.0, alpha: 0.58)
    )
    context.addPath(barPath)
    context.setStrokeColor(cyan)
    context.setLineWidth(max(1.0, scale * 0.025))
    context.strokePath()
    context.restoreGState()

    context.addPath(barPath)
    context.setStrokeColor(cyan)
    context.setLineWidth(max(1.0, scale * 0.025))
    context.strokePath()

    let segmentSize = CGSize(width: scale * 0.095, height: scale * 0.095)
    let segmentGap = scale * 0.045
    let totalWidth = segmentSize.width * 3.0 + segmentGap * 2.0
    let firstX = scale * 0.5 - totalWidth * 0.5
    let segmentY = scale * 0.5 - segmentSize.height * 0.5

    for index in 0..<3
    {
        let segmentRect = CGRect(
            x: firstX + CGFloat(index) * (segmentSize.width + segmentGap),
            y: segmentY,
            width: segmentSize.width,
            height: segmentSize.height
        )
        context.addPath(
            roundedPath(segmentRect, radius: scale * 0.025)
        )
        context.setFillColor(cyan)
        context.fillPath()
    }

    guard let data = bitmap.representation(
        using: .png,
        properties: [:]
    ) else
    {
        fatalError("Could not encode the icon bitmap")
    }

    return data
}

for output in outputs
{
    let data = try drawIcon(size: output.pixels)
    try data.write(to: outputDirectory.appendingPathComponent(output.filename))
}

print("Generated \(outputs.count) icon images in \(outputDirectory.path)")
