import AppKit

final class StableBrightnessController
{
    private let client: NSObject
    private let displayID = TouchBar.displayID
    private let selector = NSSelectorFromString(
        "setProperty:withKey:andDisplay:"
    )

    init()
    {
        let path =
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/"
                .appending("CoreBrightness")

        guard dlopen(path, RTLD_NOW) != nil else
        {
            fatalError("CoreBrightness.framework did not load")
        }

        guard let clientClass =
            NSClassFromString("BrightnessSystemClient") as? NSObject.Type else
        {
            fatalError("BrightnessSystemClient is unavailable")
        }

        client = clientClass.init()

        guard client.responds(to: selector) else
        {
            fatalError(
                "BrightnessSystemClient does not provide the DFR property setter"
            )
        }
    }

    func apply(_ brightness: Float) -> Bool
    {
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
        let target: NSDictionary =
        [
            "Brightness": brightness,
            "Nits": 0,
            "NitsPhysical": 0
        ]

        return setForDisplay(
            client,
            selector,
            target,
            "DisplayBrightness",
            displayID
        )
    }
}
