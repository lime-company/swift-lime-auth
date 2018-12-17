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
import LimeCore

internal class DefaultActivationResourcesProvider: ActivationUIProvider, ActivationUIDataProvider {
    
    public let bundle: Bundle
    public let localization: GenericLocalizationProvider
    
    public init(bundle: Bundle? = nil, localizationProvider: GenericLocalizationProvider?, authenticationUIProviderClosure: @escaping ()->AuthenticationUIProvider) {
        self.bundle = bundle ?? .limeAuthResourcesBundle
        self.localization = localizationProvider ?? SystemLocalizationProvider(tableName: "LimeAuth", bundle: .limeAuthResourcesBundle)
        self.authenticationUIProviderClosure = authenticationUIProviderClosure
    }
    
    
    // MARK: - LimeAuthActivationUIProvider
    
    public func instantiateInitialScene() -> BeginActivationViewController {
        guard let controller = storyboard.instantiateInitialViewController() as? BeginActivationViewController else {
            D.fatalError("Cannot instantiate Initial scene")
        }
        return controller
    }
    
    public func instantiateConfirmScene() -> ConfirmActivationViewController {
        guard let controller = storyboard.instantiateViewController(withIdentifier: "Confirm") as? ConfirmActivationViewController else {
            D.fatalError("Cannot instantiate Confirm scene")
        }
        return controller
    }
    
    public func instantiateScanCodeScene() -> ScanActivationCodeViewController {
        guard let controller = storyboard.instantiateViewController(withIdentifier: "ScanCode") as? ScanActivationCodeViewController else {
            D.fatalError("Cannot instantiate ScanCode scene")
        }
        return controller
    }
    
    public func instantiateEnterCodeScene() -> EnterActivationCodeViewController {
        guard let controller = storyboard.instantiateViewController(withIdentifier: "EnterCode") as? EnterActivationCodeViewController else {
            D.fatalError("Cannot instantiate EnterCode scene")
        }
        return controller
    }
    
    public func instantiateErrorScene() -> ErrorActivationViewController {
        guard let controller = storyboard.instantiateViewController(withIdentifier: "Error") as? ErrorActivationViewController else {
            D.fatalError("Cannot instantiate Error scene")
        }
        return controller
    }
    
    public func instantiateNavigationController(with rootController: UIViewController) -> UINavigationController? {
        return LimeAuthUINavigationController(rootViewController: rootController)
    }
    
    public var uiDataProvider: ActivationUIDataProvider {
        return self
    }
    
    private let authenticationUIProviderClosure: ()->AuthenticationUIProvider
    public lazy var authenticationUIProvider: AuthenticationUIProvider = {
        return authenticationUIProviderClosure()
    }()
    
    public var actionFeedback: LimeAuthActionFeedback? {
        return authenticationUIProvider.actionFeedback
    }
    
    //
    
    private var storyboard: UIStoryboard {
        return UIStoryboard(name: "Activation", bundle: bundle)
    }
    
    // MARK: - ActivationUIDataProvider

    public var uiTheme: LimeAuthActivationUITheme = .fallbackTheme()
    
    public lazy var uiCommonStrings: Activation.UIData.CommonStrings = {
        Activation.UIData.CommonStrings(
            okTitle: localization.localizedString("limeauth.common.ok"),
            cancelTitle: localization.localizedString("limeauth.common.cancel"),
            closeTitle: localization.localizedString("limeauth.common.close")
        )
    }()

    public lazy var uiDataForBeginActivation: BeginActivation.UIData = {
        BeginActivation.UIData(
            strings: BeginActivation.UIData.Strings(
                sceneTitle: localization.localizedString("limeauth.act.begin.title"),
                sceneDescription: localization.localizedString("limeauth.act.begin.description"),
                scanButton: localization.localizedString("limeauth.act.begin.scanButton"),
                enterButton: localization.localizedString("limeauth.act.begin.enterCodeButton")
            )
        )
    }()
    
    public lazy var uiDataForNoCameraAccess: NoCameraAccess.UIData = {
        NoCameraAccess.UIData(
            strings: NoCameraAccess.UIData.Strings(
                sceneTitle: localization.localizedString("limeauth.act.noCamera.title"),
                sceneDescription: localization.localizedString("limeauth.act.noCamera.description"),
                openSettingsButton: localization.localizedString("limeauth.act.noCamera.settingsButton")
            )
        )
    }()
    
