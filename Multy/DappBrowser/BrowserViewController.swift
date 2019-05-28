//Copyright 2018 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details
import UIKit
import WebKit
import JavaScriptCore
import Result
import Web3
//typealias ResultDapp<T, Error: Swift.Error> = Result

private typealias LocalizeDelegate = BrowserViewController

protocol BrowserNavigationBarDelegate: class {
    func did(action: BrowserNavigation)
}

enum BrowserAction {
    case navigationAction(BrowserNavigation)
}

protocol BrowserViewControllerDelegate: class {
    func runAction(action: BrowserAction)
    func didVisitURL(url: URL, title: String)
}

class BrowserViewController: UIViewController, AnalyticsProtocol {
    
    private var myContext = 0
    
    private lazy var web3: Web3 = {
        return Web3(rpcURL: Constants.infuraURL(wallet))
    }()
    
    var wallet = UserWalletRLM() {
        didSet {
            if wallet.id.isEmpty == false {
                DataManager.shared.getWallet(primaryKey: self.wallet.id) { [unowned self] in
                    switch $0 {
                    case .success(let wallet):
                        self.wallletFromDB = wallet
                        
                        self.wallet.importedPrivateKey = self.wallletFromDB.importedPrivateKey
                        self.wallet.importedPublicKey = self.wallletFromDB.importedPublicKey
                    case .failure(_):
                        break
                    }
                }
            }
        }
    }
        
    var wallletFromDB = UserWalletRLM()
    
    var urlString = String()
    var alert: UIAlertController?
    
    private struct Keys {
        static let estimatedProgress = "estimatedProgress"
        static let developerExtrasEnabled = "developerExtrasEnabled"
        static let URL = "URL"
        static let ClientName = "Trust"
    }
    
    private lazy var userClient: String = {
        return Keys.ClientName + "/" + (Bundle.main.versionNumber ?? "")
    }()
    //
    lazy var webView: WKWebView = {
        let webView = WKWebView(
            frame: .zero,
            configuration: self.config
        )
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        if isDebug {
            webView.configuration.preferences.setValue(true, forKey: Keys.developerExtrasEnabled)
//            webView.configuration.preferences.setValue(true, forKey: WKWebsiteDataTypeOfflineWebApplicationCache)
        }
        
        return webView
    }()
    
    weak var delegate: BrowserViewControllerDelegate?
    
    lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = UIColor(hex: "3375BB")
        progressView.trackTintColor = .clear
        
        return progressView
    }()
    
    lazy var config: WKWebViewConfiguration = {
        //TODO
        let config = WKWebViewConfiguration.make(for: wallet,
                                                 in: ScriptMessageMediator(delegate: self))
        config.websiteDataStore =  WKWebsiteDataStore.default()
        
        config.allowsInlineMediaPlayback = true
        config.suppressesIncrementalRendering = true
        
        return config
    }()
    
    
    init(wallet: UserWalletRLM, urlString: String) {
        self.wallet = wallet
        self.urlString = urlString
        
        super.init(nibName: nil, bundle: nil)
        
        view.addSubview(webView)
        injectUserAgent()
        
        webView.addSubview(progressView)
        webView.bringSubview(toFront: progressView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.layoutGuide.topAnchor),// topLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),// bottomLayoutGuide.topAnchor),
            
            progressView.topAnchor.constraint(equalTo: view.layoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
            ])
        view.backgroundColor = .white
        webView.addObserver(self, forKeyPath: Keys.estimatedProgress, options: .new, context: &myContext)
        webView.addObserver(self, forKeyPath: Keys.URL, options: [.new, .initial], context: &myContext)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        refreshURL()
        
//        NotificationCenter.default.addObserver(self, selector: #selector(self.handleTransactionUpdatedNotification(notification :)), name: NSNotification.Name("transactionUpdated"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("transactionUpdated"), object: nil)
    }
    
    private func injectUserAgent() {
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            guard let `self` = self, let currentUserAgent = result as? String else { return }
            self.webView.customUserAgent = currentUserAgent + " " + self.userClient
        }
    }
    
