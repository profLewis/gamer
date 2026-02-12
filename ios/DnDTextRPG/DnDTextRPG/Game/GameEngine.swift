//
//  GameEngine.swift
//  DnDTextRPG
//
//  Main game engine that manages game state and logic
//

import SwiftUI
import Combine

class GameEngine: ObservableObject {
    // MARK: - Published Properties

    @Published var terminalLines: [TerminalLine] = []
    @Published var currentMenuOptions: [MenuOption] = []
    @Published var directionExits: [Direction: Bool] = [:]  // direction -> enabled
    @Published var awaitingTextInput: Bool = false
    @Published var awaitingContinue: Bool = false
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

    private func isNameAppropriate(_ name: String) -> Bool {
        let lower = name.lowercased()
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

    private func logEvent(_ message: String) {
        let timestamp = formattedGameTime()
        adventureLog.append("[\(timestamp)] \(message)")
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
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.currentMenuOptions = options
            self.awaitingTextInput = false
            self.awaitingContinue = false
        }
    }

    func showMenuWithDirections(_ options: [MenuOption], exits: [Direction: Bool]) {
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
        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.directionExits = [:]
        }

        if let handler = menuHandler {
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
        DispatchQueue.main.async {
            self.awaitingTextInput = false
        }
        print("> \(text)", color: .dimGreen)

        if let handler = inputHandler {
            handler(text)
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
        print("  Tap menu options to select")
        print("  Type text when prompted")
        print("  Tap 'Continue' to advance")
        print("  Use '< Back' to return to previous menu")
        print("")
        print("GAMEPLAY:", color: .cyan, bold: true)
        print("  Create a party of adventurers")
        print("  Explore procedurally generated dungeons")
        print("  Fight monsters in turn-based combat")
        print("  Collect treasure and gain experience")
        print("")
        print("COMBAT:", color: .cyan, bold: true)
        print("  Initiative determines turn order")
        print("  Roll d20 + modifiers vs AC to hit")
        print("  Defeat all enemies to win!")
        print("")
        print("LICENSE:", color: .cyan, bold: true)
        print("  Game mechanics from the D&D 5e SRD")
        print("  under the Open Gaming License (OGL) v1.0a")
        print("  by Wizards of the Coast LLC.")
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
        print("  Provider: \(currentProvider.displayName)", color: .dimGreen)
        if dm.isConfigured {
            print("  API Key: configured", color: .brightGreen)
            print("  The DM is ready! Use 'Ask the DM' while exploring.", color: .dimGreen)
        } else {
            print("  API Key: not set", color: .yellow)
            print("  Get a key at \(currentProvider.keyURL)", color: .dimGreen)
        }
        print("")

        let currentLevel = dm.adLibLevel
        print("DM AD-LIB LEVEL:", color: .cyan, bold: true)
        print("  Current: \(currentLevel.displayName) — \(currentLevel.description)", color: .dimGreen)
        print("")

        print("FONT SIZE:", color: .cyan, bold: true)
        print("  Current: \(fontSizeSetting.displayName)", color: .dimGreen)
        print("")

        let currentAutosave = autosaveInterval
        print("AUTOSAVE:", color: .cyan, bold: true)
        print("  Current: \(currentAutosave.displayName)", color: .dimGreen)
        print("")

        var options = ["AI Provider", "Set API Key", "DM Ad-lib Level", "Font Size", "Autosave"]
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
                self?.showFontSizeMenu()
            } else if choice == 5 {
                self?.showAutosaveMenu()
            } else if dm.isConfigured && choice == 6 {
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
        print("  Choose which AI powers your Dungeon Master.", color: .dimGreen)
        print("  Each provider requires its own API key.", color: .dimGreen)
        print("")

        let current = DMEngine.shared.provider
        for provider in AIProvider.allCases {
            let marker = provider == current ? " <--" : ""
            let hasKey = DMEngine.shared.apiKey(for: provider) != nil
            let keyStatus = hasKey ? " [key set]" : ""
            print("  \(provider.displayName)\(keyStatus)\(marker)",
                  color: provider == current ? .brightGreen : .green)
            print("     Get key: \(provider.keyURL)", color: .dimGreen)
            print("")
        }

        let options = AIProvider.allCases.map { $0.displayName } + ["< Back"]
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice <= AIProvider.allCases.count {
                let selected = AIProvider.allCases[choice - 1]
                DMEngine.shared.provider = selected
                DMEngine.shared.clearHistory()
                self?.print("")
                self?.print("AI Provider set to: \(selected.displayName)", color: .brightGreen)
                if DMEngine.shared.apiKey(for: selected) == nil {
                    self?.print("You'll need to set an API key for this provider.", color: .yellow)
                }
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
                self?.print("")
                self?.print("DM Ad-lib level set to: \(DMEngine.shared.adLibLevel.displayName)", color: .brightGreen)
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
        print("")
        print("  Provider: \(provider.displayName)", color: .cyan)
        print("  Get a key at \(provider.keyURL)", color: .dimGreen)
        print("")
        promptText("Paste your \(provider.displayName) API key:")

        inputHandler = { [weak self] key in
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                self?.showSettings()
                return
            }
            DMEngine.shared.apiKey = trimmed
            self?.print("")
            self?.print("\(provider.displayName) API key saved!", color: .brightGreen)
            self?.print("The AI Dungeon Master is now available while exploring.", color: .cyan)
            self?.print("")
            self?.waitForContinue()
            self?.inputHandler = { [weak self] _ in
                self?.showSettings()
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

        var options = ["< Back"]
        if GameCenterManager.shared.isAuthenticated {
            options.insert("Game Centre Leaderboards", at: 0)
            options.insert("Game Centre Achievements", at: 1)
        }

        showMenu(options)

        menuHandler = { [weak self] choice in
            if GameCenterManager.shared.isAuthenticated {
                switch choice {
                case 1:
                    GameCenterManager.shared.showLeaderboard()
                    self?.showHallOfFame()
                case 2:
                    GameCenterManager.shared.showAchievements()
                    self?.showHallOfFame()
                default:
                    self?.clearTerminal()
                    self?.showMainMenu()
                }
            } else {
                self?.clearTerminal()
                self?.showMainMenu()
            }
        }
    }

    // MARK: - New Game

    func startNewGame() {
        clearTerminal()
        printTitle("New Adventure")
        print("How many adventurers in your party? (1-4)")
        print("")

        showMenu(["1 Character (Solo)", "2 Characters", "3 Characters", "4 Characters (Full Party)", "< Back"])

        menuHandler = { [weak self] choice in
            if choice == 5 {
                self?.clearTerminal()
                self?.showMainMenu()
                return
            }
            self?.totalCharacters = choice
            self?.creatingCharacterIndex = 0
            self?.party = []
            self?.startCharacterCreation()
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

        // Show a few random Stranger Things character name suggestions
        let suggestions = suggestedNames.shuffled().prefix(4).joined(separator: ", ")
        print("  Suggestions: \(suggestions)", color: .dimGreen)
        print("")

        promptText("Enter character name (or 'back'):")

        inputHandler = { [weak self] name in
            guard let self = self else { return }
            if name.lowercased() == "back" {
                self.clearTerminal()
                self.startNewGame()
                return
            }
            let cleanName = name.isEmpty ? "Adventurer" : name
            if !self.isNameAppropriate(cleanName) {
                self.print("That name is not befitting of an adventurer. Try again.", color: .yellow)
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
    }

    func chooseAbilityMethod() {
        clearTerminal()
        printSubtitle("Ability Score Method")

        print("Choose how to generate ability scores:")
        print("")

        showMenu(["Standard Array [15,14,13,12,10,8]", "Roll 4d6 drop lowest", "< Back"])

        menuHandler = { [weak self] choice in
            if choice == 3 {
                self?.chooseClass()
                return
            }
            if choice == 1 {
                self?.tempScores = AbilityScores.standardArray
            } else {
                self?.tempScores = Dice.rollAbilityScores()
                self?.print("You rolled: \(self?.tempScores ?? [])", color: .brightGreen)
            }
            self?.startAssigningScores()
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

        let unselected = available.filter { !selectedSkills.contains($0) }
        var skillNames = unselected.map { $0.rawValue }
        skillNames.append("< Back (restart skills)")

        print("Skill \(selectedSkills.count + 1):")
        showMenu(skillNames)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == skillNames.count {
                self.chooseSkills()
                return
            }
            let skill = unselected[choice - 1]
            self.selectedSkills.append(skill)
            self.selectNextSkill(from: available, remaining: remaining - 1)
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
            abilityScores: scores
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
                self.startCharacterCreation()
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
                    self.startCharacterCreation()
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

        promptText("Name your dungeon (or press Enter for default):")

        inputHandler = { [weak self] name in
            guard let self = self else { return }
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
        logEvent("Entered \(dungeon?.name ?? "the dungeon")")
        SoundManager.shared.startMusic(.exploration)
        showExplorationView()
    }

    // MARK: - Exploration

    /// Redraws the full exploration screen: map + room description + party + menu
    func showExplorationView() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }

        clearTerminal()

        // Always show the map at the top
        let mapLines = dungeon.getMapDisplay()
        printLines(mapLines, color: .dimGreen, size: mapFontSize)
        print("")

        // Room description
        print(room.name, color: .brightGreen, bold: true)
        print(room.roomType.description)

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
        print(formattedGameTime(), color: .dimGreen)
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

        if DMEngine.shared.isConfigured && DMEngine.shared.adLibLevel != .off {
            menuOpts.append(MenuOption("Ask the DM"))
            actions.append { [weak self] in self?.askTheDM() }
        }

        menuOpts.append(MenuOption("Save Game"))
        actions.append { [weak self] in self?.showSaveMenu() }

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
                logEvent("Moved \(direction.rawValue) to \(room.name)")
            }
            autosaveIfNeeded()
        } else {
            print(result.message, color: .yellow)
        }
        showExplorationView()
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
            if Dice.d6() >= 4 {
                let gold = Dice.rollSum(2, d: 6) * 5
                print("Hidden stash: \(gold) gold pieces!")
                party.first?.gold += gold
                logEvent("Found \(gold) gold in a hidden stash")
            } else {
                print("A secret alcove, but it's empty.")
                logEvent("Searched room — found an empty alcove")
            }
        } else {
            print("You don't find anything of interest.")
            logEvent("Searched room — found nothing")
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

        var totalGold = 0
        var itemNames: [String] = []
        for treasureItem in room.treasure {
            if treasureItem.type == .potion {
                let potion = ItemCatalog.healingPotion()
                if let char = party.first, char.canCarry(potion) {
                    _ = char.addItem(potion)
                    print("  \(treasureItem.name) — added to bag!", color: .brightGreen)
                } else {
                    totalGold += treasureItem.value
                    print("  \(treasureItem.name) — too heavy, sold for \(treasureItem.value)gp")
                }
            } else {
                totalGold += treasureItem.value
                print("  \(treasureItem.name) — \(treasureItem.value)gp")
            }
            itemNames.append(treasureItem.name)
        }

        if totalGold > 0 {
            party.first?.gold += totalGold
            print("")
            print("  Total gold: +\(totalGold)", color: .yellow)
        }
        room.treasure.removeAll()
        logEvent("Collected treasure: \(itemNames.joined(separator: ", "))")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    // MARK: - Inventory

    func showInventory() {
        guard let character = party.first else { return }

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
            actions.append { [weak self] in self?.showEquipMenu(character: character, type: .weapon, label: "Weapon") }
        }
        if !equipableArmor.isEmpty {
            options.append("Equip Armor")
            actions.append { [weak self] in self?.showEquipMenu(character: character, type: .armor, label: "Armor") }
        }
        if !equipableShields.isEmpty {
            options.append("Equip Shield")
            actions.append { [weak self] in self?.showEquipMenu(character: character, type: .shield, label: "Shield") }
        }
        if !usablePotions.isEmpty {
            options.append("Use Potion")
            actions.append { [weak self] in self?.showUsePotionMenu(character: character) }
        }
        if character.equippedWeapon != nil {
            options.append("Unequip Weapon")
            actions.append { [weak self] in
                character.unequipWeapon()
                self?.showInventory()
            }
        }
        if character.equippedArmor != nil {
            options.append("Unequip Armor")
            actions.append { [weak self] in
                character.unequipArmor()
                self?.showInventory()
            }
        }
        if !character.inventory.isEmpty {
            options.append("Drop Item")
            actions.append { [weak self] in self?.showDropItemMenu(character: character) }
        }

        options.append("< Back")
        actions.append { [weak self] in self?.showExplorationView() }

        showMenu(options)
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showEquipMenu(character: Character, type: ItemType, label: String) {
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
                self?.showInventory()
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
            self?.showInventory()
        }
    }

    private func showUsePotionMenu(character: Character) {
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
                self.showInventory()
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
                self?.showInventory()
            }
        }
    }

    private func showDropItemMenu(character: Character) {
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
                self.showInventory()
                return
            }
            guard choice > 0 && choice <= character.inventory.count else { return }
            let item = character.inventory[choice - 1]
            character.removeItem(item)
            self.print("")
            self.print("  Dropped \(item.name).", color: .yellow)
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showInventory()
            }
        }
    }

    // MARK: - Shop

    func visitShop() {
        guard let character = party.first, let dungeon = dungeon else { return }

        shopEngine.openShop(character: character, dungeonLevel: dungeon.level) { [weak self] in
            self?.showExplorationView()
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

        // Game time
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

        showMenu(["Adventure Log", "< Back"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.showAdventureLog()
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
            // Show most recent events first, limit to last 30
            let recentLog = adventureLog.suffix(30)
            for entry in recentLog {
                print("  \(entry)", color: .dimGreen)
            }
            if adventureLog.count > 30 {
                print("")
                print("  (\(adventureLog.count - 30) earlier entries omitted)", color: .dimGreen)
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

            self.clearTerminal()

            // Show map at top
            if let dungeon = self.dungeon {
                self.printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
                self.print("")
            }

            SoundManager.shared.stopMusic()
            SoundManager.shared.playHeal()
            if choice == 1 {
                self.advanceTime(60)
                self.print("Your party takes a short rest...", color: .cyan)
                var healed: [String] = []
                for char in self.party {
                    let healAmount = Dice.rollSum(1, d: char.characterClass.hitDie)
                    char.heal(healAmount)
                    self.print("\(char.name) recovers \(healAmount) HP")
                    healed.append("\(char.name) +\(healAmount)HP")
                    // Short rest: reset Second Wind
                    if char.characterClass == .fighter {
                        char.secondWindUsed = false
                    }
                }
                self.logEvent("Short rest — \(healed.joined(separator: ", "))")
            } else {
                self.advanceTime(480)
                self.print("Your party takes a long rest...", color: .cyan)
                for char in self.party {
                    char.heal(char.maxHP)
                    self.print("\(char.name) fully recovers!")
                    // Long rest: restore spell slots
                    if !char.spellSlots.isEmpty {
                        char.spellSlots.restoreAll()
                        self.print("  Spell slots restored", color: .cyan)
                    }
                    // Long rest: reset class features
                    char.secondWindUsed = false
                    if char.characterClass == .barbarian {
                        char.rageUsesRemaining = char.rageMaxUses
                        char.isRaging = false
                        self.print("  Rage uses restored", color: .cyan)
                    }
                    char.huntersMarkActive = false
                }
                self.logEvent("Long rest — party fully recovered")
            }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                SoundManager.shared.startMusic(.exploration)
                self?.showExplorationView()
            }
        }
    }

    // MARK: - AI Dungeon Master

    func askTheDM() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen, size: mapFontSize)
            print("")
        }

        print("The DM awaits your question...", color: .cyan, bold: true)
        print("(Type your question or action, or 'back' to return)", color: .dimGreen)
        print("")

        promptText(">")

        inputHandler = { [weak self] input in
            guard let self = self else { return }

            if input.lowercased() == "back" || input.isEmpty {
                self.showExplorationView()
                return
            }

            self.print("")
            self.print("The DM considers...", color: .dimGreen)

            let context = self.buildDMContext()

            DMEngine.shared.ask(input, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // Parse commands at level 3
                    let result = DMEngine.parseCommands(from: response)
                    let displayText = DMEngine.shared.adLibLevel == .full ? result.cleanText : response

                    self.print("")
                    self.print("DM:", color: .yellow, bold: true)

                    // Print each paragraph, let SwiftUI handle word wrap
                    for paragraph in displayText.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            self.print("")
                        } else {
                            self.print("  \(trimmed)", color: .yellow)
                        }
                    }

                    // Apply DM commands at level 3
                    if DMEngine.shared.adLibLevel == .full {
                        if result.bonusGold > 0 {
                            self.party.first?.gold += result.bonusGold
                            self.print("")
                            self.print("  [The DM grants \(result.bonusGold) gold!]", color: .yellow, bold: true)
                        }
                        if result.healAmount > 0 {
                            for char in self.party {
                                char.heal(result.healAmount)
                            }
                            self.print("  [The DM heals the party for \(result.healAmount) HP!]", color: .brightGreen, bold: true)
                        }
                        for itemName in result.grantedItems {
                            if let item = self.resolveItemByName(itemName) {
                                if let char = self.party.first, char.canCarry(item) {
                                    _ = char.addItem(item)
                                    self.print("  [Received: \(item.name)!]", color: .brightGreen, bold: true)
                                }
                            }
                        }
                    }

                    self.print("")
                    self.logEvent("Asked DM: \(input)")

                    // Text prompt for follow-up, with Back button
                    self.print("(Type another question, or tap Back)", color: .dimGreen)
                    self.promptTextWithMenu(">", options: ["< Back"])

                    self.inputHandler = { [weak self] followUp in
                        guard let self = self else { return }
                        if followUp.lowercased() == "back" || followUp.isEmpty {
                            self.showExplorationView()
                            return
                        }
                        // Recurse — ask the DM again with new input
                        self.print("")
                        self.print("The DM considers...", color: .dimGreen)
                        let ctx = self.buildDMContext()
                        DMEngine.shared.ask(followUp, context: ctx) { [weak self] resp in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                let r = DMEngine.parseCommands(from: resp)
                                let dt = DMEngine.shared.adLibLevel == .full ? r.cleanText : resp
                                self.print("")
                                self.print("DM:", color: .yellow, bold: true)
                                for p in dt.components(separatedBy: "\n") {
                                    let t = p.trimmingCharacters(in: .whitespaces)
                                    if t.isEmpty { self.print("") }
                                    else { self.print("  \(t)", color: .yellow) }
                                }
                                if DMEngine.shared.adLibLevel == .full {
                                    if r.bonusGold > 0 {
                                        self.party.first?.gold += r.bonusGold
                                        self.print("  [+\(r.bonusGold) gold!]", color: .yellow, bold: true)
                                    }
                                    if r.healAmount > 0 {
                                        for c in self.party { c.heal(r.healAmount) }
                                        self.print("  [+\(r.healAmount) HP!]", color: .brightGreen, bold: true)
                                    }
                                    for itemName in r.grantedItems {
                                        if let item = self.resolveItemByName(itemName),
                                           let c = self.party.first, c.canCarry(item) {
                                            _ = c.addItem(item)
                                            self.print("  [Received: \(item.name)!]", color: .brightGreen, bold: true)
                                        }
                                    }
                                }
                                self.print("")
                                self.logEvent("Asked DM: \(followUp)")
                                self.print("(Type another question, or tap Back)", color: .dimGreen)
                                self.promptTextWithMenu(">", options: ["< Back"])
                                self.menuHandler = { [weak self] _ in
                                    self?.showExplorationView()
                                }
                            }
                        }
                    }
                    self.menuHandler = { [weak self] _ in
                        self?.showExplorationView()
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

            if input.lowercased() == "back" || input.isEmpty {
                self.showPlayerCombatMenu(characterId: characterId)
                return
            }

            self.print("")
            self.print("The DM considers...", color: .dimGreen)

            let context = self.buildDMContext(combatContext: combat, activeCharacter: character)

            DMEngine.shared.ask(input, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    self.print("")
                    self.print("DM:", color: .yellow, bold: true)
                    for paragraph in response.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { self.print("") }
                        else { self.print("  \(trimmed)", color: .yellow) }
                    }
                    self.print("")
                    self.logEvent("Asked DM in combat: \(input)")

                    // After DM responds, continue combat (counts as their turn action)
                    self.print("(Press continue to proceed)", color: .dimGreen)
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        combat.checkCombatEnd()
                        combat.nextTurn()
                        self?.runCombatTurn()
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

        return DMContext(
            roomName: room?.name ?? "Unknown",
            roomType: room?.roomType.rawValue ?? "Unknown",
            roomDescription: room?.roomType.description ?? "",
            exits: exitList,
            isCleared: room?.cleared ?? false,
            partyStatus: partyStatus,
            gameTime: formattedGameTime(),
            inventorySummary: inventorySummary,
            adLibLevel: DMEngine.shared.adLibLevel,
            combatSummary: combatSummary
        )
    }

    private func resolveItemByName(_ name: String) -> Item? {
        let lower = name.lowercased()
        if lower.contains("greater") && lower.contains("healing") { return ItemCatalog.greaterHealingPotion() }
        if lower.contains("healing") || lower.contains("potion") { return ItemCatalog.healingPotion() }
        if lower.contains("dagger") { return ItemCatalog.dagger() }
        if lower.contains("torch") { return ItemCatalog.torch() }
        if lower.contains("rope") { return ItemCatalog.rope() }
        if lower.contains("shortsword") { return ItemCatalog.shortsword() }
        if lower.contains("longsword") { return ItemCatalog.longsword() }
        return nil
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

    func displayAttackReport(_ report: AttackReport, completion: @escaping () -> Void) {
        let attackColor: TerminalColor = report.isPlayerAttack ? .brightGreen : .red

        print("\(report.attackerName) attacks \(report.targetName)!", color: attackColor, bold: true)
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
                        self.print("  \(report.targetName) is defeated!", color: .yellow, bold: true)
                    } else if report.targetUnconscious {
                        self.print("  \(report.targetName) falls unconscious!", color: .red, bold: true)
                    } else {
                        self.print("  \(report.targetName): \(report.targetCurrentHP)/\(report.targetMaxHP) HP", color: .dimGreen)
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
        logEvent("Battle! Encountered \(monsterNames)")

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
            // Check if unconscious — death saving throw instead of normal turn
            if let character = party.first(where: { $0.id == current.id }),
               !character.isConscious {
                showDeathSavingThrow(character: character)
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
            self.print("\(character.name) takes a defensive stance.")
            combat.checkCombatEnd()
            combat.nextTurn()
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in self?.runCombatTurn() }
        }

        // Ask the DM (in combat)
        if DMEngine.shared.isConfigured && DMEngine.shared.adLibLevel != .off {
            options.append("Ask the DM")
            actions.append { [weak self] in
                self?.askTheDMInCombat(characterId: characterId)
            }
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
                }
                self.currentCombat = nil
                self.gameState = .exploring

                // Don't clear the room — encounter stays
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
        logEvent("\(character.name) reached Level \(newLevel)! (+\(hpGain) HP)")

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

        // Combat cleanup — end rage, hunter's mark, reset death saves
        for char in party {
            char.isRaging = false
            char.huntersMarkActive = false
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
        logEvent("Victory! Defeated \(defeated) (+\(xp) XP)")

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

        waitForContinue()
        inputHandler = { [weak self] _ in
            guard let self = self else { return }
            // Check for level-ups before returning to exploration
            self.checkAndShowLevelUp {
                self.showExplorationView()
            }
        }
    }

    func handleCombatDefeat() {
        // Combat cleanup
        for char in party {
            char.isRaging = false
            char.huntersMarkActive = false
        }

        SoundManager.shared.stopMusic()
        SoundManager.shared.playDefeat()
        clearTerminal()
        gameState = .gameOver
        logEvent("The party has fallen...")

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
        logEvent("DUNGEON CONQUERED! \(dungeon?.name ?? "The dungeon") has been cleared!")

        // Record in Hall of Fame + Game Center
        recordHallOfFame(outcome: .victory)

        printLines(asciiTrophy, color: .yellow)
        print("")
        printTitle("DUNGEON CONQUERED!")
        print("You have defeated the dungeon boss!", color: .brightGreen, bold: true)
        print("")
        print("Your party emerges victorious from \(dungeon?.name ?? "the dungeon")!")
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

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.resetGame()
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

        logEvent("Game saved: \(slotName)")

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
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                self?.print("Name cannot be empty.", color: .yellow)
                self?.showSlotActions(slot: slot, returnTo: origin)
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
            if self?.activeSlotId == slot.slotId {
                self?.activeSlotName = trimmed
            }

            self?.print("")
            self?.print("Renamed to '\(trimmed)'", color: .brightGreen)
            self?.print("")
            self?.waitForContinue()
            self?.inputHandler = { [weak self] _ in
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

        logEvent("Game loaded: \(save.slotName)")
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

        waitForContinue()
        inputHandler = { _ in
            // Suspend the app (go to home screen)
            DispatchQueue.main.async {
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
            }
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
