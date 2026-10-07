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

// Glassgram: the look of glass bubbles comes from GlassBubbleSettings
// (Settings → Glassgram), defaults are in GlassBubbleSettings.swift.

/// Bright edge of the glass: a white gradient visible only through the bubble outline.
private final class GlassRimView: NSView {
    let outline = SImageView()
    private let gradient = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.mask = outline.layer
        self.layer = gradient
        self.wantsLayer = true
        self.layer?.disableActions()
        outline.layer?.disableActions()
        apply(GlassBubbleSettings.current)
    }

    func apply(_ settings: GlassBubbleSettings) {
        gradient.colors = [
            NSColor(white: 1, alpha: settings.rimTopAlpha).cgColor,
            NSColor(white: 1, alpha: settings.rimMiddleAlpha).cgColor,
            NSColor(white: 1, alpha: settings.rimBottomAlpha).cgColor
        ]
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
    private var glassTint: NSColor?

    private var maskView: SImageView?

    init() {

        super.init(frame: NSZeroRect)
        autoresizingMask = []
        autoresizesSubviews = false
        wantsLayer = true
        self.layer?.masksToBounds = true
        self.addSubview(self.borderView)
        self.layer?.disableActions()
        NotificationCenter.default.addObserver(self, selector: #selector(glassSettingsDidChange), name: GlassBubbleSettings.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func glassSettingsDidChange() {
        guard glassView != nil, let tint = glassTint else {
            return
        }
        setGlass(tint: tint)
        rimView?.apply(GlassBubbleSettings.current)
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
            glassTint = tint
            glass.tintColor = tint.withAlphaComponent(GlassBubbleSettings.current.tintAlpha)
            layer?.backgroundColor = .clear
            backgroundContent?.isHidden = true
            updateRim()
            return true
        } else {
            glassView?.removeFromSuperview()
            glassView = nil
            glassTint = nil
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
