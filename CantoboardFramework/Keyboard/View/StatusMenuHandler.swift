//
//  StatusMenuHandler.swift
//  CantoboardFramework
//
//  Created by Alex Man on 6/15/21.
//

import Foundation
import UIKit

protocol StatusMenuHandler: class {
    var delegate: KeyboardViewDelegate? { get set }
    var state: KeyboardState { get set }
    var statusMenu: StatusMenu? { get set }

    func layoutStatusMenu()
    func handleStatusMenu(from: UIView, with: UIEvent?) -> Bool
    func showStatusMenu()
    func hideStatusMenu()
}

extension StatusMenuHandler where Self: UIView {
    func layoutStatusMenu() {
        guard let statusMenu = statusMenu else { return }
        
        let size = statusMenu.intrinsicContentSize
        let origin = CGPoint(x: frame.width - size.width, y: LayoutConstants.forMainScreen.autoCompleteBarHeight)
        let frame = CGRect(origin: origin, size: size)
        statusMenu.frame = frame.offsetBy(dx: -StatusMenu.xInset, dy: 0)
    }
    
    func handleStatusMenu(from: UIView, with: UIEvent?) -> Bool {
        if let touch = with?.allTouches?.first, touch.view == from {
            switch touch.phase {
            case .began, .moved, .stationary:
                showStatusMenu()
                statusMenu?.touchesMoved([touch], with: with)
                return true
            case .ended:
                statusMenu?.touchesEnded([touch], with: with)
                hideStatusMenu()
                return false
            case .cancelled:
                statusMenu?.touchesCancelled([touch], with: with)
                hideStatusMenu()
                return false
            default: ()
            }
        } else {
            hideStatusMenu()
            return false
        }
        return statusMenu != nil
    }
    
    func showStatusMenu() {
        guard statusMenu == nil else { return }
        FeedbackProvider.softImpact.impactOccurred()
        
        var menuRows: [[KeyCap]] =  [
            [ .changeSchema(.yale), .changeSchema(.jyutping) ],
            [ .changeSchema(.cangjie), .changeSchema(.quick) ],
            [ .changeSchema(.mandarin), .changeSchema(.stroke) ],
        ]
        if state.activeSchema.supportMixedMode {
            menuRows[menuRows.count - 1].append(.switchToEnglishMode)
        }
        let statusMenu = StatusMenu(menuRows: menuRows)
        statusMenu.handleKey = delegate?.handleKey

        addSubview(statusMenu)
        self.statusMenu = statusMenu
    }
    
    func hideStatusMenu() {
        statusMenu?.removeFromSuperview()
    }
}
