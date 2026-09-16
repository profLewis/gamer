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

    /// SHA-256 (hex) of the phrase's FIRST word — enough to recognise a
    /// half-remembered attempt and say so, without knowing the rest.
    static let firstWordHash = "a0561fd649cdb6baa784055f051bad796ea0afef17fca38219549deeba4e8c1a"

    /// SHA-256 (hex) of the phrase, lower-cased, single-spaced.
    static let phraseHash = "b4fcbae25daafd4efd457e99132efb316fd06d7621978039a6ca33188d30125a"

    /// Off at every launch — never saved.
    private(set) static var isOn = false
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

    /// Someone reaching for the phrase and not quite getting it: the right
    /// first word, but the rest wrong. Worth answering, rather than letting
    /// it fall through to the game as if nothing was typed.
    static func looksLikeAttempt(_ text: String) -> Bool {
        let t = normalize(text)
        guard command(for: text) == nil, let first = t.split(separator: " ").first else { return false }
        return hash(String(first)) == firstWordHash
    }

    /// Applied and forgotten: the words themselves are never stored, so
    /// nothing can print them back or leave them lying about on screen.
    static func apply(_ command: Command, typed: String) {
        isOn = command == .on
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

    /// For help pages while on: how to undo it, without repeating the words.
    static var helpReminder: String? {
        guard isOn else { return nil }
        return "⚙ Hidden buttons are showing. To hide them, type the access phrase again with “ off” on the end — and they hide themselves anyway whenever the app is restarted."
    }
}

extension GameEngine {
    /// Nearly right: say so, and where to look — without saying the words.
    func refuseDevAccess() {
        SoundManager.shared.playMiss()
        print("")
        print("  ⚙  clunk.  Nothing moves.", color: .yellow, bold: true)
        print("")
        printWrapped("I'm afraid I can't do that, Dave.", indent: 2, color: .red, bold: true)
        print("")
        printWrapped("That's the right idea, but not the right words — so nothing has changed, and the hidden buttons stay hidden.", indent: 2, color: .cyan)
        printWrapped("The words are in your Keychain: open Keychain Access, choose the login keychain and search “dnd” — the entry's own name tells you what to type, and its password is the phrase itself.", indent: 2, color: .dimGreen)
        printWrapped("Mind the spelling; capitals and extra spaces don't matter.", indent: 2, color: .dimGreen)
        print("")
    }

    /// The typed phrase: a whirr, the gears creak, and the buttons change.
    func applyDevAccess(_ command: DevAccess.Command, typed: String) {
        DevAccess.apply(command, typed: typed)
        SoundManager.shared.playTeleport()                                                          // the whirr
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { SoundManager.shared.playShieldBlock() } // a gear catches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { SoundManager.shared.playStaffStrike() }  // and creaks round
        print("")
        if command == .on {
            print("  ⚙  whirrrr...  clank  ⚙  creeeak...  ⚙", color: .yellow, bold: true)
            print("")
            print("  HIDDEN BUTTONS: ON", color: .brightGreen, bold: true)
            printWrapped("Something turns behind the walls, and what was hidden is there.", indent: 2, color: .cyan)
            print("")
            printWrapped("What's showing now: \(DevAccess.hiddenLabels.sorted().joined(separator: ", ")) — each on the screen it belongs to (Endgame on the title screen, Report a Bug in the Adventure Log, Puzzle List in Settings > Puzzles).", indent: 2, color: .green)
            if !currentMenuOptions.contains(where: { DevAccess.hiddenLabels.contains($0.text) }) {
                printWrapped("Nothing on THIS screen has one — go and look at one of those.", indent: 2, color: .dimGreen)
            }
            print("")
            printWrapped("To hide them again: type the same words, with “ off” on the end. Go on, try it.", indent: 2, color: .yellow)
            printWrapped("They hide themselves anyway: this resets every time the app starts, so a player never stumbles on them.", indent: 2, color: .dimGreen)
        } else {
            print("  ⚙  creeeak...  clunk.  ⚙", color: .yellow, bold: true)
            print("")
            print("  HIDDEN BUTTONS: OFF", color: .yellow, bold: true)
            printWrapped("The gears settle and the buttons are gone again — Endgame, Report a Bug and Puzzle List are back out of sight.", indent: 2, color: .cyan)
            print("")
            printWrapped("To bring them back: type the phrase again.", indent: 2, color: .dimGreen)
            printWrapped("Either way this resets when the app starts: hidden again, every time.", indent: 2, color: .dimGreen)
        }
        print("")
        if !currentMenuOptions.isEmpty { currentMenuOptions = withForwardOption(DevAccess.redrawn()) }
    }
}