//    @objc fileprivate func handleTransactionUpdatedNotification(notification : Notification) {
//        DispatchQueue.main.async { [unowned self] in
//            print(notification)
//
//            let msg = notification.userInfo?["NotificationMsg"] as? [AnyHashable : Any]
//            guard msg != nil, let txID = msg!["txid"] as? String else {
//                return
//            }
//
//            if txID == self.lastTxID {
//                self.webView.reload()
//                self.webView.scrollView.setContentOffset(CGPoint.zero, animated: true)
//            }
//
//            self.lastTxID = ""
//        }
//    }
    
    func goTo(url: URL) {
        webView.load(URLRequest(url: url))
    }
    
    func goHome() {
        let linkString = urlString //"https://dragonereum-alpha-test.firebaseapp.com"  //"https://app.alpha.dragonereum.io"
        guard let url = URL(string: linkString) else { return } //"https://dapps.trustwalletapp.com/"
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
//        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
//        browserNavBar?.textField.text = url.absoluteString
    }
    
    func reload() {
        webView.reload()
        self.webView.scrollView.setContentOffset(CGPoint.zero, animated: true)
    }
    
    private func stopLoading() {
        webView.stopLoading()
    }
    
    private func refreshURL() {
        if let url = webView.url?.absoluteURL {
            delegate?.didVisitURL(url: url, title: "Go")
        }
    }
    
    private func recordURL() {
        guard let url = webView.url else {
            return
        }
        delegate?.didVisitURL(url: url, title: webView.title ?? "")
    }
    
    private func changeURL(_ url: URL) {
//        delegate?.runAction(action: .changeURL(url))
        refreshURL()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let change = change else { return }
        if context != &myContext {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == Keys.estimatedProgress {
            if let progress = (change[NSKeyValueChangeKey.newKey] as AnyObject).floatValue {
                progressView.progress = progress
                progressView.isHidden = progress == 1
            }
        } else if keyPath == Keys.URL {
            if let url = webView.url {
//                self.browserNavBar?.textField.text = url.absoluteString
                changeURL(url)
            }
        }
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: Keys.estimatedProgress)
        webView.removeObserver(self, forKeyPath: Keys.URL)
    }
}

extension BrowserViewController: BrowserNavigationBarDelegate {
    func did(action: BrowserNavigation) {
        delegate?.runAction(action: .navigationAction(action))
        switch action {
        case .goBack:
            break
        case .more:
            break
        case .home:
            break
        case .enter:
            break
        case .beginEditing:
            stopLoading()
        }
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        recordURL()
//        hideErrorView()
        refreshURL()
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        hideErrorView()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
//        handleError(error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
//        handleError(error: error)
    }
}

extension BrowserViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? Dictionary<String, Any>,
            let id = body["id"] as? Int64 else { return }
        
        guard let name = body["name"] as? String,
            let operationType = DappOperationType.init(rawValue: name),
            let objectData = body["object"] as? Dictionary<String, Any> else {
                cancelledJScode(for: id)
                
                return
        }
        
        let operationObject = OperationObject.init(with: objectData, for: id)
        
        switch operationType {
        case .signTransaction:
            showAlert(with: operationObject)
        case .signMessage, .signPersonalMessage:
            signMessage(OperationObject.init(with: objectData, for: id))
        case .signTypedMessage:
            break
        }
    }
}


//perfom operations
extension BrowserViewController {
    func signMessage(_ object: OperationObject) {
        if object.hexData.isEmpty {
            cancelledJScode(for: object.id)
            
            return
        }
        
        let signResult = DataManager.shared.signMessage(object.hexData, wallet: wallet)
        
        switch signResult {
        case .success(let signString):
            evaluateJS(object.id, "0x" + signString)
        case .failure(let error):
            presentAlert(for: error)
            cancelledJScode(for: object.id)
        }
    }
    
    func refreshWalletAndShowAlert(for object: OperationObject) {
        DataManager.shared.getOneWalletVerbose(wallet: wallet) { [unowned self] (wallet, error) in
            if error != nil {
                self.cancelledJScode(for: object.id)
                self.presentAlert(for: "") // default message
            } else {
                self.wallet = wallet!
                self.showAlert(with: object)
            }
        }
    }
    
