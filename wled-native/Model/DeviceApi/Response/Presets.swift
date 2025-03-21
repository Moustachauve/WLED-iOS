//
//  Presets.swift
//  WledLib
//
//  Created by Robert Brune on 26.11.23.
//

public struct Presets: Codable {
    
    var __1:Preset?
    var __2:Preset?
    var __3:Preset?
    var __4:Preset?
    var __5:Preset?
    var __6:Preset?
    var __7:Preset?
    var __8:Preset?
    var __9:Preset?
    var _10:Preset?
    var _11:Preset?
    var _12:Preset?
    var _13:Preset?
    var _14:Preset?
    var _15:Preset?
    var _16:Preset?
    var _17:Preset?
    
    public var presets:[(Int64, String)] {
        var result:[(Int64, String)] = []
        
        addTuple(&result, 1, \.__1)
        addTuple(&result, 2, \.__2)
        addTuple(&result, 3, \.__3)
        addTuple(&result, 4, \.__4)
        addTuple(&result, 5, \.__5)
        addTuple(&result, 6, \.__6)
        addTuple(&result, 7, \.__7)
        addTuple(&result, 8, \.__8)
        addTuple(&result, 9, \.__9)
        addTuple(&result, 10, \._10)
        addTuple(&result, 11, \._11)
        addTuple(&result, 12, \._12)
        addTuple(&result, 13, \._13)
        addTuple(&result, 14, \._14)
        addTuple(&result, 15, \._15)
        addTuple(&result, 16, \._16)
        addTuple(&result, 17, \._17)
        
        
        return result
    }
    
    private func addTuple(_ t: inout [(Int64, String)], _ n: Int64, _ p: KeyPath<Presets, Preset?>) {
        if let name = self[keyPath: p]?.name {
            t.append((n, name))
        }
    }
    
    enum CodingKeys:String, CodingKey {
        case __1 = "1"
        case __2 = "2"
        case __3 = "3"
        case __4 = "4"
        case __5 = "5"
        case __6 = "6"
        case __7 = "7"
        case __8 = "8"
        case __9 = "9"
        case _10 = "10"
        case _11 = "11"
        case _12 = "12"
        case _13 = "13"
        case _14 = "14"
        case _15 = "15"
        case _16 = "16"
        case _17 = "17"
    }
}
