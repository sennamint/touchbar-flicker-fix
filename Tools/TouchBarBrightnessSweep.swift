import AppKit

private let frameworkPath =
    "/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness"

private final class BrightnessClient
{
    private let client: NSObject
    private let dimSelector = NSSelectorFromString("dimToStep:withCoefficient:")
    private let turnOnSelector = NSSelectorFromString("turnOn")
    private let turnOffSelector = NSSelectorFromString("turnOff")

    private typealias Dim = @convention(c) (
        AnyObject,
        Selector,
        Int,
        Float
    ) -> Bool
    private typealias Toggle = @convention(c) (AnyObject, Selector) -> Bool

    init()
    {
        guard dlopen(frameworkPath, RTLD_NOW) != nil else
        {
            fatalError("DFRBrightness.framework did not load")
        }

        guard let clientClass =
            NSClassFromString("DFRBrightnessClient") as? NSObject.Type else
        {
            fatalError("DFRBrightnessClient is unavailable")
        }

        client = clientClass.init()
    }

    func set(coefficient: Float) -> Bool
    {
        let implementation = client.method(for: dimSelector)
        let dim = unsafeBitCast(implementation, to: Dim.self)
        return dim(client, dimSelector, 0, coefficient)
    }

    func turnOn() -> Bool
    {
        let implementation = client.method(for: turnOnSelector)
        let turnOn = unsafeBitCast(implementation, to: Toggle.self)
        return turnOn(client, turnOnSelector)
    }

    func turnOff()
    {
        let implementation = client.method(for: turnOffSelector)
        let turnOff = unsafeBitCast(implementation, to: Toggle.self)
        _ = turnOff(client, turnOffSelector)
    }
}

private final class TestViewController: NSViewController, NSTouchBarDelegate
{
    static let labelIdentifier = NSTouchBarItem.Identifier("BrightnessTest.label")

    let label = NSTextField(labelWithString: "Test wird vorbereitet …")
    let windowLabel = NSTextField(labelWithString: "Test wird vorbereitet …")

    override func loadView()
    {
        let container = NSView()
        windowLabel.translatesAutoresizingMaskIntoConstraints = false
        windowLabel.alignment = .center
        windowLabel.font = .boldSystemFont(ofSize: 24)
        windowLabel.lineBreakMode = .byWordWrapping
        windowLabel.maximumNumberOfLines = 3
        container.addSubview(windowLabel)
        NSLayoutConstraint.activate(
            [
                windowLabel.leadingAnchor.constraint(
                    equalTo: container.leadingAnchor,
                    constant: 24
                ),
                windowLabel.trailingAnchor.constraint(
                    equalTo: container.trailingAnchor,
                    constant: -24
                ),
                windowLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ]
        )
        view = container
    }

    override func makeTouchBar() -> NSTouchBar?
    {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [Self.labelIdentifier]
        touchBar.principalItemIdentifier = Self.labelIdentifier
        return touchBar
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem?
    {
        guard identifier == Self.labelIdentifier else
        {
            return nil
        }

        label.alignment = .center
        label.font = .boldSystemFont(ofSize: 15)
        label.textColor = .white

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = label
        return item
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate
{
    private let coefficients: [Float] = [0.6, 0.8, 1.0, 1.25, 1.5, 2.0]
    private let secondsPerStage = 12.0
    private let brightness = BrightnessClient()
    private let viewController = TestViewController()
    private var window: NSWindow!
    private var stageIndex = 0
    private var applyTimer: Timer?
    private var stageTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification)
    {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Touch-Bar-Helligkeitstest"
        window.contentViewController = viewController
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startStage()
    }

    func applicationWillTerminate(_ notification: Notification)
    {
        applyTimer?.invalidate()
        stageTimer?.invalidate()
        brightness.turnOff()
    }

    private func startStage()
    {
        guard stageIndex < coefficients.count else
        {
            finish()
            return
        }

        let coefficient = coefficients[stageIndex]
        let formatted = String(format: "%.2f", coefficient)
        let status =
            "Stufe \(stageIndex + 1)/\(coefficients.count) · Faktor \(formatted) · Flackern?"
        viewController.label.stringValue = status
        viewController.windowLabel.stringValue = status
        window.title = "Touch-Bar-Test: Faktor \(formatted)"

        guard brightness.turnOn(),
              brightness.set(coefficient: coefficient) else
        {
            finish()
            return
        }

        applyTimer?.invalidate()
        applyTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true)
        {
            [weak self] _ in
            guard let self else
            {
                return
            }

            if !self.brightness.set(coefficient: coefficient)
            {
                self.finish()
            }
        }

        stageTimer?.invalidate()
        stageTimer = Timer.scheduledTimer(withTimeInterval: secondsPerStage, repeats: false)
        {
            [weak self] _ in
            self?.stageIndex += 1
            self?.startStage()
        }
    }

    private func finish()
    {
        applyTimer?.invalidate()
        stageTimer?.invalidate()
        brightness.turnOff()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
