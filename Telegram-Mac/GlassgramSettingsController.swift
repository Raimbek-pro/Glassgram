//
//  GlassgramSettingsController.swift
//  Glassgram
//
//  Settings → Glassgram: live preview of two glass bubbles
//  and a slider for each GlassBubbleSettings value.
//

import Cocoa
import TGUIKit

/// One labeled slider: title on the left, percentage on the right, slider below.
private final class GlassSliderRow: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)

    var onChange: ((CGFloat) -> Void)?

    var value: CGFloat {
        get { CGFloat(slider.doubleValue) }
        set {
            slider.doubleValue = Double(newValue)
            updateValueLabel()
        }
    }

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.stringValue = title
        valueLabel.alignment = .right
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(slider)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    func updateTheme() {
        titleLabel.font = .normal(.title)
        titleLabel.textColor = theme.colors.text
        valueLabel.font = .normal(.text)
        valueLabel.textColor = theme.colors.grayText
        slider.trackFillColor = theme.colors.accent
    }

    @objc private func sliderChanged() {
        updateValueLabel()
        onChange?(value)
    }

    private func updateValueLabel() {
        valueLabel.stringValue = "\(Int((value * 100).rounded()))%"
    }

    override func layout() {
        super.layout()
        titleLabel.sizeToFit()
        valueLabel.sizeToFit()
        titleLabel.setFrameOrigin(NSMakePoint(0, 0))
        valueLabel.frame = NSMakeRect(frame.width - 60, 0, 60, valueLabel.frame.height)
        slider.frame = NSMakeRect(0, 24, frame.width, 24)
    }
}

final class GlassgramSettingsView: NSView, AppearanceViewProtocol {
    private let previewBackground = BackgroundView(frame: .zero)
    private let incomingBubble = ChatMessageBubbleBackdrop()
    private let outgoingBubble = ChatMessageBubbleBackdrop()
    private let incomingText = NSTextField(wrappingLabelWithString: "Have you seen the new glass bubbles?")
    private let outgoingText = NSTextField(wrappingLabelWithString: "Yes! Move the sliders below to tune them ✨")

    private let tintRow = GlassSliderRow(title: "Glass Tint")
    private let rimTopRow = GlassSliderRow(title: "Rim Brightness – Top")
    private let rimMiddleRow = GlassSliderRow(title: "Rim Brightness – Sides")
    private let rimBottomRow = GlassSliderRow(title: "Rim Brightness – Bottom")
    private let resetButton = NSButton(title: "Reset to Defaults", target: nil, action: nil)

    private var sliderRows: [GlassSliderRow] {
        return [tintRow, rimTopRow, rimMiddleRow, rimBottomRow]
    }

    var onChange: ((GlassBubbleSettings) -> Void)?

    private let previewHeight: CGFloat = 190
    private let sideInset: CGFloat = 20
    private let tailWidth: CGFloat = 7
    private let bubblePadding = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(previewBackground)
        addSubview(incomingBubble)
        addSubview(outgoingBubble)
        addSubview(incomingText)
        addSubview(outgoingText)
        for row in sliderRows {
            addSubview(row)
            row.onChange = { [weak self] _ in
                self?.slidersChanged()
            }
        }
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        addSubview(resetButton)
        updateLocalizationAndTheme(theme: theme)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    func set(settings: GlassBubbleSettings) {
        tintRow.value = settings.tintAlpha
        rimTopRow.value = settings.rimTopAlpha
        rimMiddleRow.value = settings.rimMiddleAlpha
        rimBottomRow.value = settings.rimBottomAlpha
    }

    private var currentSettings: GlassBubbleSettings {
        return GlassBubbleSettings(tintAlpha: tintRow.value,
                                   rimTopAlpha: rimTopRow.value,
                                   rimMiddleAlpha: rimMiddleRow.value,
                                   rimBottomAlpha: rimBottomRow.value)
    }

    private func slidersChanged() {
        onChange?(currentSettings)
    }

    @objc private func resetToDefaults() {
        set(settings: .defaults)
        onChange?(.defaults)
    }

