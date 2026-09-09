//
//  TerminalModels.swift
//  DnDTextRPG
//
//  Models for the terminal display
//

import SwiftUI

// MARK: - Terminal Line

struct TerminalLine: Identifiable {
    let id = UUID()
    var text: String
    var color: TerminalColor
    let isBold: Bool
    let isUnderlined: Bool
    let fontSize: CGFloat
    let isCentered: Bool

    init(_ text: String, color: TerminalColor = .green, bold: Bool = false, underlined: Bool = false, size: CGFloat = 14, centered: Bool = false) {
        self.text = text
        self.color = color
        self.isBold = bold
        self.isUnderlined = underlined
        self.fontSize = size
        self.isCentered = centered
    }
}

enum TerminalColor {
    case green
    case brightGreen
    case dimGreen
    case red
    case yellow
    case cyan
    case magenta
    case white
    case gray
    case orange

    var swiftUIColor: Color {
        switch self {
        case .green:
            return Color(red: 0.0, green: 0.8, blue: 0.3)
        case .brightGreen:
            return Color(red: 0.0, green: 1.0, blue: 0.4)
        case .dimGreen:
            return Color(red: 0.0, green: 0.5, blue: 0.2)
        case .red:
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .yellow:
            return Color(red: 1.0, green: 0.9, blue: 0.3)
        case .cyan:
            return Color(red: 0.3, green: 0.9, blue: 0.9)
        case .magenta:
            return Color(red: 0.9, green: 0.3, blue: 0.9)
        case .white:
            return Color.white
        case .gray:
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        case .orange:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        }
    }
}

// MARK: - Menu Option

enum MenuTint {
    case normal      // Bright green — action buttons (attack, equip, search, etc.)
    case navigation  // Dim green — Done, back, close buttons
    case cyan        // Cyan — chat, multiplayer / remote actions
    case amber       // Amber — other character's pack, secondary actions
    case danger      // Red — destructive actions (delete, clear, quit)
}

struct MenuOption: Identifiable {
    let id = UUID()
    let text: String
    let isDefault: Bool
    let isDisabled: Bool
    let isAlert: Bool  // Flashing red button for urgent actions (e.g. multiplayer invite)
    let tint: MenuTint
    let isCompactNav: Bool  // Compact navigation symbol (⏮, ⏭, ?) — grouped into one cell
    /// Explicit 1-based number to display on the button, overriding the
    /// view's own auto-numbering (which counts only visible regular buttons
    /// on the current page, restarting each page). Set this when a caller
    /// prints its own reference list of the full, unpaginated item set (e.g.
    /// "3. Bram — Fighter") — matching this to the button's displayed
    /// number keeps the two in sync regardless of which page an item lands
    /// on. Leave nil for ordinary menus, which don't need this.
    var displayNumber: Int? = nil

    static let maxButtonLength = 22

    init(_ text: String, isDefault: Bool = false, isDisabled: Bool = false, isAlert: Bool = false, tint: MenuTint = .normal, compact: Bool = false, displayNumber: Int? = nil) {
        self.text = Self.trimToFit(text)
        self.isDefault = isDefault
        self.isDisabled = isDisabled
        self.isAlert = isAlert
        self.tint = tint
        self.isCompactNav = compact
        self.displayNumber = displayNumber
    }

    /// Trim text to fit button width, cutting at a word boundary when possible
    private static func trimToFit(_ text: String) -> String {
        guard text.count > maxButtonLength else { return text }
        // Try to break at last space within the limit
        let prefix = String(text.prefix(maxButtonLength))
        if let lastSpace = prefix.lastIndex(of: " ") {
            let trimmed = String(prefix[prefix.startIndex..<lastSpace])
            // Only use word break if it keeps at least half the allowed length
            if trimmed.count >= maxButtonLength / 2 {
                return trimmed
            }
        }
        // No good word break — hard cut
        return prefix
    }
}

// MARK: - Game State

enum GameState: String, Codable {
    case mainMenu
    case partySetup
    case characterCreation
    case exploring
    case combat
    case gameOver
    case victory
}

// MARK: - Input State

enum InputState {
    case none
    case awaitingMenu
    case awaitingText(prompt: String)
    case awaitingContinue
}
