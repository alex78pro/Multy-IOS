//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import Foundation
import BigInt

enum DappOperationType : String, Decodable {
    case
    signTransaction =       "signTransaction",
    signMessage =           "signMessage",
    signPersonalMessage =   "signPersonalMessage",
    signTypedMessage =      "signTypedMessage"
}

struct OperationObject {
    var chainID:    NSNumber
    var hexData:    String
    var fromAddress:String
    var toAddress:  String
    var gasPrice:   BigUInt
    var gasLimit:   BigUInt
    var nonce:      Int
    var value:      String
    var id:         Int64
    
    
    init(with object: Dictionary<String, Any>, for id: Int64) {
        if let chainID =  object["chainId"] as? NSNumber {
            self.chainID = chainID
        } else {
            chainID = 4
        }
        
        if let hexData =  object["data"] as? String {
            self.hexData = String(hexData)
        } else {
            self.hexData = ""
        }
        
        if let fromAddress =  object["from"] as? String {
            self.fromAddress = fromAddress
        } else {
            self.fromAddress = ""
        }
        
        if let toAddress =  object["to"] as? String {
            self.toAddress = toAddress
        } else {
            self.toAddress = ""
        }
        
        if let gas =  object["gas"] as? String {
            self.gasLimit = BigUInt(gas.dropFirst(2), radix: 16)!
        } else {
            self.gasLimit = BigUInt("\(2_000_000)")!
        }
        
        if let gasPriceString =  object["gasPrice"] as? String {
            self.gasPrice = BigUInt(gasPriceString.dropFirst(2), radix: 16)!
        } else {
            self.gasPrice = BigUInt("\(5_000_000_000)")!
        }
        
        if let nonceString =  object["nonce"] as? String {
            self.nonce = Int(nonceString.dropFirst(2), radix: 16)!
        } else {
            self.nonce = 0
        }
        
        self.id = id
        
        //amount
        if let valueString =     object["value"] as? String {
            if let value = BigUInt(valueString.dropFirst(2), radix: 16) {
                self.value = value.description
            } else {
                self.value = "0"
            }
        } else {
            self.value = "0"
        }
    }
}
