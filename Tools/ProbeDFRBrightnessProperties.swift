import Foundation

private let frameworkPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
private let displayID: UInt64 = 3
private let candidateKeys =
[
    "ambient",
    "AutoBrightnessEnabled",
    "Brightness",
    "BrightnessLevel",
    "BrightnessLimit",
    "CurrentBrightness",
    "DFRAutoBrightnessEnabled",
    "DFRBrightness",
    "DFRBrightnessLevel",
    "DFRDisplayBrightness",
    "DisplayAutoBrightnessEnabled",
    "DisplayBrightness",
    "DisplayBrightnessFactor",
    "FilteredAmbient",
    "HighAmbientAdaptation",
    "LinearBrightness",
    "LowAmbientAdaptation",
    "Lux",
    "ManualBrightness",
    "SDRBrightness",
    "UserBrightness",
    "brightness"
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
let displaySelector = NSSelectorFromString("copyPropertyForKey:andDisplay:")
let globalSelector = NSSelectorFromString("copyPropertyForKey:")

typealias CopyForDisplay = @convention(c) (
    AnyObject,
    Selector,
    NSString,
    UInt64
) -> AnyObject?
typealias CopyGlobal = @convention(c) (
    AnyObject,
    Selector,
    NSString
) -> AnyObject?

let copyForDisplay = unsafeBitCast(
    client.method(for: displaySelector),
    to: CopyForDisplay.self
)
let copyGlobal = unsafeBitCast(
    client.method(for: globalSelector),
    to: CopyGlobal.self
)

for key in candidateKeys
{
    let propertyKey = key as NSString
    let displayValue = copyForDisplay(
        client,
        displaySelector,
        propertyKey,
        displayID
    )
    let globalValue = copyGlobal(client, globalSelector, propertyKey)

    if displayValue != nil || globalValue != nil
    {
        print(
            "\(key): display=\(String(describing: displayValue)), "
                .appending("global=\(String(describing: globalValue))")
        )
    }
}
