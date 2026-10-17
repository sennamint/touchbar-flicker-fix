import AppKit

let frameworkPath =
    "/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness"

guard dlopen(frameworkPath, RTLD_NOW) != nil else
{
    fatalError("DFRBrightness.framework did not load")
}

guard (3...4).contains(CommandLine.arguments.count),
      let step = Int(CommandLine.arguments[1]),
      (-2...10).contains(step),
      let coefficient = Float(CommandLine.arguments[2]),
      (0.0...4.0).contains(coefficient),
      let duration = CommandLine.arguments.count == 4
        ? Double(CommandLine.arguments[3])
        : 0.0,
      (0.0...60.0).contains(duration) else
{
    FileHandle.standardError.write(
        Data(
            "usage: SetDFRBrightness <step -2...10> "
                .appending("<coefficient 0.0...4.0> [seconds 0...60]\n")
                .utf8
        )
    )
    exit(64)
}

guard let clientClass = NSClassFromString("DFRBrightnessClient") as? NSObject.Type else
{
    fatalError("DFRBrightnessClient is unavailable")
}

let client = clientClass.init()
let turnOnSelector = NSSelectorFromString("turnOn")
let dimSelector = NSSelectorFromString("dimToStep:withCoefficient:")
let turnOffSelector = NSSelectorFromString("turnOff")

typealias Toggle = @convention(c) (AnyObject, Selector) -> Bool
typealias Dim = @convention(c) (AnyObject, Selector, Int, Float) -> Bool

guard client.responds(to: turnOnSelector),
      client.responds(to: dimSelector),
      client.responds(to: turnOffSelector) else
{
    fatalError("DFRBrightnessClient does not provide the required methods")
}

let turnOn = unsafeBitCast(client.method(for: turnOnSelector), to: Toggle.self)
let dim = unsafeBitCast(client.method(for: dimSelector), to: Dim.self)
let turnOff = unsafeBitCast(client.method(for: turnOffSelector), to: Toggle.self)

guard turnOn(client, turnOnSelector) else
{
    fatalError("DFRBrightnessClient refused to turn on")
}

func apply() -> Bool
{
    dim(client, dimSelector, step, coefficient)
}

guard apply() else
{
    _ = turnOff(client, turnOffSelector)
    fatalError("DFRBrightnessClient refused the brightness coefficient")
}

print("Applied dimming step \(step) with coefficient \(coefficient)")

if duration > 0.0
{
    let deadline = Date().addingTimeInterval(duration)

    while Date() < deadline
    {
        Thread.sleep(forTimeInterval: 0.25)

        guard apply() else
        {
            _ = turnOff(client, turnOffSelector)
            fatalError("DFRBrightnessClient stopped accepting the brightness coefficient")
        }
    }

    _ = turnOff(client, turnOffSelector)
    print("Test complete; Touch Bar turned off")
}
