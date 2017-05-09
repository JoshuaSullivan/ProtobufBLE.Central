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
        
        var errorCode: Int32 {
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
    
    fileprivate let manager: CBCentralManager
    
    fileprivate var peripheral: CBPeripheral?
    
    fileprivate var completion: CompletionCallback
    
    fileprivate let formatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .short
        return df
    }()
    
    // MARK: - Lifecycle
    
    init(completion: @escaping CompletionCallback) {
        let queue = DispatchQueue.main
        manager = CBCentralManager(delegate: nil, queue: queue)
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
//        manager.scanForPeripherals(withServices: nil, options: nil)
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
    
    // MARK: - Data handling
    
    fileprivate func handle(data: Data) {
        do {
            let packet = try Packet(serializedData: data)
            let date = Date(timeIntervalSinceReferenceDate: Double(packet.time))
            NSLog("[\(formatter.string(from: date))] x: \(packet.rx), y: \(packet.ry), z: \(packet.rz)")
        } catch {
            NSLog("Could not parse protobuf data: \(error.localizedDescription)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("BLE Central Manager did change status.")
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
        NSLog("Found a peripheral: \(peripheral)")
        NSLog("Attempting connection...")
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
        stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("Successfully connected to peripheral.")
        NSLog("Discovering services...")
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
        guard let data = characteristic.value else {
            NSLog("Characteristic contained no data on this update.")
            return
        }
        handle(data: data)
    }
}
