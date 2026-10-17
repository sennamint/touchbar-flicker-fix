import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate
{
    private enum Mode: String
    {
        case stable
        case off
    }

    private enum CalibrationAnswer
    {
        case stable
        case flickers
        case cancel
    }

    private static let defaultBrightness: Float = 0.25
    private static let minimumStableBrightness: Float = 0.25
    private static let calibrationSafetyFactor: Float = 1.4
    private static let previousCalibrationSafetyFactor: Float = 1.2
    private static let safetyMarginRevision = 2
    private static let defaultIdleTimeout: TimeInterval = 45.0
    private static let brightnessKey = "stableBrightness"
    private static let idleTimeoutKey = "idleTimeout"
    private static let modeKey = "mode"
    private static let safetyMarginRevisionKey = "safetyMarginRevision"

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let stableBrightness = StableBrightnessController()
    private var stableTimer: Timer?
    private var wasTurnedOffForIdle = false
    private var isCalibrating = false
    private var idleGraceStartedAt: Date?
    private var mode = Mode.stable
    private var targetBrightness = defaultBrightness
    private var idleTimeout: TimeInterval? = defaultIdleTimeout
    private var stableMenuItem: NSMenuItem!
    private var offMenuItem: NSMenuItem!
    private var idleTimeoutMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification)
    {
        loadPreferences()
        createStatusItem()
        createMenu()

        TouchBar.onStatusChange
        {
            [weak self] _ in
            DispatchQueue.main.async
            {
                self?.handleStatusChange()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(woke),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        applyMode()
    }

    func applicationWillTerminate(_ notification: Notification)
    {
        stopStableTimer()
    }

    private func loadPreferences()
    {
        let defaults = UserDefaults.standard

        if let storedMode = defaults.string(forKey: Self.modeKey),
           let restoredMode = Mode(rawValue: storedMode)
        {
            mode = restoredMode
        }

        if defaults.object(forKey: Self.brightnessKey) != nil
        {
            let storedBrightness = defaults.float(forKey: Self.brightnessKey)
            targetBrightness = min(
                max(storedBrightness, Self.minimumStableBrightness),
                1.0
            )

            if defaults.integer(forKey: Self.safetyMarginRevisionKey)
                < Self.safetyMarginRevision
            {
                targetBrightness = min(
                    1.0,
                    targetBrightness
                        * Self.calibrationSafetyFactor
                        / Self.previousCalibrationSafetyFactor
                )
                defaults.set(targetBrightness, forKey: Self.brightnessKey)
                defaults.set(
                    Self.safetyMarginRevision,
                    forKey: Self.safetyMarginRevisionKey
                )
            }

            defaults.set(targetBrightness, forKey: Self.brightnessKey)
        }

        if defaults.object(forKey: Self.idleTimeoutKey) != nil
        {
            let storedTimeout = defaults.double(forKey: Self.idleTimeoutKey)
            idleTimeout = storedTimeout > 0.0 ? storedTimeout : nil
        }
    }

}

// MARK: - Menu construction

private extension AppDelegate
{
    private func createStatusItem()
    {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        guard let button = statusItem.button else
        {
            fatalError("the status bar button is unavailable")
        }

        button.toolTip = "Touch Bar brightness options"
    }

    private func createMenu()
    {
        stableMenuItem = menu.addItem(
            withTitle: "Keep Touch Bar Bright and Stable",
            action: #selector(useStableBrightness),
            keyEquivalent: ""
        )
        stableMenuItem.target = self

        offMenuItem = menu.addItem(
            withTitle: "Turn Touch Bar Off",
            action: #selector(turnOff),
            keyEquivalent: ""
        )
        offMenuItem.target = self

        menu.addItem(.separator())
        addIdleTimeoutMenu()
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Calibrate…",
            action: #selector(calibrate),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "About TouchBar Flicker Fix…",
            action: #selector(showAbout),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(
            withTitle: "Quit",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = nil
        statusItem.menu = menu
    }

    private func addIdleTimeoutMenu()
    {
        let parentItem = NSMenuItem(
            title: "Turn Off After",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu(title: "Turn Off After")
        let choices: [(String, Int)] =
        [
            ("15 Seconds", 15),
            ("30 Seconds", 30),
            ("45 Seconds", 45),
            ("1 Minute", 60),
            ("2 Minutes", 120),
            ("Never", 0)
        ]

        for (title, seconds) in choices
        {
            let item = submenu.addItem(
                withTitle: title,
                action: #selector(setIdleTimeout(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = seconds
            idleTimeoutMenuItems.append(item)
        }

        menu.addItem(parentItem)
        menu.setSubmenu(submenu, for: parentItem)
    }

}

// MARK: - Brightness control and presentation

private extension AppDelegate
{
    private func savePreferences()
    {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(targetBrightness, forKey: Self.brightnessKey)
        defaults.set(idleTimeout ?? 0.0, forKey: Self.idleTimeoutKey)
        defaults.set(
            Self.safetyMarginRevision,
            forKey: Self.safetyMarginRevisionKey
        )
    }

    private func applyMode()
    {
        stopStableTimer()

        switch mode
        {
        case .stable:
            wasTurnedOffForIdle = false

            guard TouchBar.set(on: true) else
            {
                showFailure("The Touch Bar did not turn on")
                return
            }

            guard applyStableBrightness() else
            {
                showFailure("CoreBrightness rejected the stable brightness")
                return
            }

            startStableTimer()

        case .off:
            wasTurnedOffForIdle = false

            if !TouchBar.set(on: false)
            {
                showFailure("The Touch Bar did not turn off")
            }

        }

        updatePresentation()
    }

    private func applyStableBrightness() -> Bool
    {
        stableBrightness.apply(targetBrightness)
    }

    private func startStableTimer()
    {
        let timer = Timer(timeInterval: 0.1, repeats: true)
        {
            [weak self] _ in
            guard let self,
                  self.mode == .stable else
            {
                return
            }

            self.maintainStableBrightness()
        }
        RunLoop.main.add(timer, forMode: .common)
        stableTimer = timer
    }

    private func stopStableTimer()
    {
        stableTimer?.invalidate()
        stableTimer = nil
    }

    private func maintainStableBrightness()
    {
        if isCalibrating
        {
            if wasTurnedOffForIdle
            {
                _ = TouchBar.set(on: true)
                wasTurnedOffForIdle = false
            }

            _ = applyStableBrightness()
            return
        }

        let eventTypes: [CGEventType] =
        [
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .scrollWheel,
            .otherMouseDown,
            .otherMouseDragged
        ]
        var idleSeconds = eventTypes.map
        {
            CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: $0
            )
        }.min() ?? .infinity

        if let idleGraceStartedAt
        {
            let graceIdleSeconds = Date().timeIntervalSince(idleGraceStartedAt)
            idleSeconds = min(idleSeconds, graceIdleSeconds)

            if graceIdleSeconds >= (idleTimeout ?? 0.0)
            {
                self.idleGraceStartedAt = nil
            }
        }

        if wasTurnedOffForIdle
        {
            guard idleSeconds < 1.0 else
            {
                return
            }

            // Store the safe level before powering the panel back on, then
            // repeat it immediately afterwards.
            _ = applyStableBrightness()
            guard TouchBar.set(on: true) else
            {
                return
            }

            _ = applyStableBrightness()
            wasTurnedOffForIdle = false
            return
        }

        if let idleTimeout,
           idleSeconds >= idleTimeout
        {
            _ = TouchBar.set(on: false)
            wasTurnedOffForIdle = true
            return
        }

        _ = applyStableBrightness()
    }

    private func handleStatusChange()
    {
        switch mode
        {
        case .stable:
            if wasTurnedOffForIdle
            {
                return
            }

            if TouchBar.isLit
            {
                _ = applyStableBrightness()
            }
            else
            {
                applyMode()
            }

        case .off:
            if TouchBar.isLit
            {
                _ = TouchBar.set(on: false)
            }

        }
    }

    private func updatePresentation()
    {
        stableMenuItem.state = mode == .stable ? .on : .off
        offMenuItem.state = mode == .off ? .on : .off
        let selectedTimeout = Int(idleTimeout ?? 0.0)

        for item in idleTimeoutMenuItems
        {
            item.state = item.tag == selectedTimeout ? .on : .off
        }
        let description: String

        switch mode
        {
        case .stable:
            description = "Touch Bar bright and stable"
        case .off:
            description = "Touch Bar off"
        }

        let image = makeStatusIcon(isOff: mode == .off)
        image.accessibilityDescription = description
        image.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "\(description). Click for options."
    }

    private func makeStatusIcon(isOff: Bool) -> NSImage
    {
        NSImage(
            size: NSSize(width: 22, height: 16),
            flipped: false
        )
        {
            _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let outline = NSBezierPath(
                roundedRect: NSRect(x: 1.5, y: 3.5, width: 19, height: 9),
                xRadius: 3,
                yRadius: 3
            )
            outline.lineWidth = 1.5
            outline.stroke()

            for x in [4.5, 9.5, 14.5]
            {
                NSBezierPath(
                    roundedRect: NSRect(x: x, y: 6, width: 3, height: 4),
                    xRadius: 1,
                    yRadius: 1
                ).fill()
            }

            if isOff
            {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 2.5, y: 1.5))
                slash.line(to: NSPoint(x: 19.5, y: 14.5))
                slash.lineWidth = 2
                slash.lineCapStyle = .round
                slash.stroke()
            }

            return true
        }
    }

    private func setMode(_ newMode: Mode)
    {
        mode = newMode
        savePreferences()
        applyMode()
    }

}