    func showAlert(with txInfo: OperationObject) {
        let localizedFormatString = localize(string: Constants.browserTxAlertSring)
        
        //small available balance
        if BigInt("\(txInfo.value)") + (BigInt("\(txInfo.gasLimit)") * BigInt("\(txInfo.gasPrice)")) >= wallet.availableAmount {
            presentAlert(for: "Transaction is trying to spend more than available")
            
            cancelledJScode(for: txInfo.id)
            
            return
        }
        
        let valueString = BigInt("\(txInfo.value)").cryptoValueString(for: wallet.blockchain)
        let feeString = (BigInt("\(txInfo.gasLimit)") * BigInt("\(txInfo.gasPrice)")).cryptoValueString(for: wallet.blockchain)
        
        let message = NSString.init(format: NSString.init(string: localizedFormatString),  valueString, feeString, wallet.name)
        let alert = UIAlertController(title: nil, message: message as String, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: localize(string: Constants.denyString), style: .default, handler: { [weak self] (action) in
            if self != nil {
                self!.cancelledJScode(for: txInfo.id)
            }
        }))
        
        alert.addAction(UIAlertAction(title: localize(string: Constants.confirmString), style: .cancel, handler: { [weak self] (action) in
            if self != nil {
                self!.sendTxViaWeb3(object: txInfo)
            }
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    func sendTxViaWeb3(object: OperationObject) {
        let info = DataManager.shared.privateInfo(for: wallet)
        
        precondition(wallet.ethWallet != nil, "This is not a Ethereum wallet")
        
        sendTX(nonce: wallet.ethWallet!.nonce.uint64Value, gasPrice: object.gasPrice, gasLimit: object.gasLimit, fromAddress: object.fromAddress, toAddress: object.toAddress, value: object.value, data: object.hexData, privateKey: info!["privateKey"] as! String, id: object.id)
    }
    
    func sendTX(nonce: UInt64, gasPrice: BigUInt, gasLimit: BigUInt, fromAddress: String, toAddress: String, value: String, data: String, privateKey: String, id: Int64) {
        let nonceQuantity = EthereumQuantity(integerLiteral: nonce)
        let gasQuantity = EthereumQuantity(quantity: gasPrice)
        let gasLimitQuantity = EthereumQuantity(quantity: gasLimit)
        let fromEtherAddress = EthereumAddress(hexString: fromAddress)
        let toEtherAddress = EthereumAddress(hexString: toAddress)
        let etherValue = EthereumQuantity(quantity: BigUInt(value)!)
        let etherData = EthereumData(bytes: data.hexToBytes())
        
        let tx = EthereumTransaction(nonce: nonceQuantity, gasPrice: gasQuantity, gas: gasLimitQuantity, from: fromEtherAddress, to: toEtherAddress, value: etherValue, data: etherData)
        
        let etherPrivKey = try! EthereumPrivateKey(hexPrivateKey: privateKey)
        let etherChainID = EthereumQuantity(integerLiteral: wallet.chain.uint64Value)
        let signed = try! tx.sign(with: etherPrivKey, chainId: etherChainID)
        
        web3.eth.sendRawTransaction(transaction: signed) { [weak self] (response) in
            if self == nil { return }
            
            switch response.status {
            case .success(let result):
                debugPrint(result)
                
                DispatchQueue.main.async {
                    self!.evaluateJS(id, result.hex())
                }
                
                let amountString = BigInt("\(value)").cryptoValueString(for: self!.wallet.blockchain)
                self!.sendDappAnalytics(screenName: browserTx, params: self!.makeAnalyticsParams(sendAmountString: amountString,
                                                                                                 gasPrice: "\(gasPrice)",
                                                                                                 gasLimit: "\(gasLimit)",
                                                                                                 contractMethod: String(data.prefix(8))))
            case .failure(let error):
                debugPrint(error)
                
                DispatchQueue.main.async {
                    self!.cancelledJScode(for: id)
                }
                
                self!.presentAlert(for: "Error while sending tx")
            }
        }
    }
    
//    func signTx(for object: OperationObject) {
//        let dappPayload = object.hexData
//
//        let trData = DataManager.shared.createETHTransaction(wallet: wallet,
//                                                             sendAmountString: object.value,
//                                                             destinationAddress: object.toAddress,
//                                                             gasPriceAmountString: "\(object.gasPrice)",
//                                                             gasLimitAmountString: "\(object.gasLimit)",
//                                                             payload: dappPayload)
//
//        let rawTransaction = trData.message
//
//        guard trData.isTransactionCorrect else {
//            self.webView.reload()
//            self.presentAlert(for: rawTransaction)
//
//            return
//        }
//
//        let newAddressParams = [
//            "walletindex"   : wallet.walletID.intValue,
//            "address"       : wallet.address,
//            "addressindex"  : 0,
//            "transaction"   : rawTransaction,
//            "ishd"          : wallet.shouldCreateNewAddressAfterTransaction
//            ] as [String : Any]
//
//        let params = [
//            "currencyid": wallet.chain,
//            /*"JWT"       : jwtToken,*/
//            "networkid" : wallet.chainType,
//            "payload"   : newAddressParams
//            ] as [String : Any]
//
//        DataManager.shared.sendHDTransaction(transactionParameters: params) { [unowned self] (dict, error) in
//            if dict != nil {
//                self.saveLastTXID(from:  dict!)
//
//                self.showSuccessAlert()
//                self.webView.reload()
//                self.webView.scrollView.setContentOffset(CGPoint.zero, animated: true)
//
//                let amountString = BigInt("\(object.value)").cryptoValueString(for: self.wallet.blockchain)
//                self.sendDappAnalytics(screenName: browserTx, params: self.makeAnalyticsParams(sendAmountString: amountString,
//                                                                                               gasPrice: "\(object.gasPrice)",
//                                                                                               gasLimit: "\(object.gasLimit)",
//                                                                                               contractMethod: String(dappPayload.prefix(8))))
//            } else {
//                self.presentAlert(for: "")
//                self.cancelledJScode(for: object.id)
//            }
//        }
//    }
    
    func makeAnalyticsParams(sendAmountString: String, gasPrice: String, gasLimit: String, contractMethod: String) -> NSDictionary {
        let params: NSDictionary = [
            "dAppURL" :         webView.url != nil ? webView.url!.absoluteString : "empty URL",
            "Blockchain":       wallet.chain,
            "NetType" :         wallet.chainType,
            "Amount" :          sendAmountString,
            "GasPrice" :        gasPrice,
            "GasLimit" :        gasLimit,
            "ContractMethod":   contractMethod
        ]
        
        return params
    }
    
    func showSuccessAlert() {
        // show success alert
        alert = UIAlertController(title: "", message: Constants.successString, preferredStyle: .alert)
        present(self.alert!, animated: true, completion: nil)
        let when = DispatchTime.now() + 2
        DispatchQueue.main.asyncAfter(deadline: when){ [unowned self] in
            if let alert = self.alert {
                alert.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func presentAlert(for info: String) {
        var message = String()
        if info.hasPrefix("BigInt value is not representable as") {
            message = Constants.youEnteredTooSmallAmountString
        } else if info.hasPrefix("Transaction is trying to spend more than available") {
            message = Constants.youTryingSpendMoreThenHaveString
        } else {
            message = Constants.somethingWentWrongString
        }
        
        let alert = UIAlertController(title: localize(string: Constants.errorString), message: localize(string: message), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) in }))
        present(alert, animated: true, completion: nil)
    }
}

extension LocalizeDelegate: Localizable {
    var tableName: String {
        return "DappBrowser"
    }
}

extension BrowserViewController {
    func evaluateJS(_ id: Int64, _ message: String) {
        webView.evaluateJavaScript(callback(id, message, true)) { [weak self] (response, error) in //window.ethereum.sendResponse(\(id), \"\(message)\")
            debugPrint("response:  \(response), error: \(error)")
            debugPrint("after JS")
            if error != nil {
                self?.cancelledJScode(for: id) //"window.ethereum.sendError(\(id), \"Canceled\")"
            }
        }
    }
    
    func cancelledJScode(for id: Int64) {
        webView.evaluateJavaScript(callback(id, "cancelled", false)) { (_, _) in }
    }
    
    func callback(_ id: Int64, _ value: String, _ isSuccess: Bool) -> String {
        return isSuccess ? successJSCallback(id, value) : errorJSCallback(id, value)
    }
    
    func successJSCallback(_ id: Int64, _ value: String) -> String {
        return "executeCallback(\(id), null, \"\(value)\")"
    }
    
    func errorJSCallback(_ id: Int64, _ value: String) -> String {
        return "executeCallback(\(id), \"\(value)\", null)"
    }
}

