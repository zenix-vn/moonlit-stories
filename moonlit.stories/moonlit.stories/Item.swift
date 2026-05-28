//
//  Item.swift
//  moonlit.stories
//
//  Created by Toan Zin100   on 28/5/26.
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
