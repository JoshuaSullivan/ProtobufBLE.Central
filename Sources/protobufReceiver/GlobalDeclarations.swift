//
//  GlobalDeclarations.swift
//  ProtobufBTLE
//
//  Created by Joshua Sullivan on 5/5/17.
//  Copyright © 2017 The Nerdery. All rights reserved.
//

import Foundation
import CoreBluetooth

public struct BLEIdentifiers {
    public struct Services {
        public static let protoBuf = CBUUID(string: "33E02682-FD2C-4E00-A02D-BAE119562994")
    }
    
    public struct Characteristics {
        public static let attitude = CBUUID(string: "4CA9A5C5-9AD1-4ED4-8562-49F28AB7F83E")
    }
}
