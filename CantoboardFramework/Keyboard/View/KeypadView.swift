//
//  KeyPadView.swift
//  CantoboardFramework
//
//  Created by Alex Man on 6/14/21.
//

import Foundation
import UIKit

struct KeypadButtonProps {
    var keyCap: KeyCap
    let colRowSize: CGSize
    
    init(keyCap: KeyCap, colRowSize: CGSize? = nil) {
        self.keyCap = keyCap
        self.colRowSize = colRowSize ?? CGSize(width: 1, height: 1)
    }
}

class KeypadView: UIView, InputView {
    weak var delegate: KeyboardViewDelegate?
    
    private let leftButtonProps: [[KeypadButtonProps]] = [
        [ KeypadButtonProps(keyCap: .keyboardType(.numeric)) ],
        [ KeypadButtonProps(keyCap: .switchToEnglishMode) ],
        [ KeypadButtonProps(keyCap: .keyboardType(.symbolic)) ],
        [ KeypadButtonProps(keyCap: .keyboardType(.emojis)) ],
    ]
    
    private let rightButtonProps: [[KeypadButtonProps]] = [
        [ KeypadButtonProps(keyCap: .stroke("h")),
          KeypadButtonProps(keyCap: .stroke("s")),
          KeypadButtonProps(keyCap: .stroke("p")),
          KeypadButtonProps(keyCap: .backspace) ],
        [ KeypadButtonProps(keyCap: .stroke("n")),
          KeypadButtonProps(keyCap: .stroke("z")),
          KeypadButtonProps(keyCap: "?") ],
        [ KeypadButtonProps(keyCap: ","), KeypadButtonProps(keyCap: "."), KeypadButtonProps(keyCap: "!"), KeypadButtonProps(keyCap: .returnKey(.default), colRowSize: CGSize(width: 1, height: 2)) ],
        [ KeypadButtonProps(keyCap: .space(.space), colRowSize: CGSize(width: 3, height: 1)) ],
    ]
    
    private weak var candidatePaneView: CandidatePaneView?
    internal weak var statusMenu: StatusMenu?
    
    private var touchHandler: TouchHandler!
    private var leftButtons: [[KeypadButton]] = []
    private var rightButtons: [[KeypadButton]] = []
    
    private var candidateOrganizer: CandidateOrganizer
    private var _state: KeyboardState
    var state: KeyboardState {
        get { _state }
        set { changeState(prevState: _state, newState: newValue) }
    }
    
