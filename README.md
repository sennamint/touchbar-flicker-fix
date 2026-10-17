# TouchBar Flicker Fix

A menu bar utility that can keep a failing MacBook Pro Touch Bar at a stable
brightness or turn it off completely.

Some Touch Bar panels flicker at low brightness even though macOS draws a clean
image. On the tested machine, repeatedly applying a sufficiently high backlight
level prevents that flicker. The app can also turn the Touch Bar off completely.

## Is it a hardware fault?

While the fault is visible, take a picture of what macOS is drawing to the bar:

```sh
screencapture -b ~/Desktop/touchbar.png
```

Shift-Command-6 does the same.

- **The picture is clean:** the fault sits after macOS has drawn the image, in the
  panel, its cable or the display controller. Software cannot repair that. This
  app may hide the symptom.
- **The picture shows the glitch:** macOS is drawing it. Restart the Mac and
  update macOS before anything else.

## Requirements

- A MacBook Pro with a Touch Bar
- macOS with the private frameworks used by the app
- Xcode or Xcode Command Line Tools with the Swift compiler

The app has so far been tested on only one 13-inch M1 MacBook Pro
(`MacBookPro17,1`). See [Compatibility and limitations](#compatibility-and-limitations)
before installing it on another model.

## Install from source

Clone this repository and run the installer:

```sh
git clone https://github.com/sennamint/touchbar-flicker-fix.git
cd touchbar-flicker-fix
./install.sh
```

This builds the app into `~/Applications/TouchBar Flicker Fix.app` and adds a
launch agent (`~/Library/LaunchAgents/io.github.gbili.TouchBarOff.plist`) that
starts it at login. The internal launch-agent label stays unchanged so existing
installations retain their settings and migrate cleanly.

Installation does not require `sudo`. The app is built locally and ad-hoc
signed. It does not make network requests.

## Use

Click the app icon in the menu bar to choose a mode:

- **Keep Touch Bar Bright and Stable:** continuously applies the saved stable
  brightness. This is the default mode.
- **Turn Touch Bar Off:** switches the Touch Bar off completely.
- **Turn Off After:** chooses an inactivity timeout of 15 seconds, 30 seconds,
  45 seconds, one minute, two minutes or never. The default is 45 seconds.
- **Calibrate…:** guides you through progressively lower levels. Mark each level
  as stable or flickering; the app saves the lowest stable result with a 40%
  safety margin, but never below `0.25`. The inactivity timeout is suspended
  throughout calibration and starts again from zero when calibration ends. Once
  a flickering value is found, the dialog shows the narrowing interval between
  the known flickering and stable levels both as text and on a colour-coded
  percentage scale.
- **About TouchBar Flicker Fix…:** explains the purpose and limitations of the
  app and shows its installed version.

The initial stable setting is `0.25`, approximately 98 nits on the tested
machine. Panel behaviour varies, so calibration is recommended. The selected
mode and calibrated brightness persist across launches.

CoreBrightness retains a manually applied Touch Bar brightness even after the
app stops updating it. The app therefore does not provide an automatic mode.
Native automatic brightness returns after restarting the Mac without starting
this app.

The Touch Bar can also be switched from Terminal:

```sh
"$HOME/Applications/TouchBar Flicker Fix.app/Contents/MacOS/TouchBarFlickerFix" off
"$HOME/Applications/TouchBar Flicker Fix.app/Contents/MacOS/TouchBarFlickerFix" on
```

## Uninstall

```sh
./uninstall.sh
```

Stops the app, lights the Touch Bar again and removes the app and its launch
agent.

## How it works

The app uses private macOS frameworks:

- `CoreBrightness.framework` provides `BrightnessSystemClient`. In stable mode,
  the app applies a `DisplayBrightness` value to the Touch Bar display ten times
  per second so that automatic brightness cannot return it to a flickering
  level.
- `DFRBrightness.framework` provides `DFRBrightnessClient` with `turnOff` and
  `turnOn` for the fully-off mode. The app uses the period variants with a
  zero-second transition so the panel does not fade through unstable levels.
- `DFRFoundation.framework` provides the Touch Bar display identifier and status
  notifications used to reapply the active mode when macOS changes the bar.

## Compatibility and limitations

- **One machine:** a 13-inch M1 MacBook Pro (MacBookPro17,1). Intel Touch Bar
  models and other hardware are untested. If you try one, open an issue with the
  model, macOS version and what happened.
- **Private frameworks:** a macOS update can break this, and the app cannot be
  distributed through the Mac App Store. If a required symbol is unavailable,
  the app exits with an error instead of pretending to work.
- **Symptom workaround:** this does not repair the panel or prevent the hardware
  fault from getting worse. A brief flash can still occur while switching modes,
  at login or immediately after wake. After wake, the app retries the zero-period
  transition and uses the standard transition once as a fallback if the private
  display service was not immediately ready.
- **Energy use:** stable mode intentionally keeps the Touch Bar brighter than
  macOS otherwise might, and reapplies the setting frequently.
- **No Touch Bar keys while dark:** brightness, volume and media controls remain
  available in Control Centre.
- **Not a medical safeguard:** if flicker is a health risk, do not rely on this
  alone. Cover the Touch Bar or have it repaired.

## Troubleshooting

### The menu bar icon does not appear

Run `./install.sh` again and check whether it reports that the app stayed
running. A missing private framework or changed private API can prevent startup
after a macOS update.

### The Touch Bar remains black

First try the **Keep Touch Bar Bright and Stable** menu command. If the menu bar
app is unavailable, run:

```sh
"$HOME/Applications/TouchBar Flicker Fix.app/Contents/MacOS/TouchBarFlickerFix" on
```

If the panel still does not return, restart the Mac. A Touch Bar can also stop
responding independently of this app.

### Flickering returns at the calibrated value

Run **Calibrate…** again under normal lighting and with the usual Touch Bar
content visible. The app adds a 40% safety margin, but failing panels can become
less stable over time.

## Development

The production sources are in `Sources/` plus `main.swift`. The probes in
`Tools/` document the private APIs investigated during development; they are
not part of the app build. See [CONTRIBUTING.md](CONTRIBUTING.md) before making a
change.

## Credits

TouchBar Flicker Fix is based on Guillermo Pages'
[`touchbar-off`](https://github.com/gbili/touchbar-off) project and retains its
MIT licence.

## Licence

MIT. See [LICENSE](LICENSE).
