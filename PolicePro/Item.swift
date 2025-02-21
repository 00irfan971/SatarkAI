//
//  Item.swift
//  PolicePro
//
//  Created by Irfan on 21/02/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
