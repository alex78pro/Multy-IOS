//
//  SendPresenter.swift
//  Multy
//
//  Created by Artyom Alekseev on 15.05.2018.
//  Copyright © 2018 Idealnaya rabota. All rights reserved.
//

import UIKit
import RealmSwift

class SendPresenter: NSObject {
    var sendVC : SendViewController?
    
    var walletsArr = Array<UserWalletRLM>()
    var selectedWalletIndex : Int? {
        didSet {
            if selectedWalletIndex != oldValue {
                self.createTransaction()
                
                self.sendVC?.updateUI()
            }
        }
    }
    
    var activeRequestsArr = [PaymentRequest]()
    var selectedActiveRequestIndex : Int? {
        didSet {
            if selectedActiveRequestIndex != oldValue {
                self.createTransaction()
                
                self.sendVC?.updateUI()
            }
        }
    }
    
    var isSendingAvailable : Bool {
        get {
            var result = false
            if selectedActiveRequestIndex != nil && selectedWalletIndex != nil {
//                let activeRequest = activeRequestsArr[selectedActiveRequestIndex!]
//                let wallet = walletsArr[selectedWalletIndex!]
                //FIXME:
                result = true
//                if wallet.sumInCrypto >= activeRequest.sendAmount.doubleValue {
//                    result = true
//                }
            }
            return result
        }
    }
    
    var newUserCodes = [String]()
    
    var transaction : TransactionDTO?
    
