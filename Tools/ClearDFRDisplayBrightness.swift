import Foundation

private let frameworkPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
private let displayID: UInt64 = 3

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
    AnyObject,
    NSString,
    UInt64
) -> Bool

let setForDisplay = unsafeBitCast(
    client.method(for: selector),
    to: SetForDisplay.self
)
let accepted = setForDisplay(
    client,
    selector,
    NSNull(),
    "DisplayBrightness",
    displayID
)

print(accepted ? "accepted" : "rejected")
