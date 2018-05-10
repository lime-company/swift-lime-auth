//
// Copyright 2017 Lime - HighTech Solutions s.r.o.
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

open class RoundCornersButton: UIButton {
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius()
    }
    
    open override var isHighlighted: Bool {
        didSet {
            updateHighlightedBackground(isHighlighted)
        }
    }
    
    private var storedBackgroundColor: UIColor? = .clear
    
    open override var backgroundColor: UIColor? {
        didSet {
            storedBackgroundColor = backgroundColor
            updateHighlightedBackground(isHighlighted)
        }
    }
    
    /// Changes background color for highlighted button's state.
    @objc public dynamic var highlightedBackgroundColor: UIColor = .clear {
        didSet {
            updateHighlightedBackground(isHighlighted)
        }
    }
    
    /// Changes radius of border.
    @objc public dynamic var borderCornerRadius: CGFloat = 4.0 {
        didSet {
            updateCornerRadius()
        }
    }
    
    /// Changes width of border.
    @objc public dynamic var borderWidth: CGFloat = 2.0 {
        didSet {
            updateCornerRadius()
        }
    }
    
    /// Changes color of border. If not set, then contains `self.tintColor`
    @objc public dynamic var borderColor: UIColor {
        get {
            return storedBorderColor ?? tintColor
        }
        set {
            storedBorderColor = newValue
            updateCornerRadius()
        }
    }
    
    private var storedBorderColor: UIColor?
    
    /// Changes color of border in highlighted state. If not set, then contains `self.tintColor`
    @objc public dynamic var highlightedBorderColor: UIColor {
        get {
            return storedHighlightedColor ?? tintColor
        }
        set {
            storedHighlightedColor = newValue
            updateCornerRadius()
        }
    }
    
    private var storedHighlightedColor: UIColor?
    
    private func updateCornerRadius() {
        layer.cornerRadius = borderCornerRadius
        layer.borderColor = (isHighlighted ? highlightedBorderColor : borderColor).cgColor
        layer.borderWidth = borderWidth
    }
    
    private func updateHighlightedBackground(_ highlight: Bool) {
        super.backgroundColor = highlight ? highlightedBackgroundColor : storedBackgroundColor
        layer.borderColor = (highlight ? highlightedBorderColor : borderColor).cgColor
    }
    
}

