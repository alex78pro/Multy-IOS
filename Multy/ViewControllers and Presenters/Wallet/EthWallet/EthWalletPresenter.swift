//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import UIKit

class EthWalletPresenter: NSObject {
    var mainVC : EthWalletViewController?
    
    var topCellHeight = CGFloat(0)
    
    var isTherePendingAmount = false
    var wallet : UserWalletRLM? {
        didSet {
            isTherePendingAmount = wallet!.ethWallet?.pendingWeiAmountString != "0"
            mainVC?.titleLbl.text = self.wallet?.name
            mainVC?.collectionView.reloadData()
            if isUpdateBySocket != nil && isUpdateBySocket == true {
                mainVC?.makeConstantsForAnimation()
            }
        }
    }
    var account : AccountRLM?
    var isUpdateBySocket: Bool?
    
    var isThereAvailableAmount: Bool {
        get {
            return wallet!.ethWallet!.balance != "0"
        }
    }
    
    var historyArray = [HistoryRLM]() {
        didSet {
            reloadTableView()
        }
    }
    
    func reloadTableView() {
        if historyArray.count > 0 {
            mainVC?.hideEmptyLbls()
        }
        
        let contentOffset = mainVC!.tableView.contentOffset
        mainVC!.tableView.reloadData()
        mainVC!.tableView.layoutIfNeeded()
        mainVC!.tableView.setContentOffset(contentOffset, animated: false)
        
        self.mainVC!.refreshControl.endRefreshing()
    }
    
    func registerCells() {
        let walletHeaderCell = UINib.init(nibName: "EthWalletHeaderTableViewCell", bundle: nil)
        self.mainVC?.tableView.register(walletHeaderCell, forCellReuseIdentifier: "EthWalletHeaderCellID")
        
        //        let walletCollectionCell = UINib.init(nibName: "MainWalletCollectionViewCell", bundle: nil)
        //        self.mainVC?.tableView.register(walletCollectionCell, forCellReuseIdentifier: "WalletCollectionViewCellID")
        
        let transactionCell = UINib.init(nibName: "TransactionWalletCell", bundle: nil)
        self.mainVC?.tableView.register(transactionCell, forCellReuseIdentifier: "TransactionWalletCellID")
        
        let transactionPendingCell = UINib.init(nibName: "TransactionPendingCell", bundle: nil)
        self.mainVC?.tableView.register(transactionPendingCell, forCellReuseIdentifier: "TransactionPendingCellID")
        
        let headerCollectionCell = UINib.init(nibName: "EthWalletHeaderCollectionViewCell", bundle: nil)
        self.mainVC?.collectionView.register(headerCollectionCell, forCellWithReuseIdentifier: "MainWalletCollectionViewCellID")
    }
    
    func fixConstraints() {
        if #available(iOS 11.0, *) {
            //OK: Storyboard was made for iOS 11
        } else {
            self.mainVC?.tableViewTopConstraint.constant = 0
        }
    }
    
    func numberOfTransactions() -> Int {
        return self.historyArray.count
    }
    
    func isTherePendingMoney(for indexPath: IndexPath) -> Bool {
        let transaction = historyArray[indexPath.row]
        
        return transaction.txStatus.intValue == TxStatus.MempoolIncoming.rawValue
    }
    
    
    
    func getNumberOfPendingTransactions() -> Int {
        var count = 0
        
        for transaction in historyArray {
            if wallet!.blockedAmount(for: transaction) > 0 {
                count += 1
            }
        }
        
        return count
    }
    
    
    func blockUI() {
        self.mainVC?.spiner.startAnimating()
        
//        self.mainVC?.view.isUserInteractionEnabled = false
//        mainVC?.loader.show(customTitle: "Updating")

    }
    
    func unlockUI() {
        self.mainVC?.spiner.stopAnimating()
        self.mainVC?.spiner.isHidden = true
//        self.mainVC?.view.isUserInteractionEnabled = true
//        self.mainVC?.loader.hide()
    }
    
    func getHistoryAndWallet() {
//        blockUI()
        DataManager.shared.getOneWalletVerbose(wallet: wallet!) { [unowned self] (updatedWallet, error) in
            if updatedWallet != nil {
                self.wallet = updatedWallet
            }
            DataManager.shared.getTransactionHistory(wallet: self.wallet!) { [unowned self] (histList, err) in
                //            self.unlockUI()
                self.mainVC?.spiner.stopAnimating()
                if err == nil && histList != nil {
                    //                self.mainVC!.refreshControl.endRefreshing()
                    //                self.mainVC!.tableView.isUserInteractionEnabled = true
                    //                self.mainVC!.tableView.contentOffset.y = 0
                    //                self.mainVC!.tableView.contentOffset =
                    self.historyArray = histList!.sorted(by: {
                        let firstDate = $0.mempoolTime.timeIntervalSince1970 == 0 ? $0.blockTime : $0.mempoolTime
                        let secondDate = $1.mempoolTime.timeIntervalSince1970 == 0 ? $1.blockTime : $1.mempoolTime
                        
                        return firstDate > secondDate
                    })
                    self.mainVC!.isSocketInitiateUpdating = false
                }
            }
        }
    }
}
