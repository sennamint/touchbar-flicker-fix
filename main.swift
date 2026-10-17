import AppKit

// `TouchBarFlickerFix off|on` controls panel power from a terminal. Without
// arguments, the process runs as the menu bar app and maintains the selected
// mode.
let arguments = Array(CommandLine.arguments.dropFirst())

if !arguments.isEmpty
{
    guard arguments == ["off"] || arguments == ["on"] else
    {
        FileHandle.standardError.write(
            Data("usage: TouchBarFlickerFix [off|on]\n".utf8)
        )
        exit(64)
    }

    let turnOn = arguments == ["on"]

    guard TouchBar.set(on: turnOn, period: turnOn ? nil : 0.0) else
    {
        FileHandle.standardError.write(
            Data("DFRBrightnessClient refused the request\n".utf8)
        )
        exit(1)
    }

    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