    public lazy var uiDataForEnterActivationCode: EnterActivationCode.UIData = {
        EnterActivationCode.UIData(
            strings: EnterActivationCode.UIData.Strings(
                sceneTitle: localization.localizedString("limeauth.act.enterCode.title"),
                sceneDescription: localization.localizedString("limeauth.act.enterCode.description"),
                confirmButton: localization.localizedString("limeauth.act.enterCode.confirmButton")
            )
        )
    }()
    
    public lazy var uiDataForScanActivationCode: ScanActivationCode.UIData = {
        ScanActivationCode.UIData(
            strings: ScanActivationCode.UIData.Strings(
                sceneTitle: localization.localizedString("limeauth.act.scanCode.title"),
                enterCodeFallbackButton: localization.localizedString("limeauth.act.scanCode.fallbackButton")
            )
        )
    }()
    
    public lazy var uiDataForKeysExchange: KeysExchange.UIData = {
        KeysExchange.UIData(
            strings: KeysExchange.UIData.Strings(
                pendingActivationTitle: localization.localizedString("limeauth.act.keysExchange.inProgress")
            )
        )
    }()
    
    public lazy var uiDataForEnableBiometry: EnableBiometry.UIData = {
        EnableBiometry.UIData(
            strings: EnableBiometry.UIData.Strings(
                touchIdSceneTitle: localization.localizedString("limeauth.act.biometry.touchId.title"),
                touchIdDescription: localization.localizedString("limeauth.act.biometry.touchId.description"),
                enableTouchIdButton: localization.localizedString("limeauth.act.biometry.touchId.enableButton"),
                faceIdSceneTitle: localization.localizedString("limeauth.act.biometry.faceId.title"),
                faceIdDescription: localization.localizedString("limeauth.act.biometry.faceId.description"),
                enableFaceIdButton: localization.localizedString("limeauth.act.biometry.faceId.enableButton"),
                enableLaterButton: localization.localizedString("limeauth.act.biometry.enableLaterButton")
            )
        )
    }()
    
    public lazy var uiDataForConfirmActivation: ConfirmActivation.UIData = {
        ConfirmActivation.UIData(
            strings: ConfirmActivation.UIData.Strings(
                sceneTitle: localization.localizedString("limeauth.act.confirm.title"),
                sceneDescription: localization.localizedString("limeauth.act.confirm.description"),
                waitingLabel: localization.localizedString("limeauth.act.confirm.inProgress"),
                removeActivationButton: localization.localizedString("limeauth.act.confirm.cancelButton")
            ),
            errors: ConfirmActivation.UIData.Errors(
                activation: localization.localizedString("limeauth.err.activation"),
                activationRemoved: localization.localizedString("limeauth.err.activation.removed"),
                activationBlocked: localization.localizedString("limeauth.err.activation.blocked"),
                passwordSetupFailure: localization.localizedString("limeauth.err.activation.pinSetupFailure"),
                recoveryFailure: localization.localizedString("limeauth.err.activation.recoveryFailure")
            )
        )
    }()
    
    public lazy var uiDataForErrorActivation: ErrorActivation.UIData = {
        ErrorActivation.UIData(
            strings: ErrorActivation.UIData.Strings(
                sceneTitle: localization.localizedString("limeauth.act.error.title"),
                genericError: localization.localizedString("limeauth.err.activation")
            )
        )
    }()

    public func loadTheme(theme: LimeAuthActivationUITheme) {
        
        // Keep provided theme internally
        uiTheme = theme
        LimeAuthUIBaseViewController.commonPreferredStatusBarStyle = theme.common.statusBarStyle
        ScanActivationCodeViewController.preferredStatusBarStyleForScanner = theme.scannerScene.statusBarStyle
        
        // Apply changes to UIAppearance
        let appearanceNavBar = UINavigationBar.appearance(whenContainedInInstancesOf: [LimeAuthUINavigationController.self]);
        appearanceNavBar.barStyle = .blackOpaque
        appearanceNavBar.barTintColor = theme.navigationBar.backgroundColor
        appearanceNavBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: theme.navigationBar.titleColor]
        appearanceNavBar.tintColor = theme.navigationBar.tintColor
        
        let appearanceBarButton = UIBarButtonItem.appearance(whenContainedInInstancesOf: [LimeAuthUINavigationController.self])
        appearanceBarButton.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: theme.navigationBar.buttonColor], for: .normal)
    }
    
    
}

