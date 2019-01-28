//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import Foundation
import RealmSwift
import Alamofire
//import MultyCoreLibrary
typealias HistoryDataManager = DataManager

extension DataManager {
    
    func getServerConfig(completion: @escaping(_ hardVersion: Int?,_ softVersion: Int?,_ error: Error?) -> ()) {
        apiManager.getServerConfig { [unowned self] (answerDict, err) in
            switch err {
            case nil:
                var apiVersion: NSString?
                var hardVersion: Int?
                var softVersion: Int?
                var serverTime: NSDate?
                
                let userDefaults = UserDefaults.standard
                
                
                if answerDict!["api"] != nil {
                    apiVersion = (answerDict!["api"] as? NSString)
                    userDefaults.set(apiVersion, forKey: Constants.UserDefaults.apiVersionKey)
                }
                
                if answerDict!["ios"] != nil {
                    let iosDict = answerDict!["ios"] as! NSDictionary
                    hardVersion = iosDict["hard"] as? Int
                    softVersion = iosDict["soft"] as? Int
                    
                    userDefaults.set(hardVersion, forKey: Constants.UserDefaults.hardVersionKey)
                    userDefaults.set(softVersion, forKey: Constants.UserDefaults.softVersionKey)
                }
                
                if answerDict!["servertime"] != nil {
                    let timestamp = answerDict!["servertime"] as! TimeInterval
                    serverTime = NSDate(timeIntervalSince1970: timestamp)
                    
                    userDefaults.set(serverTime, forKey: Constants.UserDefaults.serverTimeKey)
                }
                
                if answerDict!["stockexchanges"] != nil {
                    let stocksDict = answerDict!["stockexchanges"] as! NSDictionary
                    let stocks = StockExchanges(dictWithStocks: stocksDict)
                    
                    let encodedData = NSKeyedArchiver.archivedData(withRootObject: stocks.stocks)
                    userDefaults.set(encodedData, forKey: Constants.UserDefaults.stocksKey)
                }
                
                if let donateInfo = answerDict!["donate"] as? NSArray {
                    var donateFeatureAndAddressDict = Dictionary<Int, String>()
                    
                    for donateEntity in donateInfo {
                        let donateEntityDict = donateEntity as! NSDictionary
                        
                        if let featureCode = donateEntityDict["FeatureCode"] as? Int, let donationAddress = donateEntityDict["DonationAddress"] as? String {
                            donateFeatureAndAddressDict[featureCode] = donationAddress
                        }
                    }
                    
                    let encodedData = NSKeyedArchiver.archivedData(withRootObject: donateFeatureAndAddressDict)
                    
                    self.btcMainNetDonationAddress = donateFeatureAndAddressDict[donationWithTransaction]!
                    userDefaults.set(encodedData, forKey: Constants.UserDefaults.btcDonationAddressesKey)
                }
                
                if let erc20Info = answerDict!["erc20tokenlist"] as? NSArray {
                    let tokens = TokenRLM.initArrayWithArray(tokensArray: erc20Info, blockchainType: BlockchainType(blockchain: BLOCKCHAIN_ERC20, net_type: 1))
                    DataManager.shared.realmManager.updateErc20Tokens(tokens: tokens)
                }
                
                if let multisigFactoriesInfo = answerDict!["multisigfactory"] as? Dictionary<String,  String> {
                    self.saveMultisigFactories(multisigFactoriesInfo)
                }
                
                if let browserDefaults = answerDict!["browserdefault"] as? NSDictionary {
                    let currencyID = browserDefaults["currencyid"] as! Int
                    userDefaults.set(currencyID, forKey: "browserCurrencyID")
                    
                    let networkID = browserDefaults["networkid"] as! Int
                    userDefaults.set(networkID, forKey: "browserNetworkID")
                    
                    let browserURL = browserDefaults["url"] as! String
                    userDefaults.set(browserURL, forKey: "browserDefURL")
                }
                
                userDefaults.synchronize()
                
                completion(hardVersion, softVersion, nil)
                break
            default:
                //do it something
                completion(nil, nil, err)
                break
            }
        }
    }
    
