//
//  Preset.swift
//  WledLib
//
//  Created by Robert Brune on 28.11.23.
//

public struct Preset: Codable {
    var name:String?
    
    enum CodingKeys: String, CodingKey {
        case name = "n"
    }
}
