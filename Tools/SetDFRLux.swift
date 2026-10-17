import Foundation

private let frameworkPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
private let displayID: UInt64 = 3

guard (2...3).contains(CommandLine.arguments.count),
      let lux = Float(CommandLine.arguments[1]),
      (0.0...100_000.0).contains(lux),
      let duration = CommandLine.arguments.count == 3
        ? Double(CommandLine.arguments[2])
        : 0.0,
      (0.0...60.0).contains(duration) else
{
    FileHandle.standardError.write(
        Data("usage: SetDFRLux <0...100000> [seconds 0...60]\n".utf8)
    )
    exit(64)
}

guard dlopen(frameworkPath, RTLD_NOW) != nil else
{
    fatalError("CoreBrightness.framework did not load")
}

guard let clientClass =
    NSClassFromString("BrightnessSystemClient") as? NSObject.Type else
{
    fatalError("BrightnessSystemClient is unavailable")
}

let client = clientClass.init()
let selector = NSSelectorFromString("setProperty:withKey:andDisplay:")

typealias SetForDisplay = @convention(c) (
    AnyObject,
    Selector,
    NSNumber,
    NSString,
    UInt64
) -> Bool

let setForDisplay = unsafeBitCast(
    client.method(for: selector),
    to: SetForDisplay.self
)

func apply() -> Bool
{
    setForDisplay(client, selector, NSNumber(value: lux), "Lux", displayID)
}

guard apply() else
{
    fatalError("CoreBrightness rejected the DFR Lux value")
}

print("Set DFR Lux to \(lux)")

if duration > 0.0
{
    let deadline = Date().addingTimeInterval(duration)

    while Date() < deadline
    {
        Thread.sleep(forTimeInterval: 0.1)

        guard apply() else
        {
            fatalError("CoreBrightness stopped accepting the DFR Lux value")
        }
    }
}
