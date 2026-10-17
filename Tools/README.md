# Development tools

This directory contains the small probes used to investigate the Touch Bar's
private brightness APIs and to reproduce the app icon. They are not required to
build or run TouchBar Flicker Fix.

Most probes call undocumented macOS frameworks directly. Their behaviour can
change between macOS releases, and some of them deliberately override Touch Bar
brightness or power state. Read the source before running one.

`GenerateAppIcon.swift` is the exception: it is the reproducible source for the
icon files in `Assets/AppIcon.iconset` and `Assets/AppIcon.icns`.