    func restoreMetamaskWallets(seedPhrase: String, completion: @escaping(_ isSucces: Bool?) -> ()) {
        let info = metamaskWalletsInfoForRestore(seedPhrase: seedPhrase, isMainnet: true)
        let info2 = metamaskWalletsInfoForRestore(seedPhrase: seedPhrase, isMainnet: false)
        
        apiManager.restoreMemamaskWallets(walletsInfo: info) { [unowned self] in
            if $0 {
                self.apiManager.restoreMemamaskWallets(walletsInfo: info2) {
                    completion($0)
                }
            } else {
                completion(false)
            }
        }
    }
    
    func appVersion() -> String {
        return ((infoPlist["CFBundleShortVersionString"] as! String) + (infoPlist["CFBundleVersion"] as! String))
    }
    
    func auth(rootKey: String?, completion: @escaping (_ account: AccountRLM?,_ error: Error?) -> ()) {
        realmManager.getRealm { (realmOpt, error) in
            if let realm = realmOpt {
                let account = realm.object(ofType: AccountRLM.self, forPrimaryKey: 1)
                
                var params : Parameters = [ : ]
                
                if account != nil {
                    params["userID"] = account?.userID
                    params["deviceID"] = account?.deviceID
                    params["deviceType"] = account?.deviceType
                    params["pushToken"] = ApiManager.shared.pushToken
                    params["appVersion"] = self.appVersion()
                    
                    self.apiManager.userID = account!.userID
                } else {
                    //MARK: names
                    var paramsDict = NSMutableDictionary()
                    
                    params["deviceID"] = "iOS \(UIDevice.current.name)"
                    params["deviceType"] = 1
                    params["pushToken"] = ApiManager.shared.pushToken
                    params["appVersion"] = self.appVersion()
                    
                    
                    if rootKey == nil {
                        let seedPhraseString = self.coreLibManager.createMnemonicPhraseArray().joined(separator: " ")
                        params["userID"] = self.getRootString(from: seedPhraseString).0
                        
                        paramsDict = NSMutableDictionary(dictionary: params)
                        
                        paramsDict["seedPhrase"] = seedPhraseString
                        paramsDict["binaryData"] = self.coreLibManager.createSeedBinaryData(from: seedPhraseString)?.convertToHexString()
                    } else {
                        params["userID"] = self.getRootString(from: rootKey!).0
                        
                        paramsDict = NSMutableDictionary(dictionary: params)
                        
                        let hexBinData = self.coreLibManager.createSeedBinaryData(from: rootKey!)?.convertToHexString()
                        paramsDict["binaryData"] = hexBinData
                        paramsDict["backupSeedPhrase"] = rootKey
                        
                        if isDebug {
                            print(paramsDict)
                        }
                    }
                    
                    self.apiManager.userID = params["userID"] as! String
                    self.updateAccount(paramsDict, completion: { (account, error) in
                        
                    })
                }
                
                guard let _ =  params["userID"] as? String else {
                    fatalError("userID should not be empty")
                }
                
                self.apiManager.auth(with: params, completion: { (dict, error) in
                    if dict != nil {
                        self.updateAccount(dict!, completion: { (account, error) in
                            UserDefaults.standard.set(false, forKey: "isFirstLaunch")
                            completion(account, error)
                        })
                    } else {
                        completion(nil, nil)
                    }
                })
            } else {
                print("Error fetching realm:\(#function)")
                completion(nil, nil)
            }
        }
    }
    
