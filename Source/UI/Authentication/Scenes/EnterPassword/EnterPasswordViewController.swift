//
// Copyright 2018 Wultra s.r.o.
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

open class EnterPasswordViewController: LimeAuthUIBaseViewController, EnterPasswordRoutableController, UITextFieldDelegate {
    
    public var router: (AuthenticationUIProcessRouter & EnterPasswordRoutingLogic)!
    public var uiDataProvider: AuthenticationUIDataProvider!
    
    open func connectEnterPasswordRouter(router: (AuthenticationUIProcessRouter & EnterPasswordRoutingLogic)) {
        self.router = router
        router.connect(controller: self)
    }
    
    open func connect(authenticationProcess process: AuthenticationUIProcess) {
        router?.authenticationProcess = process
        process.currentRouter = router
        uiDataProvider = process.uiDataProvider
    }
    
    // MARK: - Outlets -
    
    /// Label for password prompt
    @IBOutlet weak var promptLabel: UILabel!
    /// Text field for password
    @IBOutlet weak var passwordTextField: UITextField!
    /// Label displaying remaining attempts
    @IBOutlet weak var attemptsLabel: UILabel!
    /// Password confirmation button
    @IBOutlet weak var confirmPasswordButton: UIButton!
    /// Rounded view around textfield and button
    @IBOutlet weak var roundCornersView: UIView!
    /// A button for cancel
    @IBOutlet weak var cancelButton: UIButton!
    /// A button for biometry signing
    @IBOutlet weak var useBiometryButton: UIButton!
    
    /// An activity indicator
    @IBOutlet weak var activityIndicator: (UIView & CheckmarkWithActivity)!
    /// Close dialog button, displayed only when error occured
    @IBOutlet weak var closeErrorButton: UIButton!
    
    /// Keyboard accessory view
    @IBOutlet var keyboardAccessoryView: UIView!
    
    
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
    
    var actionFeedback: LimeAuthActionFeedback? {
        return router.authenticationProcess.uiProvider.actionFeedback
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
    private var currentState     = InterfaceState.empty
    /// Next UI state.
    private var nextState         = InterfaceState.empty
    
    /// Returns true if there's pending activity
    private var isPendingStateChange: Bool {
        return self.currentState != self.nextState
    }
    
    private var password: String {
        return self.passwordTextField.text ?? ""
    }
    
    private var passwordLength: Int {
        return self.password.count
    }
    
    /// The required length for password
    private var minimumPasswordLength: Int = -1
    /// Maximum length for the password. This is just a some safe limit, to do not allow to paste 65k strings,
    /// to the text field. Like the penetration testers do :)
    private let maximumPasswordLength: Int = 128
    
    /// Returns true if biometry is allowed for this operation.
    private var isBiometryAllowed: Bool {
        return operationExecution.isBiometryAllowed
    }
    
    /// Result returned from operation execution
    private var executionResult: AuthenticationUIOperationResult?
    
    private var isExecutingOperation = false
    
    // MARK: - ViewController life cycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        // Initial checks
        guard let _ = router?.authenticationProcess else {
            D.fatalError("EnterPasswordViewController is not configured properly")
        }
        
        let credentials = authenticationProcess.credentialsProvider.credentials
        guard credentials.password.type == .password else {
            D.fatalError("This controller implements different credentials input method than is requested.")
        }
        minimumPasswordLength = credentials.password.minimumLength

        // Prepare UI
        updateLocalizedStrings()
        prepareUIForFirstUse()
        actionFeedback?.prepare()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if uiRequest.tweaks.presentedAsModal || uiRequest.tweaks.hideNavigationBar {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }
    
    /// Helper variable to prevent repeated execution of biometry
    /// after the controller is re-introduced
    private var viewDidAppearOnce = false
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        title = ""
        
        // first presentation, ask for biometric authentication execution
        if operationExecution.willUseBiometryFirst() && viewDidAppearOnce == false {
            doBiometryAuth()
        }
        
        viewDidAppearOnce = true
    }
    
