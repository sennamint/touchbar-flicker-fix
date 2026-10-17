import Foundation
import IOKit
import IOKit.graphics

private let targetParentName = "backlight-dfr"
private let brightnessKey = "brightness" as CFString

func findTouchBarBacklight() -> io_service_t?
{
    var iterator: io_iterator_t = 0
    let result = IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceMatching("AppleARMBacklight"),
        &iterator
    )

    guard result == KERN_SUCCESS else
    {
        return nil
    }

    defer
    {
        IOObjectRelease(iterator)
    }

    while true
    {
        let service = IOIteratorNext(iterator)

        guard service != 0 else
        {
            return nil
        }

        var parent: io_registry_entry_t = 0
        let parentResult = IORegistryEntryGetParentEntry(
            service,
            kIOServicePlane,
            &parent
        )

        guard parentResult == KERN_SUCCESS else
        {
            IOObjectRelease(service)
            continue
        }

        defer
        {
            IOObjectRelease(parent)
        }

        var name = [CChar](repeating: 0, count: 128)
        let nameResult = IORegistryEntryGetName(parent, &name)

        if nameResult == KERN_SUCCESS,
           String(cString: name) == targetParentName
        {
            return service
        }

        IOObjectRelease(service)
    }
}

guard let service = findTouchBarBacklight() else
{
    fatalError("Touch Bar backlight service was not found")
}

defer
{
    IOObjectRelease(service)
}

var currentBrightness: Float = 0.0
let readResult = IODisplayGetFloatParameter(
    service,
    0,
    brightnessKey,
    &currentBrightness
)

if readResult == KERN_SUCCESS
{
    print(
        String(
            format: "Current Touch Bar brightness: %.4f",
            currentBrightness
        )
    )
}
else
{
    print("Reading brightness is unsupported (IOKit error \(readResult))")
}

if CommandLine.arguments.count == 3,
   CommandLine.arguments[1] == "--set",
   let targetBrightness = Float(CommandLine.arguments[2]),
   (0.0...1.0).contains(targetBrightness)
{
    let writeResult = IODisplaySetFloatParameter(
        service,
        0,
        brightnessKey,
        targetBrightness
    )

    guard writeResult == KERN_SUCCESS else
    {
        fatalError(
            "Setting Touch Bar brightness failed with IOKit error \(writeResult)"
        )
    }

    print(String(format: "Set Touch Bar brightness to %.4f", targetBrightness))
}
else if CommandLine.arguments.count != 1
{
    FileHandle.standardError.write(
        Data("usage: TouchBarBacklight [--set 0.0...1.0]\n".utf8)
    )
    exit(64)
}
