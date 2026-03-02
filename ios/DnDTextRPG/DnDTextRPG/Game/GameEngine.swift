//
//  GameEngine.swift
//  DnDTextRPG
//
//  Main game engine that manages game state and logic
//

import SwiftUI
import Combine
import AVFoundation

class GameEngine: ObservableObject {
    // MARK: - Published Properties

    @Published var terminalLines: [TerminalLine] = []
    @Published var currentMenuOptions: [MenuOption] = []
    @Published var directionExits: [Direction: Bool] = [:]  // direction -> enabled
    @Published var awaitingTextInput: Bool = false
    @Published var awaitingContinue: Bool = false
    @Published var isHoldingScreen: Bool = false
    @Published var gameState: GameState = .mainMenu

    // MARK: - Game State

    @Published var party: [Character] = []
    @Published var dungeon: Dungeon?
    @Published var currentCombat: Combat?

    // Time & history
    @Published var gameTimeMinutes: Int = 360  // Start at Day 1, 6:00 AM
    @Published var adventureLog: [String] = []

    // Run stats
    private var monstersSlain: Int = 0
    private var combatsWon: Int = 0

    // Save slot tracking
    private var activeSlotId: UUID?
    private var activeSlotName: String?

    // DM chat log (persists across DM mode entries)
    private var dmChatLog: [(isUser: Bool, text: String)] = []

    // Character creation state
    private var creatingCharacterIndex: Int = 0
    private var totalCharacters: Int = 1
    private var tempCharacterName: String = ""
    private var tempRace: Race?
    private var tempClass: CharacterClass?
    private var tempScores: [Int] = AbilityScores.standardArray
    private var remainingScores: [Int] = []
    private var assignedScores: [Ability: Int] = [:]
    private var remainingAbilities: [Ability] = []
    private var selectedSkills: [Skill] = []
    private var tempDungeonName: String = ""

    // Input handling
    var inputHandler: ((String) -> Void)?
    var menuHandler: ((Int) -> Void)?
    var menuLongPressHandler: ((Int) -> Void)?
    var directionHandler: ((Direction) -> Void)?

    // Shop
    private lazy var shopEngine = ShopEngine(game: self)

    // Autosave
    private var roomsSinceLastSave: Int = 0

    // MARK: - Initialization

    init() {}

    // MARK: - Name Validation

    private let blockedWords: Set<String> = [
        "fuck", "shit", "ass", "damn", "bitch", "bastard", "dick", "cock",
        "pussy", "cunt", "nigger", "nigga", "faggot", "retard", "slut",
        "whore", "piss", "bollocks", "wanker", "twat"
    ]

    /// Reserved words that trigger navigation (go back) and cannot be used as names
    private let reservedWords: Set<String> = ["quit", "back", "exit", "b"]

    private func isReservedWord(_ text: String) -> Bool {
        reservedWords.contains(text.lowercased().trimmingCharacters(in: .whitespaces))
    }

    private func isNameAppropriate(_ name: String) -> Bool {
        let lower = name.lowercased()
        // Reject reserved navigation words and shortcuts
        if reservedWords.contains(lower) { return false }
        if lower == "a" || lower == "auto" { return false }
        let words = lower.components(separatedBy: .alphanumerics.inverted)
        for word in words {
            if blockedWords.contains(word) { return false }
        }
        // Also check if any blocked word appears as a substring
        for blocked in blockedWords {
            if lower.contains(blocked) { return false }
        }
        return true
    }

    // MARK: - Game Time & Adventure Log

