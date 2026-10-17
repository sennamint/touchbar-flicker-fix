import Foundation

private let frameworkPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
private let displayID: UInt64 = 3

guard CommandLine.arguments.count == 4,
      let duration = Double(CommandLine.arguments[1]),
      (0.0...60.0).contains(duration),
      let brightness = Double(CommandLine.arguments[2]),
      (0.0...1.0).contains(brightness),
      let nits = Double(CommandLine.arguments[3]),
      (0.0...357.099).contains(nits) else
{
    FileHandle.standardError.write(
        Data(
            "usage: SetDFRDisplayBrightness "
                .appending("<seconds 0...60> <brightness 0...1> <nits 0...357.099>\n")
                .utf8
        )
    )
    exit(64)
}

private let target: NSDictionary =
[
    "Brightness": brightness,
    "Nits": nits,
    "NitsPhysical": nits
]

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
    NSDictionary,
    NSString,
    UInt64
) -> Bool

let setForDisplay = unsafeBitCast(
    client.method(for: selector),
    to: SetForDisplay.self
)

func apply() -> Bool
{
    setForDisplay(client, selector, target, "DisplayBrightness", displayID)
}

guard apply() else
{
    fatalError("CoreBrightness rejected the DFR brightness dictionary")
}

print("Applied DFR brightness target \(target)")

let deadline = Date().addingTimeInterval(duration)

while Date() < deadline
{
    Thread.sleep(forTimeInterval: 0.1)

    guard apply() else
    {
        fatalError("CoreBrightness stopped accepting the DFR brightness target")
    }
}
