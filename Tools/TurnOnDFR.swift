import Foundation

private let frameworkPath =
    "/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness"

guard dlopen(frameworkPath, RTLD_NOW) != nil else
{
    fatalError("DFRBrightness.framework did not load")
}

guard let clientClass =
    NSClassFromString("DFRBrightnessClient") as? NSObject.Type else
{
    fatalError("DFRBrightnessClient is unavailable")
}

let client = clientClass.init()
let selector = NSSelectorFromString("turnOn")

typealias TurnOn = @convention(c) (AnyObject, Selector) -> Bool
let turnOn = unsafeBitCast(client.method(for: selector), to: TurnOn.self)

guard turnOn(client, selector) else
{
    fatalError("DFRBrightnessClient refused turnOn")
}

print("Touch Bar turnOn accepted")
