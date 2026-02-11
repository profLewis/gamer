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
    let text: String
    let color: TerminalColor
    let isBold: Bool
    let fontSize: CGFloat

    init(_ text: String, color: TerminalColor = .green, bold: Bool = false, size: CGFloat = 14) {
        self.text = text
        self.color = color
        self.isBold = bold
        self.fontSize = size
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
        }
    }
}

// MARK: - Menu Option

struct MenuOption: Identifiable {
    let id = UUID()
    let text: String
    let isDefault: Bool

    init(_ text: String, isDefault: Bool = false) {
        self.text = text
        self.isDefault = isDefault
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
