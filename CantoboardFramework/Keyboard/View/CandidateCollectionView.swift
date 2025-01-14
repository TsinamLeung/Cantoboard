//
//  CandidateCollectionView.swift
//  CantoboardFramework
//
//  Created by Alex Man on 3/25/21.
//

import Foundation
import UIKit

protocol CandidateCollectionViewDelegate: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didLongPressItemAt indexPath: IndexPath)
}

class CandidateCollectionViewFlowLayout: UICollectionViewFlowLayout {
    private weak var candidatePaneView: CandidatePaneView?
    
    init(candidatePaneView: CandidatePaneView) {
        self.candidatePaneView = candidatePaneView
        super.init()
        sectionHeadersPinToVisibleBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        var contentSize = super.collectionViewContentSize
        let segmentControlHeight = LayoutConstants.forMainScreen.autoCompleteBarHeight
        if let collectionView = collectionView,
           let candidatePaneView = candidatePaneView,
           candidatePaneView.mode == .table && candidatePaneView.groupByEnabled &&
           contentSize.height <= collectionView.bounds.height + segmentControlHeight {
            // Expand the content size to let user to scroll upward to see the segment control.
            contentSize.height = collectionView.bounds.height + segmentControlHeight
        }
        return contentSize
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let allAttributes = super.layoutAttributesForElements(in: rect) ?? []
        
        for attributes in allAttributes {
            if attributes.representedElementKind == UICollectionView.elementKindSectionHeader {
                fixHeaderPosition(attributes)
            }
        }
        
        return allAttributes
    }
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)
        if let attributes = attributes, elementKind == UICollectionView.elementKindSectionHeader {
            fixHeaderPosition(attributes)
        }
        return attributes
    }
    
    private func fixHeaderPosition(_ headerAttributes: UICollectionViewLayoutAttributes) {
        guard let candidatePaneView = candidatePaneView,
              let collectionView = collectionView
            else { return }
        
        let section = headerAttributes.indexPath.section
        guard section < collectionView.numberOfSections else { return }
        
        var headerSize = CGSize(width: candidatePaneView.sectionHeaderWidth, height: LayoutConstants.forMainScreen.autoCompleteBarHeight)
        let numOfItemsInSection = collectionView.numberOfItems(inSection: section)
        var origin = headerAttributes.frame.origin
        if numOfItemsInSection > 0,
           let rectOfLastItemInSection = layoutAttributesForItem(at: [section, numOfItemsInSection - 1]) {
            origin.y = min(origin.y, rectOfLastItemInSection.frame.maxY - headerSize.height)
            // Expand the header to cover the whole section vertically.
            headerSize.height = rectOfLastItemInSection.frame.maxY - origin.y
        }
        headerAttributes.frame = CGRect(origin: origin, size: headerSize)
    }
}

// This is the UICollectionView inside CandidatePaneView.
class CandidateCollectionView: UICollectionView {
    private static let longPressDelay: Double = 1
    private static let longPressMovement: CGFloat = 10
    
    var scrollOnLayoutSubviews: (() -> Bool)?
    var didLayoutSubviews: ((UICollectionView) -> Void)?
    
    private var longPressTimer: Timer?
    private var cancelTouch: UITouch?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if scrollOnLayoutSubviews?() ?? false {
            scrollOnLayoutSubviews = nil
        }
        
        didLayoutSubviews?(self)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previousTraitCollection = previousTraitCollection,
              traitCollection.verticalSizeClass != previousTraitCollection.verticalSizeClass ||
              traitCollection.horizontalSizeClass != previousTraitCollection.horizontalSizeClass else {
                return
        }
        