    init(state: KeyboardState, candidateOrganizer: CandidateOrganizer) {
        self._state = state
        self.candidateOrganizer = candidateOrganizer
        super.init(frame: .zero)
        
        backgroundColor = .clearInteractable
        insetsLayoutMarginsFromSafeArea = false
        isMultipleTouchEnabled = true
        preservesSuperviewLayoutMargins = false
        
        initView()
        touchHandler = TouchHandler(keyboardView: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("NSCoder is not supported")
    }
    
    private func initView() {
        leftButtons = initButtons(buttonLayouts: leftButtonProps)
        rightButtons = initButtons(buttonLayouts: rightButtonProps)
        
        let candidatePaneView = CandidatePaneView(keyboardState: state, candidateOrganizer: candidateOrganizer)
        candidatePaneView.delegate = self
        addSubview(candidatePaneView)
        self.candidatePaneView = candidatePaneView
    }
    
    private func initButtons(buttonLayouts: [[KeypadButtonProps]]) -> [[KeypadButton]] {
        var buttons: [[KeypadButton]] = []
        var x: CGFloat = 0, y: CGFloat = 0
        for row in buttonLayouts {
            var buttonRow: [KeypadButton] = []
            for props in row {
                let button = KeypadButton(props: props, colRowOrigin: CGPoint(x: x, y: y), colRowSize: props.colRowSize)
                addSubview(button)
                buttonRow.append(button)
                x += 1
            }
            buttons.append(buttonRow)
            y += 1
        }
        return buttons
    }
    
    private func setupButtons() {
        let isFullShape = state.keyboardContextualType == .chinese
        for row in rightButtons {
            for button in row {
                var props = button.props
                switch props.keyCap.action {
                case ",", "，": props.keyCap = isFullShape ? "，" : ","
                case ".", "。": props.keyCap = isFullShape ? "。" : "."
                case "?", "？": props.keyCap = isFullShape ? "？" : "?"
                case "!", "！": props.keyCap = isFullShape ? "！" : "!"
                default: ()
                }
                button.keyCap = props.keyCap
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let layoutConstants = LayoutConstants.forMainScreen
        layoutButtons(leftButtons, initialX: layoutConstants.edgeHorizontalInset, layoutConstants: layoutConstants)
        layoutButtons(rightButtons, initialX: layoutConstants.edgeHorizontalInset + layoutConstants.buttonGap + layoutConstants.keypadButtonUnitSize.width, layoutConstants: layoutConstants)
        
        layoutCandidateSubviews(layoutConstants)
        layoutStatusMenu()
    }
    
    private func layoutButtons(_ buttons: [[KeypadButton]], initialX: CGFloat, layoutConstants: LayoutConstants) {
        var x: CGFloat = initialX, y: CGFloat = LayoutConstants.keyViewTopInset + layoutConstants.autoCompleteBarHeight
        
        for row in buttons {
            x = initialX
            for button in row {
                let origin = CGPoint(x: x, y: y)
                let size = button.getSize(layoutConstants: layoutConstants)
                button.frame = CGRect(origin: origin, size: size)
                x += size.width + layoutConstants.buttonGap
            }
            y += layoutConstants.keypadButtonUnitSize.height + layoutConstants.buttonGap
        }
    }

    private func changeState(prevState: KeyboardState, newState: KeyboardState) {
        let isViewDirty = prevState.keyboardContextualType != newState.keyboardContextualType
        
        _state = newState
        if isViewDirty { setupButtons() }
        
        candidatePaneView?.keyboardState = state
    }
    
    private func layoutCandidateSubviews(_ layoutConstants: LayoutConstants) {
        guard let candidatePaneView = candidatePaneView else { return }
        let height = candidatePaneView.mode == .row ? layoutConstants.autoCompleteBarHeight : bounds.height
        candidatePaneView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: height))
    }
    
    func candidatePanescrollToNextPageInRowMode() {
        candidatePaneView?.scrollToNextPageInRowMode()
    }
}

extension KeypadView: CandidatePaneViewDelegate, StatusMenuHandler {
    func candidatePaneViewCandidateSelected(_ choice: IndexPath) {
        delegate?.handleKey(.selectCandidate(choice))
    }
    
    func candidatePaneViewExpanded() {
        setNeedsLayout()
        refreshButtonsVisibility(buttons: leftButtons)
        refreshButtonsVisibility(buttons: rightButtons)
    }
    
    func candidatePaneViewCollapsed() {
        setNeedsLayout()
        refreshButtonsVisibility(buttons: leftButtons)
        refreshButtonsVisibility(buttons: rightButtons)
    }
    
    private func refreshButtonsVisibility(buttons: [[KeypadButton]]) {
        let isButtonVisible = candidatePaneView?.mode ?? .row == .row
        
        buttons.forEach({
            $0.forEach({ b in
                b.isHidden = !isButtonVisible
            })
        })
    }
    
    func candidatePaneCandidateLoaded() {
    }
    
    func handleKey(_ action: KeyboardAction) {
        // if case .keyboardType(.alphabetic) = action, case .alphabetic = state.keyboardType {
        delegate?.handleKey(action)
    }
}

extension KeypadView {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first,
              let keypadButton = touch.view as? KeypadButton else { return }
        
        touchHandler.touchBegan(touch, key: keypadButton, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first,
              let keypadButton = touch.view as? KeypadButton else { return }
        
        touchHandler.touchMoved(touch, key: keypadButton, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first,
              let keypadButton = touch.view as? KeypadButton else { return }
        
        touchHandler.touchEnded(touch, key: keypadButton, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let touch = touches.first else { return }
        
        touchHandler.touchCancelled(touch, with: event)
    }
}
