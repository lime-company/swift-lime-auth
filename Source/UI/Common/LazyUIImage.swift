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

/// The `LazyUIImage` class provides an interface for lazy `UIImage` construction.
/// The actual image is constructed on demand, when `image` or `optionalImage`
/// property is used.
public class LazyUIImage {
    
    private let construction: (()->UIImage?)?
    
    // MARK: - Construction
    
    /// Constrruction with autoclosure
    public init(image: @escaping @autoclosure () -> UIImage?) {
        construction = image
    }

    /// Constructs an lazy image with closure, which will later provide
    /// an actual UIImage
    public init(closure: @escaping ()->UIImage?) {
        construction = closure
    }
    
    /// Constructs an empty object, which will later provide an empty UIImage.
    public init() {
        construction = nil
    }
    
    // MARK: - Properties
    
    /// Contains an image provided by construction closure. If closure is not set,
    /// or it doesn't provide image, then simply empty `UIImage` object is returned.
    public var image: UIImage {
        if let image = construction?() {
            return image
        }
        return UIImage()
    }
    
    /// Contains an image provided by construction closure or nil if image cannot
    /// be constructed.
    public var optionalImage: UIImage? {
        return construction?()
    }
    
    // MARK: - Static functions
    
    /// Returns `LazyUIImage` object which will construct a named image from given bundle.
    /// If bundle parameter is nil, then `Bundle.main` is used.
    public static func named(_ name: String, bundle: Bundle? = nil) -> LazyUIImage {
        return LazyUIImage { ()->UIImage? in
            if let bundle = bundle {
                return UIImage(named: name, in: bundle, compatibleWith: nil)
            } else {
                return UIImage(named: name)
            }
        }
    }
    
    /// Returns `LazyUIImage` object
    public static func build(_ closure: @escaping ()->UIImage?) -> LazyUIImage {
        return LazyUIImage(closure: closure)
    }
    
    /// Contains empty `LazyUIImage`. This kind of lazy image doesn't provide UIImage at all, so it will
    /// be ignored when it's applied to `UIImageView`
    public static let empty = LazyUIImage()
    
    /// Contains `LazyUIImage` which always produces an empty UIImage. Unlike `.empty` constant, this
    /// image will be always applied to `UIImageView`.
    public static let none = LazyUIImage { return UIImage() }
    
    /// Returns a lazy image constructed from another one, but tinted with provided color.
    public static func tinted(_ image: LazyUIImage, with color: UIColor) -> LazyUIImage {
        return LazyUIImage {
            guard let image = image.optionalImage else {
                return nil
            }
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            let rect = CGRect(origin: CGPoint.zero, size: image.size)
            color.setFill()
            image.draw(in: rect)
            context.setBlendMode(.sourceIn)
            context.fill(rect)
            let tintedImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return tintedImage
        }
    }
}
