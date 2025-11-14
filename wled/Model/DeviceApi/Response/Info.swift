
import Foundation

struct Info: Decodable {
    var leds : Leds
    var wifi : Wifi
    var version : String?
    var buildId : Int64?
    var name : String
    var str : Bool?
    var udpPort : Int64?
    var isUpdatedLive : Bool?
    var lm : String?
    var lip : String?
    var websocketClientCount : Int64?
    var effectCount : Int64?
    var paletteCount : Int64?
    var fileSystem : FileSystem?
    var ndc : Int64?
    var platformName : String?	
    var arduinoCoreVersion : String?
    var lwip : Int64?
    var freeHeap : Int64?
    var uptime : Int64?
    var opt : Int64?
    var brand : String?
    var product : String?
    var mac : String?
    
    
    enum CodingKeys: String, CodingKey {
        case leds
        case wifi
        case version = "ver"
        case buildId = "vid"
        case name
        case str
        case udpPort = "udpport"
        case isUpdatedLive = "Live"
        case lm
        case lip
        case websocketClientCount = "ws"
        case effectCount = "fxcount"
        case paletteCount = "palcount"
        case fileSystem = "fs"
        case ndc
        case platformName = "arch"
        case arduinoCoreVersion = "core"
        case lwip
        case freeHeap
        case uptime
        case opt
        case brand
        case product
        case mac
    }
}