// MARK: - Menu and system actions

private extension AppDelegate
{
    @objc private func woke()
    {
        guard mode == .stable else
        {
            applyMode()
            return
        }

        wasTurnedOffForIdle = false
        idleGraceStartedAt = Date()

        for delay in [0.25, 0.75]
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay)
            {
                [weak self] in
                guard let self,
                      self.mode == .stable else
                {
                    return
                }

                _ = self.applyStableBrightness()
                _ = TouchBar.set(on: true)
                _ = self.applyStableBrightness()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)
        {
            [weak self] in
            guard let self,
                  self.mode == .stable else
            {
                return
            }

            _ = self.applyStableBrightness()
            _ = TouchBar.set(on: true, period: nil)
            _ = self.applyStableBrightness()
        }
    }

    @objc private func useStableBrightness()
    {
        setMode(.stable)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75)
        {
            [weak self] in
            guard let self,
                  self.mode == .stable else
            {
                return
            }

            _ = self.applyStableBrightness()
            _ = TouchBar.set(on: true, period: nil)
            _ = self.applyStableBrightness()
        }
    }

    @objc private func turnOff()
    {
        setMode(.off)
    }

    @objc private func setIdleTimeout(_ sender: NSMenuItem)
    {
        idleTimeout = sender.tag > 0 ? TimeInterval(sender.tag) : nil
        savePreferences()
        updatePresentation()

        if mode == .stable && wasTurnedOffForIdle
        {
            _ = applyStableBrightness()
            _ = TouchBar.set(on: true)
            _ = applyStableBrightness()
            wasTurnedOffForIdle = false
        }
    }

    @objc private func showAbout()
    {
        NSApp.activate(ignoringOtherApps: true)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 9

        let credits = NSAttributedString(
            string:
                "TouchBar Flicker Fix suppresses flickering on affected "
                    .appending("MacBook Pro Touch Bars by keeping panel ")
                    .appending("brightness above a calibrated stable threshold.\n\n")
                    .appending("It can also turn the Touch Bar off after ")
                    .appending("inactivity and restore it without fading through ")
                    .appending("unstable brightness levels.\n\n")
                    .appending("This is a software workaround for a likely ")
                    .appending("hardware fault. It does not repair the Touch Bar.\n\n")
                    .appending("Uses private macOS frameworks. MIT License."),
            attributes:
            [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        let options: [NSApplication.AboutPanelOptionKey: Any] =
        [
            .credits: credits
        ]

        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func quitApplication()
    {
        NSApp.terminate(nil)
    }

}

// MARK: - Calibration

private extension AppDelegate
{
    @objc private func calibrate()
    {
        NSApp.activate(ignoringOtherApps: true)
        isCalibrating = true

        guard showCalibrationIntroduction() else
        {
            endCalibrationSession()
            return
        }

        defer
        {
            endCalibrationSession()
        }

        let originalMode = mode
        let originalBrightness = targetBrightness
        mode = .stable
        targetBrightness = 0.7
        applyMode()

        var stableValue: Float?
        var flickerValue: Float?
        var candidate = targetBrightness

        while true
        {
            targetBrightness = candidate
            _ = applyStableBrightness()

            switch askAboutCalibrationStep(
                candidate,
                stableValue: stableValue,
                flickerValue: flickerValue
            )
            {
            case .stable:
                stableValue = candidate

                if let lowerBound = flickerValue
                {
                    if candidate - lowerBound <= 0.01
                    {
                        finishCalibration(with: candidate)
                        return
                    }

                    candidate = (candidate + lowerBound) / 2.0
                }
                else if candidate <= 0.05
                {
                    finishCalibration(with: candidate)
                    return
                }
                else
                {
                    candidate = max(0.05, candidate - 0.1)
                }

            case .flickers:
                flickerValue = candidate

                if let upperBound = stableValue
                {
                    if upperBound - candidate <= 0.01
                    {
                        finishCalibration(with: upperBound)
                        return
                    }

                    candidate = (candidate + upperBound) / 2.0
                }
                else if candidate >= 1.0
                {
                    showFailure("No flicker-free brightness was found")
                    targetBrightness = originalBrightness
                    mode = originalMode
                    applyMode()
                    return
                }
                else
                {
                    candidate = min(1.0, candidate + 0.1)
                }

            case .cancel:
                targetBrightness = originalBrightness
                mode = originalMode
                applyMode()
                return
            }
        }
    }

    private func askAboutCalibrationStep(
        _ brightness: Float,
        stableValue: Float?,
        flickerValue: Float?
    ) -> CalibrationAnswer
    {
        let alert = NSAlert()
        alert.icon = nil
        let testPercent = brightness * 100.0
        alert.accessoryView = CalibrationScaleView(
            testValue: brightness,
            stableValue: stableValue,
            flickerValue: flickerValue
        )

        if let stableValue,
           let flickerValue
        {
            alert.messageText = String(
                format: "Fine search — test %.0f%%",
                testPercent
            )
            alert.informativeText = String(
                format:
                    "Flickers: %.0f%%   ←   Test: %.0f%%   →   Stable: %.0f%%\n\n"
                        .appending("The test value may move up or down while the ")
                        .appending("interval is narrowed. Wait a few seconds, ")
                        .appending("then report what you see."),
                flickerValue * 100.0,
                testPercent,
                stableValue * 100.0
            )
        }
        else
        {
            alert.messageText = String(
                format: "Coarse search — test %.0f%%",
                testPercent
            )

            if stableValue != nil
            {
                alert.informativeText =
                    "Brightness is being lowered in larger steps to find the "
                        .appending("first flickering level. Wait a few seconds, ")
                        .appending("then report what you see.")
            }
            else
            {
                alert.informativeText =
                    "No stable level has been found yet, so brightness is being "
                        .appending("increased. Wait a few seconds, then report ")
                        .appending("what you see.")
            }
        }

        alert.addButton(
            withTitle: String(format: "%.0f%% Is Stable", testPercent)
        )
        alert.addButton(
            withTitle: String(format: "%.0f%% Flickers", testPercent)
        )
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal()
        {
        case .alertFirstButtonReturn:
            return .stable
        case .alertSecondButtonReturn:
            return .flickers
        default:
            return .cancel
        }
    }

    private func finishCalibration(with lowestStableValue: Float)
    {
        targetBrightness = min(
            1.0,
            max(
                Self.minimumStableBrightness,
                lowestStableValue * Self.calibrationSafetyFactor
            )
        )
        mode = .stable
        savePreferences()
        applyMode()

        let alert = NSAlert()
        alert.icon = nil
        alert.messageText = "Calibration complete"
        alert.informativeText = String(
            format:
                "The stable brightness is set to %.0f%%, including a 40%% "
                    .appending("safety margin."),
            targetBrightness * 100.0
        )
        alert.addButton(withTitle: "Done")
        alert.runModal()
    }

    private func makeCalibrationIntroductionView() -> NSView
    {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.edgeInsets = NSEdgeInsets(
            top: 4,
            left: 0,
            bottom: 4,
            right: 0
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        let sections =
        [
            (
                "1. Find the flicker boundary",
                "Brightness is lowered in larger steps until flickering first "
                    .appending("appears.")
            ),
            (
                "2. Narrow the interval",
                "The app then tests values between the known flickering and "
                    .appending("stable levels. Values may move up and down; this ")
                    .appending("is intentional.")
            ),
            (
                "At each test",
                "Wait a few seconds before choosing whether the Touch Bar is "
                    .appending("stable or flickering.")
            )
        ]

        for (index, section) in sections.enumerated()
        {
            let heading = NSTextField(labelWithString: section.0)
            heading.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            stack.addArrangedSubview(heading)

            let body = NSTextField(wrappingLabelWithString: section.1)
            body.font = NSFont.systemFont(ofSize: 13)
            body.maximumNumberOfLines = 0
            body.preferredMaxLayoutWidth = 500
            stack.addArrangedSubview(body)

            if index < sections.count - 1
            {
                stack.setCustomSpacing(15, after: body)
            }
        }

        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: 500, height: 175)
        )
        container.addSubview(stack)
        NSLayoutConstraint.activate(
            [
                stack.leadingAnchor.constraint(
                    equalTo: container.leadingAnchor
                ),
                stack.trailingAnchor.constraint(
                    equalTo: container.trailingAnchor
                ),
                stack.topAnchor.constraint(equalTo: container.topAnchor),
                stack.bottomAnchor.constraint(
                    lessThanOrEqualTo: container.bottomAnchor
                ),
                container.widthAnchor.constraint(equalToConstant: 500)
            ]
        )
        return container
    }

    private func showCalibrationIntroduction() -> Bool
    {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 360),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "TouchBar Flicker Fix"
        panel.isReleasedWhenClosed = false

        let contentView = NSView()
        panel.contentView = contentView

        let title = NSTextField(
            labelWithString: "Calibrate the stable Touch Bar brightness"
        )
        title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let introduction = makeCalibrationIntroductionView()
        introduction.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(
            title: "Cancel",
            target: self,
            action: #selector(cancelCalibrationIntroduction)
        )
        cancelButton.keyEquivalent = "\u{1b}"

        let startButton = NSButton(
            title: "Start",
            target: self,
            action: #selector(startCalibrationIntroduction)
        )
        startButton.keyEquivalent = "\r"

        let buttons = NSStackView(views: [cancelButton, startButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(title)
        contentView.addSubview(introduction)
        contentView.addSubview(buttons)
        NSLayoutConstraint.activate(
            [
                title.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: 30
                ),
                title.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 40
                ),
                title.trailingAnchor.constraint(
                    lessThanOrEqualTo: contentView.trailingAnchor,
                    constant: -40
                ),
                introduction.topAnchor.constraint(
                    equalTo: title.bottomAnchor,
                    constant: 22
                ),
                introduction.centerXAnchor.constraint(
                    equalTo: contentView.centerXAnchor
                ),
                buttons.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -30
                ),
                buttons.bottomAnchor.constraint(
                    equalTo: contentView.bottomAnchor,
                    constant: -24
                )
            ]
        )

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return response == .OK
    }

    @objc private func startCalibrationIntroduction()
    {
        NSApp.stopModal(withCode: .OK)
    }

    @objc private func cancelCalibrationIntroduction()
    {
        NSApp.stopModal(withCode: .cancel)
    }

    private func endCalibrationSession()
    {
        isCalibrating = false
        idleGraceStartedAt = Date()
        _ = applyStableBrightness()
        _ = TouchBar.set(on: true)
        _ = applyStableBrightness()
        wasTurnedOffForIdle = false
    }

    private func showFailure(_ message: String)
    {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText =
            "The private macOS brightness service refused the request."
        alert.runModal()
    }
}
