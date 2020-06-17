//
//  OCSProtocol.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/5/20.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Foundation

/*
 
 <ocs>
         <meta>
                 <status>ok</status>
                 <statuscode>100</statuscode>
                 <message>OK</message>
                 <totalitems></totalitems>
                 <itemsperpage></itemsperpage>
         </meta>
         <data>
                 <version>
                         <major>17</major>
                         <minor>0</minor>
                         <micro>2</micro>
                         <string>17.0.2</string>
                         <edition></edition>
                         <extendedSupport></extendedSupport>
                 </version>
                 <capabilities>
                         <core>
                                 <pollinterval>60</pollinterval>
                                 <webdav-root>remote.php/webdav</webdav-root>
                         </core>
                 </capabilities>
         </data>
 </ocs>
 
 */

/*
 "meta": {
     "itemsperpage": "",
     "message": "OK",
     "status": "ok",
     "statuscode": 100,
     "totalitems": ""
 }

 */
struct OCSMeta: Codable {
    var status: String
    var statuscode: Int
    var message: String
    var totalitems: String
    var itemsperpage: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case statuscode
        case message
        case totalitems
        case itemsperpage
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        status = try values.decode(String.self, forKey: .status)
        statuscode = try values.decode(Int.self, forKey: .statuscode)
        message = try values.decode(String.self, forKey: .message)
        totalitems = try values.decode(String.self, forKey: .totalitems)
        itemsperpage = try values.decode(String.self, forKey: .itemsperpage)
    }
}

/*
 "version": {
     "edition": "",
     "extendedSupport": 0,
     "major": 18,
     "micro": 2,
     "minor": 0,
     "string": "18.0.2"
 }

 */
struct OCSVersion: Codable {
    var major: Int
    var minor: Int
    var micro: Int
    var string: String
    var edition: String
    var extendedSupport: Bool
    
    enum CodingKeys: String, CodingKey {
        case major
        case minor
        case micro
        case string
        case edition
        case extendedSupport
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        major = try values.decode(Int.self, forKey: .major)
        minor = try values.decode(Int.self, forKey: .minor)
        micro = try values.decode(Int.self, forKey: .micro)
        string = try values.decode(String.self, forKey: .string)
        edition = try values.decode(String.self, forKey: .edition)
        extendedSupport = try values.decodeIfPresent(Bool.self, forKey: .extendedSupport) ?? false
    }
}

struct OCSData: Decodable {
    var version: OCSVersion
    var notes: OCSNotes
    
    enum CodingKeys: String, CodingKey {
        case version
        case capabilities
    }
    
    enum ExtraKeys: String, CodingKey {
        case notes
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(OCSVersion.self, forKey: .version)
        let capabilityValues = try values.nestedContainer(keyedBy: ExtraKeys.self, forKey: .capabilities)
        notes = try capabilityValues.decodeIfPresent(OCSNotes.self, forKey: .notes) ?? OCSNotes()
    }
}

/*
 "notes": {
   "api_version": [ "0.2", "1.0" ],
   "version": "3.6.0"
 }
 */
struct OCSNotes: Decodable {
    var api_version: [String]
    var version: String
    
    enum CodingKeys: String, CodingKey {
        case api_version
        case version
    }

    init() {
        api_version = [ "0.2" ]
        version = ""
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        api_version = try values.decode([String].self, forKey: .api_version)
        version = try values.decodeIfPresent(String.self, forKey: .version) ?? ""
    }
}


struct OCS: Decodable {
    var meta: OCSMeta
    var data: OCSData
    
    enum OCSKeys: String, CodingKey {
        case meta
        case data
    }
    
    enum CodingKeys: String, CodingKey {
        case ocs
    }

    init(from decoder: Decoder) throws {
        // Extract the top-level values ("ocs")
        let values = try decoder.container(keyedBy: CodingKeys.self)

        // Extract the user object as a nested container
        let ocs = try values.nestedContainer(keyedBy: OCSKeys.self, forKey: .ocs)

        // Extract each property from the nested container
        meta = try ocs.decode(OCSMeta.self, forKey: .meta)
        data = try ocs.decode(OCSData.self, forKey: .data)
    }

}

/*
 {"installed":true,
 "maintenance":false,
 "needsDbUpgrade":false,
 "version":"10.0.10.4",
 "versionstring":"10.0.10",
 "edition":"Community",
 "productname":"ownCloud"
 }
 */

struct CloudStatus: Decodable {
    var installed: Bool
    var maintenance: Bool
    var needsDbUpgrade: Bool
    var version: String
    var versionstring: String
    var edition: String
    var productname: String
    
    enum CodingKeys: String, CodingKey {
        case installed
        case maintenance
        case needsDbUpgrade
        case version
        case versionstring
        case edition
        case productname
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        installed = try values.decode(Bool.self, forKey: .installed)
        maintenance = try values.decode(Bool.self, forKey: .maintenance)
        needsDbUpgrade = try values.decode(Bool.self, forKey: .needsDbUpgrade)
        version = try values.decode(String.self, forKey: .version)
        versionstring = try values.decode(String.self, forKey: .versionstring)
        edition = try values.decode(String.self, forKey: .edition)
        productname = try values.decode(String.self, forKey: .productname)
    }

}
