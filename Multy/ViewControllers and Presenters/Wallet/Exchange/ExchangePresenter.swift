//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import UIKit

class ExchangePresenter: NSObject {
    
    var exchangeVC: ExchangeViewController?
    var walletFromSending: UserWalletRLM? {
        didSet {
            updateUI()
        }
    }

    
    func updateUI() {
        exchangeVC?.sendingImg.image = UIImage(named: walletFromSending!.blockchainType.iconString)
        exchangeVC?.sendingMaxBtn.setTitle("MAX \(walletFromSending!.availableAmountString)", for: .normal)
        exchangeVC?.summarySendingImg.image = exchangeVC?.sendingImg.image
    }
    
    
    //text field section
    
    func checkIsFiatTf(textField: UITextField) -> Bool {
        if textField == exchangeVC?.sendingFiatValueTF || textField == exchangeVC?.receiveFiatValueTF {
            return true
        } else {
            return false
        }
    }
    
    func maxSymblosAfterDelimiter(textField: UITextField) -> Int {
        if checkIsFiatTf(textField: textField) {
            return 2
        } else {
            return 8
        }
    }
    
    func checkNumberOfSymbolsAfterDelimeter(textField: UITextField) -> Bool {
        let delimeter = textField.text!.contains(",") ? "," : "."
        let strAfterDot: [String?] = textField.text!.components(separatedBy: delimeter)
        if checkIsFiatTf(textField: textField) {
            return strAfterDot[1]!.count == 2 ? false : true
        } else {
            return strAfterDot[1]!.count == 8 ? false : true
        }
    }
    
//    func maxAllowedToSpend(stringWithEnteredNumber: String) -> Bool {
//        BigInt(stringWithEnteredNumber, <#T##blockchain: Blockchain##Blockchain#>)
//
//        walletFromSending?.availableAmount
//    }
    
        //Delete section
    func deleteEnteredIn(textField: UITextField) -> Bool {
//        makeSendFiat(enteredNumber: "")
        if checkIsFiatTf(textField: textField) {
            if textField.text == "$ " {             // "$ " default value in fiat tf
                return false
            } else if textField.text == "$ 0," || textField.text == "$ 0." {
                textField.text = "$ "
                return false
            }
        }
        
        if textField.text == "0," || textField.text == "0." {
            textField.text?.removeAll()
            return false
        }
        
        return true
    }
        // -------- done -------- //
        // Delimeter Section
    func delimiterEnteredIn(textField: UITextField) -> Bool {
        // if text contains delimeter than return false
        if textField.text!.contains(",") || textField.text!.contains(".") {
            return false
        }
        
        //if text is empty return 0.
        if checkIsFiatTf(textField: textField) && textField.text == "$ " {
            textField.text = "$ 0."
            return false
        } else if textField.text!.isEmpty {
            textField.text = "0."
            return false
        }
        
        return true
    }
        // -------- done -------- //
        //Value section
    func numberEnteredIn(textField: UITextField) -> Bool {
//        makeSendFiat(enteredNumber: enteredNumber)
        var textInTfWithOneMoreSymbol = textField.text!.replacingOccurrences(of: "$ ", with: "") + " "  //remove "$ " for fiat TF
        textInTfWithOneMoreSymbol = textInTfWithOneMoreSymbol.replacingOccurrences(of: ".", with: "")
        if textInTfWithOneMoreSymbol.count > 12 {
            return false
        }
        if textField.text!.contains(",") || textField.text!.contains(".") {
            return checkNumberOfSymbolsAfterDelimeter(textField: textField)
        }
        
        return true
    }
        // -------- done -------- //
    
    func makeSendFiatTfValue() {
        let str: String = exchangeVC!.sendingCryptoValueTF.text!
        exchangeVC!.sendingFiatValueTF.text = "$ " + str.fiatValueString(for: walletFromSending!.blockchainType)
    }
    
    func makeSendCryptoTfValue() {
        let valueFromTF = exchangeVC!.sendingFiatValueTF.text!.replacingOccurrences(of: "$ ", with: "")
        let sumInFiat = walletFromSending!.blockchain.multiplyerToMinimalUnits * Double(valueFromTF.stringWithDot)
        let endCryptoString = sumInFiat / walletFromSending?.exchangeCourse
        if valueFromTF.isEmpty {
            exchangeVC!.sendingCryptoValueTF.text = "0.0"
        } else {
            exchangeVC!.sendingCryptoValueTF.text = endCryptoString.cryptoValueString(for: walletFromSending!.blockchain)
        }
    }
}