        // Invalidate layout to resize cells.
        collectionViewLayout.invalidateLayout()
    }
    
    @objc private func onLongPress(longPressTouch: UITouch, longPressBeginPoint: CGPoint) {
        if longPressTouch.force >= longPressTouch.maximumPossibleForce * 0.75,
           let d = delegate as? CandidateCollectionViewDelegate,
           longPressBeginPoint.distanceTo(longPressTouch.location(in: self)).isLessThanOrEqualTo(Self.longPressMovement),
           let indexPath = indexPathForItem(at: longPressBeginPoint) {
            d.collectionView(self, didLongPressItemAt: indexPath)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        longPressTimer?.invalidate()
        
        guard let longPressTouch = touches.first else { return }
        let longPressBeginPoint = longPressTouch.location(in: self)
        
        longPressTimer = Timer.scheduledTimer(withTimeInterval: Self.longPressDelay, repeats: false) { [weak self] timer in
            guard let self = self, self.longPressTimer == timer else { return }
            self.onLongPress(longPressTouch: longPressTouch, longPressBeginPoint: longPressBeginPoint)
            self.longPressTimer = nil
            self.cancelTouch = longPressTouch
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        var touches = touches
        if let cancelTouch = cancelTouch {
            touches.remove(cancelTouch)
        }
        super.touchesEnded(touches, with: event)
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    func reloadCandidates() {
        reloadData()
        
        guard numberOfSections > 1 else { return }
        
        let visibleCellCounts = min(indexPathsForVisibleItems.count, dataSource?.collectionView(self, numberOfItemsInSection: 1) ?? 0)
        // For some reason, sometimes willDisplayCell isn't called for the first few visible cells.
        // Manually refreshing them to workaround the bug.
        reloadItems(at: (0..<visibleCellCounts).map({ [1, $0] }))
    }
}

class CandidateCell: UICollectionViewCell {
    static var reuseId: String = "CandidateCell"
    static let margin = UIEdgeInsets(top: 3, left: 8, bottom: 0, right: 8)
    
    var showComment: Bool = false
    
    weak var label: UILabel?
    weak var keyHintLayer: KeyHintLayer?
    weak var commentLayer: CATextLayer?
    
    // Uncomment this to debug memory leak.
    private let c = InstanceCounter<CandidateCell>()
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
    }
    
    func setup(_ text: String, _ comment: String?, showComment: Bool) {
        let layoutConstants = LayoutConstants.forMainScreen
        self.showComment = showComment
        
        if label == nil {
            let label = UILabel()
            label.textAlignment = .center
            label.baselineAdjustment = .alignBaselines
            label.isUserInteractionEnabled = false

            self.contentView.addSubview(label)
            self.label = label
        }
        
        label?.text = text
        
        let keyCap = KeyCap(stringLiteral: text)
        if let hintText = keyCap.barHint {
            if keyHintLayer == nil {
                let keyHintLayer = KeyHintLayer()
                self.keyHintLayer = keyHintLayer
                layer.addSublayer(keyHintLayer)
                keyHintLayer.layoutSublayers()
                keyHintLayer.foregroundColor = label?.textColor.resolvedColor(with: traitCollection).cgColor
            }
            
            keyHintLayer?.setup(keyCap: keyCap, hintText: hintText)
        }
        
        if showComment, let comment = comment {
            if commentLayer == nil {
                let commentLayer = CATextLayer()
                self.commentLayer = commentLayer
                layer.addSublayer(commentLayer)
                commentLayer.alignmentMode = .center
                commentLayer.allowsFontSubpixelQuantization = true
                commentLayer.contentsScale = UIScreen.main.scale
                commentLayer.foregroundColor = label?.textColor.resolvedColor(with: traitCollection).cgColor
            }
            commentLayer?.font = UIFont.systemFont(ofSize: layoutConstants.candidateCommentFontSize)
            commentLayer?.fontSize = layoutConstants.candidateCommentFontSize
            commentLayer?.string = comment
        } else {
            commentLayer?.removeFromSuperlayer()
            commentLayer = nil
        }
        
        layout(bounds)
    }
    
    func free() {
        label?.text = nil
        label?.removeFromSuperview()
        label = nil
        
        keyHintLayer?.removeFromSuperlayer()
        keyHintLayer = nil
        
        commentLayer?.removeFromSuperlayer()
        commentLayer = nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        layout(layoutAttributes.bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        keyHintLayer?.layout(insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
    }
    
    private func layout(_ bounds: CGRect) {
        let layoutConstants = LayoutConstants.forMainScreen
        let fontSizeScale = Settings.cached.candidateFontSize.scale

        label?.font = UIFont.systemFont(ofSize: layoutConstants.candidateFontSize * fontSizeScale)
        commentLayer?.font = UIFont.systemFont(ofSize: layoutConstants.candidateCommentFontSize)
        commentLayer?.fontSize = layoutConstants.candidateCommentFontSize
        
        if showComment && commentLayer != nil {
            let margin = Self.margin
            let textFrame = CGRect(x: 0, y: margin.top, width: bounds.width, height: layoutConstants.candidateCharSize.height)
            
            self.label?.frame = textFrame
            let commentHeight = layoutConstants.candidateCommentCharSize.height
            commentLayer?.frame = CGRect(x: 0, y: bounds.height - commentHeight - margin.bottom, width: bounds.width, height: commentHeight)
        } else {
            self.label?.frame = bounds
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if let keyHintLayer = keyHintLayer {
            keyHintLayer.foregroundColor = label?.textColor.resolvedColor(with: traitCollection).cgColor
        }
        if let commentLayer = commentLayer {
            commentLayer.foregroundColor = label?.textColor.resolvedColor(with: traitCollection).cgColor
        }
    }
}

class CandidateSegmentControlCell: UICollectionViewCell {
    static var reuseId: String = "CandidateGroupBySegmentControl"
    private static let inset = UIEdgeInsets(top: 6, left: 8, bottom: 8, right: 12)
    
    weak var segmentControl: UISegmentedControl?
    var groupByModes: [GroupByMode]?
    var onSelectionChanged: ((_ groupByMode: GroupByMode) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    func setup(groupByModes: [GroupByMode], selectedGroupByMode: GroupByMode, onSelectionChanged: ((_ groupByMode: GroupByMode) -> Void)?) {
        self.onSelectionChanged = onSelectionChanged
        
        if segmentControl == nil {
            let segmentControl = UISegmentedControl()
            addSubview(segmentControl)
            segmentControl.addTarget(self, action: #selector(onSegmentControlChange), for: .valueChanged)
            self.segmentControl = segmentControl
        }
        
        guard let segmentControl = segmentControl, segmentControl.numberOfSegments != groupByModes.count else { return }
        
        UIView.performWithoutAnimation {
            segmentControl.removeAllSegments()
            self.groupByModes = groupByModes
            for i in 0..<groupByModes.count {
                segmentControl.insertSegment(withTitle: groupByModes[i].title, at: i, animated: false)
                if groupByModes[i] == selectedGroupByMode {
                    segmentControl.selectedSegmentIndex = i
                }
            }
        }
    }
    
    func update(selectedGroupByMode: GroupByMode) {
        guard let groupByModes = groupByModes else { return }
        for i in 0..<groupByModes.count {
            if groupByModes[i] == selectedGroupByMode {
                UIView.performWithoutAnimation {
                    segmentControl?.selectedSegmentIndex = i
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        layout(layoutAttributes.bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout(bounds)
    }
    
    private func layout(_ bounds: CGRect) {
        segmentControl?.frame = bounds.inset(by: Self.inset)
    }
    
    @objc private func onSegmentControlChange() {
        guard let segmentControl = segmentControl,
              let selectedGroupByMode = groupByModes?[safe: segmentControl.selectedSegmentIndex]
              else { return }
        
        onSelectionChanged?(selectedGroupByMode)
    }
}

class CandidateSectionHeader: UICollectionReusableView {
    static var reuseId: String = "CandidateSectionHeader"
    weak var textLayer: UILabel?
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        backgroundColor = ButtonColor.systemKeyBackgroundColor
    }
    
    func setup(_ text: String, autoSize: Bool) {
        if textLayer == nil {
            let textLayer = UILabel()
            self.textLayer = textLayer
            addSubview(textLayer)
            textLayer.textAlignment = .center
            textLayer.baselineAdjustment = .alignCenters
            textLayer.adjustsFontSizeToFitWidth = autoSize
            textLayer.font = UIFont.systemFont(ofSize: autoSize ? UIFont.labelFontSize : LayoutConstants.forMainScreen.candidateFontSize + 2)
        }
        
        textLayer?.text = text
        
        layout(bounds)
    }
    
    func free() {
        textLayer?.removeFromSuperview()
        textLayer = nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        layout(layoutAttributes.bounds)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout(bounds)
    }
    
    private func layout(_ bounds: CGRect) {
        let layoutConstants = LayoutConstants.forMainScreen
        let size = CGSize(width: bounds.width, height: layoutConstants.autoCompleteBarHeight)
        textLayer?.frame = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 0)
    }
}