    func importWallet(params: Parameters, completion: @escaping (_ answer: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.importWallet(params) { (responceDict, error) in
            completion(responceDict, error)
        }
    }
    
    func addWallet(params: Parameters, completion: @escaping (_ answer: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.addWallet(params) { (responceDict, error) in
            completion(responceDict, error)
        }
    }
    
    func addAddress(params: Parameters, completion: @escaping (_ dict: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.addAddress(params) { (dict, error) in
            completion(dict, error)
        }
    }
    
    func getFeeRate(currencyID: UInt32, networkID: UInt32, ethAddress: String?, completion: @escaping (_ feeRateDict: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.getFeeRate(currencyID: currencyID, networkID: networkID, ethAddress: ethAddress) { (answer, error) in
            if error != nil || (answer!["code"] as! NSNumber).intValue != 200  {
                completion(nil, error)
            } else {
//                completion(answer!["speeds"] as? NSDictionary, nil)
                completion(answer, nil)
            }
        }
    }
    
    func getWalletsVerbose(completion: @escaping (_ walletsArr: NSArray?,_ error: Error?) -> ()) {
        apiManager.getWalletsVerbose() { [unowned self] (answer, err) in
            if err == nil {
                let dict = NSMutableDictionary()
                dict["topindexes"] = answer!["topindexes"]
                
                self.updateAccount(dict, completion: { (_, _) in })
                
                if (answer?["code"] as? NSNumber)?.intValue == 200 {
                    print("getWalletsVerbose:\n \(answer ?? ["":""])")
                    if answer!["wallets"] is NSNull {
                        completion(NSArray(), nil)
                        
                        return
                    }
                    let walletsArrayFromApi = answer!["wallets"] as! NSArray
//                    let walletsArr = UserWalletRLM.initWithArray(walletsInfo: walletsArrayFromApi)
                    completion(walletsArrayFromApi, nil)
                } else {
                    //MARK: delete
                    if answer!["wallets"] is NSNull || answer!["wallets"] == nil {
                        completion(nil, NSError(domain: "Error", code: 404, userInfo: nil))
                        
                        return
                    } else if answer!["wallets"] == nil {
                        completion(nil, NSError(domain: "Error", code: 404, userInfo: nil))
                        
                        return
                    }
                    
                    let walletsArrayFromApi = answer!["wallets"] as! NSArray
                    completion(walletsArrayFromApi, nil)
                }
            } else {
                completion(nil, err)
            }
        }
    }
    
    func getOneWalletVerbose(wallet: UserWalletRLM, completion: @escaping (_ answer: UserWalletRLM?,_ error: Error?) -> ()) {
        if wallet.isImported {
            getOneImportedWalletVerbose(walletAddress: wallet.address, blockchain: wallet.blockchainType, completion: completion)
        } else if wallet.isMultiSig {
            getOneMultisigWalletVerbose(inviteCode: wallet.multisigWallet!.inviteCode, blockchain: wallet.blockchainType, completion: completion)
        } else {
            getOneCreatedWalletVerbose(walletID: wallet.walletID, blockchain: wallet.blockchainType, completion: completion)
        }
    }
    
    private func getOneCreatedWalletVerbose(walletID: NSNumber, blockchain: BlockchainType, completion: @escaping (_ answer: UserWalletRLM?,_ error: Error?) -> ()) {
        apiManager.getOneCreatedWalletVerbose(walletID: walletID, blockchain: blockchain) { (dict, error) in
            if dict != nil && dict!["wallet"] != nil && !(dict!["wallet"] is NSNull) {
                let wallet = UserWalletRLM.initWithInfo(walletInfo: (dict!["wallet"] as! NSArray)[0] as! NSDictionary)
//                let addressesInfo = ((dict!["wallet"] as! NSArray)[0] as! NSDictionary)["addresses"]!
                
//                let addresses = AddressRLM.initWithArray(addressesInfo: addressesInfo as! NSArray)
                UserWalletRLM.checkMissingTokens(array: [wallet])
                completion(wallet, nil)
            } else {
                completion(nil, error)
            }
            
            print("getOneWalletVerbose:\n\(dict)")
        }
    }
    
    private func getOneMultisigWalletVerbose(inviteCode: String, blockchain: BlockchainType, completion: @escaping (_ answer: UserWalletRLM?,_ error: Error?) -> ()) {
        apiManager.getOneMultisigWalletVerbose(inviteCode: inviteCode, blockchain: blockchain) { (dict, error) in
            if dict != nil && dict!["wallet"] != nil && !(dict!["wallet"] is NSNull) {
                let wallet = UserWalletRLM.initWithInfo(walletInfo: (dict!["wallet"] as! NSArray)[0] as! NSDictionary)
                //                let addressesInfo = ((dict!["wallet"] as! NSArray)[0] as! NSDictionary)["addresses"]!
                
                //                let addresses = AddressRLM.initWithArray(addressesInfo: addressesInfo as! NSArray)
                UserWalletRLM.checkMissingTokens(array: [wallet])
                completion(wallet, nil)
            } else {
                completion(nil, error)
            }
            
            print("getOneMultisigWalletVerbose:\n\(dict)")
        }
    }
    
    private func getOneImportedWalletVerbose(walletAddress: String, blockchain: BlockchainType, completion: @escaping (_ answer: UserWalletRLM?,_ error: Error?) -> ()) {
        apiManager.getOneImportedWalletVerbose(address: walletAddress, blockchain: blockchain) { (dict, error) in
            if dict != nil && dict!["wallet"] != nil && !(dict!["wallet"] is NSNull) {
                let wallet = UserWalletRLM.initWithInfo(walletInfo: (dict!["wallet"] as! NSArray)[0] as! NSDictionary)
                //                let addressesInfo = ((dict!["wallet"] as! NSArray)[0] as! NSDictionary)["addresses"]!
                
                //                let addresses = AddressRLM.initWithArray(addressesInfo: addressesInfo as! NSArray)
                UserWalletRLM.checkMissingTokens(array: [wallet])
                completion(wallet, nil)
            } else {
                completion(nil, error)
            }
            
            print("getOneImportedWalletVerbose:\n\(dict)")
        }
    }
    
    func getWalletOutputs(currencyID: UInt32, address: String, completion: @escaping (_ answer: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.getWalletOutputs(currencyID: currencyID, address: address) { (dict, error) in
            completion(dict, error)
        }
    }
    
    func changeWalletName(_ wallet: UserWalletRLM, newName: String, completion: @escaping(_ answer: NSDictionary?,_ error: Error?) -> ()) {
        if wallet.isImported {
            changeImportedWalletName(currencyID: wallet.chain, chainType: wallet.chainType, address: wallet.address, newName: newName, completion: completion)
        } else {
            changeCreatedWalletName(currencyID: wallet.chain, chainType: wallet.chainType, walletID: wallet.walletID, newName: newName, completion: completion)
        }
    }
    
    private func changeCreatedWalletName(currencyID: NSNumber, chainType: NSNumber, walletID: NSNumber, newName: String, completion: @escaping(_ answer: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.changeCreatedWalletName(currencyID: currencyID, chainType: chainType, walletID: walletID, newName: newName) { (answer, error) in
            if error == nil {

                completion(answer!, nil)
            } else {
                completion(nil, error)
            }
        }
    }
    
    private func changeImportedWalletName(currencyID: NSNumber, chainType: NSNumber, address: String, newName: String, completion: @escaping(_ answer: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.changeImportedWalletName(currencyID: currencyID, chainType: chainType, address: address, newName: newName) { (answer, error) in
            if error == nil {
                completion(answer!, nil)
            } else {
                completion(nil, error)
            }
        }
    }
    
    func sendHDTransaction(transactionParameters: Parameters, completion: @escaping (_ answer: NSDictionary?,_ error: Error?) -> ()) {
        apiManager.sendHDTransaction(transactionParameters: transactionParameters) { (answer, error) in
            if error != nil {
                //send analytics err
                
                completion(nil, error)
            }
            completion(answer, error)
        }
    }
    
    func getTransactionInfo(wallet: UserWalletRLM, transactionHash: String, completion: @escaping (_ answer: HistoryRLM?,_ error: Error?) -> ()) {
        apiManager.getTransactionInfo(wallet: wallet, transactionHash: transactionHash) { (answer, error) in
            completion(answer, error)
        }
    }
    
    func estimation(for mustisigAddress: String, completion: @escaping(Result<NSDictionary, String>) -> ()) {
        apiManager.estimation(for: mustisigAddress) { completion($0) }
    }
    
    func resyncWallet(_ wallet: UserWalletRLM, completion: @escaping(Result<NSDictionary, String>) -> ()) {
        if wallet.isImported {
            apiManager.resyncImportedWallet(currencyID: wallet.chain, chainType: wallet.chainType, address: wallet.address, completion: completion)
        } else {
            apiManager.resyncCreatedWallet(currencyID: wallet.chain, chainType: wallet.chainType, walletID: wallet.walletID, completion: completion)
        }
    }
    
    func deleteWallet(_ wallet: UserWalletRLM, completion: @escaping(Result<NSDictionary, String>) -> ()) {
        if wallet.isImported {
            apiManager.deleteImportedWallet(currencyID: wallet.chain, networkID: wallet.chainType, address: wallet.address, completion: completion)
        } else {
            apiManager.deleteCreatedWallet(currencyID: wallet.chain, networkID: wallet.chainType, walletIndex: wallet.walletID, completion: completion)
        }
    }
    
    func convertToBroken(currencyID: NSNumber, networkID: NSNumber, walletID: NSNumber, completion: @escaping(Result<NSDictionary, String>) -> ()) {
        apiManager.convertToBroken(currencyID: currencyID, networkID: networkID, walletID: walletID) {
            completion($0)
        }
    }
    
    func convertToBroken(_ addresses: [String], completion: @escaping(Result<NSDictionary, String>) -> ()) {
        if addresses.isEmpty == false {
            apiManager.convertToBroken(addresses) {
                completion($0)
            }
        }
    }
}

//MARK: -
//MARK: -
extension HistoryDataManager {
    func getTransactionHistory(wallet: UserWalletRLM, completion: @escaping(_ historyArr: List<HistoryRLM>?,_ error: Error?) ->()) {
        if wallet.isImported {
            getImportedWalletTransactionHistory(wallet: wallet, completion: completion)
        } else if wallet.isMultiSig {
            getMultisigWalletTransactionHistory(wallet: wallet, completion: completion)
        } else {
            getCreatedWalletTransactionHistory(wallet: wallet, completion: completion)
        }
    }
    
    private func getCreatedWalletTransactionHistory(wallet: UserWalletRLM, completion: @escaping(_ historyArr: List<HistoryRLM>?, _ error: Error?) ->()) {
        apiManager.getCreatedWalletTransactionHistory(currencyID: wallet.chain, networkID: wallet.chainType, walletID: wallet.walletID) { [unowned self] (answer, err) in
            self.parseHistoryResponse(wallet: wallet, answer: answer, error: err, completion: completion)
        }
    }
    
    private func getMultisigWalletTransactionHistory(wallet: UserWalletRLM, completion: @escaping(_ historyArr: List<HistoryRLM>?,_ error: Error?) ->()) {
        apiManager.getMultisigWalletTransactionHistory(currencyID: wallet.chain, networkID: wallet.chainType, address: wallet.address) { (answer, err) in
            self.parseHistoryResponse(wallet: wallet, answer: answer, error: err, completion: completion)
        }
    }
    
    private func getImportedWalletTransactionHistory(wallet: UserWalletRLM, completion: @escaping(_ historyArr: List<HistoryRLM>?,_ error: Error?) ->()) {
        apiManager.getImportedWalletTransactionHistory(currencyID: wallet.chain, networkID: wallet.chainType, address: wallet.address) { (answer, err) in
            self.parseHistoryResponse(wallet: wallet, answer: answer, error: err, completion: completion)
        }
    }
    
    private func parseHistoryResponse(wallet: UserWalletRLM, answer: NSDictionary?, error: Error?, completion: @escaping(_ historyArr: List<HistoryRLM>?,_ error: Error?) ->()) {
        switch error {
        case nil:
            if let response = answer, let code = response["code"] as? Int, code == 200 {
                if response["history"] is NSNull || (response["history"] as? NSArray)?.count == 0 {
                    //history empty
                    completion(nil, nil)
                    return
                }
                if response["history"] as? NSArray != nil {
                    let historyArr = response["history"] as! NSArray
                    print("getTransactionHistory:\n\(historyArr)")
                    let initializedArr = HistoryRLM.initWithArray(historyArr: historyArr, for: wallet.id)
                    
                    self.realmManager.update(objects: initializedArr)
                    
                    let list = List<HistoryRLM>()
                    initializedArr.forEach{ list.append($0) }
                    completion(list, nil)
                }
            }
        default:
            completion(nil, error)
            break
        }
    }
}