    open override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        router.prepare(for: segue, sender: sender)
    }
    
    open func updateLocalizedStrings() {
        let commonStrings = uiDataProvider.uiCommonStrings
        self.confirmPasswordButton.setTitle(commonStrings.okButton, for: .normal)
        self.closeErrorButton.setTitle(commonStrings.closeButton, for: .normal)
        self.cancelButton.setTitle(commonStrings.cancelButton, for: .normal)
        let biometryButtonTitle = LimeAuthSession.supportedBiometricAuthentication == .touchID ? commonStrings.useTouchId : commonStrings.useFaceId
        self.useBiometryButton.setTitle(biometryButtonTitle, for: .normal)
    }
    
    // MARK: - UITextFieldDelegate
    
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.nextState == .password
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // paranoid test for a very big strings
        if string.count > self.maximumPasswordLength {
            return false
        }
        // calculate what will textfield contain after the update
        let currString = (textField.text ?? "") as NSString
        let nextString = currString.replacingCharacters(in: range, with: string)
        let shouldChange = nextString.count <= self.maximumPasswordLength
        if shouldChange {
            // hide remaining attempts during typing
            self.remainingAttemptsLabelIsVisible = false
            // update OK button, if change will be really applied
            self.updatePasswordConfirmButton(for: nextString)
        }
        return shouldChange
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.doPasswordAuth()
        return false
    }
    
    
    
    // MARK: - Internals -
    
    private func doCancel() {
        self.passwordTextField.resignFirstResponder()
        router.routeToCancel()
    }
    
    private func doPasswordAuth() {
        if self.passwordLength >= self.minimumPasswordLength {
            self.executeOperation(biometry: false)
        }
    }
    
    private func doBiometryAuth() {
        if self.isBiometryAllowed {
            executeOperation(biometry: true)
        }
    }
    
    private func getAndResetPassword() -> String {
        let pass = self.password
        self.passwordTextField.text = nil
        return pass
    }
    
    private func executeOperation(biometry: Bool, delay: Bool = true) {
        
        guard isExecutingOperation == false else {
            D.warning("Trying to execute operation more than once")
            return
        }
        
        isExecutingOperation = true
        
        setSwipeToDismissGestureEnabled(to: false) { resetBlock in
            let changeStateDuration: TimeInterval = 0.1
            let authentication = PowerAuthAuthentication()
            let currentPassword = self.password
            if biometry {
                // simulate "full bullets" when biometry is used
                self.passwordTextField.text = String(repeating: "*", count: self.minimumPasswordLength)
                // create biometry credentials object
                authentication.useBiometry = true
                authentication.biometryPrompt = self.uiRequest.prompts.biometricPrompt
            } else {
                // create password credentials
                authentication.usePassword = currentPassword
            }
            
            // Switch to "activity"
            self.presentActivity(animated: true, afterDelay: changeStateDuration) {
                // And execute operation after
                self.operationExecution.execute(for: authentication) { (result) in
                    resetBlock()
                    // Operation is completed, so process the result
                    if result.isError {
                        self.authenticationProcess.storeFailureReason(error: result.error!)
                        self.showFailureResult(result)
                    } else {
                        self.authenticationProcess.storeCurrentCredentials(credentials: Authentication.UICredentials(password: currentPassword))
                        self.showSuccessResult()
                    }
                    
                    self.isExecutingOperation = false
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
        
        self.executionResult = failure
        if failure.isTouchIdCancel {
            // user did cancel TouchID dialog
            self.presentKeyboard(animated: true)
            //
        } else if failure.isAuthenticationError {
            // auth error
            if failure.isActivationProblem {
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
    
    // MARK: - IBActions -
    
    @IBAction func cancelAction(_ sender: UIButton) {
        self.doCancel()
    }
    
    @IBAction func confirmErrorAction(_ sender: UIButton) {
        router.routeToError()
    }
    
    @IBAction func confirmPasswordAction(_ sender: UIButton) {
        self.doPasswordAuth()
    }
    
    @IBAction func useBiometryAction(_ sender: UIButton) {
        self.doBiometryAuth()
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
        // Apply style
        let theme = uiDataProvider.uiTheme
        
        configureBackground(image: theme.common.backgroundImage, color: theme.common.backgroundColor)
        passwordTextField?.applyTextFieldStyle(theme.common.passwordTextField)
        passwordTextField?.font = UIFont.systemFont(ofSize: 17)
        closeErrorButton?.applyButtonStyle(theme.buttons.dismissError)
        confirmPasswordButton?.applyButtonStyle(theme.buttons.ok)
        (activityIndicator as? CheckmarkWithActivityView)?.applyIndicatorStyle(theme.styleForCheckmarkWithActivity)
        promptLabel?.textColor = theme.common.promptTextColor
        attemptsLabel?.textColor = theme.common.highlightedTextColor
		
        // Setup TextField
        passwordTextField.delegate = self
        passwordTextField.returnKeyType = .send
        passwordTextField.isSecureTextEntry = true
        passwordTextField.clearButtonMode = .never
        passwordTextField.autocorrectionType = .no
        (passwordTextField as? TextFieldWithInset)?.textContentInset = CGPoint(x: 12, y: 0)
        
        roundCornersView.applyLayerStyle(theme.layerStyleFromAuthenticationCommon)
        
        // Keyboard accessory view
        self.keyboardAccessoryView.backgroundColor = theme.common.backgroundColor
        self.useBiometryButton.applyButtonStyle(theme.buttons.keyboardAuxiliary)
        
        // Choose right initial mode of the scene
        if operationExecution.willUseBiometryFirst() {
            presentActivity(animated: false)
        } else {
            presentKeyboard(animated: false)
        }
        
        updateViews()
    }
    
    open func presentActivity(animated: Bool, afterDelay: TimeInterval = 0, completion: (()->Void)? = nil) {
        self.changeState(to: .activity)
		
		self.passwordTextField.resignFirstResponder()
		self.passwordTextField.isEnabled = false
		
		let uiChange = { ()->Void in
            //
            self.closeErrorButton.alpha = 0
            self.activityIndicator.alpha = 1
            self.activityIndicator.showActivity(animated: animated)
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
		
		self.passwordTextField.isEnabled = true
		self.passwordTextField.becomeFirstResponder()
		
        let uiChange = { ()->Void in
            //
            self.passwordTextField.textColor = self.uiDataProvider.uiTheme.common.passwordTextField.textColor
            self.closeErrorButton.alpha = 0
            self.activityIndicator.alpha = 0
            self.activityIndicator.showIdle(animated: animated)
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
        actionFeedback?.scene(.operationSuccess)
        
        // we're delaying auto-navigation, so disable any tempering with potentional modal presentation
        setSwipeToDismissGestureEnabled(to: false) { resetBlock in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.uiRequest.tweaks.successAnimationDelay)) {
                resetBlock()
                self.commitChangeState()
                completion()
            }
        }
    }
    
    open func presentError(retry: Bool, completion: (()->Void)? = nil) {
        
        self.changeState(to: .error)
        self.updateViews()
        self.activityIndicator.showError()
        actionFeedback?.scene(.operationFail)
        
        if retry {
            // Retry means that we need to shake with PIN and then wait for a while
            doShake(view: passwordTextField, time: 0.07 , start: {
                self.passwordTextField.textColor = self.uiDataProvider.uiTheme.common.wrongPasswordTextColor
            }) {
                self.passwordTextField.textColor = self.uiDataProvider.uiTheme.common.passwordTextField.textColor
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.uiRequest.tweaks.errorAnimationDelay)) {
                    self.commitChangeState()
                    completion?()
                }
            }
        } else {
            // Non retry... We need to wait and then animate close button
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.uiRequest.tweaks.errorAnimationDelay)) {
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
        self.updatePasswordConfirmButton(for: self.password)
        self.updateBiometryButton()
        self.updateRemainingAttemptsLabel()
        self.updatePromptLabel()
        // disable cancel button during the activity
        self.cancelButton.isEnabled = self.nextState == .password
    }
    
    open func updatePasswordConfirmButton(for nextPassword: String) {
        let enabled = nextPassword.count >= self.minimumPasswordLength && self.nextState == .password
        self.confirmPasswordButton.isEnabled = enabled
        self.updateRemainingAttemptsLabel()
    }
    
    open func updateBiometryButton() {
        let allowed = self.isBiometryAllowed && self.nextState == .password
        self.useBiometryButton.isEnabled = allowed
        if allowed {
            // If allowed, we're using an accessory view which contains the right button
            self.passwordTextField.inputAccessoryView = self.keyboardAccessoryView
        } else {
            // ...otherwise set nil as no accessory view
            self.passwordTextField.inputAccessoryView = nil
        }
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
        self.attemptsLabel?.text = remainingAttemptsLabelIsVisible ? attemptsText : ""
    }
    
    open func updatePromptLabel() {
        var promptText: String
        let state = self.isPendingStateChange ? self.nextState : self.currentState
        switch state {
        case .password:
            promptText = uiRequest.prompts.keyboardPrompt  ?? uiDataProvider.uiCommonStrings.enterPassword
        case .activity:
            promptText = uiRequest.prompts.activityMessage ?? uiDataProvider.uiCommonStrings.pleaseWait
        case .success:
            promptText = uiRequest.prompts.successMessage  ?? uiDataProvider.uiCommonStrings.success
        case .error:
            promptText = localizedErrorMessage(fallbackMessage: uiRequest.prompts.errorFallbackMessage ?? uiDataProvider.uiCommonStrings.failure)
        default:
            promptText = ""
        }
        self.promptLabel?.text = promptText
    }
    
    private func localizedErrorMessage(fallbackMessage: String) -> String {
        guard let result = executionResult else {
            return fallbackMessage
        }
        if result.isAuthenticationError {
            if result.isActivationProblem {
                if result.activationState == .blocked {
                    return uiDataProvider.uiCommonErrors.activationIsBlocked
                } else if result.activationState == .removed {
                    return uiDataProvider.uiCommonErrors.activationWasRemoved
                }
            } else if result.isBiometryError {
                switch PA2Keychain.biometricAuthenticationInfo.biometryType {
                case .touchID:
                    return uiDataProvider.uiCommonErrors.biometryNotRecognized_TouchId
                case .faceID:
                    return uiDataProvider.uiCommonErrors.biometryNotRecognized_FaceId
                default:
                    break
                }
            }
            return uiDataProvider.uiCommonErrors.wrongPassword
        }
        return uiDataProvider.localizeError(error: result.error, fallback: fallbackMessage)
    }
}