    var receiveActiveRequestTimer = Timer()
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.didDiscoverNewAd(notification:)), name: Notification.Name(didDiscoverNewAdvertisementNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didChangedBluetoothReachability(notification:)), name: Notification.Name(bluetoothReachabilityChangedNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveNewRequests(notification:)), name: Notification.Name("newReceiver"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveSendResponse(notification:)), name: Notification.Name("sendResponse"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(didDiscoverNewAdvertisementNotificationName), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(bluetoothReachabilityChangedNotificationName), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("newReceiver"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("sendResponse"), object: nil)
    }
    
    func viewControllerViewDidLoad() {
        handleBluetoothReachability()
    }
    
    func numberOfWallets() -> Int {
        return self.walletsArr.count
    }
    
    func numberOfActiveRequests() -> Int {
        return self.activeRequestsArr.count
    }
    
    func getWallets() {
        DataManager.shared.getAccount { (acc, err) in
            if err == nil {
                // MARK: check this
                self.walletsArr = acc!.wallets.sorted(by: { $0.availableSumInCrypto > $1.availableSumInCrypto })
                if self.walletsArr.count > 0 {
                    self.selectedWalletIndex = 0
                }
                self.sendVC?.updateUI()
            }
        }
    }
    
    private func createTransaction() {
        if isSendingAvailable {
            transaction = TransactionDTO()
            let request = activeRequestsArr[selectedActiveRequestIndex!]
            //FIXME:
            transaction!.sendAmount = request.sendAmount.doubleValue
            transaction!.sendAddress = request.sendAddress
            transaction!.choosenWallet = walletsArr[selectedWalletIndex!]
            sendVC?.fillTransaction()
        }
    }
    
    @objc private func didDiscoverNewAd(notification: Notification) {
        DispatchQueue.main.async {
            let newAdOriginID = notification.userInfo!["originID"] as! UUID
            if BLEManager.shared.receivedAds != nil {
                var newAd : Advertisement?
                for ad in BLEManager.shared.receivedAds! {
                    if ad.originID == newAdOriginID {
                        newAd = ad
                        print("Discovered new usercode \(ad.userCode)")
                        break
                    }
                }
                
                if newAd != nil {
                    self.newUserCodes.append(newAd!.userCode)
                }
            }
        }
    }
    
    func becomeSenderForUsersWithCodes(_ userCodes : [String]) {
        DataManager.shared.socketManager.becomeSender(nearIDs: userCodes)
    }
        
    func handleBluetoothReachability() {
        switch BLEManager.shared.reachability {
        case .reachable, .unknown:
            self.sendVC?.updateUIForBluetoothState(true)
            if BLEManager.shared.reachability == .reachable {
                self.startSearchingActiveRequests()
            }
            
            break
            
        case .notReachable:
            self.sendVC?.updateUIForBluetoothState(false)
            
            break
            
        }
    }
    
    func addActivePaymentRequests(requests: [PaymentRequest]) {
        activeRequestsArr.append(contentsOf: requests)
        if numberOfActiveRequests() > 0 && selectedActiveRequestIndex == nil {
            selectedActiveRequestIndex = 0
        }
        
        sendVC?.updateUI()
    }
    
    func send() {
        DataManager.shared.getAccount { (account, error) in
            let request = self.activeRequestsArr[self.selectedActiveRequestIndex!]
            let jwt = account!.token
            DataManager.shared.socketManager.txSend(userCode: request.userCode, currencyID: request.currencyID, networkID: request.networkID, jwt: jwt, payload: "")
        }
    }
    
    @objc private func didChangedBluetoothReachability(notification: Notification) {
        DispatchQueue.main.async {
            self.handleBluetoothReachability()
        }
    }
    
    @objc private func didReceiveNewRequests(notification: Notification) {
        DispatchQueue.main.async {
            var requests = notification.userInfo!["paymentRequests"] as! [PaymentRequest]
            
            var newRequests = [PaymentRequest]()
            while requests.count > 0 {
                let request = requests.first!
                
                var isRequestOld = false
                for oldRequest in self.activeRequestsArr {
                    if oldRequest.userCode == request.userCode {
                        isRequestOld = true
                        break
                    }
                }
                
                if !isRequestOld {
                    newRequests.append(request)
                }
                
                requests.removeFirst()
            }
            
            if newRequests.count > 0 {
                self.addActivePaymentRequests(requests: newRequests)
            }
        }
    }
    
    @objc private func didReceiveSendResponse(notification: Notification) {
        DispatchQueue.main.async {
            let success = notification.userInfo!["data"] as! Bool
            
            if success {
                self.activeRequestsArr[self.selectedActiveRequestIndex!].satisfied = true
            }
            
            self.sendVC?.updateUIWithSendResponse(success: success)
        }
    }
    
    //TODO: remove after searching via bluetooth will implemented
    func startSearchingActiveRequests() {
        BLEManager.shared.startScan()
        receiveActiveRequestTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkNewUserCodes), userInfo: nil, repeats: true)
    }
    
    @objc func checkNewUserCodes() {
//        let request = PaymentRequest.init(sendAddress: randomRequestAddress(), currencyID: randomCurrencyID(), sendAmount: randomAmount(), color: randomColor())
//
//        activeRequestsArr.append(request)
//        if numberOfActiveRequests() == 1 {
//            selectedActiveRequestIndex = 0
//        }
//
//        sendVC?.updateUI()
        
        if newUserCodes.count > 0 {
            becomeSenderForUsersWithCodes(newUserCodes)
            newUserCodes.removeAll()
        }
    }
    
    func randomRequestAddress() -> String {
        var result = "0x"
        result.append(randomString(length: 34))
        return result
    }
    
    func randomString(length:Int) -> String {
        let charSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var c = charSet.characters.map { String($0) }
        var s:String = ""
        for _ in (1...length) {
            s.append(c[Int(arc4random()) % c.count])
        }
        return s
    }
    
    func randomAmount() -> Double {
        return Double(arc4random())/Double(UInt32.max)
    }
    
    func randomCurrencyID() -> NSNumber {
        return NSNumber.init(value: 0)
    }
    
    func randomColor() -> UIColor {
        return UIColor(red:   CGFloat(arc4random()) / CGFloat(UInt32.max),
                       green: CGFloat(arc4random()) / CGFloat(UInt32.max),
                       blue:  CGFloat(arc4random()) / CGFloat(UInt32.max),
                       alpha: 1.0)
    }
}
