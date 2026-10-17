import AppKit

for _ in 0..<20
{
    let eventTypes: [CGEventType] =
    [
        .keyDown,
        .leftMouseDown,
        .rightMouseDown,
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .scrollWheel,
        .otherMouseDown,
        .otherMouseDragged
    ]
    let idle = eventTypes.map
    {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: $0
        )
    }.min() ?? .infinity
    print(String(format: "input idle %.2f", idle))
    Thread.sleep(forTimeInterval: 0.5)
}
