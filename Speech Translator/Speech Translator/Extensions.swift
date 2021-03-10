//
//  Extensions.swift
//  Speech Translator
//
//  Created by Ivan Pedrero on 27/02/21.
//

import Foundation
import UIKit

extension UIView {
    func roundBorders(radius:CGFloat) {
        self.layer.cornerRadius = radius
    }
    
    func drawShadow(radius:CGFloat){
        self.layer.shadowRadius = radius
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = .zero
    }
}

extension UITextView {
    func disableEditing() {
        self.isEditable = false
        self.isUserInteractionEnabled = false
    }
    
    func enableEditing() {
        self.isEditable = true
        self.isUserInteractionEnabled = true
    }
}
