//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import UIKit
import StoreKit
import SwiftyStoreKit

private let swizzling: (AnyClass, Selector, Selector) -> () = { forClass, originalSelector, swizzledSelector in
    let originalMethod = class_getInstanceMethod(forClass, originalSelector)
    let swizzledMethod = class_getInstanceMethod(forClass, swizzledSelector)
//    method_exchangeImplementations(originalMethod!, swizzledMethod!)
    let flag = class_addMethod(UIViewController.self, originalSelector, method_getImplementation(swizzledMethod!), method_getTypeEncoding(swizzledMethod!))
    if flag {
        class_replaceMethod(UIViewController.self,
                            swizzledSelector,
                            method_getImplementation(swizzledMethod!),
                            method_getTypeEncoding(swizzledMethod!))
    } else {
        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }
}

extension Localizable where Self: UIViewController, Self: Localizable {

    func presentWarning(message: String) {
        presentAlert(withTitle: localize(string: Constants.warningString), andMessage: message)
    }
    
    func presentAlert(with message: String?) {        
        presentAlert(withTitle: localize(string: Constants.errorString), andMessage: message)
    }
    
    func presentInfoAlert(with message: String) {
        presentAlert(withTitle: nil, andMessage: message)
    }
    
    func presentAlert(withTitle title: String?, andMessage message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }

    
    func makePurchaseFor(productId: String) {
        let loader = PreloaderView(frame: HUDFrame, text: localize(string: Constants.loadingString), image: #imageLiteral(resourceName: "walletHuge"))
        view.addSubview(loader)
        loader.show(customTitle: localize(string: Constants.loadingString))
        self.getAvailableInAppBy(stringId: productId) { [unowned self] (product) in
            if product == nil {
                self.presentAlert(with: self.localize(string: Constants.somethingWentWrongString))
                loader.hide()
                return
            }
            SwiftyStoreKit.purchaseProduct(product!) { (result) in
                loader.hide()
                switch result {
                case .success(let purchase):
                    print("Purchase Success: \(purchase.productId)")
                case .error(let error):
                    switch error.code {
                    case .unknown: print("Unknown error. Please contact support")
                    case .clientInvalid: print("Not allowed to make the payment")
                    case .paymentCancelled: break
                    case .paymentInvalid: print("The purchase identifier was invalid")
                    case .paymentNotAllowed: print("The device is not allowed to make the payment")
                    case .storeProductNotAvailable: print("The product is not available in the current storefront")
                    case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
                    case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
                    case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
                    default: print("default")
                    }
                }
            }
        }
    }
}

extension EPPickerDelegate where Self: UIViewController {
    func presentiPhoneContacts() {
        let contactPickerScene = EPContactsPicker(delegate: self, multiSelection: false, subtitleCellType: SubtitleCellValue.email)
        let navigationController = UINavigationController(rootViewController: contactPickerScene)
        present(navigationController, animated: true, completion: nil)
    }
}

extension UIViewController {
    func presentAlert(withTitle title: String?, andMessage message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func closeVcByTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissVC))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissVC() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func animateLayout() { // animation when changed constraint
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    func isOperationSystemAtLeast11() -> Bool {
        return ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 11, minorVersion: 0, patchVersion: 0))
    }

    static let classInit: Void = {
        let originalSelector = #selector(UIViewController.viewWillAppear(_:))
        let swizzledSelector = #selector(proj_viewWillAppear(animated:))
        swizzling(UIViewController.self, originalSelector, swizzledSelector)
    }()
    
    func presentNoInternetScreen() -> Bool {
        if !(ConnectionCheck.isConnectedToNetwork()) {
            if self.isKind(of: NoInternetConnectionViewController.self) || self.isKind(of: UIAlertController.self) {
                return false
            }
            
            let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
            let nextViewController = storyBoard.instantiateViewController(withIdentifier: "NoConnectionVC") as! NoInternetConnectionViewController
            present(nextViewController, animated: true, completion: nil)
            
            return false
        } else {
            return true
        }
    }
    
    @objc func proj_viewWillAppear(animated: Bool) {
        proj_viewWillAppear(animated: animated)
        if !(ConnectionCheck.isConnectedToNetwork()) {
            if self.isKind(of: NoInternetConnectionViewController.self) || self.isKind(of: UIAlertController.self) {
                return
            }
            
            let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
            let nextViewController = storyBoard.instantiateViewController(withIdentifier: "NoConnectionVC") as! NoInternetConnectionViewController
            
            //case where exists textfields
            let tmvc = UIApplication.topViewController()
            
            if tmvc != nil && (tmvc!.className.hasPrefix("SendDetails") ||
                tmvc!.className.hasPrefix("CustomFee") ||
                tmvc!.className.hasPrefix("SendAmount") ||
                tmvc!.className.hasPrefix("BackupSeedPhraseViewController") ||
                tmvc!.className.hasPrefix("CheckWords") ||
                tmvc!.className.hasPrefix("AssetsViewController") ||
//                tmvc!.className.hasPrefix("ActivityViewController") ||
                tmvc!.className.hasPrefix("BrowserViewController") ||
                tmvc!.className.hasPrefix("FastOperationsViewController") ||
                tmvc!.className.hasPrefix("ContactsViewController") ||
                tmvc!.className.hasPrefix("SettingsViewController")) {
                
            } else if tmvc != nil && tmvc!.shouldRemoveKeyboard() {
                tmvc!.dismissKeyboard()
                
                tmvc!.present(nextViewController, animated: true, completion: nil)
            } else {
                self.present(nextViewController, animated: true, completion: nil)
            }
        } else if isServerConnectionExist == false {
            DataManager.shared.apiManager.presentServerOff()
        }
        //        print("swizzled_layoutSubviews")
    }
    
    func isVisible() -> Bool {
        return self.isViewLoaded && view.window != nil
    }
    
    func shouldRemoveKeyboard() -> Bool {
        if self.className.hasPrefix("SendStart") ||
            self.className.hasPrefix("WalletSettings") ||
            self.className.hasPrefix("CreateWallet") ||
            self.className.hasPrefix("ReceiveAmount") ||
            self.className.hasPrefix("CheckWordsViewController") {
                return true
        }
        
        return false
    }
    
    func presentDonationVCorAlert() {
        DataManager.shared.realmManager.fetchBTCWallets(isTestNet: false) { (wallets) in
            if wallets == nil || wallets?.count == 0 {
                let message = "You don`t have any Bitcoin wallets yet."
                self.donateOrAlert(isHaveNotEmptyWallet: false, message: message)
                
                return
            }
            
            for wallet in wallets! {
                if wallet.availableAmount > Int64(0) && wallet.availableAmount > Int64(minSatoshiInWalletForDonate) {
                    let message = "You have nothing to donate.\nRecharge your balance for any of your BTC wallets."  // no money no honey
                    self.donateOrAlert(isHaveNotEmptyWallet: true, message: message)
                    break
                } else { // empty wallet
                    let message = "You have nothing to donate.\nRecharge your balance for any of your BTC wallets."  // no money no honey
                    self.donateOrAlert(isHaveNotEmptyWallet: false, message: message)
                    break
                }
            }
        }
    }
    
    //not used any more
    func donateOrAlert(isHaveNotEmptyWallet: Bool, message: String) {
        if isHaveNotEmptyWallet {
            (self.tabBarController as! CustomTabBarViewController).changeViewVisibility(isHidden: true)
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let donatSendVC = storyboard.instantiateViewController(withIdentifier: "donatSendVC") as! DonationSendViewController
            donatSendVC.selectedTabIndex = self.tabBarController?.selectedIndex
            self.navigationController?.pushViewController(donatSendVC, animated: true)
        } else {
            self.viewWillAppear(false)
            let alert = UIAlertController(title: "Sorry", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func setPresentedVcToDelegate() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.presentedVC = self
    }
    
    func enableSwipeToBack() {
        self.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    func disableSwipeToBack() {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    func isVCVisible() -> Bool {
        return isViewLoaded && view.window != nil
    }
    
    func presentDonationAlertVC(from cancelDelegate: CancelProtocol, with idOfProduct: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let donatAlert = storyboard.instantiateViewController(withIdentifier: "donationAlert") as! DonationAlertViewController
        donatAlert.modalPresentationStyle = .overCurrentContext
        donatAlert.modalTransitionStyle = .crossDissolve
        donatAlert.cancelDelegate = cancelDelegate
        donatAlert.idOfProduct = idOfProduct
        self.present(donatAlert, animated: true, completion: nil)
    }
    
    func showHud(text: String) -> UIView {
        let hud = ProgressHUD(text: text)
        hud.tag = 999
        self.view.addSubview(hud)
        hud.blockUIandShowProgressHUD()
        return hud
    }
    
    func hideHud(view: ProgressHUD?) {
        view?.unblockUIandHideProgressHUD()
    }
    
    func getAvailableInAppBy(stringId: String, completion: @escaping (SKProduct?) -> ()) {
        SwiftyStoreKit.retrieveProductsInfo([stringId]) { result in
            if let product = result.retrievedProducts.first {
                let priceString = product.localizedPrice!
                print("Product: \(product.localizedDescription), price: \(priceString)")
                completion(product)
            } else if let invalidProductId = result.invalidProductIDs.first {
                print("Invalid product identifier: \(invalidProductId)")
                completion(nil)
            } else {
                print("Error: \(result.error)")
                completion(nil)
            }
        }
    }
    
    func add(_ child: UIViewController, to view: UIView) {
        addChildViewController(child)
        addChildView(child.view, to: view)
        
        child.didMove(toParentViewController: self)
    }
    
    func remove() {
        guard parent != nil else {
            return
        }
        willMove(toParentViewController: nil)
        removeFromParentViewController()
        view.removeFromSuperview()
    }
    
    func addChildView(_ childView: UIView, to parentView: UIView) {
        childView.frame = parentView.bounds
        parentView.addSubview(childView)
        
        childView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-0-[childView]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["childView" : childView]))
        parentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[childView]-0-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["childView" : childView]))
    }
    

    func noConnectionView() -> UIView {
//        let blockView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 60))
        
        let heightOfView: CGFloat = screenHeight > heightOfPlus ? 60 : 40
        let blockView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: heightOfView))
        blockView.backgroundColor = .red
        blockView.layer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6)
        blockView.layer.shadowOpacity = 1
        blockView.layer.shadowOffset = .zero
        blockView.layer.shadowRadius = 10
        blockView.tag = 500  // for tracking is on screen
        
        
        let reconnectBtn = UIButton(frame: CGRect(x: 0, y: blockView.frame.height/2, width: screenWidth, height: blockView.frame.height/2))
        reconnectBtn.setTitle("Server is Unavailable", for: .normal)
        reconnectBtn.setTitleColor(.white, for: .normal)
        
        blockView.addSubview(reconnectBtn)
        
        return blockView
    }
    
    func isNoConnectionOnScreen() -> Bool {
        for subviewView in self.view.subviews {
            if subviewView.tag == 500 {
                return true
            }
        }
        return false
    }
    
    func removeNoConnection(view: UIView) {
        UIView.animate(withDuration: 0.2, animations: {
            view.alpha = 0
        }) { (isEnd) in
//            view.removeFromSuperview()
            
            //FIXME: research why view has .superview as nil
            let aView = DataManager.shared.apiManager.topVC?.view.subviews.filter { $0.tag == 500 }.first
            if aView != nil {
                aView?.removeFromSuperview()
            }
        }
    }
        
    func topMostViewController() -> UIViewController {
        
        if let presented = self.presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        
        return self
    }
    
    func presentPrivateKeyView(wallet: UserWalletRLM, addressIndex: Int) {
        let privateKeyVC = viewControllerFrom("Wallet", "privateKey") as! PrivateKeyViewController
        privateKeyVC.modalPresentationStyle = .overCurrentContext
        
        DataManager.shared.getAccount(completion: { (acc, err) in
            privateKeyVC.account = acc
            privateKeyVC.wallet = wallet
            privateKeyVC.addressID = addressIndex
            self.present(privateKeyVC, animated: true, completion: nil)
        })
    }
}
