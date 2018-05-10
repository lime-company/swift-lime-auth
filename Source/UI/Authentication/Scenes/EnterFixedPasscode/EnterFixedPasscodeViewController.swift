//
// Copyright 2018 Lime - HighTech Solutions s.r.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
//

import UIKit
import PowerAuth2

open class EnterFixedPasscodeViewController: LimeAuthUIBaseViewController, EnterPasswordRoutableController, PinKeyboardViewDelegate {
    
    public var router: (AuthenticationUIProcessRouter & EnterPasswordRoutingLogic)!
    public var uiDataProvider: AuthenticationUIDataProvider!

    public func connectEnterPasswordRouter(router: (AuthenticationUIProcessRouter & EnterPasswordRoutingLogic)) {
        self.router = router
        router.connect(controller: self)
    }
    
    public func connect(authenticationProcess process: AuthenticationUIProcess) {
        router?.authenticationProcess = process
        uiDataProvider = process.uiDataProvider
    }

    
    // MARK: - Outlets -
    
    /// A PIN keyboard view
    @IBOutlet weak var pinKeyboard: PinKeyboardView!
    /// Image view dedicated for logo
    @IBOutlet weak var logoImage: UIImageView!
    
    /// Label for PIN prompt
    @IBOutlet weak var promptLabel: UILabel!
    /// Label for PIN bullets
    @IBOutlet weak var fixedPinLabel: UILabel!
    /// Label displaying remaining attempts
    @IBOutlet weak var attemptsLabel: UILabel!
    
    /// An activity indicator
    @IBOutlet weak var activityIndicator: (UIView & CheckmarkWithActivity)!
    /// Close dialog button, displayed only when error occured
    @IBOutlet weak var closeErrorButton: UIButton!
    
    
    // Layout adjustments
    @IBOutlet weak var logoImageTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinKeyboardBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Getters
    
    var uiRequest: Authentication.UIRequest {
        return router.authenticationProcess.uiRequest
    }
    
    var authenticationProcess: AuthenticationUIProcess {
        return router.authenticationProcess
    }
    
    var operationExecution: AuthenticationUIOperationExecutionLogic {
        return router.authenticationProcess.operationExecution
    }
    
    // MARK: - Runtime variables
    
    /// Enum defining all internal UI states
    private enum InterfaceState {
        /// Initial interface state, which must be changed after the controller is loaded
        case empty
        /// Entering password
        case password
        /// Waiting for operation
        case activity
        /// Error is presented
        case error
        /// Success is presented
        case success
    }
    
    /// Current UI state.
    private var currentState    = InterfaceState.empty
    /// Next UI state.
    private var nextState       = InterfaceState.empty
    
    /// Returns true if there's pending activity
    private var isPendingStateChange: Bool {
        return self.currentState != self.nextState
    }
    
    /// Current password
    private var password = ""
    
    /// Length of current password (in characters)
    private var passwordLength: Int {
        return password.count
    }
    
    /// The required length for PIN
    private var requiredPasswordLength: Int = -1
    
    /// Returns true if biometry is allowed for this operation.
    private var isBiometryAllowed: Bool {
        return operationExecution.isBiometryAllowed
    }
    
    /// Error returned from operation execution
    private var error: LimeAuthError?
    
    // MARK: - ViewController life cycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial checks
        guard let _ = router?.authenticationProcess else {
            fatalError("EnterFixedPasscodeViewController is not configured properly")
        }
        
        let credentials = authenticationProcess.credentialsProvider.credentials
        guard credentials.password.type == .fixedPin else {
            fatalError("This controller implements different credentials input method than is requested.")
        }
        requiredPasswordLength = credentials.password.maximumLength
        
        // Prepare UI
        updateLocalizedStrings()
        prepareUIForFirstUse()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if uiRequest.tweaks.presentedAsModal || uiRequest.tweaks.hideNavigationBar {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // first presentation, ask for biometric authentication execution
        if operationExecution.willUseBiometryFirst() {
            executeOperation(biometry: true)
        }
    }
    
