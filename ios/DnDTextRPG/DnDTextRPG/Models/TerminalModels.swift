//
//  TerminalModels.swift
//  DnDTextRPG
//
//  Models for the terminal display
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Terminal Line

struct TerminalLine: Identifiable {
    let id = UUID()
    var text: String
    var color: TerminalColor
    let isBold: Bool
    let isUnderlined: Bool
    let fontSize: CGFloat
    /// A wrapped paragraph's later lines — read aloud together with the first.
    var continuesPrevious = false
    let isCentered: Bool
    /// Optional character range drawn in `highlightColor` (bold) — e.g.
    /// the Atlas's "[@]" so you can spot where you are at a glance.
    var highlightRange: Range<Int>? = nil
    var highlightColor: TerminalColor = .yellow
    /// In-text link key (see GameEngine.printLink/followLink) — the whole
    /// line is a tap target that opens that screen.
    var link: String? = nil
    /// More coloured stretches of the line (the big map's visited rooms),
    /// under highlightRange.
    var extraHighlights: [(range: Range<Int>, color: TerminalColor)] = []

    /// Mostly symbols — ASCII art, dice faces, borders. VoiceOver skips these
    /// (they read as a string of punctuation). Lines with numbers, like HP
    /// bars, still count as content.
    var isDecorativeArt: Bool {
        let visible = text.filter { !$0.isWhitespace }
        guard visible.count >= 6 else { return false }
        let meaningful = visible.filter { $0.isLetter || $0.isNumber }.count
        return Double(meaningful) / Double(visible.count) < 0.2
    }

    /// What VoiceOver says for a line: box-drawing and bar glyphs dropped,
    /// and stat shorthand spelt out so each name is heard with its value —
    /// "║STR████░░ 16║" is read "strength 16", "HP:12/20" "hit points 12 of 20".
    static func spokenText(_ text: String) -> String {
        let drop: Set<Swift.Character> = ["║", "═", "╔", "╗", "╚", "╝", "╠", "╣", "╦", "╩", "╬", "│", "─", "┌", "┐", "└", "┘",
                                          "├", "┤", "┬", "┴", "┼", "█", "░", "▒", "▓", "■", "□", "|",
                                          // Pointer triangles are markers, not words — VoiceOver
                                          // read them as "left-pointing triangle".
                                          "◀", "▶", "◂", "▸", "◄", "►", "◁", "▷", "▲", "▼", "△", "▽"]
        var s = String(text.map { drop.contains($0) ? " " : $0 })
        s = s.replacingOccurrences(of: "[-=_+*~#]{3,}", with: " ", options: .regularExpression)
        let words: [(String, String)] = [("STR", "strength"), ("DEX", "dexterity"), ("CON", "constitution"),
                                         ("INT", "intelligence"), ("WIS", "wisdom"), ("CHA", "charisma"),
                                         ("HP", "hit points"), ("AC", "armour class"), ("XP", "experience"),
                                         ("ATK", "attack"), ("DMG", "damage"), ("CR", "challenge rating"), ("DC", "difficulty")]
        for (short, long) in words {
            s = s.replacingOccurrences(of: "\\b\(short)\\b:?", with: "\(long) ", options: .regularExpression)
        }
        s = s.replacingOccurrences(of: "(\\d+)/(\\d+)", with: "$1 of $2", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\bR\\. (?=[A-Z])", with: "R ", options: .regularExpression)   // "R. Athos" is a name
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    init(_ text: String, color: TerminalColor = .green, bold: Bool = false, underlined: Bool = false, size: CGFloat = 14, centered: Bool = false) {
        self.text = text
        self.color = color
        self.isBold = bold
        self.isUnderlined = underlined
        #if os(macOS)
        // Mac: the story reads at the same size as the map (GameEngine.mapFontSize).
        self.fontSize = size == 14 ? 16 : size
        #else
        self.fontSize = size
        #endif
        self.isCentered = centered
    }
}

enum TerminalColor {
    /// The system's Increase Contrast setting: the dim colours step up from
    /// WCAG AA (at least 4.5:1 on black) to AAA (7:1 or more).
    static var increasedContrast: Bool {
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #elseif os(iOS)
        return UIAccessibility.isDarkerSystemColorsEnabled
        #else
        return false
        #endif
    }

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
            // 5:1 on black (AA); 7.9:1 with Increase Contrast (AAA). Was 4.1:1.
            return Self.increasedContrast ? Color(red: 0.0, green: 0.72, blue: 0.32) : Color(red: 0.0, green: 0.56, blue: 0.24)
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
            return Self.increasedContrast ? Color(red: 0.7, green: 0.7, blue: 0.7) : Color(red: 0.55, green: 0.55, blue: 0.55)
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
    /// Where this button was in the list the screen gave, when the default
    /// has been moved to the front (see GameEngine.prepareMenu) — the
    /// screen's handler still gets the choice number it expects.
    var sourceIndex: Int? = nil

    static let maxButtonLength = 22
    /// What the help button shows (Settings > Accessibility > Help Button).
    /// Menus still use "?" internally; only the label changes.
    static let helpGlyphChoices = ["?", "ⓘ", "Help"]

    /// What VoiceOver says for the terse nav-cell buttons.
    static func spokenLabel(_ text: String) -> String {
        switch text {
        case "?": return "Help"
        case "< Back": return "Back"
        case "<<": return "Previous page"
        case ">>": return "Next page"
        case "Fwd >": return "Forward"
        case "Next >": return "Next, redo the last step"
        case "< Leave": return "Leave"
        case "< Leave Game": return "Leave game"
        case "⚄": return "New ideas"
        case "▲": return "Up"
        case "▼": return "Down"
        default:
            // "▲ Prev", "▶ Continue": the words without the triangle.
            let triangles = CharacterSet(charactersIn: "◀▶◂▸◄►◁▷▲▼△▽")
            let cleaned = text.unicodeScalars.filter { !triangles.contains($0) }
            let words = String(String.UnicodeScalarView(cleaned)).trimmingCharacters(in: .whitespaces)
            return words.isEmpty ? text : words
        }
    }
    static var helpGlyph: String {
        let g = UserDefaults.standard.string(forKey: "helpGlyph") ?? "?"
        return helpGlyphChoices.contains(g) ? g : "?"
    }

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

/// What the game calls the AI that runs the Dungeon Master — in one place,
/// so a label changed here changes on every button, title and help line.
enum BrainLabels {
    /// The Settings button that opens the Brain's settings. Called the
    /// Dungeon Master Brain in full, so it's clear whose mind it is.
    static let button = "Dungeon Master Brain"
    /// That screen's title.
    static let title = "Dungeon Master Brain"
    /// Choosing which mind runs the Dungeon Master (inside Brain Settings).
    static let change = "Change Brain"
    /// How help text points there.
    static let path = "Settings > \(button)"
}
