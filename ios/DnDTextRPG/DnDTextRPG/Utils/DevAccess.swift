//
//  DevAccess.swift — hidden (developer) buttons.
//
//  Some buttons are for the game's maker, not its players: the Endgame
//  preview and Report a Bug. They're ALWAYS hidden when the app starts.
//  A secret phrase typed at the text prompt reveals them — with a whirr and
//  a creak of gears — and the same phrase followed by "off" hides them again.
//
//  Only a SHA-256 of the phrase is kept here, never the phrase itself. The
//  maker keeps the phrase in their Keychain (search "dndrpg") and in the
//  git-ignored file .dev-access at the repo root; tools/check-dev-access.swift
//  checks both against this hash.
//
//  Self-contained on purpose. To remove the feature: delete this file (and
//  its project entry) and the lines in GameEngine marked "DevAccess".
//

import Foundation
import CryptoKit

enum DevAccess {
    /// Buttons hidden from players.
    static let hiddenLabels: Set<String> = ["Endgame", "Report a Bug", "Puzzle List"]

    /// SHA-256 (hex) of the phrase, lower-cased, single-spaced.
    static let phraseHash = "b4fcbae25daafd4efd457e99132efb316fd06d7621978039a6ca33188d30125a"

    /// Off at every launch — never saved.
    private(set) static var isOn = false
    /// What was typed (memory only), so help pages can remind the maker.
    private(set) static var phrase: String?
    /// The last menu before filtering, so a toggle can redraw it at once.
    private static var lastMenu: [MenuOption] = []

    /// More ordinary buttons than this and the screen is full: a revealed
    /// button goes into the 3-bar nav cell instead.
    private static let maxRegular = 10

    enum Command { case on, off }

    static func normalize(_ s: String) -> String {
        s.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The phrase (on), the phrase + " off" (off), or neither.
    static func command(for text: String) -> Command? {
        let t = normalize(text)
        guard (6...80).contains(t.count) else { return nil }
        if hash(t) == phraseHash { return .on }
        if t.hasSuffix(" off"), hash(String(t.dropLast(4))) == phraseHash { return .off }
        return nil
    }

    static func apply(_ command: Command, typed: String) {
        let t = normalize(typed)
        isOn = command == .on
        phrase = command == .on ? t : String(t.dropLast(4))
    }

    /// The menu filter. Hidden buttons are taken out, leaving no gap. When
    /// on, they come back in the first free slot after the ordinary buttons
    /// (or, on a full screen, in the 3-bar nav cell). Every button keeps its
    /// sourceIndex, so the screen's handler still gets the choice it expects.
    static func filter(_ options: [MenuOption]) -> [MenuOption] {
        lastMenu = options
        guard options.contains(where: { hiddenLabels.contains($0.text) }) else { return options }
        let indexed = options.enumerated().map { i, o -> MenuOption in
            var o = o
            if o.sourceIndex == nil { o.sourceIndex = i }
            return o
        }
        var shown = indexed.filter { !hiddenLabels.contains($0.text) }
        guard isOn else { return shown }
        for h in indexed where hiddenLabels.contains(h.text) {
            let regular = shown.filter { !$0.isCompactNav }.count
            let compact = shown.filter { $0.isCompactNav }.count
            if regular >= maxRegular && compact < 4 {
                var c = MenuOption(h.text, isDefault: false, isDisabled: h.isDisabled, isAlert: h.isAlert, tint: h.tint, compact: true, displayNumber: h.displayNumber)
                c.sourceIndex = h.sourceIndex
                shown.insert(c, at: shown.firstIndex(where: { $0.isCompactNav }) ?? shown.endIndex)
            } else {
                shown.insert(h, at: shown.lastIndex(where: { !$0.isCompactNav }).map { $0 + 1 } ?? 0)
            }
        }
        return shown
    }

    /// The current screen's buttons, re-filtered after a toggle.
    static func redrawn() -> [MenuOption] { filter(lastMenu) }

    /// For help pages while on: how it was done, and how to undo it.
    static var helpReminder: String? {
        guard isOn, let p = phrase else { return nil }
        return "⚙ Hidden buttons are showing — you typed “\(p)” to reveal them. Type “\(p) off” to hide them again."
    }
}

extension GameEngine {
    /// The typed phrase: a whirr, the gears creak, and the buttons change.
    func applyDevAccess(_ command: DevAccess.Command, typed: String) {
        DevAccess.apply(command, typed: typed)
        SoundManager.shared.playTeleport()                                                          // the whirr
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { SoundManager.shared.playShieldBlock() } // a gear catches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { SoundManager.shared.playStaffStrike() }  // and creaks round
        print("")
        if command == .on {
            print("  ⚙  whirrrr...  clank  ⚙  creeeak...  ⚙", color: .yellow, bold: true)
            printWrapped("Something turns behind the walls. Hidden buttons now show wherever a screen has them (\(DevAccess.hiddenLabels.sorted().joined(separator: ", "))).", indent: 2, color: .cyan)
            printWrapped("Now try hiding them again: type “\(DevAccess.phrase ?? "") off”.", indent: 2, color: .dimGreen)
        } else {
            print("  ⚙  creeeak...  clunk.  ⚙", color: .yellow, bold: true)
            printWrapped("The gears settle. Hidden buttons are hidden again — the same words bring them back.", indent: 2, color: .cyan)
        }
        print("")
        if !currentMenuOptions.isEmpty { currentMenuOptions = withForwardOption(DevAccess.redrawn()) }
    }
}
