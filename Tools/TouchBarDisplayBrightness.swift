import AppKit

private let dfrBrightnessPath =
    "/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness"
private let displayServicesPath =
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

guard dlopen(dfrBrightnessPath, RTLD_NOW) != nil else
{
    fatalError("DFRBrightness.framework did not load")
}

guard let displayServices = dlopen(displayServicesPath, RTLD_NOW) else
{
    fatalError("DisplayServices.framework did not load")
}

guard let clientClass = NSClassFromString("DFRBrightnessClient") as? NSObject.Type else
{
    fatalError("DFRBrightnessClient is unavailable")
}

let client = clientClass.init()
let displayIDSelector = NSSelectorFromString("getDFRDisplayID")

typealias GetDisplayID = @convention(c) (AnyObject, Selector) -> UInt32
let getDisplayID = unsafeBitCast(
    client.method(for: displayIDSelector),
    to: GetDisplayID.self
)
let displayID = getDisplayID(client, displayIDSelector)

typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32

guard let getAddress = dlsym(displayServices, "DisplayServicesGetBrightness"),
      let setAddress = dlsym(displayServices, "DisplayServicesSetBrightness") else
{
    fatalError("DisplayServices brightness functions are unavailable")
}

let getBrightness = unsafeBitCast(getAddress, to: GetBrightness.self)
let setBrightness = unsafeBitCast(setAddress, to: SetBrightness.self)
var brightness: Float = 0.0
let readResult = getBrightness(displayID, &brightness)

print("DFR display ID: \(displayID)")

if readResult == 0
{
    print(String(format: "Current DFR brightness: %.4f", brightness))
}
else
{
    print("Reading DFR brightness failed with result \(readResult)")
}

if CommandLine.arguments.count == 3,
   CommandLine.arguments[1] == "--set",
   let targetBrightness = Float(CommandLine.arguments[2]),
   (0.0...1.0).contains(targetBrightness)
{
    let writeResult = setBrightness(displayID, targetBrightness)

    guard writeResult == 0 else
    {
        fatalError("Setting DFR display brightness failed with result \(writeResult)")
    }

    print(String(format: "Set DFR brightness to %.4f", targetBrightness))
}
else if CommandLine.arguments.count != 1
{
    FileHandle.standardError.write(
        Data("usage: TouchBarDisplayBrightness [--set 0.0...1.0]\n".utf8)
    )
    exit(64)
}