    func formattedGameTime() -> String {
        let day = gameTimeMinutes / 1440 + 1
        let hourOfDay = (gameTimeMinutes % 1440) / 60
        let minute = gameTimeMinutes % 60
        let period = hourOfDay >= 12 ? "PM" : "AM"
        let hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay)
        return "Day \(day), \(hour12):\(String(format: "%02d", minute)) \(period)"
    }

    private func advanceTime(_ minutes: Int) {
        gameTimeMinutes += minutes
    }

    private func logEvent(_ message: String, category: String? = nil) {
        let timestamp = formattedGameTime()
        if let cat = category {
            adventureLog.append("[\(timestamp)] [\(cat)] \(message)")
        } else {
            adventureLog.append("[\(timestamp)] \(message)")
        }
    }

    // MARK: - Terminal Output

    func print(_ text: String, color: TerminalColor = .green, bold: Bool = false, size: CGFloat = 14) {
        DispatchQueue.main.async {
            self.terminalLines.append(TerminalLine(text, color: color, bold: bold, size: size))
        }
    }

    func printLines(_ lines: [String], color: TerminalColor = .green, size: CGFloat = 14) {
        for line in lines {
            print(line, color: color, size: size)
        }
    }

    /// Font size for the map — larger on iPad
    var mapFontSize: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 20 : 14
        #else
        return 14
        #endif
    }

    func printTitle(_ text: String) {
        let t = String(text.prefix(30))
        let border = String(repeating: "═", count: t.count + 4)
        print("╔\(border)╗", color: .brightGreen, bold: true)
        print("║  \(t)  ║", color: .brightGreen, bold: true)
        print("╚\(border)╝", color: .brightGreen, bold: true)
        print("")
    }

    func printSubtitle(_ text: String) {
        print("--- \(text) ---", color: .cyan)
        print("")
    }

    func clearTerminal() {
        DispatchQueue.main.async {
            self.terminalLines.removeAll()
        }
    }

    // MARK: - Input Handling

    func showMenu(_ options: [String], defaultIndex: Int = 0) {
        menuLongPressHandler = nil
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.currentMenuOptions = options.enumerated().map { index, text in
                MenuOption(text, isDefault: index == defaultIndex)
            }
            self.awaitingTextInput = false
            self.awaitingContinue = false
        }
    }

    func showMenuOptions(_ options: [MenuOption]) {
        menuLongPressHandler = nil
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.currentMenuOptions = options
            self.awaitingTextInput = false
            self.awaitingContinue = false
        }
    }

    func showMenuWithDirections(_ options: [MenuOption], exits: [Direction: Bool]) {
        menuLongPressHandler = nil
        DispatchQueue.main.async {
            self.directionExits = exits
            self.currentMenuOptions = options
            self.awaitingTextInput = false
            self.awaitingContinue = false
        }
    }

    func promptText(_ prompt: String) {
        print(prompt, color: .green)
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.currentMenuOptions = []
            self.awaitingTextInput = true
            self.awaitingContinue = false
        }
    }

    /// Show both a text input prompt and menu buttons simultaneously
    func promptTextWithMenu(_ prompt: String, options: [String]) {
        print(prompt, color: .green)
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.currentMenuOptions = options.enumerated().map { index, text in
                MenuOption(text, isDefault: index == 0)
            }
            self.awaitingTextInput = true
            self.awaitingContinue = false
        }
    }

    func waitForContinue() {
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.currentMenuOptions = []
            self.awaitingTextInput = false
            self.awaitingContinue = true
        }
    }

    func handleMenuChoice(_ choice: Int) {
        // Suppress taps briefly after a long-press screen transition
        guard Date() > suppressMenuUntil else { return }

        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.directionExits = [:]
        }

        if let handler = menuHandler {
            handler(choice)
        }
    }

    private var suppressMenuUntil: Date = .distantPast

    func handleMenuLongPress(_ choice: Int) {
        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.directionExits = [:]
        }

        if let handler = menuLongPressHandler {
            handler(choice)
            // After a long-press triggers a screen change, briefly suppress
            // menu taps to prevent finger-up from hitting the new menu
            suppressMenuUntil = Date().addingTimeInterval(0.5)
        } else if let handler = menuHandler {
            // Fall back to normal handler if no long-press handler
            handler(choice)
        }
    }

    func handleDirectionChoice(_ direction: Direction) {
        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.directionExits = [:]
        }

        if let handler = directionHandler {
            handler(direction)
        }
    }

    func handleTextInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            self.awaitingTextInput = false
        }
        print("> \(trimmed)", color: .dimGreen)

        if let handler = inputHandler {
            handler(trimmed)
        }
    }

    func handleContinue() {
        DispatchQueue.main.async {
            self.awaitingContinue = false
        }

        if let handler = inputHandler {
            handler("")
        }
    }

    // MARK: - Game Start

    func startGame() {
        GameCenterManager.shared.authenticatePlayer()
        HallOfFameManager.shared.seedIfEmpty()
        clearTerminal()
        showMainMenu()
    }

    // MARK: - Main Menu

    func showMainMenu() {
        gameState = .mainMenu
        SoundManager.shared.startMusic(.menu)

        printTitle("D&D 5e Text Adventure")
        print("A text-based role-playing game", color: .dimGreen)
        print("")

        showMenu(["New Game", "Load Game", "Hall of Fame", "How to Play", "Settings", "Quit"])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.startNewGame()
            case 2: self?.showLoadGameMenu(returnTo: .mainMenu)
            case 3: self?.showHallOfFame()
            case 4: self?.showHowToPlay()
            case 5: self?.showSettings()
            case 6: self?.quitApp()
            default: self?.showMainMenu()
            }
        }
    }

    func showHowToPlay() {
        clearTerminal()
        printTitle("How to Play")

        print("Welcome to D&D 5e Text Adventure!", color: .brightGreen)
        print("")
        print("CONTROLS:", color: .cyan, bold: true)
        print("  - Tap menu options to select")
        print("  - Type text when prompted")
        print("  - Tap 'Continue' to advance")
        print("  - Use '< Back' to go back")
        print("")
        print("GAMEPLAY:", color: .cyan, bold: true)
        print("  - Create a party of adventurers")
        print("  - Explore generated dungeons")
        print("  - Fight monsters in turn-based combat")
        print("  - Collect treasure and gain XP")
        print("  - Defeat the boss to advance levels")
        print("")
        print("TIPS:", color: .cyan, bold: true)
        print("  - Long-press a button to auto-fill")
        print("    all remaining choices")
        print("  - Hold the screen to speed up resting")
        print("  - Use 'Ask the DM' to talk to the AI")
        print("  - Dodge gives attackers disadvantage")
        print("  - Play Dead to escape tough fights")
        print("")
        print("COMBAT:", color: .cyan, bold: true)
        print("  - Initiative determines turn order")
        print("  - Roll d20 + modifiers vs AC to hit")
        print("  - Beware of poison from some creatures")
        print("  - Defeat all enemies to win!")
        print("")
        print("DUNGEON MASTER:", color: .cyan, bold: true)
        print("  The DM has three intelligence tiers:")
        print("")
        print("  Basic DM (all devices):", color: .yellow)
        print("  - Very simple canned responses")
        print("  - No AI needed, works everywhere")
        print("")
        print("  Apple On-Device AI:", color: .brightGreen)
        print("  - iPhone 16+ / iPad M-series, iOS 26+")
        print("  - Much smarter, runs locally/offline")
        print("  - No account or API key needed")
        print("  - Can be fussy — rephrase if it")
        print("    won't answer (e.g. 'tell me the")
        print("    contents of my pack' not 'whats")
        print("    in my pack')")
        print("")
        print("  Cloud AI (best experience):", color: .brightGreen)
        print("  - Works on any device")
        print("  - Google Gemini is FREE (ages 18+)")
        print("  - Also supports Claude & OpenAI")
        print("  - Set up in Settings > AI Provider")
        print("")
        print("  - Adjust level: Settings > DM Ad-lib")
        print("")
        print("LICENSE:", color: .cyan, bold: true)
        print("  D&D 5e SRD under the Open Gaming")
        print("  License (OGL) v1.0a by Wizards of")
        print("  the Coast LLC.")
        print("")
        print("ABOUT:", color: .cyan, bold: true)
        print("  Created by Prof. Lewis")
        print("  Assisted by Claude (Anthropic)")
        print("  github.com/profLewis/gamer")
        print("")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.clearTerminal()
            self?.showMainMenu()
        }
    }

    // MARK: - Font Size

    enum FontSizeSetting: Int, CaseIterable {
        case small = 0
        case medium = 1
        case large = 2

        var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }

        var scale: CGFloat {
            switch self {
            case .small: return 1.0
            case .medium: return 1.3
            case .large: return 1.6
            }
        }

        /// Default: medium on iPad, small on iPhone
        static var defaultSetting: FontSizeSetting {
            #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad ? .medium : .small
            #else
            return .small
            #endif
        }
    }

    @Published var fontScale: CGFloat = {
        let raw = UserDefaults.standard.object(forKey: "font_size_setting") as? Int
        if let raw = raw, let setting = FontSizeSetting(rawValue: raw) {
            return setting.scale
        }
        return FontSizeSetting.defaultSetting.scale
    }()

    var fontSizeSetting: FontSizeSetting {
        get {
            let raw = UserDefaults.standard.object(forKey: "font_size_setting") as? Int
            if let raw = raw, let setting = FontSizeSetting(rawValue: raw) {
                return setting
            }
            return FontSizeSetting.defaultSetting
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "font_size_setting")
            fontScale = newValue.scale
        }
    }

    // MARK: - Autosave

    enum AutosaveInterval: Int, CaseIterable {
        case off = 0
        case everyRoom = 1
        case every3Rooms = 3
        case every5Rooms = 5

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .everyRoom: return "Every Room"
            case .every3Rooms: return "Every 3 Rooms"
            case .every5Rooms: return "Every 5 Rooms"
            }
        }
    }

    var autosaveInterval: AutosaveInterval {
        get {
            let raw = UserDefaults.standard.integer(forKey: "autosave_interval")
            return AutosaveInterval(rawValue: raw) ?? .off
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "autosave_interval")
        }
    }

    var dmLogContextSize: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "dm_log_context_size")
            return val > 0 ? val : 128
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "dm_log_context_size")
        }
    }

    private func autosaveIfNeeded() {
        let interval = autosaveInterval
        guard interval != .off, dungeon != nil else { return }

        roomsSinceLastSave += 1
        if roomsSinceLastSave >= interval.rawValue {
            roomsSinceLastSave = 0
            performAutosave()
        }
    }

    private func performAutosave() {
        guard let dungeon = dungeon else { return }

        let partyDesc = party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", ")

        // Use the active slot if we have one, otherwise create a new slot
        let slotId = activeSlotId ?? UUID()
        let slotName = activeSlotName ?? "\(party.first?.name ?? "Unknown") — \(dungeon.name)"

        // Remember this slot for future autosaves
        if activeSlotId == nil {
            activeSlotId = slotId
            activeSlotName = slotName
        }

        let saveGame = SaveGame(
            id: UUID(),
            slotId: slotId,
            savedAt: Date(),
            slotName: slotName,
            partyDescription: partyDesc,
            dungeonName: dungeon.name,
            dungeonLevel: dungeon.level,
            party: party,
            dungeon: dungeon,
            gameState: .exploring,
            gameTimeMinutes: gameTimeMinutes,
            adventureLog: adventureLog,
            monstersSlain: monstersSlain,
            combatsWon: combatsWon
        )

        try? SaveGameManager.shared.save(saveGame)
    }

    // MARK: - Settings

    func showSettings() {
        clearTerminal()
        printTitle("Settings")

        let dm = DMEngine.shared
        let currentProvider = dm.provider

        print("AI DUNGEON MASTER:", color: .cyan, bold: true)
        if dm.isConfigured {
            print("  Provider: \(currentProvider.displayName)", color: .brightGreen)
            print("  API Key: configured", color: .brightGreen)
        } else if dm.isAppleModelAvailable {
            print("  Using: Apple On-Device AI", color: .brightGreen)
            print("  No API key needed!", color: .dimGreen)
            print("  (Upgrade to a cloud AI for a", color: .dimGreen)
            print("  smarter DM — see AI Provider)", color: .dimGreen)
        } else {
            print("  DM: Basic (no AI available)", color: .red)
            print("  For a smarter DM, set up a", color: .yellow)
            print("  cloud AI in 'AI Provider'.", color: .yellow)
            print("  Google Gemini is free (ages 18+).", color: .brightGreen)
        }
        print("")

        let currentLevel = dm.adLibLevel
        print("DM AD-LIB LEVEL:", color: .cyan, bold: true)
        print("  Current: \(currentLevel.displayName) — \(currentLevel.description)", color: .dimGreen)
        print("")

        print("FONT SIZE:", color: .cyan, bold: true)
        print("  Current: \(fontSizeSetting.displayName)", color: .dimGreen)
        print("")

        let speech = SpeechEngine.shared
        print("DM VOICE:", color: .cyan, bold: true)
        print("  Talking DM: \(speech.isEnabled ? "On" : "Off")", color: speech.isEnabled ? .brightGreen : .dimGreen)
        if speech.isEnabled {
            let voiceName = speech.voiceIdentifier.flatMap { id in
                AVSpeechSynthesisVoice(identifier: id)?.name
            } ?? "Default"
            print("  Voice: \(voiceName)", color: .dimGreen)
        }
        print("")

        let currentAutosave = autosaveInterval
        print("AUTOSAVE:", color: .cyan, bold: true)
        print("  Current: \(currentAutosave.displayName)", color: .dimGreen)
        print("")

        print("DM LOG CONTEXT:", color: .cyan, bold: true)
        print("  Entries sent to DM: \(dmLogContextSize)", color: .dimGreen)
        print("")

        var options = ["AI Provider", "Set API Key", "DM Ad-lib Level", "DM Voice", "Font Size", "Autosave", "DM Log Context"]
        if dm.isConfigured {
            options.append("Clear API Key")
        }
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.showAIProviderMenu()
            } else if choice == 2 {
                self?.promptAPIKey()
            } else if choice == 3 {
                self?.showAdLibLevelMenu()
            } else if choice == 4 {
                self?.showVoiceSettings()
            } else if choice == 5 {
                self?.showFontSizeMenu()
            } else if choice == 6 {
                self?.showAutosaveMenu()
            } else if choice == 7 {
                self?.showDMLogContextMenu()
            } else if dm.isConfigured && choice == 8 {
                dm.apiKey = nil
                self?.print("")
                self?.print("API key cleared.", color: .yellow)
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showSettings()
                }
            } else {
                self?.clearTerminal()
                self?.showMainMenu()
            }
        }
    }

    func showAIProviderMenu() {
        clearTerminal()
        printTitle("AI Provider")

        let dm = DMEngine.shared

        // Show current DM status
        print("CURRENT DM:", color: .cyan, bold: true)
        if dm.isConfigured {
            print("  \(dm.provider.displayName) [key set]", color: .brightGreen)
        } else if dm.isAppleModelAvailable {
            print("  Apple On-Device AI", color: .brightGreen)
            print("  Running locally on this device.", color: .dimGreen)
            print("  Works offline, no account needed.", color: .dimGreen)
            print("  Upgrade to a cloud provider below", color: .dimGreen)
            print("  for a more creative DM.", color: .dimGreen)
        } else {
            print("  Basic DM (no AI)", color: .red)
            print("  This device doesn't support Apple", color: .yellow)
            print("  on-device AI (requires iOS 26+", color: .yellow)
            print("  on iPhone 16 or newer).", color: .yellow)
            print("")
            print("  Without AI, you get a simple DM", color: .yellow)
            print("  with canned responses.", color: .yellow)
            print("")
            print("  OPTIONS:", color: .cyan, bold: true)
            print("  - Set up a cloud AI below", color: .dimGreen)
            print("    (Gemini is FREE for ages 18+)", color: .brightGreen)
            print("  - Use a newer iPhone/iPad", color: .dimGreen)
            print("  - Try the web version (coming soon)", color: .dimGreen)
        }
        print("")

        print("CLOUD PROVIDERS:", color: .cyan, bold: true)
        print("  These give the best DM experience.", color: .dimGreen)
        print("  Each requires its own API key.", color: .dimGreen)
        print("")

        let current = dm.provider
        for provider in AIProvider.allCases {
            let marker = provider == current && dm.isConfigured ? " <--" : ""
            let hasKey = dm.apiKey(for: provider) != nil
            let keyStatus = hasKey ? " [key set]" : ""
            let freeTag = provider == .google && !hasKey ? " (FREE!)" : ""
            print("  \(provider.displayName)\(keyStatus)\(freeTag)\(marker)",
                  color: hasKey ? .brightGreen : .green)
            print("     \(provider.keyURL)", color: .dimGreen)
            print("")
        }

        var options: [String] = []
        if dm.isAppleModelAvailable {
            options.append("Apple On-Device AI")
        }
        options += AIProvider.allCases.map { $0.displayName }
        options.append("< Back")
        showMenu(options)

        let appleOffset = dm.isAppleModelAvailable ? 1 : 0

        menuHandler = { [weak self] choice in
            if dm.isAppleModelAvailable && choice == 1 {
                // Switch to Apple on-device model (clear API key)
                dm.apiKey = nil
                dm.clearHistory()
                self?.dmChatLog = []
                self?.print("")
                self?.print("Switched to Apple On-Device AI.", color: .brightGreen)
                self?.print("")
                self?.print("  Runs locally, no account needed.", color: .dimGreen)
                self?.print("  Works offline.", color: .dimGreen)
                self?.print("  May refuse some queries — try", color: .dimGreen)
                self?.print("  rephrasing if it won't answer.", color: .dimGreen)
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showSettings()
                }
            } else if choice - appleOffset >= 1 && choice - appleOffset <= AIProvider.allCases.count {
                let selected = AIProvider.allCases[choice - appleOffset - 1]
                dm.provider = selected
                dm.clearHistory()
                self?.dmChatLog = []
                self?.print("")
                self?.print("AI Provider set to: \(selected.displayName)", color: .brightGreen)
                if dm.apiKey(for: selected) == nil {
                    self?.print("")
                    self?.print("You need an API key for \(selected.displayName).", color: .yellow)
                    if selected == .google {
                        self?.print("Gemini is free — just needs a Google", color: .brightGreen)
                        self?.print("account (you must be 18+).", color: .brightGreen)
                    }
                    self?.print("")
                    self?.print("Tap 'Set API Key' in Settings to", color: .dimGreen)
                    self?.print("get your key and paste it in.", color: .dimGreen)
                }
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    if dm.apiKey(for: selected) == nil {
                        self?.promptAPIKey()
                    } else {
                        self?.showSettings()
                    }
                }
            } else {
                self?.showSettings()
            }
        }
    }

    func showAdLibLevelMenu() {
        clearTerminal()
        printTitle("DM Ad-lib Level")

        for level in DMAdLibLevel.allCases {
            let marker = level == DMEngine.shared.adLibLevel ? " <--" : ""
            print("  \(level.rawValue): \(level.displayName)\(marker)", color: level == DMEngine.shared.adLibLevel ? .brightGreen : .green)
            print("     \(level.description)", color: .dimGreen)
            print("")
        }

        let options = DMAdLibLevel.allCases.map { $0.displayName } + ["< Back"]
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= DMAdLibLevel.allCases.count {
                DMEngine.shared.adLibLevel = DMAdLibLevel(rawValue: choice - 1) ?? .flavorOnly
                self?.showAdLibLevelMenu()
            } else {
                self?.showSettings()
            }
        }
    }

    func showVoiceSettings() {
        clearTerminal()
        printTitle("DM Voice")

        let speech = SpeechEngine.shared

        // Check if TTS is available at all
        guard speech.isAvailable else {
            print("  Text-to-speech is not available", color: .red)
            print("  on this device.", color: .red)
            print("")
            print("  Make sure your device has voices", color: .dimGreen)
            print("  installed in Settings > Accessibility", color: .dimGreen)
            print("  > Spoken Content > Voices.", color: .dimGreen)
            print("")
            showMenu(["< Back"])
            menuHandler = { [weak self] _ in self?.showSettings() }
            return
        }

        // Check DM is active
        if DMEngine.shared.adLibLevel == .off {
            print("  DM Voice reads DM responses aloud.", color: .dimGreen)
            print("")
            print("  The DM is currently Off.", color: .yellow)
            print("  Enable the DM first in", color: .yellow)
            print("  'DM Ad-lib Level' settings.", color: .yellow)
            print("")
            showMenu(["< Back"])
            menuHandler = { [weak self] _ in self?.showSettings() }
            return
        }

        print("  The DM can read responses aloud", color: .dimGreen)
        print("  using text-to-speech.", color: .dimGreen)
        print("  (No API key needed — built into iOS)", color: .dimGreen)
        print("")
        print("  Talking DM: \(speech.isEnabled ? "On" : "Off")", color: speech.isEnabled ? .brightGreen : .yellow)

        if speech.isEnabled {
            let voiceName = speech.voiceIdentifier.flatMap { id in
                AVSpeechSynthesisVoice(identifier: id)?.name
            } ?? "Default (British)"
            let speedLabel: String
            if speech.rate < 0.4 { speedLabel = "Slow" }
            else if speech.rate < 0.5 { speedLabel = "Normal" }
            else { speedLabel = "Fast" }
            let pitchLabel: String
            if speech.pitch < 0.85 { pitchLabel = "Deep" }
            else if speech.pitch < 1.05 { pitchLabel = "Normal" }
            else { pitchLabel = "High" }
            print("  Voice: \(voiceName)", color: .dimGreen)
            print("  Speed: \(speedLabel)  Pitch: \(pitchLabel)", color: .dimGreen)
        }
        print("")

        var options = [String]()
        options.append(speech.isEnabled ? "Turn Off" : "Turn On")
        if speech.isEnabled {
            options.append("Choose Voice")
            options.append("Speed")
            options.append("Pitch")
        }
        options.append("Preview")
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == 1 {
                // Toggle on/off
                speech.isEnabled = !speech.isEnabled
                if speech.isEnabled {
                    // Give immediate feedback
                    speech.preview()
                } else {
                    speech.stop()
                }
                self?.showVoiceSettings()
            } else if speech.isEnabled {
                // On: choices are Toggle, Voice, Speed, Pitch, Preview, Back
                if choice == 2 {
                    self?.showVoiceChoiceMenu()
                } else if choice == 3 {
                    self?.showVoiceSpeedMenu()
                } else if choice == 4 {
                    self?.showVoicePitchMenu()
                } else if choice == 5 {
                    self?.showVoicePreview()
                } else {
                    self?.showSettings()
                }
            } else {
                // Off: choices are Toggle, Preview, Back
                if choice == 2 {
                    self?.showVoicePreview()
                } else {
                    self?.showSettings()
                }
            }
        }
    }

    private func showVoicePreview() {
        let speech = SpeechEngine.shared
        clearTerminal()
        printTitle("DM Voice Preview")
        print("")
        print("  Speaking...", color: .cyan)
        print("")
        speech.preview()

        showMenu(["Sounds Good", "Change Voice", "Change Speed", "Change Pitch"])

        menuHandler = { [weak self] choice in
            speech.stop()
            if choice == 1 {
                self?.showVoiceSettings()
            } else if choice == 2 {
                self?.showVoiceChoiceMenu()
            } else if choice == 3 {
                self?.showVoiceSpeedMenu()
            } else if choice == 4 {
                self?.showVoicePitchMenu()
            }
        }
    }

    private func showVoiceChoiceMenu(page: Int = 0) {
        clearTerminal()
        printTitle("Choose Voice")

        let speech = SpeechEngine.shared
        let allVoices = speech.availableVoices()
        let currentId = speech.voiceIdentifier

        if allVoices.isEmpty {
            print("  No English voices available.", color: .red)
            print("")
            print("  Install voices in iOS Settings:", color: .dimGreen)
            print("  Settings > Accessibility >", color: .dimGreen)
            print("  Spoken Content > Voices > English", color: .dimGreen)
            print("")
            showMenu(["< Back"])
            menuHandler = { [weak self] _ in self?.showVoiceSettings() }
            return
        }

        // Tip if only standard voices
        if !speech.hasHighQualityVoices {
            print("  Tip: Download better voices in", color: .yellow)
            print("  iOS Settings > Accessibility >", color: .yellow)
            print("  Spoken Content > Voices > English", color: .yellow)
            print("  (tap a voice to download Enhanced", color: .yellow)
            print("  or Premium quality)", color: .yellow)
            print("")
        }

        // Paginate — 6 voices per page
        let perPage = 6
        let totalPages = (allVoices.count + perPage - 1) / perPage
        let startIdx = page * perPage
        let endIdx = min(startIdx + perPage, allVoices.count)
        let pageVoices = Array(allVoices[startIdx..<endIdx])

        if totalPages > 1 {
            print("  Page \(page + 1) of \(totalPages)", color: .dimGreen)
            print("")
        }

        for v in pageVoices {
            let marker = v.identifier == currentId ? " <--" : ""
            print("  \(v.label)\(marker)",
                  color: v.identifier == currentId ? .brightGreen : .green)
        }
        print("")

        var options = pageVoices.map { $0.name }
        if page < totalPages - 1 {
            options.append("More Voices")
        }
        options.append("< Back")
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= pageVoices.count {
                let selected = pageVoices[choice - 1]
                speech.voiceIdentifier = selected.identifier
                self?.showVoicePreview()
            } else if page < totalPages - 1 && choice == pageVoices.count + 1 {
                self?.showVoiceChoiceMenu(page: page + 1)
            } else {
                self?.showVoiceSettings()
            }
        }
    }

    private func showVoiceSpeedMenu() {
        clearTerminal()
        printTitle("Speech Speed")

        let speech = SpeechEngine.shared
        let speeds: [(name: String, value: Float)] = [
            ("Slow", 0.35),
            ("Normal", 0.45),
            ("Fast", 0.55),
            ("Very Fast", 0.65),
        ]

        for s in speeds {
            let marker = abs(speech.rate - s.value) < 0.05 ? " <--" : ""
            print("  \(s.name)\(marker)", color: abs(speech.rate - s.value) < 0.05 ? .brightGreen : .green)
        }
        print("")

        var options = speeds.map { $0.name }
        options.append("< Back")
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= speeds.count {
                speech.rate = speeds[choice - 1].value
                self?.print("")
                self?.print("Speed set to: \(speeds[choice - 1].name)", color: .brightGreen)
                speech.preview()
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showVoiceSettings()
                }
            } else {
                self?.showVoiceSettings()
            }
        }
    }

    private func showVoicePitchMenu() {
        clearTerminal()
        printTitle("Voice Pitch")

        let speech = SpeechEngine.shared
        let pitches: [(name: String, value: Float)] = [
            ("Deep", 0.75),
            ("Low", 0.85),
            ("Normal", 1.0),
            ("High", 1.15),
        ]

        for p in pitches {
            let marker = abs(speech.pitch - p.value) < 0.08 ? " <--" : ""
            print("  \(p.name)\(marker)", color: abs(speech.pitch - p.value) < 0.08 ? .brightGreen : .green)
        }
        print("")

        var options = pitches.map { $0.name }
        options.append("< Back")
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= pitches.count {
                speech.pitch = pitches[choice - 1].value
                self?.print("")
                self?.print("Pitch set to: \(pitches[choice - 1].name)", color: .brightGreen)
                speech.preview()
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showVoiceSettings()
                }
            } else {
                self?.showVoiceSettings()
            }
        }
    }

    func showAutosaveMenu() {
        clearTerminal()
        printTitle("Autosave")
        print("  Automatically saves your game as you explore.", color: .dimGreen)
        print("  Replaces the previous autosave each time.", color: .dimGreen)
        print("")

        let current = autosaveInterval
        for interval in AutosaveInterval.allCases {
            let marker = interval == current ? " <--" : ""
            print("  \(interval.displayName)\(marker)", color: interval == current ? .brightGreen : .green)
        }
        print("")

        let options = AutosaveInterval.allCases.map { $0.displayName } + ["< Back"]
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= AutosaveInterval.allCases.count {
                let selected = AutosaveInterval.allCases[choice - 1]
                self?.autosaveInterval = selected
                self?.print("")
                self?.print("Autosave set to: \(selected.displayName)", color: .brightGreen)
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showSettings()
                }
            } else {
                self?.showSettings()
            }
        }
    }

    func showDMLogContextMenu() {
        clearTerminal()
        printTitle("DM Log Context")
        print("  How many adventure log entries are", color: .dimGreen)
        print("  sent to the AI DM for context.", color: .dimGreen)
        print("  More = better narrative continuity", color: .dimGreen)
        print("  but uses more AI tokens.", color: .dimGreen)
        print("")

        let current = dmLogContextSize
        let sizes = [32, 64, 128, 256, 512]
        for size in sizes {
            let marker = size == current ? " <--" : ""
            print("  \(size) entries\(marker)", color: size == current ? .brightGreen : .green)
        }
        print("")

        var options = sizes.map { "\($0) entries" }
        options.append("< Back")
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= sizes.count {
                self?.dmLogContextSize = sizes[choice - 1]
                self?.showDMLogContextMenu()
            } else {
                self?.showSettings()
            }
        }
    }

    func showFontSizeMenu() {
        clearTerminal()
        printTitle("Font Size")
        print("")

        let current = fontSizeSetting
        for size in FontSizeSetting.allCases {
            let marker = size == current ? " <--" : ""
            print("  \(size.displayName)\(marker)", color: size == current ? .brightGreen : .green)
        }
        print("")

        let options = FontSizeSetting.allCases.map { $0.displayName } + ["< Back"]
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= FontSizeSetting.allCases.count {
                let selected = FontSizeSetting.allCases[choice - 1]
                self?.fontSizeSetting = selected
                self?.print("")
                self?.print("Font size set to: \(selected.displayName)", color: .brightGreen)
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showSettings()
                }
            } else {
                self?.showSettings()
            }
        }
    }

    private func promptAPIKey() {
        let provider = DMEngine.shared.provider
        clearTerminal()
        printTitle("Set API Key")
        print("")
        print("  Provider: \(provider.displayName)", color: .cyan)
        print("")
        if provider == .google {
            print("  Gemini is FREE — no credit card", color: .brightGreen)
            print("  needed! Just a Google account.", color: .brightGreen)
            print("")
            print("  Note: You must be 18+ to create", color: .yellow)
            print("  a Google API key.", color: .yellow)
            print("")
            print("  1. Tap 'Get Free Key' below", color: .dimGreen)
            print("  2. Sign in with Google", color: .dimGreen)
            print("  3. Click 'Create API Key'", color: .dimGreen)
            print("  4. Copy it, come back here", color: .dimGreen)
            print("  5. Tap 'Paste from Clipboard'", color: .dimGreen)
        } else {
            print("  Get a key at \(provider.keyURL)", color: .dimGreen)
        }
        print("")

        var options = [String]()
        if provider == .google {
            options.append("Get Free Key")
        } else {
            options.append("Get Key")
        }
        options.append("Paste from Clipboard")
        options.append("Type Key Manually")
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == 1 {
                // Open the provider's key URL in Safari
                let urlString: String
                switch provider {
                case .google: urlString = "https://aistudio.google.com/apikey"
                case .anthropic: urlString = "https://console.anthropic.com"
                case .openAI: urlString = "https://platform.openai.com/api-keys"
                }
                if let url = URL(string: urlString) {
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url)
                    }
                }
                // When they come back, show the same menu again
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.promptAPIKey()
                }
            } else if choice == 2 {
                // Paste from clipboard
                #if os(iOS)
                if let clipText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !clipText.isEmpty {
                    DMEngine.shared.apiKey = clipText
                    self?.print("")
                    self?.print("  Testing API key...", color: .dimGreen)
                    self?.validateAndConfirmKey(provider: provider)
                } else {
                    self?.print("")
                    self?.print("Clipboard is empty.", color: .yellow)
                    self?.print("Copy your API key first.", color: .dimGreen)
                    self?.print("")
                    self?.waitForContinue()
                    self?.inputHandler = { [weak self] _ in
                        self?.promptAPIKey()
                    }
                }
                #endif
            } else if choice == 3 {
                // Manual text entry
                self?.print("")
                self?.promptText("Paste your API key:")
                self?.inputHandler = { [weak self] key in
                    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        self?.promptAPIKey()
                        return
                    }
                    DMEngine.shared.apiKey = trimmed
                    self?.print("")
                    self?.print("  Testing API key...", color: .dimGreen)
                    self?.validateAndConfirmKey(provider: provider)
                }
            } else {
                self?.showSettings()
            }
        }
    }

    private func validateAndConfirmKey(provider: AIProvider) {
        DMEngine.shared.testAPIKey { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    self?.print("")
                    self?.print("  Key verified!", color: .brightGreen)
                    self?.print("  \(provider.displayName) is working.", color: .brightGreen)
                    self?.print("  The AI Dungeon Master is now", color: .cyan)
                    self?.print("  available.", color: .cyan)
                    self?.print("")
                    self?.waitForContinue()
                    self?.inputHandler = { [weak self] _ in
                        self?.showSettings()
                    }
                } else {
                    self?.print("")
                    self?.print("  Key test FAILED.", color: .red)
                    if let msg = errorMessage {
                        // Wrap long error messages
                        let maxLen = 30
                        var remaining = msg
                        while !remaining.isEmpty {
                            let line = String(remaining.prefix(maxLen))
                            remaining = String(remaining.dropFirst(line.count))
                            self?.print("  \(line)", color: .yellow)
                        }
                    }
                    self?.print("")
                    self?.print("  Check the key and try again.", color: .dimGreen)
                    // Remove the bad key
                    DMEngine.shared.apiKey = nil
                    self?.print("")
                    self?.waitForContinue()
                    self?.inputHandler = { [weak self] _ in
                        self?.promptAPIKey()
                    }
                }
            }
        }
    }

    // MARK: - Hall of Fame

    func showHallOfFame() {
        clearTerminal()

        printLines(asciiTrophy, color: .yellow)
        print("")
        printTitle("Hall of Fame")

        let entries = HallOfFameManager.shared.listEntries()
        let manager = HallOfFameManager.shared

        // Summary stats
        print("  Victories: \(manager.totalVictories())  Defeats: \(manager.totalDefeats())  Total Runs: \(manager.totalRuns())", color: .cyan)
        if manager.bestGold() > 0 {
            print("  Best Gold: \(manager.bestGold())  Most Slain: \(manager.mostSlain())", color: .cyan)
        }
        print("")

        if entries.isEmpty {
            print("  No adventures recorded yet.", color: .dimGreen)
            print("  Complete a dungeon to earn your place!", color: .dimGreen)
            print("")
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            for (index, entry) in entries.enumerated() {
                let outcome = entry.outcome == .victory ? "VICTORY" : "DEFEAT"
                let outcomeColor: TerminalColor = entry.outcome == .victory ? .yellow : .red

                print("\(index + 1). \(entry.dungeonName) (Lv.\(entry.dungeonLevel)) — \(outcome)  [\(entry.score) pts]", color: outcomeColor)
                print("   \(entry.partyDescription)", color: .dimGreen)

                let day = entry.gameTimeMinutes / 1440 + 1
                print("   Gold: \(entry.goldCollected)  Slain: \(entry.monstersSlain)  Rooms: \(entry.roomsExplored)/\(entry.totalRooms)  Day \(day)", color: .dimGreen)
                print("   \(dateFormatter.string(from: entry.date))", color: .dimGreen)
                print("")
            }
        }

        showMenu(["< Back"])

        menuHandler = { [weak self] _ in
            self?.clearTerminal()
            self?.showMainMenu()
        }
    }

    // MARK: - New Game

    func startNewGame() {
        clearTerminal()
        printTitle("New Adventure")
        print("How many adventurers in your party?")
        print("  (Long-press for all-AI party)", color: .dimGreen)
        print("")

        showMenu(["1 Character", "2 Characters", "3 Characters", "4 Characters", "Random Party", "< Back"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 6 {
                self.clearTerminal()
                self.showMainMenu()
                return
            }
            if choice == 5 {
                self.createRandomParty()
                return
            }
            self.totalCharacters = choice
            self.creatingCharacterIndex = 0
            self.party = []
            self.chooseCharacterType()
        }

        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= 4 {
                self.createRandomParty(count: choice, allAI: true)
            }
        }
    }

    /// Pick a name not already used by party members
    private func pickUniqueName() -> String {
        let existingNames = Set(party.map { $0.name.lowercased() })
        let available = suggestedNames.filter { !existingNames.contains($0.lowercased()) }
        return available.randomElement() ?? "Adventurer \(party.count + 1)"
    }

    /// Create a fully random party and present for confirmation
    private func createRandomParty(count: Int? = nil, allAI: Bool = false) {
        let count = count ?? Int.random(in: 1...4)
        party = []
        creatingCharacterIndex = 0
        totalCharacters = count

        for i in 0..<count {
            let name = pickUniqueName()
            let race = Race.allCases.randomElement()!
            let charClass = CharacterClass.allCases.randomElement()!

            // Auto scores
            let sorted = AbilityScores.standardArray.sorted(by: >)
            var scores = AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10)
            for (idx, ability) in charClass.abilityPriority.enumerated() {
                scores.set(ability, to: sorted[idx])
            }
            // Racial bonuses
            for (ability, bonus) in race.abilityBonuses {
                scores.set(ability, to: scores.score(for: ability) + bonus)
            }

            // First character is always human-controlled
            let isAI = allAI && i > 0
            let character = Character(name: name, race: race, characterClass: charClass, abilityScores: scores, isComputerControlled: isAI)

            // Skills
            let skills = Array(charClass.skillChoices.shuffled().prefix(charClass.numSkillChoices))
            for skill in skills { character.skillProficiencies.insert(skill) }

            // Gold & equipment
            character.gold = Dice.rollSum(4, d: 4) * 10
            let equipOptions = ItemCatalog.startingEquipmentOptions(for: charClass)
            if let (_, items) = equipOptions.first {
                for item in items { _ = character.addItem(item) }
            }
            autoEquip(character)

            // Spells
            let startingSpells = SpellCatalog.startingSpells(for: charClass)
            if !startingSpells.isEmpty {
                character.knownSpells = startingSpells
                character.spellSlots = SpellCatalog.startingSlots(for: charClass, level: 1)
            }
            if charClass == .barbarian {
                character.rageUsesRemaining = character.rageMaxUses
            }

            party.append(character)
        }

        // Show the random party for confirmation
        clearTerminal()
        printTitle("Random Party")
        for char in party {
            let aiTag = char.isComputerControlled ? " [AI]" : ""
            print("  \(char.name)\(aiTag) — \(char.race.rawValue) \(char.characterClass.rawValue)", color: .brightGreen)
            print("    HP: \(char.maxHP)  AC: \(char.armorClass)  \(char.characterClass.primaryAbility.abbreviation): \(char.abilityScores.score(for: char.characterClass.primaryAbility))", color: .dimGreen)
        }
        print("")

        showMenu(["Accept Party", "< Back", "Reroll"])
        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.startAdventure()
            case 2:
                self?.party = []
                self?.startNewGame()
            case 3: self?.createRandomParty()
            default: break
            }
        }
    }

    /// Tracks whether the current character being created is AI
    private var creatingAsAI: Bool = false

    /// Ask if this character is human or AI, then proceed
    private func chooseCharacterType() {
        // Must have at least one human — skip choice for solo or if all others are AI
        let hasHuman = party.contains(where: { !$0.isComputerControlled })
        let isLastCharacter = creatingCharacterIndex == totalCharacters - 1
        let mustBeHuman = totalCharacters == 1 || (isLastCharacter && !hasHuman)

        if mustBeHuman {
            creatingAsAI = false
            startCharacterCreation()
            return
        }

        clearTerminal()
        printSubtitle("Character \(creatingCharacterIndex + 1) of \(totalCharacters)")
        print("Who controls this character?")
        print("")

        showMenu(["Human Player", "Computer (AI)", "< Back"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1:
                self.creatingAsAI = false
                self.startCharacterCreation()
            case 2:
                self.creatingAsAI = true
                self.autoCreateCharacter()
            default:
                if self.creatingCharacterIndex > 0 {
                    // Go back to previous character
                    self.creatingCharacterIndex -= 1
                    self.party.removeLast()
                    self.chooseCharacterType()
                } else {
                    self.startNewGame()
                }
            }
        }
    }

    // MARK: - Character Creation

    private let suggestedNames = [
        "Will the Wise", "Eleven", "Zoomer", "Sundar the Bold",
        "Eddie Munson", "Lady Applejack", "Steve", "Nancy",
        "Hopper", "Robin", "Jonathan", "Murray", "Joyce", "Nog"
    ]

    func startCharacterCreation() {
        clearTerminal()
        gameState = .characterCreation

        printSubtitle("Character \(creatingCharacterIndex + 1) of \(totalCharacters)")

        // Show name suggestions (exclude already-used names)
        let existingNames = Set(party.map { $0.name.lowercased() })
        let available = suggestedNames.filter { !existingNames.contains($0.lowercased()) }
        let suggestions = available.shuffled().prefix(4).joined(separator: ", ")
        print("  Suggestions: \(suggestions)", color: .dimGreen)
        if !party.isEmpty {
            let taken = party.map { $0.name }.joined(separator: ", ")
            print("  Already in party: \(taken)", color: .dimGreen)
        }
        print("")

        promptTextWithMenu("Enter character name (or 'a' for auto):", options: ["< Back"])

        menuHandler = { [weak self] _ in
            guard let self = self else { return }
            if self.creatingCharacterIndex > 0 {
                self.creatingCharacterIndex -= 1
                self.party.removeLast()
                self.chooseCharacterType()
            } else {
                self.startNewGame()
            }
        }

        inputHandler = { [weak self] name in
            guard let self = self else { return }
            if self.isReservedWord(name) {
                if self.creatingCharacterIndex > 0 {
                    self.creatingCharacterIndex -= 1
                    self.party.removeLast()
                    self.chooseCharacterType()
                } else {
                    self.clearTerminal()
                    self.startNewGame()
                }
                return
            }
            let lower = name.lowercased()
            if lower == "a" || lower == "auto" {
                self.autoCreateCharacter()
                return
            }
            let cleanName = name.isEmpty ? "Adventurer" : name
            if !self.isNameAppropriate(cleanName) {
                self.print("That name is not befitting of an adventurer. Try again.", color: .yellow)
                self.print("")
                self.startCharacterCreation()
                return
            }
            // Check for duplicate character name
            let isDuplicate = self.party.contains(where: {
                $0.name.lowercased() == cleanName.lowercased()
            })
            if isDuplicate {
                self.print("A character named \(cleanName) already exists in your party. Choose a different name.", color: .yellow)
                self.print("")
                self.startCharacterCreation()
                return
            }
            self.tempCharacterName = cleanName
            self.chooseRace()
        }
    }

    func chooseRace() {
        clearTerminal()
        printSubtitle("Choose Race for \(tempCharacterName)")

        let races = Race.allCases
        var raceNames = races.map { "\($0.rawValue)" }
        raceNames.append("< Back")

        showMenu(raceNames)

        menuHandler = { [weak self] choice in
            if choice == raceNames.count {
                self?.startCharacterCreation()
                return
            }
            self?.tempRace = races[choice - 1]
            self?.chooseClass()
        }

        // Long-press: pick this race and auto-fill rest
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= races.count {
                self.tempRace = races[choice - 1]
                self.tempClass = CharacterClass.allCases.randomElement()
                self.autoAssignAndFinish()
            }
        }
    }

    func chooseClass() {
        clearTerminal()
        printSubtitle("Choose Class for \(tempCharacterName)")

        let classes = CharacterClass.allCases
        var classNames = classes.map { "\($0.rawValue) (d\($0.hitDie) HP)" }
        classNames.append("< Back")

        showMenu(classNames)

        menuHandler = { [weak self] choice in
            if choice == classNames.count {
                self?.chooseRace()
                return
            }
            self?.tempClass = classes[choice - 1]
            self?.chooseAbilityMethod()
        }

        // Long-press: pick this class and auto-fill rest
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= classes.count {
                self.tempClass = classes[choice - 1]
                self.autoAssignAndFinish()
            }
        }
    }

    func chooseAbilityMethod() {
        clearTerminal()
        printSubtitle("Ability Score Method")

        print("Choose how to generate ability scores:")
        print("")

        showMenu(["Auto (Recommended)", "Standard Array [15,14,13,12,10,8]", "Roll 4d6 drop lowest", "< Back"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 4 {
                self.chooseClass()
                return
            }
            if choice == 1 {
                // Auto-assign standard array optimally for this class
                self.tempScores = AbilityScores.standardArray
                self.autoAssignScores()
                return
            }
            if choice == 2 {
                self.tempScores = AbilityScores.standardArray
            } else {
                self.tempScores = Dice.rollAbilityScores()
                self.print("You rolled: \(self.tempScores ?? [])", color: .brightGreen)
            }
            self.startAssigningScores()
        }

        // Long-press on any option: auto-assign scores and finish
        menuLongPressHandler = { [weak self] _ in
            self?.autoAssignAndFinish()
        }
    }

    func autoAssignScores() {
        guard let charClass = tempClass else { return }

        let sorted = tempScores.sorted(by: >)
        let priority = charClass.abilityPriority

        assignedScores = [:]
        for (i, ability) in priority.enumerated() {
            assignedScores[ability] = sorted[i]
        }

        clearTerminal()
        print("Auto-assigned scores for \(charClass.rawValue):", color: .brightGreen)
        print("")
        for ability in Ability.allCases {
            let score = assignedScores[ability] ?? 10
            let isPrimary = ability == charClass.primaryAbility
            let marker = isPrimary ? " (Primary)" : ""
            print("  \(ability.rawValue): \(score)\(marker)", color: isPrimary ? .brightGreen : .green)
        }
        print("")

        remainingScores = []
        remainingAbilities = []
        chooseSkills()
    }

    /// Auto-assign scores, skills and finish from current temp state (name/race/class already set)
    private func autoAssignAndFinish() {
        if tempRace == nil { tempRace = Race.allCases.randomElement() }
        if tempClass == nil { tempClass = CharacterClass.allCases.randomElement() }
        guard let charClass = tempClass else { return }

        // Auto-assign scores
        tempScores = AbilityScores.standardArray
        let sorted = tempScores.sorted(by: >)
        assignedScores = [:]
        for (i, ability) in charClass.abilityPriority.enumerated() {
            assignedScores[ability] = sorted[i]
        }
        remainingScores = []
        remainingAbilities = []

        // Auto-select skills
        selectedSkills = Array(charClass.skillChoices.shuffled().prefix(charClass.numSkillChoices))

        finishCharacterCreation()
    }

    /// Fully auto-create a character with random name, race, class, scores, and skills
    func autoCreateCharacter() {
        // Random unique name
        tempCharacterName = pickUniqueName()
        // Random race & class
        tempRace = Race.allCases.randomElement()
        tempClass = CharacterClass.allCases.randomElement()

        guard let charClass = tempClass else { return }

        // Auto-assign scores
        tempScores = AbilityScores.standardArray
        let sorted = tempScores.sorted(by: >)
        assignedScores = [:]
        for (i, ability) in charClass.abilityPriority.enumerated() {
            assignedScores[ability] = sorted[i]
        }
        remainingScores = []
        remainingAbilities = []

        // Auto-select skills
        selectedSkills = Array(charClass.skillChoices.shuffled().prefix(charClass.numSkillChoices))

        // Show result for confirmation
        clearTerminal()
        printSubtitle("Auto-Generated Character")
        print("  Name:  \(tempCharacterName)", color: .brightGreen)
        print("  Race:  \(tempRace?.rawValue ?? "?")", color: .green)
        print("  Class: \(charClass.rawValue)", color: .green)
        print("")
        for ability in Ability.allCases {
            let score = assignedScores[ability] ?? 10
            let isPrimary = ability == charClass.primaryAbility
            let marker = isPrimary ? " *" : ""
            print("  \(ability.abbreviation): \(score)\(marker)", color: isPrimary ? .brightGreen : .green)
        }
        print("")
        let skillStr = selectedSkills.map { $0.rawValue }.joined(separator: ", ")
        print("  Skills: \(skillStr)", color: .green)
        print("")

        showMenu(["Accept", "< Back", "Reroll"])
        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.finishCharacterCreation()
            case 2: self?.startCharacterCreation()
            case 3: self?.autoCreateCharacter()
            default: break
            }
        }
    }

    func startAssigningScores() {
        remainingScores = tempScores.sorted(by: >)
        assignedScores = [:]
        remainingAbilities = Ability.allCases

        if let charClass = tempClass {
            print("")
            print("Tip: \(charClass.rawValue)s use \(charClass.primaryAbility.rawValue) as primary.", color: .cyan)
        }

        assignNextScore()
    }

    func assignNextScore() {
        if remainingAbilities.isEmpty {
            chooseSkills()
            return
        }

        clearTerminal()
        print("Scores remaining: \(remainingScores)", color: .brightGreen)
        print("")
        print("Assign score to which ability?")
        print("")

        var abilityNames = remainingAbilities.map { ability -> String in
            let isPrimary = ability == tempClass?.primaryAbility
            return isPrimary ? "\(ability.rawValue) (Recommended)" : ability.rawValue
        }
        abilityNames.append("< Back (restart scores)")

        showMenu(abilityNames)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == abilityNames.count {
                self.chooseAbilityMethod()
                return
            }
            let ability = self.remainingAbilities[choice - 1]
            self.selectScoreForAbility(ability)
        }
    }

    func selectScoreForAbility(_ ability: Ability) {
        print("")
        print("Choose score for \(ability.rawValue):")

        var scoreOptions = remainingScores.map { String($0) }
        scoreOptions.append("< Back")

        showMenu(scoreOptions)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == scoreOptions.count {
                self.assignNextScore()
                return
            }
            let score = self.remainingScores[choice - 1]
            self.assignedScores[ability] = score
            self.remainingScores.remove(at: choice - 1)
            self.remainingAbilities.removeAll { $0 == ability }
            self.assignNextScore()
        }
    }

    func chooseSkills() {
        guard let charClass = tempClass else { return }

        clearTerminal()
        printSubtitle("Choose Skills")

        selectedSkills = []
        let availableSkills = charClass.skillChoices
        let numChoices = charClass.numSkillChoices

        print("Choose \(numChoices) skills from your class list:")
        print("")

        selectNextSkill(from: availableSkills, remaining: numChoices)
    }

    func selectNextSkill(from available: [Skill], remaining: Int) {
        if remaining == 0 {
            finishCharacterCreation()
            return
        }

        if !selectedSkills.isEmpty {
            let chosen = selectedSkills.map { $0.rawValue }.joined(separator: ", ")
            print("Selected: \(chosen)", color: .brightGreen)
            print("")
        }

        let unselected = available.filter { !selectedSkills.contains($0) }
        var skillNames = unselected.map { $0.rawValue }
        skillNames.append("Restart Skills")
        skillNames.append("< Back")

        print("Skill \(selectedSkills.count + 1) of \(selectedSkills.count + remaining):")
        showMenu(skillNames)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == skillNames.count {
                // Back — go up a level to ability method
                self.chooseAbilityMethod()
                return
            }
            if choice == skillNames.count - 1 {
                // Restart skills from scratch
                self.chooseSkills()
                return
            }
            let skill = unselected[choice - 1]
            self.selectedSkills.append(skill)
            self.selectNextSkill(from: available, remaining: remaining - 1)
        }

        // Long-press: pick this skill and auto-fill rest randomly
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= unselected.count {
                self.selectedSkills.append(unselected[choice - 1])
                let stillNeeded = remaining - 1
                if stillNeeded > 0 {
                    let leftover = unselected.filter { !self.selectedSkills.contains($0) }
                    let autoSkills = Array(leftover.shuffled().prefix(stillNeeded))
                    self.selectedSkills.append(contentsOf: autoSkills)
                }
                self.finishCharacterCreation()
            }
        }
    }

    func finishCharacterCreation() {
        guard let race = tempRace, let charClass = tempClass else { return }

        var scores = AbilityScores(
            strength: assignedScores[.strength] ?? 10,
            dexterity: assignedScores[.dexterity] ?? 10,
            constitution: assignedScores[.constitution] ?? 10,
            intelligence: assignedScores[.intelligence] ?? 10,
            wisdom: assignedScores[.wisdom] ?? 10,
            charisma: assignedScores[.charisma] ?? 10
        )

        // Apply racial bonuses
        for (ability, bonus) in race.abilityBonuses {
            let current = scores.score(for: ability)
            scores.set(ability, to: current + bonus)
        }

        let character = Character(
            name: tempCharacterName,
            race: race,
            characterClass: charClass,
            abilityScores: scores,
            isComputerControlled: creatingAsAI
        )

        // Add skill proficiencies
        for skill in selectedSkills {
            character.skillProficiencies.insert(skill)
        }

        // Starting gold
        character.gold = Dice.rollSum(4, d: 4) * 10

        // Auto-assign default starting equipment for class
        let equipOptions = ItemCatalog.startingEquipmentOptions(for: charClass)
        if let (_, items) = equipOptions.first {
            for item in items {
                _ = character.addItem(item)
            }
        }
        autoEquip(character)

        // Assign starting spells and spell slots
        let startingSpells = SpellCatalog.startingSpells(for: charClass)
        if !startingSpells.isEmpty {
            character.knownSpells = startingSpells
            character.spellSlots = SpellCatalog.startingSlots(for: charClass, level: 1)
        }

        // Barbarian starts with rage uses
        if charClass == .barbarian {
            character.rageUsesRemaining = character.rageMaxUses
        }

        party.append(character)

        clearTerminal()
        print("\(character.name) joins the party!", color: .brightGreen, bold: true)
        print("")
        printLines(character.displaySheet())
        print("")

        if let w = character.equippedWeapon {
            print("  Weapon: \(w.name)", color: .cyan)
        }
        if let a = character.equippedArmor {
            print("  Armor: \(a.name)", color: .cyan)
        }
        if let s = character.equippedShield {
            print("  Shield: \(s.name)", color: .cyan)
        }

        // Show other items in bag
        let otherItems = character.inventory.filter { item in
            item.id != character.equippedWeapon?.id &&
            item.id != character.equippedArmor?.id &&
            item.id != character.equippedShield?.id
        }
        if !otherItems.isEmpty {
            print("  Also carrying:", color: .dimGreen)
            for item in otherItems {
                print("    \(item.name)", color: .dimGreen)
            }
        }

        // Show spells
        if !character.knownSpells.isEmpty {
            print("")
            let cantrips = character.knownSpells.filter { $0.level == .cantrip }
            let leveled = character.knownSpells.filter { $0.level != .cantrip }
            if !cantrips.isEmpty {
                print("  Cantrips:", color: .cyan)
                for s in cantrips { print("    \(s.name) — \(s.description)", color: .dimGreen) }
            }
            if !leveled.isEmpty {
                let slots = character.spellSlots
                print("  Spells (slots: \(slots.level1Current)/\(slots.level1Max)):", color: .cyan)
                for s in leveled { print("    \(s.name) — \(s.description)", color: .dimGreen) }
            }
        }
        print("")

        waitForContinue()

        inputHandler = { [weak self] _ in
            guard let self = self else { return }
            self.creatingCharacterIndex += 1
            if self.creatingCharacterIndex < self.totalCharacters {
                self.chooseCharacterType()
            } else {
                self.startAdventure()
            }
        }
    }

    func chooseStartingEquipment(for character: Character) {
        clearTerminal()
        printSubtitle("Starting Equipment for \(character.name)")

        let equipOptions = ItemCatalog.startingEquipmentOptions(for: character.characterClass)

        print("Choose your starting equipment:", color: .cyan)
        print("  Carry capacity: \(String(format: "%.0f", character.carryCapacity)) lb", color: .dimGreen)
        print("")

        for (i, (name, items)) in equipOptions.enumerated() {
            print("  Option \(i + 1): \(name)", color: .brightGreen)
            for item in items {
                print("    - \(item.name) (\(String(format: "%.1f", item.weight))lb)", color: .dimGreen)
            }
            print("")
        }

        var menuOptions: [String] = []
        for (name, items) in equipOptions {
            let totalWeight = items.reduce(0.0) { $0 + $1.weight }
            menuOptions.append("\(name) (\(String(format: "%.0f", totalWeight)) lb)")
        }

        showMenu(menuOptions)

        menuHandler = { [weak self] choice in
            guard let self = self, choice > 0 && choice <= equipOptions.count else { return }

            let (_, items) = equipOptions[choice - 1]

            for item in items {
                _ = character.addItem(item)
            }

            // Auto-equip best weapon and armor
            self.autoEquip(character)

            self.clearTerminal()
            self.print("Equipment loaded!", color: .brightGreen, bold: true)
            self.print("")
            self.printLines(character.displaySheet())
            self.print("")

            if let w = character.equippedWeapon {
                self.print("  Equipped weapon: \(w.name)", color: .cyan)
            }
            if let a = character.equippedArmor {
                self.print("  Equipped armor: \(a.name)", color: .cyan)
            }
            if let s = character.equippedShield {
                self.print("  Equipped shield: \(s.name)", color: .cyan)
            }
            self.print("")

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                guard let self = self else { return }
                self.creatingCharacterIndex += 1
                if self.creatingCharacterIndex < self.totalCharacters {
                    self.chooseCharacterType()
                } else {
                    self.startAdventure()
                }
            }
        }
    }

    private func autoEquip(_ character: Character) {
        if let weapon = character.inventory.first(where: { $0.type == .weapon }) {
            character.equipWeapon(weapon)
        }
        if let armor = character.inventory
            .filter({ $0.type == .armor })
            .sorted(by: { ($0.armorStats?.baseAC ?? 0) > ($1.armorStats?.baseAC ?? 0) })
            .first {
            character.equipArmor(armor)
        }
        if let shield = character.inventory.first(where: { $0.type == .shield }) {
            character.equipShield(shield)
        }
    }

    // MARK: - Adventure

    func startAdventure() {
        clearTerminal()
        printTitle("Adventure Awaits!")

        promptTextWithMenu("Name your dungeon (or press Enter for default):", options: ["< Back"])

        menuHandler = { [weak self] _ in
            self?.clearTerminal()
            self?.startNewGame()
        }

        inputHandler = { [weak self] name in
            guard let self = self else { return }
            if self.isReservedWord(name) {
                self.clearTerminal()
                self.startNewGame()
                return
            }
            let dungeonName = name.isEmpty ? "The Dark Depths" : name
            if !self.isNameAppropriate(dungeonName) {
                self.print("The DM frowns. Choose a more suitable name for your dungeon.", color: .yellow)
                self.print("")
                self.startAdventure()
                return
            }
            self.tempDungeonName = dungeonName
            self.selectDifficulty(dungeonName: dungeonName)
        }
    }

    func selectDifficulty(dungeonName: String) {
        print("")
        print("Choose difficulty:")

        showMenu(["Easy (Level 1)", "Medium (Level 2)", "Hard (Level 3)", "< Back"])

        menuHandler = { [weak self] choice in
            if choice == 4 {
                self?.clearTerminal()
                self?.startAdventure()
                return
            }
            self?.dungeon = Dungeon(name: dungeonName, level: choice)
            self?.enterDungeon()
        }
    }

    private func enterDungeon() {
        clearTerminal()
        gameState = .exploring
        gameTimeMinutes = 360  // 6:00 AM
        adventureLog = []
        roomsSinceLastSave = 0
        DMEngine.shared.clearHistory()
        dmChatLog = []
        logEvent("Entered \(dungeon?.name ?? "the dungeon")", category: "EXPLORE")
        SoundManager.shared.startMusic(.exploration)
        showExplorationView()
    }

    // MARK: - Exploration

    /// Redraws the full exploration screen: map + room description + party + menu
    func showExplorationView() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }

        SpeechEngine.shared.stop()
        clearTerminal()

        // Always show the map at the top
        let mapLines = dungeon.getMapDisplay()
        printLines(mapLines, color: .dimGreen, size: mapFontSize)
        print("")

        // Room description
        print(room.name, color: .brightGreen, bold: true)
        print(room.roomDescription)

        if !room.cleared && room.encounter != nil {
            print("You sense danger here...", color: .red)
        }
        if !room.treasure.isEmpty && room.cleared {
            print("You see treasure on the ground.", color: .yellow)
        }

        let exitList = room.exits.keys.map { $0.rawValue }.joined(separator: ", ")
        if !exitList.isEmpty {
            print("Exits: \(exitList)", color: .dimGreen)
        }

        print("")

        // Party status
        let levelStr = dungeon.level > 0 ? "Level \(dungeon.level) | " : ""
        print("\(levelStr)\(formattedGameTime())", color: .dimGreen)
        for char in party {
            print(" \(char.name) \(char.currentHP)/\(char.maxHP) HP", color: .cyan)
        }
        print("")

        // Check for encounter
        if !room.cleared, let encounter = room.encounter {
            print("Enemies ahead!", color: .red, bold: true)
            startCombat(encounter: encounter)
            return
        }

        // Trigger trap in trap rooms (once per room)
        if !room.trapTriggered && room.roomType == .trap {
            room.trapTriggered = true
            room.cleared = true
            triggerTrap(in: room)
            return
        }

        // Build direction exits for the D-pad
        var exits: [Direction: Bool] = [:]
        for direction in Direction.allCases {
            exits[direction] = room.exits[direction] != nil
        }

        // Build menu options (non-direction actions)
        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        menuOpts.append(MenuOption("Search Room"))
        actions.append { [weak self] in self?.searchRoom() }

        if !room.treasure.isEmpty {
            menuOpts.append(MenuOption("Collect Treasure"))
            actions.append { [weak self] in self?.collectTreasure() }
        }

        menuOpts.append(MenuOption("Party Status"))
        actions.append { [weak self] in self?.showPartyStatus() }

        menuOpts.append(MenuOption("Inventory"))
        actions.append { [weak self] in self?.showInventory() }

        if room.roomType == .armory && (room.cleared || room.encounter == nil) {
            menuOpts.append(MenuOption("Visit Merchant"))
            actions.append { [weak self] in self?.visitShop() }
        }

        menuOpts.append(MenuOption("Rest"))
        actions.append { [weak self] in self?.rest() }

        if DMEngine.shared.adLibLevel != .off {
            menuOpts.append(MenuOption("Ask the DM"))
            actions.append { [weak self] in self?.askTheDM() }
        }

        menuOpts.append(MenuOption("Save Game"))
        actions.append { [weak self] in self?.showSaveMenu() }

        menuOpts.append(MenuOption("Main Menu"))
        actions.append { [weak self] in self?.confirmExitToMainMenu() }

        showMenuWithDirections(menuOpts, exits: exits)

        directionHandler = { [weak self] direction in
            self?.move(direction)
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    func move(_ direction: Direction) {
        guard let dungeon = dungeon else { return }

        let result = dungeon.move(direction: direction)
        if result.success {
            advanceTime(10)
            if let room = dungeon.currentRoom {
                logEvent("Moved \(direction.rawValue) to \(room.name)", category: "EXPLORE")
            }
            autosaveIfNeeded()
        } else {
            print(result.message, color: .yellow)
        }
        showExplorationView()
    }

    private func triggerTrap(in room: Room) {
        let traps: [(name: String, desc: String, dice: Int, sides: Int)] = [
            ("Poison Dart Trap", "Darts shoot from hidden holes in the walls!", 1, 6),
            ("Pit Trap", "The floor gives way beneath your feet!", 1, 8),
            ("Swinging Blade", "A blade swings from a concealed slot!", 1, 10),
            ("Flame Jet", "Fire erupts from vents in the floor!", 2, 6),
            ("Falling Net", "A weighted net drops from the ceiling!", 1, 4),
            ("Poison Gas", "A sickly green gas seeps from the walls!", 1, 6),
        ]

        let trap = traps.randomElement()!
        let damage = Dice.rollSum(trap.dice, d: trap.sides)

        print("")
        print("*** TRAP! ***", color: .red, bold: true)
        print(trap.desc, color: .red)
        print("  \(trap.name) — \(damage) damage!", color: .red)
        print("")

        SoundManager.shared.playDeath()

        // Damage a random party member (or the lead)
        let target = party.randomElement() ?? party[0]
        target.takeDamage(damage)
        print("  \(target.name) takes \(damage) damage! (\(target.currentHP)/\(target.maxHP) HP)", color: .yellow)

        if !target.isConscious {
            print("  \(target.name) is knocked unconscious!", color: .red, bold: true)
        }

        logEvent("Trap: \(trap.name) hit \(target.name) for \(damage) damage", category: "TRAP")

        print("")
        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    /// Apply a DM-requested movement, validating against actual dungeon exits
    private func applyTeleportToEntrance() {
        guard let dungeon = dungeon else { return }
        let entranceId = 0  // Entrance is always room 0
        if let entrance = dungeon.rooms[entranceId] {
            dungeon.previousRoomId = dungeon.currentRoomId
            dungeon.currentRoomId = entranceId
            entrance.visited = true
            print("")
            print("  [TELEPORTED to \(entrance.name)!]", color: .cyan, bold: true)
            print("")
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            logEvent("Teleported to dungeon entrance", category: "DM")
        }
    }

    private func applyDMMovement(_ dirName: String) {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }

        let direction: Direction?
        switch dirName.lowercased() {
        case "north": direction = .north
        case "south": direction = .south
        case "east":  direction = .east
        case "west":  direction = .west
        default: direction = nil
        }

        guard let dir = direction else {
            print("  [The DM tried an invalid direction.]", color: .dimGreen)
            return
        }

        // Validate the exit actually exists
        if room.exits[dir] != nil {
            let result = dungeon.move(direction: dir)
            if result.success {
                advanceTime(10)
                if let newRoom = dungeon.currentRoom {
                    logEvent("DM moved party \(dir.rawValue) to \(newRoom.name)", category: "DM")
                    print("")
                    print("  [Moved \(dir.rawValue) to \(newRoom.name)!]", color: .cyan, bold: true)
                    print("")
                    printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
                }
            }
        } else {
            print("  [No exit \(dir.rawValue) — the DM's path is blocked.]", color: .dimGreen)
        }
    }

    private func applyDMDropItem(_ itemName: String) {
        let lower = itemName.lowercased()
        for char in party {
            if let item = char.inventory.first(where: { $0.name.lowercased().contains(lower) }) {
                char.removeItem(item)
                print("  [Dropped: \(item.name)]", color: .yellow, bold: true)
                logEvent("DM: \(char.name) dropped \(item.name)", category: "DM")
                return
            }
            // Check equipped items
            if let w = char.equippedWeapon, w.name.lowercased().contains(lower) {
                char.unequipWeapon()
                char.removeItem(w)
                print("  [Dropped: \(w.name)]", color: .yellow, bold: true)
                logEvent("DM: \(char.name) dropped \(w.name)", category: "DM")
                return
            }
        }
        print("  [No \(itemName) found to drop.]", color: .dimGreen)
    }

    private func applyDMEquipItem(_ itemName: String) {
        let lower = itemName.lowercased()
        for char in party {
            if let item = char.inventory.first(where: { $0.name.lowercased().contains(lower) }) {
                switch item.type {
                case .weapon: char.equipWeapon(item)
                case .armor: char.equipArmor(item)
                case .shield: char.equipShield(item)
                default:
                    print("  [\(item.name) cannot be equipped.]", color: .dimGreen)
                    return
                }
                print("  [Equipped: \(item.name)!]", color: .cyan, bold: true)
                logEvent("DM: \(char.name) equipped \(item.name)", category: "DM")
                return
            }
        }
        print("  [No \(itemName) found to equip.]", color: .dimGreen)
    }

    private func applyDMUseItem(_ itemName: String) {
        let lower = itemName.lowercased()
        for char in party {
            if let item = char.inventory.first(where: { $0.name.lowercased().contains(lower) }) {
                if let healStr = item.potionStats?.healAmount {
                    char.removeItem(item)
                    let roll = Dice.rollDamage(healStr)
                    let amount = max(1, roll.total)
                    char.heal(amount)
                    print("  [\(char.name) uses \(item.name): +\(amount) HP!]", color: .brightGreen, bold: true)
                    logEvent("DM: \(char.name) used \(item.name), healed \(amount) HP", category: "DM")
                } else {
                    char.removeItem(item)
                    print("  [\(char.name) uses \(item.name).]", color: .cyan, bold: true)
                    logEvent("DM: \(char.name) used \(item.name)", category: "DM")
                }
                return
            }
        }
        print("  [No \(itemName) found to use.]", color: .dimGreen)
    }

    func searchRoom() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        print("You search the room carefully...", color: .cyan)
        print("")

        advanceTime(15)

        let roll = Dice.d20()
        let bestPerception = party.map { $0.skillModifier(for: .perception) }.max() ?? 0
        let total = roll + bestPerception

        if total >= 15 {
            print("You found something!", color: .brightGreen)
            let findRoll = Dice.d6()
            if findRoll >= 5 {
                // Find an item
                let level = dungeon?.level ?? 1
                let itemPool: [String]
                if level >= 3 {
                    itemPool = ["Potion of Greater Healing", "Rapier", "Longsword", "Shield", "Studded Leather"]
                } else if level >= 2 {
                    itemPool = ["Potion of Healing", "Shortsword", "Dagger", "Leather Armor", "Shield"]
                } else {
                    itemPool = ["Potion of Healing", "Dagger", "Torch", "Rope"]
                }
                let itemName = itemPool.randomElement()!
                if let item = resolveItemByName(itemName) {
                    print("  Hidden stash: \(item.name)!", color: .brightGreen)
                    showItemPickupMenu(item: item, source: "Hidden stash") { [weak self] in
                        self?.showExplorationView()
                    }
                    return
                }
            } else if findRoll >= 3 {
                let gold = Dice.rollSum(2, d: 6) * 5
                print("  Hidden stash: \(gold) gold pieces!", color: .yellow)
                showGoldPickupMenu(gold: gold, source: "Hidden stash") { [weak self] in
                    self?.showExplorationView()
                }
                return
            } else {
                print("A secret alcove, but it's empty.")
                logEvent("Searched room — found an empty alcove", category: "EXPLORE")
            }
        } else {
            print("You don't find anything of interest.")
            logEvent("Searched room — found nothing", category: "EXPLORE")
        }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    func collectTreasure() {
        guard let room = dungeon?.currentRoom, !room.treasure.isEmpty else {
            print("No treasure to collect.")
            showExplorationView()
            return
        }

        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        print("Collected treasure:", color: .brightGreen, bold: true)
        print("")

        // Separate gold from pickable items
        var totalGold = 0
        var pickableItems: [Item] = []
        var itemNames: [String] = []

        for treasureItem in room.treasure {
            itemNames.append(treasureItem.name)
            if treasureItem.type == .gold {
                totalGold += treasureItem.value
                print("  \(treasureItem.name)", color: .yellow)
            } else if treasureItem.type == .gem {
                let gemItem = Item(id: UUID(), name: treasureItem.name,
                                   description: "A precious gem worth \(treasureItem.value)gp.",
                                   type: .gem, weight: 0.1, value: treasureItem.value,
                                   weaponStats: nil, armorStats: nil, potionStats: nil)
                pickableItems.append(gemItem)
                print("  \(treasureItem.name) (\(treasureItem.value)gp)", color: .brightGreen)
            } else if treasureItem.type == .potion || treasureItem.type == .item {
                if let item = resolveItemByName(treasureItem.name) {
                    pickableItems.append(item)
                    print("  \(item.name)", color: .brightGreen)
                } else {
                    totalGold += treasureItem.value
                    print("  \(treasureItem.name) — \(treasureItem.value)gp", color: .yellow)
                }
            }
        }

        room.treasure.removeAll()

        if !itemNames.isEmpty {
            logEvent("Found treasure: \(itemNames.joined(separator: ", "))", category: "LOOT")
        }

        // Show pickup menus for gold and items
        if totalGold > 0 || !pickableItems.isEmpty {
            waitForContinue()
            inputHandler = { [weak self] _ in
                self?.showLootSequence(gold: totalGold, goldSource: "Treasure",
                                       items: pickableItems, itemSource: "Treasure") { [weak self] in
                    self?.showExplorationView()
                }
            }
        } else {
            waitForContinue()
            inputHandler = { [weak self] _ in
                self?.showExplorationView()
            }
        }
    }

    // MARK: - Item Pickup

    /// Show a menu for a found item — pick up, equip, use, or leave it
    private func showItemPickupMenu(item: Item, source: String, onDone: @escaping () -> Void) {
        clearTerminal()

        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        printSubtitle("Found: \(item.name)")
        print("  \(source)", color: .dimGreen)
        print("")
        print("  \(item.description)", color: .cyan)
        if let ws = item.weaponStats {
            print("  Damage: \(ws.damage) \(ws.damageType)", color: .dimGreen)
        }
        if let as_ = item.armorStats {
            print("  AC: \(as_.baseAC)", color: .dimGreen)
        }
        if let ps = item.potionStats {
            print("  Effect: \(ps.effect)", color: .dimGreen)
        }
        print("  Weight: \(String(format: "%.1f", item.weight))lb  Value: \(item.value)gp", color: .dimGreen)
        print("")

        var options: [String] = []
        var actions: [() -> Void] = []

        // Pick up options — one per character for multi-party, or just "Pick Up"
        if party.count > 1 {
            for char in party {
                let canCarry = char.canCarry(item)
                let tag = canCarry ? "" : " [too heavy]"
                options.append("\(char.name) picks up\(tag)")
                actions.append { [weak self] in
                    guard let self = self else { return }
                    if canCarry {
                        _ = char.addItem(item)
                        self.print("  \(char.name) takes the \(item.name).", color: .brightGreen)
                        self.logEvent("\(char.name) picked up \(item.name)", category: "LOOT")
                    } else {
                        self.print("  \(char.name) can't carry any more!", color: .yellow)
                    }
                    self.waitForContinue()
                    self.inputHandler = { _ in onDone() }
                }
            }
        } else if let char = party.first {
            let canCarry = char.canCarry(item)
            let tag = canCarry ? "" : " [too heavy]"
            options.append("Pick Up\(tag)")
            actions.append { [weak self] in
                guard let self = self else { return }
                if canCarry {
                    _ = char.addItem(item)
                    self.print("  \(char.name) takes the \(item.name).", color: .brightGreen)
                    self.logEvent("\(char.name) picked up \(item.name)", category: "LOOT")
                } else {
                    self.print("  Too heavy to carry!", color: .yellow)
                }
                self.waitForContinue()
                self.inputHandler = { _ in onDone() }
            }
        }

        // Equip option for weapon/armor/shield
        if item.type == .weapon || item.type == .armor || item.type == .shield {
            let label = item.type == .weapon ? "Equip as Weapon" : (item.type == .shield ? "Equip as Shield" : "Equip as Armor")
            options.append(label)
            actions.append { [weak self] in
                guard let self = self else { return }
                let doEquip = { (char: Character) in
                    switch item.type {
                    case .weapon: char.equipWeapon(item)
                    case .armor: char.equipArmor(item)
                    case .shield: char.equipShield(item)
                    default: break
                    }
                    self.print("  \(char.name) equips the \(item.name)!", color: .brightGreen)
                    self.logEvent("\(char.name) equipped \(item.name)", category: "LOOT")
                    self.waitForContinue()
                    self.inputHandler = { _ in onDone() }
                }
                if self.party.count > 1 {
                    self.pickCharacter(title: "Who equips it?") { char in doEquip(char) }
                } else if let char = self.party.first {
                    doEquip(char)
                }
            }
        }

        // Use option for potions
        if item.type == .potion, let healStr = item.potionStats?.healAmount {
            options.append("Use Now")
            actions.append { [weak self] in
                guard let self = self else { return }
                let doUse = { (char: Character) in
                    let roll = Dice.rollDamage(healStr)
                    let amount = max(1, roll.total)
                    char.heal(amount)
                    self.print("  \(char.name) drinks the \(item.name)!", color: .brightGreen)
                    self.print("  Restored \(amount) HP! (\(char.currentHP)/\(char.maxHP))", color: .brightGreen)
                    self.logEvent("\(char.name) used \(item.name) — healed \(amount) HP", category: "LOOT")
                    self.waitForContinue()
                    self.inputHandler = { _ in onDone() }
                }
                if self.party.count > 1 {
                    self.pickCharacter(title: "Who drinks it?") { char in doUse(char) }
                } else if let char = self.party.first {
                    doUse(char)
                }
            }
        }

        // Leave it
        options.append("Leave It")
        actions.append { [weak self] in
            self?.print("  You leave the \(item.name) behind.", color: .dimGreen)
            self?.waitForContinue()
            self?.inputHandler = { _ in onDone() }
        }

        showMenu(options)
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    /// Process multiple items one at a time
    private func showItemPickupSequence(items: [Item], source: String, onDone: @escaping () -> Void) {
        guard !items.isEmpty else {
            onDone()
            return
        }
        var remaining = items
        let current = remaining.removeFirst()
        showItemPickupMenu(item: current, source: source) { [weak self] in
            self?.showItemPickupSequence(items: remaining, source: source, onDone: onDone)
        }
    }

    /// Show a menu for found gold — pick up or leave it
    private func showGoldPickupMenu(gold: Int, source: String, onDone: @escaping () -> Void) {
        clearTerminal()

        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        printSubtitle("Found: \(gold) Gold Pieces")
        print("  \(source)", color: .dimGreen)
        print("")

        var options: [String] = []

        if party.count > 1 {
            options.append("Pick Up (split \(gold / party.count)gp each)")
        } else {
            options.append("Pick Up (+\(gold)gp)")
        }
        options.append("Leave It")

        showMenu(options)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                let goldEach = gold / self.party.count
                let remainder = gold % self.party.count
                for (i, char) in self.party.enumerated() {
                    char.gold += goldEach + (i == 0 ? remainder : 0)
                }
                if self.party.count > 1 {
                    self.print("  Party collects \(gold) gold (\(goldEach)gp each).", color: .yellow)
                } else {
                    self.print("  You pocket \(gold) gold pieces.", color: .yellow)
                }
                self.logEvent("Picked up \(gold) gold from \(source.lowercased())", category: "LOOT")
            } else {
                self.print("  You leave \(gold) gold behind.", color: .dimGreen)
                self.logEvent("Left \(gold) gold behind", category: "LOOT")
            }
            self.waitForContinue()
            self.inputHandler = { _ in onDone() }
        }
    }

    /// Process a mixed loot pile — gold first, then items one at a time
    private func showLootSequence(gold: Int, goldSource: String, items: [Item], itemSource: String, onDone: @escaping () -> Void) {
        if gold > 0 {
            showGoldPickupMenu(gold: gold, source: goldSource) { [weak self] in
                if !items.isEmpty {
                    self?.showItemPickupSequence(items: items, source: itemSource, onDone: onDone)
                } else {
                    onDone()
                }
            }
        } else if !items.isEmpty {
            showItemPickupSequence(items: items, source: itemSource, onDone: onDone)
        } else {
            onDone()
        }
    }

    // MARK: - Inventory

    private func pickCharacter(title: String, onBack: (() -> Void)? = nil, action: @escaping (Character) -> Void) {
        if party.count == 1 {
            action(party[0])
            return
        }

        clearTerminal()
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }
        printSubtitle(title)

        var options: [String] = []
        for char in party {
            options.append("\(char.name) — \(char.currentHP)/\(char.maxHP) HP, \(char.gold)gp")
        }
        options.append("< Back")

        showMenu(options)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == options.count {
                if let onBack = onBack { onBack() } else { self.showExplorationView() }
                return
            }
            guard choice > 0 && choice <= self.party.count else { return }
            action(self.party[choice - 1])
        }
    }

    func showInventory() {
        pickCharacter(title: "Whose inventory?") { [weak self] character in
            guard let self = self else { return }
            let back: () -> Void = self.party.count > 1
                ? { [weak self] in self?.showInventory() }
                : { [weak self] in self?.showExplorationView() }
            self.showInventoryFor(character, onBack: back)
        }
    }

    private func showInventoryFor(_ character: Character, onBack: (() -> Void)? = nil) {

        clearTerminal()

        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        printTitle("Inventory — \(character.name)")

        print("  Carry Weight: \(String(format: "%.0f", character.currentWeight)) / \(String(format: "%.0f", character.carryCapacity)) lb", color: character.isEncumbered ? .red : .cyan)
        print("  Gold: \(character.gold)", color: .yellow)
        print("")

        print("  EQUIPPED:", color: .cyan, bold: true)
        print("    Weapon: \(character.equippedWeapon?.name ?? "(none)")", color: .brightGreen)
        print("    Armor:  \(character.equippedArmor?.name ?? "(none)")", color: .brightGreen)
        print("    Shield: \(character.equippedShield?.name ?? "(none)")", color: .brightGreen)
        print("")

        print("  BAG:", color: .cyan, bold: true)
        if character.inventory.isEmpty {
            print("    (empty)", color: .dimGreen)
        } else {
            for item in character.inventory {
                let tag: String
                switch item.type {
                case .weapon: tag = "[W]"
                case .armor: tag = "[A]"
                case .shield: tag = "[S]"
                case .potion: tag = "[P]"
                case .scroll: tag = "[?]"
                case .gem: tag = "[$]"
                case .misc: tag = "[.]"
                }
                print("    \(tag) \(item.name) — \(String(format: "%.1f", item.weight))lb, \(item.value)gp", color: .green)
            }
        }
        print("")

        var options: [String] = []
        var actions: [() -> Void] = []

        let equipableWeapons = character.inventory.filter { $0.type == .weapon }
        let equipableArmor = character.inventory.filter { $0.type == .armor }
        let equipableShields = character.inventory.filter { $0.type == .shield }
        let usablePotions = character.inventory.filter { $0.type == .potion }

        if !equipableWeapons.isEmpty {
            options.append("Equip Weapon")
            actions.append { [weak self] in self?.showEquipMenu(character: character, type: .weapon, label: "Weapon", onBack: onBack) }
        }
        if !equipableArmor.isEmpty {
            options.append("Equip Armor")
            actions.append { [weak self] in self?.showEquipMenu(character: character, type: .armor, label: "Armor", onBack: onBack) }
        }
        if !equipableShields.isEmpty {
            options.append("Equip Shield")
            actions.append { [weak self] in self?.showEquipMenu(character: character, type: .shield, label: "Shield", onBack: onBack) }
        }
        if !usablePotions.isEmpty {
            options.append("Use Potion")
            actions.append { [weak self] in self?.showUsePotionMenu(character: character, onBack: onBack) }
        }
        if character.equippedWeapon != nil {
            options.append("Unequip Weapon")
            actions.append { [weak self] in
                character.unequipWeapon()
                self?.showInventoryFor(character, onBack: onBack)
            }
        }
        if character.equippedArmor != nil {
            options.append("Unequip Armor")
            actions.append { [weak self] in
                character.unequipArmor()
                self?.showInventoryFor(character, onBack: onBack)
            }
        }
        if !character.inventory.isEmpty {
            options.append("Drop Item")
            actions.append { [weak self] in self?.showDropItemMenu(character: character, onBack: onBack) }
        }

        options.append("< Back")
        let backAction = onBack ?? { [weak self] in self?.showExplorationView() }
        actions.append { backAction() }

        showMenu(options)
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showEquipMenu(character: Character, type: ItemType, label: String, onBack: (() -> Void)? = nil) {
        let items = character.inventory.filter { $0.type == type }

        clearTerminal()
        printSubtitle("Equip \(label)")

        var options: [String] = []
        for item in items {
            var desc = "\(item.name)"
            if let ws = item.weaponStats {
                desc += " (\(ws.damage) \(ws.damageType))"
            }
            if let as_ = item.armorStats {
                desc += " (AC \(as_.baseAC))"
            }
            options.append(desc)
        }
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == options.count {
                self?.showInventoryFor(character, onBack: onBack)
                return
            }
            guard choice > 0 && choice <= items.count else { return }
            let item = items[choice - 1]

            switch type {
            case .weapon: character.equipWeapon(item)
            case .armor: character.equipArmor(item)
            case .shield: character.equipShield(item)
            default: break
            }
            self?.showInventoryFor(character, onBack: onBack)
        }
    }

    private func showUsePotionMenu(character: Character, onBack: (() -> Void)? = nil) {
        let potions = character.inventory.filter { $0.type == .potion }

        clearTerminal()
        printSubtitle("Use Potion")
        print("  \(character.name) HP: \(character.currentHP)/\(character.maxHP)", color: .cyan)
        print("")

        var options: [String] = []
        for potion in potions {
            options.append("\(potion.name) — \(potion.potionStats?.effect ?? "")")
        }
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == options.count {
                self.showInventoryFor(character, onBack: onBack)
                return
            }
            guard choice > 0 && choice <= potions.count else { return }
            let potion = potions[choice - 1]

            // Parse heal amount and apply
            if let healStr = potion.potionStats?.healAmount {
                character.removeItem(potion)
                let roll = Dice.rollDamage(healStr)
                let amount = max(1, roll.total)
                character.heal(amount)

                self.print("")
                self.print("  \(character.name) drinks \(potion.name)!", color: .brightGreen)
                self.print("  Restored \(amount) HP! (\(character.currentHP)/\(character.maxHP))", color: .brightGreen)
            }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showInventoryFor(character, onBack: onBack)
            }
        }
    }

    private func showDropItemMenu(character: Character, onBack: (() -> Void)? = nil) {
        clearTerminal()
        printSubtitle("Drop Item")

        var options: [String] = []
        for item in character.inventory {
            options.append("\(item.name) (\(String(format: "%.1f", item.weight))lb)")
        }
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == options.count {
                self.showInventoryFor(character, onBack: onBack)
                return
            }
            guard choice > 0 && choice <= character.inventory.count else { return }
            let item = character.inventory[choice - 1]
            character.removeItem(item)
            self.print("")
            self.print("  Dropped \(item.name).", color: .yellow)
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showInventoryFor(character, onBack: onBack)
            }
        }
    }

    // MARK: - Shop

    func visitShop() {
        guard let dungeon = dungeon else { return }

        pickCharacter(title: "Who visits the merchant?") { [weak self] character in
            guard let self = self else { return }
            self.shopEngine.openShop(character: character, dungeonLevel: dungeon.level) { [weak self] in
                self?.showExplorationView()
            }
        }
    }

    func showPartyStatus() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        printLines(asciiParty, color: .cyan)
        print("")
        printTitle("Party Status")

        // Game time & level
        if let level = dungeon?.level {
            print("  Dungeon Level: \(level)", color: .cyan)
        }
        print("  Time: \(formattedGameTime())", color: .cyan)
        let roomsVisited = dungeon?.rooms.values.filter { $0.visited }.count ?? 0
        let totalRooms = dungeon?.rooms.count ?? 0
        print("  Explored: \(roomsVisited)/\(totalRooms) rooms", color: .cyan)
        print("")

        for char in party {
            printLines(char.characterClass.asciiArt, color: .cyan)

            // HP bar
            let hpFraction = Double(char.currentHP) / Double(char.maxHP)
            let barLen = 20
            let filled = Int(hpFraction * Double(barLen))
            let hpBar = String(repeating: "█", count: filled) + String(repeating: "░", count: barLen - filled)
            let hpColor: TerminalColor = hpFraction > 0.5 ? .brightGreen : (hpFraction > 0.25 ? .yellow : .red)

            printLines(char.displaySheet())
            print("  HP [\(hpBar)] \(char.currentHP)/\(char.maxHP)", color: hpColor)
            print("  Gold: \(char.gold)  XP: \(char.experiencePoints)", color: .yellow)
            print("")
        }

        showMenu(["Adventure Log", "Main Menu", "< Back"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.showAdventureLog()
            } else if choice == 2 {
                self?.confirmExitToMainMenu()
            } else {
                self?.showExplorationView()
            }
        }
    }

    func showAdventureLog() {
        clearTerminal()
        printTitle("Adventure Log")
        print("  Time: \(formattedGameTime())", color: .cyan)
        print("")

        if adventureLog.isEmpty {
            print("  No events recorded yet.", color: .dimGreen)
        } else {
            // Show most recent 50 entries with color-coding by category
            let recentLog = adventureLog.suffix(50)
            for entry in recentLog {
                let color: TerminalColor
                if entry.contains("[COMBAT]") { color = .red }
                else if entry.contains("[LOOT]") { color = .yellow }
                else if entry.contains("[DM]") { color = .cyan }
                else if entry.contains("[LEVEL]") { color = .brightGreen }
                else if entry.contains("[TRAP]") { color = .red }
                else { color = .dimGreen }
                print("  \(entry)", color: color)
            }
            if adventureLog.count > 50 {
                print("")
                print("  (\(adventureLog.count - 50) earlier entries omitted)", color: .dimGreen)
            }
        }

        print("")

        showMenu(["< Back"])
        menuHandler = { [weak self] _ in
            self?.showPartyStatus()
        }
    }

    func rest() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        print("Choose rest type:")

        showMenu(["Short Rest (Recover some HP)", "Long Rest (Full Recovery)", "< Back"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }

            if choice == 3 {
                self.showExplorationView()
                return
            }

            let isLongRest = choice == 2
            let repeats = isLongRest ? 3 : 1
            let header = isLongRest ? "Taking a long rest..." : "Resting..."

            self.clearTerminal()

            // Show map at top
            if let dungeon = self.dungeon {
                self.printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
                self.print("")
            }

            SoundManager.shared.stopMusic()
            self.print(header, color: .cyan, bold: true)
            if self.isHoldingScreen {
                self.print("(Hold screen to rest faster)", color: .dimGreen)
            }
            self.print("")

            self.playHourglassAnimation(repeats: repeats) { [weak self] in
                guard let self = self else { return }

                SoundManager.shared.playHeal()

                if !isLongRest {
                    self.advanceTime(60)
                    self.print("")
                    self.print("Short rest complete!", color: .cyan, bold: true)
                    self.print("")
                    var healed: [String] = []
                    for char in self.party {
                        let healAmount = Dice.rollSum(1, d: char.characterClass.hitDie)
                        char.heal(healAmount)
                        self.print("\(char.name) recovers \(healAmount) HP")
                        healed.append("\(char.name) +\(healAmount)HP")
                        if char.characterClass == .fighter {
                            char.secondWindUsed = false
                        }
                    }
                    self.logEvent("Short rest — \(healed.joined(separator: ", "))", category: "REST")
                } else {
                    self.advanceTime(480)
                    self.print("")
                    self.print("Long rest complete!", color: .cyan, bold: true)
                    self.print("")
                    for char in self.party {
                        char.heal(char.maxHP)
                        self.print("\(char.name) fully recovers!")
                        if !char.spellSlots.isEmpty {
                            char.spellSlots.restoreAll()
                            self.print("  Spell slots restored", color: .cyan)
                        }
                        char.secondWindUsed = false
                        if char.characterClass == .barbarian {
                            char.rageUsesRemaining = char.rageMaxUses
                            char.isRaging = false
                            self.print("  Rage uses restored", color: .cyan)
                        }
                        char.huntersMarkActive = false
                    }
                    self.logEvent("Long rest — party fully recovered", category: "REST")
                }

                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    SoundManager.shared.startMusic(.exploration)
                    self?.showExplorationView()
                }
            }
        }
    }

    // MARK: - Hourglass Animation

    private var hourglassFrames: [[String]] {
        [
            // Frame 0: full top
            [
                "    _____",
                "   |     |",
                "   |:::::|",
                "   |:::::|",
                "   |:::::|",
                "    \\:::/",
                "     \\:/",
                "     /:\\",
                "    /   \\",
                "   |     |",
                "   |     |",
                "   |     |",
                "   |_____|",
            ],
            // Frame 1: sand flowing
            [
                "    _____",
                "   |     |",
                "   |:::: |",
                "   | ::: |",
                "   |  :  |",
                "    \\ : /",
                "     \\:/",
                "     /:\\",
                "    / . \\",
                "   |     |",
                "   |  .  |",
                "   | ... |",
                "   |_____|",
            ],
            // Frame 2: half and half
            [
                "    _____",
                "   |     |",
                "   | ::: |",
                "   |  :  |",
                "   |     |",
                "    \\ : /",
                "     \\:/",
                "     /:\\",
                "    / . \\",
                "   | . . |",
                "   |:::::|",
                "   |:::::|",
                "   |_____|",
            ],
            // Frame 3: mostly bottom
            [
                "    _____",
                "   |     |",
                "   |  .  |",
                "   |     |",
                "   |     |",
                "    \\ : /",
                "     \\:/",
                "     /:\\",
                "    /:::\\",
                "   |:::::|",
                "   |:::::|",
                "   |:::::|",
                "   |_____|",
            ],
            // Frame 4: all bottom
            [
                "    _____",
                "   |     |",
                "   |     |",
                "   |     |",
                "   |     |",
                "    \\   /",
                "     \\ /",
                "     / \\",
                "    /:::\\",
                "   |:::::|",
                "   |:::::|",
                "   |:::::|",
                "   |_____|",
            ],
        ]
    }

    private func playHourglassAnimation(repeats: Int, completion: @escaping () -> Void) {
        let frames = hourglassFrames
        let frameCount = frames.count
        let totalFrames = frameCount * repeats

        // Track how many lines the hourglass uses so we can replace them
        let linesPerFrame = frames[0].count

        // Print initial frame
        printLines(frames[0], color: .yellow)

        var frameIndex = 1

        func showNextFrame() {
            if frameIndex >= totalFrames {
                completion()
                return
            }

            let delay = isHoldingScreen ? 0.15 : 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }

                // Remove previous frame lines
                let count = self.terminalLines.count
                if count >= linesPerFrame {
                    self.terminalLines.removeSubrange((count - linesPerFrame)..<count)
                }

                // Draw new frame
                let frame = frames[frameIndex % frameCount]
                self.printLines(frame, color: .yellow)

                frameIndex += 1
                showNextFrame()
            }
        }

        showNextFrame()
    }

    // MARK: - AI Dungeon Master

    func askTheDM() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        // Replay chat history
        if !dmChatLog.isEmpty {
            print("--- DM Conversation ---", color: .dimGreen)
            print("")
            for entry in dmChatLog {
                if entry.isUser {
                    print("> \(entry.text)", color: .cyan)
                } else {
                    print("DM:", color: .yellow, bold: true)
                    for paragraph in entry.text.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { print("") }
                        else { print("  \(trimmed)", color: .yellow) }
                    }
                }
                print("")
            }
            print("--- End of History ---", color: .dimGreen)
            print("")
        }

        print("The DM awaits your question...", color: .cyan, bold: true)
        print("(Type your question or action, or tap Back)", color: .dimGreen)
        print("")

        dmPromptForQuestion()
    }

    private func dmPromptForQuestion() {
        promptTextWithMenu(">", options: ["< Back"])

        menuHandler = { [weak self] _ in
            self?.showExplorationView()
        }

        inputHandler = { [weak self] input in
            guard let self = self else { return }

            if self.isReservedWord(input) || input.isEmpty {
                self.showExplorationView()
                return
            }

            self.dmChatLog.append((isUser: true, text: input))
            self.print("")
            self.print("The DM considers...", color: .dimGreen)

            let context = self.buildDMContext()

            DMEngine.shared.ask(input, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    let result = DMEngine.parseCommands(from: response)
                    let adLibLevel = DMEngine.shared.adLibLevel
                    let displayText = adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue ? result.cleanText : response

                    self.dmChatLog.append((isUser: false, text: displayText))

                    self.print("")
                    self.print("DM:", color: .yellow, bold: true)
                    for paragraph in displayText.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { self.print("") }
                        else { self.print("  \(trimmed)", color: .yellow) }
                    }

                    // Apply DM commands at moderate and full levels
                    var worldChanged = false
                    var pendingPickupItems: [Item] = []
                    var pendingGold = 0
                    if adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue {
                        if result.bonusGold > 0 {
                            pendingGold = result.bonusGold
                            self.print("")
                            self.print("  [Found \(result.bonusGold) gold!]", color: .yellow, bold: true)
                            self.logEvent("DM awarded \(result.bonusGold) bonus gold", category: "DM")
                            worldChanged = true
                        }
                        if result.healAmount > 0 {
                            for char in self.party { char.heal(result.healAmount) }
                            self.print("  [+\(result.healAmount) HP!]", color: .brightGreen, bold: true)
                            self.logEvent("DM healed party for \(result.healAmount) HP", category: "DM")
                            worldChanged = true
                        }
                        if result.damageAmount > 0 {
                            for char in self.party { char.takeDamage(result.damageAmount) }
                            self.print("  [-\(result.damageAmount) HP!]", color: .red, bold: true)
                            self.logEvent("DM dealt \(result.damageAmount) damage to party", category: "DM")
                            worldChanged = true
                        }
                        if result.damagePartyAmount > 0 {
                            for char in self.party { char.takeDamage(result.damagePartyAmount) }
                            self.print("  [-\(result.damagePartyAmount) HP!]", color: .red, bold: true)
                            self.logEvent("DM dealt \(result.damagePartyAmount) damage to party", category: "DM")
                            worldChanged = true
                        }
                        if let dir = result.moveDirection {
                            self.applyDMMovement(dir)
                            worldChanged = true
                        }
                        if result.teleport {
                            self.applyTeleportToEntrance()
                            worldChanged = true
                        }
                        // Item commands
                        for itemName in result.grantedItems {
                            if let item = self.resolveItemByName(itemName) {
                                pendingPickupItems.append(item)
                                self.print("  [Found: \(item.name)!]", color: .brightGreen, bold: true)
                            }
                            worldChanged = true
                        }
                        for itemName in result.droppedItems {
                            self.applyDMDropItem(itemName)
                            worldChanged = true
                        }
                        for itemName in result.equippedItems {
                            self.applyDMEquipItem(itemName)
                            worldChanged = true
                        }
                        for itemName in result.usedItems {
                            self.applyDMUseItem(itemName)
                            worldChanged = true
                        }
                    }

                    // Show updated party status after world changes
                    if worldChanged {
                        self.print("")
                        for char in self.party {
                            self.print("  \(char.name) \(char.currentHP)/\(char.maxHP) HP  Gold: \(char.gold)", color: .cyan)
                        }
                    }

                    // Speak the DM response
                    SpeechEngine.shared.speak(displayText)

                    self.print("")
                    self.logEvent("Asked DM: \(input)", category: "DM")

                    if worldChanged {
                        // World changed — return to exploration, with loot pickup if needed
                        self.waitForContinue()
                        self.inputHandler = { [weak self] _ in
                            self?.showLootSequence(gold: pendingGold, goldSource: "DM reward",
                                                   items: pendingPickupItems, itemSource: "DM gift") { [weak self] in
                                self?.showExplorationView()
                            }
                        }
                    } else {
                        self.print("(Type another question, or tap Back)", color: .dimGreen)
                        self.dmPromptForQuestion()
                    }
                }
            }
        }
    }

    func askTheDMInCombat(characterId: UUID) {
        guard let combat = currentCombat,
              let character = party.first(where: { $0.id == characterId }) else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("DM — describe your action or ask a question:", color: .cyan, bold: true)
        print("(e.g. throw oil from my pack, look for an exit...)", color: .dimGreen)
        print("")

        promptTextWithMenu(">", options: ["< Back"])

        menuHandler = { [weak self] _ in
            self?.showPlayerCombatMenu(characterId: characterId)
        }

        inputHandler = { [weak self] input in
            guard let self = self else { return }

            if self.isReservedWord(input) || input.isEmpty {
                self.showPlayerCombatMenu(characterId: characterId)
                return
            }

            self.print("")
            self.print("The DM considers...", color: .dimGreen)

            let context = self.buildDMContext(combatContext: combat, activeCharacter: character)

            DMEngine.shared.ask(input, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    let adLibLevel = DMEngine.shared.adLibLevel
                    let result = DMEngine.parseCommands(from: response)
                    let displayText = result.cleanText

                    self.print("")
                    self.print("DM:", color: .yellow, bold: true)
                    for paragraph in displayText.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { self.print("") }
                        else { self.print("  \(trimmed)", color: .yellow) }
                    }

                    // Apply DM commands if at moderate+ level
                    var tookAction = false
                    if adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue {
                        if result.healAmount > 0 {
                            for char in self.party { char.heal(result.healAmount) }
                            self.print("  [+\(result.healAmount) HP!]", color: .brightGreen, bold: true)
                            self.logEvent("DM healed party for \(result.healAmount) HP in combat", category: "DM")
                            tookAction = true
                        }
                        if result.damageAmount > 0 {
                            // In combat, DAMAGE hits the first alive monster
                            if let idx = combat.encounter.monsters.firstIndex(where: { $0.isAlive }) {
                                let name = combat.encounter.monsters[idx].name
                                combat.encounter.monsters[idx].takeDamage(result.damageAmount)
                                self.print("  [\(name) takes \(result.damageAmount) damage!]", color: .brightGreen, bold: true)
                                self.logEvent("DM: \(name) took \(result.damageAmount) damage", category: "DM")
                            }
                            tookAction = true
                        }
                        if result.damagePartyAmount > 0 {
                            // DAMAGE_PARTY hurts the party in combat
                            for char in self.party { char.takeDamage(result.damagePartyAmount) }
                            self.print("  [-\(result.damagePartyAmount) HP!]", color: .red, bold: true)
                            self.logEvent("DM dealt \(result.damagePartyAmount) damage to party in combat", category: "DM")
                            tookAction = true
                        }
                        if result.bonusGold > 0 {
                            self.party.first?.gold += result.bonusGold
                            self.print("  [+\(result.bonusGold) gold!]", color: .yellow, bold: true)
                            self.logEvent("DM awarded \(result.bonusGold) gold in combat", category: "DM")
                            tookAction = true
                        }
                        for itemName in result.droppedItems {
                            self.applyDMDropItem(itemName)
                            tookAction = true
                        }
                        for itemName in result.equippedItems {
                            self.applyDMEquipItem(itemName)
                            tookAction = true
                        }
                        for itemName in result.usedItems {
                            self.applyDMUseItem(itemName)
                            tookAction = true
                        }
                        for itemName in result.grantedItems {
                            if let item = self.resolveItemByName(itemName) {
                                if let c = self.party.first, c.canCarry(item) {
                                    _ = c.addItem(item)
                                    self.print("  [Received: \(item.name)!]", color: .brightGreen, bold: true)
                                    self.logEvent("DM gave \(c.name) \(item.name)", category: "DM")
                                } else {
                                    self.print("  [Too heavy to carry: \(item.name)]", color: .yellow)
                                }
                            }
                            tookAction = true
                        }
                    }

                    // Speak the DM response
                    SpeechEngine.shared.speak(displayText)

                    self.print("")
                    self.logEvent("Asked DM in combat: \(input)", category: "DM")

                    if tookAction {
                        // Action was taken — counts as their turn
                        self.waitForContinue()
                        self.inputHandler = { [weak self] _ in
                            combat.checkCombatEnd()
                            combat.nextTurn()
                            self?.runCombatTurn()
                        }
                    } else {
                        // Just a question / flavor — return to combat menu
                        self.waitForContinue()
                        self.inputHandler = { [weak self] _ in
                            self?.showPlayerCombatMenu(characterId: characterId)
                        }
                    }
                }
            }
        }
    }

    private func buildDMContext(combatContext: Combat? = nil, activeCharacter: Character? = nil) -> DMContext {
        let room = dungeon?.currentRoom
        let exitList = room?.exits.keys.map { $0.rawValue }.joined(separator: ", ") ?? "None"
        let partyStatus = party.map {
            "\($0.name) (\($0.race.rawValue) \($0.characterClass.rawValue)) HP:\($0.currentHP)/\($0.maxHP) Gold:\($0.gold)"
        }.joined(separator: "\n")

        let inventorySummary = party.map { char -> String in
            var items = char.inventory.map { $0.name }
            if let w = char.equippedWeapon { items.insert("Equipped: \(w.name)", at: 0) }
            if let a = char.equippedArmor { items.insert("Wearing: \(a.name)", at: 0) }
            return "\(char.name): \(items.isEmpty ? "(empty)" : items.joined(separator: ", "))"
        }.joined(separator: "\n")

        // Treasure in room
        var treasureInfo: String? = nil
        if let room = room, !room.treasure.isEmpty {
            let items = room.treasure.map { "\($0.name) (worth \($0.value) gold)" }
            treasureInfo = "Uncollected treasure: \(items.joined(separator: ", "))"
        }

        // Encounter info
        var encounterInfo: String? = nil
        if let room = room, let encounter = room.encounter {
            if room.cleared {
                let defeated = encounter.monsters.map { $0.name }
                let grouped = Dictionary(grouping: defeated) { $0 }.map { "\($0.value.count) \($0.key)" }
                encounterInfo = "Defeated enemies here: \(grouped.joined(separator: ", "))"
            } else {
                let alive = encounter.aliveMonsters.map { $0.name }
                let grouped = Dictionary(grouping: alive) { $0 }.map { "\($0.value.count) \($0.key)" }
                encounterInfo = "Enemies present: \(grouped.joined(separator: ", "))"
            }
        }

        // Search history
        var searchHistory: String? = nil
        if let room = room, !room.searchedFor.isEmpty {
            searchHistory = "Already searched for: \(room.searchedFor.joined(separator: ", "))"
        }

        var combatSummary: String? = nil
        if let combat = combatContext {
            let aliveMonsters = combat.encounter.aliveMonsters
            let monsterList = aliveMonsters.map { "\($0.name) HP:\($0.currentHP)/\($0.maxHP)" }.joined(separator: ", ")
            let activeInfo = activeCharacter.map { "Active character: \($0.name) (\($0.characterClass.rawValue))" } ?? ""
            combatSummary = """
            Enemies: \(monsterList)
            \(activeInfo)
            The player is asking during their combat turn. They may describe creative actions \
            (throwing items, using environment, intimidating enemies) or ask questions about \
            the battlefield. Describe the outcome vividly but briefly.
            """
        }

        // Build adventure log summary for DM context (configurable, default 128)
        let relevantLog = adventureLog
            .filter { !$0.contains("[SYSTEM]") }
            .suffix(dmLogContextSize)
            .map { String($0) }
        let logSummary: String? = relevantLog.isEmpty ? nil : relevantLog.joined(separator: "\n")

        return DMContext(
            roomName: room?.name ?? "Unknown",
            roomType: room?.roomType.rawValue ?? "Unknown",
            roomDescription: room?.roomDescription ?? "",
            exits: exitList,
            isCleared: room?.cleared ?? false,
            partyStatus: partyStatus,
            gameTime: formattedGameTime(),
            inventorySummary: inventorySummary,
            adLibLevel: DMEngine.shared.adLibLevel,
            treasureInRoom: treasureInfo,
            encounterInfo: encounterInfo,
            searchHistory: searchHistory,
            combatSummary: combatSummary,
            adventureLogSummary: logSummary
        )
    }

    private func resolveItemByName(_ name: String) -> Item? {
        let lower = name.lowercased()

        // Potions (check specific before generic)
        if lower.contains("greater") && lower.contains("healing") { return ItemCatalog.greaterHealingPotion() }
        if lower.contains("healing") || lower.contains("potion") { return ItemCatalog.healingPotion() }

        // Weapons
        if lower.contains("greataxe") { return ItemCatalog.greataxe() }
        if lower.contains("longsword") || lower.contains("long sword") { return ItemCatalog.longsword() }
        if lower.contains("shortsword") || lower.contains("short sword") { return ItemCatalog.shortsword() }
        if lower.contains("longbow") || lower.contains("long bow") { return ItemCatalog.longbow() }
        if lower.contains("rapier") { return ItemCatalog.rapier() }
        if lower.contains("quarterstaff") || lower.contains("staff") { return ItemCatalog.quarterstaff() }
        if lower.contains("handaxe") || lower.contains("hand axe") { return ItemCatalog.handaxe() }
        if lower.contains("mace") { return ItemCatalog.mace() }
        if lower.contains("dagger") || lower.contains("knife") { return ItemCatalog.dagger() }

        // Armor
        if lower.contains("chain mail") || lower.contains("chainmail") { return ItemCatalog.chainMail() }
        if lower.contains("scale mail") || lower.contains("scalemail") { return ItemCatalog.scaleMail() }
        if lower.contains("studded leather") { return ItemCatalog.studdedLeather() }
        if lower.contains("leather armor") || lower.contains("leather armour") { return ItemCatalog.leatherArmor() }
        if lower.contains("shield") { return ItemCatalog.shield() }

        // Misc gear
        if lower.contains("torch") { return ItemCatalog.torch() }
        if lower.contains("rope") { return ItemCatalog.rope() }
        if lower.contains("holy symbol") { return ItemCatalog.holySymbol() }
        if lower.contains("thieve") || lower.contains("lockpick") { return ItemCatalog.thievesTools() }
        if lower.contains("spell component") || lower.contains("component pouch") { return ItemCatalog.spellComponentPouch() }

        // Fallback — create a generic misc item so the DM's gift isn't lost
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        return Item(id: UUID(), name: cleanName, description: "A mysterious item from the DM.",
                    type: .misc, weight: 1.0, value: 5,
                    weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    // MARK: - Combat Display

    private func diceArt(_ value: Int) -> [String] {
        let valStr = String(value)
        let pad: String
        if valStr.count == 1 {
            pad = " \(valStr) "
        } else if valStr.count == 2 {
            pad = " \(valStr)"
        } else {
            pad = valStr
        }
        return [
            "      ┌─────┐",
            "      │ \(pad) │",
            "      └─────┘",
        ]
    }

    /// Render attacker vs defender side-by-side with weapon flourish
    private func renderBattleScene(_ report: AttackReport) {
        let attArt = report.attackerArt
        let defArt = report.defenderArt
        let maxLines = max(attArt.count, defArt.count)

        // Pad each art to a fixed width for alignment
        let attWidth = attArt.map { $0.count }.max() ?? 0
        let defWidth = defArt.map { $0.count }.max() ?? 0
        let padAtt = max(attWidth, 10)

        // Weapon attack animations (center column)
        let weaponLower = report.weaponName.lowercased()
        let attackFrames: [String]
        if weaponLower.contains("bow") || weaponLower.contains("crossbow") {
            attackFrames = ["  ---->  ", "  =====> ", "  --*--> "]
        } else if weaponLower.contains("staff") || weaponLower.contains("quarterstaff") {
            attackFrames = ["  |===|  ", "  |===*  ", "   *==|  "]
        } else if weaponLower.contains("dagger") || weaponLower.contains("rapier") {
            attackFrames = ["   -->   ", "   -=>>  ", "   --*>  "]
        } else if weaponLower.contains("great") || weaponLower.contains("maul") {
            attackFrames = ["  >==>   ", "  >===>  ", "  >=*=>  "]
        } else if weaponLower.contains("axe") || weaponLower.contains("hatchet") {
            attackFrames = ["   )=>   ", "   )==>  ", "   )=*>  "]
        } else {
            // Default sword/melee slash
            attackFrames = ["   \\     ", "    \\    ", "  ---*   "]
        }

        let attackColor: TerminalColor = report.isPlayerAttack ? .brightGreen : .red
        let defendColor: TerminalColor = report.isPlayerAttack ? .red : .brightGreen

        // Print scene header
        let attLabel = report.attackerName
        let defLabel = report.targetName
        let headerGap = String(repeating: " ", count: max(0, padAtt - attLabel.count + 5))
        print("\(attLabel)\(headerGap)\(defLabel)", color: .cyan, bold: true)
        print("")

        // Render side-by-side with animation frames
        for i in 0..<maxLines {
            let leftLine = i < attArt.count ? attArt[i] : ""
            let rightLine = i < defArt.count ? defArt[i] : ""
            let leftPadded = leftLine.padding(toLength: padAtt, withPad: " ", startingAt: 0)

            let midFrame = i < attackFrames.count ? attackFrames[i] : "         "
            // Show attacker in attack color, weapon in yellow, defender in defend color
            print("  \(leftPadded)\(midFrame)\(rightLine)", color: i < attackFrames.count ? .yellow : attackColor)
        }
        print("")
    }

    func displayAttackReport(_ report: AttackReport, completion: @escaping () -> Void) {
        let attackColor: TerminalColor = report.isPlayerAttack ? .brightGreen : .red

        // Show animated battle scene
        renderBattleScene(report)

        // Play weapon-appropriate sound
        let wn = report.weaponName.lowercased()
        if wn.contains("bow") || wn.contains("crossbow") {
            SoundManager.shared.playArrowShot()
        } else if wn.contains("staff") || wn.contains("quarterstaff") {
            SoundManager.shared.playStaffStrike()
        } else {
            SoundManager.shared.playSwordSwing()
        }

        print("\(report.attackerName) attacks \(report.targetName) with \(report.weaponName)!", color: attackColor, bold: true)
        print("")
        print("  To Hit: d20 + \(report.attackModifier)", color: .cyan)
        print("  (\(report.modifierBreakdown))", color: .dimGreen)
        print("  Target AC: \(report.targetAC)", color: .dimGreen)
        print("")

        // Phase 2: Dice roll (after delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }

            self.printLines(self.diceArt(report.d20Roll), color: .yellow)
            let sign = report.attackModifier >= 0 ? "+" : ""
            self.print("  d20 -> [\(report.d20Roll)] \(sign)\(report.attackModifier) = \(report.totalAttack) vs AC \(report.targetAC)", color: .cyan)
            self.print("")

            if report.isCritical {
                SoundManager.shared.playCrit()
                self.printLines(self.asciiCriticalHit, color: report.isPlayerAttack ? .yellow : .red)
                self.print("")
                self.print("  NATURAL 20 -- CRITICAL HIT!", color: .yellow, bold: true)
            } else if report.isCriticalMiss {
                SoundManager.shared.playMiss()
                self.printLines(self.asciiMiss, color: .dimGreen)
                self.print("")
                self.print("  Natural 1 -- Critical Miss!", color: .red)
            } else if report.hits {
                if report.isPlayerAttack {
                    SoundManager.shared.playHit()
                    self.printLines(self.asciiHit(attacker: report.attackerName, target: report.targetName), color: .brightGreen)
                } else {
                    SoundManager.shared.playMonsterAttack()
                    self.printLines(self.asciiMonsterAttack, color: .red)
                }
                self.print("")
                self.print("  HIT!", color: .brightGreen, bold: true)
            } else {
                SoundManager.shared.playMiss()
                self.printLines(self.asciiMiss, color: .dimGreen)
                self.print("")
                self.print("  Miss.", color: .dimGreen)
            }
            self.print("")

            // Phase 3: Damage (if hit)
            if report.hits, let rolls = report.damageRolls, let totalDmg = report.totalDamage {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }

                    let diceStr = report.damageDice ?? "?"
                    let modVal = report.damageModifier ?? 0
                    let modSign = modVal >= 0 ? "+" : ""

                    if report.isCritical {
                        self.print("  Damage: \(diceStr) \(modSign)\(modVal) (critical!)", color: .cyan)
                    } else {
                        self.print("  Damage: \(diceStr) \(modSign)\(modVal)", color: .cyan)
                    }

                    let diceTotal = rolls.reduce(0, +)
                    self.printLines(self.diceArt(diceTotal), color: .red)

                    if rolls.count <= 3 {
                        let rollStr = rolls.map { "[\($0)]" }.joined(separator: "+")
                        self.print("  \(rollStr) \(modSign)\(modVal) = \(totalDmg) damage!", color: report.isPlayerAttack ? .brightGreen : .red)
                    } else {
                        self.print("  \(totalDmg) damage!", color: report.isPlayerAttack ? .brightGreen : .red)
                    }
                    self.print("")

                    if report.targetDefeated {
                        SoundManager.shared.playDeath()
                        self.print("  \(report.targetName) is defeated!", color: .yellow, bold: true)
                    } else if report.targetUnconscious {
                        SoundManager.shared.playDeath()
                        self.print("  \(report.targetName) falls unconscious!", color: .red, bold: true)
                    } else {
                        self.print("  \(report.targetName): \(report.targetCurrentHP)/\(report.targetMaxHP) HP", color: .dimGreen)
                    }

                    if report.poisonApplied {
                        self.print("")
                        self.print("  POISONED! \(report.targetName) has been poisoned!", color: .magenta, bold: true)
                        self.print("  (takes damage each turn until cured or it wears off)", color: .dimGreen)
                    }
                    self.print("")

                    self.waitForContinue()
                    self.inputHandler = { _ in completion() }
                }
            } else {
                self.waitForContinue()
                self.inputHandler = { _ in completion() }
            }
        }
    }

    // MARK: - Combat

    func startCombat(encounter: Encounter) {
        gameState = .combat
        currentCombat = Combat(party: party, encounter: encounter)
        SoundManager.shared.startMusic(.combat)
        SoundManager.shared.playBattleStart()

        let monsterNames = encounter.monsters.map { $0.name }.joined(separator: ", ")
        logEvent("Battle! Encountered \(monsterNames)", category: "COMBAT")

        clearTerminal()
        printLines(asciiSwords, color: .red)
        print("")
        printTitle("COMBAT!")

        // Group monsters by type for cleaner display
        var monsterCounts: [(type: MonsterType, count: Int)] = []
        for monster in encounter.monsters {
            if let idx = monsterCounts.firstIndex(where: { $0.type == monster.type }) {
                monsterCounts[idx].count += 1
            } else {
                monsterCounts.append((type: monster.type, count: 1))
            }
        }
        for group in monsterCounts {
            printLines(group.type.asciiArt, color: .red)
            if group.count > 1 {
                print("\(group.count) \(group.type.rawValue)s appear!", color: .red)
            } else {
                print("\(group.type.rawValue) appears!", color: .red)
            }
            print("  \(group.type.description)", color: .dimGreen)
            print("")
        }

        // Boss difficulty flavor text
        if let bossDiff = encounter.bossDifficulty {
            let bossName = encounter.monsters.first?.name ?? "The boss"
            switch bossDiff {
            case .easy:
                print("\(bossName) looks weakened...", color: .yellow)
            case .medium:
                break
            case .hard:
                print("\(bossName) looks fearsome!", color: .red, bold: true)
            }
            print("")
        }
        print("Rolling initiative...")
        print("")

        if let combat = currentCombat {
            for (_, name, _, initiative) in combat.turnOrder {
                print("  \(name): \(initiative)")
            }
        }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.runCombatTurn()
        }
    }

    func runCombatTurn() {
        guard let combat = currentCombat else { return }

        // Check combat end
        if combat.state == .victory {
            handleCombatVictory()
            return
        } else if combat.state == .defeat {
            handleCombatDefeat()
            return
        }

        guard let current = combat.currentCombatant else {
            combat.nextTurn()
            runCombatTurn()
            return
        }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")

        if current.isPlayer {
            // Clear dodge at start of turn (dodge only lasts until your next turn)
            if let character = party.first(where: { $0.id == current.id }) {
                character.isDodging = false
            }

            // Check if character fled or is playing dead
            if let character = party.first(where: { $0.id == current.id }),
               (character.hasFledCombat || character.isPlayingDead) {
                // Skip their turn
                combat.nextTurn()
                runCombatTurn()
                return
            }

            // Tick poison at start of turn
            if let character = party.first(where: { $0.id == current.id }),
               character.isPoisoned {
                let poisonResult = character.tickPoison()
                if poisonResult.cured && poisonResult.damage == 0 {
                    print("  \(character.name) shakes off the poison!", color: .brightGreen, bold: true)
                } else if poisonResult.damage > 0 {
                    print("  \(character.name) takes \(poisonResult.damage) poison damage!", color: .magenta)
                    print("  (\(character.currentHP)/\(character.maxHP) HP)", color: .dimGreen)
                    if poisonResult.cured {
                        print("  The poison wears off.", color: .brightGreen)
                    }
                }
                if !character.isConscious {
                    combat.checkCombatEnd()
                    if combat.state == .defeat {
                        handleCombatDefeat()
                        return
                    }
                }
                print("")
            }

            // Check if unconscious — death saving throw instead of normal turn
            if let character = party.first(where: { $0.id == current.id }),
               !character.isConscious {
                showDeathSavingThrow(character: character)
            } else if let character = party.first(where: { $0.id == current.id }),
                      character.isComputerControlled {
                runAICombatTurn(character: character)
            } else {
                showPlayerCombatMenu(characterId: current.id)
            }
        } else {
            if let report = combat.runMonsterTurn() {
                displayAttackReport(report) { [weak self] in
                    guard let self = self else { return }
                    combat.checkCombatEnd()
                    combat.nextTurn()
                    self.runCombatTurn()
                }
            } else {
                combat.nextTurn()
                runCombatTurn()
            }
        }
    }

    // MARK: - AI Combat Turn

    func runAICombatTurn(character: Character) {
        guard let combat = currentCombat else { return }

        let aliveMonsters = combat.encounter.aliveMonsters
        guard !aliveMonsters.isEmpty else { return }

        print("\(character.name) (AI) considers...", color: .cyan, bold: true)
        print("")

        // Decision priority:
        // 0. If poisoned and very hurt, try to use antidote/potion or play dead
        // 1. Barbarian: Rage if not raging and has uses
        // 2. Cleric: Heal if any ally below 30% HP
        // 3. Fighter: Second Wind if below 40% HP
        // 4. Attack the weakest (lowest HP) monster

        // 0. Poisoned and hurting — seek antidote or play dead
        if character.isPoisoned {
            // Try to find and use a healing potion
            let potionIdx = character.inventory.firstIndex(where: {
                $0.name.lowercased().contains("potion") && $0.name.lowercased().contains("heal")
            })
            if let idx = potionIdx {
                let potion = character.inventory[idx]
                let healAmt = Dice.rollSum(2, d: 4) + 2
                character.heal(healAmt)
                character.inventory.remove(at: idx)
                print("  \(character.name) drinks a \(potion.name)! (+\(healAmt) HP)", color: .brightGreen)
                character.curePoison()
                print("  The poison is cleansed!", color: .brightGreen)
                combat.nextTurn()
                waitForContinue()
                inputHandler = { [weak self] _ in self?.runCombatTurn() }
                return
            }

            // Very hurt and poisoned — might play dead
            let hpPercent = Double(character.currentHP) / Double(character.maxHP)
            if hpPercent < 0.25 {
                print("  \(character.name) is badly poisoned and collapses, playing dead!", color: .yellow)
                character.isPlayingDead = true
                combat.nextTurn()
                waitForContinue()
                inputHandler = { [weak self] _ in self?.runCombatTurn() }
                return
            }
        }

        // 1. Barbarian Rage
        if character.characterClass == .barbarian && !character.isRaging && character.rageUsesRemaining > 0 {
            print("  \(character.name) enters a furious RAGE!", color: .red, bold: true)
            activateRage(character: character)
            return
        }

        // 2. Cleric healing — if any conscious ally is below 30% HP
        if character.characterClass == .cleric {
            let woundedAlly = party.first(where: {
                $0.isConscious && $0.currentHP < $0.maxHP * 30 / 100
            })
            if let ally = woundedAlly {
                // Try to cast a healing spell
                let spells = character.knownSpells
                let slots = character.spellSlots.level1Current
                let foundHealSpell: Spell? = spells.first(where: { (s: Spell) -> Bool in
                    s.spellType == .healing && (s.level == .cantrip || slots > 0)
                })
                if let healSpell = foundHealSpell {
                    let msg = "  \(character.name) casts \(healSpell.name) on \(ally.name)!"
                    print(msg, color: .brightGreen)
                    let allyId = ally.id
                    if let report = combat.castSpell(casterId: character.id, spell: healSpell, targetIds: [allyId]) {
                        SoundManager.shared.playSpellCast()
                        displaySpellReport(report) { [weak self] in
                            combat.checkCombatEnd()
                            combat.nextTurn()
                            self?.runCombatTurn()
                        }
                        return
                    }
                }
            }
        }

        // 3. Fighter Second Wind when hurt
        if character.characterClass == .fighter && !character.secondWindUsed
            && character.currentHP < character.maxHP * 40 / 100 {
            print("  \(character.name) uses Second Wind!", color: .brightGreen)
            useSecondWind(character: character)
            return
        }

        // 4. Spellcaster: use an attack cantrip or spell on weakest monster
        if character.characterClass == .wizard || character.characterClass == .ranger {
            let weakestMonster = aliveMonsters.min(by: { $0.currentHP < $1.currentHP })!
            let atkSpells = character.knownSpells
            let atkSlots = character.spellSlots.level1Current
            let foundAttackSpell: Spell? = atkSpells.first(where: { (s: Spell) -> Bool in
                s.spellType == .attack && (s.level == .cantrip || atkSlots > 0)
            })
            if let attackSpell = foundAttackSpell {
                let atkMsg = "  \(character.name) casts \(attackSpell.name)!"
                print(atkMsg, color: .yellow)
                let targetId = weakestMonster.id
                if let report = combat.castSpell(casterId: character.id, spell: attackSpell, targetIds: [targetId]) {
                    SoundManager.shared.playSpellCast()
                    displaySpellReport(report) { [weak self] in
                        combat.checkCombatEnd()
                        combat.nextTurn()
                        self?.runCombatTurn()
                    }
                    return
                }
            }
        }

        // 5. Default: attack the weakest monster
        let target = aliveMonsters.min(by: { $0.currentHP < $1.currentHP })!
        if let report = combat.playerAttack(characterId: character.id, targetId: target.id) {
            let weaponName = character.equippedWeapon?.name ?? "fists"
            print("  \(character.name) attacks \(target.name) with \(weaponName)!", color: .brightGreen)
            displayAttackReport(report) { [weak self] in
                combat.checkCombatEnd()
                combat.nextTurn()
                self?.runCombatTurn()
            }
        } else {
            // Fallback: skip turn
            combat.nextTurn()
            runCombatTurn()
        }
    }

    func showPlayerCombatMenu(characterId: UUID) {
        guard let combat = currentCombat,
              let character = party.first(where: { $0.id == characterId }) else { return }

        print("\(character.name)'s turn!", color: .brightGreen, bold: true)
        print("")

        let aliveMonsters = combat.encounter.aliveMonsters
        var options: [String] = []
        var actions: [() -> Void] = []

        // Build display names that distinguish duplicate monsters
        let monsterDisplayNames = Combat.numberedMonsterNames(aliveMonsters)

        // Attack options
        for (i, monster) in aliveMonsters.enumerated() {
            let monsterRef = monster
            options.append("Attack \(monsterDisplayNames[i])")
            actions.append { [weak self] in
                guard let self = self else { return }
                if let report = combat.playerAttack(characterId: characterId, targetId: monsterRef.id) {
                    self.clearTerminal()
                    self.printLines(combat.displayStatus())
                    self.print("")
                    self.displayAttackReport(report) { [weak self] in
                        combat.checkCombatEnd()
                        combat.nextTurn()
                        self?.runCombatTurn()
                    }
                }
            }
        }

        // Cast Spell (spellcasters with spells)
        if !character.knownSpells.isEmpty {
            let hasCantrips = character.knownSpells.contains { $0.level == .cantrip }
            let hasSlots = character.spellSlots.level1Current > 0 || character.spellSlots.level2Current > 0
            if hasCantrips || hasSlots {
                let slotInfo = character.spellSlots.isEmpty ? "" : " [\(character.spellSlots.level1Current) slots]"
                options.append("Cast Spell\(slotInfo)")
                actions.append { [weak self] in
                    self?.showSpellMenu(characterId: characterId)
                }
            }
        }

        // Fighter: Second Wind
        if character.characterClass == .fighter && !character.secondWindUsed {
            options.append("Second Wind (heal 1d10+\(character.level))")
            actions.append { [weak self] in
                self?.useSecondWind(character: character)
            }
        }

        // Barbarian: Rage
        if character.characterClass == .barbarian && character.rageUsesRemaining > 0 && !character.isRaging {
            options.append("Rage! (\(character.rageUsesRemaining) uses)")
            actions.append { [weak self] in
                self?.activateRage(character: character)
            }
        }

        // Dodge
        options.append("Dodge (defensive stance)")
        actions.append { [weak self] in
            guard let self = self else { return }
            self.clearTerminal()
            self.printLines(combat.displayStatus())
            self.print("")
            self.printLines(self.asciiDodge, color: .cyan)
            self.print("")
            character.isDodging = true
            self.print("\(character.name) takes a defensive stance!", color: .cyan, bold: true)
            self.print("  Enemies attacking \(character.name) have DISADVANTAGE", color: .dimGreen)
            self.print("  (they roll twice, take the worse result)", color: .dimGreen)
            combat.checkCombatEnd()
            combat.nextTurn()
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in self?.runCombatTurn() }
        }

        // Ask the DM (in combat)
        if DMEngine.shared.adLibLevel != .off {
            options.append("Ask the DM")
            actions.append { [weak self] in
                self?.askTheDMInCombat(characterId: characterId)
            }
        }

        // Play Dead
        options.append("Play Dead")
        actions.append { [weak self] in
            self?.attemptPlayDead(characterId: characterId)
        }

        // Run Away
        options.append("Run Away!")
        actions.append { [weak self] in
            self?.attemptRunAway()
        }

        showMenu(options)
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    // MARK: - Run Away

    func attemptRunAway() {
        guard let combat = currentCombat else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("The party attempts to flee!", color: .yellow, bold: true)
        print("")

        // Each conscious party member rolls DEX check
        // DC = 10 + highest monster DEX-like bonus (simplified: attackBonus / 2)
        let monsterDC = 10 + (combat.encounter.aliveMonsters.map { $0.attackBonus / 2 }.max() ?? 0)
        print("  Escape DC: \(monsterDC)", color: .cyan)
        print("")

        var successes = 0
        var total = 0
        for char in party where char.isConscious {
            total += 1
            let roll = Dice.d20()
            let dexMod = char.abilityScores.modifier(for: .dexterity)
            let result = roll + dexMod
            let passed = result >= monsterDC
            if passed { successes += 1 }
            print("  \(char.name): [\(roll)]+\(dexMod) = \(result) \(passed ? "OK" : "FAIL")",
                  color: passed ? .brightGreen : .red)
        }

        print("")

        // Need majority to escape
        let escaped = successes > total / 2

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            if escaped {
                self.print("You escape!", color: .brightGreen, bold: true)
                self.print("")

                // Take opportunity attacks — each monster gets one free hit on a random party member
                let opportunityHits = min(combat.encounter.aliveMonsters.count, 1)
                if opportunityHits > 0, let monster = combat.encounter.aliveMonsters.first,
                   let target = self.party.filter({ $0.isConscious }).randomElement() {
                    let dmg = max(1, Dice.rollDamage(monster.damage).total)
                    target.takeDamage(dmg)
                    self.print("  \(monster.name) strikes as you flee!", color: .red)
                    self.print("  \(target.name) takes \(dmg) damage!", color: .red)
                    self.print("")
                }

                // Combat cleanup
                for char in self.party {
                    char.isRaging = false
                    char.huntersMarkActive = false
                    char.hasFledCombat = false
                    char.isPlayingDead = false
                    char.curePoison()
                }
                self.currentCombat = nil
                self.gameState = .exploring

                // Move to previous room if possible
                if let dungeon = self.dungeon, let prevRoom = dungeon.previousRoom {
                    dungeon.currentRoom = prevRoom
                    self.print("  You retreat to the \(prevRoom.name).", color: .dimGreen)
                    self.print("")
                }

                SoundManager.shared.startMusic(.exploration)

                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.showExplorationView()
                }
            } else {
                self.print("You can't escape!", color: .red, bold: true)
                self.print("The monsters block your path!")
                self.print("")

                // Monsters get a free round of attacks
                combat.nextTurn()

                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.runCombatTurn()
                }
            }
        }
    }

    // MARK: - Play Dead

    func attemptPlayDead(characterId: UUID) {
        guard let combat = currentCombat,
              let character = party.first(where: { $0.id == characterId }) else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("\(character.name) collapses dramatically, playing dead!", color: .yellow, bold: true)
        print("")

        // Performance check: CHA or Deception-based
        // Higher success chance than Run Away (DC 8 instead of DC 10)
        let chaMod = character.abilityScores.modifier(for: .charisma)
        let profBonus = character.skillProficiencies.contains(.deception) ? character.proficiencyBonus : 0
        let roll = Dice.d20()
        let total = roll + chaMod + profBonus
        let dc = 8 + (combat.encounter.aliveMonsters.map { $0.attackBonus / 3 }.max() ?? 0)

        let profStr = profBonus > 0 ? " + Deception +\(profBonus)" : ""
        print("  Performance: d20 + CHA \(chaMod >= 0 ? "+" : "")\(chaMod)\(profStr)", color: .cyan)
        print("  [\(roll)] + \(chaMod + profBonus) = \(total) vs DC \(dc)", color: .cyan)
        print("")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            if total >= dc {
                // Success — monster reaction
                let reactions = [
                    "The monsters glance at the fallen body and lose interest.",
                    "A creature sniffs at \(character.name) suspiciously... then wanders off.",
                    "The enemies step over what they think is a corpse.",
                    "\(character.name) lies perfectly still. The monsters look elsewhere.",
                ]
                self.print(reactions.randomElement()!, color: .brightGreen)
                self.print("")
                self.print("  \(character.name) is out of the fight (playing dead).", color: .dimGreen)

                character.isPlayingDead = true

                // Check if all party members are out of the fight
                let activeFighters = self.party.filter {
                    $0.isConscious && !$0.isPlayingDead && !$0.hasFledCombat
                }
                if activeFighters.isEmpty {
                    // Everyone is out — end combat, retreat to previous room
                    self.print("")
                    self.print("With no one left fighting, the monsters lose interest.", color: .yellow)

                    for char in self.party {
                        char.isPlayingDead = false
                        char.hasFledCombat = false
                        char.isRaging = false
                        char.huntersMarkActive = false
                    }
                    self.currentCombat = nil
                    self.gameState = .exploring

                    if let dungeon = self.dungeon, let prevRoom = dungeon.previousRoom {
                        dungeon.currentRoom = prevRoom
                        self.print("  You quietly retreat to the \(prevRoom.name).", color: .dimGreen)
                    }

                    SoundManager.shared.startMusic(.exploration)
                    self.print("")
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        self?.showExplorationView()
                    }
                } else {
                    combat.nextTurn()
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in self?.runCombatTurn() }
                }
            } else {
                // Failed — monster sees through the ruse
                let reactions = [
                    "The creature isn't fooled! It kicks \(character.name) roughly.",
                    "A monster prods \(character.name) with a weapon. \"Not dead yet!\"",
                    "The ruse fails! The enemies aren't buying it.",
                ]
                self.print(reactions.randomElement()!, color: .red)

                // Take a hit as punishment
                if let monster = combat.encounter.aliveMonsters.randomElement() {
                    let dmg = max(1, Dice.rollDamage(monster.damage).total / 2)
                    character.takeDamage(dmg)
                    self.print("  \(character.name) takes \(dmg) damage!", color: .red)
                    self.print("  (\(character.currentHP)/\(character.maxHP) HP)", color: .dimGreen)
                }
                self.print("")

                combat.checkCombatEnd()
                combat.nextTurn()
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in self?.runCombatTurn() }
            }
        }
    }

    // MARK: - Spell Casting UI

    func showSpellMenu(characterId: UUID) {
        guard let combat = currentCombat,
              let character = party.first(where: { $0.id == characterId }) else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("Choose a spell:", color: .brightGreen, bold: true)
        print("")

        let cantrips = character.knownSpells.filter { $0.level == .cantrip }
        let leveled = character.knownSpells.filter { $0.level != .cantrip && character.canCastSpell($0) }

        var spellOptions: [Spell] = []

        if !cantrips.isEmpty {
            print("  CANTRIPS (unlimited):", color: .cyan, bold: true)
            for c in cantrips {
                print("    \(c.name) — \(c.description)", color: .dimGreen)
            }
            spellOptions.append(contentsOf: cantrips)
            print("")
        }

        if !leveled.isEmpty {
            let l1 = character.spellSlots.level1Current
            let l1m = character.spellSlots.level1Max
            print("  LEVEL 1 (slots: \(l1)/\(l1m)):", color: .cyan, bold: true)
            for s in leveled {
                print("    \(s.name) — \(s.description)", color: .dimGreen)
            }
            spellOptions.append(contentsOf: leveled)
            print("")
        }

        var menuOpts = spellOptions.map { $0.name }
        menuOpts.append("< Back")

        showMenu(menuOpts)

        menuHandler = { [weak self] choice in
            if choice == menuOpts.count {
                self?.clearTerminal()
                self?.printLines(combat.displayStatus())
                self?.print("")
                self?.showPlayerCombatMenu(characterId: characterId)
                return
            }
            guard choice > 0 && choice <= spellOptions.count else { return }
            let spell = spellOptions[choice - 1]
            self?.selectSpellTarget(characterId: characterId, spell: spell)
        }
    }

    func selectSpellTarget(characterId: UUID, spell: Spell) {
        guard let combat = currentCombat else { return }

        // AoE spells target all enemies automatically
        if spell.target == .allEnemies {
            let targetIds = combat.encounter.aliveMonsters.map { $0.id }
            executeSpell(characterId: characterId, spell: spell, targetIds: targetIds)
            return
        }

        // Self/buff spells
        if spell.target == .self_ {
            executeSpell(characterId: characterId, spell: spell, targetIds: [characterId])
            return
        }

        // Healing/utility — target allies
        if spell.target == .singleAlly {
            clearTerminal()
            printLines(combat.displayStatus())
            print("")
            print("Choose target for \(spell.name):", color: .cyan)
            print("")

            var options: [String] = []
            for char in party {
                let status = char.isConscious ? "\(char.currentHP)/\(char.maxHP) HP" : "Unconscious"
                options.append("\(char.name) (\(status))")
            }
            options.append("< Back")

            showMenu(options)
            menuHandler = { [weak self] choice in
                if choice == options.count {
                    self?.showSpellMenu(characterId: characterId)
                    return
                }
                guard choice > 0 && choice <= self?.party.count ?? 0 else { return }
                let targetId = self?.party[choice - 1].id ?? UUID()
                self?.executeSpell(characterId: characterId, spell: spell, targetIds: [targetId])
            }
            return
        }

        // Single enemy target
        let aliveMonsters = combat.encounter.aliveMonsters
        if aliveMonsters.count == 1 {
            executeSpell(characterId: characterId, spell: spell, targetIds: [aliveMonsters[0].id])
            return
        }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("Choose target for \(spell.name):", color: .cyan)
        print("")

        let monsterNames = Combat.numberedMonsterNames(aliveMonsters)
        var options = aliveMonsters.enumerated().map { "\(monsterNames[$0.offset]) (\($0.element.currentHP)/\($0.element.maxHP) HP)" }
        options.append("< Back")

        showMenu(options)
        menuHandler = { [weak self] choice in
            if choice == options.count {
                self?.showSpellMenu(characterId: characterId)
                return
            }
            guard choice > 0 && choice <= aliveMonsters.count else { return }
            self?.executeSpell(characterId: characterId, spell: spell, targetIds: [aliveMonsters[choice - 1].id])
        }
    }

    func executeSpell(characterId: UUID, spell: Spell, targetIds: [UUID]) {
        guard let combat = currentCombat else { return }

        guard let report = combat.castSpell(casterId: characterId, spell: spell, targetIds: targetIds) else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")

        displaySpellReport(report) { [weak self] in
            combat.checkCombatEnd()
            combat.nextTurn()
            self?.runCombatTurn()
        }
    }

    func displaySpellReport(_ report: SpellReport, completion: @escaping () -> Void) {
        print("\(report.casterName) casts \(report.spellName)!", color: .cyan, bold: true)
        print("")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            switch report.spellType {
            case .attack:
                if let d20 = report.d20Roll {
                    self.printLines(self.diceArt(d20), color: .yellow)
                    let bonus = report.attackBonus ?? 0
                    self.print("  d20 -> [\(d20)] +\(bonus) = \(report.totalAttack ?? 0) vs AC \(report.targetAC ?? 0)", color: .cyan)
                    self.print("")
                    if report.isCritical {
                        self.print("  CRITICAL HIT!", color: .yellow, bold: true)
                    } else if report.hits == true {
                        self.print("  HIT!", color: .brightGreen, bold: true)
                    } else {
                        self.print("  Miss.", color: .dimGreen)
                    }
                }

            case .savingThrow:
                self.print("  Save DC: \(report.saveDC ?? 0)", color: .cyan)
                for save in report.saveResults {
                    self.print("  \(save.targetName): [\(save.roll)] +mod = \(save.total) — \(save.saved ? "SAVED" : "FAILED")",
                               color: save.saved ? .dimGreen : .red)
                }

            case .autoHit:
                if report.damageType == "sleep" {
                    self.print("  Sleep power: \(report.totalDamage) HP", color: .cyan)
                } else {
                    self.print("  The missiles strike unerringly!", color: .brightGreen)
                }

            case .healing:
                self.print("  Healed \(report.healAmount) HP!", color: .brightGreen, bold: true)
                for status in report.targetStatuses {
                    self.print("  \(status.name): \(status.currentHP)/\(status.maxHP) HP", color: .dimGreen)
                }

            case .buff:
                self.print("  \(report.casterName) is empowered!", color: .brightGreen)

            case .utility:
                self.print("  \(report.targetName ?? "Ally") is stabilized!", color: .brightGreen)
            }

            self.print("")

            // Show damage results
            if report.totalDamage > 0 && report.spellType != .healing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self = self else { return }

                    if !report.damageRolls.isEmpty {
                        let total = report.damageRolls.reduce(0, +)
                        self.printLines(self.diceArt(total), color: .red)
                    }
                    if let dt = report.damageType {
                        self.print("  \(report.totalDamage) \(dt) damage!", color: .red, bold: true)
                    } else {
                        self.print("  \(report.totalDamage) damage!", color: .red, bold: true)
                    }

                    for defeated in report.targetsDefeated {
                        self.print("  \(defeated) is defeated!", color: .yellow, bold: true)
                    }
                    for status in report.targetStatuses where !report.targetsDefeated.contains(status.name) {
                        self.print("  \(status.name): \(status.currentHP)/\(status.maxHP) HP", color: .dimGreen)
                    }
                    self.print("")

                    self.waitForContinue()
                    self.inputHandler = { _ in completion() }
                }
            } else {
                self.waitForContinue()
                self.inputHandler = { _ in completion() }
            }
        }
    }

    // MARK: - Class Feature Actions

    func useSecondWind(character: Character) {
        guard let combat = currentCombat else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("\(character.name) uses Second Wind!", color: .brightGreen, bold: true)
        print("")

        let healRoll = Dice.rollSum(1, d: 10)
        let healAmount = healRoll + character.level
        character.heal(healAmount)
        character.secondWindUsed = true

        SoundManager.shared.playHeal()
        printLines(diceArt(healRoll), color: .brightGreen)
        print("  Healed \(healAmount) HP! (\(character.currentHP)/\(character.maxHP))", color: .brightGreen)
        print("")

        combat.checkCombatEnd()
        combat.nextTurn()

        waitForContinue()
        inputHandler = { [weak self] _ in self?.runCombatTurn() }
    }

    func activateRage(character: Character) {
        guard let combat = currentCombat else { return }

        clearTerminal()
        printLines(combat.displayStatus())
        print("")
        print("\(character.name) enters a RAGE!", color: .red, bold: true)
        print("")
        print("  +\(character.rageDamageBonus) bonus melee damage", color: .yellow)
        print("  Resistance to physical damage", color: .yellow)
        print("")

        character.isRaging = true
        character.rageUsesRemaining -= 1

        combat.checkCombatEnd()
        combat.nextTurn()

        waitForContinue()
        inputHandler = { [weak self] _ in self?.runCombatTurn() }
    }

    // MARK: - Death Saving Throws

    func showDeathSavingThrow(character: Character) {
        guard let combat = currentCombat else { return }

        print("\(character.name) is unconscious! Death Saving Throw...", color: .red, bold: true)
        print("")
        print("  Successes: \(String(repeating: "●", count: character.deathSaveSuccesses))\(String(repeating: "○", count: 3 - character.deathSaveSuccesses))", color: .brightGreen)
        print("  Failures:  \(String(repeating: "●", count: character.deathSaveFailures))\(String(repeating: "○", count: 3 - character.deathSaveFailures))", color: .red)
        print("")

        waitForContinue()
        inputHandler = { [weak self] _ in
            guard let self = self else { return }

            let result = Dice.deathSave()
            self.printLines(self.diceArt(result.roll), color: result.isSuccess ? .brightGreen : .red)
            self.print("  Death Save: [\(result.roll)]", color: .cyan)
            self.print("")

            if result.isCriticalSuccess {
                // Natural 20: revive with 1 HP
                character.heal(1)
                self.print("  NATURAL 20! \(character.name) revives with 1 HP!", color: .yellow, bold: true)
                SoundManager.shared.playHeal()
            } else if result.isCriticalFailure {
                // Natural 1: 2 failures
                character.deathSaveFailures += 2
                self.print("  NATURAL 1! Two failures!", color: .red, bold: true)
            } else if result.isSuccess {
                character.deathSaveSuccesses += 1
                self.print("  Success! (\(character.deathSaveSuccesses)/3)", color: .brightGreen)
            } else {
                character.deathSaveFailures += 1
                self.print("  Failure! (\(character.deathSaveFailures)/3)", color: .red)
            }

            // Check outcomes
            if character.deathSaveFailures >= 3 {
                self.print("")
                self.print("  \(character.name) has died!", color: .red, bold: true)
            } else if character.deathSaveSuccesses >= 3 {
                self.print("")
                self.print("  \(character.name) is stabilized!", color: .brightGreen, bold: true)
                character.deathSaveSuccesses = 0
                character.deathSaveFailures = 0
            }

            self.print("")
            combat.checkCombatEnd()
            combat.nextTurn()

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in self?.runCombatTurn() }
        }
    }

    // MARK: - Level Up

    func checkAndShowLevelUp(completion: @escaping () -> Void) {
        // Find first party member who can level up
        guard let character = party.first(where: { $0.canLevelUp }) else {
            completion()
            return
        }
        showLevelUpScreen(character: character) { [weak self] in
            // Check if more characters need leveling
            self?.checkAndShowLevelUp(completion: completion)
        }
    }

    func showLevelUpScreen(character: Character, completion: @escaping () -> Void) {
        let oldLevel = character.level
        let newLevel = oldLevel + 1

        character.level = newLevel

        clearTerminal()
        SoundManager.shared.playVictory()

        printTitle("LEVEL UP!")
        print("")
        print("\(character.name) reaches Level \(newLevel)!", color: .yellow, bold: true)
        print("")

        // Roll hit die for HP
        let hitDie = character.characterClass.hitDie
        let conMod = character.abilityScores.modifier(for: .constitution)
        let hpRoll = Dice.rollSum(1, d: hitDie)
        let hpGain = max(1, hpRoll + conMod)
        character.maxHP += hpGain
        character.currentHP += hpGain

        printLines(diceArt(hpRoll), color: .brightGreen)
        print("  HP: +\(hpGain) (d\(hitDie)[\(hpRoll)] + \(conMod) CON) → \(character.maxHP) max HP", color: .brightGreen)
        print("")

        // Update spell slots
        let newSlots = SpellCatalog.startingSlots(for: character.characterClass, level: newLevel)
        if !newSlots.isEmpty {
            character.spellSlots.level1Max = newSlots.level1Max
            character.spellSlots.level1Current = newSlots.level1Max
            character.spellSlots.level2Max = newSlots.level2Max
            character.spellSlots.level2Current = newSlots.level2Max
            if newSlots.level1Max > 0 {
                print("  Spell Slots: \(newSlots.level1Max) L1\(newSlots.level2Max > 0 ? ", \(newSlots.level2Max) L2" : "")", color: .cyan)
            }
        }

        // Learn new spells
        let newSpells = SpellCatalog.spellsForLevelUp(characterClass: character.characterClass, newLevel: newLevel)
        if !newSpells.isEmpty {
            for spell in newSpells {
                character.knownSpells.append(spell)
                print("  New Spell: \(spell.name) — \(spell.description)", color: .cyan)
            }
        }

        // Class feature announcements
        switch character.characterClass {
        case .fighter:
            if newLevel == 2 {
                print("  New Ability: Second Wind — heal 1d10+level once per short rest", color: .yellow)
            }
        case .rogue:
            let dice = (newLevel + 1) / 2
            if dice > (oldLevel + 1) / 2 {
                print("  Sneak Attack: now \(dice)d6 bonus damage", color: .yellow)
            }
        case .barbarian:
            character.rageUsesRemaining = character.rageMaxUses
            if newLevel == 3 {
                print("  Rage: now 3 uses per long rest", color: .yellow)
            }
        default:
            break
        }

        print("")
        logEvent("\(character.name) reached Level \(newLevel)! (+\(hpGain) HP)", category: "LEVEL")

        waitForContinue()
        inputHandler = { _ in completion() }
    }

    func handleCombatVictory() {
        guard let combat = currentCombat else { return }
        SoundManager.shared.playVictory()
        advanceTime(30)

        // Track stats
        monstersSlain += combat.encounter.monsters.count
        combatsWon += 1

        // Combat cleanup — end rage, hunter's mark, reset death saves, clear status
        for char in party {
            char.isRaging = false
            char.huntersMarkActive = false
            char.isPlayingDead = false
            char.hasFledCombat = false
            char.isDodging = false
            if !char.isConscious && char.deathSaveFailures < 3 {
                // Stabilize unconscious survivors
                char.deathSaveSuccesses = 0
                char.deathSaveFailures = 0
            }
        }

        clearTerminal()
        printTitle("VICTORY!")

        let xp = combat.encounter.totalXP
        let xpEach = xp / party.count

        let defeated = combat.encounter.monsters.map { $0.name }.joined(separator: ", ")
        logEvent("Victory! Defeated \(defeated) (+\(xp) XP)", category: "COMBAT")

        print("All enemies defeated!", color: .brightGreen)
        print("")
        print("Experience gained: \(xp) XP (\(xpEach) each)")

        for char in party {
            char.experiencePoints += xpEach
            let nextLevel = char.level + 1
            if char.canLevelUp {
                print("  \(char.name) has enough XP for Level \(nextLevel)!", color: .yellow)
            }
        }

        // Generate loot from defeated monsters
        var lootGold = 0
        var lootItems: [Item] = []
        for monster in combat.encounter.monsters {
            if let loot = monster.type.rollLoot() {
                if loot.type == .gold {
                    lootGold += loot.value
                    print("  \(monster.name) dropped \(loot.value) gold", color: .yellow)
                } else if loot.type == .potion || loot.type == .item {
                    if let item = resolveItemByName(loot.name) {
                        lootItems.append(item)
                        print("  \(monster.name) dropped \(loot.name)!", color: .brightGreen)
                    }
                }
            }
        }
        // Mark room cleared
        dungeon?.currentRoom?.cleared = true
        dungeon?.currentRoom?.encounter = nil

        // Check for boss room
        if dungeon?.currentRoom?.roomType == .boss {
            handleGameVictory()
            return
        }

        currentCombat = nil
        gameState = .exploring
        SoundManager.shared.startMusic(.exploration)

        // If this was a trap room, trigger the trap after combat
        let pendingTrap = dungeon?.currentRoom?.roomType == .trap && dungeon?.currentRoom?.trapTriggered == false

        waitForContinue()
        inputHandler = { [weak self] _ in
            guard let self = self else { return }
            // Show loot pickup first, then level-ups, then exploration
            let afterLoot = { [weak self] in
                guard let self = self else { return }
                self.checkAndShowLevelUp {
                    if pendingTrap, let room = self.dungeon?.currentRoom {
                        room.trapTriggered = true
                        self.triggerTrap(in: room)
                    } else {
                        self.showExplorationView()
                    }
                }
            }
            self.showLootSequence(gold: lootGold, goldSource: "Combat loot",
                                  items: lootItems, itemSource: "Combat loot", onDone: afterLoot)
        }
    }

    func handleCombatDefeat() {
        // Combat cleanup
        for char in party {
            char.isRaging = false
            char.huntersMarkActive = false
            char.isPlayingDead = false
            char.hasFledCombat = false
            char.isDodging = false
        }

        SoundManager.shared.stopMusic()
        SoundManager.shared.playDefeat()
        clearTerminal()
        gameState = .gameOver
        logEvent("The party has fallen...", category: "COMBAT")

        // Record in Hall of Fame
        recordHallOfFame(outcome: .defeat)

        printLines(asciiSkull, color: .red)
        print("")
        printTitle("DEFEAT")
        print("Your party has fallen...", color: .red)
        print("")
        print("The dungeon claims another group of adventurers.")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.resetGame()
        }
    }

    func handleGameVictory() {
        SoundManager.shared.stopMusic()
        SoundManager.shared.playVictory()
        clearTerminal()
        gameState = .victory

        let currentLevel = dungeon?.level ?? 1
        let dungeonName = dungeon?.name ?? "The dungeon"
        logEvent("DUNGEON CONQUERED! \(dungeonName) has been cleared!", category: "EXPLORE")

        // Record in Hall of Fame + Game Center
        recordHallOfFame(outcome: .victory)

        printLines(asciiTrophy, color: .yellow)
        print("")
        printTitle("DUNGEON CONQUERED!")
        print("You have defeated the dungeon boss!", color: .brightGreen, bold: true)
        print("")
        print("Your party emerges victorious from \(dungeonName)!")
        print("")

        var totalGold = 0
        var totalXP = 0
        for char in party {
            totalGold += char.gold
            totalXP += char.experiencePoints
        }

        print("Final Stats:", color: .cyan)
        print("  Gold collected: \(totalGold)")
        print("  Monsters slain: \(monstersSlain)")
        print("  Combats won: \(combatsWon)")
        print("  Experience gained: \(totalXP)")
        print("")
        print("Recorded in the Hall of Fame!", color: .yellow)
        print("")

        let nextLevel = currentLevel + 1
        showMenu(["Continue to Level \(nextLevel)", "End Adventure"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.continueToNextLevel(nextLevel, dungeonName: dungeonName)
            } else {
                self.resetGame()
            }
        }
    }

    private func continueToNextLevel(_ nextLevel: Int, dungeonName: String) {
        clearTerminal()

        // Level up any eligible characters before proceeding
        checkAndShowLevelUp { [weak self] in
            guard let self = self else { return }

            // Generate new dungeon at next level, keeping the party
            self.dungeon = Dungeon(name: dungeonName, level: nextLevel)
            self.currentCombat = nil
            self.roomsSinceLastSave = 0
            DMEngine.shared.clearHistory()
            self.dmChatLog = []

            self.gameState = .exploring
            self.logEvent("Descended to Level \(nextLevel) of \(dungeonName)", category: "EXPLORE")

            self.clearTerminal()
            self.printTitle("LEVEL \(nextLevel)")
            self.print("Your party descends deeper into \(dungeonName)...", color: .cyan)
            self.print("")
            self.print("The air grows heavier. Stronger foes await.", color: .dimGreen)
            self.print("")

            SoundManager.shared.startMusic(.exploration)

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showExplorationView()
            }
        }
    }

    private func recordHallOfFame(outcome: RunOutcome) {
        var totalGold = 0
        for char in party { totalGold += char.gold }

        let roomsExplored = dungeon?.rooms.values.filter { $0.visited }.count ?? 0
        let totalRooms = dungeon?.rooms.count ?? 0

        let entry = HallOfFameEntry(
            id: UUID(),
            date: Date(),
            partyNames: party.map { $0.name },
            partyDescription: party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", "),
            dungeonName: dungeon?.name ?? "Unknown",
            dungeonLevel: dungeon?.level ?? 1,
            outcome: outcome,
            goldCollected: totalGold,
            monstersSlain: monstersSlain,
            combatsWon: combatsWon,
            roomsExplored: roomsExplored,
            totalRooms: totalRooms,
            gameTimeMinutes: gameTimeMinutes
        )

        HallOfFameManager.shared.addEntry(entry)

        // Game Center submissions
        let gc = GameCenterManager.shared
        gc.submitScore(totalGold, leaderboardID: GameCenterManager.leaderboardGold)
        gc.submitScore(monstersSlain, leaderboardID: GameCenterManager.leaderboardSlain)

        let totalVictories = HallOfFameManager.shared.totalVictories()
        gc.submitScore(totalVictories, leaderboardID: GameCenterManager.leaderboardVictories)

        // Check achievements
        gc.checkAchievements(
            combatsWon: combatsWon,
            monstersSlain: monstersSlain,
            goldCollected: totalGold,
            dungeonLevel: dungeon?.level ?? 1,
            isVictory: outcome == .victory
        )
    }

    // MARK: - Save / Load

    private enum LoadGameOrigin {
        case mainMenu
        case exploration
    }

    func showSaveMenu() {
        clearTerminal()

        printLines(asciiScroll, color: .cyan)
        print("")
        printTitle("Save Game")

        guard let _ = dungeon else {
            print("Error: No dungeon to save.", color: .red)
            showExplorationView()
            return
        }

        let slots = SaveGameManager.shared.listSlots()

        if activeSlotId != nil {
            // We already have an active slot — offer to save to it
            let slotName = activeSlotName ?? "Current Game"
            print("Save to: \(slotName)", color: .cyan)
            print("")

            var options = ["Save (new breakpoint)"]
            if slots.count < SaveGameManager.maxSlots {
                options.append("Save as New Slot")
            }
            options.append("< Back")

            showMenu(options)
            menuHandler = { [weak self] choice in
                guard let self = self else { return }
                if choice == 1 {
                    self.performSave(slotId: self.activeSlotId!, slotName: slotName)
                } else if choice == 2 && slots.count < SaveGameManager.maxSlots {
                    self.askForNewSlotName()
                } else {
                    self.showExplorationView()
                }
            }
        } else if slots.count >= SaveGameManager.maxSlots {
            // No active slot and at limit — must pick a slot to overwrite
            showOverwriteSlotMenu(slots: slots)
        } else {
            // No active slot, room for new one
            askForNewSlotName()
        }
    }

    private func askForNewSlotName() {
        let defaultName = "\(party.first?.name ?? "Unknown") — \(dungeon?.name ?? "Dungeon")"
        print("Default: \(defaultName)", color: .dimGreen)
        promptText("Enter a name (or press Enter):")

        inputHandler = { [weak self] name in
            guard let self = self else { return }
            if self.isReservedWord(name) {
                self.showExplorationView()
                return
            }
            if !name.isEmpty && !self.isNameAppropriate(name) {
                self.print("Not appropriate. Try again.", color: .yellow)
                self.print("")
                self.askForNewSlotName()
                return
            }

            let slotName: String
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                slotName = defaultName
            } else {
                slotName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let newSlotId = UUID()
            self.activeSlotId = newSlotId
            self.activeSlotName = slotName
            self.performSave(slotId: newSlotId, slotName: slotName)
        }
    }

    private func showOverwriteSlotMenu(slots: [SaveSlot]) {
        print("Save slots full (\(SaveGameManager.maxSlots)/\(SaveGameManager.maxSlots)).", color: .yellow)
        print("Choose a slot to replace:", color: .cyan)
        print("")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        for (i, slot) in slots.enumerated() {
            let dateStr = dateFormatter.string(from: slot.latest.savedAt)
            print(" \(i + 1). \(slot.slotName)", color: .brightGreen)
            print("    \(slot.latest.partyDescription)", color: .dimGreen)
            print("    Lv\(slot.latest.dungeonLevel) — \(dateStr) (\(slot.breakpointCount) saves)", color: .dimGreen)
        }
        print("")

        var options = slots.map { "Replace: \($0.slotName)" }
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == options.count {
                self.showExplorationView()
                return
            }
            guard choice > 0 && choice <= slots.count else { return }
            let selected = slots[choice - 1]

            self.clearTerminal()
            self.print("Replace slot:", color: .yellow, bold: true)
            self.print("  \(selected.slotName) (\(selected.breakpointCount) saves)", color: .yellow)
            self.print("  \(selected.latest.partyDescription)", color: .dimGreen)
            self.print("")

            self.showMenu(["Yes, replace this slot", "Choose a different slot", "< Back"])
            self.menuHandler = { [weak self] confirm in
                guard let self = self else { return }
                switch confirm {
                case 1:
                    SaveGameManager.shared.deleteSlot(slotId: selected.slotId)
                    self.askForNewSlotName()
                case 2:
                    self.clearTerminal()
                    self.printTitle("Save Game")
                    self.showOverwriteSlotMenu(slots: slots)
                default:
                    self.showExplorationView()
                }
            }
        }
    }

    private func performSave(slotId: UUID, slotName: String) {
        guard let dungeon = dungeon else { return }

        let partyDesc = party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", ")

        logEvent("Game saved: \(slotName)", category: "SYSTEM")

        let saveGame = SaveGame(
            id: UUID(),
            slotId: slotId,
            savedAt: Date(),
            slotName: slotName,
            partyDescription: partyDesc,
            dungeonName: dungeon.name,
            dungeonLevel: dungeon.level,
            party: party,
            dungeon: dungeon,
            gameState: .exploring,
            gameTimeMinutes: gameTimeMinutes,
            adventureLog: adventureLog,
            monstersSlain: monstersSlain,
            combatsWon: combatsWon
        )

        do {
            try SaveGameManager.shared.save(saveGame)
            SoundManager.shared.playSave()
            print("")
            print("Game saved!", color: .brightGreen, bold: true)
            print("")
            print("  \(slotName)", color: .cyan)
            print("  \(partyDesc)", color: .dimGreen)
            print("  \(dungeon.name) (Level \(dungeon.level))", color: .dimGreen)

            let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slotId)
            let slotCount = SaveGameManager.shared.listSlots().count
            print("")
            print("  \(breakpoints.count) breakpoint(s) in this slot", color: .dimGreen)
            print("  \(slotCount)/\(SaveGameManager.maxSlots) slots used", color: .dimGreen)
        } catch {
            print("Failed to save: \(error.localizedDescription)", color: .red)
        }

        print("")

        showMenu(["Continue Playing", "Load Another Game", "Exit to Main Menu"])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.showExplorationView()
            case 2: self?.showLoadGameMenu(returnTo: .exploration)
            case 3: self?.resetGame()
            default: self?.showExplorationView()
            }
        }
    }

    private func showLoadGameMenu(returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle("Load Game")

        let slots = SaveGameManager.shared.listSlots()

        if slots.isEmpty {
            print("No saved games found.", color: .yellow)
            print("")

            showMenu(["< Back"])
            menuHandler = { [weak self] _ in
                switch origin {
                case .mainMenu:
                    self?.clearTerminal()
                    self?.showMainMenu()
                case .exploration:
                    self?.showExplorationView()
                }
            }
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for (index, slot) in slots.enumerated() {
            let save = slot.latest
            let dateStr = dateFormatter.string(from: save.savedAt)
            let day = save.gameTimeMinutes / 1440 + 1
            let hourOfDay = (save.gameTimeMinutes % 1440) / 60
            let period = hourOfDay >= 12 ? "PM" : "AM"
            let hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay)
            let bpInfo = slot.breakpointCount > 1 ? " (\(slot.breakpointCount) saves)" : ""
            print("\(index + 1). \(slot.slotName)\(bpInfo)", color: .brightGreen)
            print("   \(save.partyDescription)", color: .dimGreen)
            print("   \(save.dungeonName) (Lv\(save.dungeonLevel)) Day \(day), \(hour12) \(period)", color: .dimGreen)
            print("   Saved: \(dateStr)", color: .dimGreen)
            print("")
        }

        var options = slots.map { $0.slotName }
        options.append("Manage Saves")
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == options.count {
                switch origin {
                case .mainMenu:
                    self?.clearTerminal()
                    self?.showMainMenu()
                case .exploration:
                    self?.showExplorationView()
                }
                return
            }

            if choice == options.count - 1 {
                self?.showManageSavesMenu(returnTo: origin)
                return
            }

            guard choice > 0 && choice <= slots.count else { return }
            let slot = slots[choice - 1]

            if slot.breakpointCount > 1 {
                // Show breakpoint selection
                self?.showBreakpointMenu(slot: slot, returnTo: origin)
            } else {
                self?.loadGame(slot.latest)
            }
        }
    }

    private func showBreakpointMenu(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle(slot.slotName)
        print("Select a breakpoint to load:", color: .cyan)
        print("")

        let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slot.slotId)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        for (index, bp) in breakpoints.enumerated() {
            let dateStr = dateFormatter.string(from: bp.savedAt)
            let day = bp.gameTimeMinutes / 1440 + 1
            let hourOfDay = (bp.gameTimeMinutes % 1440) / 60
            let period = hourOfDay >= 12 ? "PM" : "AM"
            let hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay)
            let marker = index == 0 ? " (latest)" : ""
            print("\(index + 1). Day \(day), \(hour12) \(period)\(marker)", color: index == 0 ? .brightGreen : .green)
            print("   \(dateStr) — \(bp.dungeonName) Lv\(bp.dungeonLevel)", color: .dimGreen)
        }
        print("")

        var options = breakpoints.enumerated().map { i, _ in
            i == 0 ? "Load Latest" : "Load #\(i + 1)"
        }
        options.append("< Back")

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == options.count {
                self?.showLoadGameMenu(returnTo: origin)
                return
            }
            guard choice > 0 && choice <= breakpoints.count else { return }
            self?.loadGame(breakpoints[choice - 1])
        }
    }

    private func showManageSavesMenu(returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle("Manage Saves")

        let slots = SaveGameManager.shared.listSlots()

        if slots.isEmpty {
            print("No saved games.", color: .yellow)
            print("")
            showMenu(["< Back"])
            menuHandler = { [weak self] _ in
                self?.showLoadGameMenu(returnTo: origin)
            }
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for (index, slot) in slots.enumerated() {
            let dateStr = dateFormatter.string(from: slot.latest.savedAt)
            let bpInfo = slot.breakpointCount > 1 ? " (\(slot.breakpointCount) saves)" : ""
            print("\(index + 1). \(slot.slotName)\(bpInfo)", color: .brightGreen)
            print("   \(slot.latest.partyDescription)", color: .dimGreen)
            print("   \(dateStr)", color: .dimGreen)
            print("")
        }

        var options = slots.map { $0.slotName }
        options.append("< Back")

        print("Select a slot to manage:", color: .cyan)
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == options.count {
                self?.showLoadGameMenu(returnTo: origin)
                return
            }
            guard choice > 0 && choice <= slots.count else { return }
            self?.showSlotActions(slot: slots[choice - 1], returnTo: origin)
        }
    }

    private func showSlotActions(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printSubtitle(slot.slotName)
        print("  \(slot.latest.partyDescription)", color: .dimGreen)
        print("  \(slot.latest.dungeonName) (Level \(slot.latest.dungeonLevel))", color: .dimGreen)
        print("  \(slot.breakpointCount) breakpoint(s)", color: .dimGreen)
        print("")

        showMenu(["Rename", "Delete Slot", "< Back"])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.renameSlot(slot: slot, returnTo: origin)
            case 2: self?.confirmDeleteSlot(slot: slot, returnTo: origin)
            default: self?.showManageSavesMenu(returnTo: origin)
            }
        }
    }

    private func renameSlot(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        print("")
        promptText("Enter new name for this slot:")

        inputHandler = { [weak self] newName in
            guard let self = self else { return }
            if self.isReservedWord(newName) {
                self.showSlotActions(slot: slot, returnTo: origin)
                return
            }
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                self.print("Name cannot be empty.", color: .yellow)
                self.showSlotActions(slot: slot, returnTo: origin)
                return
            }

            // Rename all breakpoints in this slot
            let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slot.slotId)
            for bp in breakpoints {
                let renamed = SaveGame(
                    id: bp.id,
                    slotId: bp.slotId,
                    savedAt: bp.savedAt,
                    slotName: trimmed,
                    partyDescription: bp.partyDescription,
                    dungeonName: bp.dungeonName,
                    dungeonLevel: bp.dungeonLevel,
                    party: bp.party,
                    dungeon: bp.dungeon,
                    gameState: bp.gameState,
                    gameTimeMinutes: bp.gameTimeMinutes,
                    adventureLog: bp.adventureLog,
                    monstersSlain: bp.monstersSlain,
                    combatsWon: bp.combatsWon
                )
                SaveGameManager.shared.delete(id: bp.id)
                try? SaveGameManager.shared.save(renamed)
            }

            // Update active slot name if this is our slot
            if self.activeSlotId == slot.slotId {
                self.activeSlotName = trimmed
            }

            self.print("")
            self.print("Renamed to '\(trimmed)'", color: .brightGreen)
            self.print("")
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showManageSavesMenu(returnTo: origin)
            }
        }
    }

    private func confirmDeleteSlot(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        print("")
        print("Delete '\(slot.slotName)'?", color: .red, bold: true)
        print("This will delete all \(slot.breakpointCount) breakpoint(s).", color: .yellow)
        print("This cannot be undone.", color: .yellow)
        print("")

        showMenu(["Yes, Delete All", "No, Keep It"])

        menuHandler = { [weak self] choice in
            if choice == 1 {
                SaveGameManager.shared.deleteSlot(slotId: slot.slotId)
                if self?.activeSlotId == slot.slotId {
                    self?.activeSlotId = nil
                    self?.activeSlotName = nil
                }
                self?.print("")
                self?.print("Slot deleted.", color: .red)
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showManageSavesMenu(returnTo: origin)
                }
            } else {
                self?.showSlotActions(slot: slot, returnTo: origin)
            }
        }
    }

    private func loadGame(_ save: SaveGame) {
        party = save.party
        dungeon = save.dungeon
        currentCombat = nil
        gameState = .exploring
        gameTimeMinutes = save.gameTimeMinutes
        adventureLog = save.adventureLog
        monstersSlain = save.monstersSlain
        combatsWon = save.combatsWon

        // Track the loaded slot for future saves/autosaves
        activeSlotId = save.slotId
        activeSlotName = save.slotName

        // Reroll encounters so monsters are different each load
        dungeon?.rerollEncounters()

        logEvent("Game loaded: \(save.slotName)", category: "SYSTEM")
        SoundManager.shared.startMusic(.exploration)

        clearTerminal()
        print("Game loaded!", color: .brightGreen, bold: true)
        print("")
        print("Welcome back to \(save.dungeonName).", color: .cyan)
        print("Time: \(formattedGameTime())", color: .dimGreen)
        print("")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    func confirmExitToMainMenu() {
        clearTerminal()
        print("Exit to Main Menu?", color: .yellow, bold: true)
        print("")
        print("Unsaved progress will be lost.", color: .red)
        print("")

        showMenu(["Yes, Exit", "No, Keep Playing"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.resetGame()
            } else {
                self?.showExplorationView()
            }
        }
    }

    func resetGame() {
        party = []
        dungeon = nil
        currentCombat = nil
        gameTimeMinutes = 360
        adventureLog = []
        monstersSlain = 0
        combatsWon = 0
        activeSlotId = nil
        activeSlotName = nil
        clearTerminal()
        showMainMenu()
    }

    func quitApp() {
        SoundManager.shared.stopMusic()
        clearTerminal()
        printLines(asciiFarewell, color: .dimGreen)
        print("")
        print("Thanks for playing!", color: .brightGreen)
        print("")
        print("Goodbye, adventurer...", color: .dimGreen)
        print("")

        // Exit the app after a brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            exit(0)
        }
    }

    // MARK: - ASCII Art

    private var asciiSwords: [String] {
        [
            "     />",
            "    //>",
            "   ///>",
            "  ////>  BATTLE!",
            " /////>",
            "  \\\\\\\\>",
            "   \\\\\\>",
            "    \\\\>",
            "     \\>",
        ]
    }

    private var asciiSkull: [String] {
        [
            "      ___________",
            "     /           \\",
            "    |  X       X  |",
            "    |      ^      |",
            "    |    \\___/    |",
            "     \\___________/",
            "       ||| |||",
        ]
    }

    private var asciiTrophy: [String] {
        [
            "       ___________",
            "      '._==_==_=_.'",
            "      .-\\:      /-.",
            "     | (|:.     |) |",
            "      '-|:.     |-'",
            "        \\::.    /",
            "         '::. .'",
            "           ) (",
            "         _.' '._",
            "        '-------'",
        ]
    }

    private var asciiScroll: [String] {
        [
            "  ____________________",
            " /                    \\",
            "|   +-+-+-+-+-+-+-+    |",
            "|   |S|A|V|E|D|!|     |",
            "|   +-+-+-+-+-+-+-+    |",
            " \\____________________/",
        ]
    }

    private var asciiFarewell: [String] {
        [
            "  .   .     .  .   .  .",
            "    .   .  :    .  :. .",
            "      .  .   .   :.:. ",
            "    .  :     .  ..:.. ",
            "  .   . :: +.  . | ..",
            "   .  :    .   . . . .",
            "     +   .   .  . :  .",
            "       .       .  . ..",
        ]
    }

    private func asciiHit(attacker: String, target: String) -> [String] {
        [
            "   \\  |  /",
            "    \\ | /",
            " ----*----  HIT!",
            "    / | \\",
            "   /  |  \\",
        ]
    }

    private var asciiCriticalHit: [String] {
        [
            "  \\\\  ||  //",
            "   \\\\ || //",
            "    \\\\||//",
            " ===*CRITICAL*===",
            "    //||\\\\",
            "   // || \\\\",
            "  //  ||  \\\\",
        ]
    }

    private var asciiMiss: [String] {
        [
            "       ~",
            "     ~   ~",
            "       ~     MISS!",
            "     ~   ~",
            "       ~",
        ]
    }

    private var asciiDodge: [String] {
        [
            "    .^.",
            "   / | \\",
            "  /  |  \\  DODGE!",
            " /   |   \\",
            " ----+----",
        ]
    }

    private var asciiMonsterAttack: [String] {
        [
            "      /\\  /\\",
            "     /  \\/  \\",
            "    / SLASH! \\",
            "    \\        /",
            "     \\  /\\  /",
            "      \\/  \\/",
        ]
    }

    private var asciiParty: [String] {
        let icons = ["[=]", "[~]", "[+]", "[*]"]
        let count = min(party.count, 4)
        if count == 0 { return [] }
        let heads = (0..<count).map { _ in " o " }.joined(separator: " ")
        let bodies = (0..<count).map { _ in "/|\\" }.joined(separator: " ")
        let legs = (0..<count).map { _ in "/ \\" }.joined(separator: " ")
        let items = (0..<count).map { icons[$0 % icons.count] }.joined(separator: " ")
        return [" " + heads, " " + bodies, " " + legs, " " + items]
    }
}
