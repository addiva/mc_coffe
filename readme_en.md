# mc_coffe
Need a coffe break without teams telling on you? I got you!

## Location
The tool can be placed in any folder. For the example, assume `coffe.swift` is in the current directory.

## Compilation
```
swiftc -framework IOKit -framework CoreFoundation coffe.swift -o coffe
```

## Installation (PATH)
Add the current folder to your PATH so `coffe` can be invoked from any directory:

```
echo 'export PATH="$(pwd):$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Usage
```
coffe
```

## Short description
`coffe` keeps the Mac awake by preventing sleep and display shutdown and by simulating user activity. Interrupt with `Ctrl+C` to restore normal behavior.

## Advanced
Brief: coffe creates an IOPM assertion to prevent system sleep and keep the display on; it also simulates user activity by moving the mouse at regular intervals and can stop automatically at a configurable time.

### Modes and parameters
| Option | Effect | Values |
|---|---:|---|
| none | Default behavior: create assertion, move mouse every 12s, auto-stop at 18:10 | — |
| -t false | Disable automatic stop (remains active until manually closed) | `-t false` |
| -t HH MM | Set auto-stop time (if already passed today → schedule for tomorrow) | `-t 21 30` (example) |
| Ctrl+C (SIGINT) | Release assertion and exit cleanly | User interaction |
| invalid arguments | Prints error to stderr and exits with failure | — |

### Technical details (not in the summary)
- Default auto-stop: 18:10 (configurable with `-t`).
- Mouse movement interval: every 12 seconds; movement is ±1 point on the X axis.
- Status line updated with timestamp (dateStyle .short / timeStyle .medium).
- Display stop time format: `HH:mm dd/MM`.
- Uses DispatchSourceTimer and RunLoop.main for scheduling.
- Handles SIGINT to release the IOPM assertion cleanly.
- May require Accessibility / Input Monitoring permissions to send mouse events on macOS.
- Errors when creating the assertion or invalid arguments are reported to stderr and cause the program to exit.
