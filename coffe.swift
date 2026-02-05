import Foundation
import IOKit.pwr_mgt
import CoreGraphics
// MARK: - Output
var lastStatusLength = 0

func updateStatusLine(_ message: String) {
    var output = "\r" + message
    let paddingCount = max(0, lastStatusLength - message.count)
    if paddingCount > 0 {
        output += String(repeating: " ", count: paddingCount)
    }
    lastStatusLength = message.count

    if let data = output.data(using: .utf8) {
        FileHandle.standardOutput.write(data)
    }
}

func printNewLineIfNeeded() {
    if lastStatusLength > 0 {
        print("")
        lastStatusLength = 0
    }
}

// MARK: - Assertion per evitare sleep

var assertionID = IOPMAssertionID(0)
let assertionReason = "Modalità chiamata attiva (keep-awake)" as CFString
let shutdownFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm dd/MM"
    return formatter
}()

func createNoDisplaySleepAssertion() {
    let result = IOPMAssertionCreateWithName(
        kIOPMAssertionTypeNoDisplaySleep as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        assertionReason,
        &assertionID
    )

    if result == kIOReturnSuccess {
        print(shutdownConditionMessage())
        print(" - Il Mac non andrà in standby.")
        print(" - Il monitor resterà acceso.")
        print("Premi Ctrl+C per disattivare.\n")
    } else {
        fputs("Impossibile creare l'asserzione IOPM (errore \(result)).\n", stderr)
        exit(EXIT_FAILURE)
    }
}

func releaseNoDisplaySleepAssertion() {
    if assertionID != 0 {
        let result = IOPMAssertionRelease(assertionID)
        if result != kIOReturnSuccess {
            fputs("Errore nel rilascio dell'asserzione (errore \(result)).\n", stderr)
        }
        assertionID = 0
    }
}

// MARK: - Mouse jiggler

var jiggleDirection: CGFloat = 1
let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

func jiggleMouse() {
    guard let baseEvent = CGEvent(source: nil) else {
        fputs("Impossibile leggere la posizione corrente del mouse.\n", stderr)
        return
    }

    let currentLocation = baseEvent.location
    let newLocation = CGPoint(x: currentLocation.x + jiggleDirection,
                              y: currentLocation.y)

    if let moveEvent = CGEvent(mouseEventSource: nil,
                               mouseType: .mouseMoved,
                               mouseCursorPosition: newLocation,
                               mouseButton: .left) {
        moveEvent.post(tap: .cghidEventTap)
    }

    jiggleDirection *= -1

    let timestamp = timestampFormatter.string(from: Date())
    updateStatusLine("Ultimo movimento: \(timestamp)")
}

// MARK: - Gestione SIGINT (Ctrl+C)

var sigIntSource: DispatchSourceSignal?
var autoStopTimer: DispatchSourceTimer?

func shutdown(reason: String) {
    printNewLineIfNeeded()
    print(reason)

    releaseNoDisplaySleepAssertion()

    print("Modalità chiamata disattivata.")
    print("Il sistema tornerà al normale comportamento di risparmio energetico.")
    exit(EXIT_SUCCESS)
}

func setupSignalHandler() {
    // Ignoriamo il comportamento di default del segnale
    signal(SIGINT, SIG_IGN)

    let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

    source.setEventHandler {
        shutdown(reason: "Interruzione richiesta (Ctrl+C). Sto disattivando la modalità chiamata...")
    }

    source.resume()
    sigIntSource = source
}

// MARK: - Auto stop alle 18:10

var autoStopEnabled = true
var autoStopHour = 18
var autoStopMinute = 10

func parseArguments() {
    let args = ProcessInfo.processInfo.arguments
    var index = 1

    while index < args.count {
        let arg = args[index]

        if arg == "-t" {
            guard index + 1 < args.count else {
                fputs("Manca il valore per -t.\n", stderr)
                exit(EXIT_FAILURE)
            }

            let next = args[index + 1]
            if next.lowercased() == "false" {
                autoStopEnabled = false
                index += 2
                continue
            }

            guard index + 2 < args.count else {
                fputs("Serve -t HH MM.\n", stderr)
                exit(EXIT_FAILURE)
            }

            let hourValue = args[index + 1]
            let minuteValue = args[index + 2]
            guard let hour = Int(hourValue),
                  let minute = Int(minuteValue),
                  (0...23).contains(hour),
                  (0...59).contains(minute) else {
                fputs("Orario non valido per -t. Usa HH MM (00-23 00-59).\n", stderr)
                exit(EXIT_FAILURE)
            }

            autoStopHour = hour
            autoStopMinute = minute
            autoStopEnabled = true
            index += 3
            continue
        }

        fputs("Argomento non riconosciuto: \(arg)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

func nextAutoStopDate(from now: Date = Date()) -> Date? {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day], from: now)
    components.hour = autoStopHour
    components.minute = autoStopMinute
    components.second = 0

    guard let todayTarget = calendar.date(from: components) else {
        return nil
    }

    if now < todayTarget {
        return todayTarget
    }

    return calendar.date(byAdding: .day, value: 1, to: todayTarget)
}

func shutdownConditionMessage() -> String {
    if !autoStopEnabled {
        return "Modalità chiamata attiva fino a chiusura manuale."
    }

    if let targetDate = nextAutoStopDate() {
        return "Modalità chiamata attiva fino alle \(shutdownFormatter.string(from: targetDate))."
    }

    return "Modalità chiamata attiva."
}

func scheduleAutoStop() {
    if !autoStopEnabled {
        return
    }

    guard let targetDate = nextAutoStopDate() else {
        fputs("Impossibile calcolare l'orario di arresto automatico.\n", stderr)
        return
    }

    let interval = targetDate.timeIntervalSinceNow
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + interval)
    timer.setEventHandler {
        shutdown(reason: "Ora limite 18:10 raggiunta. Sto disattivando la modalità chiamata...")
    }
    timer.resume()
    autoStopTimer = timer
}

// MARK: - Main

parseArguments()
createNoDisplaySleepAssertion()
setupSignalHandler()
scheduleAutoStop()

// Timer: muove il mouse ogni 12 secondi
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now(), repeating: .seconds(12))
timer.setEventHandler {
    jiggleMouse()
}
timer.resume()

RunLoop.main.run()
