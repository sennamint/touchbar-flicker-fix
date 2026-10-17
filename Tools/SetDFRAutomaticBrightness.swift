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
let displaySelector = NSSelectorFromString(
    "setProperty:withKey:andDisplay:"
)
let globalSelector = NSSelectorFromString("setProperty:forKey:")

typealias SetForDisplay = @convention(c) (
    AnyObject,
    Selector,
    NSNumber,
    NSString,
    UInt64
) -> Bool

typealias SetGlobal = @convention(c) (
    AnyObject,
    Selector,
    NSNumber,
    NSString
) -> Bool

let setForDisplay = unsafeBitCast(
    client.method(for: displaySelector),
    to: SetForDisplay.self
)
let setGlobal = unsafeBitCast(
    client.method(for: globalSelector),
    to: SetGlobal.self
)

for key in
[
    "AutoBrightnessEnabled",
    "DisplayAutoBrightnessEnabled",
    "DFRAutoBrightnessEnabled"
]
{
    let accepted = setForDisplay(
        client,
        displaySelector,
        NSNumber(value: true),
        key as NSString,
        displayID
    )
    let globallyAccepted = setGlobal(
        client,
        globalSelector,
        NSNumber(value: true),
        key as NSString
    )
    print(
        "\(key): display \(accepted ? "accepted" : "rejected"), "
            .appending("global \(globallyAccepted ? "accepted" : "rejected")")
    )
}
