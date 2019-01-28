//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import Foundation
import RealmSwift

class AccountRLM: Object {
    @objc dynamic var seedPhrase = String() {
        didSet {
            if seedPhrase != "" {
                self.backupSeedPhrase = seedPhrase
            }
        }
    }
    @objc dynamic var backupSeedPhrase = String()
    @objc dynamic var binaryDataString = String()
    
    @objc dynamic var userID = String()
    @objc dynamic var deviceID = String()
    @objc dynamic var deviceType = 1
    @objc dynamic var pushToken = String()
    
    @objc dynamic var expireDateString = String()
    @objc dynamic var token = String()
    @objc dynamic var id: NSNumber = 1
    @objc dynamic var accountTypeID: NSNumber = 0
    
    var topIndexes = List<TopIndexRLM>()
    
//    var wallets = List<UserWalletRLM>()
    
    func isSeedPhraseSaved() -> Bool {
        return seedPhrase == ""
    }

    
    override class func primaryKey() -> String? {
        return "id"
    }
    
    var accountType: AccountType {
//        return AccountType(typeID: accountTypeID.intValue)
        return AccountType(wordsCount: backupSeedPhrase.split(separator: " ").count)
    }
}
