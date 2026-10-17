import AppKit
// Some MacBook Pro Touch Bars develop a hardware fault that becomes visible at
// low panel brightness. DFRBrightness controls power, while CoreBrightness can
// hold the panel above the machine-specific flicker threshold.
enum TouchBar
{
    private static let brightness = load("DFRBrightness")
    private static let foundation = load("DFRFoundation")
    private static let panelDarkBit = 0x4

    private static func load(_ framework: String) -> UnsafeMutableRawPointer
    {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/\(framework).framework/\(framework)",
            RTLD_NOW
        ) else
        {
            fatalError("\(framework).framework did not load")
        }

        return handle
    }

    private static func function<T>(_ name: String, as type: T.Type) -> T
    {
        guard let address = dlsym(foundation, name) else
        {
            fatalError("\(name) is missing from DFRFoundation.framework")
        }

        return unsafeBitCast(address, to: type)
    }

    private static func makeBrightnessClient() -> NSObject
    {
        _ = brightness

        guard let clientClass =
            NSClassFromString("DFRBrightnessClient") as? NSObject.Type else
        {
            fatalError(
                "DFRBrightnessClient is missing from DFRBrightness.framework"
            )
        }

        return clientClass.init()
    }

    static var displayID: UInt64
    {
        let client = makeBrightnessClient()
        let selector = NSSelectorFromString("getDFRDisplayID")

        guard client.responds(to: selector) else
        {
            fatalError("DFRBrightnessClient does not provide getDFRDisplayID")
        }

        typealias GetDisplayID = @convention(c) (
            AnyObject,
            Selector
        ) -> UInt32
        let getDisplayID = unsafeBitCast(
            client.method(for: selector),
            to: GetDisplayID.self
        )

        return UInt64(getDisplayID(client, selector))
    }

    static var isLit: Bool
    {
        let status = function(
            "DFRGetStatus",
            as: (@convention(c) () -> Int).self
        )()
        return status & panelDarkBit == 0
    }

    static func onStatusChange(
        _ handler: @escaping @Sendable @convention(block) (Int) -> Void
    )
    {
        typealias Register = @convention(c) (
            @Sendable @convention(block) (Int) -> Void
        ) -> Void
        function(
            "DFRRegisterStatusChangeCallback",
            as: Register.self
        )(handler)
    }

    static func set(on: Bool, period: Float? = 0.0) -> Bool
    {
        let client = makeBrightnessClient()

        if let period
        {
            let selector = NSSelectorFromString(
                on ? "turnOnWithPeriod:" : "turnOffWithPeriod:"
            )

            guard client.responds(to: selector) else
            {
                fatalError(
                    "DFRBrightnessClient does not respond to \(selector)"
                )
            }

            typealias CallWithPeriod = @convention(c) (
                AnyObject,
                Selector,
                Float
            ) -> Bool
            let call = unsafeBitCast(
                client.method(for: selector),
                to: CallWithPeriod.self
            )
            return call(client, selector, period)
        }

        let selector = NSSelectorFromString(on ? "turnOn" : "turnOff")

        guard client.responds(to: selector) else
        {
            fatalError("DFRBrightnessClient does not respond to \(selector)")
        }

        typealias Call = @convention(c) (AnyObject, Selector) -> Bool
        let call = unsafeBitCast(client.method(for: selector), to: Call.self)
        return call(client, selector)
    }
}
