# Contributing

Thank you for helping improve TouchBar Flicker Fix. The app relies on private
macOS frameworks and currently has a very small hardware test pool, so careful
reports are especially valuable.

## Reporting a problem

Please include:

- Mac model and model identifier
- Processor architecture: Intel or Apple silicon
- macOS version
- App version
- Selected mode and inactivity timeout
- Calibrated brightness, if relevant
- What happened before, during and after the problem
- Whether the issue also occurs when the app is not running

Do not post serial numbers, account names or other personal information.

## Proposing a code change

1. Keep behavioural changes separate from cleanup where practical.
2. Use Allman brace style consistently.
3. Wrap comments at roughly 80 characters.
4. Build the production sources with the same command used by `install.sh`.
5. Test both menu-bar operation and the terminal `on`/`off` commands when the
   change affects Touch Bar control.
6. Update `README.md` and `CHANGELOG.md` when behaviour changes.

The programs in `Tools/` are investigative utilities, not production sources.
Read them before running them: some intentionally change Touch Bar brightness
or power state.

## Safety

Do not describe this project as a hardware repair or a medical safeguard. It is
a software workaround for a likely hardware fault and uses undocumented APIs
that Apple can change without notice.