    func updateLocalizationAndTheme(theme presentation: PresentationTheme) {
        previewBackground.backgroundMode = theme.backgroundMode

        configure(bubble: incomingBubble, text: incomingText, incoming: true)
        configure(bubble: outgoingBubble, text: outgoingText, incoming: false)

        for row in sliderRows {
            row.updateTheme()
        }
        needsLayout = true
    }

    private func configure(bubble: ChatMessageBubbleBackdrop, text: NSTextField, incoming: Bool) {
        let shape = incoming ? theme.icons.chatBubble_none_incoming_withInset : theme.icons.chatBubble_none_outgoing_withInset
        let gradient = incoming ? theme.icons.chatGradientBubble_incoming : theme.icons.chatGradientBubble_outgoing
        let color = theme.chat.bubbleBackgroundColor(incoming, true)

        bubble.setType(image: shape, border: nil, background: gradient)
        bubble.setRim(glassRimImage(incoming: incoming, neighbors: .none))
        if !bubble.setGlass(tint: color) {
            bubble.background = color
        }

        text.font = .normal(theme.fontSize)
        text.textColor = theme.chat.textColor(incoming, true)
    }

    /// Places a bubble with its text; returns the bubble height.
    private func layoutBubble(_ bubble: ChatMessageBubbleBackdrop, text: NSTextField, incoming: Bool, y: CGFloat) -> CGFloat {
        let maxTextWidth = min(300, frame.width - sideInset * 2 - 80)
        let textSize = text.cell?.cellSize(forBounds: NSMakeRect(0, 0, maxTextWidth, .greatestFiniteMagnitude)) ?? .zero
        let width = ceil(textSize.width) + bubblePadding.left + bubblePadding.right + tailWidth
        let height = max(ceil(textSize.height) + bubblePadding.top + bubblePadding.bottom, 36)
        let x = incoming ? sideInset : frame.width - sideInset - width

        bubble.frame = NSMakeRect(x, y, width, height)
        bubble.updateLayout(size: bubble.frame.size, transition: .immediate)

        let textX = x + bubblePadding.left + (incoming ? tailWidth : 0)
        text.frame = NSMakeRect(textX, y + floor((height - textSize.height) / 2), ceil(textSize.width), ceil(textSize.height))
        return height
    }

    override func layout() {
        super.layout()

        previewBackground.frame = NSMakeRect(0, 0, frame.width, previewHeight)
        previewBackground.updateLayout(size: previewBackground.frame.size, transition: .immediate)

        let incomingHeight = layoutBubble(incomingBubble, text: incomingText, incoming: true, y: 30)
        _ = layoutBubble(outgoingBubble, text: outgoingText, incoming: false, y: 30 + incomingHeight + 14)

        var y = previewHeight + 24
        for row in sliderRows {
            row.frame = NSMakeRect(sideInset, y, frame.width - sideInset * 2, 50)
            y += 64
        }

        resetButton.sizeToFit()
        resetButton.setFrameOrigin(NSMakePoint(floor((frame.width - resetButton.frame.width) / 2), y + 4))
    }
}

/// 24×24 Settings icon: blue-to-cyan rounded square with a white message bubble.
let glassgramSettingsIcon: CGImage = generateImage(NSMakeSize(24, 24), contextGenerator: { size, ctx in
    ctx.clear(CGRect(origin: .zero, size: size))

    let rect = CGRect(origin: .zero, size: size)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.clip()
    let colors = [NSColor(red: 0.0, green: 0.27, blue: 1.0, alpha: 1).cgColor,
                  NSColor(red: 0.35, green: 0.9, blue: 1.0, alpha: 1).cgColor] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
    }

    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 5, y: 7, width: 14, height: 10), cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.fillPath()
    ctx.move(to: CGPoint(x: 7, y: 8))
    ctx.addLine(to: CGPoint(x: 5, y: 4.5))
    ctx.addLine(to: CGPoint(x: 10, y: 7.5))
    ctx.closePath()
    ctx.fillPath()
}, scale: System.backingScale)!

final class GlassgramSettingsController: TelegramGenericViewController<GlassgramSettingsView> {

    override var defaultBarTitle: String {
        return "Glassgram"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.set(settings: GlassBubbleSettings.current)
        genericView.onChange = { settings in
            GlassBubbleSettings.current = settings
        }
        readyOnce()
    }
}
