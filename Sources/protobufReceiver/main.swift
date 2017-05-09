import Foundation

NSLog("Starting BLECentralService...")

let manager = BLECentralService(completion: {
    error in
    NSLog("BLECentralServices quit with an error: \(error.localizedDescription)")
    exit(error.errorCode)
})

RunLoop.main.run()
