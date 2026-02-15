//
//  Untitled.swift
//  RaveClone
//
//  Created by Francesca Finetti on 15/02/26.
//

import Foundation

// Definisce le azioni possibili
enum ActionType: String, Codable {
    case play
    case pause
    case seek
}

// Il pacchetto dati che viaggia via WiFi
struct VideoEvent: Codable {
    let action: ActionType
    let timestamp: Double
}
