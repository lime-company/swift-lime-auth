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

public class NoCameraAccessViewController: UIViewController, ActivationProcessController {
    
    // MARK: - Object lifecycle
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        let viewController = self
        let router = NoCameraAccessRouter()
        router.viewController = self
        viewController.router = router
    }
    
    // MARK: - View lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let _ = router?.activationProcess else {
            fatalError("NoCameraAccessViewController is not configured properly.")
        }
        
        prepareUI()
    }
    
    // MARK: - Routing
    
    public var router: (NoCameraAccessRoutingLogic & ActivationProcessRouter)!
    
    public func connect(activationProcess process: ActivationProcess) {
        router?.activationProcess = process
    }
    
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        router?.prepare(for: segue, sender: sender)
    }
 
    
    // MARK: - Interactions
    
    @IBAction func openSettingsAction(_ sender: Any) {
        openSettings()
    }

    @IBAction func closeSceneAction(_ sender: Any) {
        closeScene()
    }

    public func openSettings() {
        router?.routeToSystemSettings()
    }
    
    public func closeScene() {
        router?.routeToPreviousScene()
    }
    
    
    // MARK: - Presentation
    
    @IBOutlet weak var sceneTitleLabel: UILabel?
    @IBOutlet weak var sceneDescriptionLabel: UILabel?
    @IBOutlet weak var promoImageView: UIImageView?
    @IBOutlet weak var openSettingsButton: UIButton?
    @IBOutlet weak var closeSceneButton: UIButton?
    
    // MARK: -
    
    open func prepareUI() {
        let uiData = router.activationProcess.uiDataForNoCameraAccess
        let commonStrings = router.activationProcess.uiCommonStrings
        
        promoImageView?.image = uiData.images.noAccess.image
        sceneTitleLabel?.text = uiData.strings.sceneTitle
        sceneDescriptionLabel?.text = uiData.strings.sceneDescription
        openSettingsButton?.setTitle(uiData.strings.openSettingsButton, for: .normal)
        closeSceneButton?.setTitle(commonStrings.closeTitle, for: .normal)
    }
    
}