    open override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        router.prepare(for: segue, sender: sender)
    }
    
    open func updateLocalizedStrings() {
        let commonStrings = uiDataProvider.uiCommonStrings
        self.closeErrorButton.setTitle(commonStrings.closeButton, for: .normal)
    }
    
    
    // MARK: - PIN keyboard view delegate
    
    public func pinKeyboardView(_ pinKeyboardView: PinKeyboardView, didTapOnDigit digit: Int) {
        appendDigit(digit)
    }
    
    public func pinKeyboardView(_ pinKeyboardView: PinKeyboardView, didTapOnSpecialKey key: PinKeyboardSpecialKey) {
        if key == .cancel {
            doCancel()
        } else if key == .backspace {
            removeLastDigit()
        } else if key == .biometry {
            if isBiometryAllowed {
                self.executeOperation(biometry: true)
            }
        }
    }
    
    public func pinKeyboardView(_ pinKeyboardView: PinKeyboardView, imageFor biometryIcon: PinKeyboardBiometryIcon) -> UIImage? {
        let commonImages = uiDataProvider.uiCommonImages
        let lazyImage = biometryIcon == .touchID ? commonImages.touchIdButton : commonImages.faceIdButton
        return lazyImage.optionalImage
    }
    
    // MARK: - Internals -
    
    private func getAndResetPassword(keepFakePassword: Bool = false) -> String {
        let pass = self.password
        let stars = String(repeating: "*", count: self.requiredPasswordLength)
        self.password.removeAll()
        self.password.append(stars)
        self.password.removeAll()
        if keepFakePassword {
            self.password.append(stars)
        }
        return pass
    }
    
    private func executeOperation(biometry: Bool, delay: Bool = true) {
        
        var changeStateDuration: TimeInterval = 0.1
        let authentication = PowerAuthAuthentication()
        let password = self.getAndResetPassword(keepFakePassword: true)
        if biometry {
            // simulate "full bullets" when biometry is used
            self.updatePasswordLabel()
            // create biometry credentials object
            authentication.useBiometry = true
            authentication.biometryPrompt = uiRequest.prompts.biometricPrompt
        } else {
            // we need wait for a while, to show present last typed digit
            changeStateDuration = 0.1
            // create password credentials
            authentication.usePassword = password
        }
        
        // Switch to "activity"
        self.presentActivity(animated: true, afterDelay: changeStateDuration) {
            // And execute operation after
            self.operationExecution.execute(for: authentication) { (result) in
                if result.isError {
                    self.authenticationProcess.storeFailureReason(error: result.error!)
                    self.showFailureResult(result)
                } else {
                    self.authenticationProcess.storeCurrentCredentials(credentials: Authentication.UICredentials(password: password))
                    self.showSuccessResult()
                }
            }
        }
    }
    
    private func showSuccessResult() {
        self.presentSuccess(animated: true) {
            self.router.routeToSuccess()
        }
    }
    
    private func showFailureResult(_ failure: AuthenticationUIOperationResult) {
        
        error = failure.error
        self.fixedPinLabel?.isHidden = false
        if failure.isTouchIdCancel {
            // user did cancel TouchID dialog
            self.presentKeyboard(animated: true)
            //
        } else if failure.isAuthenticationError {
            // auth error
            if failure.activationProblem {
                // activation has been blocked, or completely removed.
                // we should inform user about this situation and dismiss the dialog
                self.presentError(retry: false)
                //
            } else {
                // activation looks ok, user just did enter a wrong PIN
                // we will show termporary error message and retry authorization
                self.presentError(retry: true) {
                    self.presentKeyboard(animated: true)
                }
            }
            //
        } else {
            // this is a regular error
            self.presentError(retry: false)
        }
    }
    
    private func appendDigit(_ digit: Int) {
        if self.passwordLength < self.requiredPasswordLength {
            self.password.append(Character(UnicodeScalar(48 + digit)!))
        } else {
            D.warning("Trying to add more digits than allowed")
        }
        // hide remaining attempts label during the typing
        self.remainingAttemptsLabelIsVisible = false
        afterPassowrdChange()
    }
    
    private func removeLastDigit() {
        if !password.isEmpty {
            password.remove(at: password.index(before: password.endIndex))
        } else {
            D.warning("Removing digit from already empty password")
        }
        afterPassowrdChange()
    }
    
    private func afterPassowrdChange() {
        self.updateViews()
        if self.passwordLength == self.requiredPasswordLength {
            // PIN is complete, so execute the operation immediately
            executeOperation(biometry: false)
        }
    }
    
    // MARK: - IBActions -
    
    @IBAction func confirmErrorAction(_ sender: UIButton) {
        router.routeToError()
    }
    
    private func doCancel() {
        router.routeToCancel()
    }
    
    // MARK: - Present UI state change
    
    private func changeState(to state: InterfaceState) {
        if isPendingStateChange {
            D.warning("Changing state to '\(state)' during ongoing switch to '\(nextState)' is not allowed!")
            return
        }
        D.print("Changing UI state from '\(currentState)' to \(state)'")
        nextState = state
    }
    
    private func commitChangeState() {
        if !isPendingStateChange {
            D.warning("There's no pending state change")
            return
        }
        D.print("Changing UI state to '\(nextState)' is now completed")
        self.currentState = self.nextState
    }
    
    // MARK: - Update UI
    
    open func prepareUIForFirstUse() {
        // KB delegate
        pinKeyboard?.delegate = self
        
        adjustLayout()
        
        // Choose right initial mode
        if operationExecution.willUseBiometryFirst() {
            presentActivity(animated: false)
        } else {
            presentKeyboard(animated: false)
        }
        
        updateViews()
    }
    
    /// Adjusts layout for various device screen sizes
    open func adjustLayout() {
        if LayoutHelper.phoneScreenSize == .small {
            // 5, 5s, SE
            self.pinKeyboardBottomConstraint.constant = 12.0
            self.logoImageTopConstraint.constant = 0.0
        } else {
            // Other models
            self.pinKeyboardBottomConstraint.constant = 32.0
            self.logoImageTopConstraint.constant = 20.0
        }
    }
    
    
    open func presentActivity(animated: Bool, afterDelay: TimeInterval = 0, completion: (()->Void)? = nil) {
        self.changeState(to: .activity)
        let uiChange = { ()->Void in
            //
            self.closeErrorButton.alpha = 0
            self.activityIndicator.alpha = 1
            self.activityIndicator.showActivity(animated: animated)
            self.pinKeyboard.transform = CGAffineTransform.init(translationX: 0.0, y: self.pinKeyboard.frame.size.height + 50.0)
            //
            self.commitChangeState()
            self.updateViews()
            completion?()
        }
        let animatedChange = !animated ? uiChange : { ()->Void in
            UIView.animate(withDuration: animated ? 0.25 : 0, delay: 0, options: .curveEaseInOut, animations: {
                uiChange()
                self.view.layoutIfNeeded()
            })
        }
        if afterDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(afterDelay * 1000))) {
                animatedChange()
            }
        } else {
            animatedChange()
        }
    }
    
    open func presentKeyboard(animated: Bool, completion: (()->Void)? = nil) {
        self.changeState(to: .password)
        
        let _ = self.getAndResetPassword()
        self.remainingAttemptsLabelIsVisible = true
        
        let uiChange = { ()->Void in
            //
            self.fixedPinLabel.textColor = UIColor.black
            self.closeErrorButton.alpha = 0
            self.activityIndicator.alpha = 0
            self.activityIndicator.showIdle(animated: animated)
            self.pinKeyboard.transform = CGAffineTransform.identity
            //
            self.commitChangeState()
            completion?()
        }
        self.updateViews()
        
        UIView.animate(withDuration: animated ? 0.25 : 0, delay: 0, options: .curveEaseInOut, animations: {
            uiChange()
            self.view.layoutIfNeeded()
        })
    }
    
    open func presentSuccess(animated: Bool, completion: @escaping ()->Void) {
        self.changeState(to: .success)
        
        self.activityIndicator.showSuccess(animated: animated)
        
        self.updateViews()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(uiRequest.tweaks.successAnimationDelay)) {
            self.commitChangeState()
            completion()
        }
    }
    
    open func presentError(retry: Bool, completion: (()->Void)? = nil) {
        self.changeState(to: .error)
        self.updateViews()
        
        self.activityIndicator.showError()
        
        if retry {
            // Retry means that we need to shake with PIN and then wait for a while
            doShake(view: fixedPinLabel, time: 0.07 , start: {
                self.fixedPinLabel?.textColor = UIColor(red:0.761, green:0.000, blue:0.502, alpha:1.000)
            }) {
                self.fixedPinLabel?.textColor = UIColor.black
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.uiRequest.tweaks.errorAnimationDelay)) {
                    self.commitChangeState()
                    completion?()
                }
            }
        } else {
            // Non retry... We need to wait and then animate close button
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(uiRequest.tweaks.errorAnimationDelay)) {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                    self.closeErrorButton?.alpha = 1
                }, completion: { (complete) in
                    self.commitChangeState()
                    completion?()
                })
            }
        }
    }
    
    private func doShake(view: UIView?, time: TimeInterval = 0.05, start: (() -> Void)? = nil, completion: @escaping () -> Void) {
        
        guard let viewForShake = view else {
            return
        }
        
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
                
        UIView.animate(withDuration: time, delay: 0, options: .curveEaseOut, animations: {
            start?()
            viewForShake.transform = CGAffineTransform.init(translationX: -10.0, y: 0.0)
            self.view.layoutIfNeeded()
        }) { (didComplete) in
            UIView.animate(withDuration: time * 2, delay: 0, options: .curveEaseInOut, animations: {
                viewForShake.transform = CGAffineTransform.init(translationX: 10.0, y: 0.0)
                self.view.layoutIfNeeded()
            }) { (didComplete) in
                UIView.animate(withDuration: time, delay: 0, options: .curveEaseIn, animations: {
                    viewForShake.transform = CGAffineTransform.identity
                    self.view.layoutIfNeeded()
                }) { (didComplete) in
                    completion()
                }
            }
        }
    }
    
    
    // MARK: - Update UI
    
    open func updateViews() {
        // Update delete or cancel
        let empty = self.password.isEmpty
        pinKeyboard?.setSpecialKeyVisible(.cancel, visible: empty)
        pinKeyboard?.setSpecialKeyVisible(.backspace, visible: !empty)
        
        // Show or Hide biometry button
        pinKeyboard?.setSpecialKeyVisible(.biometry, visible: isBiometryAllowed)
        
        self.updatePasswordLabel()
        self.updateRemainingAttemptsLabel()
        self.updatePromptLabel()
    }
    
    open func updatePasswordLabel() {
        let filledBulletsCount = self.passwordLength
        var bulletsText = String(repeating: "• ", count: filledBulletsCount)
        let emptyBulletsCount = self.requiredPasswordLength - filledBulletsCount
        if (emptyBulletsCount > 0) {
            bulletsText.append(String(repeating: "◦ ", count: emptyBulletsCount))
        }
        self.fixedPinLabel?.text = bulletsText
    }
    
    /// Triggers visibility of remaining attempts label
    private var remainingAttemptsLabelIsVisible = true
    
    open func updateRemainingAttemptsLabel() {
        // Attempts label
        var attemptsText: String?
        if let lastStatus = authenticationProcess.session.lastFetchedActivationStatus {
            if lastStatus.failCount > 0 {
                attemptsText = uiDataProvider.localizeRemainingAttempts(attempts: lastStatus.remainingAttempts)
            }
        }
        self.attemptsLabel?.text = attemptsText
        self.attemptsLabel?.isHidden = !remainingAttemptsLabelIsVisible
    }
    
    open func updatePromptLabel() {
        // TODO: loc
        var promptText: String
        let state = self.isPendingStateChange ? self.nextState : self.currentState
        switch state {
        case .password:
            promptText = uiRequest.prompts.keyboardPrompt  ?? uiDataProvider.uiCommonStrings.enterPin
        case .activity:
            promptText = uiRequest.prompts.activityMessage ?? uiDataProvider.uiCommonStrings.pleaseWait
        case .success:
            promptText = uiRequest.prompts.successMessage  ?? uiDataProvider.uiCommonStrings.success
        case .error:
            promptText = "Operation execution did fail."
        default:
            promptText = ""
        }
        self.promptLabel?.text = promptText
    }
}
