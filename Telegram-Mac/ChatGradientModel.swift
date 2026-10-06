//
//  ChatGradientModel.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

private let maskInset: CGFloat = 1.0

// Glassgram: tweak the glass bubble look here.
private let glassTintAlpha: CGFloat = 0.25      // 0 = colorless glass, 1 = solid theme color
private let glassRimTopAlpha: CGFloat = 0.95    // rim brightness at the top edge
private let glassRimMiddleAlpha: CGFloat = 0.2  // rim brightness on the sides
private let glassRimBottomAlpha: CGFloat = 0.55 // rim brightness at the bottom edge

/// Bright edge of the glass: a white gradient visible only through the bubble outline.
private final class GlassRimView: NSView {
    let outline = SImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(white: 1, alpha: glassRimTopAlpha).cgColor,
            NSColor(white: 1, alpha: glassRimMiddleAlpha).cgColor,
            NSColor(white: 1, alpha: glassRimBottomAlpha).cgColor
        ]
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.mask = outline.layer
        self.layer = gradient
        self.wantsLayer = true
        self.layer?.disableActions()
        outline.layer?.disableActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        outline.frame = bounds
    }
}


final class ChatMessageBubbleBackdrop: NSView {
    private var backgroundContent: NSView?
    private let borderView: SImageView = SImageView()
    private var currentMaskMode: Bool?
    private var glassView: NSView?
    private var rimView: GlassRimView?
    private var rimImage: (CGImage, NSEdgeInsets)?

    private var maskView: SImageView?
    
    init() {
        
        super.init(frame: NSZeroRect)
        autoresizingMask = []
        autoresizesSubviews = false
        wantsLayer = true
        self.layer?.masksToBounds = true
        self.addSubview(self.borderView)
        self.layer?.disableActions()
    }
    
    /// Returns true if glass is active (macOS 26+).
    @discardableResult
    func setGlass(tint: NSColor?) -> Bool {
        if #available(macOS 26.0, *), let tint {
            let glass: NSGlassEffectView
            if let current = glassView as? NSGlassEffectView {
                glass = current
            } else {
                glass = NSGlassEffectView(frame: bounds)
                // No own corners: the bubble mask cuts the exact shape, tail included.
                glass.cornerRadius = 0
                glass.style = .clear
                addSubview(glass, positioned: .below, relativeTo: subviews.first)
                glassView = glass
            }
            glass.tintColor = tint.withAlphaComponent(glassTintAlpha)
            layer?.backgroundColor = .clear
            backgroundContent?.isHidden = true
            updateRim()
            return true
        } else {
            glassView?.removeFromSuperview()
            glassView = nil
            backgroundContent?.isHidden = false
            updateRim()
            return false
        }
    }

    func setRim(_ image: (CGImage, NSEdgeInsets)?) {
        rimImage = image
        updateRim()
    }

    private func updateRim() {
        if let glass = glassView, let image = rimImage {
            let rim: GlassRimView
            if let current = rimView {
                rim = current
            } else {
                rim = GlassRimView(frame: bounds)
                addSubview(rim, positioned: .above, relativeTo: glass)
                rimView = rim
            }
            rim.outline.data = image
        } else {
            rimView?.removeFromSuperview()
            rimView = nil
        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        if let view = maskView {
            transition.updateFrame(view: view, frame: size.bounds)
        }
        // added frame
        glassView?.frame = size.bounds
        rimView?.frame = size.bounds
        transition.updateFrame(view: borderView, frame: size.bounds)
    }
    
    func setType(image: (CGImage, NSEdgeInsets)?, border: (CGImage, NSEdgeInsets)?, background: CGImage) {
        if let _ = image {
            let maskView: SImageView
            if let current = self.maskView {
                maskView = current
            } else {
                maskView = SImageView()
                maskView.frame = self.bounds
                self.maskView?.layer?.disableActions()
                self.maskView = maskView
                self.layer?.mask = maskView.layer
            }
        } else {
            if let _ = self.maskView {
                self.layer?.mask = nil
                self.maskView = nil
            }
        }
        self.borderView.data = border
        if image == nil {
            if let view = self.backgroundContent {
                performSubviewRemoval(view, animated: false)
            }
            self.backgroundContent = nil
        } else {
            let current: NSView
            if let view = self.backgroundContent {
                current = view
            } else {
                current = NSView()
                current.wantsLayer = true
                current.isHidden = glassView != nil
                self.backgroundContent = current
                addSubview(current, positioned: .below, relativeTo: self.borderView)
            }
            current.layer?.contents = background
        }
        
        if let maskView = self.maskView {
            maskView.data = image
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition, rotated: Bool = false) {
        
        if let backgroundContent = backgroundContent {
            transition.updateFrame(view: backgroundContent, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize))
        }

        if rotated {
            backgroundContent?.rotate(byDegrees: 180)
        } else {
            backgroundContent?.rotate(byDegrees: 0)
        }
    }
}
