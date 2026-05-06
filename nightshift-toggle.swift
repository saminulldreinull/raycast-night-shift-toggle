import Foundation

// -- CoreBrightness Private Framework laden --
let fwPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
guard dlopen(fwPath, RTLD_NOW) != nil else {
    fputs("ERROR: CoreBrightness framework not found. Night Shift may not be supported.\n", stderr)
    exit(1)
}

guard let ClientClass = NSClassFromString("CBBlueLightClient") as? NSObject.Type else {
    fputs("ERROR: CBBlueLightClient class not available.\n", stderr)
    exit(1)
}

let client = ClientClass.init()

// -- Aktuellen Status lesen --
let getSel = NSSelectorFromString("getBlueLightStatus:")
guard client.responds(to: getSel),
      let method = class_getInstanceMethod(type(of: client), getSel) else {
    fputs("ERROR: getBlueLightStatus: not available.\n", stderr)
    exit(1)
}

// Status-Struct: offset 0 = available, offset 1 = enabled (verifiziert auf macOS 26)
var statusBuf = [UInt8](repeating: 0, count: 128)
typealias GetStatusFn = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<UInt8>) -> Bool
let getStatus = unsafeBitCast(method_getImplementation(method), to: GetStatusFn.self)

guard getStatus(client, getSel, &statusBuf) else {
    fputs("ERROR: Could not read Night Shift status.\n", stderr)
    exit(1)
}

// Offset 1 = enabled (ermittelt per Struct-Analyse auf macOS 26 Tahoe)
let isEnabled = statusBuf[1] != 0

// -- Toggle --
let newState = !isEnabled
let setSel = NSSelectorFromString("setEnabled:")
guard client.responds(to: setSel),
      let setMethod = class_getInstanceMethod(type(of: client), setSel) else {
    fputs("ERROR: setEnabled: not available.\n", stderr)
    exit(1)
}

typealias SetEnabledFn = @convention(c) (AnyObject, Selector, Bool) -> Void
let setEnabled = unsafeBitCast(method_getImplementation(setMethod), to: SetEnabledFn.self)
setEnabled(client, setSel, newState)

// -- Ergebnis verifizieren --
usleep(200_000) // 200ms warten
var verifyBuf = [UInt8](repeating: 0, count: 128)
if getStatus(client, getSel, &verifyBuf) {
    let verifiedState = verifyBuf[1] != 0
    if verifiedState == newState {
        print(newState ? "Night Shift ON 🌙" : "Night Shift OFF ☀️")
    } else {
        fputs("WARNING: Toggle was sent but verification shows state unchanged.\n", stderr)
        print(newState ? "Night Shift ON 🌙 (unverified)" : "Night Shift OFF ☀️ (unverified)")
    }
} else {
    print(newState ? "Night Shift ON 🌙" : "Night Shift OFF ☀️")
}
