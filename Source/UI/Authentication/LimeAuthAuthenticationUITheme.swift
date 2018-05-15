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

public struct LimeAuthAuthenticationUITheme {
    
    public struct Common {
        
        /// Common background color for all authentication scenes.
        /// You can choose between `backgroundColor` or `backgroundImage`, or use both.
        public var backgroundColor: UIColor?
        
        /// Common background image for all authentication scenes.
        /// You can choose between `backgroundColor` or `backgroundImage`, or use both.
        public var backgroundImage: LazyUIImage?
		
		/// Color for all prompts in authentication scenes (e.g. "Enter your PIN").
		public var promptTextColor: UIColor
		
		/// Highlighted color for "remaining attempts" error, or for errors related to creating a new password.
		public var highlightedTextColor: UIColor
		
		/// Color for password label or text field.
		public var passwordTextColor: UIColor
		
		/// Color temporariliy presented to password label (or text field) when user enters a wrong PIN.
		public var wrongPasswordTextColor: UIColor
		
        /// Style applied to all activity indicators
        public var activityIndicator: ActivityIndicatorStyle
        
        /// Style for password text field
        public var passwordTextField: TextFieldStyle
		
		/// Status bar style for all authentication scenes.
		/// Note that your application has to support "ViewController based" status bar appearance.
		public var statusBarStyle: UIStatusBarStyle
    }
    
    public struct Images {
        
        /// Logo displayed in pin keyboards
        public var logo: LazyUIImage?
        
        /// Image displayed when entered password is correct
        public var successImage: LazyUIImage
        
        /// Image displayed in case of error
        public var failureImage: LazyUIImage
        
        /// Touch ID icon for PIN keyboard's biometry button
        public var touchIdIcon: LazyUIImage
        
        /// Face ID icon for PIN keyboard's biometry button
        public var faceIdIcon: LazyUIImage
    }
    
    public struct Buttons {
        
        /// Style for all digits on PIN keyboard. This kind of button is typically instantiated as "custom".
        public var pinDigits: ButtonStyle
        
        /// Style for all auxiliary buttons (backspace, cancel, etc...) on PIN keyboard.
		/// This kind of button is typically instantiated as "custom".
        public var pinAuxiliary: ButtonStyle
        
        /// "OK" button used in scene with variable PIN length, or in alphanumeric password.
		/// This kind of button is typically instantiated as "custom".
        public var ok: ButtonStyle
        
        /// A "Close / Cancel" button used typically on alphanumeric password picker.
		/// This kind of button is typically instantiated as "system".
        public var close: ButtonStyle
		
		/// A "Close error" button, used after authentication operation fails
		/// This kind of button is typically instantiated as "custom".
		public var dismissError: ButtonStyle
        
        /// Style for button embededd in keyboard's accessory view. This button is typically
        /// used when a new alphanumeric password is going to be created ("Choose password complexity"),
        /// or as biometry button on alphanumeric password picker ("Use Touch ID / Use Face ID")
		/// This kind of button is typically instantiated as "system".
		public var keyboardAuxiliary: ButtonStyle
    }
    
    public var common: Common
    public var images: Images
    public var buttons: Buttons
    
    
    /// Function provides a fallback theme used internally, for theme initial values.
    public static func fallbackTheme() -> LimeAuthAuthenticationUITheme {
        return LimeAuthAuthenticationUITheme(
            common: Common(
                backgroundColor: .white,
                backgroundImage: nil,
				promptTextColor: .black,
				highlightedTextColor: .purple,
				passwordTextColor: .black,
				wrongPasswordTextColor: .red,
                activityIndicator: .small(.blue),
                passwordTextField: .noStyle,
				statusBarStyle: .default
            ),
            images: Images(
                logo: nil,
                successImage: .empty,
                failureImage: .empty,
                touchIdIcon: .empty,
                faceIdIcon: .empty
            ),
            buttons: Buttons(
                pinDigits: .noStyle,
                pinAuxiliary: .noStyle,
                ok: .noStyle,
                close: .noStyle,
				dismissError: .noStyle,
                keyboardAuxiliary: .noStyle
            )
        )
    }
}

internal extension LimeAuthAuthenticationUITheme {
    
	var styleForCheckmarkWithActivity: CheckmarkWithActivityStyle {
		return CheckmarkWithActivityStyle(
			indicatorStyle: common.activityIndicator,
			successImage: images.successImage,
			failureImage: images.failureImage
		)
	}
    
    var layerStyleFromPasswordTextField: GenericLayerStyle? {
        guard let borderColor = common.passwordTextField.borderColor else {
            return nil
        }
        guard common.passwordTextField.borderWidth <= 0.0 else {
            return nil
        }
        return GenericLayerStyle(
            borderWidth: common.passwordTextField.borderWidth,
            cornerRadius: common.passwordTextField.borderCornerRadius,
            borderColor: borderColor
        )
    }
}
