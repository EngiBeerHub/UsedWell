//
//  Item.swift
//  UsedWell
//
//  Created by RyosukeSeki on 2026/08/23.
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
