//
//  BLECentralService.swift
//  ProtobufReceiver
//
//  Created by Joshua Sullivan on 5/9/17.
//
//

import Foundation
import CoreBluetooth

class BLECentralService: NSObject {
    
    // MARK: Child Types and Constants
    
    /// A closure that is invoked when the BLECentralSerivce is shutting down due to an error.
    typealias CompletionCallback = (BLECentralServiceError) -> Void
    
    enum BLECentralServiceError: Error {
        case bleNotSupported
        case bleNotAuthorized
        
        var errorCode: Int {
            switch self {
            case .bleNotSupported:
                return 1000
            case .bleNotAuthorized:
                return 1001
            }
        }
        
        var localizedDescription: String {
            switch self {
            case .bleNotSupported:
                return "BLE is not supported by this device."
            case .bleNotAuthorized:
                return "The app is not authorized to use BLE."
            }
        }
    }
    
    // MARK: - Properties
    
    let manager: CBCentralManager
    
    var peripheral: CBPeripheral?
    
    var completion: CompletionCallback
    
    // MARK: - Lifecycle
    
    init(completion: @escaping CompletionCallback) {
        manager = CBCentralManager(delegate: nil, queue: DispatchQueue.global(qos: .default))
        self.completion = completion
        super.init()
        manager.delegate = self
    }
    
    // MARK: - Peripheral Discovery
    
    fileprivate func startScan() {
        guard manager.state == .poweredOn else {
            return
        }
        NSLog("Starting scan for peripherals.")
        manager.scanForPeripherals(withServices: [BLEIdentifiers.Services.protoBuf], options: nil)
    }
    
    fileprivate func stopScan() {
        guard manager.state == .poweredOn else {
            return
        }
        NSLog("Stopping scan for peripherals.")
        manager.stopScan()
    }
    
    fileprivate func restartScan() {
        self.peripheral = nil
        startScan()
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            NSLog("BLE is now powered on.")
            guard peripheral == nil else { return }
            startScan()
        case .poweredOff:
            NSLog("BLE is now powered off.")
        case .unauthorized:
            completion(.bleNotAuthorized)
        case .unsupported:
            completion(.bleNotSupported)
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        central.connect(peripheral, options: nil)
        stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([BLEIdentifiers.Services.protoBuf])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            NSLog("Failed to connect to peripheral: \(error.localizedDescription)")
        } else {
            NSLog("Failed to connect to peripheral.")
        }
        restartScan()
    }
}

extension BLECentralService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            NSLog("Failed to discover services: \(error.localizedDescription)")
            restartScan()
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == BLEIdentifiers.Services.protoBuf }) else {
            NSLog("Couldn't find any appropriate services on the peripheral.")
            restartScan()
            return
        }
        
        peripheral.discoverCharacteristics([BLEIdentifiers.Characteristics.attitude], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == BLEIdentifiers.Characteristics.attitude }) else {
            NSLog("Couldn't find the 'attitude' characteristic.")
            restartScan()
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        <#code#>
    }
}
