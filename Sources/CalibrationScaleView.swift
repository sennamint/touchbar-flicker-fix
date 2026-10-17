import AppKit

final class CalibrationScaleView: NSView
{
    private let testValue: Float
    private let stableValue: Float?
    private let flickerValue: Float?

    init(
        testValue: Float,
        stableValue: Float?,
        flickerValue: Float?
    )
    {
        self.testValue = testValue
        self.stableValue = stableValue
        self.flickerValue = flickerValue
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 82))
    }

    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize
    {
        NSSize(width: 420, height: 82)
    }

    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        let track = NSRect(
            x: 18,
            y: 27,
            width: bounds.width - 36,
            height: 14
        )
        let cornerRadius = track.height / 2.0

        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(
            roundedRect: track,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        ).fill()

        if let flickerValue
        {
            let flickerRect = NSRect(
                x: track.minX,
                y: track.minY,
                width: track.width * CGFloat(flickerValue),
                height: track.height
            )
            NSColor.systemRed.withAlphaComponent(0.75).setFill()
            NSBezierPath(
                roundedRect: flickerRect,
                xRadius: cornerRadius,
                yRadius: cornerRadius
            ).fill()
        }

        if let stableValue
        {
            let stableX =
                track.minX + track.width * CGFloat(stableValue)
            let stableRect = NSRect(
                x: stableX,
                y: track.minY,
                width: track.maxX - stableX,
                height: track.height
            )
            NSColor.systemGreen.withAlphaComponent(0.75).setFill()
            NSBezierPath(
                roundedRect: stableRect,
                xRadius: cornerRadius,
                yRadius: cornerRadius
            ).fill()
        }

        let markerX = track.minX + track.width * CGFloat(testValue)
        let marker = NSBezierPath()
        marker.move(to: NSPoint(x: markerX, y: track.minY - 6))
        marker.line(to: NSPoint(x: markerX, y: track.maxY + 7))
        marker.lineWidth = 3
        NSColor.systemBlue.setStroke()
        marker.stroke()

        drawLabel("0%", at: NSPoint(x: track.minX, y: 5))
        drawRightAlignedLabel(
            "100%",
            at: NSPoint(x: track.maxX, y: 5)
        )

        let statusText: String

        if let stableValue,
           let flickerValue
        {
            statusText = String(
                format: "Possible threshold: %.0f–%.0f%%",
                flickerValue * 100.0,
                stableValue * 100.0
            )
        }
        else
        {
            statusText = "Searching for the flicker threshold"
        }

        drawCenteredLabel(statusText, y: 56)
    }

    private var labelAttributes: [NSAttributedString.Key: Any]
    {
        [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
    }

    private func drawLabel(_ text: String, at point: NSPoint)
    {
        (text as NSString).draw(at: point, withAttributes: labelAttributes)
    }

    private func drawRightAlignedLabel(
        _ text: String,
        at point: NSPoint
    )
    {
        let size = (text as NSString).size(withAttributes: labelAttributes)
        drawLabel(text, at: NSPoint(x: point.x - size.width, y: point.y))
    }

    private func drawCenteredLabel(_ text: String, y: CGFloat)
    {
        let size = (text as NSString).size(withAttributes: labelAttributes)
        drawLabel(
            text,
            at: NSPoint(x: (bounds.width - size.width) / 2.0, y: y)
        )
    }
}
