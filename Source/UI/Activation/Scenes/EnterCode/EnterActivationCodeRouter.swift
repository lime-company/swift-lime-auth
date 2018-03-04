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

public protocol EnterActivationCodeRoutingLogic {
    func routeToPreviousScene()
    func routeToKeyExchange(activationCode: String)
    
    func prepare(for segue: UIStoryboardSegue, sender: Any?)
}

public class EnterActivationCodeRouter: EnterActivationCodeRoutingLogic, ActivationProcessRouter {

    public weak var viewController: EnterActivationCodeViewController?
    public var activationProcess: ActivationProcess!

    public func routeToPreviousScene() {
        viewController?.navigationController?.popViewController(animated: true)
    }
    
    public func routeToKeyExchange(activationCode: String) {
        activationProcess?.activationData.activationCode = activationCode
        viewController?.performSegue(withIdentifier: "KeyExchange", sender: nil)
    }
    
    public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var destinationVC = segue.destination
        if let navigationVC = destinationVC as? UINavigationController, let first = navigationVC.viewControllers.first {
            destinationVC = first
        }
        if let activationVC = destinationVC as? ActivationProcessController {
            activationVC.connect(activationProcess: activationProcess)
        }
    }
    
}
