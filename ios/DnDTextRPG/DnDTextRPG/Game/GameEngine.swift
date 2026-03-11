//
//  GameEngine.swift
//  DnDTextRPG
//
//  Main game engine that manages game state and logic
//

import SwiftUI
import Combine
import AVFoundation
import GameKit
#if os(macOS)
import AppKit
#endif

class GameEngine: ObservableObject {
    // MARK: - Published Properties

    @Published var terminalLines: [TerminalLine] = []
    @Published var currentMenuOptions: [MenuOption] = []
    @Published var directionExits: [Direction: Bool] = [:]  // direction -> enabled
    @Published var securedExits: Set<Direction> = []  // directions that are barred
    /// Set to a 1-based menu index to animate a button press (e.g. from voice input)
    @Published var pressedMenuIndex: Int?
    @Published var menuImageName: String? = nil
    /// Name of the dragon GIF to show (nil = hidden)
    @Published var dragonGifName: String? = nil
    @Published var awaitingTextInput: Bool = false
    @Published var awaitingContinue: Bool = false
    @Published var chatInputMode: Bool = false
    @Published var isHoldingScreen: Bool = false

    /// Brief dim-then-restore pulse for text content (e.g. re-pressing a help button)
    @Published var textFlashOpacity: CGFloat = 1.0

    /// When set, TerminalView shows an icon bar (close + optional mic/chat-focus)
    @Published var closeHandler: (() -> Void)?

    /// Accessibility: show mic icon in menu icon bars for voice menu selection
    @Published var voiceMenuEnabled: Bool = UserDefaults.standard.bool(forKey: "voiceMenuEnabled")

    /// Card navigation style: true = arrow buttons, false = swipe gesture only
    @Published var useArrowNavigation: Bool = UserDefaults.standard.object(forKey: "useArrowNavigation") == nil ? false : UserDefaults.standard.bool(forKey: "useArrowNavigation")

    /// Suppress auto-scroll-to-bottom (for help/card views where top content matters)
    @Published var suppressAutoScroll: Bool = false
    /// Lock scrolling entirely (for card views with swipe navigation)
    @Published var scrollLocked: Bool = false

    /// Swipe left/right handlers for top-trump card navigation
    var swipeLeftHandler: (() -> Void)?
    var swipeRightHandler: (() -> Void)?
    /// Jump to random card
    var swipeRandomHandler: (() -> Void)?
    /// Card position label e.g. " 3/12"
    @Published var cardPositionLabel: String?

    /// Info screen auto-dismiss delay in seconds (configurable in Gameplay settings)
    @Published var infoTimeout: Double = UserDefaults.standard.object(forKey: "infoTimeout") == nil ? 3.0 : UserDefaults.standard.double(forKey: "infoTimeout")

    /// Whether the DM is currently reading the screen aloud
    @Published var isSpeakingAloud: Bool = false
    /// Persistent speaker mode — stays on until toggled off
    @Published var speakerModeOn: Bool = false
    /// Temporarily paused — stops reading this page but re-engages on next screen change
    @Published var speakerPaused: Bool = false
    /// Tracks whether the current page has already been read aloud (reset on clearTerminal)
    private var speakerHasReadCurrentPage: Bool = false
    private var speakingCheckTimer: Timer?
    private var lastSpeakerTapTime: Date?
    /// Recently spoken text snippets — avoids re-reading repeated NPC greetings etc.
    private var recentlySpokenTexts: [String] = []
    private let maxSpokenMemory = 10

    /// Accessibility: scale multiplier for UI icons (close, mic, return, prompt)
    @Published var iconScaleSetting: Int = UserDefaults.standard.integer(forKey: "iconScaleSetting") // 0=normal, 1=large, 2=extra-large
    /// Adventure log display limit: 0 = all, otherwise show last N entries
    var adventureLogLimit: Int {
        get { UserDefaults.standard.integer(forKey: "adventureLogLimit") } // 0 = all
        set { UserDefaults.standard.set(newValue, forKey: "adventureLogLimit") }
    }
    var iconScale: CGFloat {
        switch iconScaleSetting {
        case 1: return 1.5
        case 2: return 2.0
        default: return 1.0
        }
    }

    /// Use custom in-app keyboard instead of system keyboard (no globe/mic)
    @Published var useCustomKeyboard: Bool = UserDefaults.standard.object(forKey: "useCustomKeyboard") == nil ? true : UserDefaults.standard.bool(forKey: "useCustomKeyboard")

    /// Idle animation prompts (eye blinks, combat hesitation, save menu nags)
    @Published var idlePromptsEnabled: Bool = UserDefaults.standard.bool(forKey: "idlePromptsEnabled")

    /// When set, shows a dice icon next to the return button in text input for re-rolling suggestions
    var rerollHandler: (() -> Void)?

    /// Undo/redo handlers — shown as icons in the input bar on edit screens
    var undoHandler: (() -> Void)?
    var redoHandler: (() -> Void)?

    /// Screen-scoped undo/redo stacks — keyed by screen identifier
    private var screenUndoStacks: [String: [Data]] = [:]
    private var screenRedoStacks: [String: [Data]] = [:]
    private var currentUndoScreen: String? = nil

    private var editingCharacterIndex: Int?
    private var editScreenIsInGame: Bool = true

    /// Track last room where inventory was opened (for pack animation)
    private var lastInventoryRoomId: Int?

    /// Long-press handler for terminal text lines — maps line index to action
    var textLongPressHandler: ((Int) -> Void)? {
        didSet { DispatchQueue.main.async { self.textTapEnabled = self.textLongPressHandler != nil } }
    }
    @Published var textTapEnabled: Bool = false
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
    private var lastSaveTime: Date?

    // DM chat log (persists across DM mode entries)
    private var dmChatLog: [(isUser: Bool, text: String)] = []
    private var adventureLogIndexAtLastDM: Int = 0

    // Party chat (used in single-player; multiplayer uses multiplayerState.partyChatLog)
    var partyChatLog: [PartyChatMessage] = []
    private var lastChatTarget: UUID?  // Track last @mentioned character for conversation continuation

    // Torch state
    @Published var torchLit: Bool = false
    var torchTurnsRemaining: Int = 0      // minutes remaining on active torch
    var activeTorchId: UUID?              // which torch item is currently burning
    var torchHolderId: UUID?              // which character is holding the lit torch

    // DM mode tracking
    var returnToDMAfterCombat: Bool = false
    var inDMMode: Bool = false

    // Combat idle timer — penalise hesitation
    private var combatIdleTimer: Timer?
    private var combatHesitating: Bool = false  // true = next attack has disadvantage

    // Track barricade state for DM context injection
    private var lastDMBarricadeState: Set<Direction> = []

    // Save menu idle timer — DM nags and time ticks
    private var saveMenuIdleTimer: Timer?
    private var saveMenuNagCount: Int = 0

    // Party status idle timer — weapon animations
    private var partyStatusAnimTimer: Timer?
    private var partyStatusAnimFrame: Int = 0

    // MARK: - Multiplayer State

    var isMultiplayer: Bool = false
    var multiplayerState: MultiplayerMatchState?
    private var pendingRemoteSlots: Set<Int> = []  // Character slot indices assigned to remote players
    private var pendingReplacementCharacterId: UUID?  // Placeholder char to replace when remote player customises
    private var pendingInviteMatch: GKTurnBasedMatch?  // Cached invite for main menu button
    private var pendingRemoteCharacterId: UUID?  // AI char being converted to remote in local-to-multiplayer flow
    private var matchPollTimer: Timer?  // Polls for match updates while waiting
    private var invitePollTimer: Timer?  // Periodically re-checks for invites on main menu
    private var lastNudgeTime: Date? = nil  // When nudge was last sent
    private var nudgeCooldownTimer: Timer? = nil  // Countdown timer for re-nudge
    private var nudgeCooldownSeconds: Int = 0  // Seconds remaining before re-nudge
    private var nudgeCooldownSpeed: Double = 1.0  // 1.0 = normal, faster when long-pressing
    private static let nudgeCooldownDuration = 60  // Seconds between nudges
    private var shownTipIndices: Set<Int> = []
    private var tipCooldown: Int = 0

    static let gameplayTips: [String] = {
        // Core tips not in FAQ
        var tips = [
            "Hold the Rest button for a fast long rest — restores more HP and spell slots.",
            "Long-press a button during character creation to auto-fill all remaining choices.",
            "Long-press a direction to barricade or unblock a door. Barricade the doors and douse the light before resting!",
            "Try long-pressing buttons — many have hidden shortcuts! Barricades, dark actions, quick starts, and more.",
            "Long-press Search Room in the dark to attempt it blindly — risky but sometimes rewarding!",
            "Use View Card in Party Review to see detailed character stats. Swipe left/right to browse.",
            "Settings are available from Party Status — adjust sound, DM, display, and more during your adventure.",
            "Set up a free Google Gemini API key in Settings for a smarter Dungeon Master.",
            "Save your game before boss fights — they can be deadly!",
            "Douse your torch to sneak past monsters — 30% chance they won't spot you in the dark.",
            "Each character can carry up to 12 items. Sell unwanted gear at the Merchant to free space.",
            "You can type button names or numbers at the prompt instead of tapping — try typing 'help' or '1'.",
            "Swipe left on any screen to go back or close it.",
        ]
        // Pull concise answers from FAQ entries
        for entry in FAQData.allEntries {
            // Only include short answers as tips
            if entry.answer.count <= 180 {
                tips.append(entry.answer)
            }
        }
        return tips
    }()
    var localPlayerID: String? {
        GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID : nil
    }
    var isPartyLeader: Bool {
        multiplayerState?.players.first(where: { $0.gamePlayerID == localPlayerID })?.isPartyLeader ?? false
    }
    var localCharacterId: UUID? {
        multiplayerState?.players.first(where: { $0.gamePlayerID == localPlayerID })?.characterId
    }

    // Transient status message shown once in exploration view
    private var explorationStatusMessage: (text: String, color: TerminalColor)? = nil

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
    var directionLongPressHandler: ((Direction) -> Void)?
    @Published var dpadCenterLabel: String? = nil
    var dpadCenterHandler: (() -> Void)?
    var dpadCenterLongPressHandler: (() -> Void)?
    @Published var dpadNPCLabel: String? = nil
    var dpadNPCHandler: (() -> Void)?

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

    /// Produce short display names for the party that fit on buttons.
    /// Drops " the X" titles, abbreviates to "First L" if needed, keeps full name if short enough.
    func shortNames(maxLen: Int = 12) -> [UUID: String] {
        let chars = party
        var result: [UUID: String] = [:]

        // Phase 1: strip " the ..." suffix
        var candidates: [(Character, String)] = chars.map { char in
            let name = char.name
            if let range = name.range(of: " the ", options: .caseInsensitive) {
                return (char, String(name[name.startIndex..<range.lowerBound]))
            }
            return (char, name)
        }

        // Phase 2: if still too long, abbreviate multi-word names to "First L"
        candidates = candidates.map { (char, name) in
            if name.count <= maxLen { return (char, name) }
            let words = name.split(separator: " ")
            if words.count >= 2 {
                let short = "\(words[0]) \(words[1].prefix(1))"
                return (char, short)
            }
            return (char, String(name.prefix(maxLen)))
        }

        // Phase 3: ensure uniqueness — append class initial if needed
        let names = candidates.map { $0.1.lowercased() }
        for (i, (char, name)) in candidates.enumerated() {
            let isDuplicate = names.enumerated().contains { $0.offset != i && $0.element == name.lowercased() }
            if isDuplicate {
                let classInitial = String(char.characterClass.rawValue.prefix(3))
                result[char.id] = "\(name) (\(classInitial))"
            } else {
                result[char.id] = name
            }
        }

        return result
    }

    /// Get a short display name for a character in the context of the current party.
    func shortName(for char: Character) -> String {
        let map = shortNames()
        return map[char.id] ?? char.name
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
        if gameTimeLimit > 0 && gameTimeMinutes >= gameTimeLimit && gameState == .exploring {
            handleTimeLimitExpired()
        }
    }

    private func logEvent(_ message: String, category: String? = nil) {
        let timestamp = formattedGameTime()
        if let cat = category {
            adventureLog.append("[\(timestamp)] [\(cat)] \(message)")
        } else {
            adventureLog.append("[\(timestamp)] \(message)")
        }
    }

    /// Log a multiplayer action visible to remote players in catch-up
    private func logMultiplayerAction(_ description: String) {
        guard isMultiplayer else { return }
        let playerName = GKLocalPlayer.local.displayName
        multiplayerState?.addAction(playerName: playerName, description: description)
    }

    // MARK: - Terminal Output

    func print(_ text: String, color: TerminalColor = .green, bold: Bool = false, size: CGFloat = 14, centered: Bool = false) {
        DispatchQueue.main.async {
            self.terminalLines.append(TerminalLine(text, color: color, bold: bold, size: size, centered: centered))
        }
    }

    func printLines(_ lines: [String], color: TerminalColor = .green, size: CGFloat = 14) {
        // Pad all lines to the same width to preserve ASCII art alignment
        let maxLen = lines.map { $0.count }.max() ?? 0
        for line in lines {
            let padded = maxLen > 0 ? line.padding(toLength: maxLen, withPad: " ", startingAt: 0) : line
            print(padded, color: color, size: size)
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

    func printTitle(_ text: String, color: TerminalColor = .brightGreen) {
        let t = String(text.prefix(30))
        let border = String(repeating: "═", count: t.count + 4)
        print("╔\(border)╗", color: color, bold: true)
        print("║  \(t)  ║", color: color, bold: true)
        print("╚\(border)╝", color: color, bold: true)
        print("")
    }

    func printSubtitle(_ text: String) {
        print("--- \(text) ---", color: .cyan)
        print("")
    }

    /// Word-wrap text to fit within maxWidth characters, with optional indent
    func printWrapped(_ text: String, indent: Int = 0, color: TerminalColor = .green, bold: Bool = false, maxWidth: Int = 38) {
        // Detect any extra leading whitespace in the text and fold it into indent
        let trimmed = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        let effectiveIndent = indent + (text.count - trimmed.count)
        let prefix = String(repeating: " ", count: effectiveIndent)
        let lineWidth = maxWidth - effectiveIndent
        guard lineWidth > 10 else {
            print("\(prefix)\(trimmed)", color: color, bold: bold)
            return
        }

        let words = trimmed.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var currentLine = ""

        for word in words {
            if currentLine.isEmpty {
                currentLine = word
            } else if currentLine.count + 1 + word.count <= lineWidth {
                currentLine += " " + word
            } else {
                print("\(prefix)\(currentLine)", color: color, bold: bold)
                currentLine = word
            }
        }
        if !currentLine.isEmpty {
            print("\(prefix)\(currentLine)", color: color, bold: bold)
        }
    }

    func clearTerminal() {
        stopIdleAnimations()
        stopMenuAnimation()
        SpeechEngine.shared.stop()
        textLongPressHandler = nil
        closeHandler = nil
        rerollHandler = nil
        suppressAutoScroll = false
        scrollLocked = false
        swipeLeftHandler = nil
        swipeRightHandler = nil
        swipeRandomHandler = nil
        cardPositionLabel = nil
        menuImageName = nil
        dragonGifName = nil
        speakerHasReadCurrentPage = false
        DispatchQueue.main.async {
            self.terminalLines.removeAll()
        }
    }

    // MARK: - Screen-Scoped Undo/Redo

    /// Push a snapshot onto the undo stack for a given screen
    private func pushScreenUndo(screen: String, data: Data) {
        screenUndoStacks[screen, default: []].append(data)
        screenRedoStacks[screen] = []
    }

    private func popScreenUndo(screen: String) -> Data? {
        screenUndoStacks[screen]?.popLast()
    }

    private func popScreenRedo(screen: String) -> Data? {
        screenRedoStacks[screen]?.popLast()
    }

    private func pushScreenRedo(screen: String, data: Data) {
        screenRedoStacks[screen, default: []].append(data)
    }

    private func clearUndoRedo(for screen: String) {
        screenUndoStacks.removeValue(forKey: screen)
        screenRedoStacks.removeValue(forKey: screen)
    }

    private func clearAllUndoRedo() {
        screenUndoStacks.removeAll()
        screenRedoStacks.removeAll()
        currentUndoScreen = nil
        undoHandler = nil
        redoHandler = nil
    }

    private func screenHasUndo(_ screen: String) -> Bool {
        !(screenUndoStacks[screen]?.isEmpty ?? true)
    }

    private func screenHasRedo(_ screen: String) -> Bool {
        !(screenRedoStacks[screen]?.isEmpty ?? true)
    }

    // MARK: - Edit Undo/Redo

    private func editScreenKey(for index: Int) -> String { "editChar:\(index)" }

    /// Begin tracking edits for a character — fresh stacks each visit
    private func beginEditTracking(index: Int, inGame: Bool = true) {
        editingCharacterIndex = index
        editScreenIsInGame = inGame
        let key = editScreenKey(for: index)
        currentUndoScreen = key
        clearUndoRedo(for: key)
        updateUndoRedoHandlers(index: index)
    }

    /// End edit tracking
    private func endEditTracking() {
        if let index = editingCharacterIndex {
            clearUndoRedo(for: editScreenKey(for: index))
        }
        editingCharacterIndex = nil
        currentUndoScreen = nil
        undoHandler = nil
        redoHandler = nil
    }

    /// Push a snapshot before making changes
    private func pushEditSnapshot(index: Int) {
        guard index < party.count else { return }
        let key = editScreenKey(for: index)
        if let data = try? JSONEncoder().encode(party[index]) {
            pushScreenUndo(screen: key, data: data)
        }
        updateUndoRedoHandlers(index: index)
    }

    private func undoEdit() {
        guard let index = editingCharacterIndex, index < party.count else { return }
        let key = editScreenKey(for: index)
        guard let data = popScreenUndo(screen: key) else { return }
        if let currentData = try? JSONEncoder().encode(party[index]) {
            pushScreenRedo(screen: key, data: currentData)
        }
        if let restored = try? JSONDecoder().decode(Character.self, from: data) {
            party[index] = restored
        }
        updateUndoRedoHandlers(index: index)
        if editScreenIsInGame {
            showInGameEditCharacter(index: index)
        } else {
            showEditCharacter(index: index)
        }
    }

    private func redoEdit() {
        guard let index = editingCharacterIndex, index < party.count else { return }
        let key = editScreenKey(for: index)
        guard let data = popScreenRedo(screen: key) else { return }
        if let currentData = try? JSONEncoder().encode(party[index]) {
            pushScreenUndo(screen: key, data: currentData)
        }
        if let restored = try? JSONDecoder().decode(Character.self, from: data) {
            party[index] = restored
        }
        updateUndoRedoHandlers(index: index)
        if editScreenIsInGame {
            showInGameEditCharacter(index: index)
        } else {
            showEditCharacter(index: index)
        }
    }

    private func updateUndoRedoHandlers(index: Int) {
        let key = editScreenKey(for: index)
        undoHandler = screenHasUndo(key) ? { [weak self] in self?.undoEdit() } : nil
        redoHandler = screenHasRedo(key) ? { [weak self] in self?.redoEdit() } : nil
    }

    // MARK: - Settings Undo/Redo

    private let settingsScreenKey = "settings"

    /// Call before making any settings change to snapshot current state
    private func pushSettingsSnapshot() {
        if let data = try? JSONSerialization.data(withJSONObject: exportSettings()) {
            pushScreenUndo(screen: settingsScreenKey, data: data)
        }
    }

    private func undoSettings(refreshScreen: @escaping () -> Void) {
        guard let data = popScreenUndo(screen: settingsScreenKey) else { return }
        if let currentData = try? JSONSerialization.data(withJSONObject: exportSettings()) {
            pushScreenRedo(screen: settingsScreenKey, data: currentData)
        }
        if let snapshot = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            importSettings(snapshot)
            syncSettingsAfterRestore()
        }
        refreshScreen()
    }

    private func redoSettings(refreshScreen: @escaping () -> Void) {
        guard let data = popScreenRedo(screen: settingsScreenKey) else { return }
        if let currentData = try? JSONSerialization.data(withJSONObject: exportSettings()) {
            pushScreenUndo(screen: settingsScreenKey, data: currentData)
        }
        if let snapshot = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            importSettings(snapshot)
            syncSettingsAfterRestore()
        }
        refreshScreen()
    }

    /// Sync runtime state after restoring settings from a snapshot
    private func syncSettingsAfterRestore() {
        SoundManager.shared.battleSoundsEnabled = battleSoundsEnabled
        if musicEnabled {
            playCurrentMusic()
        } else {
            SoundManager.shared.stopMusic()
        }
    }

    /// Install undo/redo handlers for settings screens
    private func updateSettingsUndoRedo(refreshScreen: @escaping () -> Void) {
        undoHandler = screenHasUndo(settingsScreenKey) ? { [weak self] in
            self?.undoSettings(refreshScreen: refreshScreen)
        } : nil
        redoHandler = screenHasRedo(settingsScreenKey) ? { [weak self] in
            self?.redoSettings(refreshScreen: refreshScreen)
        } : nil
    }

    private func beginSettingsTracking() {
        currentUndoScreen = settingsScreenKey
        clearUndoRedo(for: settingsScreenKey)
    }

    private func endSettingsTracking() {
        clearUndoRedo(for: settingsScreenKey)
        currentUndoScreen = nil
        undoHandler = nil
        redoHandler = nil
    }

    // MARK: - Input Handling

    func showMenu(_ options: [String], defaultIndex: Int = 0) {
        menuLongPressHandler = nil
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.securedExits = []
            self.dpadCenterLabel = nil
            self.dpadCenterHandler = nil
            self.dpadCenterLongPressHandler = nil
            self.dpadNPCLabel = nil
            self.dpadNPCHandler = nil
            self.currentMenuOptions = options.enumerated().map { index, text in
                MenuOption(text, isDefault: index == defaultIndex, tint: Self.autoTint(text))
            }
            self.awaitingTextInput = false
            self.awaitingContinue = false
            self.autoReadIfSpeakerMode()
        }
    }

    func showMenuOptions(_ options: [MenuOption]) {
        menuLongPressHandler = nil
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.securedExits = []
            self.dpadCenterLabel = nil
            self.dpadCenterHandler = nil
            self.dpadCenterLongPressHandler = nil
            self.dpadNPCLabel = nil
            self.dpadNPCHandler = nil
            self.currentMenuOptions = options
            self.awaitingTextInput = false
            self.awaitingContinue = false
            self.autoReadIfSpeakerMode()
        }
    }

    // MARK: - Paginated Menu

    /// Show a paginated menu with ▸/◂ navigation when items exceed maxButtonsPerScreen.
    /// - allOptions: full list of display strings
    /// - page: current page (0-indexed)
    /// - pinned: buttons always shown on every page (e.g. "Help") — count against limit
    /// - handler: called with index into allOptions (0-based)
    func showPaginatedMenu(_ allOptions: [String], page: Int = 0,
                            pinned: [String] = [],
                            handler: @escaping (Int) -> Void) {
        let limit = maxButtonsPerScreen
        let pinnedCount = pinned.count
        let totalItems = allOptions.count

        // If everything fits, just show normally
        if totalItems + pinnedCount <= limit {
            var all = allOptions + pinned
            showMenu(all)
            menuHandler = { choice in
                let idx = choice - 1
                if idx < totalItems {
                    handler(idx)
                }
                // pinned items handled by caller via separate check
            }
            // Let caller install its own menuHandler that also handles pinned
            // Actually, provide a combined handler
            let _ = all // suppress warning
            menuHandler = { choice in
                let idx = choice - 1
                if idx < allOptions.count {
                    handler(idx)
                }
                // pinned items: caller checks choice > allOptions.count
            }
            return
        }

        let totalPages: Int
        let contentSlots: Int
        let pageStart: Int
        let pageEnd: Int

        // Calculate how many content slots we have on this page
        // Page 0: might need ▸ only. Middle pages: ◂ + ▸. Last page: ◂ only.
        let hasBack = page > 0

        // First pass: figure out total pages
        // Page 0 gets (limit - pinnedCount - 1) slots (for ▸ More)
        // Middle pages get (limit - pinnedCount - 2) slots (for ◂ + ▸)
        // Last page gets (limit - pinnedCount - 1) slots (for ◂ Back)
        let firstPageSlots = max(1, limit - pinnedCount - 1) // -1 for ▸
        let middlePageSlots = max(1, limit - pinnedCount - 2) // -2 for ◂ and ▸
        let lastPageSlots = max(1, limit - pinnedCount - 1) // -1 for ◂

        if totalItems <= firstPageSlots {
            // Shouldn't happen (we checked above), but safety
            totalPages = 1
        } else {
            var remaining = totalItems - firstPageSlots
            var pages = 1
            while remaining > lastPageSlots {
                remaining -= middlePageSlots
                pages += 1
            }
            totalPages = pages + 1
        }

        let safePage = min(page, totalPages - 1)
        let hasMore: Bool

        if safePage == 0 {
            contentSlots = firstPageSlots
            pageStart = 0
            pageEnd = min(totalItems, contentSlots)
            hasMore = totalItems > pageEnd
        } else {
            let afterFirstPage = firstPageSlots
            let middleOffset = (safePage - 1) * middlePageSlots
            pageStart = afterFirstPage + middleOffset

            if safePage == totalPages - 1 {
                // Last page
                contentSlots = lastPageSlots
                pageEnd = min(totalItems, pageStart + contentSlots)
                hasMore = false
            } else {
                contentSlots = middlePageSlots
                pageEnd = min(totalItems, pageStart + contentSlots)
                hasMore = totalItems > pageEnd
            }
        }

        // Build visible menu
        var visibleOptions: [String] = []
        var mapping: [Int] = [] // maps visible index to action

        if hasBack {
            visibleOptions.append("◂ Back")
            mapping.append(-1) // sentinel for back
        }

        for i in pageStart..<pageEnd {
            visibleOptions.append(allOptions[i])
            mapping.append(i) // index into allOptions
        }

        if hasMore {
            visibleOptions.append("▸ More")
            mapping.append(-2) // sentinel for more
        }

        // Add pinned items
        for p in pinned {
            visibleOptions.append(p)
            mapping.append(-3) // sentinel for pinned
        }

        // Build MenuOptions with tints
        let menuOpts = visibleOptions.enumerated().map { idx, text -> MenuOption in
            let m = mapping[idx]
            if m == -1 || m == -2 {
                return MenuOption(text, tint: .navigation)
            }
            return MenuOption(text, isDefault: idx == (hasBack ? 1 : 0), tint: Self.autoTint(text))
        }
        showMenuOptions(menuOpts)

        menuHandler = { [weak self] choice in
            let idx = choice - 1
            guard idx >= 0 && idx < mapping.count else { return }
            let m = mapping[idx]
            if m == -1 {
                // ◂ Back — go to previous page
                self?.showPaginatedMenu(allOptions, page: safePage - 1, pinned: pinned, handler: handler)
            } else if m == -2 {
                // ▸ More — go to next page
                self?.showPaginatedMenu(allOptions, page: safePage + 1, pinned: pinned, handler: handler)
            } else if m >= 0 {
                handler(m)
            }
            // pinned items (m == -3) are ignored here — caller handles via pinnedHandler
        }

        // Long-press on ◂/▸ jumps 3 pages
        menuLongPressHandler = { [weak self] choice in
            let idx = choice - 1
            guard idx >= 0 && idx < mapping.count else { return }
            let m = mapping[idx]
            if m == -1 {
                self?.showPaginatedMenu(allOptions, page: max(0, safePage - 3), pinned: pinned, handler: handler)
            } else if m == -2 {
                self?.showPaginatedMenu(allOptions, page: min(totalPages - 1, safePage + 3), pinned: pinned, handler: handler)
            }
        }
    }

    /// Show a paginated menu with ▸/◂ navigation for MenuOption arrays.
    /// pinnedHandler is called with the pinned item's index (0-based within pinned array).
    func showPaginatedMenuOptions(_ allOptions: [String], page: Int = 0,
                                   pinned: [String] = [],
                                   handler: @escaping (Int) -> Void,
                                   pinnedHandler: @escaping (Int) -> Void) {
        let limit = maxButtonsPerScreen
        let totalItems = allOptions.count
        let pinnedCount = pinned.count

        // If everything fits, just show normally
        if totalItems + pinnedCount <= limit {
            let all = allOptions + pinned
            showMenu(all)
            menuHandler = { choice in
                let idx = choice - 1
                if idx < allOptions.count {
                    handler(idx)
                } else {
                    pinnedHandler(idx - allOptions.count)
                }
            }
            return
        }

        // Use base paginated menu, then override handler for pinned
        showPaginatedMenu(allOptions, page: page, pinned: pinned, handler: handler)

        // Wrap the existing menuHandler to also handle pinned items
        let baseHandler = menuHandler
        menuHandler = { [weak self] choice in
            // Check if this is a pinned item
            let options = self?.currentMenuOptions ?? []
            let idx = choice - 1
            if idx >= 0 && idx < options.count {
                let text = options[idx].text
                if let pinnedIdx = pinned.firstIndex(of: text) {
                    pinnedHandler(pinnedIdx)
                    return
                }
            }
            baseHandler?(choice)
        }

        // Also wrap long press handler for pinned
        let baseLongPress = menuLongPressHandler
        menuLongPressHandler = { [weak self] choice in
            let options = self?.currentMenuOptions ?? []
            let idx = choice - 1
            if idx >= 0 && idx < options.count {
                let text = options[idx].text
                if pinned.contains(text) {
                    return // ignore long press on pinned
                }
            }
            baseLongPress?(choice)
        }
    }

    /// Auto-assign button tint based on text content
    static func autoTint(_ text: String) -> MenuTint {
        let lower = text.lowercased()
        // Navigation / back buttons
        if lower == "done" || lower.hasPrefix("done (") || lower == "< cancel"
            || lower == "cancel" || lower == "continue" || lower == "next"
            || lower == "back" || lower == "quit" || lower == "save & quit"
            || lower.hasPrefix("delete") || lower.hasPrefix("clear all")
            || lower.hasPrefix("yes, delete") || lower.hasPrefix("quit") { return .navigation }
        // Chat
        if lower == "chat" { return .cyan }
        return .normal
    }

    func showMenuWithDirections(_ options: [MenuOption], exits: [Direction: Bool]) {
        menuLongPressHandler = nil
        DispatchQueue.main.async {
            self.directionExits = exits
            self.currentMenuOptions = options
            self.awaitingTextInput = false
            self.awaitingContinue = false
            self.autoReadIfSpeakerMode()
        }
    }

    func promptText(_ prompt: String) {
        print(prompt, color: .green)
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.securedExits = []
            self.currentMenuOptions = []
            self.awaitingTextInput = true
            self.awaitingContinue = false
            self.autoReadIfSpeakerMode()
        }
    }

    /// Show both a text input prompt and menu buttons simultaneously
    func promptTextWithMenu(_ prompt: String, options: [String]) {
        print(prompt, color: .green)
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.securedExits = []
            self.currentMenuOptions = options.enumerated().map { index, text in
                MenuOption(text, isDefault: index == 0)
            }
            self.awaitingTextInput = true
            self.awaitingContinue = false
            self.autoReadIfSpeakerMode()
        }
    }

    func waitForContinue() {
        DispatchQueue.main.async {
            self.directionExits = [:]
            self.securedExits = []
            self.currentMenuOptions = []
            self.awaitingTextInput = false
            self.awaitingContinue = true
            self.autoReadIfSpeakerMode()
        }
        resetIdleTimer()
    }

    /// Wait for continue with auto-timeout — taps to continue immediately, or auto-continues after delay
    func waitForContinueWithTimeout(multiplier: Double = 2.0, action: @escaping () -> Void) {
        waitForContinue()
        let timer = Timer.scheduledTimer(withTimeInterval: infoTimeout * multiplier, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.awaitingContinue == true else { return }
                action()
            }
        }
        inputHandler = { _ in
            timer.invalidate()
            action()
        }
    }

    /// Auto-return to exploration after a delay. Sets closeHandler for manual dismiss too.
    /// Where to return after auto-timeout (nil = exploration view)
    private var autoReturnDestination: (() -> Void)?

    func autoReturn(after seconds: Double? = nil) {
        let seconds = seconds ?? infoTimeout
        let destination = autoReturnDestination ?? { [weak self] in self?.showExplorationView() }
        autoReturnDestination = nil
        closeHandler = destination
        Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.closeHandler != nil else { return }
                destination()
            }
        }
    }

    /// Print the dungeon map matching the exploration view style (radius, torch, colour)
    func printExplorationMap() {
        guard let dungeon = dungeon else { return }
        let (radius, verticalRadius, compact) = bestMapRadius()
        let mapLines = dungeon.getMapDisplay(visibilityRadius: radius, torchLit: torchLit, compact: compact, verticalRadius: verticalRadius)
        printLines(mapLines, color: torchMapColor, size: mapFontSize)
    }

    /// Fixed-width card position label, e.g. " 3/30" always same length as "30/30"
    private func cardLabel(_ current: Int, of total: Int) -> String {
        let totalStr = "\(total)"
        let currentStr = "\(current)".padding(toLength: totalStr.count, withPad: " ", startingAt: 0)
        return "\(currentStr)/\(totalStr)"
    }

    func handleMenuChoice(_ choice: Int) {
        stopIdleAnimations()
        // Suppress taps briefly after a long-press screen transition
        guard Date() > suppressMenuUntil else { return }

        // Ignore stale taps from a previous menu (e.g. finger-up after long-press
        // where the old menu had more options than the new one)
        guard choice >= 1 && choice <= currentMenuOptions.count else { return }

        if let handler = menuHandler {
            handler(choice)
        }

        // Clear pressed state after handler runs (handler sets new menu)
        DispatchQueue.main.async {
            self.pressedMenuIndex = nil
        }
    }

    private var suppressMenuUntil: Date = .distantPast

    func handleMenuLongPress(_ choice: Int) {
        stopIdleAnimations()

        // Long-press on disabled buttons = dark/forced actions
        if choice >= 1 && choice <= currentMenuOptions.count {
            let option = currentMenuOptions[choice - 1]
            if option.isDisabled && !torchLit {
                switch option.text {
                case "Search Room": darkSearch(); return
                case "Scavenge": searchRoom(); return
                default: break
                }
            }
        }

        // Long-press on "Done" during active gameplay = return directly to game view
        if choice >= 1 && choice <= currentMenuOptions.count {
            let optionText = currentMenuOptions[choice - 1].text
            if optionText == "Done" && (gameState == .exploring || gameState == .combat) && dungeon != nil {
                DispatchQueue.main.async {
                    self.currentMenuOptions = []
                    self.directionExits = [:]
            self.securedExits = []
                }
                suppressMenuUntil = Date().addingTimeInterval(0.5)
                if gameState == .combat, currentCombat != nil {
                    advanceCombat()
                } else {
                    showExplorationView()
                }
                return
            }
        }

        if let handler = menuLongPressHandler {
            DispatchQueue.main.async {
                self.currentMenuOptions = []
                self.directionExits = [:]
                self.securedExits = []
            }
            handler(choice)
            suppressMenuUntil = Date().addingTimeInterval(0.8)
        } else if let handler = menuHandler {
            DispatchQueue.main.async {
                self.currentMenuOptions = []
                self.directionExits = [:]
            self.securedExits = []
            }
            // Fall back to normal handler if no long-press handler
            handler(choice)
        }
        // If no handler at all, do nothing — don't clear the menu
    }

    /// Match a voice transcript against current menu options and select the best match
    func handleVoiceMenuChoice(_ transcript: String) {
        let lower = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return }

        // "done", "back", "return", "close", "go back", "b", "d" → trigger close handler or emergency exit
        let backWords: Set<String> = ["done", "back", "return", "close", "go back", "exit", "cancel", "b", "d"]
        if backWords.contains(lower) || lower.hasSuffix(" back") || lower.hasSuffix(" return") {
            if let handler = closeHandler {
                print("\"\(transcript)\" -> Back", color: .dimGreen)
                handler()
                return
            }
            // Fallback: on victory/defeat/combat, exit even without closeHandler
            if gameState == .victory || gameState == .gameOver || gameState == .combat {
                print("\"\(transcript)\" -> Back", color: .dimGreen)
                emergencyExit()
                return
            }
        }

        // "continue", "next", "ok", "okay" → tap to continue (inputHandler when waiting)
        let continueWords: Set<String> = ["continue", "next", "ok", "okay", "yes", "carry on"]
        if continueWords.contains(lower) {
            if let handler = inputHandler {
                print("\"\(transcript)\" -> Continue", color: .dimGreen)
                handler("")
                inputHandler = nil
                return
            }
        }

        let options = currentMenuOptions
        guard !options.isEmpty else {
            // No menu options — route to DM if available
            let dm = DMEngine.shared
            if dm.isConfigured || dm.isAppleModelAvailable {
                print("")
                print("  The DM considers...", color: .dimGreen)
                let context = buildDMContext()
                dm.ask(transcript, context: context) { [weak self] response in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.print("")
                        self.print("  DM:", color: .yellow, bold: true)
                        for paragraph in response.components(separatedBy: "\n") {
                            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                            if trimmed.isEmpty { self.print("") }
                            else { self.printWrapped("  \(trimmed)", indent: 2, color: .yellow) }
                        }
                    }
                }
            } else {
                let dmResponse = dmFallbackResponse(for: lower)
                print("")
                print("  The DM says:", color: .yellow, bold: true)
                printWrapped("  \"\(dmResponse)\"", indent: 2, color: .yellow)
            }
            return
        }

        // Helper to show visual press feedback, then trigger button after a short delay
        func selectButton(_ index: Int) {
            let opt = options[index - 1]
            self.print("\"\(transcript)\" -> \(opt.text)", color: .dimGreen)
            // Animate the button press visually
            DispatchQueue.main.async {
                self.pressedMenuIndex = index
            }
            // Delay to let the user see the press, then fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.pressedMenuIndex = nil
                self?.handleMenuChoice(index)
            }
        }

        // Number matching: "one", "button one", "number one", "first", "1" etc.
        let numberWords: [String: Int] = [
            "one": 1, "1": 1, "first": 1, "button one": 1, "number one": 1, "option one": 1,
            "two": 2, "2": 2, "second": 2, "button two": 2, "number two": 2, "option two": 2,
            "three": 3, "3": 3, "third": 3, "button three": 3, "number three": 3, "option three": 3,
            "four": 4, "4": 4, "fourth": 4, "button four": 4, "number four": 4, "option four": 4,
            "five": 5, "5": 5, "fifth": 5, "button five": 5, "number five": 5, "option five": 5,
            "six": 6, "6": 6, "sixth": 6, "button six": 6, "number six": 6, "option six": 6,
            "seven": 7, "7": 7, "seventh": 7, "button seven": 7, "number seven": 7, "option seven": 7,
            "eight": 8, "8": 8, "eighth": 8, "button eight": 8, "number eight": 8, "option eight": 8,
            "nine": 9, "9": 9, "ninth": 9, "button nine": 9, "number nine": 9, "option nine": 9,
            "ten": 10, "10": 10, "tenth": 10, "button ten": 10, "number ten": 10, "option ten": 10,
        ]
        if let num = numberWords[lower], num >= 1 && num <= options.count {
            if !options[num - 1].isDisabled {
                selectButton(num)
                return
            }
        }

        // Level 1: exact match
        for (i, opt) in options.enumerated() where !opt.isDisabled {
            if opt.text.lowercased() == lower {
                selectButton(i + 1)
                return
            }
        }
        // Level 2: option starts with transcript
        for (i, opt) in options.enumerated() where !opt.isDisabled {
            if opt.text.lowercased().hasPrefix(lower) {
                selectButton(i + 1)
                return
            }
        }
        // Level 3: transcript contains option name
        for (i, opt) in options.enumerated() where !opt.isDisabled {
            if lower.contains(opt.text.lowercased()) {
                selectButton(i + 1)
                return
            }
        }
        // Level 4: option contains transcript
        for (i, opt) in options.enumerated() where !opt.isDisabled {
            if opt.text.lowercased().contains(lower) {
                selectButton(i + 1)
                return
            }
        }
        // No button match — if awaiting text input, confirm before submitting
        if awaitingTextInput, let handler = inputHandler {
            print("")
            print("  Heard: \"\(transcript)\"", color: .yellow, bold: true)
            print("")
            showMenu(["Confirm", "Try Again"])
            menuHandler = { [weak self] choice in
                guard let self = self else { return }
                if choice == 1 {
                    DispatchQueue.main.async { self.awaitingTextInput = false }
                    handler(transcript)
                } else {
                    // Restore text input mode so user can try again
                    DispatchQueue.main.async { self.awaitingTextInput = true }
                }
            }
            return
        }

        // No match — in combat, redirect to chat with the message
        if gameState == .combat {
            showPartyChat(initialMessage: transcript)
            return
        }

        // If DM engine is available, give a real AI response; otherwise canned fallback
        let dm = DMEngine.shared
        if dm.isConfigured || dm.isAppleModelAvailable {
            print("")
            print("  The DM considers...", color: .dimGreen)
            let context = buildDMContext()
            dm.ask(transcript, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.print("")
                    self.print("  DM:", color: .yellow, bold: true)
                    for paragraph in response.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { self.print("") }
                        else { self.printWrapped("  \(trimmed)", indent: 2, color: .yellow) }
                    }
                    if self.speakerModeOn {
                        SpeechEngine.shared.speak(response)
                        self.speakerHasReadCurrentPage = true
                    }
                }
            }
        } else {
            let dmResponse = dmFallbackResponse(for: lower)
            print("")
            print("  The DM says:", color: .yellow, bold: true)
            printWrapped("  \"\(dmResponse)\"", indent: 2, color: .yellow)
        }
    }

    /// Provide a helpful DM-style response for unmatched text input
    private func dmFallbackResponse(for input: String) -> String {
        // Navigation / exit words
        let navWords: Set<String> = ["done", "back", "return", "close", "exit", "cancel", "go back",
                                      "leave", "quit", "stop", "end", "escape", "flee", "run"]
        if navWords.contains(input) || input.hasSuffix(" back") || input.hasSuffix(" return") {
            let responses = [
                "There is nowhere to go right now. Choose from the options before you.",
                "The path behind you has closed. You must press on — use the buttons below.",
                "You cannot leave yet. Your choices lie before you, adventurer.",
            ]
            return responses.randomElement()!
        }

        // Help / confused
        let helpWords: Set<String> = ["help", "what", "huh", "how", "where", "why", "who", "?"]
        if helpWords.contains(input) || input.hasPrefix("what ") || input.hasPrefix("how ") || input.hasPrefix("where ") {
            return "Look to the buttons below — they show your available actions. Tap one to proceed."
        }

        // Greetings
        let greetWords: Set<String> = ["hello", "hi", "hey", "greetings", "yo", "sup"]
        if greetWords.contains(input) {
            let responses = [
                "Well met, adventurer. Now choose your next action from the options below.",
                "Greetings. The dungeon waits for no one — make your choice.",
                "Hail! Your options lie before you. Choose wisely.",
            ]
            return responses.randomElement()!
        }

        // Yes / No / Agree
        if input == "yes" || input == "no" || input == "ok" || input == "okay" || input == "sure" || input == "fine" {
            return "Noted. But I need you to choose one of the options below to continue."
        }

        // Inventory / status queries
        let statusWords: Set<String> = ["inventory", "stats", "status", "health", "hp", "gold", "map", "items", "gear", "equipment"]
        if statusWords.contains(input) {
            return "Use the Party Status button during exploration to check your party's condition, or open your Inventory."
        }

        // Attack / fight
        let fightWords: Set<String> = ["attack", "fight", "hit", "strike", "kill", "slay", "smash", "stab", "slash"]
        if fightWords.contains(input) || input.hasPrefix("attack ") || input.hasPrefix("kill ") {
            if gameState == .exploring {
                return "There is nothing to fight here. Explore the dungeon to find monsters — they will find you soon enough."
            }
            return "Eager for blood? Choose your action from the options below."
        }

        // Rest / heal
        let restWords: Set<String> = ["rest", "sleep", "heal", "camp", "recover"]
        if restWords.contains(input) {
            if gameState == .exploring {
                return "To rest, use the Rest button in the centre of the compass. Short rests heal hit dice; long rests restore the party fully."
            }
            return "Now is not the time for rest. Focus on your current situation."
        }

        // Default — flavourful catchall
        let defaults = [
            "I don't understand '\(input)'. Choose from the options shown below.",
            "The dungeon does not respond to '\(input)'. Your choices are shown below — pick one.",
            "'\(input.capitalized)'? That means nothing here. Use the buttons below, adventurer.",
            "Even the wisest DM cannot parse '\(input)'. Try the buttons instead.",
            "The ancient runes do not recognise '\(input)'. Your path forward lies in the buttons below.",
        ]
        return defaults.randomElement()!
    }

    /// Read all visible terminal text aloud via SpeechEngine
    /// - Single tap while speaking: pause. Single tap while paused: resume.
    /// - Rapid double-tap: restart from beginning.
    /// - Single tap while silent: start reading.
    func readScreenAloud() {
        let speech = SpeechEngine.shared
        guard speech.isAvailable else { return }

        // Toggle persistent speaker mode
        if speakerModeOn {
            // Turn off entirely
            speakerModeOn = false
            speakerPaused = false
            speech.stop()
            isSpeakingAloud = false
            speakingCheckTimer?.invalidate()
            speakingCheckTimer = nil
            recentlySpokenTexts.removeAll()
            return
        }

        // Turn on — read current screen and stay in mode
        speakerModeOn = true
        speakerPaused = false
        startReadingScreen()
    }

    /// Long-press: pause reading on this page, but re-engage on next screen change
    func pauseSpeaker() {
        guard speakerModeOn else { return }
        let speech = SpeechEngine.shared
        speech.stop()
        isSpeakingAloud = false
        speakerPaused = true
        speakingCheckTimer?.invalidate()
        speakingCheckTimer = nil
    }

    /// Auto-read the screen when speaker mode is on (call after screen changes)
    func autoReadIfSpeakerMode() {
        guard speakerModeOn else { return }
        // Only read once per page — skip if already read
        guard !speakerHasReadCurrentPage else { return }
        // Un-pause on screen change (clearTerminal resets both flags)
        speakerPaused = false
        let speech = SpeechEngine.shared
        speech.stop()
        // Small delay so terminal lines are populated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.speakerPaused, !self.speakerHasReadCurrentPage else { return }
            self.startReadingScreen()
        }
    }

    private func startReadingScreen() {
        let speech = SpeechEngine.shared
        let allLines = gatherScreenLines()
        // Filter out lines recently spoken (NPC greetings, repeated descriptions)
        let newLines = allLines.filter { line in
            !recentlySpokenTexts.contains(line)
        }
        guard !newLines.isEmpty else {
            speakerHasReadCurrentPage = true
            return
        }
        // Add new lines to the memory buffer (circular, max 10)
        for line in newLines {
            recentlySpokenTexts.append(line)
        }
        if recentlySpokenTexts.count > maxSpokenMemory {
            recentlySpokenTexts.removeFirst(recentlySpokenTexts.count - maxSpokenMemory)
        }
        let text = newLines.joined(separator: ". ")
        speakerHasReadCurrentPage = true
        speech.speakAloud(text)
        isSpeakingAloud = true
        startSpeakingCheck()
    }

    private func startSpeakingCheck() {
        speakingCheckTimer?.invalidate()
        speakingCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let speech = SpeechEngine.shared
                if !speech.isSpeaking && !speech.isPaused {
                    self.isSpeakingAloud = false
                    self.speakingCheckTimer?.invalidate()
                    self.speakingCheckTimer = nil
                    // Do NOT turn off speakerModeOn — it stays on
                }
            }
        }
    }

    /// Gather readable narrative text from the terminal, filtering out ASCII art, stats, and lists
    private func gatherScreenText() -> String {
        return gatherScreenLines().joined(separator: ". ")
    }

    /// Gather readable narrative lines from the terminal
    private func gatherScreenLines() -> [String] {
        // Extended set of art/decoration characters including block elements
        let artStr = "/\\|_+=#~<>^{}()[].:;*`\"─╔╗╠╣╚╝║✦✧★☆✓·▸☠☢█░▓▄▀▌▐▲▼◆◇●○■□▪▫◈◊♦♠♣♥⚔⚗⚡⚰⛊⛏☽☾⊕⊘⊗┌┐└┘├┤┬┴┼━┃╭╮╯╰"
        // HP/score pattern: digits/digits like "12/20"
        let hpPattern = try? NSRegularExpression(pattern: "\\d+/\\d+")
        let lines = terminalLines.compactMap { line -> String? in
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            // Lines containing quoted speech are always readable
            let hasQuote = trimmed.contains("\"") || trimmed.contains("\u{201C}") || trimmed.contains("\u{201D}")

            // Only read narrative/informative colours
            // Skip: dimGreen (nav hints), gray (decorative), red (damage numbers)
            if !hasQuote {
                switch line.color {
                case .yellow, .white, .green, .brightGreen, .cyan, .orange, .magenta:
                    break  // these can contain readable content
                case .dimGreen, .gray, .red:
                    return nil
                }
            }

            // Skip NPC name labels (bold brightGreen short lines like "  Hermit")
            if line.color == .brightGreen && line.isBold && trimmed.count < 25 {
                return nil
            }

            // Skip very short non-word lines (decorative elements)
            if trimmed.count <= 3 && !trimmed.contains(where: { $0.isLetter }) {
                return nil
            }

            // Skip lines that are mostly ASCII art/decoration (>25% special chars)
            let specialCount = trimmed.filter { artStr.contains($0) }.count
            if trimmed.count > 2 && Double(specialCount) / Double(trimmed.count) > 0.25 {
                return nil
            }

            // Skip lines with no readable text
            let letterCount = trimmed.filter { $0.isLetter }.count
            if letterCount == 0 { return nil }
            // Lines need at least 50% letters to be narrative (filters stat lines)
            if trimmed.count > 5 && Double(letterCount) / Double(trimmed.count) < 0.5 {
                return nil
            }

            // Skip table/stat lines containing HP-style "X/Y" patterns with padded spacing
            if let regex = hpPattern {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    // Only skip if it looks like a status line (has padding/alignment)
                    if trimmed.contains("  ") { return nil }
                }
            }

            // Skip table-like lines (mostly dashes/pipes)
            let dashCount = trimmed.filter { $0 == "-" || $0 == "─" || $0 == "|" || $0 == "║" }.count
            if trimmed.count > 5 && Double(dashCount) / Double(trimmed.count) > 0.25 {
                return nil
            }

            // Strip remaining decorative characters but keep readable content
            var cleaned = trimmed.filter { char in
                char.isLetter || char.isNumber || char.isWhitespace ||
                char == "," || char == "." || char == "!" || char == "?" ||
                char == ":" || char == ";" || char == "'" || char == "\"" || char == "-" ||
                char == "(" || char == ")" || char == "/" || char == "%" ||
                char == "+" || char == "&"
            }.trimmingCharacters(in: .whitespaces)

            // Expand common abbreviations for natural speech
            cleaned = cleaned
                .replacingOccurrences(of: "HP ", with: "hit points ")
                .replacingOccurrences(of: "HP:", with: "hit points:")
                .replacingOccurrences(of: "AC ", with: "armour class ")
                .replacingOccurrences(of: "AC:", with: "armour class:")
                .replacingOccurrences(of: "ATK:", with: "attack bonus:")
                .replacingOccurrences(of: "DMG:", with: "damage:")
                .replacingOccurrences(of: "CR:", with: "challenge rating:")
                .replacingOccurrences(of: "XP ", with: "experience ")
                .replacingOccurrences(of: "XP:", with: "experience:")
                .replacingOccurrences(of: "STR", with: "strength")
                .replacingOccurrences(of: "DEX", with: "dexterity")
                .replacingOccurrences(of: "CON", with: "constitution")
                .replacingOccurrences(of: "INT", with: "intelligence")
                .replacingOccurrences(of: "WIS", with: "wisdom")
                .replacingOccurrences(of: "CHA", with: "charisma")
                .replacingOccurrences(of: "DM ", with: "dungeon master ")
                .replacingOccurrences(of: "NPC", with: "non-player character")
                .replacingOccurrences(of: "Prof", with: "proficiency")
                .replacingOccurrences(of: "vs ", with: "versus ")
                .replacingOccurrences(of: "d20", with: "dee twenty")
                .replacingOccurrences(of: "d12", with: "dee twelve")
                .replacingOccurrences(of: "d10", with: "dee ten")
                .replacingOccurrences(of: "d8", with: "dee eight")
                .replacingOccurrences(of: "d6", with: "dee six")
                .replacingOccurrences(of: "d4", with: "dee four")
                .replacingOccurrences(of: "1d", with: "one dee ")
                .replacingOccurrences(of: "2d", with: "two dee ")
                .replacingOccurrences(of: "3d", with: "three dee ")
                .replacingOccurrences(of: "4d", with: "four dee ")
                .replacingOccurrences(of: " ft", with: " feet")
                .replacingOccurrences(of: " GP", with: " gold pieces")
                .replacingOccurrences(of: " gp", with: " gold pieces")
                .replacingOccurrences(of: "gatekeeper", with: "gate keeper")
                .replacingOccurrences(of: "Gatekeeper", with: "Gate Keeper")
                .replacingOccurrences(of: "Choose", with: "Chooze")

            return cleaned.isEmpty ? nil : cleaned
        }
        return lines
    }

    func handleDirectionChoice(_ direction: Direction) {
        stopIdleAnimations()
        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.directionExits = [:]
            self.securedExits = []
        }

        if let handler = directionHandler {
            handler(direction)
        }
    }

    func handleTextInput(_ text: String) {
        stopIdleAnimations()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep keyboard open in chat mode; dismiss otherwise
        if !chatInputMode {
            DispatchQueue.main.async {
                self.awaitingTextInput = false
            }
        }
        print("> \(trimmed)", color: .dimGreen)

        if let handler = inputHandler {
            handler(trimmed)
        } else if !currentMenuOptions.isEmpty {
            // Route text input to menu matching when on a menu screen
            handleVoiceMenuChoice(trimmed)
        }
    }

    func handleContinue() {
        guard awaitingContinue else { return }
        awaitingContinue = false
        stopIdleAnimations()
        if let handler = inputHandler {
            inputHandler = nil
            handler("")
        }
    }

    // MARK: - Idle Animations

    private var idleTimer: Timer?
    private var idleAnimTimer: Timer?
    private var idleOriginals: [(index: Int, text: String)] = []

    /// Eye patterns and their wink/blink replacements (tried in order, first match wins)
    private static let eyePatterns: [(find: String, winkL: String, winkR: String, blink: String)] = [
        // Wide-spaced eyes
        ("o   o", "-   o", "o   -", "-   -"),
        ("O   O", "-   O", "O   -", "-   -"),
        ("x   x", "-   x", "x   -", "-   -"),
        (".   .", "-   .", ".   -", "-   -"),
        // Medium-spaced
        ("O  O",  "-  O",  "O  -",  "-  -"),
        ("o  o",  "-  o",  "o  -",  "-  -"),
        ("@  @",  "-  @",  "@  -",  "-  -"),
        // Dotted/underscored
        ("o.o", "-.o", "o.-", "-.-"),
        ("o_o", "-_o", "o_-", "-_-"),
        // Close eyes
        ("o o", "- o", "o -", "- -"),
        ("oo",  "-o",  "o-",  "--"),
        ("OO",  "-O",  "O-",  "--"),
        // Special
        ("><",  ">-",  "-<",  "--"),
        ("( O )", "( - )", "( - )", "( - )"),
        ("(@::@)", "(-::@)", "(@::-)", "(-::-)"),
    ]

    func resetIdleTimer() {
        idleTimer?.invalidate()
        revertIdleLines()
        idleAnimTimer?.invalidate()
        idleAnimTimer = nil

        guard idlePromptsEnabled else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.startIdleAnimations()
        }
    }

    private func startIdleAnimations() {
        idleAnimTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.playIdleAnimation()
        }
        playIdleAnimation()
    }

    private func playIdleAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Revert any previous animation
            self.revertIdleLines()

            // Find lines with eye patterns (skip short patterns inside words)
            var candidates: [Int] = []
            for (i, line) in self.terminalLines.enumerated() {
                if Self.eyePatterns.contains(where: {
                    line.text.contains($0.find) && self.isPatternInAsciiArt(line.text, pattern: $0.find)
                }) {
                    candidates.append(i)
                }
            }
            guard let idx = candidates.randomElement() else { return }

            let original = self.terminalLines[idx].text
            if let animated = self.idleTransform(original) {
                self.idleOriginals.append((index: idx, text: original))
                self.terminalLines[idx].text = animated
            }
        }
    }

    /// Check if a pattern match is safe to animate (not inside a normal word)
    private func isPatternInAsciiArt(_ text: String, pattern: String) -> Bool {
        // Short patterns like "oo", "OO" can match inside words — only allow
        // if not surrounded by letters (i.e., the match is in ASCII art context)
        guard pattern.count <= 2 else { return true }  // Longer patterns are fine
        guard let range = text.range(of: pattern) else { return false }

        let before: Swift.Character = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : " "
        let after: Swift.Character = range.upperBound < text.endIndex ? text[range.upperBound] : " "
        if before.isLetter || after.isLetter { return false }
        // Skip lines that are mostly text (not ASCII art)
        let letterCount = text.filter { $0.isLetter }.count
        if letterCount > text.count / 2 { return false }
        return true
    }

    private func idleTransform(_ text: String) -> String? {
        for pattern in Self.eyePatterns {
            if text.contains(pattern.find) && isPatternInAsciiArt(text, pattern: pattern.find) {
                let doBlink = Int.random(in: 1...10) <= 3  // 30% blink
                if doBlink {
                    return text.replacingOccurrences(of: pattern.find, with: pattern.blink)
                } else {
                    let wink = Bool.random() ? pattern.winkL : pattern.winkR
                    return text.replacingOccurrences(of: pattern.find, with: wink)
                }
            }
        }
        return nil
    }

    private func revertIdleLines() {
        for saved in idleOriginals {
            if saved.index < terminalLines.count {
                terminalLines[saved.index].text = saved.text
            }
        }
        idleOriginals.removeAll()
    }

    func stopIdleAnimations() {
        idleTimer?.invalidate()
        idleTimer = nil
        idleAnimTimer?.invalidate()
        idleAnimTimer = nil
        revertIdleLines()
    }

    // MARK: - Game Start

    func startGame() {
        GameCenterManager.shared.authenticatePlayer()
        GameCenterManager.shared.turnBasedDelegate = self
        HallOfFameManager.shared.seedIfEmpty()
        // Sync sound settings from UserDefaults
        SoundManager.shared.battleSoundsEnabled = battleSoundsEnabled
        clearTerminal()
        showMainMenu()
    }

    // MARK: - Main Menu

    func showMainMenu() {
        gameState = .mainMenu
        if self.musicEnabled { SoundManager.shared.startMusic(.menu, preference: self.menuMelodyChoice) }

        renderMainMenu()

        // Async check for pending multiplayer invites — refresh menu if found
        if multiplayerEnabled && GameCenterManager.shared.isAuthenticated {
            checkForPendingInvites()
            // Re-check periodically while on main menu (Game Center events are unreliable)
            startInvitePollTimer()
        }
    }

    // MARK: - Main Menu Animation

    private var menuAnimTimer: Timer?

    private func stopMenuAnimation() {
        menuAnimTimer?.invalidate()
        menuAnimTimer = nil
    }

    private func renderMainMenu() {
        clearTerminal()
        stopMenuAnimation()
        print("")
        print("")
        print("D&D 5e ASCII Adventure", color: .brightGreen, bold: true, centered: true)
        print("A text-based role-playing game", color: .dimGreen, centered: true)
        print("")

        // Dragon mascot — animated GIF (positioned ~1/3 down screen)
        DispatchQueue.main.async {
            self.dragonGifName = "dragon_castle"
        }
        print("")

        let hasActiveGame = dungeon != nil && !party.isEmpty

        // Build menu dynamically based on settings
        var menuOptions: [MenuOption] = []
        var actions: [() -> Void] = []

        if hasActiveGame {
            menuOptions.append(MenuOption("Continue Quest"))
            actions.append { [weak self] in self?.showExplorationView() }
        }
        menuOptions.append(MenuOption("Play"))
        actions.append { [weak self] in self?.showPlayMenu() }

        // Show flashing Requests button when there's a pending invite
        if pendingInviteMatch != nil {
            menuOptions.append(MenuOption("Requests", isAlert: true, tint: .cyan))
            actions.append { [weak self] in
                guard let self = self, let match = self.pendingInviteMatch else { return }
                self.stopInvitePollTimer()
                GameCenterManager.shared.currentMatch = match
                self.showIncomingTurnPrompt(match: match)
            }
        }

        menuOptions.append(MenuOption("Hall of Fame"))
        actions.append { [weak self] in self?.showHallOfFame() }
        menuOptions.append(MenuOption("How to Play"))
        actions.append { [weak self] in self?.showHowToPlay() }
        menuOptions.append(MenuOption("Settings"))
        actions.append { [weak self] in self?.showSettings() }

        showMenuOptions(menuOptions)

        closeHandler = { [weak self] in self?.quitApp() }
        menuHandler = { choice in
            guard choice >= 1 && choice <= actions.count else { return }
            actions[choice - 1]()
        }
    }

    private func startInvitePollTimer() {
        stopInvitePollTimer()
        invitePollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.gameState == .mainMenu else {
                self?.stopInvitePollTimer()
                return
            }
            self.checkForPendingInvites()
        }
    }

    private func stopInvitePollTimer() {
        invitePollTimer?.invalidate()
        invitePollTimer = nil
    }

    /// Check Game Center for pending invites and refresh main menu with "Game Invite!" button
    private func checkForPendingInvites() {
        Task {
            guard let matches = try? await GKTurnBasedMatch.loadMatches() else { return }

            // Find matches that need our attention
            let myID = GKLocalPlayer.local.gamePlayerID
            let invites = matches.filter { match in
                // Pending invite we haven't accepted yet
                if match.status == .matching { return true }
                // Any open match where our slot needs confirmation (regardless of whose turn it is)
                guard match.status == .open,
                      let data = match.matchData, !data.isEmpty else { return false }
                if let state = try? MultiplayerMatchState.decoded(from: data) {
                    let mySlot = state.players.first(where: { $0.gamePlayerID == myID })
                    if mySlot?.needsConfirmation == true { return true }
                    // Catch pending_N slots — the host created the match before we joined
                    let hasPendingSlot = state.players.contains(where: { $0.gamePlayerID.hasPrefix("pending_") && $0.needsConfirmation })
                    if hasPendingSlot && state.phase == .characterCreation { return true }
                    // Also catch matches where we need to create a character
                    if mySlot == nil && state.phase == .characterCreation { return true }
                }
                return false
            }

            guard let firstInvite = invites.first else { return }

            await MainActor.run { [weak self] in
                guard let self = self else { return }

                // If not on the main menu, cache the invite for later
                guard self.gameState == .mainMenu else {
                    self.pendingInviteMatch = firstInvite
                    return
                }

                // If this is a brand new invite we haven't shown yet, go straight to the prompt
                if self.pendingInviteMatch?.matchID != firstInvite.matchID {
                    self.pendingInviteMatch = firstInvite
                    self.stopInvitePollTimer()
                    SoundManager.shared.playMultiplayerNotification()
                    GameCenterManager.shared.currentMatch = firstInvite
                    self.showIncomingTurnPrompt(match: firstInvite)
                    return
                }

                // Already seen this invite — just ensure Requests button is showing
                self.pendingInviteMatch = firstInvite
                self.renderMainMenu()
            }
        }
    }

    // MARK: - Unified Play Menu

    private enum PlayEntry {
        case newGame
        case localSave(SaveSlot)
        case multiplayerMatch(GKTurnBasedMatch, info: String, status: String)
    }

    private func showPlayMenu() {
        clearAllUndoRedo()
        clearTerminal()
        printTitle("Play")

        // Load local saves immediately
        let localSlots = SaveGameManager.shared.listSlots()

        // Show local saves while loading multiplayer
        renderPlayMenu(localSlots: localSlots, mpMatches: nil, loading: multiplayerEnabled && GameCenterManager.shared.isAuthenticated)

        // Load multiplayer matches async
        if multiplayerEnabled && GameCenterManager.shared.isAuthenticated {
            Task {
                let matches = (try? await GameCenterManager.shared.loadMatches()) ?? []
                let activeMatches = matches.filter { $0.status == .open || $0.status == .matching }
                await MainActor.run { [weak self] in
                    self?.renderPlayMenu(localSlots: localSlots, mpMatches: activeMatches, loading: false)
                }
            }
        }
    }

    private func renderPlayMenu(localSlots: [SaveSlot], mpMatches: [GKTurnBasedMatch]?, loading: Bool) {
        clearTerminal()
        printTitle("Play")

        // Summary info
        print("  1. New Adventure", color: .brightGreen, bold: true)
        print("     Long-press for quick start", color: .dimGreen)
        print("")

        if !localSlots.isEmpty {
            print("  2. Saved Adventure\(localSlots.count == 1 ? "" : "s") (\(localSlots.count))", color: .dimGreen)
            print("")
        }

        // Show multiplayer matches
        var mpEntries: [(match: GKTurnBasedMatch, info: String, status: String)] = []
        if let matches = mpMatches {
            for match in matches {
                let status: String
                if match.status == .matching {
                    status = "invite"
                } else if match.currentParticipant?.player == GKLocalPlayer.local {
                    status = "your turn"
                } else {
                    status = "waiting"
                }
                var info = ""
                if let data = match.matchData, !data.isEmpty,
                   let state = try? MultiplayerMatchState.decoded(from: data) {
                    info = "\(state.dungeon.name) (Lv\(state.dungeonLevel))"
                }
                mpEntries.append((match: match, info: info, status: status))

                let names = match.participants.compactMap { $0.player?.displayName }
                let playerStr = names.isEmpty ? "Multiplayer" : names.joined(separator: ", ")
                let statusColor: TerminalColor = status == "your turn" ? .brightGreen : (status == "invite" ? .yellow : .dimGreen)
                print("  \(playerStr)", color: .cyan, bold: status == "your turn" || status == "invite")
                if !info.isEmpty {
                    print("     \(info)", color: .dimGreen)
                }
                print("     [\(status)]", color: statusColor)
                print("")
            }
        }

        if loading {
            print("  Loading multiplayer...", color: .dimGreen)
            print("")
        }

        if multiplayerEnabled {
            print("  Remote players: set up in New Adventure", color: .dimGreen)
            print("  or change AI→Remote in Party Status.", color: .dimGreen)
            print("")
        }

        // Build menu buttons: New Adventure, multiplayer matches, Load Saves, Manage Saves, Help
        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        menuOpts.append(MenuOption("New Adventure", isDefault: true))
        actions.append { [weak self] in self?.startNewGame() }

        // Multiplayer match buttons
        for mp in mpEntries {
            let names = mp.match.participants.compactMap { $0.player?.displayName }
            let label = names.isEmpty ? "Multiplayer" : names.prefix(2).joined(separator: ", ")
            let isInvite = mp.status == "invite"
            menuOpts.append(MenuOption(label, isAlert: isInvite, tint: .cyan))
            let match = mp.match
            actions.append { [weak self] in
                GameCenterManager.shared.currentMatch = match
                self?.loadMultiplayerMatch(match)
            }
        }

        if !localSlots.isEmpty {
            menuOpts.append(MenuOption("Continue Quest"))
            actions.append { [weak self] in self?.showLoadGameMenu(returnTo: .mainMenu) }

            menuOpts.append(MenuOption("Manage Saves"))
            actions.append { [weak self] in self?.showManageSavesMenu(returnTo: .mainMenu) }
        }

        menuOpts.append(MenuOption("Help", tint: .navigation))
        actions.append { [weak self] in self?.showPlayHelp() }

        showMenuOptions(menuOpts)

        closeHandler = { [weak self] in
            self?.clearTerminal()
            self?.showMainMenu()
        }
        menuHandler = { choice in
            guard choice >= 1 && choice <= actions.count else { return }
            actions[choice - 1]()
        }

        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            // Long-press New Adventure → quick start
            if choice == 1 {
                self.createRandomParty(count: 2, allAI: true)
            }
        }
    }

    private func showPlayHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Play Menu Help")
        print("")
        print("  NEW ADVENTURE", color: .cyan, bold: true)
        printWrapped("Start a fresh adventure. Create your party, choose a dungeon, and begin exploring. Long-press for a quick start with a random party.", indent: 2, color: .dimGreen)
        print("")
        print("  LOAD SAVES", color: .cyan, bold: true)
        printWrapped("Browse your saved adventures with full details — party members, dungeon level, game time, and save dates. Tap to load, or long-press a save to load the latest instantly.", indent: 2, color: .dimGreen)
        print("")
        print("  MANAGE SAVES", color: .cyan, bold: true)
        printWrapped("Delete old saves or manage cloud saves. Each adventure can have multiple save points (breakpoints) that you can return to.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showPlayMenu() }
    }

    private func confirmDeleteSlot(_ slot: SaveSlot) {
        clearTerminal()
        printTitle("Delete Save?")
        print("This will delete all saves for:", color: .red)
        print("  \(slot.slotName)", color: .brightGreen)
        if slot.breakpointCount > 1 {
            print("  (\(slot.breakpointCount) saves)", color: .dimGreen)
        }
        print("")
        showMenu(["Yes, Delete", "< Cancel"], defaultIndex: 1)
        menuHandler = { [weak self] choice in
            if choice == 1 {
                let saves = SaveGameManager.shared.listBreakpoints(slotId: slot.slotId)
                for save in saves {
                    SaveGameManager.shared.delete(id: save.id)
                }
                self?.showPlayMenu()
            } else {
                self?.showPlayMenu()
            }
        }
    }

    private func showMultiplayerHub() {
        clearTerminal()
        printTitle("Multiplayer Games")

        let gcAuth = GameCenterManager.shared.isAuthenticated
        if !gcAuth {
            print("Game Centre is required for", color: .yellow)
            print("multiplayer. Signing in...", color: .yellow)
            print("")
            GameCenterManager.shared.authenticatePlayer()
        }

        showMenu(["New Multiplayer Game", "Active Matches",
                   "How Multiplayer Works"])

        closeHandler = { [weak self] in self?.showMainMenu() }
        menuHandler = { [weak self] choice in
            switch choice {
            case 1:
                self?.startMultiplayerNewGame()
            case 2:
                if GameCenterManager.shared.isAuthenticated {
                    self?.showActiveMatches()
                } else {
                    self?.clearTerminal()
                    self?.printTitle("Active Matches")
                    self?.print("Sign in to Game Centre first.", color: .yellow)
                    self?.print("Check Settings > Game Centre.", color: .dimGreen)
                    self?.print("")
                    self?.waitForContinue()
                    self?.inputHandler = { [weak self] _ in
                        self?.showMultiplayerHub()
                    }
                    self?.closeHandler = { [weak self] in self?.showMultiplayerHub() }
                }
            case 3:
                self?.showMultiplayerHelp()
            default:
                self?.showMainMenu()
            }
        }
    }

    /// Start a new game pre-configured for multiplayer
    private func startMultiplayerNewGame() {
        if !GameCenterManager.shared.isAuthenticated {
            clearTerminal()
            printTitle("New Multiplayer Game")
            print("Sign in to Game Centre first.", color: .yellow)
            print("Check Settings > Game Centre.", color: .dimGreen)
            print("")
            GameCenterManager.shared.authenticatePlayer()
            waitForContinue()
            inputHandler = { [weak self] _ in self?.showPlayMenu() }
            closeHandler = { [weak self] in self?.showPlayMenu() }
            return
        }

        clearTerminal()
        printTitle("New Multiplayer Game")
        print("How many adventurers in your party?", color: .brightGreen)
        print("  (Long-press for auto-setup)", color: .dimGreen)
        print("")

        showMenu(["2 Characters", "3 Characters", "4 Characters"])

        closeHandler = { [weak self] in self?.showMultiplayerHub() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1...3:
                // Manual creation: 1 human + rest to be created manually, last slot preset as remote
                let count = choice + 1
                self.totalCharacters = count
                self.creatingCharacterIndex = 0
                self.party = []
                self.pendingRemoteSlots.removeAll()
                self.pendingRemoteSlots.insert(count - 1) // last slot = remote
                self.isMultiplayer = true
                self.chooseCharacterType()
            default: self.showPlayMenu()
            }
        }

        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1: self.createRandomParty(count: 2, allAI: true, presetRemote: true)
            case 2: self.createRandomParty(count: 3, allAI: true, presetRemote: true)
            case 3: self.createRandomParty(count: 4, allAI: true, presetRemote: true)
            default: break
            }
        }
    }

    /// Track which help topic is currently displayed (for re-press flash)
    private var currentHelpTopic: Int = -1

    /// Dim-then-restore pulse on the text area
    func flashText() {
        DispatchQueue.main.async {
            self.textFlashOpacity = 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.textFlashOpacity = 1.0
            }
        }
    }

    func showHowToPlay() {
        clearTerminal()
        currentHelpTopic = -1
        printTitle("How to Play")
        printWrapped("Navigate with buttons, type commands at the > prompt, or tap the mic to speak. Swipe left to go back from any screen.", indent: 2, color: .dimGreen)
        print("")

        let helpTopics = ["Getting Started", "Exploration", "Combat",
                          "Character & Party", "Recovery",
                          "Dungeon Master", "Multiplayer", "Tips & Tricks",
                          "FAQs", "Bestiary", "Rogues Gallery", "Name Lore"]
        let helpActions: [(GameEngine) -> Void] = [
            { $0.showHelpGettingStarted() }, { $0.showHelpExploration() },
            { $0.showHelpCombat() }, { $0.showHelpCharacter() },
            { $0.showHelpRecovery() }, { $0.showHelpDM() },
            { $0.showHelpMultiplayer() }, { $0.showHelpTips() },
            { $0.showFAQCategories() }, { $0.showBestiary() },
            { $0.showNPCBestiary() }, { $0.showNameLore() },
        ]

        showPaginatedMenu(helpTopics) { [weak self] idx in
            guard let self = self, idx >= 0 && idx < helpActions.count else { return }
            if idx == self.currentHelpTopic {
                // Same topic re-pressed — flash the text as feedback
                self.flashText()
                return
            }
            self.currentHelpTopic = idx
            helpActions[idx](self)
        }

        closeHandler = { [weak self] in
            self?.closeHandler = nil
            self?.currentHelpTopic = -1
            self?.showMainMenu()
        }
    }

    // MARK: - Help Sub-Pages

    private func showHelpGettingStarted() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Getting Started")

        print("CREATE YOUR PARTY", color: .cyan, bold: true)
        printWrapped("Choose 1-4 adventurers. For each, pick a race, class, and assign ability scores.", indent: 2)
        print("")
        printWrapped("Long-press any button during character creation to auto-fill all remaining choices instantly.", indent: 2, color: .yellow)
        print("")
        print("ENTER THE DUNGEON", color: .cyan, bold: true)
        printWrapped("Your party enters a randomly generated dungeon. Light your torch to see room details and the map.", indent: 2)
        print("")
        print("GOAL", color: .cyan, bold: true)
        printWrapped("Explore rooms, fight monsters, collect treasure and XP. Defeat the boss on each level to descend deeper.", indent: 2)
        print("")
        print("CONTROLS", color: .cyan, bold: true)
        print("  - Tap buttons to select actions", color: .dimGreen)
        print("  - Type text when prompted", color: .dimGreen)
        print("  - Tap ✕ to go back", color: .dimGreen)
        print("  - Swipe left to go back", color: .dimGreen)
        print("  - Long-press 'Done' to jump", color: .dimGreen)
        print("    back to the game view", color: .dimGreen)
        print("  - Tap speaker icon to toggle", color: .dimGreen)
        print("    narration mode on/off", color: .dimGreen)
        print("")
        print("BUTTON COLOURS", color: .cyan, bold: true)
        print("  Green — actions (attack, search,", color: .brightGreen)
        print("    equip, use items)", color: .brightGreen)
        print("  Dim green — navigation (Done,", color: .dimGreen)
        print("    Save, Continue)", color: .dimGreen)
        print("  Cyan — chat, NPCs & multiplayer", color: .cyan)
        print("  Amber — room actions, NPCs,", color: .yellow)
        print("    companions & special actions", color: .yellow)
        print("  Red — destructive (delete, drop)", color: .red)
        print("")

        closeHandler = { [weak self] in self?.showHowToPlay() }
    }

    private func showHelpExploration() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Exploration")

        print("MOVEMENT", color: .cyan, bold: true)
        printWrapped("Tap a direction button (N/S/E/W) to move between rooms. Long-press a direction to barricade or unblock a door. The map updates as you explore.", indent: 2)
        print("")
        print("TORCH", color: .cyan, bold: true)
        printWrapped("Light your torch to see room details, find items, read the map, and search rooms. Torches have limited fuel — use wisely!", indent: 2)
        print("")
        printWrapped("Beware: monsters are attracted to light! Torches, lit pipes, and similar illuminations may draw them to you.", indent: 2, color: .yellow)
        print("")
        printWrapped("Douse your torch to travel in darkness. 30% chance to sneak past monsters! It's much harder to search, examine, or forage in the dark — you'll have to work out how, or just light the torch.", indent: 2, color: .yellow)
        print("")
        print("SEARCHING", color: .cyan, bold: true)
        printWrapped("Search rooms to find hidden treasure and items. Much easier with a lit torch! Search multiple times — some items are well hidden.", indent: 2)
        print("")
        print("ROOM ACTIONS", color: .cyan, bold: true)
        printWrapped("Listen at doors to hear what lies ahead (works in the dark — ears sharpen without light). Search Room to find hidden items and scavenge for supplies, or Secure doors behind you.", indent: 2)
        print("")
        printWrapped("Search Room requires a lit torch. Long-press it in the dark to attempt blindly — but expect less success and more mishaps!", indent: 2, color: .yellow)
        print("")
        printWrapped("Monsters are attracted to torchlight. Travel dark to sneak past them, but you'll miss hidden treasures.", indent: 2, color: .yellow)
        print("")
        print("RESTING", color: .cyan, bold: true)
        printWrapped("Tap Rest for a short rest (heals some HP, advances 1 hour).", indent: 2)
        print("")
        printWrapped("Long-press Rest for a long rest (full HP heal + spell slots restored, advances 8 hours). This is a hidden shortcut!", indent: 2, color: .yellow)
        print("")
        print("SAVING", color: .cyan, bold: true)
        printWrapped("Use Save/Quit from the exploration menu. When there's room, separate Save and Quit buttons appear. Save often before boss fights!", indent: 2)
        print("")
        print("PARTY STATUS", color: .cyan, bold: true)
        let partyStatusLine = terminalLines.count
        printWrapped("Tap 'Party Status' from the exploration menu to see HP bars, stats, equipment, gold, XP, the dungeon map, and the Adventure Log. Use Party Review to edit characters or return to the main menu.", indent: 2)
        let partyStatusEndLine = terminalLines.count
        print("")

        // Long-press yellow text to navigate
        let hasGame = dungeon != nil && !party.isEmpty
        textLongPressHandler = { [weak self] lineIndex in
            guard let self = self, hasGame else { return }
            if lineIndex >= partyStatusLine && lineIndex < partyStatusEndLine {
                self.showPartyStatus()
                self.closeHandler = { [weak self] in self?.showHelpExploration() }
            }
        }

        closeHandler = { [weak self] in self?.showHowToPlay() }
    }

    private func showHelpCombat() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Combat")

        print("INITIATIVE", color: .cyan, bold: true)
        printWrapped("Each combatant rolls d20 + DEX modifier. Highest goes first.", indent: 2)
        print("")
        print("ATTACKING", color: .cyan, bold: true)
        printWrapped("Roll d20 + attack modifier vs target's AC. Meet or beat AC to hit. Roll damage dice on a hit.", indent: 2)
        print("")
        print("CRITICAL HITS", color: .cyan, bold: true)
        printWrapped("Natural 20 = critical hit (double damage dice). Natural 1 = automatic miss.", indent: 2)
        print("")
        print("SPELLS", color: .cyan, bold: true)
        printWrapped("Spellcasters use spell slots. Some spells deal damage, others heal or protect. Slots restore on long rest.", indent: 2)
        print("")
        print("DODGE", color: .cyan, bold: true)
        printWrapped("Dodge gives all attackers disadvantage (roll twice, take lower) against you until your next turn.", indent: 2, color: .yellow)
        print("")
        print("PLAY DEAD", color: .cyan, bold: true)
        printWrapped("If a fight is unwinnable, Play Dead lets you escape combat. You receive no XP or loot.", indent: 2, color: .yellow)
        print("")
        print("POISON", color: .cyan, bold: true)
        printWrapped("Some creatures inflict poison on a successful hit. Poisoned characters take damage each turn. Cure it with an Antidote, Healing Potion, or rest.", indent: 2)
        print("")
        print("  Venomous creatures (long-press):", color: .dimGreen)
        // Individual monster lines for long-press
        let poisonMonsters: [(String, MonsterType)] = [
            ("Giant Spider", .giantSpider), ("Stirge", .stirge),
            ("Giant Rat", .giantRat), ("Gelatinous Cube", .gelatinousCube),
            ("Basilisk", .basilisk), ("Young Dragon", .youngDragon),
        ]
        var monsterLineRanges: [(MonsterType, Int)] = []
        for (name, monster) in poisonMonsters {
            let chance = Int(monster.poisonChance * 100)
            let dmg = monster.poisonDamagePerTurn
            monsterLineRanges.append((monster, terminalLines.count))
            print("    ☠ \(name) — \(chance)%, \(dmg)/turn", color: .yellow)
        }
        let monsterEndLine = terminalLines.count
        print("")

        textLongPressHandler = { [weak self] lineIndex in
            for (i, entry) in monsterLineRanges.enumerated() {
                let endLine = (i + 1 < monsterLineRanges.count) ? monsterLineRanges[i + 1].1 : monsterEndLine
                if lineIndex >= entry.1 && lineIndex < endLine {
                    self?.showMonsterDetail(entry.0)
                    self?.closeHandler = { [weak self] in self?.showHelpCombat() }
                    return
                }
            }
        }

        closeHandler = { [weak self] in self?.showHowToPlay() }
    }

    func showPoisonInfo(onBack: @escaping () -> Void) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Curing Poison")
        print("")

        // Skull ASCII
        let skull = [
            "     _____",
            "    /     \\",
            "   | () () |",
            "    \\  ^  /",
            "     |||||",
            "     |||||",
        ]
        printLines(skull, color: .magenta)
        print("")

        print("HOW POISON WORKS", color: .cyan, bold: true)
        printWrapped("When a venomous creature hits you, there's a chance you'll be poisoned. You take damage every turn and must make a CON save (DC 14) each turn to fight it off naturally.", indent: 2)
        print("")

        print("CREATURES THAT POISON", color: .cyan, bold: true)
        print("  (long-press for bestiary card)", color: .dimGreen)
        let poisonMonsters: [(String, MonsterType, Int, Int)] = [
            ("Giant Spider", .giantSpider, 35, 3),
            ("Gelatinous Cube", .gelatinousCube, 40, 4),
            ("Basilisk", .basilisk, 30, 3),
            ("Young Dragon", .youngDragon, 25, 5),
            ("Stirge", .stirge, 25, 2),
            ("Giant Rat", .giantRat, 15, 1),
        ]
        var monsterLines: [(MonsterType, Int)] = []
        for (name, monster, chance, dmg) in poisonMonsters {
            monsterLines.append((monster, terminalLines.count))
            print("  ☠ \(name) — \(chance)%, \(dmg) dmg/turn", color: .magenta)
        }
        let monsterEndLine = terminalLines.count
        print("")

        textLongPressHandler = { [weak self] lineIndex in
            for (i, entry) in monsterLines.enumerated() {
                let endLine = (i + 1 < monsterLines.count) ? monsterLines[i + 1].1 : monsterEndLine
                if lineIndex >= entry.1 && lineIndex < endLine {
                    self?.showMonsterDetail(entry.0)
                    self?.closeHandler = { onBack() }
                    return
                }
            }
        }

        print("CURES", color: .brightGreen, bold: true)
        print("")
        print("  1. Antidote", color: .brightGreen)
        printWrapped("Cures poison instantly. Buy from shops (30 gold), loot from poisonous creatures, or find one on a Kobold. Creatures that resist poison carry natural antidotes.", indent: 5, color: .dimGreen)
        print("")
        print("  2. Healing Potion", color: .brightGreen)
        printWrapped("Cures poison as a side effect when drunk. Also restores HP.", indent: 5, color: .dimGreen)
        print("")
        print("  3. Short Rest", color: .brightGreen)
        printWrapped("Your body forces a fever to fight the venom (CON save, DC 12). Clerics and Rangers are skilled with herbal remedies and get a +3 bonus. May need a few rests!", indent: 5, color: .dimGreen)
        print("")
        print("  4. Long Rest", color: .brightGreen)
        printWrapped("Eight hours is enough to fight off any poison completely.", indent: 5, color: .dimGreen)
        print("")
        print("  5. NPCs", color: .brightGreen)
        printWrapped("The Old Priestess, Mad Alchemist, and Hermit can cure poison for free if you find them in the dungeon.", indent: 5, color: .dimGreen)
        print("")

        print("CLASS ADVANTAGES", color: .cyan, bold: true)
        printWrapped("Clerics and Rangers are natural herbalists. They get +3 on CON saves to cure poison during rest. Keep one in your party if you're heading into spider territory!", indent: 2, color: .dimGreen)
        print("")
        printWrapped("Poison can be switched on or off in Settings > Gameplay.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { onBack() }
    }

    private func showHelpCharacter() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Character & Party")

        print("RACES", color: .cyan, bold: true)
        printWrapped("Human, Elf, Dwarf, Halfling, Half-Orc, Tiefling, Dragonborn. Each has unique ability bonuses.", indent: 2)
        print("")
        print("CLASSES", color: .cyan, bold: true)
        printWrapped("Fighter, Wizard, Cleric, Rogue, Ranger, Barbarian. Each has a primary ability and unique features.", indent: 2)
        print("")
        print("ABILITY SCORES", color: .cyan, bold: true)
        printWrapped("STR, DEX, CON, INT, WIS, CHA. Higher scores give better modifiers. Assign your best scores to your class's primary ability.", indent: 2)
        print("")
        print("INVENTORY", color: .cyan, bold: true)
        printWrapped("Each character can carry limited items. Use Inventory to equip weapons, armour, and use potions.", indent: 2)
        print("")
        print("LEVELING UP", color: .cyan, bold: true)
        printWrapped("Earn XP from combat victories. Level up to gain more HP, better attack bonuses, and new abilities.", indent: 2)
        print("")
        print("GOLD", color: .cyan, bold: true)
        printWrapped("Collect gold from treasure and defeated enemies. Spend it at the Merchant in shop rooms.", indent: 2)
        print("")
        print("NAME LORE STATS", color: .cyan, bold: true)
        printWrapped("The character cards in Name Lore rate heroes and locations on five qualities:", indent: 2)
        print("")
        print("  Hero Cards:", color: .yellow)
        printWrapped("  Power → STR/combat (10 = Conan)", indent: 2, color: .dimGreen)
        printWrapped("  Cunning → DEX/INT (10 = Granny Weatherwax)", indent: 2, color: .dimGreen)
        printWrapped("  Magic → spellcasting (10 = Raistlin)", indent: 2, color: .dimGreen)
        printWrapped("  Fame → cultural icon (10 = Conan, Drizzt)", indent: 2, color: .dimGreen)
        printWrapped("  Charm → CHA (10 = Madmartigan, Jareth)", indent: 2, color: .dimGreen)
        print("")
        print("  Dungeon Cards:", color: .yellow)
        printWrapped("  Danger → lethality (10 = Tomb of Horrors)", indent: 2, color: .dimGreen)
        printWrapped("  Puzzle → traps & riddles (10 = Labyrinth)", indent: 2, color: .dimGreen)
        printWrapped("  Magic → magical energy (10 = Barad-dur)", indent: 2, color: .dimGreen)
        printWrapped("  Fame → cultural impact (10 = Moria)", indent: 2, color: .dimGreen)
        printWrapped("  Dread → fear factor (10 = Mount Doom)", indent: 2, color: .dimGreen)
        print("")
        print("PARTY STATUS", color: .cyan, bold: true)
        let partyStatusLine = terminalLines.count
        printWrapped("Open Party Status from the exploration menu to see each character's full stat sheet, HP, gold, XP, and equipped gear. Use Party Review to change names or player types mid-game.", indent: 2, color: .yellow)
        let partyStatusEndLine = terminalLines.count
        print("")

        let hasGame = dungeon != nil && !party.isEmpty
        textLongPressHandler = { [weak self] lineIndex in
            guard let self = self, hasGame else { return }
            if lineIndex >= partyStatusLine && lineIndex < partyStatusEndLine {
                self.showPartyStatus()
                self.closeHandler = { [weak self] in self?.showHelpCharacter() }
            }
        }

        closeHandler = { [weak self] in self?.showHowToPlay() }
    }

    private func showHelpRecovery() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Recovery")

        print("RESTING", color: .cyan, bold: true)
        printWrapped("Tap Rest to take a short rest (1 hour). This restores some HP and recharges short-rest abilities like Second Wind.", indent: 2, color: .green)
        printWrapped("Long-press Rest for a long rest (8 hours). This fully restores HP, spell slots, and all abilities. Your torch goes out during a long rest, so make sure you have another one.", indent: 2, color: .green)
        print("")

        print("TORCH & LIGHT", color: .cyan, bold: true)
        printWrapped("Many actions require a lit torch. Without light you cannot search rooms, scavenge for supplies, or see properly in combat. Torches burn for about 60 minutes of game time. Keep spares in your inventory or buy them from merchants.", indent: 2, color: .green)
        print("")

        let poisonStartLine = terminalLines.count
        print("POISON", color: .cyan, bold: true)
        printWrapped("Poisoned characters take damage each turn in combat. Cure poison with an Antidote (consumable item from shops or loot), a Cleric's healing spell, or by visiting a Healer NPC. Poison wears off after several turns but can be deadly if ignored.", indent: 2, color: .green)
        print("  (long-press for details)", color: .dimGreen)
        print("")
        let poisonEndLine = terminalLines.count

        print("HEALING SPELLS", color: .cyan, bold: true)
        printWrapped("Clerics know Cure Wounds (1d8 + WIS mod HP, costs a spell slot) and Healing Word (1d4 + WIS mod HP, bonus action). Rangers learn Cure Wounds at level 2. Cantrip Spare the Dying stabilises an unconscious ally without using a spell slot.", indent: 2, color: .green)
        print("")

        print("POTIONS", color: .cyan, bold: true)
        printWrapped("Healing Potions restore 2d4+2 HP. Use them from your Inventory or the Use Item button in combat. Stock up at shops when you can — they can save your life.", indent: 2, color: .green)
        print("")

        closeHandler = { [weak self] in self?.showHowToPlay() }

        // Long-press on the POISON section navigates to Curing Poison page
        textLongPressHandler = { [weak self] lineIndex in
            guard let self = self else { return }
            if lineIndex >= poisonStartLine && lineIndex < poisonEndLine {
                self.textLongPressHandler = nil
                self.showPoisonInfo(onBack: { self.showHelpRecovery() })
            }
        }
    }

    private func showHelpDM() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Dungeon Master (Robot)")

        printWrapped("The DM narrates your adventure. There are three intelligence tiers:", indent: 2)
        print("")
        print("  Basic DM", color: .yellow, bold: true)
        printWrapped("Simple canned responses. Works on all devices. No setup needed.", indent: 4)
        print("")
        print("  Apple On-Device AI", color: .brightGreen, bold: true)
        printWrapped("iPhone 16+ / iPad M-series, iOS 26+. Runs locally and offline. No account needed.", indent: 4)
        print("")
        printWrapped("Can be fussy — rephrase if it refuses (e.g. 'tell me the contents of my pack' not 'whats in my pack').", indent: 4, color: .dimGreen)
        print("")
        print("  Cloud AI (best)", color: .brightGreen, bold: true)
        printWrapped("Works on any device. Google Gemini is FREE (ages 18+). Also supports Claude and OpenAI.", indent: 4)
        print("")
        printWrapped("Set up in Settings > AI Provider. Adjust narration level in Settings > DM Ad-lib.", indent: 4, color: .dimGreen)
        print("")
        print("CHAT", color: .cyan, bold: true)
        printWrapped("Tap Chat during exploration to open the chat prompt. Just type naturally — ask questions, request actions, or roleplay.", indent: 2)
        print("")
        printWrapped("Use @ to address party members (e.g. '@Thorin heal me') or speak to the DM directly. The DM responds in character and may take game actions.", indent: 2)
        print("")
        print("  Shortcuts in chat:", color: .dimGreen)
        print("    'i' = open inventory", color: .dimGreen)
        print("    'map' = show dungeon map", color: .dimGreen)
        print("    'rest' = short rest", color: .dimGreen)
        print("    'status' = party status", color: .dimGreen)
        print("    Enter (empty) = close chat", color: .dimGreen)
        print("")
        print("DM VOICE", color: .cyan, bold: true)
        printWrapped("Enable text-to-speech in Settings > Accessibility > DM Voice to hear the DM's responses read aloud.", indent: 2)
        print("")
        print("SPEAKER MODE", color: .cyan, bold: true)
        printWrapped("Tap the speaker icon in the input bar to toggle narration on. Story text is read aloud automatically as you play. Tap again to turn it off.", indent: 2)
        print("")

        closeHandler = { [weak self] in self?.showHowToPlay() }
        showMenu(["Go to Settings"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.showSettings()
                // Override Settings close to return here instead of main menu
                self?.closeHandler = { [weak self] in self?.showHelpDM() }
            }
        }
    }

    private func showHelpMultiplayer() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Multiplayer")

        print("OVERVIEW", color: .cyan, bold: true)
        printWrapped("Play with friends via Game Center turn-based multiplayer. Both players need the app and a Game Center account.", indent: 2)
        print("")
        print("SETTING UP", color: .cyan, bold: true)
        printWrapped("From the Play menu, tap New Adventure. Choose your party size. By default all other characters are robot-controlled.", indent: 2)
        print("")
        let partyReviewLine = terminalLines.count
        printWrapped("To add a remote player: in Party Review, tap the swap button on any robot character to mark them [Remote]. The Game Center matchmaker will invite a friend.", indent: 2, color: .yellow)
        let partyReviewEndLine = terminalLines.count
        print("")
        printWrapped("Quick setup: long-press a party size to auto-create all characters, then swap one to Remote.", indent: 2, color: .dimGreen)
        print("")
        print("INVITING MID-GAME", color: .cyan, bold: true)
        let partyStatusLine = terminalLines.count
        printWrapped("Open Party Status during gameplay and tap 'Party Review' to change character names or switch between human and AI control at any time.", indent: 2, color: .yellow)
        let partyStatusEndLine = terminalLines.count
        print("")
        print("JOINING A GAME", color: .cyan, bold: true)
        printWrapped("When invited, you'll be prompted to connect. Accept to view the party and customise your character, or decline.", indent: 2)
        print("")
        print("PARTY CHAT", color: .cyan, bold: true)
        printWrapped("Use Party Chat (in the exploration menu) to message other players. Chat messages are saved and visible to all players regardless of whose turn it is.", indent: 2)
        print("")
        print("GAMEPLAY", color: .cyan, bold: true)
        printWrapped("The host controls exploration. In combat, each player controls their own character when it's their turn. Robot characters act automatically.", indent: 2)
        print("")
        print("ASYNC PLAY", color: .cyan, bold: true)
        printWrapped("Turns are saved to Game Center. Play at your own pace — you don't need to be online at the same time. Use Nudge to remind a player it's their turn.", indent: 2)
        print("")
        print("REMOTE GAMES IN PLAY MENU", color: .cyan, bold: true)
        printWrapped("Remote games show in cyan in the Play menu. Status shows [your turn], [waiting], or [invite].", indent: 2)
        print("")

        let mpOn = UserDefaults.standard.object(forKey: "multiplayer_enabled") == nil ? true : UserDefaults.standard.bool(forKey: "multiplayer_enabled")
        print("SETTING", color: .cyan, bold: true)
        print("  Multiplayer is currently \(mpOn ? "ON" : "OFF").", color: mpOn ? .brightGreen : .red)
        let settingsLinkLine = terminalLines.count
        printWrapped("Long-press here to change this in Settings > Gameplay.", indent: 2, color: .yellow)
        let settingsLinkEndLine = terminalLines.count
        print("")

        let hasGame = dungeon != nil && !party.isEmpty
        textLongPressHandler = { [weak self] lineIndex in
            guard let self = self else { return }
            // Party Status — navigable if game active
            if hasGame && lineIndex >= partyStatusLine && lineIndex < partyStatusEndLine {
                self.showPartyStatus()
                self.closeHandler = { [weak self] in self?.showHelpMultiplayer() }
            }
            // Settings link — navigate to gameplay settings
            if lineIndex >= settingsLinkLine && lineIndex < settingsLinkEndLine {
                self.showGameplaySettings()
                self.closeHandler = { [weak self] in self?.showHelpMultiplayer() }
            }
        }

        closeHandler = { [weak self] in self?.showHowToPlay() }
    }

    private func showHelpTips() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Tips & Tricks")

        // --- Combat Example ---
        print("COMBAT EXAMPLE", color: .cyan, bold: true)
        print("  You attack the Goblin:", color: .yellow)
        print("")
        print("    Roll: d20 + STR + Prof", color: .dimGreen)
        print("    [17]  +  3  +  2 = 22", color: .brightGreen)
        print("    vs Goblin AC 13 -> HIT!", color: .brightGreen)
        print("")
        print("    Damage: 1d8 + 3 = 7", color: .red)
        print("    Goblin HP: 7/7 -> 0/7", color: .red)
        print("    Goblin defeated!", color: .red)
        print("")

        // --- Map Example ---
        print("MAP READING", color: .cyan, bold: true)
        print("  # = wall  . = floor", color: .dimGreen)
        print("  @ = you   ? = unexplored", color: .dimGreen)
        print("")
        print("    # # # # # # #", color: .green)
        print("    # . . . # ? #", color: .green)
        print("    # . @ . . . #", color: .green)
        print("    # . . . # ? #", color: .green)
        print("    # # # # # # #", color: .green)
        print("")

        // --- Rest Example ---
        print("REST & HEALING", color: .cyan, bold: true)
        print("  Short rest (tap Rest):", color: .brightGreen)
        print("    Heal 1d8 + CON modifier", color: .dimGreen)
        print("    Takes 10 minutes", color: .dimGreen)
        print("  Long rest (hold Rest):", color: .brightGreen)
        print("    Full HP + cure conditions", color: .dimGreen)
        print("    Takes 8 hours (may attract", color: .dimGreen)
        print("    monsters if door unsecured!)", color: .dimGreen)
        print("")

        // --- Shortcuts ---
        print("LONG-PRESS SHORTCUTS", color: .cyan, bold: true)
        print("  Rest:", color: .brightGreen)
        print("    Tap = short rest", color: .dimGreen)
        print("    Hold = long rest (full heal)", color: .dimGreen)
        print("  Party size buttons:", color: .brightGreen)
        print("    Hold = auto-fill AI party", color: .dimGreen)
        print("  Play menu saves:", color: .brightGreen)
        print("    Hold = delete save", color: .dimGreen)
        print("")

        print("CHAT SHORTCUTS", color: .cyan, bold: true)
        print("  Type in DM Chat:", color: .brightGreen)
        print("    'i'      = open inventory", color: .dimGreen)
        print("    'map'    = show dungeon map", color: .dimGreen)
        print("    'rest'   = short rest", color: .dimGreen)
        print("    'status' = party status", color: .dimGreen)
        print("    Enter    = leave chat", color: .dimGreen)
        print("")

        print("NAME ENTRY", color: .cyan, bold: true)
        print("  Enter (empty) = random name", color: .dimGreen)
        print("  Type 'a' = auto-create character", color: .dimGreen)
        print("")

        // --- Inventory Example ---
        print("INVENTORY TIPS", color: .cyan, bold: true)
        let inventoryLine = terminalLines.count
        print("  Equip weapons BEFORE combat!", color: .yellow)
        let inventoryEndLine = terminalLines.count
        print("  Each character carries max 12", color: .dimGreen)
        print("  items. Drop or sell extras.", color: .dimGreen)
        print("")
        print("  Weapon equipped:", color: .brightGreen)
        print("    [E] Longsword (1d8+3)", color: .dimGreen)
        print("  Potion in pack:", color: .brightGreen)
        print("    [ ] Healing Potion (2d4+2)", color: .dimGreen)
        print("")

        print("GAMEPLAY TIPS", color: .cyan, bold: true)
        for tip in GameEngine.gameplayTips {
            print("  * \(tip)", color: .green)
            print("")
        }

        let hasGame = dungeon != nil && !party.isEmpty
        textLongPressHandler = { [weak self] lineIndex in
            guard let self = self, hasGame else { return }
            if lineIndex >= inventoryLine && lineIndex < inventoryEndLine {
                self.showInventory()
                self.closeHandler = { [weak self] in self?.showHelpTips() }
            }
        }

        closeHandler = { [weak self] in self?.showHowToPlay() }
    }

    // MARK: - FAQ

    private func showFAQCategories() {
        clearTerminal()
        printTitle("FAQs")
        // Show a random FAQ tidbit as useful preamble
        let allFAQs = FAQData.allEntries
        if let random = allFAQs.randomElement() {
            print("  Did you know?", color: .cyan, bold: true)
            printWrapped(random.answer, indent: 2, color: .dimGreen)
        }
        print("")

        let categories = FAQData.faqMenuCategories
        let shortNames: [String: String] = [
            "Inventory & Equipment": "Inventory",
            "Shops & Gold": "Shops",
            "Saving & Loading": "Saving",
            "Torch & Light": "Torches",
        ]
        let options: [String] = categories.map { shortNames[$0.title] ?? $0.title }

        closeHandler = { [weak self] in self?.showHowToPlay() }
        showMenu(options)
        menuHandler = { [weak self] choice in
            if choice >= 1 && choice <= categories.count {
                self?.showFAQCategory(categories[choice - 1])
            }
        }
    }

    private func showFAQCategory(_ category: FAQCategory) {
        clearTerminal()
        printTitle("FAQ: \(category.title)")
        print("")

        // Track answer line ranges for long-press navigation
        var answerRanges: [(startLine: Int, endLine: Int, answer: String)] = []
        let linkKeywords = ["settings →", "go to settings", "open inventory", "open pack",
                            "party status", "settings >"]

        for entry in category.entries {
            print("  Q: \(entry.question)", color: .cyan, bold: true)
            let lower = entry.answer.lowercased()
            let hasLink = linkKeywords.contains(where: { lower.contains($0) })
            let startLine = terminalLines.count
            printWrapped(entry.answer, indent: 4, color: hasLink ? .brightGreen : .green)
            let endLine = terminalLines.count
            answerRanges.append((startLine, endLine, lower))
            print("")
        }

        // Determine which answers link to which pages
        let hasGame = dungeon != nil && !party.isEmpty
        textLongPressHandler = { [weak self] lineIndex in
            guard let self = self else { return }
            for range in answerRanges {
                guard lineIndex >= range.startLine && lineIndex < range.endLine else { continue }
                let answer = range.answer
                let returnHere: () -> Void = { [weak self] in self?.showFAQCategory(category) }

                if answer.contains("settings → accessibility") || answer.contains("settings > accessibility") {
                    self.showAccessibilityMenu()
                    self.closeHandler = returnHere
                } else if answer.contains("settings →") || answer.contains("settings >") || answer.contains("go to settings") {
                    self.showSettings()
                    self.closeHandler = returnHere
                } else if answer.contains("open inventory") || answer.contains("open pack") {
                    if hasGame {
                        self.showInventory()
                        self.closeHandler = returnHere
                    }
                } else if answer.contains("party status") {
                    if hasGame {
                        self.showPartyStatus()
                        self.closeHandler = returnHere
                    }
                }
                return
            }
        }

        closeHandler = { [weak self] in self?.showFAQCategories() }
    }

    func showBestiary() {
        clearTerminal()
        printTitle("Bestiary")
        printWrapped("Tap any monster to see details.", indent: 2, color: .dimGreen)
        print("")
        print("")

        // Group monsters by tier
        let tiers: [(String, [MonsterType])] = [
            ("STARTER", [.giantRat, .kobold, .stirge, .giantBat, .crawlingClaw]),
            ("LOW", [.goblin, .skeleton, .zombie, .wolf]),
            ("MID-LOW", [.orc, .hobgoblin, .gnoll, .rustMonster]),
            ("MID", [.bugbear, .giantSpider, .ogre, .gargoyle, .mimic, .gelatinousCube]),
            ("HIGH", [.owlbear, .troll, .minotaur, .basilisk, .displacerBeast, .wraith, .demogorgon, .mindFlayer]),
            ("BOSS", [.beholder, .youngDragon, .vecna]),
        ]

        // Map line index → monster for tap detection
        // We schedule this on main queue after all prints have been queued
        var monsterLineRanges: [(monster: MonsterType, lineCount: Int)] = []

        for (tier, monsters) in tiers {
            print("  \(tier):", color: .cyan, bold: true)
            for monster in monsters {
                let art = monster.asciiArt
                let maxArtWidth = art.map { $0.count }.max() ?? 0
                let padded = art.map { $0.padding(toLength: maxArtWidth, withPad: " ", startingAt: 0) }

                print("    \(monster.rawValue)", color: .brightGreen)
                for line in padded {
                    print("    \(line)", color: .green)
                }
                printWrapped(monster.description, indent: 4, color: .dimGreen)
                print("")
                // Track approximate line count for this monster (name + art + desc + blank)
                monsterLineRanges.append((monster, padded.count))
            }
        }

        print("")
        print("")
        print("")

        closeHandler = { [weak self] in
            self?.cancelBestiaryAnim()
            self?.showHowToPlay()
        }

        // Build art ranges and block ranges on main queue after all prints are queued
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var artRanges: [(monster: MonsterType, startIndex: Int, count: Int)] = []
            var blockRanges: [(monster: MonsterType, startLine: Int)] = []

            // Find each monster's name line in the actual terminalLines
            for (monster, _) in monsterLineRanges {
                let nameText = "    \(monster.rawValue)"
                // Search for the name line — find the first matching line not already claimed
                let claimedLines = Set(blockRanges.map { $0.startLine })
                for (i, line) in self.terminalLines.enumerated() {
                    if line.text == nameText && !claimedLines.contains(i) {
                        blockRanges.append((monster, i))
                        // Art starts on the line after the name
                        let artLineCount = monster.asciiArt.count
                        artRanges.append((monster, i + 1, artLineCount))
                        break
                    }
                }
            }

            // Set up tap handler
            self.textLongPressHandler = { [weak self] lineIndex in
                for (i, block) in blockRanges.enumerated() {
                    let endLine = (i + 1 < blockRanges.count) ? blockRanges[i + 1].startLine : (self?.terminalLines.count ?? 0)
                    if lineIndex >= block.startLine && lineIndex < endLine {
                        self?.cancelBestiaryAnim()
                        self?.showMonsterDetail(block.monster)
                        return
                    }
                }
            }

            // Start animation with correct art ranges
            self.startBestiaryAnim(artRanges: artRanges)
        }
    }

    private var bestiaryAnimTimer: Timer?
    private var bestiaryAnimFrame: Int = 0

    private func startBestiaryAnim(artRanges: [(monster: MonsterType, startIndex: Int, count: Int)]) {
        cancelBestiaryAnim()
        bestiaryAnimFrame = 0

        // Start after a short delay, then animate one random monster at a time
        bestiaryAnimTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, !artRanges.isEmpty else { return }
                self.bestiaryAnimFrame += 1

                // Pick a random monster to animate — skip the first 3 entries
                // to avoid interfering with the visible top of the list
                let eligible = artRanges.count > 3 ? Array(artRanges.dropFirst(3)) : artRanges
                let range = eligible.randomElement()!
                let frames = range.monster.asciiArtFrames
                let frameIdx = self.bestiaryAnimFrame % frames.count
                let frame = frames[frameIdx]
                let maxWidth = frame.map { $0.count }.max() ?? 0
                let padded = frame.map { $0.padding(toLength: maxWidth, withPad: " ", startingAt: 0) }

                for (i, line) in padded.enumerated() {
                    let lineIdx = range.startIndex + i
                    if lineIdx < self.terminalLines.count {
                        self.terminalLines[lineIdx].text = "    \(line)"
                    }
                }
            }
        }
    }

    private func cancelBestiaryAnim() {
        bestiaryAnimTimer?.invalidate()
        bestiaryAnimTimer = nil
    }

    private var monsterDetailAnimTimer: Timer?
    private var monsterDetailAnimFrame: Int = 0

    private func showMonsterDetail(_ monster: MonsterType) {
        monsterDetailAnimTimer?.invalidate()
        monsterDetailAnimTimer = nil

        clearTerminal()
        suppressAutoScroll = true
        scrollLocked = true

        // Stat card border
        let s = monster.stats
        let crText = s.cr < 1 ? "1/\(Int(1.0 / s.cr))" : "\(Int(s.cr))"
        let name = monster.rawValue
        let cardW = 27
        let border = String(repeating: "─", count: cardW)

        // Card top border with sparkle corners
        let topBorderLine = terminalLines.count
        print("  ╔\(border)╗", color: .cyan)
        // Name centred (wrap to 2 lines if needed)
        for line in cardWrapText(name, width: cardW) {
            let pad = max(0, cardW - line.count)
            let left = pad / 2; let right = pad - left
            print("  ║\(String(repeating: " ", count: left))\(line)\(String(repeating: " ", count: right))║", color: .brightGreen, bold: true)
        }
        print("  ╠\(border)╣", color: .cyan)

        // ASCII art (animated)
        let art = monster.asciiArt
        let maxWidth = art.map { $0.count }.max() ?? 0
        let padded = art.map { $0.padding(toLength: min(maxWidth, 25), withPad: " ", startingAt: 0) }

        let artStart = terminalLines.count
        for line in padded {
            let artPad = max(0, cardW - line.count)
            let aLeft = artPad / 2
            let aRight = artPad - aLeft
            print("  ║\(String(repeating: " ", count: aLeft))\(line)\(String(repeating: " ", count: aRight))║", color: .green)
        }

        // Stat divider
        print("  ╠\(border)╣", color: .cyan)

        // Stats in card format
        let monsterStatStart = terminalLines.count
        let hpStr = "HP: \(s.hp)"
        let acStr = "AC: \(s.ac)"
        let statLine1 = " \(hpStr)".padding(toLength: 14, withPad: " ", startingAt: 0) + "\(acStr) ".padding(toLength: 13, withPad: " ", startingAt: 0)
        print("  ║\(statLine1)║", color: .yellow)

        let atkStr = "ATK: +\(s.attackBonus)"
        let dmgStr = "DMG: \(s.damage)"
        let statLine2 = " \(atkStr)".padding(toLength: 14, withPad: " ", startingAt: 0) + "\(dmgStr) ".padding(toLength: 13, withPad: " ", startingAt: 0)
        print("  ║\(statLine2)║", color: .yellow)

        let crStr = "CR: \(crText)"
        let xpStr = "XP: \(s.xp)"
        let statLine3 = " \(crStr)".padding(toLength: 14, withPad: " ", startingAt: 0) + "\(xpStr) ".padding(toLength: 13, withPad: " ", startingAt: 0)
        print("  ║\(statLine3)║", color: .yellow)

        // Card bottom border
        let bottomBorderLine = terminalLines.count
        print("  ╚\(border)╝", color: .cyan)

        // Description
        printWrapped(monster.description, indent: 2, color: .dimGreen)

        // Combat tips
        let tips: [String]
        switch monster {
        case .giantRat: tips = ["Weak but often found in groups.", "Can inflict mild poison — carry antidotes."]
        case .kobold: tips = ["Cunning trapmakers. Check the floor.", "Cowardly alone but dangerous in packs."]
        case .stirge: tips = ["Attaches and drains blood. Venomous bite.", "Fragile — one good hit will do."]
        case .giantBat: tips = ["Echolocation means darkness won't help.", "Fast but fragile."]
        case .crawlingClaw: tips = ["Undead severed hands. Unsettling.", "Weak but hard to spot in the dark."]
        case .goblin: tips = ["Nimble and sneaky.", "Often carries small treasures."]
        case .skeleton: tips = ["Vulnerable to bludgeoning weapons.", "Mindless but relentless."]
        case .zombie: tips = ["Slow but tough.", "Sometimes rises again after being felled."]
        case .wolf: tips = ["Pack tactics give advantage on attacks.", "Fast and hard to outrun."]
        case .orc: tips = ["Aggressive charge ability.", "Drops useful weapons when slain."]
        case .hobgoblin: tips = ["Disciplined and well-armoured.", "More dangerous than common goblins."]
        case .gnoll: tips = ["Driven by hunger and rage.", "Gets extra attacks when it downs a foe."]
        case .rustMonster: tips = ["Corrodes metal on contact!", "Target it before it ruins your gear."]
        case .bugbear: tips = ["Surprise attacks deal extra damage.", "Stealthy for their size."]
        case .giantSpider: tips = ["Web attack can restrain you. Potent venom!", "Vulnerable to fire. May drop an antidote."]
        case .ogre: tips = ["Hits very hard but slow-witted.", "Big target — easy to hit."]
        case .gargoyle: tips = ["Resistant to non-magical weapons.", "Can remain perfectly still as stone."]
        case .mimic: tips = ["Disguises itself as a chest or door.", "Adhesive body grapples on contact."]
        case .gelatinousCube: tips = ["Nearly invisible in corridors. Highly toxic!", "Dissolves organic matter — watch your gear."]
        case .owlbear: tips = ["Ferocious and territorial.", "Devastating multiattack."]
        case .troll: tips = ["Regenerates health each turn.", "Fire and acid stop regeneration."]
        case .minotaur: tips = ["Charging attack is devastating.", "Knows every twist of the labyrinth."]
        case .basilisk: tips = ["Petrifying gaze — avoid eye contact!", "Venomous bite. Slow but deadly."]
        case .displacerBeast: tips = ["Illusions make it hard to hit.", "Attacks have disadvantage against it."]
        case .wraith: tips = ["Incorporeal — resists physical damage.", "Life drain reduces max HP."]
        case .demogorgon: tips = ["Two heads, each with its own will.", "Maddening gaze can stun."]
        case .mindFlayer: tips = ["Mind Blast stuns in a cone.", "Extract brain for instant kill — stay at range!"]
        case .beholder: tips = ["Anti-magic eye disables spells.", "Each eye ray has a different deadly effect."]
        case .youngDragon: tips = ["Breath weapon is devastating. Venomous claws.", "Flies out of melee range."]
        case .vecna: tips = ["Legendary lich of immense power.", "Lair actions reshape the battlefield."]
        }
        print("  COMBAT TIPS", color: .cyan, bold: true)
        for tip in tips {
            printWrapped("  \(tip)", indent: 4, color: .dimGreen)
        }

        // Poison info
        var poisonLine = -1
        if monster.canPoison {
            let chance = Int(monster.poisonChance * 100)
            let dmg = monster.poisonDamagePerTurn
            poisonLine = terminalLines.count
            print("  ☠ POISON — \(chance)%, \(dmg) dmg/turn", color: .magenta, bold: true)
        }

        closeHandler = { [weak self] in
            self?.monsterDetailAnimTimer?.invalidate()
            self?.monsterDetailAnimTimer = nil
            self?.showBestiary()
        }

        // Swipe navigation between monsters
        let allMonsters = MonsterType.allCases
        if let idx = allMonsters.firstIndex(of: monster) {
            cardPositionLabel = cardLabel(idx + 1, of: allMonsters.count)
            swipeLeftHandler = idx + 1 < allMonsters.count ? { [weak self] in
                self?.showMonsterDetail(allMonsters[idx + 1])
            } : nil
            swipeRightHandler = idx > 0 ? { [weak self] in
                self?.showMonsterDetail(allMonsters[idx - 1])
            } : nil
            swipeRandomHandler = { [weak self] in
                let r = Int.random(in: 0..<allMonsters.count)
                self?.showMonsterDetail(allMonsters[r])
            }
        }

        // Animate: art frames + sparkle corners + poison skull blink
        let sparkles = ["✦", "✧", "★", "☆"]
        let canPoison = monster.canPoison
        let poisonChance = canPoison ? Int(monster.poisonChance * 100) : 0
        let poisonDmg = canPoison ? monster.poisonDamagePerTurn : 0
        monsterDetailAnimFrame = 0
        let frames = monster.asciiArtFrames
        monsterDetailAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.monsterDetailAnimFrame += 1
                let frame2 = self.monsterDetailAnimFrame

                // Art frame animation
                let frameIdx = frame2 % frames.count
                let frame = frames[frameIdx]
                let fw = frame.map { $0.count }.max() ?? 0
                let fp = frame.map { $0.padding(toLength: min(fw, 25), withPad: " ", startingAt: 0) }
                for (i, line) in fp.enumerated() {
                    let lineIdx = artStart + i
                    if lineIdx < self.terminalLines.count {
                        let artPad = max(0, cardW - line.count)
                        let aLeft = artPad / 2
                        let aRight = artPad - aLeft
                        self.terminalLines[lineIdx].text = "  ║\(String(repeating: " ", count: aLeft))\(line)\(String(repeating: " ", count: aRight))║"
                    }
                }

                // Sparkle corners
                let sp = sparkles[frame2 % sparkles.count]
                if topBorderLine < self.terminalLines.count {
                    self.terminalLines[topBorderLine].text = "  \(sp)\(border)\(sp)"
                }
                if bottomBorderLine < self.terminalLines.count {
                    self.terminalLines[bottomBorderLine].text = "  \(sp)\(border)\(sp)"
                }

                // Poison skull blink
                if canPoison && poisonLine >= 0 && poisonLine < self.terminalLines.count {
                    let skull = frame2 % 2 == 0 ? "☠" : "☢"
                    self.terminalLines[poisonLine].text = "  \(skull) POISON — \(poisonChance)%, \(poisonDmg) dmg/turn"
                }
            }
        }
    }

    // MARK: - NPC Bestiary

    func showNPCBestiary() {
        clearTerminal()
        printTitle("Rogues Gallery")
        print("")

        let met = metNPCNames
        let metCount = NPCType.allCases.filter { met.contains($0.rawValue) }.count
        let total = NPCType.allCases.count
        print("  Encountered: \(metCount)/\(total)", color: .dimGreen)
        print("")

        // Group NPCs by role
        let groups: [(String, [NPCType])] = [
            ("TRADERS", NPCType.allCases.filter { $0.canTrade }),
            ("HEALERS", NPCType.allCases.filter { $0.canHeal }),
            ("COMPANIONS", NPCType.allCases.filter { $0.canJoinTemporarily }),
            ("TEACHERS", NPCType.allCases.filter { $0.canTeach && !$0.canHeal && !$0.canJoinTemporarily }),
        ]

        for (group, npcs) in groups {
            print("  \(group):", color: .cyan, bold: true)
            for npc in npcs {
                let isMet = met.contains(npc.rawValue)
                let art = npc.asciiArt
                let maxWidth = art.map { $0.count }.max() ?? 0
                let padded = art.map { $0.padding(toLength: maxWidth, withPad: " ", startingAt: 0) }
                if isMet {
                    print("  ✓ \(npc.rawValue)", color: .brightGreen)
                    for line in padded {
                        print("    \(line)", color: .green)
                    }
                    printWrapped(npc.description, indent: 4, color: .dimGreen)
                } else {
                    print("  · \(npc.rawValue)", color: .gray)
                    for line in padded {
                        print("    \(line)", color: .gray)
                    }
                    print("    Not yet encountered.", color: .gray)
                }
                print("")
            }
        }

        closeHandler = { [weak self] in self?.showHowToPlay() }

        // Sequential pagination through all NPCs
        let allNPCs = NPCType.allCases
        let npcNames = allNPCs.map { npc in
            let isMet = met.contains(npc.rawValue)
            return isMet ? "✓ \(npc.rawValue)" : "· \(npc.rawValue)"
        }

        // Dice button: show random NPC card
        rerollHandler = { [weak self] in
            guard let self = self, !allNPCs.isEmpty else { return }
            let r = Int.random(in: 0..<allNPCs.count)
            self.showNPCDetail(allNPCs[r])
        }

        showPaginatedMenu(npcNames) { [weak self] idx in
            guard idx >= 0, idx < allNPCs.count else { return }
            self?.showNPCDetail(allNPCs[idx])
        }
    }

    private var npcDetailAnimTimer: Timer?
    private var npcDetailAnimFrame: Int = 0

    private func showNPCDetail(_ npc: NPCType) {
        npcDetailAnimTimer?.invalidate()
        npcDetailAnimTimer = nil

        clearTerminal()
        suppressAutoScroll = true
        scrollLocked = true

        // Card layout — compact single-page
        let name = npc.rawValue
        let cardW = 27
        let border = String(repeating: "─", count: cardW)

        // Top border with sparkle corners
        let topBorderLine = terminalLines.count
        print("  ╔\(border)╗", color: .cyan)

        // Centred name (wrap to 2 lines if needed)
        for line in cardWrapText(name, width: cardW) {
            let pad = max(0, cardW - line.count)
            let left = pad / 2; let right = pad - left
            print("  ║\(String(repeating: " ", count: left))\(line)\(String(repeating: " ", count: right))║", color: .brightGreen, bold: true)
        }

        print("  ╠\(border)╣", color: .cyan)

        // ASCII art inside card (animated)
        let art = npc.asciiArt
        let maxWidth = art.map { $0.count }.max() ?? 0
        let padded = art.map { $0.padding(toLength: min(maxWidth, 25), withPad: " ", startingAt: 0) }

        let artStart = terminalLines.count
        for line in padded {
            let artPad = max(0, cardW - line.count)
            let aLeft = artPad / 2
            let aRight = artPad - aLeft
            print("  ║\(String(repeating: " ", count: aLeft))\(line)\(String(repeating: " ", count: aRight))║", color: .green)
        }

        // Stats divider
        print("  ╠\(border)╣", color: .cyan)

        // Compact capability icons — ✓ for yes, · for no
        let statStart = terminalLines.count
        let tradeS = npc.canTrade ? "✓" : "·"
        let healS = npc.canHeal ? "✓" : "·"
        let joinS = npc.canJoinTemporarily ? "✓" : "·"
        let teachS = npc.canTeach ? "✓" : "·"
        let repairS = npc.canRepair ? "✓" : "·"
        let cureS = npc.canCurePoison ? "✓" : "·"

        let row1 = " Trade:\(tradeS)".padding(toLength: 10, withPad: " ", startingAt: 0)
            + "Heal:\(healS)".padding(toLength: 8, withPad: " ", startingAt: 0)
            + "Join:\(joinS)".padding(toLength: 9, withPad: " ", startingAt: 0)
        print("  ║\(row1)║", color: .yellow)
        let questS = npc.canOfferQuest ? "✓" : "·"
        let row2 = " Teach:\(teachS)".padding(toLength: 10, withPad: " ", startingAt: 0)
            + "Fix:\(repairS)".padding(toLength: 8, withPad: " ", startingAt: 0)
            + "Quest:\(questS)".padding(toLength: 9, withPad: " ", startingAt: 0)
        print("  ║\(row2)║", color: .yellow)

        // Card bottom border with sparkle corners
        let bottomBorderLine = terminalLines.count
        print("  ╚\(border)╝", color: .cyan)

        // Description (compact)
        printWrapped(npc.description, indent: 2, color: .dimGreen)

        // Greeting — inline, no header
        let cardGreeting = npc == .gatekeeper
            ? "Hold, adventurers. I can tell you what lurks below..."
            : npc.greeting
        printWrapped("  \"\(cardGreeting)\"", indent: 2, color: .green)

        // Single best tip
        let tip: String
        switch npc {
        case .wanderingTrader: tip = "Buys gems at better prices than shops."
        case .prisoner: tip = "Heal or free them and they may join you."
        case .hermit: tip = "Ask about their grandfather for lore."
        case .ghostlyScholar: tip = "Can reveal parts of the dungeon map."
        case .dwarvenSmith: tip = "Can improve weapon damage permanently."
        case .elfScout: tip = "Joins your party and reveals traps ahead."
        case .goblinDefector: tip = "Knows the weakness of nearby monsters."
        case .mysteriousStranger: tip = "Sells rare items not found in shops."
        case .woundedKnight: tip = "Heal them first, then ask them to join."
        case .madAlchemist: tip = "Experimental potions have random effects!"
        case .oldPriestess: tip = "Heals for free and can cure poison."
        case .ratCatcher: tip = "Knows where monsters lurk on this level."
        case .gatekeeper: tip = "Offers quests and info — but may not be truthful."
        }
        print("  TIP: \(tip)", color: .cyan)

        closeHandler = { [weak self] in
            self?.npcDetailAnimTimer?.invalidate()
            self?.npcDetailAnimTimer = nil
            self?.showNPCBestiary()
        }

        // Swipe navigation between NPCs
        let allNPCs = NPCType.allCases
        if let idx = allNPCs.firstIndex(of: npc) {
            cardPositionLabel = cardLabel(idx + 1, of: allNPCs.count)
            swipeLeftHandler = idx + 1 < allNPCs.count ? { [weak self] in
                self?.showNPCDetail(allNPCs[idx + 1])
            } : nil
            swipeRightHandler = idx > 0 ? { [weak self] in
                self?.showNPCDetail(allNPCs[idx - 1])
            } : nil
            swipeRandomHandler = { [weak self] in
                let r = Int.random(in: 0..<allNPCs.count)
                self?.showNPCDetail(allNPCs[r])
            }
        }

        // Animate: art sway + sparkle corners + blink capabilities
        let sparkles = ["✦", "✧", "★", "☆"]
        npcDetailAnimFrame = 0
        npcDetailAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.npcDetailAnimFrame += 1
            let frame = self.npcDetailAnimFrame
            DispatchQueue.main.async {
                // Art sway
                let shift = frame % 2 == 0 ? 0 : 1
                for (j, line) in padded.enumerated() {
                    let lineIdx = artStart + j
                    guard lineIdx < self.terminalLines.count else { continue }
                    let artPad = max(0, cardW - line.count)
                    let aLeft = artPad / 2 + shift
                    let aRight = max(0, artPad - artPad / 2 - shift)
                    self.terminalLines[lineIdx].text = "  ║\(String(repeating: " ", count: aLeft))\(line)\(String(repeating: " ", count: aRight))║"
                }

                // Sparkle corners — cycle through sparkle characters
                let s = sparkles[frame % sparkles.count]
                if topBorderLine < self.terminalLines.count {
                    self.terminalLines[topBorderLine].text = "  \(s)\(border)\(s)"
                }
                if bottomBorderLine < self.terminalLines.count {
                    self.terminalLines[bottomBorderLine].text = "  \(s)\(border)\(s)"
                }

                // Blink capability ✓ marks — alternate ✓ and ★
                let mark = frame % 2 == 0 ? "✓" : "★"
                let tS = npc.canTrade ? mark : "·"
                let hS = npc.canHeal ? mark : "·"
                let jS = npc.canJoinTemporarily ? mark : "·"
                let teS = npc.canTeach ? mark : "·"
                let rS = npc.canRepair ? mark : "·"
                let cuS = npc.canCurePoison ? mark : "·"
                let r1 = " Trade:\(tS)".padding(toLength: 10, withPad: " ", startingAt: 0)
                    + "Heal:\(hS)".padding(toLength: 8, withPad: " ", startingAt: 0)
                    + "Join:\(jS)".padding(toLength: 9, withPad: " ", startingAt: 0)
                let r2 = " Teach:\(teS)".padding(toLength: 10, withPad: " ", startingAt: 0)
                    + "Fix:\(rS)".padding(toLength: 8, withPad: " ", startingAt: 0)
                    + "Cure:\(cuS)".padding(toLength: 9, withPad: " ", startingAt: 0)
                if statStart < self.terminalLines.count {
                    self.terminalLines[statStart].text = "  ║\(r1)║"
                }
                if statStart + 1 < self.terminalLines.count {
                    self.terminalLines[statStart + 1].text = "  ║\(r2)║"
                }
            }
        }
    }

    // MARK: - Name Lore

    private var nameLoreAnimTimer: Timer?
    private var nameLoreAnimFrame: Int = 0

    private struct NameEntry {
        let name: String
        let source: String
        let description: String
        let category: String     // "hero" or "dungeon"
        let art: [String]        // Individual ASCII art (3-4 lines)
        // Card stats (1-10)
        let power: Int
        let cunning: Int
        let magic: Int
        let fame: Int
        let charm: Int
        var year: Int = 0       // Year of source material (for cutoff filtering)
    }

    /// Cutoff year for Name Lore entries (source material up to this year)

    /// Map source strings to broad display clusters for heroes and dungeons
    private func nameLoreCluster(for source: String) -> String {
        // TV & Animation
        let tvSources: Set<String> = [
            "Stranger Things", "Community", "Futurama",
            "He-Man (1983)", "ThunderCats (1985)", "Dogtanian (1981)",
            "Noggin the Nog (1959)", "Doctor Who (1963)", "Blake's 7 (1978)",
            "Ulysses 31 (1981)", "Mysterious Cities of Gold (1982)",
            "Robin of Sherwood (1984)"]
        if tvSources.contains(source) { return "TV & Animation" }
        // Films
        let filmSources: Set<String> = [
            "Honour Among Thieves", "Willow (1988)",
            "The NeverEnding Story (1984)", "Conan the Barbarian (1982)",
            "Highlander (1986)", "Labyrinth (1986)", "Legend (1985)",
            "The Black Cauldron (1985)", "Ladyhawke (1985)",
            "Red Sonja (1985)", "The Beastmaster (1982)",
            "Dragonslayer (1981)", "Alien (1979)", "Star Wars (1977)",
            "Forbidden Planet (1956)", "King Kong (1933)"]
        if filmSources.contains(source) { return "Films" }
        // Sci-Fi & Robots
        if source == "Classic Sci-Fi" || source == "Famous Robots" { return "Sci-Fi & Robots" }
        // Comics & Strips
        let comicSources: Set<String> = [
            "Flash Gordon (1934)", "Buck Rogers (1929)",
            "Dan Dare (1950)", "Prince Valiant (1937)",
            "The Phantom (1936)", "Judge Dredd (1977)"]
        if comicSources.contains(source) { return "Comics & Strips" }
        // D&D Modules
        if source.hasPrefix("D&D Module") { return "D&D Modules" }
        // Everything else (including Tolkien) → Books
        return "Books"
    }

    // swiftlint:disable function_body_length
    private var nameEntries: [NameEntry] {
        [
            // ══════════════════════════════════════════
            // HERO NAMES — Comics & Newspaper Strips
            // ══════════════════════════════════════════
            NameEntry(name: "Flash Gordon", source: "Flash Gordon (1934)", description: "Space adventurer supreme. Flash, a Yale polo player, rocketed to Mongo with Dale Arden and Dr Zarkov to face Ming the Merciless. Alex Raymond's strip defined space opera: ray guns, rocket ships, and a square-jawed hero saving the universe. Every space adventure since owes Flash a debt.", category: "hero", art: [" \\O/ ", " /|\\ ", " RAY ", " / \\"], power: 8, cunning: 5, magic: 1, fame: 10, charm: 8, year: 1934),
            NameEntry(name: "Buck Rogers", source: "Buck Rogers (1929)", description: "Anthony Rogers fell asleep in a mine in 1927 and woke in the 25th century. The first science fiction comic strip hero, Buck fought sky pirates and alien invaders with ray guns and rocket belts. He predates Flash Gordon by five years and gave the world its first taste of space adventure in the Sunday papers.", category: "hero", art: ["  O  ", " /|\\ ", " JET ", " / \\"], power: 7, cunning: 6, magic: 1, fame: 9, charm: 6, year: 1929),
            NameEntry(name: "Dan Dare", source: "Dan Dare (1950)", description: "Pilot of the Future! Colonel Dan Dare of the Interplanet Space Fleet battled the Mekon — a green, dome-headed Venusian genius — across the pages of Eagle comic. Frank Hampson's beautifully painted strip was thoughtful, optimistic sci-fi. Dan was a gentleman hero: brave, decent, and unfailingly polite.", category: "hero", art: ["  O  ", " /|\\ ", " JET ", " DAN"], power: 7, cunning: 7, magic: 1, fame: 8, charm: 7, year: 1950),
            NameEntry(name: "Prince Valiant", source: "Prince Valiant (1937)", description: "Prince of Thule, Knight of the Round Table, star of Hal Foster's magnificent comic strip. Valiant's adventures span decades of Arthurian glory — questing, jousting, and romancing Princess Aleta. The strip is painted, not drawn, and its visual splendour set a standard no other comic has matched.", category: "hero", art: ["  O  ", " /|X ", " SWD ", " / \\"], power: 8, cunning: 6, magic: 2, fame: 8, charm: 7, year: 1937),
            NameEntry(name: "The Phantom", source: "The Phantom (1936)", description: "The Ghost Who Walks. For over four hundred years, the Phantom has haunted the jungles of Bengalla. Each Phantom trains his son to succeed him, creating the legend of an immortal hero. Lee Falk's masked avenger was the first costumed superhero in comics, predating Batman by three years.", category: "hero", art: ["  O  ", " /|\\ ", " SKL ", " / \\"], power: 8, cunning: 7, magic: 1, fame: 8, charm: 6, year: 1936),
            NameEntry(name: "Judge Dredd", source: "Judge Dredd (1977)", description: "I am the Law! In the irradiated wasteland of Mega-City One, Judge Dredd is judge, jury, and executioner. He never removes his helmet, never smiles, and never bends the rules. 2000 AD's greatest creation is a fascist lawman played straight in a satirical world — and somehow, you root for him anyway.", category: "hero", art: ["  O  ", " ]|[ ", " LAW ", " / \\"], power: 9, cunning: 7, magic: 1, fame: 9, charm: 2, year: 1977),

            // ══════════════════════════════════════════
            // HERO NAMES — Film & TV
            // ══════════════════════════════════════════
            NameEntry(name: "Will the Wise", source: "Stranger Things", description: "A boy who survived the Upside Down and emerged wiser for it. His D&D character became his truest self — a divination wizard who sees what others cannot. Will proved that the bravest heroes are not the strongest, but the ones who endure.", category: "hero", art: ["  o  ", " /|\\ ", " / \\ ", " ~DM~"], power: 3, cunning: 7, magic: 8, fame: 9, charm: 6),
            NameEntry(name: "Eleven", source: "Stranger Things", description: "She has powers no wizard could match — telekinesis, remote viewing, and the ability to close rifts between dimensions. Raised in a laboratory, she escaped and found a family. Her favourite spell component? Eggo waffles.", category: "hero", art: ["  o  ", " /|\\ ", "  |  ", " ~~~"], power: 9, cunning: 5, magic: 10, fame: 10, charm: 7),
            NameEntry(name: "Eddie Munson", source: "Stranger Things", description: "Dungeon Master of the Hellfire Club and metalhead bard extraordinaire. Eddie played guitar on a trailer roof to draw demobats away from his friends. He never ran from a fight — not even his last one. The campaign continues without him, but the seat at the head of the table stays empty.", category: "hero", art: ["  o  ", " /|\\ ", " / \\ ", " \\m/"], power: 5, cunning: 6, magic: 3, fame: 8, charm: 9),
            NameEntry(name: "Hopper", source: "Stranger Things", description: "Chief of Hawkins police and reluctant father figure. Tough as chain mail on the outside, soft as a healing potion when it counts. Survived a Russian gulag and punched a demogorgon. His character class would be Paladin — sworn to protect, no matter the cost.", category: "hero", art: ["  O  ", " [|] ", " / \\ ", " HAT"], power: 8, cunning: 6, magic: 1, fame: 8, charm: 6),
            NameEntry(name: "Steve", source: "Stranger Things", description: "Once the popular kid with perfect hair, now the party's unlikely protector. Steve wields a nail bat like a mace and babysits a group of adventurous children through literal hellscapes. His hair remains perfect throughout. A fighter with surprising depth.", category: "hero", art: ["  o  ", " /|\\ ", " BAT ", " / \\"], power: 6, cunning: 4, magic: 1, fame: 7, charm: 8),

            NameEntry(name: "Hector the Well-Endowed", source: "Community", description: "Troy Barnes's legendary D&D character, blessed with exceptional... abilities. All of them. A human fighter of prodigious talent and even more prodigious name. The Community study group's most memorable campaign moment, proving that sometimes the best character concepts come from sheer enthusiasm.", category: "hero", art: ["  O  ", " \\|/", " /|\\ ", " BIG"], power: 9, cunning: 3, magic: 1, fame: 7, charm: 10),
            NameEntry(name: "Brutalitops", source: "Community", description: "The magician! Created by Abed Nadir during the Community D&D episode. Abed proved that the quiet, observant player can absolutely dominate a campaign. Named with the subtlety of a fireball spell, Brutalitops the Magician brought arcane devastation and dry wit in equal measure.", category: "hero", art: ["  o  ", " *|* ", " /|\\ ", " MAG"], power: 4, cunning: 8, magic: 9, fame: 6, charm: 5),

            NameEntry(name: "Titanius", source: "Futurama", description: "Titanius Anglesmith, Fancy Man of Cornwood! Bender's fantasy alter-ego from Bender's Game, wielding a sword and an ego of legendary proportions. A warrior who fights with more style than skill and more mouth than either. His armour is polished to a mirror shine — naturally.", category: "hero", art: [" [O] ", " /|\\ ", " | | ", " BOT"], power: 7, cunning: 4, magic: 2, fame: 7, charm: 6),
            NameEntry(name: "Leegola", source: "Futurama", description: "Leela's fantasy form — a fearsome elf centaur with a bow and a legendary temper. Half horse, all warrior, and absolutely not taking any nonsense from Titanius. The deadliest archer in Cornwood, with depth perception issues that somehow never affect her aim.", category: "hero", art: ["  o  ", " /|\\ ", " /~~\\", " LEGS"], power: 8, cunning: 6, magic: 4, fame: 6, charm: 5),

            NameEntry(name: "Edgin", source: "Honour Among Thieves", description: "A bard who plans heists instead of singing ballads. Edgin Darvis lost his wife to the Red Wizards of Thay and turned to thievery to cope. His only weapon is a lute and his only armour is audacity. He inspires the party not through magic but through sheer stubbornness and surprisingly good plans.", category: "hero", art: ["  o  ", " /|\\ ", " ♪|  ", " LUTE"], power: 3, cunning: 8, magic: 2, fame: 8, charm: 9),
            NameEntry(name: "Holga", source: "Honour Among Thieves", description: "A barbarian who solves problems by hitting them. Hard. Holga Kilgore is an exile from the Elk Tribe with a heart of gold beneath her battle-scarred exterior. She once knocked a man unconscious with a potato. Her rage is matched only by her loyalty and her cooking.", category: "hero", art: ["  O  ", " \\|/", " AXE ", " / \\"], power: 10, cunning: 4, magic: 1, fame: 7, charm: 6),
            NameEntry(name: "Xenk", source: "Honour Among Thieves", description: "A paladin of unwavering virtue and absolutely no sense of humour. Xenk Yendar walks through every scene like a walking cathedral. He is annoyingly perfect at everything — fighting, diplomacy, moral integrity — and completely unaware of how irritating this makes him to rogues and bards.", category: "hero", art: ["  O  ", " ╬|╬ ", " /|\\ ", " / \\"], power: 9, cunning: 5, magic: 6, fame: 7, charm: 4),

            NameEntry(name: "Ripley", source: "Classic Sci-Fi", description: "Ellen Ripley, warrant officer of the Nostromo and the ultimate survivor. She faced xenomorphs, corporate betrayal, and an android with milk for blood — and she won every time. If transported to a dungeon, she'd be a Ranger with a flamethrower and zero patience for NPCs who say 'let's split up'.", category: "hero", art: ["  o  ", " /|\\ ", " GUN ", " / \\"], power: 8, cunning: 9, magic: 1, fame: 10, charm: 6),
            NameEntry(name: "Deckard", source: "Classic Sci-Fi", description: "Rick Deckard, blade runner, hunter of replicants in the neon rain of 2019 Los Angeles. He asks the questions that make androids dream of electric sheep. Is he human? Even he doesn't know. In a dungeon, he'd be an Investigator — always asking questions, never quite trusting the answers.", category: "hero", art: ["  o  ", " ]|[ ", " /|\\ ", " DET"], power: 6, cunning: 8, magic: 1, fame: 9, charm: 5),
            NameEntry(name: "Atreides", source: "Classic Sci-Fi", description: "House Atreides rules through honour in a universe of treachery. Paul Atreides walked the desert of Arrakis, drank the Water of Life, and became Muad'Dib — the Kwisatz Haderach. He could see the future but couldn't prevent the jihad his name would inspire. The most reluctant messiah in fiction.", category: "hero", art: ["  O  ", " }|{ ", " SAND", " / \\"], power: 7, cunning: 9, magic: 10, fame: 10, charm: 7),
            NameEntry(name: "Snake Plissken", source: "Classic Sci-Fi", description: "War hero turned outlaw, eyepatch, leather jacket, and an escape plan for everything. Snake was dropped into Manhattan Maximum Security Prison and told to rescue the President. His response was essentially 'fine, but I'm not happy about it'. A rogue with a military background and a permanent scowl.", category: "hero", art: ["  ø  ", " /|\\ ", " GUN ", " / \\"], power: 8, cunning: 9, magic: 1, fame: 8, charm: 4),

            NameEntry(name: "Daneel", source: "Famous Robots", description: "R. Daneel Olivaw — Asimov's positronic detective who served humanity for twenty thousand years. He began as a robot detective on Earth and ended as the secret guardian of the entire galaxy. He followed the Three Laws of Robotics so well that he invented a Zeroth Law. The most loyal companion imaginable.", category: "hero", art: [" [o] ", " /|\\ ", " | | ", " BOT"], power: 6, cunning: 9, magic: 1, fame: 7, charm: 7),
            NameEntry(name: "Marvin", source: "Famous Robots", description: "The Paranoid Android from The Hitchhiker's Guide to the Galaxy. Brain the size of a planet, asked to open doors. Terribly, terribly depressed about everything, and not shy about telling you. He once talked an alien battleship into committing suicide out of sheer existential despair.", category: "hero", art: [" (o) ", " /|\\ ", " | | ", " SAD"], power: 2, cunning: 10, magic: 1, fame: 9, charm: 2),
            NameEntry(name: "K-9", source: "Famous Robots", description: "The Doctor's faithful robot dog. Affirmative, Master. K-9 Mark III defended Sarah Jane Smith with a nose laser and an unshakeable sense of duty. He plays chess, solves equations, and occasionally saves the universe — all while rolling on tiny wheels and calling everyone 'Master' or 'Mistress'.", category: "hero", art: [" ___ ", " |o|>", " |_| ", " WOOF"], power: 5, cunning: 8, magic: 3, fame: 8, charm: 9),
            NameEntry(name: "Roy Batty", source: "Famous Robots", description: "A Nexus-6 replicant who wanted more life. Roy Batty was stronger, faster, and smarter than any human, but was given only four years to live. In his final moments, he saved the man sent to kill him and delivered the most beautiful death speech in cinema: 'All those moments will be lost in time, like tears in rain.'", category: "hero", art: ["  O  ", " \\|/", " /|\\ ", " REP"], power: 10, cunning: 7, magic: 1, fame: 9, charm: 8),

            // 80s Fantasy Films
            NameEntry(name: "Madmartigan", source: "Willow (1988)", description: "The greatest swordsman who ever lived — just ask him. Val Kilmer's rogue warrior in Willow was charming, reckless, and surprisingly heroic when it counted. Locked in a cage when we meet him, he talks his way out with nothing but charisma. His romance with Sorsha involved a love potion, a snowball fight, and a stolen kiss on a battlefield.", category: "hero", art: ["  o  ", " /|X ", " / \\ ", " SWD"], power: 8, cunning: 7, magic: 1, fame: 8, charm: 10),
            NameEntry(name: "Willow", source: "Willow (1988)", description: "Willow Ufgood, a Nelwyn farmer who dreamed of being a sorcerer. When he found an abandoned baby destined to overthrow an evil queen, he could have walked away. Instead, this small farmer became the bravest member of the party. He proved that heroes come in all sizes — especially the ones nobody expected.", category: "hero", art: ["  o  ", " /|\\ ", "  |  ", " SML"], power: 3, cunning: 6, magic: 7, fame: 8, charm: 8),
            NameEntry(name: "Atreyu", source: "The NeverEnding Story (1984)", description: "A young warrior of the Plains People, chosen to find a cure for the Childlike Empress. Atreyu crossed the Swamps of Sadness (where his horse Artax was lost), faced the Nothing, and stood before the Southern Oracle. All before his fourteenth birthday. A ranger with the heart of a lion and the determination of a legend.", category: "hero", art: ["  o  ", " /|\\ ", " ~|~ ", " / \\"], power: 7, cunning: 6, magic: 4, fame: 9, charm: 7),
            NameEntry(name: "Conan", source: "Conan the Barbarian (1982)", description: "The Cimmerian. Born on a battlefield, orphaned by Thulsa Doom, enslaved at the Wheel of Pain, and trained as a gladiator. What is best in life? To crush your enemies, see them driven before you, and hear the lamentation of their women. Arnold Schwarzenegger gave this barbarian a soul beneath the muscle.", category: "hero", art: ["  O  ", " \\|/", " AXE ", " / \\"], power: 10, cunning: 4, magic: 1, fame: 10, charm: 5),
            NameEntry(name: "Connor MacLeod", source: "Highlander (1986)", description: "An immortal Scotsman born in 1518, banished from his village for witchcraft after surviving a mortal wound. Trained by Ramirez, he fought through centuries of history in the great Game. There can be only one. Christopher Lambert brought melancholy grace to a man who watched everyone he loved grow old and die.", category: "hero", art: ["  O  ", " /|\\ ", " SWD ", " / \\"], power: 9, cunning: 5, magic: 5, fame: 9, charm: 6),
            NameEntry(name: "Jareth", source: "Labyrinth (1986)", description: "The Goblin King, played by David Bowie with otherworldly charisma. Jareth stole baby Toby and offered Sarah her dreams in exchange. He juggles crystal balls, sings haunting songs, and rules a labyrinth of impossible geometry. Part villain, part tragic figure — a fey lord who fell in love with a mortal girl.", category: "hero", art: ["  O  ", " *|* ", " /|\\ ", " GOB"], power: 7, cunning: 8, magic: 9, fame: 10, charm: 10),
            NameEntry(name: "Darkness", source: "Legend (1985)", description: "The Lord of Darkness himself, played by Tim Curry in the greatest practical makeup ever created. Towering red horns, cloven hooves, and a voice like velvet thunder. He wanted to destroy all sunlight and plunge the world into eternal night. A villain so magnificent he made evil look like performance art.", category: "hero", art: [" \\V/ ", "  O  ", " /|\\ ", " DRK"], power: 10, cunning: 6, magic: 10, fame: 9, charm: 7),
            NameEntry(name: "Taran", source: "The Black Cauldron (1985)", description: "An assistant pig-keeper in the land of Prydain who dreamed of being a great warrior. Based on Lloyd Alexander's beloved Chronicles of Prydain, Taran proved that heroism isn't about swords and glory — it's about protecting a magical pig called Hen Wen and stopping the Horned King from raising an army of the dead.", category: "hero", art: ["  o  ", " /|\\ ", " PIG ", " / \\"], power: 5, cunning: 5, magic: 3, fame: 6, charm: 7),
            NameEntry(name: "Hawk", source: "Ladyhawke (1985)", description: "Captain Etienne Navarre, cursed by an evil bishop. By day, his beloved Isabeau becomes a hawk. By night, he becomes a wolf. Always together, eternally apart. Rutger Hauer played this doomed knight with stoic grace and a very large sword. The ultimate star-crossed lovers' quest.", category: "hero", art: ["  o  ", " /|\\ ", " ~V~ ", " / \\"], power: 8, cunning: 5, magic: 4, fame: 7, charm: 8),
            NameEntry(name: "Red Sonja", source: "Red Sonja (1985)", description: "A fierce swordswoman blessed by a goddess after her family was murdered. Brigitte Nielsen played the flame-haired warrior who swore no man would have her unless he could defeat her in fair combat. She needs no rescuing, no sidekick, and no permission. The original warrior woman of sword-and-sorcery cinema.", category: "hero", art: ["  O  ", " /|X ", " SWD ", " / \\"], power: 9, cunning: 5, magic: 2, fame: 8, charm: 7),
            NameEntry(name: "Beast Master", source: "The Beastmaster (1982)", description: "Dar, the last of his people, born with the power to communicate with animals. A black tiger, two ferrets, and an eagle became his companions in a quest against the sorcerer Maax. Marc Singer brought warmth to this barbarian-with-a-heart, proving that a hero's greatest weapon is friendship with nature.", category: "hero", art: ["  o  ", " /|\\ ", " EGL ", " / \\"], power: 7, cunning: 6, magic: 5, fame: 7, charm: 7),
            NameEntry(name: "Valerian", source: "Dragonslayer (1981)", description: "Galen Bradwarden, a sorcerer's apprentice who inherited his master's quest to slay the dragon Vermithrax Pejorative. Armed with a magic amulet and more courage than skill, he faced the last and greatest dragon. Dragonslayer featured the most realistic dragon in cinema until CGI arrived — and some say still does.", category: "hero", art: ["  o  ", " *|* ", " /|\\ ", " DRG"], power: 5, cunning: 6, magic: 7, fame: 7, charm: 6),

            // 80s Fantasy Books
            NameEntry(name: "Elric", source: "Michael Moorcock", description: "The albino emperor of Melnibone, last of an ancient decadent race, wielder of the black runesword Stormbringer that drinks the souls of those it slays — including, inevitably, everyone Elric loves. Moorcock's eternal champion is the anti-Conan: frail, philosophical, drug-dependent, and cursed by his own weapon.", category: "hero", art: ["  O  ", " /|! ", " BLD ", " / \\"], power: 8, cunning: 7, magic: 9, fame: 9, charm: 5),
            NameEntry(name: "Ged", source: "Ursula K. Le Guin", description: "Sparrowhawk, the greatest mage of Earthsea, who learned that true power is knowing your own shadow — literally. As a young student, he recklessly summoned a shadow creature and spent years hunting it across the archipelago, only to discover it was himself. Le Guin's wizard is about wisdom, not fireballs.", category: "hero", art: ["  o  ", " *|* ", " /|\\ ", " SEA"], power: 5, cunning: 8, magic: 10, fame: 9, charm: 6),
            NameEntry(name: "Drizzt", source: "R.A. Salvatore", description: "Drizzt Do'Urden, a dark elf who rejected the evil of Menzoberranzan and fled to the surface world. With his twin scimitars Twinkle and Icingdeath, his panther companion Guenhwyvar, and his unshakeable moral compass, he became the most famous ranger in D&D history. Proof that your birth doesn't define your destiny.", category: "hero", art: ["  o  ", " X|X ", " /|\\ ", " ELF"], power: 9, cunning: 8, magic: 4, fame: 10, charm: 7),
            NameEntry(name: "Raistlin", source: "Dragonlance", description: "Raistlin Majere, the sickly mage with golden skin and hourglass eyes that see all things as dying. He is brilliant, ambitious, and ruthlessly pragmatic. He chose the Black Robes of evil magic, challenged the gods themselves, and nearly won. The most compelling villain-hero in fantasy — you never stop wanting him to be redeemed.", category: "hero", art: ["  o  ", " *|* ", " BLK ", " |||"], power: 4, cunning: 10, magic: 10, fame: 9, charm: 3),
            NameEntry(name: "Tasslehoff", source: "Dragonlance", description: "Tasslehoff Burrfoot, kender extraordinaire. He is NOT a thief — he just finds things. In your pockets. On your belt. In your locked safe. Fearless to the point of foolishness, endlessly curious, and the most annoying companion in fantasy literature. Also, somehow, the bravest. He faced a god and didn't flinch.", category: "hero", art: ["  o  ", " /|\\ ", " BAG ", " / \\"], power: 2, cunning: 9, magic: 1, fame: 8, charm: 10),
            NameEntry(name: "Rincewind", source: "Terry Pratchett", description: "The worst wizard on the Discworld. He can't cast a single spell because the most powerful spell ever written lodged in his brain and scared all the others away. His chief skill is running away, which he has elevated to an art form. His Luggage follows him everywhere on hundreds of tiny legs. Somehow, he always saves the world.", category: "hero", art: ["  o  ", " /|\\ ", " RUN ", " / \\"], power: 1, cunning: 6, magic: 2, fame: 8, charm: 5),
            NameEntry(name: "Granny Weatherwax", source: "Terry Pratchett", description: "Esmerelda Weatherwax, the most powerful witch on the Discworld. She doesn't do magic — she does headology, which is much more effective. She can Borrow the minds of animals, stare down vampires, and make you do what she wants by simply raising an eyebrow. She is not nice. She is good. There's a difference.", category: "hero", art: ["  O  ", " /|\\ ", " HAT ", " / \\"], power: 5, cunning: 10, magic: 9, fame: 8, charm: 3),
            NameEntry(name: "Belgarion", source: "David Eddings", description: "Garion, a farmboy raised by his aunt (who happens to be a three-thousand-year-old sorceress) who discovers he's the heir to an ancient throne and the chosen vessel of a cosmic prophecy. He must recover a stolen magical orb and face the mad god Torak. It's always a farmboy. Always.", category: "hero", art: ["  o  ", " /|\\ ", " ORB ", " / \\"], power: 7, cunning: 5, magic: 8, fame: 7, charm: 7),
            NameEntry(name: "Fafhrd", source: "Fritz Leiber", description: "A seven-foot northern barbarian with a poet's soul and a thief's instincts, from the frozen Waste of Nehwon. With his partner the Grey Mouser, he defined the sword-and-sorcery buddy adventure. Leiber created the original mismatched duo — the big dreamy fighter and the small cunning rogue.", category: "hero", art: ["  O  ", " /|\\ ", " BIG ", " / \\"], power: 8, cunning: 6, magic: 2, fame: 8, charm: 7),
            NameEntry(name: "Grey Mouser", source: "Fritz Leiber", description: "A small, quick swordsman and former wizard's apprentice from the city of Lankhmar. The original rogue archetype — before D&D codified the class, the Grey Mouser was picking locks, backstabbing villains, and spending his loot on wine and questionable romantic choices. He and Fafhrd are the eternal adventuring party.", category: "hero", art: ["  o  ", " /|\\ ", " DAG ", " / \\"], power: 6, cunning: 10, magic: 4, fame: 8, charm: 8),
            NameEntry(name: "Thomas Covenant", source: "Stephen Donaldson", description: "A leper transported to a land of magic he refuses to believe in. Donaldson's anti-hero is deliberately unlikeable — he commits a terrible act upon arrival and spends three trilogies wrestling with guilt, disbelief, and wild magic he can't control. The most morally complex protagonist in fantasy. Not for the faint-hearted.", category: "hero", art: ["  o  ", " /|\\ ", " WLD ", " / \\"], power: 7, cunning: 4, magic: 9, fame: 7, charm: 1),

            // Additional Book Heroes
            NameEntry(name: "Tenar", source: "Ursula K. Le Guin", description: "Born Arha, the Eaten One, priestess of the Nameless Ones in the Tombs of Atuan. She lived in darkness, serving ancient powers, until the wizard Ged came seeking the Ring of Erreth-Akbe. She chose light over duty, freedom over ritual, and became Tenar — a woman who defined herself rather than being defined by gods.", category: "hero", art: ["  o  ", " /|\\ ", " TOM ", " ~~~"], power: 4, cunning: 7, magic: 6, fame: 8, charm: 7, year: 1971),
            NameEntry(name: "John Carter", source: "Edgar Rice Burroughs", description: "A Confederate cavalry officer mysteriously transported to Mars — Barsoom, where the lower gravity gave him superhuman strength. He fought four-armed Tharks, won the love of Princess Dejah Thoris, and became Warlord of Mars. Burroughs invented planetary romance in 1912 and every space hero since carries a piece of John Carter.", category: "hero", art: [" \\O/ ", " /|\\ ", " MARS", " / \\"], power: 9, cunning: 6, magic: 1, fame: 8, charm: 7, year: 1912),
            NameEntry(name: "Conan", source: "Robert E. Howard", description: "The original Cimmerian, created by Robert E. Howard in 1932. Before the films, before the comics, Conan was a literary barbarian — not just a brute but a thief, a pirate, a mercenary, and eventually a king. Howard's Conan is smarter and more nuanced than his imitators. He defined sword and sorcery.", category: "hero", art: ["  O  ", " \\|/", " SWD ", " / \\"], power: 10, cunning: 6, magic: 1, fame: 10, charm: 5, year: 1932),
            NameEntry(name: "Aragorn", source: "J.R.R. Tolkien", description: "Strider, the Ranger of the North. Heir of Isildur, who waited eighty-seven years for his crown. He led the Fellowship, faced the Paths of the Dead, and drew the armies of Mordor to the Black Gate as a diversion. His love for Arwen cost her immortality. The king who returned.", category: "hero", art: ["  O  ", " /|X ", " SWD ", " / \\"], power: 9, cunning: 8, magic: 4, fame: 10, charm: 8, year: 1954),
            NameEntry(name: "DEATH", source: "Terry Pratchett", description: "A seven-foot skeleton in a black robe who speaks IN CAPITAL LETTERS. He rides a pale horse called Binky, has a granddaughter called Susan, and takes a professional interest in humanity. He once tried being human and found it bewildering. The most beloved personification of mortality in literature. DO NOT FEED THE ELEPHANT.", category: "hero", art: [" ___ ", " |O| ", " /|\\ ", " SKL"], power: 10, cunning: 5, magic: 10, fame: 9, charm: 8, year: 1983),
            NameEntry(name: "Corwin", source: "Roger Zelazny", description: "Prince of Amber, the one true city of which all other worlds — including Earth — are mere shadows. Corwin woke in a hospital bed with amnesia, discovered he was an immortal prince, and walked the Pattern to reclaim his birthright. Zelazny's Chronicles of Amber blend swashbuckling with cosmology. Everything is a reflection.", category: "hero", art: ["  O  ", " /|X ", " AMB ", " / \\"], power: 8, cunning: 9, magic: 7, fame: 7, charm: 8, year: 1970),
            NameEntry(name: "Corum", source: "Michael Moorcock", description: "Prince Corum Jhaelen Irsei, the Prince in the Scarlet Robe. Last of the Vadhagh, he lost his hand and eye and replaced them with the Hand of Kwll and the Eye of Rhynn — grafts from dead gods that let him summon the dead to fight. Another face of Moorcock's Eternal Champion, elegant where Elric is tormented.", category: "hero", art: ["  O  ", " /|! ", " EYE ", " / \\"], power: 7, cunning: 7, magic: 8, fame: 7, charm: 6, year: 1971),
            NameEntry(name: "Sauron", source: "J.R.R. Tolkien", description: "The Dark Lord, Lieutenant of Morgoth, forger of the One Ring. Once a Maia spirit of great skill, he fell into darkness and spent three ages trying to dominate Middle-earth. He poured his power into a golden ring and lost everything when a hobbit dropped it into a volcano. The greatest villain in fantasy.", category: "hero", art: [" \\V/ ", " |O| ", " EYE ", " |||"], power: 10, cunning: 9, magic: 10, fame: 10, charm: 3, year: 1954),
            NameEntry(name: "Skeletor", source: "He-Man (1983)", description: "Lord of Snake Mountain, skull-faced nemesis of He-Man. His plans to conquer Castle Greyskull are endlessly thwarted, but he never stops trying. Beneath the buffoonery of the cartoon, Skeletor is a genuinely menacing villain — a sorcerer of immense power trapped in an endless cycle of failure. NYEH HEH HEH!", category: "hero", art: [" SKL ", "  O  ", " /|\\ ", " / \\"], power: 8, cunning: 7, magic: 9, fame: 9, charm: 4, year: 1983),
            NameEntry(name: "Ming the Merciless", source: "Flash Gordon (1934)", description: "Emperor of Mongo, tyrant of a thousand worlds. Ming rules through fear, technology, and a magnificent wardrobe. He is Flash Gordon's eternal nemesis — cruel, intelligent, and utterly without mercy. Every space villain since owes something to Ming: the pointed beard, the flowing robes, the casual cruelty of absolute power.", category: "hero", art: [" \\V/ ", "  O  ", " /|\\ ", " IMP"], power: 9, cunning: 8, magic: 7, fame: 9, charm: 4, year: 1934),

            // 70s & 80s TV
            NameEntry(name: "He-Man", source: "He-Man (1983)", description: "Prince Adam of Eternia raises the Sword of Power and becomes He-Man, the most powerful man in the universe. By the power of Greyskull! With Battle Cat at his side, he defends Castle Greyskull against the forces of Skeletor. Also, every episode ends with a moral lesson. A paladin in every sense.", category: "hero", art: [" \\O/ ", " /|\\ ", " SWD ", " / \\"], power: 10, cunning: 3, magic: 6, fame: 10, charm: 7),
            NameEntry(name: "Lion-O", source: "ThunderCats (1985)", description: "Lord of the ThunderCats, wielder of the Sword of Omens. 'Thunder, Thunder, ThunderCats, HO!' Lion-O was a boy in a man's body — his suspension capsule aged him during the flight from Thundera. He must learn to lead while wielding Sight Beyond Sight. A young king with an ancient blade and everything to prove.", category: "hero", art: [" \\O/ ", " /|\\ ", " CAT ", " / \\"], power: 9, cunning: 5, magic: 7, fame: 9, charm: 7),

            // 60s-80s Kids TV & Animation
            NameEntry(name: "Noggin", source: "Noggin the Nog (1959)", description: "Noggin was the gentle prince of the Nogs, kind-hearted ruler of the icy fjords. Never violent, Noggin solved every problem with wisdom, friendship, and hot soup. His nemesis Nogbad the Bad schemed endlessly, but good always prevailed in Oliver Postgate's Norse saga. A cleric by temperament — he'd rather heal than harm.", category: "hero", art: ["  O  ", " /|\\ ", " NOG ", " \\_/"], power: 3, cunning: 5, magic: 4, fame: 7, charm: 9),
            // Noggin villains
            NameEntry(name: "Nogbad the Bad", source: "Noggin the Nog (1959)", description: "The scheming uncle of Prince Noggin, forever plotting to steal the crown of the Nogs. Nogbad's plans are elaborate, his machines are improbable, and his defeat is inevitable. He is the perfect villain for a gentle saga — menacing enough to create tension, foolish enough to always lose. Oliver Postgate's finest scoundrel.", category: "hero", art: [" \\V/ ", "  O  ", " /|\\ ", " BAD"], power: 4, cunning: 7, magic: 3, fame: 7, charm: 5, year: 1959),

            NameEntry(name: "The Doctor", source: "Doctor Who (1963)", description: "A Time Lord from Gallifrey who stole a TARDIS and never stopped running. The Doctor has saved Earth so many times it is practically a hobby. Regenerating into new forms, wielding only a sonic screwdriver, defeating monsters with intelligence rather than violence. The longest-running science fiction show in history.", category: "hero", art: ["  O  ", " /|\\ ", " WHO ", " BOX"], power: 5, cunning: 10, magic: 7, fame: 10, charm: 9, year: 1963),
            NameEntry(name: "Davros", source: "Doctor Who (1963)", description: "Creator of the Daleks. A crippled Kaled scientist who saw the future of his race and decided it was extermination. Davros built the ultimate weapon — mutants inside armoured shells — and lost control of his own creation. He is the dark mirror of the Doctor: both geniuses, but one chose compassion and the other chose power.", category: "hero", art: [" (O) ", " /|\\ ", " DAL ", " ~~~"], power: 8, cunning: 10, magic: 6, fame: 9, charm: 2, year: 1975),
            NameEntry(name: "Avon", source: "Blake's 7 (1978)", description: "Kerr Avon, computer genius and reluctant rebel. He joined Blake's revolution not out of idealism but because the alternative was prison. Cold, sarcastic, and brilliant, Avon trusted machines more than people — and was usually right to do so. Paul Darrow played him with ice-cold charisma. The anti-hero before it was fashionable.", category: "hero", art: ["  O  ", " ]|[ ", " GUN ", " / \\"], power: 6, cunning: 10, magic: 1, fame: 7, charm: 5, year: 1978),
            NameEntry(name: "Ulysses", source: "Ulysses 31 (1981)", description: "Captain Ulysses, transported across the galaxy by the wrath of the gods after destroying the Cyclops. His crew frozen in suspended animation, he wanders the cosmos with his son Telemachus, the alien girl Yumi, and the robot Nono, seeking the Kingdom of Hades to free his companions. Homer's Odyssey retold among the stars.", category: "hero", art: ["  O  ", " /|\\ ", " ★  ", " / \\"], power: 8, cunning: 7, magic: 3, fame: 7, charm: 7, year: 1981),
            NameEntry(name: "Esteban", source: "Mysterious Cities of Gold (1982)", description: "Child of the Sun, orphan of Barcelona, seeker of the lost Cities of Gold in the New World. Esteban can summon sunlight through sheer willpower. With Zia and Tao, he discovered the golden condor — a solar-powered flying machine left by a lost civilisation. One of the greatest animated adventures ever made.", category: "hero", art: ["  o  ", " /|\\ ", " SUN ", " / \\"], power: 4, cunning: 6, magic: 7, fame: 7, charm: 8, year: 1982),
            NameEntry(name: "Robin of Loxley", source: "Robin of Sherwood (1984)", description: "Herne's Son, the hooded man of Sherwood Forest. This Robin Hood was touched by pagan magic — chosen by Herne the Hunter to protect the poor of England. Michael Praed and later Jason Connery played a Robin who was part outlaw, part mystic. Clannad's haunting soundtrack made every arrow fly in slow motion.", category: "hero", art: ["  o  ", " /|\\ ", " BOW ", " / \\"], power: 7, cunning: 7, magic: 5, fame: 9, charm: 8, year: 1984),
            NameEntry(name: "Dogtanian", source: "Dogtanian (1981)", description: "The brave young pup who travelled from Gascony to Paris to join the King's Muskehounds. With his friends Porthos, Athos, and Aramis, Dogtanian fought Cardinal Richelieu's guards and won the heart of fair Juliette. One for all, and all for one! This anime adaptation taught a generation about loyalty, honour, and excellent swordsmanship.", category: "hero", art: ["  o  ", " /|X ", " DOG ", " / \\"], power: 6, cunning: 6, magic: 1, fame: 7, charm: 9, year: 1981),

            // ══════════════════════════════════════════
            // DUNGEON NAMES
            // ══════════════════════════════════════════
            NameEntry(name: "Moria", source: "Tolkien", description: "Khazad-dum, the greatest mansion of the dwarves, delved deep beneath the Misty Mountains. Its halls once blazed with mithril light. Then the dwarves dug too deep and woke a Balrog — a demon of the ancient world wreathed in shadow and flame. Now its endless corridors echo with goblin drums and the fellowship's most desperate battle.", category: "dungeon", art: [" /\\/\\ ", " |  | ", " DEEP ", " \\__/"], power: 10, cunning: 5, magic: 8, fame: 10, charm: 3),
            NameEntry(name: "Barad-dur", source: "Tolkien", description: "The Dark Tower of Sauron, raised with the power of the One Ring. A fortress of iron and obsidian so vast it cast a shadow across Mordor. At its summit, the Eye of Sauron — lidless, wreathed in flame — searched endlessly for the Ring. Its foundations could not be destroyed while the Ring survived.", category: "dungeon", art: [" /||\\ ", " |EYE|", " |  | ", " \\||/"], power: 10, cunning: 7, magic: 10, fame: 10, charm: 1),
            NameEntry(name: "Cirith Ungol", source: "Tolkien", description: "The Pass of the Spider, the secret way into Mordor above Minas Morgul. Gollum led Frodo and Sam through Shelob's lair — a darkness so total that even elven light barely pierced it. The tower of Cirith Ungol held Frodo prisoner and Sam had to fight through an entire orc garrison alone to rescue him.", category: "dungeon", art: [" /\\/\\ ", " |WEB|", " PASS ", " / \\ "], power: 8, cunning: 8, magic: 6, fame: 9, charm: 1),
            NameEntry(name: "Isengard", source: "Tolkien", description: "Saruman's fortress at the southern end of the Misty Mountains. The tower of Orthanc rose from its centre — an unbreakable spire of ancient stone. Saruman turned the surrounding gardens into a war factory, breeding Uruk-hai in pits beneath the earth. The Ents marched on Isengard and tore it apart with roots and rage.", category: "dungeon", art: [" /||\\ ", " |  | ", " RING ", " \\||/"], power: 9, cunning: 8, magic: 9, fame: 9, charm: 2),
            NameEntry(name: "Mount Doom", source: "Tolkien", description: "Orodruin, the Fire-mountain — where Sauron forged the One Ring and where Frodo carried it to be destroyed. The Crack of Doom, a chasm of liquid fire inside the volcano, is the only place hot enough to unmake the Ring. In the end, it was Gollum's obsession, not Frodo's will, that cast the Ring into the flames.", category: "dungeon", art: [" /\\/\\ ", " |FIRE|", " LAVA ", " \\~~/ "], power: 10, cunning: 3, magic: 10, fame: 10, charm: 1),
            NameEntry(name: "Minas Morgul", source: "Tolkien", description: "Once Minas Ithil, the Tower of the Moon, a beautiful fortress of Gondor. Taken by the Nazgul, it became Minas Morgul — the Tower of Sorcery. Its walls glow with a corpse-light that makes the living sick. The Witch-king rules from its summit, and the road to Cirith Ungol begins at its cursed gate.", category: "dungeon", art: [" /||\\ ", " |MON|", " GLOW ", " \\||/"], power: 9, cunning: 7, magic: 9, fame: 8, charm: 2, year: 1954),
            NameEntry(name: "Dol Guldur", source: "Tolkien", description: "The Hill of Sorcery in southern Mirkwood, where Sauron hid as 'the Necromancer' for centuries before the War of the Ring. Gandalf entered alone and discovered the truth. The fortress corrupted the forest around it, turning Greenwood the Great into Mirkwood. A dungeon where shadow itself is the enemy.", category: "dungeon", art: [" /\\/\\ ", " |DRK|", " HILL ", " \\__/"], power: 8, cunning: 8, magic: 9, fame: 7, charm: 1, year: 1937),
            NameEntry(name: "Helm's Deep", source: "Tolkien", description: "The fortress of Rohan, carved into the White Mountains behind the Deeping Wall. Ten thousand Uruk-hai marched against it and nearly won. The battle of Helm's Deep is the definitive siege in fantasy — ladders, a culvert bomb, and a dawn charge led by Gandalf. The Glittering Caves behind it are said to be breathtaking.", category: "dungeon", art: [" /\\/\\ ", " WALL ", " |  | ", " \\__/"], power: 9, cunning: 6, magic: 4, fame: 10, charm: 5, year: 1954),

            NameEntry(name: "Tomb of Horrors", source: "D&D Module (1978)", description: "Acererak's tomb, written by Gary Gygax himself. The deadliest dungeon ever published. Thousands of characters have died here — crushed, disintegrated, soul-trapped, or simply erased from existence. Every room is a death trap. Every treasure is bait. The demilich at the end can kill with a glance. Approach with multiple backup characters.", category: "dungeon", art: [" SKULL", " |RIP|", " TRAP ", " ~~~~"], power: 10, cunning: 10, magic: 9, fame: 10, charm: 1),
            NameEntry(name: "Ravenloft", source: "D&D Module (1983)", description: "Castle Ravenloft, domain of Count Strahd von Zarovich, the first vampire in D&D. Gothic horror meets dungeon crawling in a castle perched on a cliff above the village of Barovia. Strahd is a tragic villain — a warrior who made a pact with dark powers for love and lost his humanity. The castle changes with each play.", category: "dungeon", art: [" /\\/\\ ", " |BAT|", " DARK ", " \\  /"], power: 9, cunning: 8, magic: 9, fame: 10, charm: 5),
            NameEntry(name: "White Plume Mountain", source: "D&D Module (1979)", description: "A volcanic dungeon hiding three legendary weapons: Wave (a trident), Whelm (a hammer), and Blackrazor (a soul-drinking sword). Created by the wizard Keraptis, every room is an ingenious puzzle or deadly trap. The dungeon is inside a volcanic mountain that perpetually vents steam — hence the white plume.", category: "dungeon", art: [" /\\/\\ ", " STEAM", " |WPN|", " \\~~/"], power: 8, cunning: 9, magic: 8, fame: 9, charm: 3),
            NameEntry(name: "Caves of Chaos", source: "D&D Module (1979)", description: "A ravine filled with monster-infested caves — the first dungeon for millions of D&D players. The Keep on the Borderlands module introduced an entire generation to tabletop gaming. Multiple caves hold different monster tribes: kobolds, goblins, orcs, gnolls, and worse. At the very end, a temple of chaos awaits the brave.", category: "dungeon", art: [" /\\/\\ ", " CAVE ", " |  | ", " \\__/"], power: 6, cunning: 5, magic: 4, fame: 10, charm: 4),
            NameEntry(name: "Barrier Peaks", source: "D&D Module (1980)", description: "A crashed spaceship in a fantasy world. Expedition to the Barrier Peaks combined science fiction and fantasy decades before it was fashionable. Robots patrol the corridors, ray guns lie beside treasure chests, and a colour-coded keycard system guards the doors. Your fighters will be very confused by the blaster pistols.", category: "dungeon", art: [" /--\\ ", " |UFO|", " BEAM ", " \\--/"], power: 8, cunning: 7, magic: 3, fame: 8, charm: 5),
            NameEntry(name: "Temple of Elemental Evil", source: "D&D Module (1985)", description: "The ruined temple near the village of Hommlet, where cultists of four elemental factions scheme and fight each other. Gary Gygax and Frank Mentzer's mega-adventure spans four dungeon levels, each dedicated to Earth, Air, Fire, or Water. At the bottom lurks Zuggtmoy, the Demon Queen of Fungi. Bring a large party.", category: "dungeon", art: [" /\\/\\ ", " EVIL ", " |EE| ", " \\__/"], power: 9, cunning: 8, magic: 9, fame: 9, charm: 2, year: 1985),
            NameEntry(name: "Isle of Dread", source: "D&D Module (1981)", description: "A tropical island of dinosaurs, pirates, and lost civilisations. The Isle of Dread was D&D's first wilderness adventure — a hex-crawl across jungles and mountains to find a ruined temple and its treasure. There are actual dinosaurs. And kopru. And a volcano. It is basically D&D does King Kong meets Jurassic Park.", category: "dungeon", art: [" /\\/\\ ", " ISLE ", " DINO ", " ~~~~"], power: 7, cunning: 5, magic: 5, fame: 8, charm: 6, year: 1981),

            NameEntry(name: "Melnibone", source: "Michael Moorcock", description: "The Dragon Isle, home of Elric's dying empire. For ten thousand years the Melniboneans ruled with dragon fire and demon pacts, building a civilisation of exquisite cruelty and beauty. Their dreaming towers rise from an island that exists partly in another dimension. The last great empire of Chaos.", category: "dungeon", art: [" /||\\ ", " |DRG|", " ISLE ", " ~~~~"], power: 9, cunning: 8, magic: 10, fame: 8, charm: 4),
            NameEntry(name: "Tanelorn", source: "Michael Moorcock", description: "The eternal city of peace that exists in every version of the multiverse. Every wanderer seeks it; few ever find it. It is the one place where the Eternal Champion can rest between incarnations. Tanelorn offers no excitement, no glory, no adventure — only peace. For weary heroes, that is the greatest treasure of all.", category: "dungeon", art: [" /\\/\\ ", " PEACE", " |  | ", " \\__/"], power: 1, cunning: 5, magic: 8, fame: 8, charm: 10),
            NameEntry(name: "Tombs of Atuan", source: "Ursula K. Le Guin", description: "A sacred labyrinth beneath the desert where the young priestess Tenar served the Nameless Ones. In total darkness, she navigated by touch through tunnels that had swallowed countless victims. When Ged came seeking the other half of the Ring of Erreth-Akbe, she had to choose between ancient duty and human connection.", category: "dungeon", art: [" ____ ", " TOMB ", " |  | ", " DARK"], power: 7, cunning: 6, magic: 9, fame: 8, charm: 3),
            NameEntry(name: "Roke", source: "Ursula K. Le Guin", description: "The island of the wise, home of the great school of wizardry in Earthsea. On Roke, young mages learn the true names of things — for to know a thing's true name is to have power over it. The Immanent Grove stands at its heart, and the Master Patterner walks among the trees. Hogwarts wishes it were Roke.", category: "dungeon", art: [" /\\/\\ ", " MAGE ", " |  | ", " ~~~~"], power: 5, cunning: 8, magic: 10, fame: 8, charm: 7, year: 1968),
            NameEntry(name: "The Dry Land", source: "Ursula K. Le Guin", description: "The land of the dead in Earthsea — not a hell but an endless twilight of dust and silence where the dead walk without purpose. There is no sun, no wind, no water. The wall between life and death was broken, and Ged spent his last magic to mend it. The most haunting afterlife in fantasy.", category: "dungeon", art: [" ---- ", " DUST ", " .... ", " ----"], power: 6, cunning: 4, magic: 10, fame: 7, charm: 1, year: 1972),
            NameEntry(name: "Selidor", source: "Ursula K. Le Guin", description: "The westernmost island of Earthsea, where the dragon Orm Embar lived and where Ged faced the broken wall between life and death. Beyond Selidor there is only the Open Sea and the edge of the world. It is the end of all maps, the last shore — where heroes go when there is nowhere else left.", category: "dungeon", art: [" /\\/\\ ", " WEST ", " |DRG|", " ~~~~"], power: 8, cunning: 5, magic: 9, fame: 7, charm: 4, year: 1972),
            NameEntry(name: "Havnor", source: "Ursula K. Le Guin", description: "The great city of the Archipelago, once the seat of kings in Earthsea. Its tower rises above a harbour that has seen ten thousand ships. When the kings ceased, Havnor fell into squabbling and piracy. Ged restored the king — a young man named Lebannen — and the city shone again. The heart of a world of islands.", category: "dungeon", art: [" /||\\ ", " CITY ", " |  | ", " ~~~~"], power: 5, cunning: 7, magic: 7, fame: 7, charm: 8, year: 1968),
            NameEntry(name: "Lankhmar", source: "Fritz Leiber", description: "The City of Sevenscore Thousand Smokes, greatest metropolis on Nehwon. Its thieves' guild is legendary, its temples countless, and its sewers full of rats (some of which are quite large and disturbingly intelligent). Fafhrd and the Grey Mouser call it home between adventures. The original fantasy city of rogues.", category: "dungeon", art: [" /||\\ ", " CITY ", " SMOK ", " \\||/"], power: 7, cunning: 10, magic: 5, fame: 8, charm: 6, year: 1939),
            NameEntry(name: "Ankh-Morpork", source: "Terry Pratchett", description: "The greatest city on the Discworld — which is to say, the most interesting in the way that a compost heap is interesting. Built on the River Ankh (a body of water you can walk across if you are brave enough), ruled by the Patrician, and policed by Sam Vimes. It smells. It works. It is magnificent.", category: "dungeon", art: [" /||\\ ", " ANKH ", " DISC ", " \\||/"], power: 6, cunning: 9, magic: 7, fame: 9, charm: 8, year: 1983),
            NameEntry(name: "Gormenghast", source: "Mervyn Peake", description: "A castle so vast its inhabitants have forgotten most of its rooms. The Groan family has ruled Gormenghast for seventy-seven generations, performing rituals whose meaning is lost. Steerpike climbs from the kitchens to challenge everything. Peake's gothic masterpiece is a dungeon made of tradition, madness, and crumbling stone.", category: "dungeon", art: [" /||\\ ", " GOTH ", " |  | ", " \\||/"], power: 6, cunning: 8, magic: 4, fame: 8, charm: 7, year: 1950),
            NameEntry(name: "Cimmeria", source: "Robert E. Howard", description: "A bleak, grey land of hills and forests, birthplace of Conan. The Cimmerians are a fierce, dark-haired people who worship Crom — a god who gives you nothing but the strength to fight. Howard described it as perpetually overcast, perpetually dangerous, and perpetually producing the hardest warriors in the Hyborian Age.", category: "dungeon", art: [" /\\/\\ ", " GREY ", " |  | ", " \\__/"], power: 9, cunning: 4, magic: 2, fame: 8, charm: 2, year: 1932),
            NameEntry(name: "Barsoom", source: "Edgar Rice Burroughs", description: "Mars as Burroughs imagined it: a dying world of red deserts, ancient canals, and warring city-states. The atmosphere is thin, the oceans are gone, and four-armed green warriors roam the dead sea-bottoms. Barsoom has two moons, eight-legged beasts called thoats, and a princess worth crossing a planet for.", category: "dungeon", art: [" /\\/\\ ", " MARS ", " |  | ", " ~~~~"], power: 8, cunning: 6, magic: 4, fame: 8, charm: 6, year: 1912),

            // Film & TV Locations
            NameEntry(name: "Nostromo", source: "Alien (1979)", description: "USCSS Nostromo, a commercial towing vessel. Crew of seven. Dark corridors, dripping condensation, chains hanging from ceilings, and something hunting the crew. Ridley Scott's spaceship is the ultimate dungeon — claustrophobic, industrial, and inescapable. The air ducts are just big enough for a xenomorph.", category: "dungeon", art: [" /--\\ ", " |SHIP|", " DARK ", " \\--/"], power: 8, cunning: 7, magic: 1, fame: 10, charm: 2),
            NameEntry(name: "Trantor", source: "Isaac Asimov", description: "The city-planet at the heart of the Galactic Empire. An entire world covered in metal, housing forty billion people in interconnected domes. When the Empire fell, Trantor's surface crumbled and its inhabitants returned to farming between the ruins. The ultimate megadungeon — a planet-sized ruin of a fallen civilisation.", category: "dungeon", art: [" /--\\ ", " CITY ", " MEGA ", " \\--/"], power: 7, cunning: 9, magic: 3, fame: 9, charm: 4),

            NameEntry(name: "Castle Greyskull", source: "He-Man (1983)", description: "A skull-shaped fortress holding the secrets of the universe on the planet Eternia. Castle Greyskull is the source of He-Man's power and Skeletor's obsession. Inside, the Sorceress guards ancient magic. The jawbridge entrance is one of the most iconic images in 1980s pop culture. By the power of Greyskull!", category: "dungeon", art: [" SKULL", " |  | ", " GATE ", " \\__/"], power: 10, cunning: 5, magic: 10, fame: 10, charm: 6),
            NameEntry(name: "The Labyrinth", source: "Labyrinth (1986)", description: "Thirteen hours to solve it, or the baby becomes a goblin forever. Jim Henson's Labyrinth is a maze of impossible geometry, trick doors, and unhelpful creatures. The rules change whenever the Goblin King feels like it. It's not fair — but as Sarah learned, that's exactly the point. The journey matters more than the destination.", category: "dungeon", art: [" /\\/\\ ", " MAZE ", " |??| ", " \\__/"], power: 6, cunning: 10, magic: 8, fame: 10, charm: 8),
            NameEntry(name: "Fantasia", source: "The NeverEnding Story (1984)", description: "A world being consumed by the Nothing — the void left when humans stop dreaming. Fantasia is not a dungeon in the traditional sense but a dying realm that contains every story ever imagined. The Ivory Tower crumbles, the Swamps of Sadness claim the brave, and only a human child's imagination can restore what was lost.", category: "dungeon", art: [" ~~~~ ", " VOID ", " |  | ", " ~~~~"], power: 5, cunning: 4, magic: 10, fame: 10, charm: 9),
            NameEntry(name: "Snake Mountain", source: "He-Man (1983)", description: "Skeletor's lair on Eternia — a mountain shaped like a coiled serpent with a gaping mouth for an entrance. Inside, Skeletor plots his endless schemes to conquer Castle Greyskull, surrounded by his bumbling henchmen Evil-Lyn, Beast Man, and Trap Jaw. The ultimate villain's headquarters, designed by someone who really loved snakes.", category: "dungeon", art: [" /\\/\\ ", " SNAKE", " |SSS|", " \\__/"], power: 8, cunning: 7, magic: 7, fame: 9, charm: 3),
            NameEntry(name: "Death Star", source: "Star Wars (1977)", description: "That is no moon. The Galactic Empire's ultimate weapon — a space station the size of a small moon with a superlaser capable of destroying a planet. Its one weakness: a thermal exhaust port, two metres wide, leading directly to the main reactor. The biggest dungeon crawl in cinema. Watch out for the trash compactor.", category: "dungeon", art: [" /--\\ ", " |DS| ", " BEAM ", " \\--/"], power: 10, cunning: 6, magic: 3, fame: 10, charm: 2, year: 1977),
            NameEntry(name: "Skull Island", source: "King Kong (1933)", description: "A fog-shrouded island where dinosaurs still roam and a giant ape rules from a mountaintop. Beyond the great wall, the jungle is lethal — every vine might be a snake, every shadow might be a predator. Kong is king here, and the natives know enough to stay behind the wall. The original monster island.", category: "dungeon", art: [" /\\/\\ ", " SKULL", " KONG ", " ~~~~"], power: 9, cunning: 4, magic: 3, fame: 10, charm: 5, year: 1933),
            NameEntry(name: "Krell Laboratory", source: "Forbidden Planet (1956)", description: "Buried beneath the surface of Altair IV, the Krell — an ancient civilisation — built a machine twenty miles across. It could materialise thought into reality. The Krell forgot one thing: the monsters of the id. Dr Morbius found their laboratory and their power. The machine still works. The monsters still come at night.", category: "dungeon", art: [" /--\\ ", " KREL ", " MIND ", " \\--/"], power: 9, cunning: 9, magic: 8, fame: 8, charm: 3, year: 1956),
        ]
    }
    // swiftlint:enable function_body_length

    func showNameLore() {
        clearTerminal()
        printTitle("Name Lore")
        printWrapped("Ancient scrolls listing the heroes and dungeons whose names echo through the ages.", indent: 2, color: .dimGreen)
        print("")

        // Animated dragon GIF
        DispatchQueue.main.async {
            self.dragonGifName = "dragon_flapping"
        }
        print("")

        showMenu(["Heroes & Villains", "Dungeon Names"])

        closeHandler = { [weak self] in self?.showHowToPlay() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let cat = choice == 1 ? "hero" : "dungeon"
            self.showNameLoreList(category: cat)
        }
    }

    private func showNameLoreList(category: String) {
        nameLoreAnimTimer?.invalidate()
        nameLoreAnimTimer = nil
        clearTerminal()

        let title = category == "hero" ? "Heroes & Villains" : "Dungeon Names"
        printTitle(title)
        let entries = nameEntries.filter { $0.category == category }
        if category == "hero" {
            printWrapped("\(entries.count) characters from books, films, TV, comics and games. Each has a character card with stats.", indent: 2, color: .dimGreen)
        } else {
            printWrapped("\(entries.count) dungeon names drawn from classic fantasy. Each has a card with danger and puzzle ratings.", indent: 2, color: .dimGreen)
        }
        print("")

        // Build clusters with entry counts
        var clusterOrder: [String] = []
        var clusterSources: [String: Set<String>] = [:]
        for e in entries {
            let cluster = nameLoreCluster(for: e.source)
            if clusterSources[cluster] == nil {
                clusterOrder.append(cluster)
                clusterSources[cluster] = []
            }
            clusterSources[cluster]?.insert(e.source)
        }

        var menuNames: [String] = []
        for cluster in clusterOrder {
            let sources = clusterSources[cluster] ?? []
            let count = entries.filter { sources.contains($0.source) }.count
            menuNames.append("\(cluster) (\(count))")
        }

        menuNames.append("Browse Selection")

        // Dice button shows a random card
        rerollHandler = { [weak self] in
            guard let self = self, !entries.isEmpty else { return }
            let r = Int.random(in: 0..<entries.count)
            self.showNameCard(entries, index: r, onBack: { self.showNameLoreList(category: category) })
        }

        closeHandler = { [weak self] in self?.showNameLore() }

        showPaginatedMenuOptions(menuNames, pinned: ["Help"], handler: { [weak self] idx in
            guard let self = self else { return }
            // Last item in menuNames (before Help) is "Browse Selection"
            if idx == menuNames.count - 1 {
                self.showNameLoreClusterList(category: category, sources: nil, clusterName: nil)
                return
            }
            guard idx >= 0 && idx < clusterOrder.count else { return }
            let cluster = clusterOrder[idx]
            let sources = Array(clusterSources[cluster] ?? [])
            self.showNameLoreClusterList(category: category, sources: sources, clusterName: cluster)
        }, pinnedHandler: { [weak self] _ in
            self?.showNameLoreHelp(category: category)
        })
    }

    /// Show names filtered by source cluster (or all if sources is nil)
    private func showNameLoreClusterList(category: String, sources: [String]?, clusterName: String?) {
        nameLoreAnimTimer?.invalidate()
        nameLoreAnimTimer = nil
        clearTerminal()

        let allEntries = nameEntries.filter { $0.category == category }
        let filtered: [NameEntry]
        let title: String
        if let srcs = sources {
            filtered = allEntries.filter { srcs.contains($0.source) }
            title = clusterName ?? "Names"
        } else {
            filtered = allEntries
            title = category == "hero" ? "All Heroes & Villains" : "All Dungeons"
        }

        printTitle(title)
        print("  \(filtered.count) names — tap to see character card", color: .dimGreen)
        print("")

        let menuNames = filtered.map { $0.name }

        // Dice button: show random card
        rerollHandler = { [weak self] in
            guard let self = self, !filtered.isEmpty else { return }
            let r = Int.random(in: 0..<filtered.count)
            self.showNameCard(filtered, index: r, onBack: { self.showNameLoreClusterList(category: category, sources: sources, clusterName: clusterName) })
        }

        closeHandler = { [weak self] in self?.showNameLoreList(category: category) }

        showPaginatedMenuOptions(menuNames, pinned: ["Help"], handler: { [weak self] idx in
            guard let self = self, idx >= 0 && idx < filtered.count else { return }
            let selected = filtered[idx]
            if let fullIdx = allEntries.firstIndex(where: { $0.name == selected.name && $0.source == selected.source }) {
                self.showNameCard(allEntries, index: fullIdx)
            }
        }, pinnedHandler: { [weak self] _ in
            self?.showNameLoreHelp(category: category)
        })
    }

    private func showNameLoreHelp(category: String) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Name Lore Help")
        print("")

        printWrapped("Each name has a character card with five stats rated 1-10. You can swipe or tap arrows to browse cards, or tap the dice for a random card.", indent: 2, color: .dimGreen)
        print("")

        if category == "hero" {
            print("  HERO STATS & D&D", color: .cyan, bold: true)
            print("")
            print("  Power", color: .yellow, bold: true)
            printWrapped("Raw fighting strength. A Power 10 hero like Conan would have STR 18+ and proficiency in heavy weapons. Power 1 (Rincewind) means relying on legs, not arms.", indent: 4, color: .dimGreen)
            print("")
            print("  Cunning", color: .yellow, bold: true)
            printWrapped("Wits, tactics, and trickery. Maps to DEX and INT. Granny Weatherwax (10) would have INT 20 — she outthinks every problem. In D&D terms: Investigation, Insight, and Stealth checks.", indent: 4, color: .dimGreen)
            print("")
            print("  Magic", color: .yellow, bold: true)
            printWrapped("Arcane or divine power. A Magic 10 hero like Raistlin would be a level 20 wizard. Magic 0 means no spellcasting at all — pure martial characters like Conan.", indent: 4, color: .dimGreen)
            print("")
            print("  Fame", color: .yellow, bold: true)
            printWrapped("How well-known in our world. Fame 10 (Conan, Drizzt) means everyone knows the name. This is a fun stat — an obscure but powerful character might score low here.", indent: 4, color: .dimGreen)
            print("")
            print("  Charm", color: .yellow, bold: true)
            printWrapped("Personality and charisma. Maps to CHA. Charm 10 (Madmartigan, Jareth) means you can talk your way out of anything. Charm 1 (Thomas Covenant) means... you cannot.", indent: 4, color: .dimGreen)
        } else {
            print("  DUNGEON STATS & D&D", color: .cyan, bold: true)
            print("")
            print("  Danger", color: .yellow, bold: true)
            printWrapped("Lethality rating. Danger 10 (Tomb of Horrors) means most parties die. In D&D: higher CR encounters, save-or-die traps, and no safe resting spots.", indent: 4, color: .dimGreen)
            print("")
            print("  Puzzle", color: .yellow, bold: true)
            printWrapped("Traps, riddles, and navigation challenges. Puzzle 10 (The Labyrinth) rewards INT and WIS checks. Low Puzzle means straightforward combat encounters.", indent: 4, color: .dimGreen)
            print("")
            print("  Magic", color: .yellow, bold: true)
            printWrapped("Magical energy saturating the location. Magic 10 (Barad-dur) means powerful enchantments, magical traps, and spell-resistant foes. Dispel Magic and Counterspell are essential.", indent: 4, color: .dimGreen)
            print("")
            print("  Fame", color: .yellow, bold: true)
            printWrapped("Cultural recognition. Fame 10 (Moria) means everyone knows it. This helps newer players discover classic locations from fantasy literature and gaming.", indent: 4, color: .dimGreen)
            print("")
            print("  Dread", color: .yellow, bold: true)
            printWrapped("Atmosphere and fear factor. Dread 10 (Mount Doom) would impose WIS saves against Frightened. Low Dread (Tanelorn) means a place of peace and safety.", indent: 4, color: .dimGreen)
        }

        print("")

        print("  WHAT NEXT", color: .cyan, bold: true)
        printWrapped("Swipe or use arrows to browse cards. Tap the dice for a random card. Close (X) to return to the list. No single card wins on every stat — that is the fun of comparing them!", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showNameLoreList(category: category) }
    }

    /// Wrap text to fit inside a card of given width, returning 1 or 2 lines.
    private func cardWrapText(_ text: String, width: Int) -> [String] {
        if text.count <= width { return [text] }
        let words = text.split(separator: " ").map(String.init)
        var line1 = "", line2 = ""
        for word in words {
            if line1.count + (line1.isEmpty ? 0 : 1) + word.count <= width {
                line1 += (line1.isEmpty ? "" : " ") + word
            } else {
                line2 += (line2.isEmpty ? "" : " ") + word
            }
        }
        // If line2 is still too long, truncate it
        if line2.count > width { line2 = String(line2.prefix(width)) }
        return line2.isEmpty ? [line1] : [line1, line2]
    }

    private func showNameCard(_ entries: [NameEntry], index: Int, onBack: (() -> Void)? = nil) {
        nameLoreAnimTimer?.invalidate()
        nameLoreAnimTimer = nil
        clearTerminal()
        suppressAutoScroll = true
        scrollLocked = true

        let entry = entries[index]
        let cardW = 27
        let border = String(repeating: "─", count: cardW)

        // Compute line indices arithmetically (since clearTerminal + print are async)
        // Line 0: top border, 1: name, 2: source, 3: separator, 4...: art
        let topBorderLine = 0
        let artStart = 4
        let artCount = entry.art.count
        let statStart = artStart + artCount + 1  // +1 for separator after art
        let bottomBorderLine = statStart + 5     // 5 stat lines

        // Top border with sparkle corners
        print("  ╔\(border)╗", color: .cyan)

        // Centred name (wrap to 2 lines if needed)
        for line in cardWrapText(entry.name, width: cardW) {
            let pad = max(0, cardW - line.count)
            let left = pad / 2; let right = pad - left
            print("  ║\(String(repeating: " ", count: left))\(line)\(String(repeating: " ", count: right))║", color: .brightGreen, bold: true)
        }

        // Source line (wrap to 2 lines if needed)
        for line in cardWrapText(entry.source, width: cardW) {
            let pad = max(0, cardW - line.count)
            let left = pad / 2; let right = pad - left
            print("  ║\(String(repeating: " ", count: left))\(line)\(String(repeating: " ", count: right))║", color: .yellow)
        }

        print("  ╠\(border)╣", color: .cyan)

        // Individual ASCII art
        for line in entry.art {
            let trimmed = line.count > 25 ? String(line.prefix(25)) : line
            let artPad = max(0, cardW - trimmed.count)
            let aLeft = artPad / 2
            let aRight = artPad - aLeft
            print("  ║\(String(repeating: " ", count: aLeft))\(trimmed)\(String(repeating: " ", count: aRight))║", color: .green)
        }

        print("  ╠\(border)╣", color: .cyan)
        func statBar(_ label: String, _ val: Int) -> String {
            let bar = String(repeating: "█", count: val) + String(repeating: "░", count: 10 - val)
            let lbl = " \(label)".padding(toLength: 8, withPad: " ", startingAt: 0)
            let vStr = "\(val)".padding(toLength: 3, withPad: " ", startingAt: 0)
            let full = "\(lbl)\(bar) \(vStr)"
            return String(full.prefix(cardW))
        }
        let stats: [(String, Int)]
        if entry.category == "hero" {
            stats = [("Power", entry.power), ("Cunning", entry.cunning),
                     ("Magic", entry.magic), ("Fame", entry.fame), ("Charm", entry.charm)]
        } else {
            stats = [("Danger", entry.power), ("Puzzle", entry.cunning),
                     ("Magic", entry.magic), ("Fame", entry.fame), ("Dread", entry.charm)]
        }
        for (label, val) in stats {
            let line = statBar(label, val)
            let sPad = max(0, cardW - line.count)
            print("  ║\(line)\(String(repeating: " ", count: sPad))║", color: .yellow)
        }

        // Bottom border (index already computed as bottomBorderLine above)
        print("  ╚\(border)╝", color: .cyan)

        // Space between card and description
        print("")

        // Description below card
        printWrapped(entry.description, indent: 2, color: .dimGreen)

        let category = entry.category
        closeHandler = { [weak self] in self?.showNameLoreList(category: category) }

        // Swipe navigation
        cardPositionLabel = cardLabel(index + 1, of: entries.count)
        swipeLeftHandler = index + 1 < entries.count ? { [weak self] in
            self?.showNameCard(entries, index: index + 1, onBack: onBack)
        } : nil
        swipeRightHandler = index > 0 ? { [weak self] in
            self?.showNameCard(entries, index: index - 1, onBack: onBack)
        } : nil
        swipeRandomHandler = entries.count > 1 ? { [weak self] in
            let r = Int.random(in: 0..<entries.count)
            self?.showNameCard(entries, index: r, onBack: onBack)
        } : nil

        // Close handler — return to caller or name lore list
        if let onBack = onBack {
            closeHandler = { [weak self] in
                self?.nameLoreAnimTimer?.invalidate()
                self?.nameLoreAnimTimer = nil
                onBack()
            }
        }

        // Animate: sparkle corners + art sway + stat bar pulse
        let sparkles = ["✦", "✧", "★", "☆"]
        let artLines = entry.art
        nameLoreAnimFrame = 0
        nameLoreAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.nameLoreAnimFrame += 1
            let frame = self.nameLoreAnimFrame
            DispatchQueue.main.async {
                // Sparkle corners
                let sp = sparkles[frame % sparkles.count]
                if topBorderLine < self.terminalLines.count {
                    self.terminalLines[topBorderLine].text = "  \(sp)\(border)\(sp)"
                }
                if bottomBorderLine < self.terminalLines.count {
                    self.terminalLines[bottomBorderLine].text = "  \(sp)\(border)\(sp)"
                }

                // Art sway
                let shift = frame % 2 == 0 ? 0 : 1
                for (j, rawLine) in artLines.enumerated() {
                    let lineIdx = artStart + j
                    guard lineIdx < self.terminalLines.count else { continue }
                    let trimmed = rawLine.count > 25 ? String(rawLine.prefix(25)) : rawLine
                    let artPad = max(0, cardW - trimmed.count)
                    let aLeft = artPad / 2 + shift
                    let aRight = max(0, artPad - artPad / 2 - shift)
                    self.terminalLines[lineIdx].text = "  ║\(String(repeating: " ", count: aLeft))\(trimmed)\(String(repeating: " ", count: aRight))║"
                }

                // Stat bar highlight — pulse the highest stat
                let maxStat = stats.max(by: { $0.1 < $1.1 })?.1 ?? 0
                for (i, (label, val)) in stats.enumerated() {
                    let lineIdx = statStart + i
                    guard lineIdx < self.terminalLines.count else { continue }
                    let pulse = (val == maxStat && frame % 2 == 1)
                    let fillChar = pulse ? "▓" : "█"
                    let bar = String(repeating: fillChar, count: val) + String(repeating: "░", count: 10 - val)
                    let lbl = " \(label)".padding(toLength: 8, withPad: " ", startingAt: 0)
                    let vStr = "\(val)".padding(toLength: 3, withPad: " ", startingAt: 0)
                    let full = "\(lbl)\(bar) \(vStr)"
                    let line = String(full.prefix(cardW))
                    let sPad = max(0, cardW - line.count)
                    self.terminalLines[lineIdx].text = "  ║\(line)\(String(repeating: " ", count: sPad))║"
                }
            }
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
            return val == 0 ? Int.max : val  // 0 or unset = unlimited
        }
        set {
            // Store 0 for unlimited (Int.max)
            UserDefaults.standard.set(newValue == Int.max ? 0 : newValue, forKey: "dm_log_context_size")
        }
    }

    var multiplayerEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: "multiplayer_enabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "multiplayer_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "multiplayer_enabled")
        }
    }

    var npcsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "npcs_enabled") == nil { return false }
            return UserDefaults.standard.bool(forKey: "npcs_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "npcs_enabled")
        }
    }

    var poisonEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "poison_enabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "poison_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "poison_enabled")
        }
    }

    /// Track which NPC types the player has encountered across all dungeons
    private var metNPCNames: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "metNPCs") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "metNPCs") }
    }

    func recordNPCEncounter(_ npcType: NPCType) {
        var met = metNPCNames
        met.insert(npcType.rawValue)
        metNPCNames = met
    }

    var hitAnimationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "hit_animations") == nil { return true }
            return UserDefaults.standard.bool(forKey: "hit_animations")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hit_animations")
        }
    }

    var musicEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "music_enabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "music_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "music_enabled")
            if !newValue { SoundManager.shared.stopMusic() }
        }
    }

    var battleSoundsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "battle_sounds_enabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "battle_sounds_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "battle_sounds_enabled")
            SoundManager.shared.battleSoundsEnabled = newValue
        }
    }

    var menuMelodyChoice: Int {
        get { UserDefaults.standard.integer(forKey: "menu_melody") }
        set { UserDefaults.standard.set(newValue, forKey: "menu_melody") }
    }

    var explorationMelodyChoice: Int {
        get { UserDefaults.standard.integer(forKey: "exploration_melody") }
        set { UserDefaults.standard.set(newValue, forKey: "exploration_melody") }
    }

    var combatMelodyChoice: Int {
        get { UserDefaults.standard.integer(forKey: "combat_melody") }
        set { UserDefaults.standard.set(newValue, forKey: "combat_melody") }
    }

    var chatMelodyChoice: Int {
        get { UserDefaults.standard.integer(forKey: "chat_melody") }
        set { UserDefaults.standard.set(newValue, forKey: "chat_melody") }
    }

    private func melodyName(type: String, choice: Int) -> String {
        let names: [String]
        switch type {
        case "menu": names = ["Random", "The Dungeon Awaits", "Forgotten Throne", "Cathedral of Bones"]
        case "exploration": names = ["Random", "Into the Depths", "Whispering Corridors", "The Descent", "Forgotten Halls"]
        case "combat": names = ["Random", "Blades of Fury", "Shields and Steel", "Dragon's Wrath"]
        case "chat": names = ["Random", "Whispered Council", "Flickering Shadows", "Candlelit Murmurs"]
        default: names = ["Random"]
        }
        return choice >= 0 && choice < names.count ? names[choice] : names[0]
    }

    var mapRadius: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "map_radius")
            return val > 0 ? min(val, 3) : 2
        }
        set {
            UserDefaults.standard.set(min(newValue, 3), forKey: "map_radius")
        }
    }

    var gameTimeLimit: Int {  // 0 = off, value in game-minutes
        get { UserDefaults.standard.integer(forKey: "gameTimeLimit") }
        set { UserDefaults.standard.set(newValue, forKey: "gameTimeLimit") }
    }

    var maxButtonsPerScreen: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "maxButtonsPerScreen")
            return val > 0 ? val : 8
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxButtonsPerScreen")
        }
    }

    var longPressDuration: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "longPressDuration")
            return val > 0 ? val : 0.5
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "longPressDuration")
        }
    }

    func effectiveMapRadius() -> Int {
        return torchLit ? mapRadius : 0
    }

    func partyHasTorch() -> Bool {
        return party.contains { char in
            char.inventory.contains { $0.isTorch && ($0.torchLife ?? Item.torchFullLife) > 0 }
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

        let chatEntries = dmChatLog.map { DMChatEntry(isUser: $0.isUser, text: $0.text) }
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
            dmChatLog: chatEntries,
            torchLit: torchLit,
            torchTurnsRemaining: torchTurnsRemaining,
            partyChatLog: partyChatLog.suffix(20).map { $0 },
            monstersSlain: monstersSlain,
            combatsWon: combatsWon
        )

        try? SaveGameManager.shared.save(saveGame)
    }

    // MARK: - Settings

    func showSettings() {
        if currentUndoScreen != settingsScreenKey {
            beginSettingsTracking()
        }
        clearTerminal()
        printTitle("Settings")

        let dm = DMEngine.shared

        print("R. DUNGEON MASTER:", color: .cyan, bold: true)
        if dm.isConfigured {
            print("  \(dm.provider.displayName) — \(dm.adLibLevel.displayName)", color: .brightGreen)
        } else if dm.isAppleModelAvailable {
            print("  Apple On-Device — \(dm.adLibLevel.displayName)", color: .brightGreen)
        } else {
            print("  Basic (no AI)", color: .dimGreen)
        }
        print("")

        print("ACCESSIBILITY:", color: .cyan, bold: true)
        print("  Font: \(fontSizeSetting.displayName)  Hits: \(hitAnimationsEnabled ? "On" : "Off")  Voice: \(SpeechEngine.shared.isEnabled ? "On" : "Off")", color: .dimGreen)
        print("")

        print("MOOD:", color: .cyan, bold: true)
        print("  Music: \(musicEnabled ? "On" : "Off")  Sounds: \(battleSoundsEnabled ? "On" : "Off")", color: .dimGreen)
        print("")

        print("GAMEPLAY:", color: .cyan, bold: true)
        print("  Map: \(mapRadius)  Buttons: \(maxButtonsPerScreen)  Multi: \(multiplayerEnabled ? "On" : "Off")", color: .dimGreen)
        print("")

        print("SAVE:", color: .cyan, bold: true)
        print("  Autosave: \(autosaveInterval.displayName)", color: .dimGreen)
        print("")

        var options = ["DM Settings", "Accessibility", "Mood", "Gameplay", "Saving", "Help"]

        showMenu(options)

        updateSettingsUndoRedo { [weak self] in self?.showSettings() }

        closeHandler = { [weak self] in
            self?.endSettingsTracking()
            self?.clearTerminal()
            self?.showMainMenu()
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = options[choice - 1]
            switch selected {
            case "DM Settings": self.showDMSettingsSubMenu()
            case "Accessibility": self.showAccessibilityMenu()
            case "Mood": self.showMusicSettings()
            case "Gameplay": self.showGameplaySettings()
            case "Saving": self.showSaveSettings()
            case "Help": self.showSettingsHelp()
            default: break
            }
        }
    }

    private func showAbout(onBack: (() -> Void)? = nil) {
        clearTerminal()
        printTitle("About")
        print("")
        print("  D&D 5e ASCII Adventure", color: .brightGreen, bold: true)
        print("")
        printWrapped("A text-based dungeon crawler inspired by classic RPGs and the golden age of adventure gaming.", indent: 2, color: .dimGreen)
        print("")
        print("")

        // Philip ASCII portrait
        let philipArt = [
            "     _.--._",
            "    / /||\\ \\",
            "   | | '' | |",
            "   | \\    / |",
            "    \\ `--` /",
            "     |o  o|",
            "     | \\/ |",
            "     \\    /",
            "    .-`--`-.",
            "   /  ~~~~  \\",
            "  | ~~~~~~~~ |",
            "   \\________/",
        ]
        printLines(philipArt, color: .cyan)
        print("")
        print("  CREATED BY", color: .cyan, bold: true)
        print("  Philip Lewis", color: .brightGreen)
        printWrapped("Game design, creative direction, and relentless testing.", indent: 2, color: .dimGreen)
        print("")
        print("")

        // Claude dragon ASCII art (winking)
        let claudeArt = [
            "        /\\/\\",
            "       / -o \\",
            "      | >~<  |",
            "       \\_--_/",
            "       / /",
            "   .--' /",
            "  /   /`",
            "  \\  `-'  __",
            "   `-. .-'  '.",
            "     `-' )) ) )",
            "        )) ) )",
            "       `-------'",
        ]
        printLines(claudeArt, color: .yellow)
        print("")
        print("  BUILT WITH", color: .yellow, bold: true)
        print("  Claude (Anthropic)", color: .brightGreen)
        printWrapped("Code, monsters, lore, and dungeon mastering by Claude AI.", indent: 2, color: .dimGreen)
        print("")
        print("")
        printWrapped("Made with SwiftUI, imagination, and far too many late nights.", indent: 2, color: .dimGreen)
        print("")
        print("")
        print("COPYRIGHT", color: .cyan, bold: true)
        printWrapped("\u{00A9} 2024-2026 Philip Lewis. All rights reserved.", indent: 2, color: .dimGreen)
        print("")
        print("LICENSE", color: .cyan, bold: true)
        printWrapped("D&D 5e SRD under the Open Gaming License (OGL) v1.0a by Wizards of the Coast LLC.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = onBack ?? { [weak self] in self?.showHowToPlay() }
    }

    private func showAccessibilityMenu() {
        clearTerminal()
        printTitle("Accessibility")
        printWrapped("These settings help adapt the game to your needs — larger text, audio output, and visual aids.", indent: 2, color: .dimGreen)
        print("")

        let speech = SpeechEngine.shared

        print("FONT SIZE:", color: .cyan, bold: true)
        print("  \(fontSizeSetting.displayName)", color: .brightGreen)
        printWrapped("Increase text size if you find the default hard to read.", indent: 2, color: .dimGreen)
        print("")

        print("ICON SIZE:", color: .cyan, bold: true)
        let iconLabel = iconScaleSetting == 0 ? "Normal" : (iconScaleSetting == 1 ? "Large" : "Extra Large")
        print("  \(iconLabel)", color: .brightGreen)
        printWrapped("Scale up the close, return, and microphone icons for easier tapping.", indent: 2, color: .dimGreen)
        print("")

        print("HIT ANIMATIONS:", color: .cyan, bold: true)
        print("  \(hitAnimationsEnabled ? "On" : "Off")", color: hitAnimationsEnabled ? .brightGreen : .dimGreen)
        printWrapped("Small screen flashes when attacks land in combat. Draws attention to the action and adds visual feedback.", indent: 2, color: .dimGreen)
        print("")

        print("DM VOICE:", color: .cyan, bold: true)
        print("  \(speech.isEnabled ? "On" : "Off")", color: speech.isEnabled ? .brightGreen : .dimGreen)
        printWrapped("Text-to-speech narration. Reduces the need to read — helpful for vision difficulties or a hands-free experience.", indent: 2, color: .dimGreen)
        print("")

        print("COMPANION VOICES:", color: .cyan, bold: true)
        let modeLabel = speech.companionVoiceMode == .characterAppropriate ? "Character" : "Random"
        print("  Mode: \(modeLabel)", color: .dimGreen)
        printWrapped("Give party members spoken voices in chat. Configure in Voice Settings.", indent: 2, color: .dimGreen)
        print("")

        print("VOICE MENUS:", color: .cyan, bold: true)
        print("  \(voiceMenuEnabled ? "On" : "Off")", color: voiceMenuEnabled ? .brightGreen : .dimGreen)
        printWrapped("When on, two icons appear on each screen:", indent: 2, color: .dimGreen)
        print("")
        print("  speaker icon — reads the screen aloud", color: .dimGreen)
        print("  mic icon — speak a menu choice", color: .dimGreen)
        print("")
        printWrapped("Voice commands:", indent: 2, color: .dimGreen)
        print("  Say button text (e.g. 'Save')", color: .dimGreen)
        print("  Say a number ('one', 'button two')", color: .dimGreen)
        print("  Say 'back' or 'done' to close", color: .dimGreen)
        print("  Say 'continue' or 'ok' to proceed", color: .dimGreen)
        print("")

        let options = ["Font Size", "Icon Size", hitAnimationsEnabled ? "Hits Off" : "Hits On", speech.isEnabled ? "DM Voice Off" : "DM Voice On", "DM Voice Menu", "Companion Voices", voiceMenuEnabled ? "Voice Menus Off" : "Voice Menus On"]

        var menuOpts = options.map { MenuOption($0) }
        menuOpts.append(MenuOption("Help", tint: .navigation))
        showMenuOptions(menuOpts)
        closeHandler = { [weak self] in self?.showSettings() }
        updateSettingsUndoRedo { [weak self] in self?.showAccessibilityMenu() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == menuOpts.count {
                self.showAccessibilityHelp()
                return
            }
            self.pushSettingsSnapshot()
            let selected = options[choice - 1]
            if selected == "Font Size" {
                self.showFontSizeMenu()
            } else if selected == "Icon Size" {
                self.iconScaleSetting = (self.iconScaleSetting + 1) % 3
                UserDefaults.standard.set(self.iconScaleSetting, forKey: "iconScaleSetting")
                self.showAccessibilityMenu()
            } else if selected.hasPrefix("Hits") {
                self.hitAnimationsEnabled.toggle()
                self.showAccessibilityMenu()
            } else if selected.hasPrefix("DM Voice") {
                speech.isEnabled.toggle()
                self.showAccessibilityMenu()
            } else if selected == "DM Voice Menu" {
                self.showVoiceSettings()
            } else if selected == "Companion Voices" {
                self.showAdventurerVoiceSettings()
                self.closeHandler = { [weak self] in self?.showAccessibilityMenu() }
            } else if selected.hasPrefix("Voice Menus") {
                self.voiceMenuEnabled.toggle()
                UserDefaults.standard.set(self.voiceMenuEnabled, forKey: "voiceMenuEnabled")
                self.showAccessibilityMenu()
            }
        }
    }

    private func showAccessibilityHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Accessibility Help")
        print("")

        print("  FONT SIZE", color: .cyan, bold: true)
        printWrapped("Increase or decrease the text size throughout the game. Helpful if the default font is too small to read comfortably.", indent: 2, color: .dimGreen)
        print("")

        print("  ICON SIZE", color: .cyan, bold: true)
        printWrapped("Scale up the close (X), return, and microphone icons. Cycles through Normal, Large, and Extra Large for easier tapping.", indent: 2, color: .dimGreen)
        print("")

        print("  HIT ANIMATIONS", color: .cyan, bold: true)
        printWrapped("Small screen flashes when attacks land in combat. Turn off if you find the flashing distracting or if you are sensitive to screen flashes.", indent: 2, color: .dimGreen)
        print("")

        print("  DM VOICE", color: .cyan, bold: true)
        printWrapped("Enables text-to-speech narration by the Dungeon Master. Reduces the need to read the screen — helpful for vision difficulties or a hands-free experience.", indent: 2, color: .dimGreen)
        print("")

        print("  DM VOICE MENU", color: .cyan, bold: true)
        printWrapped("Opens the voice configuration screen where you can choose the DM's speaking voice, speed, and pitch.", indent: 2, color: .dimGreen)
        print("")

        print("  COMPANION VOICES", color: .cyan, bold: true)
        printWrapped("Give each party member a unique spoken voice in chat. Choose 'Character' for voices matched to each character or 'Random' for variety.", indent: 2, color: .dimGreen)
        print("")

        print("  VOICE MENUS", color: .cyan, bold: true)
        printWrapped("When on, a speaker icon and microphone icon appear on each screen. The speaker reads the screen aloud; the microphone lets you speak menu choices instead of tapping.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showAccessibilityMenu() }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showAccessibilityMenu() }
    }

    private func showGameplaySettings() {
        clearTerminal()
        printTitle("Gameplay")

        print("MAP RADIUS:", color: .cyan, bold: true)
        let hasTorch = party.contains { (char: Character) in
            char.inventory.contains { $0.name.lowercased().contains("torch") }
        }
        let effective = effectiveMapRadius()
        print("  Setting: \(mapRadius)  Effective: \(effective)\(hasTorch ? "" : " (no torch!)")", color: hasTorch ? .dimGreen : .yellow)
        printWrapped("How far you can see on the dungeon map. Light your torch to see further!", indent: 2, color: .dimGreen)
        print("")

        print("CARD NAVIGATION:", color: .cyan, bold: true)
        print("  \(useArrowNavigation ? "Use Arrows" : "Use Swipe")", color: .brightGreen)
        printWrapped("Use Arrows shows < > arrow buttons and a dice for random on character cards. Use Swipe lets you swipe left/right across the screen to browse cards. Both modes support the random dice.", indent: 2, color: .dimGreen)
        print("")

        print("INFO TIMEOUT:", color: .cyan, bold: true)
        print("  \(String(format: "%.1fs", infoTimeout))", color: .brightGreen)
        printWrapped("How long information screens (search results, listen, examine) stay before auto-dismissing. Tap the close icon to dismiss sooner.", indent: 2, color: .dimGreen)
        print("")

        print("BUTTON LIMIT:", color: .cyan, bold: true)
        print("  \(maxButtonsPerScreen) per screen", color: .brightGreen)
        printWrapped("Maximum buttons shown at once. When a screen has more options, ▸ More and ◂ Back buttons let you page through them. Long-press ▸/◂ to skip 3 pages.", indent: 2, color: .dimGreen)
        print("")

        print("LONG PRESS:", color: .cyan, bold: true)
        print("  \(String(format: "%.1fs", longPressDuration))", color: .brightGreen)
        printWrapped("How long you must hold a button for a long-press action (e.g. long rest, page jump). Lower values make long-press faster to trigger.", indent: 2, color: .dimGreen)
        print("")

        print("NPCs:", color: .cyan, bold: true)
        print("  \(npcsEnabled ? "Enabled" : "Disabled")", color: npcsEnabled ? .brightGreen : .dimGreen)
        printWrapped("Non-player characters spawn in dungeons. They can trade, heal, teach, and give information.", indent: 2, color: .dimGreen)
        print("")

        print("POISON:", color: .cyan, bold: true)
        print("  \(poisonEnabled ? "Enabled" : "Disabled")", color: poisonEnabled ? .brightGreen : .dimGreen)
        printWrapped("When enabled, venomous creatures can poison your party. Cure with antidotes, potions, or rest.", indent: 2, color: .dimGreen)
        print("")

        print("MULTIPLAYER:", color: .cyan, bold: true)
        print("  \(multiplayerEnabled ? "Enabled" : "Disabled")", color: multiplayerEnabled ? .brightGreen : .dimGreen)
        printWrapped("When enabled, you can invite remote players to control party members via Game Centre.", indent: 2, color: .dimGreen)
        print("")

        print("ADVENTURE LOG:", color: .cyan, bold: true)
        let logLimitText = adventureLogLimit == 0 ? "Show All" : "Last \(adventureLogLimit)"
        print("  \(logLimitText)", color: .brightGreen)
        printWrapped("How many log entries to display. 'Show All' can be slow for very long adventures.", indent: 2, color: .dimGreen)
        print("")

        print("TIME LIMIT:", color: .cyan, bold: true)
        let timeLimitText = gameTimeLimit == 0 ? "Off" : formatTimeLimitValue(gameTimeLimit)
        print("  \(timeLimitText)", color: gameTimeLimit == 0 ? .dimGreen : .brightGreen)
        printWrapped("Optional time limit for your adventure. When game time runs out, the game ends in defeat.", indent: 2, color: .dimGreen)
        print("")

        print("IDLE PROMPTS:", color: .cyan, bold: true)
        print("  \(idlePromptsEnabled ? "On" : "Off")", color: idlePromptsEnabled ? .brightGreen : .dimGreen)
        printWrapped("When on, the DM reacts if you take too long — eye blinks on ASCII art, combat hesitation penalties, and save menu nudges.", indent: 2, color: .dimGreen)
        print("")

        #if os(iOS)
        print("KEYBOARD:", color: .cyan, bold: true)
        print("  \(useCustomKeyboard ? "In-App" : "System")", color: .brightGreen)
        printWrapped("In-App keyboard has no globe or microphone buttons. System uses the standard iOS keyboard.", indent: 2, color: .dimGreen)
        print("")
        #endif

        var options = ["Map Radius", useArrowNavigation ? "Use Swipe" : "Use Arrows", "Info Timeout", "Button Limit", "Long Press", npcsEnabled ? "NPCs Off" : "NPCs On", poisonEnabled ? "Poison Off" : "Poison On", multiplayerEnabled ? "Multi Off" : "Multi On", "Log Limit", "Time Limit", idlePromptsEnabled ? "Idle Off" : "Idle On"]
        #if os(iOS)
        options.append(useCustomKeyboard ? "System KB" : "In-App KB")
        #endif
        var menuOpts = options.map { MenuOption($0) }
        menuOpts.append(MenuOption("Help", tint: .navigation))
        showMenuOptions(menuOpts)
        closeHandler = { [weak self] in self?.showSettings() }
        updateSettingsUndoRedo { [weak self] in self?.showGameplaySettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == menuOpts.count {
                self.showGameplaySettingsHelp()
                return
            }
            self.pushSettingsSnapshot()
            let selected = options[choice - 1]
            if selected == "Map Radius" {
                self.showMapRadiusMenu()
            } else if selected.hasPrefix("Use") {
                self.useArrowNavigation.toggle()
                UserDefaults.standard.set(self.useArrowNavigation, forKey: "useArrowNavigation")
                self.showGameplaySettings()
            } else if selected == "Info Timeout" {
                self.showInfoTimeoutMenu()
            } else if selected == "Button Limit" {
                self.showButtonLimitMenu()
            } else if selected == "Long Press" {
                self.showLongPressMenu()
            } else if selected.hasPrefix("NPCs") {
                self.npcsEnabled.toggle()
                self.showGameplaySettings()
            } else if selected.hasPrefix("Poison") {
                self.poisonEnabled.toggle()
                self.showGameplaySettings()
            } else if selected.hasPrefix("Multi") {
                self.multiplayerEnabled.toggle()
                self.showGameplaySettings()
            } else if selected == "Log Limit" {
                self.showLogLimitMenu()
            } else if selected == "Time Limit" {
                self.showTimeLimitMenu()
            } else if selected.hasPrefix("Idle") {
                self.idlePromptsEnabled.toggle()
                UserDefaults.standard.set(self.idlePromptsEnabled, forKey: "idlePromptsEnabled")
                if !self.idlePromptsEnabled {
                    self.stopIdleAnimations()
                    self.cancelCombatIdleTimer()
                    self.cancelSaveMenuIdleTimer()
                }
                self.showGameplaySettings()
            } else if selected.hasSuffix("KB") {
                self.useCustomKeyboard.toggle()
                UserDefaults.standard.set(self.useCustomKeyboard, forKey: "useCustomKeyboard")
                self.showGameplaySettings()
            }
        }
    }

    private func showGameplaySettingsHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Gameplay Help")
        print("")

        print("  MAP RADIUS", color: .cyan, bold: true)
        printWrapped("How far you can see on the dungeon map. A larger radius reveals more rooms but may spoil surprises. Light your torch to see further!", indent: 2, color: .dimGreen)
        print("")

        print("  CARD NAVIGATION", color: .cyan, bold: true)
        printWrapped("Choose how to browse character cards. 'Use Arrows' shows < > buttons and a dice for random. 'Use Swipe' lets you swipe left and right across the screen.", indent: 2, color: .dimGreen)
        print("")

        print("  INFO TIMEOUT", color: .cyan, bold: true)
        printWrapped("How long information screens (search results, listen, examine) stay before auto-dismissing. Shorter means faster gameplay; longer gives you more time to read. Tap the close icon to dismiss sooner.", indent: 2, color: .dimGreen)
        print("")

        print("  BUTTON LIMIT", color: .cyan, bold: true)
        printWrapped("Maximum buttons shown on screen at once. When there are more options than this limit, More and Back buttons let you page through them. Long-press More/Back to skip 3 pages.", indent: 2, color: .dimGreen)
        print("")

        print("  LONG PRESS", color: .cyan, bold: true)
        printWrapped("How long you must hold a button for a long-press action (e.g. long rest, page jump, quick-start). Lower values make long-press faster to trigger.", indent: 2, color: .dimGreen)
        print("")

        print("  NPCs", color: .cyan, bold: true)
        printWrapped("Non-player characters that spawn in dungeons. They can trade items, heal your party, teach skills, and give information. Not all NPCs are truthful!", indent: 2, color: .dimGreen)
        print("")

        print("  MULTIPLAYER", color: .cyan, bold: true)
        printWrapped("When enabled, you can invite remote players to control party members via Game Centre. Each player takes turns controlling their character.", indent: 2, color: .dimGreen)
        print("")

        print("  ADVENTURE LOG", color: .cyan, bold: true)
        printWrapped("How many log entries to display. 'Show All' displays every event but can be slow for very long adventures. Limit it to keep things snappy.", indent: 2, color: .dimGreen)
        print("")

        print("  TIME LIMIT", color: .cyan, bold: true)
        printWrapped("Optional time limit for your adventure. When in-game time exceeds the limit, the game ends in defeat. The remaining time is shown during exploration.", indent: 2, color: .dimGreen)
        print("")

        print("  IDLE PROMPTS", color: .cyan, bold: true)
        printWrapped("When on, the DM reacts if you take too long. Effects include eye blinks on ASCII art, combat hesitation penalties, and save menu nudges.", indent: 2, color: .dimGreen)
        print("")

        #if os(iOS)
        print("  KEYBOARD", color: .cyan, bold: true)
        printWrapped("Choose between the In-App keyboard (no globe or microphone buttons) and the standard iOS System keyboard.", indent: 2, color: .dimGreen)
        print("")
        #endif

        closeHandler = { [weak self] in self?.showGameplaySettings() }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showGameplaySettings() }
    }

    private func showTimeLimitMenu() {
        clearTerminal()
        printTitle("Time Limit")
        let current = gameTimeLimit == 0 ? "Off" : formatTimeLimitValue(gameTimeLimit)
        printWrapped("Set an optional time limit for your adventure. When in-game time exceeds the limit, the game ends in defeat. The remaining time is shown during exploration.", indent: 2, color: .dimGreen)
        print("")
        print("  Current: \(current)", color: .brightGreen)
        print("")

        let options = ["Off", "8 Hours", "12 Hours", "1 Day", "2 Days", "3 Days"]
        showMenu(options)
        closeHandler = { [weak self] in self?.showGameplaySettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let values = [0, 480, 720, 1440, 2880, 4320]
            if choice > 0 && choice <= values.count {
                self.gameTimeLimit = values[choice - 1]
            }
            self.showGameplaySettings()
        }
    }

    private func showLogLimitMenu() {
        clearTerminal()
        printTitle("Adventure Log Limit")
        let current = adventureLogLimit == 0 ? "Show All" : "Last \(adventureLogLimit)"
        printWrapped("How many entries to show in the Adventure Log. 'Show All' displays every event but may take a while to scroll for long adventures.", indent: 2, color: .dimGreen)
        print("")
        print("  Current: \(current)", color: .brightGreen)
        print("")

        let options = ["Show All", "Last 50", "Last 100", "Last 200"]
        showMenu(options)
        closeHandler = { [weak self] in self?.showGameplaySettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let values = [0, 50, 100, 200]
            if choice > 0 && choice <= values.count {
                self.adventureLogLimit = values[choice - 1]
            }
            self.showGameplaySettings()
        }
    }

    /// Persisted custom info timeout values added by the user
    private var customInfoTimeouts: [Double] {
        get { (UserDefaults.standard.array(forKey: "customInfoTimeouts") as? [Double]) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "customInfoTimeouts") }
    }

    private func showInfoTimeoutMenu() {
        clearTerminal()
        printTitle("Info Timeout")
        printWrapped("How long information screens stay before auto-dismissing. Shorter = faster gameplay, longer = more time to read.", indent: 2, color: .dimGreen)
        print("")
        print("  Current: \(String(format: "%.1fs", infoTimeout))", color: .brightGreen)
        printWrapped("Type a number with 's' or a decimal (e.g. 1.5s, 4.0) to set a custom value.", indent: 2, color: .dimGreen)
        print("")

        var values: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0]
        for v in customInfoTimeouts {
            if !values.contains(v) { values.append(v) }
        }
        values.sort()
        let options = values.map { String(format: "%.1fs", $0) }
        promptTextWithMenu("> ", options: options)
        closeHandler = { [weak self] in self?.showGameplaySettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice > 0 && choice <= values.count {
                self.infoTimeout = values[choice - 1]
                UserDefaults.standard.set(self.infoTimeout, forKey: "infoTimeout")
            }
            self.showGameplaySettings()
        }
        inputHandler = { [weak self] input in
            guard let self = self else { return }
            let trimmed = input.trimmingCharacters(in: .whitespaces)

            // Try to parse as a timeout value (float, or ends with 's')
            var parsed: Double?
            if trimmed.hasSuffix("s") {
                parsed = Double(trimmed.dropLast())
            } else if trimmed.contains(".") {
                parsed = Double(trimmed)
            } else if let intVal = Int(trimmed) {
                // Integer: if it's a valid button number, treat as button press
                if intVal >= 1 && intVal <= options.count {
                    self.infoTimeout = values[intVal - 1]
                    UserDefaults.standard.set(self.infoTimeout, forKey: "infoTimeout")
                    self.showGameplaySettings()
                    return
                }
                // Otherwise treat as seconds
                parsed = Double(intVal)
            }

            if let val = parsed, val > 0, val <= 60 {
                self.infoTimeout = val
                UserDefaults.standard.set(val, forKey: "infoTimeout")
                // If not already a button option, save as custom for next time
                if !values.contains(val) {
                    var custom = self.customInfoTimeouts
                    custom.append(val)
                    custom.sort()
                    self.customInfoTimeouts = custom
                }
                self.showGameplaySettings()
            } else {
                self.print("  Invalid value. Enter seconds (e.g. 1.5s or 4.0)", color: .red)
            }
        }
    }

    private func showButtonLimitMenu() {
        clearTerminal()
        printTitle("Button Limit")
        printWrapped("Maximum buttons shown on a single screen. Screens with more options will paginate with ▸ More and ◂ Back buttons.", indent: 2, color: .dimGreen)
        print("")
        print("  Current: \(maxButtonsPerScreen)", color: .brightGreen)
        print("")

        let options = ["6", "8", "10", "12"]
        showMenu(options)
        closeHandler = { [weak self] in self?.showGameplaySettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let values = [6, 8, 10, 12]
            if choice > 0 && choice <= values.count {
                self.maxButtonsPerScreen = values[choice - 1]
            }
            self.showGameplaySettings()
        }
    }

    private func showLongPressMenu() {
        clearTerminal()
        printTitle("Long Press Duration")
        printWrapped("How long you must hold a button before it triggers a long-press action (e.g. long rest, page jump, quick-return). Lower values make long-press faster but easier to trigger accidentally.", indent: 2, color: .dimGreen)
        print("")
        print("  Current: \(String(format: "%.1fs", longPressDuration))", color: .brightGreen)
        print("")

        let options = ["0.3s", "0.5s", "1.0s", "2.0s"]
        promptTextWithMenu("> ", options: options)
        closeHandler = { [weak self] in self?.showGameplaySettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let values: [Double] = [0.3, 0.5, 1.0, 2.0]
            if choice > 0 && choice <= values.count {
                self.longPressDuration = values[choice - 1]
            }
            self.showGameplaySettings()
        }
        inputHandler = { [weak self] input in
            guard let self = self else { return }
            let trimmed = input.trimmingCharacters(in: .whitespaces)
            var parsed: Double?
            if trimmed.hasSuffix("s") {
                parsed = Double(trimmed.dropLast())
            } else {
                parsed = Double(trimmed)
            }
            if let val = parsed, val >= 0.1, val <= 5.0 {
                self.longPressDuration = val
                self.showGameplaySettings()
            } else {
                self.print("  Enter seconds between 0.1 and 5.0 (e.g. 0.5s)", color: .red)
            }
        }
    }

    // MARK: - Settings Backup/Restore

    /// All UserDefaults keys used by the game
    private static let settingsKeys: [String] = [
        "maxButtonsPerScreen", "longPressDuration", "infoTimeout", "customInfoTimeouts",
        "map_radius", "useArrowNavigation", "multiplayer_enabled", "npcs_enabled",
        "hit_animations", "voiceMenuEnabled", "iconScaleSetting", "adventureLogLimit",
        "fontSizeSetting", "music_enabled", "battle_sounds_enabled",
        "autosave_interval", "dmProvider", "dmAdLibLevel", "dmLogContextSize",
        "dmApiKey", "speechEnabled", "companionVoiceMode",
        "menu_melody", "exploration_melody", "combat_melody", "chat_melody",
        "gameTimeLimit", "useCustomKeyboard",
    ]

    private func exportSettings() -> [String: Any] {
        var dict: [String: Any] = [:]
        for key in Self.settingsKeys {
            if let val = UserDefaults.standard.object(forKey: key) {
                dict[key] = val
            }
        }
        return dict
    }

    private func importSettings(_ dict: [String: Any]) {
        for (key, value) in dict {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func settingsBackupDir() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SettingsBackups")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func settingsBackupURL(name: String) -> URL {
        settingsBackupDir().appendingPathComponent("\(name).plist")
    }

    private func listSettingsBackups() -> [(name: String, date: Date)] {
        let dir = settingsBackupDir()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        var results: [(name: String, date: Date)] = []
        for file in files where file.hasSuffix(".plist") {
            let name = String(file.dropLast(6)) // remove .plist
            let path = dir.appendingPathComponent(file).path
            let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date ?? .distantPast
            results.append((name, date))
        }
        return results.sorted { $0.date > $1.date }
    }

    // Migrate old single-file backup if it exists
    private func migrateOldBackup() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldFile = docs.appendingPathComponent("DnDSettings.plist")
        if FileManager.default.fileExists(atPath: oldFile.path) {
            let newFile = settingsBackupURL(name: "Backup")
            try? FileManager.default.moveItem(at: oldFile, to: newFile)
        }
    }

    private func showSettingsBackupMenu() {
        migrateOldBackup()
        clearTerminal()
        printTitle("Settings Backup")
        printWrapped("Save, load, or manage named settings backups.", indent: 2, color: .dimGreen)
        print("")

        let backups = listSettingsBackups()
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short

        if backups.isEmpty {
            print("  No backups yet.", color: .dimGreen)
        } else {
            print("  BACKUPS:", color: .cyan, bold: true)
            for b in backups {
                print("  \(b.name) — \(fmt.string(from: b.date))", color: .brightGreen)
            }
        }
        print("")

        var options = ["New Backup"]
        if !backups.isEmpty {
            options.append("View/Load")
            options.append("Delete Backup")
        }

        showMenu(options)
        closeHandler = { [weak self] in self?.showSettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = options[choice - 1]
            if selected == "New Backup" {
                self.promptNewBackupName()
            } else if selected == "View/Load" {
                self.showLoadBackupMenu()
            } else if selected == "Delete Backup" {
                self.showDeleteBackupMenu()
            }
        }
    }

    private func promptNewBackupName() {
        clearTerminal()
        printTitle("New Backup")
        printWrapped("Enter a name for this backup:", indent: 2, color: .dimGreen)
        print("")

        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy"
        let suggestion = fmt.string(from: Date())

        promptTextWithMenu("", options: [suggestion])
        closeHandler = { [weak self] in self?.showSettingsBackupMenu() }
        menuHandler = { [weak self] choice in
            // Button 1 = use the suggested name
            self?.saveBackupWithName(suggestion)
        }
        inputHandler = { [weak self] input in
            let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            // Sanitise: remove path separators
            let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            self?.saveBackupWithName(safe)
        }
    }

    private func saveBackupWithName(_ name: String) {
        let dict = exportSettings()
        let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        if let data = data {
            try? data.write(to: settingsBackupURL(name: name))
            print("")
            print("  Saved backup: \(name)", color: .brightGreen)
        } else {
            print("")
            print("  Failed to save backup.", color: .red)
        }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showSettingsBackupMenu() }
    }

    private func showLoadBackupMenu() {
        clearTerminal()
        printTitle("Load Backup")
        print("  This will overwrite your current settings.", color: .yellow)
        print("")

        let backups = listSettingsBackups()
        let names = backups.map { $0.name }

        showPaginatedMenu(names) { [weak self] idx in
            guard let self = self, idx >= 0 && idx < backups.count else { return }
            let backup = backups[idx]
            self.clearTerminal()
            self.printTitle("Load: \(backup.name)")
            self.print("  Overwrite current settings with this backup?", color: .yellow)
            self.print("")
            self.showMenu(["Yes, Load", "< Cancel"])
            self.menuHandler = { [weak self] choice in
                guard let self = self else { return }
                if choice == 1 {
                    let url = self.settingsBackupURL(name: backup.name)
                    if let data = try? Data(contentsOf: url),
                       let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        self.importSettings(dict)
                        self.print("")
                        self.print("  Settings restored from \(backup.name).", color: .brightGreen)
                        self.print("  Restart the app for all changes to take effect.", color: .dimGreen)
                    } else {
                        self.print("")
                        self.print("  Failed to read backup.", color: .red)
                    }
                }
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in self?.showSettingsBackupMenu() }
            }
        }
        closeHandler = { [weak self] in self?.showSettingsBackupMenu() }
    }

    private func showDeleteBackupMenu() {
        clearTerminal()
        printTitle("Delete Backup")
        print("")

        let backups = listSettingsBackups()
        let names = backups.map { $0.name }

        showPaginatedMenu(names) { [weak self] idx in
            guard let self = self, idx >= 0 && idx < backups.count else { return }
            let backup = backups[idx]
            self.clearTerminal()
            self.printTitle("Delete: \(backup.name)")
            self.print("  This cannot be undone.", color: .red)
            self.print("")
            self.showMenu(["Yes, Delete", "< Cancel"], defaultIndex: 1)
            self.menuHandler = { [weak self] choice in
                guard let self = self else { return }
                if choice == 1 {
                    let url = self.settingsBackupURL(name: backup.name)
                    try? FileManager.default.removeItem(at: url)
                    self.print("")
                    self.print("  Deleted \(backup.name).", color: .yellow)
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in self?.showSettingsBackupMenu() }
                } else {
                    self.showDeleteBackupMenu()
                }
            }
        }
        closeHandler = { [weak self] in self?.showSettingsBackupMenu() }
    }

    // MARK: - API Key Keychain Backup

    private let keychainServicePrefix = "com.dndtextrpg.apikey."

    private func loadAPIKeysFromKeychain() -> [String: String]? {
        var result: [String: String] = [:]
        for provider in AIProvider.allCases {
            let key = provider.userDefaultsKey
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainServicePrefix + key,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) {
                result[key] = value
            }
        }
        return result.isEmpty ? nil : result
    }

    private func backupAPIKeysToKeychain() {
        var backed = 0
        for provider in AIProvider.allCases {
            let key = provider.userDefaultsKey
            guard let value = UserDefaults.standard.string(forKey: key), !value.isEmpty else { continue }
            guard let data = value.data(using: .utf8) else { continue }

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainServicePrefix + key,
                kSecAttrAccount as String: key
            ]
            // Delete existing item first
            SecItemDelete(query as CFDictionary)
            // Add new item
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status == errSecSuccess { backed += 1 }
        }
        print("")
        if backed > 0 {
            print("  Backed up \(backed) API key\(backed == 1 ? "" : "s") to Keychain.", color: .brightGreen)
        } else {
            print("  No API keys configured to back up.", color: .yellow)
        }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showSaveSettings() }
    }

    private func restoreAPIKeysFromKeychain() {
        guard let keys = loadAPIKeysFromKeychain() else {
            print("")
            print("  No API keys found in Keychain.", color: .yellow)
            waitForContinue()
            inputHandler = { [weak self] _ in self?.showSaveSettings() }
            return
        }
        var restored = 0
        for (key, value) in keys {
            UserDefaults.standard.set(value, forKey: key)
            restored += 1
        }
        print("")
        print("  Restored \(restored) API key\(restored == 1 ? "" : "s") from Keychain.", color: .brightGreen)
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showSaveSettings() }
    }

    private func showSaveSettings() {
        clearTerminal()
        printTitle("Save & Backup")

        print("AUTOSAVE:", color: .cyan, bold: true)
        print("  \(autosaveInterval.displayName)", color: .brightGreen)
        printWrapped("Automatically saves your game at regular intervals. Saves appear in the Play menu.", indent: 2, color: .dimGreen)
        print("")

        let saves = SaveGameManager.shared.listAllSaves()
        print("GAME SAVES:", color: .cyan, bold: true)
        print("  \(saves.count) save file\(saves.count == 1 ? "" : "s")", color: .dimGreen)
        print("")

        let backups = listSettingsBackups()
        print("SETTINGS BACKUPS:", color: .cyan, bold: true)
        if backups.isEmpty {
            print("  No backups", color: .dimGreen)
        } else {
            print("  \(backups.count) backup\(backups.count == 1 ? "" : "s")", color: .dimGreen)
        }
        print("")

        let hasKeychainBackup = loadAPIKeysFromKeychain() != nil
        print("API KEY BACKUP:", color: .cyan, bold: true)
        print("  \(hasKeychainBackup ? "Saved to Keychain" : "Not backed up")", color: hasKeychainBackup ? .brightGreen : .dimGreen)
        print("")

        var options = ["Autosave"]
        if !saves.isEmpty {
            options.append("Manage Saves")
            options.append("Clear All Saves")
        }
        options.append("Settings Backup")
        options.append(hasKeychainBackup ? "Restore API Keys" : "Backup API Keys")

        var menuOpts = options.map { MenuOption($0) }
        menuOpts.append(MenuOption("Help", tint: .navigation))
        showMenuOptions(menuOpts)
        closeHandler = { [weak self] in self?.showSettings() }
        updateSettingsUndoRedo { [weak self] in self?.showSaveSettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == menuOpts.count {
                self.showSaveSettingsHelp()
                return
            }
            self.pushSettingsSnapshot()
            let selected = options[choice - 1]
            if selected == "Autosave" {
                self.showAutosaveMenu()
            } else if selected == "Manage Saves" {
                self.showManageSavesMenu(returnTo: .settings)
            } else if selected == "Clear All Saves" {
                self.confirmClearAllSaves()
            } else if selected == "Settings Backup" {
                self.showSettingsBackupMenu()
            } else if selected == "Backup API Keys" {
                self.backupAPIKeysToKeychain()
            } else if selected == "Restore API Keys" {
                self.restoreAPIKeysFromKeychain()
            }
        }
    }

    private func showSaveSettingsHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Save & Backup Help")
        print("")

        print("  AUTOSAVE", color: .cyan, bold: true)
        printWrapped("Automatically saves your game at regular intervals. Choose how often autosave triggers. Saves appear in the Play menu under your adventure name.", indent: 2, color: .dimGreen)
        print("")

        print("  MANAGE SAVES", color: .cyan, bold: true)
        printWrapped("Browse and delete individual save files. Each adventure can have multiple save points (breakpoints) that you can return to.", indent: 2, color: .dimGreen)
        print("")

        print("  CLEAR ALL SAVES", color: .cyan, bold: true)
        printWrapped("Permanently deletes every save file on the device. Use with caution — this cannot be undone.", indent: 2, color: .dimGreen)
        print("")

        print("  SETTINGS BACKUP", color: .cyan, bold: true)
        printWrapped("Create and restore backups of your settings. Useful before experimenting with configuration changes or when moving to a new device.", indent: 2, color: .dimGreen)
        print("")

        print("  API KEY BACKUP / RESTORE", color: .cyan, bold: true)
        printWrapped("Saves your AI provider API keys to the device Keychain for safe keeping. Restore retrieves them if they are cleared. The Keychain is encrypted and persists across app reinstalls.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showSaveSettings() }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showSaveSettings() }
    }

    private func showDMSettingsSubMenu() {
        clearTerminal()
        printTitle("R. Dungeon Master (DM)")

        let dm = DMEngine.shared
        print("PROVIDER:", color: .cyan, bold: true)
        print("  \(dm.provider.displayName)", color: .brightGreen)
        print("")
        print("AD-LIB:", color: .cyan, bold: true)
        print("  \(dm.adLibLevel.displayName)", color: .brightGreen)
        print("")
        let logCtx = dmLogContextSize == Int.max ? "Unlimited" : "\(dmLogContextSize)"
        print("LOG CONTEXT:", color: .cyan, bold: true)
        print("  \(logCtx) lines", color: .dimGreen)
        print("")
        if dm.isConfigured {
            print("API KEY:", color: .cyan, bold: true)
            print("  Configured", color: .brightGreen)
            print("")
        }

        var options = ["Provider", "API Key", "Ad-lib Level", "Log Context"]
        if dm.isConfigured {
            options.append("Clear API Key")
        }
        options.append("DM Voice")

        var menuOpts = options.map { MenuOption($0) }
        menuOpts.append(MenuOption("Help", tint: .navigation))
        showMenuOptions(menuOpts)
        closeHandler = { [weak self] in self?.showSettings() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == menuOpts.count {
                self.showDMSettingsHelp()
                return
            }
            let selected = options[choice - 1]
            switch selected {
            case "Provider":
                self.showAIProviderMenu()
            case "API Key":
                self.promptAPIKey()
            case "Ad-lib Level":
                self.showAdLibLevelMenu()
            case "Log Context":
                self.showDMLogContextMenu()
            case "Clear API Key":
                DMEngine.shared.apiKey = nil
                self.print("")
                self.print("API key cleared.", color: .yellow)
                self.print("")
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.showDMSettingsSubMenu()
                }
            case "DM Voice":
                self.showVoiceSettings()
            default: break
            }
        }
    }

    private func showDMSettingsHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("DM Settings Help")
        print("")

        print("  PROVIDER", color: .cyan, bold: true)
        printWrapped("Choose which AI service powers the Dungeon Master. Options include OpenAI, Anthropic, Google, and Apple on-device AI. Cloud providers need an API key and offer more creative narration.", indent: 2, color: .dimGreen)
        print("")

        print("  API KEY", color: .cyan, bold: true)
        printWrapped("Enter the API key for your chosen cloud provider. The key is stored locally on your device and never shared. Without a key, the DM falls back to basic or on-device AI.", indent: 2, color: .dimGreen)
        print("")

        print("  AD-LIB LEVEL", color: .cyan, bold: true)
        printWrapped("Controls how creative and verbose the AI Dungeon Master is. Higher levels produce richer descriptions and more flavourful narration but use more tokens (and cost more for cloud providers).", indent: 2, color: .dimGreen)
        print("")

        print("  LOG CONTEXT", color: .cyan, bold: true)
        printWrapped("How many lines of adventure log the DM reads for context when generating responses. More context means better continuity but slower and more expensive requests. 'Unlimited' sends everything.", indent: 2, color: .dimGreen)
        print("")

        print("  CLEAR API KEY", color: .cyan, bold: true)
        printWrapped("Removes your stored API key. The DM will revert to basic or on-device AI until a new key is entered.", indent: 2, color: .dimGreen)
        print("")

        print("  DM VOICE", color: .cyan, bold: true)
        printWrapped("Configure the text-to-speech voice used for DM narration. Choose from different voice styles, speeds, and pitches.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showDMSettingsSubMenu() }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showDMSettingsSubMenu() }
    }

    private func confirmClearAllSaves() {
        clearTerminal()
        printTitle("Clear All Saves")
        let saves = SaveGameManager.shared.listAllSaves()
        print("This will permanently delete \(saves.count) save file\(saves.count == 1 ? "" : "s").", color: .red)
        print("")
        showMenu(["Yes, Delete All", "< Cancel"], defaultIndex: 1)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                for save in saves {
                    SaveGameManager.shared.delete(id: save.id)
                }
                self.print("")
                self.print("All saves deleted.", color: .yellow)
                self.print("")
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.showSaveSettings()
                }
            } else {
                self.showSaveSettings()
            }
        }
    }

    private func showSettingsHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Settings — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Settings lets you customise your game experience. Changes are saved automatically.", indent: 2, color: .dimGreen)
        print("")

        print("  BUTTONS", color: .cyan, bold: true)
        printWrapped("DM Settings — configure the robot Dungeon Master: provider, API key, ad-lib level, context memory.", indent: 2, color: .dimGreen)
        printWrapped("Accessibility — font size, icon size, hit animations, DM voice, companion voices, voice menus.", indent: 2, color: .dimGreen)
        printWrapped("Mood — music and sound effects for menu, exploration, combat, and chat.", indent: 2, color: .dimGreen)
        printWrapped("Gameplay — map radius, card navigation style, info timeout, multiplayer.", indent: 2, color: .dimGreen)
        printWrapped("Saving — autosave frequency and managing saved games.", indent: 2, color: .dimGreen)
        print("")

        print("  WHAT NEXT", color: .cyan, bold: true)
        printWrapped("Tap any setting category or close (X) to return.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showSettings() }
    }

    func showMusicSettings() {
        clearTerminal()
        printTitle("Mood")

        print("MUSIC:", color: .cyan, bold: true)
        print("  \(musicEnabled ? "On" : "Off")", color: musicEnabled ? .brightGreen : .dimGreen)
        print("")

        if musicEnabled {
            print("MENU TUNE:", color: .cyan, bold: true)
            print("  \(melodyName(type: "menu", choice: menuMelodyChoice))", color: .brightGreen)
            print("")

            print("EXPLORATION TUNE:", color: .cyan, bold: true)
            print("  \(melodyName(type: "exploration", choice: explorationMelodyChoice))", color: .brightGreen)
            print("")

            print("COMBAT TUNE:", color: .cyan, bold: true)
            print("  \(melodyName(type: "combat", choice: combatMelodyChoice))", color: .brightGreen)
            print("")

            print("CHAT TUNE:", color: .cyan, bold: true)
            print("  \(melodyName(type: "chat", choice: chatMelodyChoice))", color: .brightGreen)
            print("")
        }

        print("BATTLE SOUNDS:", color: .cyan, bold: true)
        print("  \(battleSoundsEnabled ? "On" : "Off")", color: battleSoundsEnabled ? .brightGreen : .dimGreen)
        print("")

        var options = [musicEnabled ? "Music Off" : "Music On"]
        if musicEnabled {
            options.append("Menu Tune")
            options.append("Explore Tune")
            options.append("Combat Tune")
            options.append("Chat Tune")
        }
        options.append(battleSoundsEnabled ? "Sounds Off" : "Sounds On")
        var menuOpts = options.map { MenuOption($0) }
        menuOpts.append(MenuOption("Help", tint: .navigation))
        showMenuOptions(menuOpts)

        closeHandler = { [weak self] in
            guard let self = self else { return }
            SoundManager.shared.stopMusic()
            self.playCurrentMusic()
            self.showSettings()
        }
        updateSettingsUndoRedo { [weak self] in self?.showMusicSettings() }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == menuOpts.count {
                self.showMusicSettingsHelp()
                return
            }
            self.pushSettingsSnapshot()
            let selected = options[choice - 1]
            if selected.hasPrefix("Music O") {
                self.musicEnabled.toggle()
                if self.musicEnabled {
                    self.playCurrentMusic()
                }
                self.showMusicSettings()
            } else if selected == "Menu Tune" {
                self.menuMelodyChoice = (self.menuMelodyChoice + 1) % 4
                SoundManager.shared.stopMusic()
                SoundManager.shared.startMusic(.menu, preference: self.menuMelodyChoice)
                self.showMusicSettings()
            } else if selected == "Explore Tune" {
                self.explorationMelodyChoice = (self.explorationMelodyChoice + 1) % 5
                SoundManager.shared.stopMusic()
                SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice)
                self.showMusicSettings()
            } else if selected == "Combat Tune" {
                self.combatMelodyChoice = (self.combatMelodyChoice + 1) % 4
                SoundManager.shared.stopMusic()
                SoundManager.shared.startMusic(.combat, preference: self.combatMelodyChoice)
                self.showMusicSettings()
            } else if selected == "Chat Tune" {
                self.chatMelodyChoice = (self.chatMelodyChoice + 1) % 4
                SoundManager.shared.stopMusic()
                SoundManager.shared.startMusic(.chat, preference: self.chatMelodyChoice)
                self.showMusicSettings()
            } else if selected.hasPrefix("Sounds O") {
                self.battleSoundsEnabled.toggle()
                self.showMusicSettings()
            }
        }
    }

    private func showMusicSettingsHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Mood Help")
        print("")

        print("  MUSIC", color: .cyan, bold: true)
        printWrapped("Toggle background music on or off. When on, different tunes play during menus, exploration, combat, and chat.", indent: 2, color: .dimGreen)
        print("")

        print("  MENU TUNE", color: .cyan, bold: true)
        printWrapped("The melody that plays on the main menu and setup screens. Tap to cycle through available tunes.", indent: 2, color: .dimGreen)
        print("")

        print("  EXPLORATION TUNE", color: .cyan, bold: true)
        printWrapped("The melody that plays while exploring the dungeon. Sets the mood as you navigate corridors and discover rooms.", indent: 2, color: .dimGreen)
        print("")

        print("  COMBAT TUNE", color: .cyan, bold: true)
        printWrapped("The melody that plays during combat encounters. Tap to cycle through available battle themes.", indent: 2, color: .dimGreen)
        print("")

        print("  CHAT TUNE", color: .cyan, bold: true)
        printWrapped("The melody that plays during chat and conversation screens. A calmer tune for when you are talking to your party or the DM.", indent: 2, color: .dimGreen)
        print("")

        print("  BATTLE SOUNDS", color: .cyan, bold: true)
        printWrapped("Sound effects during combat — sword clashes, spell impacts, and hit sounds. Turn off for a quieter experience.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showMusicSettings() }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showMusicSettings() }
    }

    /// Start music appropriate for current game state, respecting preferences
    private func playCurrentMusic() {
        guard musicEnabled else { return }
        switch gameState {
        case .mainMenu, .partySetup, .characterCreation, .gameOver, .victory:
            SoundManager.shared.startMusic(.menu, preference: menuMelodyChoice)
        case .exploring:
            SoundManager.shared.startMusic(.exploration, preference: explorationMelodyChoice)
        case .combat:
            SoundManager.shared.startMusic(.combat, preference: combatMelodyChoice)
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

        // Build menu with <-- marker on current provider
        var options: [MenuOption] = []
        let isAppleSelected = !dm.isConfigured && dm.isAppleModelAvailable
        if dm.isAppleModelAvailable {
            let label = isAppleSelected ? "Apple On-Device AI <--" : "Apple On-Device AI"
            options.append(MenuOption(label))
        }
        for provider in AIProvider.allCases {
            let isSelected = provider == current && dm.isConfigured
            let label = isSelected ? "\(provider.displayName) <--" : provider.displayName
            options.append(MenuOption(label))
        }
        showMenuOptions(options)

        let appleOffset = dm.isAppleModelAvailable ? 1 : 0

        closeHandler = { [weak self] in self?.showDMSettingsSubMenu() }
        menuHandler = { [weak self] choice in
            if dm.isAppleModelAvailable && choice == 1 {
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
                    self?.showAIProviderMenu()
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
                        self?.showAIProviderMenu()
                    }
                }
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

        let options = DMAdLibLevel.allCases.map { $0.displayName }
        showMenu(options)

        closeHandler = { [weak self] in self?.showDMSettingsSubMenu() }
        menuHandler = { [weak self] choice in
            if choice <= DMAdLibLevel.allCases.count {
                DMEngine.shared.adLibLevel = DMAdLibLevel(rawValue: choice - 1) ?? .flavorOnly
                self?.showAdLibLevelMenu()
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
            showMenu(["Settings"])
            closeHandler = { [weak self] in self?.showSettings() }
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
            closeHandler = { [weak self] in self?.showSettings() }
            waitForContinue()
            inputHandler = { [weak self] _ in self?.showSettings() }
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
            print("")
            print("ACCESSIBILITY:", color: .cyan, bold: true)
            print("  Help Narration: \(speech.accessibilityHelpEnabled ? "On" : "Off")", color: speech.accessibilityHelpEnabled ? .brightGreen : .dimGreen)
            printWrapped(speech.accessibilityHelpEnabled ? "The DM reads help pages, menus, and tips aloud as you navigate." : "Turn on to have the DM read help pages and menus aloud — useful for vision accessibility.", indent: 4, color: .dimGreen)
        }
        print("")

        var options = [String]()
        options.append(speech.isEnabled ? "Turn Off" : "Turn On")
        if speech.isEnabled {
            options.append("Choose DM Voice")
            options.append("Speed")
            options.append("Pitch")
            options.append(speech.accessibilityHelpEnabled ? "Help Narration Off" : "Help Narration On")
        }
        options.append("Preview")

        closeHandler = { [weak self] in self?.showSettings() }
        showMenu(options)

        menuHandler = { [weak self] choice in
            let selected = options[choice - 1]
            if selected.hasPrefix("Turn O") {
                speech.isEnabled = !speech.isEnabled
                if speech.isEnabled { speech.preview() } else { speech.stop() }
                self?.showVoiceSettings()
            } else if selected == "Choose DM Voice" {
                self?.showVoiceChoiceMenu()
            } else if selected == "Speed" {
                self?.showVoiceSpeedMenu()
            } else if selected == "Pitch" {
                self?.showVoicePitchMenu()
            } else if selected.hasPrefix("Help Narration") {
                speech.accessibilityHelpEnabled.toggle()
                self?.showVoiceSettings()
            } else if selected == "Preview" {
                self?.showVoicePreview()
            }
        }
    }

    private func showAdventurerVoiceSettings() {
        clearTerminal()
        printTitle("Companion Voices")

        let speech = SpeechEngine.shared
        let allVoices = speech.availableVoices()
        let currentPool = speech.adventurerVoicePool

        printWrapped("Your party members speak with their own voices. Voices are automatically matched to each companion's race, class, and name — a dwarf fighter sounds different from an elf wizard.", indent: 2, color: .dimGreen)
        print("")

        // Show current party members and their assigned voices
        if !party.isEmpty {
            print("  YOUR PARTY:", color: .cyan, bold: true)
            for char in party {
                let voiceName = speech.voiceNameForCharacter(name: char.name, race: char.race.rawValue, characterClass: char.characterClass.rawValue) ?? "Default"
                let hasOverride = speech.voiceOverride(forCharacter: char.name) != nil
                print("    \(char.name)", color: .brightGreen, bold: true)
                print("      \(char.race.rawValue) \(char.characterClass.rawValue)", color: .dimGreen)
                print("      Voice: \(voiceName)\(hasOverride ? " (manual)" : "")", color: .cyan)
                print("")
            }
        } else {
            print("  No party yet — start a game to", color: .yellow)
            print("  see your companions here.", color: .yellow)
            print("")
        }

        print("  VOICE POOL (\(currentPool.count)/\(allVoices.count) enabled):", color: .cyan, bold: true)
        printWrapped("Toggle voices on/off. More voices gives the DM a wider range to match characters. Tap a voice to toggle and hear it.", indent: 2, color: .dimGreen)
        print("")

        var menuOpts: [String] = []
        if !party.isEmpty { menuOpts.append("Preview Party") }
        menuOpts.append("Help")

        for voice in allVoices {
            let isOn = currentPool.contains(voice.identifier)
            let icon = isOn ? "+" : "-"
            let shortName = String(voice.name.prefix(14))
            menuOpts.append("\(icon) \(shortName)")
        }
        menuOpts.append("Reset All On")

        closeHandler = { [weak self] in self?.showSettings() }
        showMenu(menuOpts)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = menuOpts[choice - 1]
            if selected == "Preview Party" {
                self.previewPartyVoices()
            } else if selected == "Help" {
                self.showCompanionVoiceHelp()
            } else if selected == "Reset All On" {
                speech.adventurerVoicePool = speech.defaultAdventurerPool()
                self.showAdventurerVoiceSettings()
            } else {
                // Voice toggle
                let fixedCount = self.party.isEmpty ? 1 : 2  // Help + optional Preview
                let voiceIdx = choice - fixedCount - 1
                if voiceIdx >= 0 && voiceIdx < allVoices.count {
                    let voice = allVoices[voiceIdx]
                    var pool = speech.adventurerVoicePool
                    if let idx = pool.firstIndex(of: voice.identifier) {
                        if pool.count > 1 { pool.remove(at: idx) }
                    } else {
                        pool.append(voice.identifier)
                    }
                    speech.adventurerVoicePool = pool
                    speech.previewVoice(voice.identifier)
                }
                self.showAdventurerVoiceSettings()
            }
        }
    }

    private func showCompanionVoiceHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Companion Voices — Help")
        print("")
        printWrapped("HOW IT WORKS", indent: 2, color: .cyan, bold: true)
        printWrapped("Each party member is assigned a unique voice based on their race, class, and name. The DM picks voices that fit each character — deep voices for dwarves and orcs, lighter voices for elves and halflings.", indent: 2, color: .dimGreen)
        print("")
        printWrapped("VOICE POOL", indent: 2, color: .cyan, bold: true)
        printWrapped("Toggle voices on or off in the pool. The more voices available, the better the DM can match characters. Include both male and female voices for variety.", indent: 2, color: .dimGreen)
        print("")
        printWrapped("MANUAL OVERRIDE", indent: 2, color: .cyan, bold: true)
        printWrapped("To manually set a specific voice for a character, go to Party Status > Edit > Edit Voice > Change Voice. Use 'Reset to Auto' to let the DM choose again.", indent: 2, color: .dimGreen)
        print("")
        printWrapped("PREVIEW", indent: 2, color: .cyan, bold: true)
        printWrapped("'Preview Party' speaks a line for each party member in their assigned voice so you can hear how they sound.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showAdventurerVoiceSettings() }
    }

    private func previewPartyVoices() {
        let speech = SpeechEngine.shared
        clearTerminal()
        printTitle("Party Voice Preview")
        print("")

        let greetings = [
            "Ready for battle!",
            "I've got your back.",
            "Stay alert, something stirs ahead.",
            "Lead on, adventurer!",
        ]

        for (i, char) in party.enumerated() {
            let voiceName = speech.voiceNameForCharacter(name: char.name, race: char.race.rawValue, characterClass: char.characterClass.rawValue) ?? "Default"
            print("  \(char.name) (\(voiceName)):", color: .brightGreen)
            let greeting = greetings[i % greetings.count]
            print("  \"\(greeting)\"", color: .dimGreen)
            print("")
        }

        print("  Speaking...", color: .cyan)
        print("")

        // Speak each character's greeting sequentially
        var charIdx = 0
        func speakNext() {
            guard charIdx < self.party.count else {
                speech.onFinish = nil
                return
            }
            let char = self.party[charIdx]
            let greeting = greetings[charIdx % greetings.count]
            charIdx += 1
            speech.onFinish = { speakNext() }
            speech.speakAsCharacter(greeting, characterName: char.name, race: char.race.rawValue, characterClass: char.characterClass.rawValue)
        }
        speakNext()

        closeHandler = { [weak self] in
            speech.stop()
            self?.showAdventurerVoiceSettings()
        }
    }

    private func showCharacterVoiceEdit(index: Int) {
        guard index < party.count else { showPartyReview(); return }
        let char = party[index]
        let speech = SpeechEngine.shared

        clearTerminal()
        printTitle("Voice — \(shortName(for: char))")

        guard speech.isAvailable else {
            print("  Text-to-speech is not available", color: .red)
            print("  on this device.", color: .red)
            print("")
            closeHandler = { [weak self] in self?.showEditCharacter(index: index) }
            return
        }

        let voiceName = speech.voiceNameForCharacter(name: char.name, race: char.race.rawValue, characterClass: char.characterClass.rawValue) ?? "Default"
        print("  \(char.race.rawValue) \(char.characterClass.rawValue)", color: .dimGreen)
        print("")
        let hasOverride = speech.voiceOverride(forCharacter: char.name) != nil
        print("  Voice: \(voiceName)\(hasOverride ? " (manual)" : "")", color: speech.isEnabled ? .brightGreen : .dimGreen)
        print("  Companion voices: \(speech.isEnabled ? "On" : "Off")", color: speech.isEnabled ? .brightGreen : .yellow)
        print("")
        printWrapped("Voice is automatically matched to this character's race, class, and name. Use Change Voice to manually override.", indent: 2, color: .dimGreen)
        print("")

        var options = [String]()
        options.append(speech.isEnabled ? "Turn Off Voices" : "Turn On Voices")
        if speech.isEnabled {
            options.append("Change Voice")
            if hasOverride {
                options.append("Reset to Auto")
            }
            options.append("Preview")
            options.append("Voice Pool")
        }

        showMenu(options)
        closeHandler = { [weak self] in self?.showEditCharacter(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = options[choice - 1]
            if selected.hasPrefix("Turn O") {
                speech.isEnabled = !speech.isEnabled
                self.showCharacterVoiceEdit(index: index)
            } else if selected == "Change Voice" {
                self.showVoicePicker(forCharacter: char, editIndex: index)
            } else if selected == "Reset to Auto" {
                speech.setVoiceOverride(forCharacter: char.name, voiceId: nil)
                self.showCharacterVoiceEdit(index: index)
            } else if selected == "Preview" {
                let greeting = "I am \(char.name). Ready for adventure!"
                speech.speakAsCharacter(greeting, characterName: char.name, race: char.race.rawValue, characterClass: char.characterClass.rawValue)
                self.showCharacterVoiceEdit(index: index)
            } else if selected == "Voice Pool" {
                self.showAdventurerVoiceSettingsFrom(index: index)
            }
        }
    }

    private func showVoicePicker(forCharacter char: Character, editIndex: Int) {
        let speech = SpeechEngine.shared
        let pool = speech.adventurerVoicePool
        guard !pool.isEmpty else {
            showCharacterVoiceEdit(index: editIndex)
            return
        }

        clearTerminal()
        printSubtitle("Choose Voice — \(shortName(for: char))")
        print("")

        let currentOverride = speech.voiceOverride(forCharacter: char.name)

        // Collect all eligible voices from the pool
        let allVoiceOptions = speech.availableVoices()
        var allEligible: [(label: String, id: String)] = []
        for vo in allVoiceOptions where pool.contains(vo.identifier) {
            allEligible.append((label: vo.label, id: vo.identifier))
        }

        // Show current voice if set
        if let overrideId = currentOverride,
           let current = allEligible.first(where: { $0.id == overrideId }) {
            print("  Current: \(current.label)", color: .yellow)
        } else {
            print("  Current: Auto (DM assigns)", color: .dimGreen)
        }
        print("")

        // Pick a random sample of 8 voices (always include current override if set)
        var sample: [(label: String, id: String)] = []
        if let overrideId = currentOverride,
           let current = allEligible.first(where: { $0.id == overrideId }) {
            sample.append(current)
        }
        let sampleIds = Set(sample.map { $0.id })
        let remaining = allEligible.filter { !sampleIds.contains($0.id) }
        let needed = min(8 - sample.count, remaining.count)
        sample.append(contentsOf: remaining.shuffled().prefix(needed))

        var options: [String] = []
        var voiceIds: [String] = []
        for vo in sample {
            let marker = (vo.id == currentOverride) ? " ✓" : ""
            options.append("\(vo.label)\(marker)")
            voiceIds.append(vo.id)
        }

        print("  Tap to select & preview. 🎲 for more voices.", color: .dimGreen)
        print("  \(allEligible.count) voices available.", color: .dimGreen)
        print("")

        showMenu(options)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let idx = choice - 1
            guard idx >= 0 && idx < voiceIds.count else { return }
            let selectedId = voiceIds[idx]
            speech.setVoiceOverride(forCharacter: char.name, voiceId: selectedId)
            speech.previewVoice(selectedId)
            self.showVoicePicker(forCharacter: char, editIndex: editIndex)
        }

        closeHandler = { [weak self] in
            self?.showCharacterVoiceEdit(index: editIndex)
        }

        // Dice icon → shuffle new random voices
        rerollHandler = { [weak self] in
            self?.showVoicePicker(forCharacter: char, editIndex: editIndex)
        }
    }

    /// Companion voice settings with return-to-edit-character support
    private func showAdventurerVoiceSettingsFrom(index: Int) {
        // Reuse the existing companion voices screen but override close to go back to character edit
        showAdventurerVoiceSettings()
        closeHandler = { [weak self] in self?.showCharacterVoiceEdit(index: index) }
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
            showMenu(["Done"])
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
        options.append("Done")
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
        options.append("Done")
        showMenu(options)

        let previousRate = speech.rate
        menuHandler = { [weak self] choice in
            if choice <= speeds.count {
                let newRate = speeds[choice - 1].value
                speech.rate = newRate
                speech.preview()
                self?.clearTerminal()
                self?.printTitle("Confirm Speed")
                self?.print("")
                self?.print("  Preview: \(speeds[choice - 1].name)", color: .brightGreen)
                self?.print("")
                self?.showMenu(["Apply", "Go Back"])
                self?.menuHandler = { [weak self] confirm in
                    if confirm == 1 {
                        self?.showVoiceSettings()
                    } else {
                        speech.rate = previousRate
                        self?.showVoiceSpeedMenu()
                    }
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
        options.append("Done")
        showMenu(options)

        let previousPitch = speech.pitch
        menuHandler = { [weak self] choice in
            if choice <= pitches.count {
                let newPitch = pitches[choice - 1].value
                speech.pitch = newPitch
                speech.preview()
                self?.clearTerminal()
                self?.printTitle("Confirm Pitch")
                self?.print("")
                self?.print("  Preview: \(pitches[choice - 1].name)", color: .brightGreen)
                self?.print("")
                self?.showMenu(["Apply", "Go Back"])
                self?.menuHandler = { [weak self] confirm in
                    if confirm == 1 {
                        self?.showVoiceSettings()
                    } else {
                        speech.pitch = previousPitch
                        self?.showVoicePitchMenu()
                    }
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

        let options = AutosaveInterval.allCases.map { $0.displayName }
        closeHandler = { [weak self] in self?.showSaveSettings() }
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
                    self?.showSaveSettings()
                }
            }
        }
    }

    func showDMLogContextMenu() {
        // Roller steps: 0 (unlimited), 20, 40, 60, ... 2020, 2040, 2048 (unlimited)
        let steps: [Int] = {
            var s = [0]
            var v = 20
            while v < 2048 {
                s.append(v)
                v += 20
            }
            s.append(2048)
            return s
        }()

        // Find current index
        let currentVal = dmLogContextSize == Int.max ? 0 : dmLogContextSize
        let selectedIndex: Int
        if currentVal == 0 || currentVal >= 2048 {
            selectedIndex = 0  // unlimited
        } else {
            selectedIndex = steps.enumerated().min(by: { abs($0.element - currentVal) < abs($1.element - currentVal) })?.offset ?? 0
        }

        showDMLogRoller(steps: steps, selectedIndex: selectedIndex)
    }

    private func showDMLogRoller(steps: [Int], selectedIndex: Int) {
        clearTerminal()
        printTitle("DM Log Context")
        print("  How many adventure log entries are", color: .dimGreen)
        print("  sent to the AI DM for context.", color: .dimGreen)
        print("  More = better narrative continuity", color: .dimGreen)
        print("  but uses more AI tokens.", color: .dimGreen)
        print("")

        // Show scroll wheel: 2 above, current, 2 below
        for offset in -2...2 {
            let idx = selectedIndex + offset
            if idx < 0 || idx >= steps.count {
                print("")
                continue
            }
            let val = steps[idx]
            let label = (val == 0 || val >= 2048) ? "Unlimited" : "\(val)"
            if offset == 0 {
                print("    > \(label) <", color: .brightGreen, bold: true)
            } else {
                print("      \(label)", color: .dimGreen)
            }
        }
        print("")

        var options: [MenuOption] = []
        options.append(MenuOption("▲", isDisabled: selectedIndex <= 0))
        options.append(MenuOption("▼", isDisabled: selectedIndex >= steps.count - 1))
        options.append(MenuOption("Set", tint: .navigation))

        showMenuOptions(options)
        closeHandler = { [weak self] in
            self?.showDMSettingsSubMenu()
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1: // Up
                if selectedIndex > 0 {
                    self.showDMLogRoller(steps: steps, selectedIndex: selectedIndex - 1)
                }
            case 2: // Down
                if selectedIndex < steps.count - 1 {
                    self.showDMLogRoller(steps: steps, selectedIndex: selectedIndex + 1)
                }
            case 3: // Set
                let val = steps[selectedIndex]
                self.dmLogContextSize = (val == 0 || val >= 2048) ? Int.max : val
                self.showDMSettingsSubMenu()
            default: break
            }
        }
    }

    private var mapPreviewTorchOn: Bool = true

    func showMapRadiusMenu() {
        clearTerminal()
        printTitle("Map Radius")
        print("  How far you can see on the minimap.", color: .dimGreen)
        print("  Without a torch, visibility drops to 1.", color: .dimGreen)
        print("  Larger values may cause scrolling.", color: .dimGreen)
        print("")
        let hasTorch = party.contains { char in
            char.inventory.contains { $0.name.lowercased().contains("torch") }
        }
        let effective = effectiveMapRadius()
        print("  Setting: \(mapRadius)  Effective: \(effective)", color: .brightGreen)
        if !hasTorch {
            print("  No torch — visibility reduced!", color: .yellow)
        }
        print("")

        // Show map preview if in a dungeon
        if let dungeon = dungeon {
            let previewLabel = mapPreviewTorchOn ? "TORCH ON" : "TORCH OFF"
            print("  PREVIEW (\(previewLabel)):", color: .cyan, bold: true)
            let previewMap = dungeon.getMapDisplay(visibilityRadius: mapRadius, torchLit: mapPreviewTorchOn)
            printLines(previewMap, color: mapPreviewTorchOn ? .dimGreen : .red, size: mapFontSize)
            print("")
        }

        var menuOpts = ["1 (Compact)", "2 (Normal)", "3 (Wide)"]
        if dungeon != nil {
            menuOpts.append(mapPreviewTorchOn ? "Torch Off" : "Torch On")
        }
        menuOpts.append("Done")

        showMenu(menuOpts)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= 3 {
                self.mapRadius = choice
                self.showMapRadiusMenu()
            } else if dungeon != nil && choice == 4 {
                self.mapPreviewTorchOn.toggle()
                self.showMapRadiusMenu()
            } else {
                self.showGameplaySettings()
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

        let options = FontSizeSetting.allCases.map { $0.displayName }
        showMenu(options)

        closeHandler = { [weak self] in self?.showAccessibilityMenu() }
        menuHandler = { [weak self] choice in
            let selected = FontSizeSetting.allCases[choice - 1]
            self?.fontSizeSetting = selected
            self?.print("")
            self?.print("Font size set to: \(selected.displayName)", color: .brightGreen)
            self?.print("")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.showFontSizeMenu()
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
            print("  HOW TO GET YOUR KEY:", color: .cyan, bold: true)
            print("  1. Tap 'Get Free Key' below", color: .dimGreen)
            print("  2. Sign in with your Google account", color: .dimGreen)
            print("  3. Click 'Create API Key'", color: .dimGreen)
            print("  4. A long key starting with 'AIza'", color: .dimGreen)
            print("     will appear — tap the copy icon", color: .dimGreen)
            print("  5. Come back here and tap 'Paste Key'", color: .dimGreen)
            print("")
            print("  Google lets you view your key again", color: .dimGreen)
            print("  later, so don't worry if you lose it.", color: .dimGreen)
        } else if provider == .anthropic {
            print("  Claude is Anthropic's AI — one of", color: .dimGreen)
            print("  the best DMs available. Requires a", color: .dimGreen)
            print("  paid account with credit.", color: .dimGreen)
            print("")
            print("  HOW TO GET YOUR KEY:", color: .cyan, bold: true)
            print("  1. Tap 'Get Key' — this opens the", color: .dimGreen)
            print("     Anthropic console API keys page", color: .dimGreen)
            print("  2. Sign in or create a free account", color: .dimGreen)
            print("  3. Click the '+ Create Key' button", color: .dimGreen)
            print("  4. Give it any name (e.g. 'DnD')", color: .dimGreen)
            print("  5. Your key appears — it starts with", color: .dimGreen)
            print("     sk-ant-api03-... Copy it NOW!", color: .dimGreen)
            print("  6. Come back here and tap 'Paste Key'", color: .dimGreen)
            print("")
            print("  IMPORTANT:", color: .red, bold: true)
            print("  The key is shown ONLY ONCE when you", color: .yellow)
            print("  create it. You cannot go back to view", color: .yellow)
            print("  or copy it later. If you lose it, you", color: .yellow)
            print("  must delete the old key and create a", color: .yellow)
            print("  new one. So copy it straight away!", color: .yellow)
            print("")
            print("  COST: Claude uses pay-as-you-go.", color: .cyan)
            print("  A typical dungeon session costs only", color: .dimGreen)
            print("  a few pence. Add credit at:", color: .dimGreen)
            print("  console.anthropic.com/settings/billing", color: .dimGreen)
        } else if provider == .openAI {
            print("  ChatGPT is OpenAI's AI. Requires a", color: .dimGreen)
            print("  paid account with credit.", color: .dimGreen)
            print("")
            print("  HOW TO GET YOUR KEY:", color: .cyan, bold: true)
            print("  1. Tap 'Get Key' — this opens the", color: .dimGreen)
            print("     OpenAI API keys page", color: .dimGreen)
            print("  2. Sign in or create an account", color: .dimGreen)
            print("  3. Click '+ Create new secret key'", color: .dimGreen)
            print("  4. Give it any name (e.g. 'DnD')", color: .dimGreen)
            print("  5. Your key appears — it starts with", color: .dimGreen)
            print("     sk-... Copy it NOW!", color: .dimGreen)
            print("  6. Come back here and tap 'Paste Key'", color: .dimGreen)
            print("")
            print("  IMPORTANT:", color: .red, bold: true)
            print("  The key is shown ONLY ONCE when you", color: .yellow)
            print("  create it. You cannot go back to view", color: .yellow)
            print("  or copy it later. If you lose it, you", color: .yellow)
            print("  must delete the old key and create a", color: .yellow)
            print("  new one. So copy it straight away!", color: .yellow)
            print("")
            print("  COST: OpenAI uses pay-as-you-go.", color: .cyan)
            print("  A typical dungeon session costs only", color: .dimGreen)
            print("  a few pence. Add credit at:", color: .dimGreen)
            print("  platform.openai.com/settings/billing", color: .dimGreen)
        }

        // Show existing key status
        if let existingKey = DMEngine.shared.apiKey, !existingKey.isEmpty {
            print("")
            let preview = String(existingKey.suffix(6))
            print("  Current key: ...\(preview)", color: .brightGreen)
            print("  Setting a new key will replace it.", color: .dimGreen)
        }

        // Note about key preservation
        let otherProviders = AIProvider.allCases.filter { $0 != provider && DMEngine.shared.apiKey(for: $0) != nil }
        if !otherProviders.isEmpty {
            let names = otherProviders.map { $0.displayName }.joined(separator: ", ")
            print("")
            print("  Keys saved for: \(names)", color: .dimGreen)
            print("  Switch back any time — keys are kept.", color: .dimGreen)
        }
        print("")

        var options = [String]()
        if provider == .google {
            options.append("Get Free Key")
        } else {
            options.append("Get Key")
        }
        options.append("Paste Key")
        options.append("Type Key")

        closeHandler = { [weak self] in
            self?.closeHandler = nil
            self?.showSettings()
        }
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == 1 {
                // Open the provider's key URL in Safari
                let urlString: String
                switch provider {
                case .google: urlString = "https://aistudio.google.com/apikey"
                case .anthropic: urlString = "https://console.anthropic.com/settings/keys"
                case .openAI: urlString = "https://platform.openai.com/api-keys"
                }
                if let url = URL(string: urlString) {
                    DispatchQueue.main.async {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #elseif os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
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
                    self?.print("  KEY TEST FAILED", color: .red, bold: true)
                    self?.print("")
                    if let msg = errorMessage {
                        // Wrap long error messages
                        let maxLen = 30
                        var remaining = msg
                        while !remaining.isEmpty {
                            let line = String(remaining.prefix(maxLen))
                            remaining = String(remaining.dropFirst(line.count))
                            self?.print("  \(line)", color: .yellow)
                        }
                        self?.print("")
                        // Provide helpful guidance based on error
                        let msgLower = msg.lowercased()
                        if msgLower.contains("401") || msgLower.contains("authentication") || msgLower.contains("invalid") || msgLower.contains("incorrect") {
                            self?.print("  LIKELY CAUSE:", color: .cyan, bold: true)
                            self?.print("  The API key is invalid or expired.", color: .dimGreen)
                            self?.print("  Create a new key and try again.", color: .dimGreen)
                            self?.print("  Remember: keys can only be copied", color: .dimGreen)
                            self?.print("  at the moment of creation!", color: .dimGreen)
                        } else if msgLower.contains("402") || msgLower.contains("billing") || msgLower.contains("credit") || msgLower.contains("payment") || msgLower.contains("insufficient") {
                            self?.print("  LIKELY CAUSE:", color: .cyan, bold: true)
                            self?.print("  No credit on your account.", color: .dimGreen)
                            self?.print("  Add credit/payment method at", color: .dimGreen)
                            self?.print("  your provider's billing page.", color: .dimGreen)
                        } else if msgLower.contains("403") || msgLower.contains("permission") || msgLower.contains("forbidden") {
                            self?.print("  LIKELY CAUSE:", color: .cyan, bold: true)
                            self?.print("  Your key doesn't have permission", color: .dimGreen)
                            self?.print("  to use this API. Check your", color: .dimGreen)
                            self?.print("  account settings.", color: .dimGreen)
                        } else if msgLower.contains("429") || msgLower.contains("rate") || msgLower.contains("quota") {
                            self?.print("  LIKELY CAUSE:", color: .cyan, bold: true)
                            self?.print("  Rate limit or quota exceeded.", color: .dimGreen)
                            self?.print("  Wait a minute and try again,", color: .dimGreen)
                            self?.print("  or check your usage limits.", color: .dimGreen)
                        } else if msgLower.contains("connection") || msgLower.contains("network") || msgLower.contains("timeout") {
                            self?.print("  LIKELY CAUSE:", color: .cyan, bold: true)
                            self?.print("  No internet connection.", color: .dimGreen)
                            self?.print("  Check your WiFi/mobile data", color: .dimGreen)
                            self?.print("  and try again.", color: .dimGreen)
                        } else if msgLower.contains("404") || msgLower.contains("not_found") || msgLower.contains("model") {
                            self?.print("  LIKELY CAUSE:", color: .cyan, bold: true)
                            self?.print("  The AI model is unavailable.", color: .dimGreen)
                            self?.print("  This may be a temporary issue.", color: .dimGreen)
                            self?.print("  Try again later.", color: .dimGreen)
                        } else {
                            self?.print("  Check the key and try again.", color: .dimGreen)
                        }
                    } else {
                        self?.print("  Unknown error. Check the key", color: .dimGreen)
                        self?.print("  and try again.", color: .dimGreen)
                    }
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

        // Track line ranges for each entry (for text long-press)
        var entryLineRanges: [(entry: HallOfFameEntry, startLine: Int, endLine: Int)] = []

        if entries.isEmpty {
            print("  No adventures recorded yet.", color: .dimGreen)
            print("  Complete a dungeon to earn your place!", color: .dimGreen)
            print("")

            closeHandler = { [weak self] in
                self?.showMainMenu()
            }
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            for (index, entry) in entries.enumerated() {
                let outcomeTag = entry.outcome == .victory ? "W" : "L"
                let outcomeColor: TerminalColor = entry.outcome == .victory ? .yellow : .red

                let num = "\(index + 1)."
                let name = String(entry.dungeonName.prefix(20))
                print("\(num) \(name) Lv.\(entry.dungeonLevel) \(outcomeTag) \(entry.score)pts", color: outcomeColor)

                let day = entry.gameTimeMinutes / 1440 + 1
                printWrapped(entry.partyDescription, indent: 3, color: .dimGreen)
                printWrapped("Gold:\(entry.goldCollected) Slain:\(entry.monstersSlain) Rooms:\(entry.roomsExplored)/\(entry.totalRooms) Day \(day)", indent: 3, color: .dimGreen)
                print("   \(dateFormatter.string(from: entry.date))", color: .dimGreen)
                print("")
            }

            showMenu(["Tell a Tale"])
            closeHandler = { [weak self] in
                self?.showMainMenu()
            }
            menuHandler = { [weak self] choice in
                if choice == 1 {
                    self?.showTaleSelector(entries: entries)
                }
            }
        }
    }

    /// Retro ASCII scroll-wheel style tale selector
    private func showTaleSelector(entries: [HallOfFameEntry], selectedIndex: Int = 0) {
        clearTerminal()
        suppressAutoScroll = true
        scrollLocked = true
        printTitle("Choose a Tale")
        print("")

        let count = entries.count

        // ASCII scroll display — show 5 slots with the selected one highlighted
        let scrollArt = [
            "  ╔══════════════════════════╗",
            "  ║  ▲ scroll up             ║",
            "  ╠══════════════════════════╣",
        ]
        printLines(scrollArt, color: .dimGreen)

        // Show entries: 2 above, current, 2 below
        for offset in -2...2 {
            let idx = ((selectedIndex + offset) % count + count) % count
            let entry = entries[idx]
            let outcomeTag = entry.outcome == .victory ? "W" : "L"
            let name = String(entry.dungeonName.prefix(16))
            let line = "\(idx + 1). \(name) \(outcomeTag) \(entry.score)pts"
            let padded = line.padding(toLength: 26, withPad: " ", startingAt: 0)

            if offset == 0 {
                // Selected entry — highlighted
                print("  ║▶ \(padded)◀║", color: .yellow, bold: true)
            } else {
                // Dimmed neighbours
                let dimColor: TerminalColor = abs(offset) == 1 ? .dimGreen : .gray
                print("  ║  \(padded)  ║", color: dimColor)
            }
        }

        let scrollArtBottom = [
            "  ╠══════════════════════════╣",
            "  ║  ▼ scroll down           ║",
            "  ╚══════════════════════════╝",
        ]
        printLines(scrollArtBottom, color: .dimGreen)
        print("")

        // Show selected entry details
        let entry = entries[selectedIndex]
        printWrapped(entry.partyDescription, indent: 4, color: .cyan)
        let day = entry.gameTimeMinutes / 1440 + 1
        printWrapped("Gold:\(entry.goldCollected)  Slain:\(entry.monstersSlain)  Rooms:\(entry.roomsExplored)/\(entry.totalRooms)  Day \(day)", indent: 4, color: .dimGreen)
        print("")

        var options = ["▲ Prev", "▼ Next", "Read Tale"]
        if count > 3 {
            options.insert("Surprise Me", at: 2)
        }

        showMenu(options)
        menuHandler = { [weak self] choice in
            let selected = options[choice - 1]
            switch selected {
            case "▲ Prev":
                let prev = (selectedIndex - 1 + count) % count
                self?.showTaleSelector(entries: entries, selectedIndex: prev)
            case "▼ Next":
                let next = (selectedIndex + 1) % count
                self?.showTaleSelector(entries: entries, selectedIndex: next)
            case "Surprise Me":
                let rand = Int.random(in: 0..<count)
                self?.showHallOfFameDetail(entries[rand])
            case "Read Tale":
                self?.showHallOfFameDetail(entries[selectedIndex])
            default:
                self?.showHallOfFame()
            }
        }

        closeHandler = { [weak self] in
            self?.closeHandler = nil
            self?.showHallOfFame()
        }

        // Swipe navigation
        cardPositionLabel = cardLabel(selectedIndex + 1, of: count)
        swipeLeftHandler = { [weak self] in
            let next = (selectedIndex + 1) % count
            self?.showTaleSelector(entries: entries, selectedIndex: next)
        }
        swipeRightHandler = { [weak self] in
            let prev = (selectedIndex - 1 + count) % count
            self?.showTaleSelector(entries: entries, selectedIndex: prev)
        }
        swipeRandomHandler = count > 1 ? { [weak self] in
            let r = Int.random(in: 0..<count)
            self?.showTaleSelector(entries: entries, selectedIndex: r)
        } : nil
    }

    /// Generate an exciting narrative summary of a Hall of Fame entry
    private func showHallOfFameDetail(_ entry: HallOfFameEntry) {
        clearTerminal()

        let isVictory = entry.outcome == .victory

        // Show appropriate header art
        if isVictory {
            printLines(asciiTrophy, color: .yellow)
        } else {
            printLines(asciiSkull, color: .red)
        }
        print("")

        // Title
        let titleColor: TerminalColor = isVictory ? .yellow : .red
        printTitle(entry.dungeonName)
        print("  Level \(entry.dungeonLevel) — \(isVictory ? "VICTORY" : "DEFEAT")", color: titleColor, bold: true)
        print("")

        // The party
        print("  THE PARTY", color: .cyan, bold: true)

        // Parse class from partyDescription and show art side-by-side
        let members = entry.partyDescription.components(separatedBy: ", ")
        var partyClasses: [CharacterClass] = []
        for member in members {
            // Format: "Name (Class)"
            if let openParen = member.lastIndex(of: "("),
               let closeParen = member.lastIndex(of: ")") {
                let className = String(member[member.index(after: openParen)..<closeParen])
                if let cls = CharacterClass.allCases.first(where: { $0.rawValue == className }) {
                    partyClasses.append(cls)
                }
            }
        }

        // Show party art side-by-side
        if !partyClasses.isEmpty {
            let arts = partyClasses.map { $0.asciiArt }
            let maxLines = arts.map { $0.count }.max() ?? 0
            let colWidth = 12
            for row in 0..<maxLines {
                var line = "   "
                for art in arts {
                    let artLine = row < art.count ? art[row] : ""
                    line += artLine.padding(toLength: colWidth, withPad: " ", startingAt: 0)
                }
                print(line, color: .cyan)
            }
            // Labels
            var labelLine = "   "
            for member in members {
                let name = member.components(separatedBy: " (").first ?? member
                labelLine += String(name.prefix(colWidth - 1)).padding(toLength: colWidth, withPad: " ", startingAt: 0)
            }
            print(labelLine, color: .brightGreen)
        }
        print("")

        // Generate exciting narrative
        print("  THE TALE", color: .cyan, bold: true)
        print("")

        let day = entry.gameTimeMinutes / 1440 + 1
        let hours = (entry.gameTimeMinutes % 1440) / 60
        let explorationPct = entry.totalRooms > 0 ? (entry.roomsExplored * 100 / entry.totalRooms) : 0

        // Opening
        let partySize = entry.partyNames.count
        let firstNames = entry.partyNames.map { $0.components(separatedBy: " ").first ?? $0 }
        let heroList = firstNames.count <= 2
            ? firstNames.joined(separator: " and ")
            : firstNames.dropLast().joined(separator: ", ") + ", and " + (firstNames.last ?? "")

        printWrapped("On a \(day > 1 ? "fateful" : "bold") day, \(heroList) \(partySize == 1 ? "descended" : "descended together") into the depths of \(entry.dungeonName).", indent: 4, color: .green)
        print("")

        // Combat narrative
        if entry.monstersSlain > 0 {
            let combatWord: String
            if entry.monstersSlain >= 15 { combatWord = "carved a bloody path through" }
            else if entry.monstersSlain >= 8 { combatWord = "fought valiantly against" }
            else { combatWord = "clashed with" }

            printWrapped("They \(combatWord) \(entry.monstersSlain) creature\(entry.monstersSlain == 1 ? "" : "s"), winning \(entry.combatsWon) battle\(entry.combatsWon == 1 ? "" : "s") in the darkness below.", indent: 4, color: .green)
            print("")
        }

        // Show a random monster they might have faced
        let possibleMonsters = MonsterType.forLevel(entry.dungeonLevel)
        if let monster = possibleMonsters.randomElement() {
            print("", color: .dimGreen)
            let art = monster.asciiArt
            for line in art {
                print("       \(line)", color: .red)
            }
            printWrapped("Among their foes: the dreaded \(monster.rawValue)...", indent: 4, color: .dimGreen)
            print("")
        }

        // Exploration
        if explorationPct == 100 {
            printWrapped("Every chamber was explored, every corridor mapped — \(entry.roomsExplored) rooms laid bare.", indent: 4, color: .green)
        } else if explorationPct >= 75 {
            printWrapped("They explored \(entry.roomsExplored) of \(entry.totalRooms) rooms, leaving few corners unsearched.", indent: 4, color: .green)
        } else {
            printWrapped("They ventured through \(entry.roomsExplored) of \(entry.totalRooms) rooms before fate intervened.", indent: 4, color: .green)
        }
        print("")

        // Treasure
        if entry.goldCollected > 0 {
            let treasureWord: String
            if entry.goldCollected >= 300 { treasureWord = "amassed a king's ransom of" }
            else if entry.goldCollected >= 100 { treasureWord = "gathered a respectable hoard of" }
            else { treasureWord = "scraped together" }
            printWrapped("\(treasureWord) \(entry.goldCollected) gold pieces.", indent: 4, color: .yellow)
            print("")
        }

        // Duration
        printWrapped("The adventure lasted \(day > 1 ? "\(day) days" : "\(hours) hours") in the depths.", indent: 4, color: .dimGreen)
        print("")

        // Ending
        if isVictory {
            printLines(asciiSwords, color: .yellow)
            print("")
            printWrapped("Against all odds, they emerged triumphant! The dungeon boss fell, and \(entry.dungeonName) was conquered. Their names echo in the halls of legend.", indent: 4, color: .yellow)
        } else {
            printWrapped("But the darkness proved too strong. One by one, they fell... Their sacrifice is remembered, even if their quest ended in shadow.", indent: 4, color: .red)
        }
        print("")

        // Score
        print("  FINAL SCORE: \(entry.score) points", color: isVictory ? .yellow : .red, bold: true)
        print("")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        print("  Recorded: \(dateFormatter.string(from: entry.date))", color: .dimGreen)
        print("")
        print("")

        closeHandler = { [weak self] in
            SpeechEngine.shared.stop()
            self?.showHallOfFame()
        }

        // If DM voice is on, narrate the tale
        if SpeechEngine.shared.isEnabled {
            let heroList = entry.partyNames.map { $0.components(separatedBy: " ").first ?? $0 }.joined(separator: ", ")
            var narration = "\(heroList) entered \(entry.dungeonName). "
            if entry.monstersSlain > 0 {
                narration += "They slew \(entry.monstersSlain) creatures and won \(entry.combatsWon) battles. "
            }
            narration += "They explored \(entry.roomsExplored) of \(entry.totalRooms) rooms. "
            if entry.goldCollected > 0 {
                narration += "They collected \(entry.goldCollected) gold. "
            }
            if isVictory {
                narration += "Against all odds, they emerged triumphant!"
            } else {
                narration += "But the darkness proved too strong, and they fell."
            }
            SpeechEngine.shared.speak(narration)
        }
    }

    // MARK: - New Game

    func startNewGame() {
        clearAllUndoRedo()
        clearTerminal()
        printTitle("New Adventure")
        print("How many adventurers in your party?", color: .brightGreen)
        print("")
        print("  Long-press: auto-create party", color: .dimGreen)
        print("  (you play one, the rest are AI)", color: .dimGreen)
        if multiplayerEnabled {
            print("")
            print("  Multiplayer: after creating your", color: .cyan)
            print("  party, swap any AI slot to Remote", color: .cyan)
            print("  in Party Review, or later via", color: .cyan)
            print("  Party Status during the game.", color: .cyan)
        }
        print("")

        showMenuOptions([
            MenuOption("1 Character"), MenuOption("2 Characters"),
            MenuOption("3 Characters"), MenuOption("4 Characters"),
            MenuOption("Random Party"),
            MenuOption("Help", tint: .navigation),
        ])

        closeHandler = { [weak self] in
            self?.clearTerminal()
            self?.showPlayMenu()
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 6 {
                self.showNewGameHelp()
                return
            }
            if choice == 5 {
                self.createRandomParty()
                return
            }
            self.totalCharacters = choice
            self.creatingCharacterIndex = 0
            self.party = []
            self.pendingRemoteSlots.removeAll()
            self.isMultiplayer = false
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
    private func createRandomParty(count: Int? = nil, allAI: Bool = false, presetRemote: Bool = false) {
        let count = count ?? Int.random(in: 1...4)
        party = []
        creatingCharacterIndex = 0
        totalCharacters = count
        pendingRemoteSlots.removeAll()

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
            if isAI { character.markAsAI() }

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

        // For multiplayer new game, pre-set the last AI slot as Remote
        if presetRemote && count >= 2 {
            pendingRemoteSlots.insert(count - 1)
            isMultiplayer = true
        }

        showPartyReview()
    }

    /// Show party roster with options to swap AI/Remote slots before starting
    private func showPartyReview() {
        clearTerminal()
        printTitle("Party Review")

        // Display roster with type tags — aligned past the number
        for (i, char) in party.enumerated() {
            let tag: String
            if pendingRemoteSlots.contains(i) {
                tag = " [Remote]"
            } else if char.isComputerControlled {
                tag = " [Auto]"
            } else {
                tag = " [You]"
            }
            let num = "\(i + 1)"
            // "  1. Name [Tag]"  then indented lines aligned under the name (past "1. ")
            let indentCount = 2 + num.count + 2  // "  " + number + ". "
            print("  \(num). \(char.name)\(tag)", color: .brightGreen)
            printWrapped("\(char.race.rawValue) \(char.characterClass.rawValue)", indent: indentCount, color: .dimGreen)
            printWrapped("HP:\(char.maxHP)  AC:\(char.armorClass)  \(char.characterClass.primaryAbility.abbreviation):\(char.abilityScores.score(for: char.characterClass.primaryAbility))", indent: indentCount, color: .dimGreen)
        }
        print("")

        let hasRemote = !pendingRemoteSlots.isEmpty

        // Build menu options
        var opts: [String] = []
        var actions: [() -> Void] = []

        // Per-character buttons — just the name, clicking shows card
        if party.count >= 1 {
            for (i, char) in party.enumerated() {
                let shortN = shortName(for: char)
                opts.append(shortN)
                actions.append { [weak self] in
                    self?.showCharacterReviewCard(index: i)
                }
            }
        }

        opts.append("Help")
        actions.append { [weak self] in self?.showPartyReviewHelp() }

        // Bottom row: Start
        opts.append(hasRemote ? "Start Matchmaker" : "Enter the Dungeon")
        actions.append { [weak self] in
            guard let self = self else { return }
            if hasRemote { self.createMultiplayerMatch() } else { self.startAdventure() }
        }
        showMenu(opts, defaultIndex: opts.count - 1)

        closeHandler = { [weak self] in
            guard let self = self else { return }
            let wasMultiplayer = !self.pendingRemoteSlots.isEmpty
            self.party = []
            self.pendingRemoteSlots.removeAll()
            if wasMultiplayer { self.showPlayMenu() } else { self.startNewGame() }
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
        // Long-press character buttons → show character card
        if party.count >= 1 {
            menuLongPressHandler = { [weak self] choice in
                guard let self = self else { return }
                guard choice >= 1 && choice <= self.party.count else { return }
                self.showCardForCharacter(named: self.party[choice - 1].name)
            }
        }

        let partyKey = "partyReview"
        // Clear stacks on fresh entry (not when refreshing after undo/redo/reroll)
        if currentUndoScreen != partyKey {
            clearUndoRedo(for: partyKey)
        }
        currentUndoScreen = partyKey

        // Dice icon on input bar — reroll party
        rerollHandler = { [weak self] in
            guard let self = self else { return }
            if let snapshot = try? JSONEncoder().encode(self.party) {
                self.pushScreenUndo(screen: partyKey, data: snapshot)
            }
            let savedRemote = self.pendingRemoteSlots
            let partyCount = self.party.count
            self.createRandomParty(count: partyCount, allAI: true, presetRemote: !savedRemote.isEmpty)
        }

        // Undo — restore previous party
        undoHandler = screenHasUndo(partyKey) ? { [weak self] in
            guard let self = self else { return }
            if let snapshot = try? JSONEncoder().encode(self.party) {
                self.pushScreenRedo(screen: partyKey, data: snapshot)
            }
            if let prev = self.popScreenUndo(screen: partyKey),
               let restored = try? JSONDecoder().decode([Character].self, from: prev) {
                self.party = restored
                self.showPartyReview()
            }
        } : nil

        // Redo — restore next party
        redoHandler = screenHasRedo(partyKey) ? { [weak self] in
            guard let self = self else { return }
            if let snapshot = try? JSONEncoder().encode(self.party) {
                self.pushScreenUndo(screen: partyKey, data: snapshot)
            }
            if let next = self.popScreenRedo(screen: partyKey),
               let restored = try? JSONDecoder().decode([Character].self, from: next) {
                self.party = restored
                self.showPartyReview()
            }
        } : nil
    }

    /// Show character card with edit options — dulled if game in progress
    private func showCharacterReviewCard(index: Int) {
        guard index < party.count else { showPartyReview(); return }
        let char = party[index]
        let inGame = dungeon != nil

        clearTerminal()

        // Show character card art — centred with padding
        let artLines = char.characterClass.asciiArt
        let artMax = artLines.map { $0.count }.max() ?? 0
        let artPadCount = max(0, (31 - artMax) / 2)
        let artPad = String(repeating: " ", count: artPadCount)
        printLines(artLines.map { artPad + $0 }, color: .cyan)
        print("")

        // Name and identity
        print("  \(char.name)", color: .brightGreen, bold: true)
        let typeStr: String
        if pendingRemoteSlots.contains(index) {
            typeStr = "Remote"
        } else if char.isComputerControlled {
            typeStr = "Auto (Robot)"
        } else {
            typeStr = "Local (You)"
        }
        print("  Lv\(char.level) \(char.race.rawValue) \(char.characterClass.rawValue) · \(typeStr)", color: .dimGreen)
        print("")

        // Core stats
        let fm: (Int) -> String = { $0 >= 0 ? "+\($0)" : "\($0)" }
        let s = char.abilityScores
        print("  HP: \(char.currentHP)/\(char.maxHP)   AC: \(char.armorClass)", color: .cyan)
        print("  Gold: \(char.gold)   XP: \(char.experiencePoints)", color: .dimGreen)
        print("")

        // Ability scores
        print("  STR \(s.strength)(\(fm(s.modifier(for: .strength))))  INT \(s.intelligence)(\(fm(s.modifier(for: .intelligence))))", color: .dimGreen)
        print("  DEX \(s.dexterity)(\(fm(s.modifier(for: .dexterity))))  WIS \(s.wisdom)(\(fm(s.modifier(for: .wisdom))))", color: .dimGreen)
        print("  CON \(s.constitution)(\(fm(s.modifier(for: .constitution))))  CHA \(s.charisma)(\(fm(s.modifier(for: .charisma))))", color: .dimGreen)
        print("")

        // Equipment
        if let w = char.equippedWeapon { print("  Weapon: \(w.name)", color: .cyan) }
        if let a = char.equippedArmor { print("  Armour: \(a.name)", color: .cyan) }
        if let sh = char.equippedShield { print("  Shield: \(sh.name)", color: .cyan) }
        print("")

        // Skills
        if !char.skillProficiencies.isEmpty {
            let skillList = char.skillProficiencies.map { $0.rawValue }.sorted().joined(separator: ", ")
            print("  Skills: \(skillList)", color: .dimGreen)
            print("")
        }

        // Mid-adventure warning
        if inGame {
            let warnings = [
                "Best not to change horses midstream...",
                "A wise adventurer plays the hand they're dealt.",
                "Changing now could upset the balance of the party.",
                "The dungeon is no place for second thoughts.",
                "Your companions may not take kindly to sudden changes.",
            ]
            printWrapped(warnings.randomElement()!, indent: 2, color: .yellow)
            print("  (Long-press to edit anyway)", color: .dimGreen)
            print("")
        }

        // Build edit options — disabled if in-game
        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        menuOpts.append(MenuOption("Edit Type", isDisabled: inGame))
        actions.append { [weak self] in self?.showChangePlayerType(index: index) }

        menuOpts.append(MenuOption("Edit Race", isDisabled: inGame))
        actions.append { [weak self] in self?.showChangeRace(index: index) }

        menuOpts.append(MenuOption("Edit Class", isDisabled: inGame))
        actions.append { [weak self] in self?.showChangeClass(index: index) }

        menuOpts.append(MenuOption("Edit Voice", isDisabled: inGame))
        actions.append { [weak self] in self?.showCharacterVoiceEdit(index: index) }

        menuOpts.append(MenuOption("Help", tint: .navigation))
        actions.append { [weak self] in self?.showCharacterReviewCardHelp(index: index, inGame: inGame) }

        showMenuOptions(menuOpts)

        closeHandler = { [weak self] in self?.showPartyReview() }
        menuHandler = { [weak self] choice in
            guard choice > 0 && choice <= actions.count else { return }
            // Block disabled buttons on normal tap
            if menuOpts[choice - 1].isDisabled { return }
            actions[choice - 1]()
        }
        // Long-press bypasses disabled state for in-game edits
        menuLongPressHandler = { choice in
            guard choice > 0 && choice <= actions.count else { return }
            actions[choice - 1]()
        }
    }

    private func showCharacterReviewCardHelp(index: Int, inGame: Bool) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Character Review Help")
        print("")
        printWrapped("Tap a character's name to view their card and edit options.", indent: 2, color: .green)
        print("")
        if inGame {
            printWrapped("Your adventure is underway! Edit buttons are greyed out to prevent accidental changes. If you really need to make a change, long-press the button to override.", indent: 2, color: .yellow)
            print("")
        }
        printWrapped("Edit Type: Switch between Local (you control), Auto (AI robot), or Remote (multiplayer) control.", indent: 2, color: .dimGreen)
        printWrapped("Edit Race: Change the character's race (Elf, Dwarf, etc.).", indent: 2, color: .dimGreen)
        printWrapped("Edit Class: Change the character's class (Fighter, Wizard, etc.).", indent: 2, color: .dimGreen)
        printWrapped("Edit Voice: Customise the character's speech voice.", indent: 2, color: .dimGreen)
        printWrapped("View Card: See the full character stat card.", indent: 2, color: .dimGreen)
        print("")

        closeHandler = { [weak self] in self?.showCharacterReviewCard(index: index) }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showCharacterReviewCard(index: index) }
    }

    private func showEditCharacter(index: Int) {
        guard index < party.count else { showPartyReview(); return }
        let char = party[index]
        clearTerminal()

        // Start edit tracking if not already tracking this character
        if editingCharacterIndex != index {
            beginEditTracking(index: index, inGame: false)
        }

        printTitle("Edit — \(char.name)")

        // Show current details
        printLines(char.characterClass.asciiArt, color: .cyan)
        print("")
        let typeStr: String
        if pendingRemoteSlots.contains(index) {
            typeStr = "Remote"
        } else if char.isComputerControlled {
            typeStr = "Auto (Robot)"
        } else {
            typeStr = "Local (You)"
        }
        print("  Type:  \(typeStr)", color: .yellow)
        print("  Race:  \(char.race.rawValue)", color: .green)
        print("  Class: \(char.characterClass.rawValue)", color: .green)
        print("  HP:\(char.maxHP) AC:\(char.armorClass)", color: .dimGreen)
        print("")

        var opts: [String] = []
        var actions: [() -> Void] = []

        // Player type options
        opts.append("Edit Type")
        actions.append { [weak self] in
            self?.showChangePlayerType(index: index)
        }

        // Edit race
        opts.append("Edit Race")
        actions.append { [weak self] in
            self?.showChangeRace(index: index)
        }

        // Edit class
        opts.append("Edit Class")
        actions.append { [weak self] in
            self?.showChangeClass(index: index)
        }

        // Edit voice
        opts.append("Edit Voice")
        actions.append { [weak self] in
            self?.showCharacterVoiceEdit(index: index)
        }

        // View card
        opts.append("View Card")
        actions.append { [weak self] in
            self?.showCharacterCardFromEdit(index: index)
        }

        // Help
        opts.append("Help")
        actions.append { [weak self] in
            self?.showEditCharacterHelp(index: index)
        }

        showMenu(opts)

        // Restore undo/redo handlers
        updateUndoRedoHandlers(index: index)

        closeHandler = { [weak self] in
            self?.endEditTracking()
            self?.showPartyReview()
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showEditCharacterHelp(index: Int) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Edit Character — Help")
        print("")

        print("  OVERVIEW", color: .cyan, bold: true)
        printWrapped("Customise this character before entering the dungeon. Each change takes effect immediately — no need to confirm.", indent: 2, color: .dimGreen)
        print("")

        print("  CHANGE TYPE", color: .cyan, bold: true)
        printWrapped("Local (You) — you control this character in combat and exploration.", indent: 2, color: .dimGreen)
        printWrapped("Auto (Robot) — the AI controls this character. Names prefixed with \"R.\" indicate robot companions.", indent: 2, color: .dimGreen)
        printWrapped("Remote — reserved for a multiplayer partner via Game Centre (requires Multiplayer enabled in Settings).", indent: 2, color: .dimGreen)
        print("")

        print("  CHANGE RACE", color: .cyan, bold: true)
        printWrapped("Each race has unique ability score bonuses and traits. For example, Dwarves gain +2 Constitution and poison resistance, while Elves get +2 Dexterity and darkvision.", indent: 2, color: .dimGreen)
        print("")

        print("  CHANGE CLASS", color: .cyan, bold: true)
        printWrapped("Class determines HP, armour, weapons, and abilities. Fighters are tough and straightforward; Wizards are fragile but powerful. Changing class re-rolls HP and starting equipment.", indent: 2, color: .dimGreen)
        print("")

        print("  EDIT VOICE", color: .cyan, bold: true)
        printWrapped("Configure text-to-speech for this companion. You can toggle voices on or off, preview how they sound, and switch between automatic character-matched voices or random assignment.", indent: 2, color: .dimGreen)
        print("")

        print("  VIEW CARD", color: .cyan, bold: true)
        printWrapped("See the character's full stat card with ability scores, HP, equipment, and more. Swipe left/right to browse other party members' cards.", indent: 2, color: .dimGreen)
        print("")

        print("  THINGS TO KNOW", color: .cyan, bold: true)
        printWrapped("Changing race or class re-generates the character's stats. The name stays the same. You can undo/redo changes with swipe gestures if available.", indent: 2, color: .dimGreen)
        printWrapped("At least one character must be Local (You) — you need someone to control!", indent: 2, color: .yellow)
        printWrapped("Tap ✕ to return to Party Review when you're done editing.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showEditCharacter(index: index) }
    }

    private func showChangePlayerType(index: Int) {
        guard index < party.count else { showPartyReview(); return }
        let char = party[index]
        let hasHumanElsewhere = party.enumerated().contains(where: { $0.offset != index && !$0.element.isComputerControlled && !pendingRemoteSlots.contains($0.offset) })

        clearTerminal()
        printTitle("Player Type — \(shortName(for: char))")
        let currentType: String
        if pendingRemoteSlots.contains(index) { currentType = "Remote" }
        else if char.isComputerControlled { currentType = "Auto (Robot)" }
        else { currentType = "Local (You)" }
        print("  Current: \(currentType)", color: .yellow)
        print("  Who controls this character?", color: .cyan)
        print("")

        var opts: [String] = []
        var typeLabels: [String] = []

        // Local (human) option
        opts.append("Local (You)")
        typeLabels.append("Local (You)")

        // Auto (robot) option — not allowed for solo adventurers
        if party.count > 1 && (hasHumanElsewhere || !char.isComputerControlled) {
            opts.append("Auto (Robot)")
            typeLabels.append("Auto (Robot)")
        }

        // Remote option
        let gcAuth = GameCenterManager.shared.isAuthenticated && party.count >= 2
        if gcAuth && hasHumanElsewhere {
            opts.append("Remote Player")
            typeLabels.append("Remote Player")
        }

        showMenu(opts)

        closeHandler = { [weak self] in self?.showEditCharacter(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            guard choice > 0 && choice <= typeLabels.count else { return }
            let newType = typeLabels[choice - 1]
            // No change? Go back
            if newType == currentType {
                self.showEditCharacter(index: index)
                return
            }
            self.confirmChangeType(index: index, newType: newType, currentType: currentType)
        }
    }

    private func confirmChangeType(index: Int, newType: String, currentType: String) {
        let char = party[index]
        clearTerminal()
        printTitle("Confirm Type Change")
        print("")
        print("  \(shortName(for: char)): \(currentType) → \(newType)", color: .yellow, bold: true)
        print("")

        print("  WHAT CHANGES:", color: .cyan, bold: true)
        switch newType {
        case "Local (You)":
            printWrapped("You will control \(char.name) directly — choosing actions in combat and exploration.", indent: 2, color: .dimGreen)
        case "Auto (Robot)":
            printWrapped("\(char.name) will act on their own using AI — making combat and exploration choices automatically.", indent: 2, color: .dimGreen)
        case "Remote Player":
            printWrapped("Another player will control \(char.name) via Game Centre multiplayer.", indent: 2, color: .dimGreen)
        default: break
        }
        print("")

        showMenu(["Confirm", "Cancel"])
        closeHandler = { [weak self] in self?.showChangePlayerType(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.pushEditSnapshot(index: index)
                switch newType {
                case "Local (You)":
                    self.pendingRemoteSlots.remove(index)
                    self.party[index].unmarkAsAI()
                    if self.pendingRemoteSlots.isEmpty { self.isMultiplayer = false }
                case "Auto (Robot)":
                    self.pendingRemoteSlots.remove(index)
                    self.party[index].markAsAI()
                    if self.pendingRemoteSlots.isEmpty { self.isMultiplayer = false }
                case "Remote Player":
                    self.party[index].unmarkAsAI()
                    self.pendingRemoteSlots.insert(index)
                    self.isMultiplayer = true
                default: break
                }
            }
            self.showEditCharacter(index: index)
        }
    }

    private func showChangeRace(index: Int) {
        guard index < party.count else { showPartyReview(); return }
        clearTerminal()
        printTitle("Change Race")
        print("  Current: \(party[index].race.rawValue)", color: .yellow)
        print("")

        let races = Race.allCases
        showMenu(races.map { $0.rawValue })

        closeHandler = { [weak self] in self?.showEditCharacter(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self, choice >= 1 && choice <= races.count else { return }
            let newRace = races[choice - 1]
            let char = self.party[index]
            if newRace == char.race {
                self.showEditCharacter(index: index)
                return
            }
            self.confirmChangeRace(index: index, newRace: newRace)
        }
    }

    private func confirmChangeRace(index: Int, newRace: Race) {
        let char = party[index]
        let oldRace = char.race

        clearTerminal()
        printTitle("Confirm Race Change")
        print("")
        print("  \(oldRace.rawValue) → \(newRace.rawValue)", color: .yellow, bold: true)
        print("")

        // Show ability score changes
        print("  ABILITY CHANGES:", color: .cyan, bold: true)
        let oldBonuses = Dictionary(oldRace.abilityBonuses, uniquingKeysWith: { a, _ in a })
        let newBonuses = Dictionary(newRace.abilityBonuses, uniquingKeysWith: { a, _ in a })
        let allAbilities: [Ability] = [.strength, .dexterity, .constitution, .intelligence, .wisdom, .charisma]
        for ability in allAbilities {
            let oldB = oldBonuses[ability] ?? 0
            let newB = newBonuses[ability] ?? 0
            if oldB != newB {
                let diff = newB - oldB
                let sign = diff > 0 ? "+" : ""
                print("    \(ability.abbreviation): \(sign)\(diff)", color: diff > 0 ? .brightGreen : .red)
            }
        }

        // Show HP impact
        let oldCon = char.abilityScores.modifier(for: .constitution)
        let oldConBonus = oldBonuses[.constitution] ?? 0
        let newConBonus = newBonuses[.constitution] ?? 0
        let conDiff = newConBonus - oldConBonus
        if conDiff != 0 {
            print("  HP will change (CON modifier \(conDiff > 0 ? "increases" : "decreases"))", color: conDiff > 0 ? .brightGreen : .yellow)
        }
        print("")

        showMenu(["Confirm", "Cancel"])
        closeHandler = { [weak self] in self?.showChangeRace(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.pushEditSnapshot(index: index)
                let char = self.party[index]
                // Remove old racial bonuses
                for (ability, bonus) in oldRace.abilityBonuses {
                    let current = char.abilityScores.score(for: ability)
                    char.abilityScores.set(ability, to: current - bonus)
                }
                // Apply new racial bonuses
                char.race = newRace
                for (ability, bonus) in newRace.abilityBonuses {
                    let current = char.abilityScores.score(for: ability)
                    char.abilityScores.set(ability, to: current + bonus)
                }
                char.recalculateMaxHP()
            }
            self.showEditCharacter(index: index)
        }
    }

    private func showChangeClass(index: Int) {
        guard index < party.count else { showPartyReview(); return }
        clearTerminal()
        printTitle("Change Class")
        print("  Current: \(party[index].characterClass.rawValue)", color: .yellow)
        print("")

        let classes = CharacterClass.allCases
        showMenu(classes.map { $0.rawValue })

        closeHandler = { [weak self] in self?.showEditCharacter(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self, choice >= 1 && choice <= classes.count else { return }
            let newClass = classes[choice - 1]
            let char = self.party[index]
            if newClass == char.characterClass {
                self.showEditCharacter(index: index)
                return
            }
            self.confirmChangeClass(index: index, newClass: newClass)
        }
    }

    private func confirmChangeClass(index: Int, newClass: CharacterClass) {
        let char = party[index]
        let oldClass = char.characterClass

        clearTerminal()
        printTitle("Confirm Class Change")
        printLines(newClass.asciiArt, color: .cyan)
        print("")
        print("  \(oldClass.rawValue) → \(newClass.rawValue)", color: .yellow, bold: true)
        print("")

        print("  WHAT CHANGES:", color: .cyan, bold: true)
        print("    Ability priorities re-ordered for \(newClass.rawValue)", color: .dimGreen)
        print("    Primary: \(newClass.primaryAbility.rawValue)  Hit Die: d\(newClass.hitDie)", color: .green)
        if oldClass.hitDie != newClass.hitDie {
            let hpDir = newClass.hitDie > oldClass.hitDie ? "increase" : "decrease"
            print("    HP will \(hpDir) (d\(oldClass.hitDie) → d\(newClass.hitDie))", color: newClass.hitDie > oldClass.hitDie ? .brightGreen : .yellow)
        }
        print("    New starting equipment (old gear lost)", color: .dimGreen)
        print("    New skill proficiencies", color: .dimGreen)
        let hasSpells = !SpellCatalog.startingSpells(for: newClass).isEmpty
        if hasSpells {
            print("    Gains spellcasting", color: .brightGreen)
        } else if !char.knownSpells.isEmpty {
            print("    Loses spellcasting", color: .yellow)
        }
        print("")

        showMenu(["Confirm", "Cancel"])
        closeHandler = { [weak self] in self?.showChangeClass(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.pushEditSnapshot(index: index)
                self.applyClassChange(index: index, newClass: newClass)
            }
            self.showEditCharacter(index: index)
        }
    }

    private func applyClassChange(index: Int, newClass: CharacterClass) {
        let char = party[index]
        char.characterClass = newClass

        // Re-prioritise ability scores for new class
        let sorted = AbilityScores.standardArray.sorted(by: >)
        for (ability, bonus) in char.race.abilityBonuses {
            let current = char.abilityScores.score(for: ability)
            char.abilityScores.set(ability, to: current - bonus)
        }
        for (idx, ability) in newClass.abilityPriority.enumerated() {
            char.abilityScores.set(ability, to: sorted[idx])
        }
        for (ability, bonus) in char.race.abilityBonuses {
            let current = char.abilityScores.score(for: ability)
            char.abilityScores.set(ability, to: current + bonus)
        }

        char.recalculateMaxHP()

        // Update skills
        char.skillProficiencies.removeAll()
        let skills = Array(newClass.skillChoices.shuffled().prefix(newClass.numSkillChoices))
        for skill in skills { char.skillProficiencies.insert(skill) }

        // Update equipment
        char.inventory.removeAll()
        char.equippedWeapon = nil
        char.equippedArmor = nil
        char.equippedShield = nil
        let equipOptions = ItemCatalog.startingEquipmentOptions(for: newClass)
        if let (_, items) = equipOptions.first {
            for item in items { _ = char.addItem(item) }
        }
        autoEquip(char)

        // Update spells
        char.knownSpells = SpellCatalog.startingSpells(for: newClass)
        char.spellSlots = SpellCatalog.startingSlots(for: newClass, level: 1)

        // Barbarian rage
        if newClass == .barbarian {
            char.rageUsesRemaining = char.rageMaxUses
        }
    }

    private func showPartyReviewHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Party Review — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Shows your adventuring party. Each character has a race, class, HP, armour class, and ability scores. Names with \"R.\" (like R. Daneel) are robot companions — they act on their own in combat.", indent: 2, color: .dimGreen)
        print("")

        print("  BUTTONS", color: .cyan, bold: true)
        printWrapped("Edit — change a character's type (You, Robot, or Remote), race, or class.", indent: 2, color: .dimGreen)
        printWrapped("Random Party — re-roll the entire party with random characters.", indent: 2, color: .dimGreen)
        printWrapped("Done / Start Matchmaker — proceed to name your dungeon and begin.", indent: 2, color: .dimGreen)
        print("")

        print("  WHAT NEXT", color: .cyan, bold: true)
        printWrapped("Edit your party until you're happy, then tap Done to name your dungeon, choose difficulty, and start exploring!", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showPartyReview() }
    }

    private func showRemotePlayerHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Multiplayer — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Multiplayer uses Apple Game Centre. Each player controls one or more characters. Turns are asynchronous — you don't need to be online at the same time.", indent: 2, color: .dimGreen)
        print("")

        print("  SETUP", color: .cyan, bold: true)
        printWrapped("1. Enable Multiplayer in Settings > Gameplay.", indent: 2, color: .dimGreen)
        printWrapped("2. In Party Review, set a character to 'Remote'.", indent: 2, color: .dimGreen)
        printWrapped("3. Tap Start Matchmaker to invite via Game Centre.", indent: 2, color: .dimGreen)
        print("")

        print("  DURING PLAY", color: .cyan, bold: true)
        printWrapped("Remote players make their own combat choices and can chat. The game auto-saves between turns. Convert slots back to AI from Party Status.", indent: 2, color: .dimGreen)
        print("")

        print("  WHAT NEXT", color: .cyan, bold: true)
        printWrapped("Close (X) to return to Party Review.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showPartyReview() }
    }

    /// Tracks whether the current character being created is AI
    private var creatingAsAI: Bool = false

    /// Ask if this character is human, AI, or remote player, then proceed
    private func chooseCharacterType() {
        // Skip slots pre-assigned as remote — go to party review when done
        if pendingRemoteSlots.contains(creatingCharacterIndex) {
            creatingCharacterIndex += 1
            if creatingCharacterIndex < totalCharacters {
                chooseCharacterType()
            } else {
                showPartyReview()
            }
            return
        }

        // Must have at least one human — first character is always human
        let hasHuman = party.contains(where: { !$0.isComputerControlled })
        let isFirstCharacter = creatingCharacterIndex == 0
        let isLastCharacter = creatingCharacterIndex == totalCharacters - 1
        let mustBeHuman = totalCharacters == 1 || (isFirstCharacter && !hasHuman) || (isLastCharacter && !hasHuman)

        if mustBeHuman {
            creatingAsAI = false
            startCharacterCreation()
            return
        }

        // Default remaining characters to Auto (AI) — skip type choice
        creatingAsAI = true
        autoCreateCharacter()
        return

        // NOTE: manual type choice below is no longer used — player types
        // can be changed in Party Review after creation

        clearTerminal()
        printSubtitle("Character \(creatingCharacterIndex + 1) of \(totalCharacters)")
        print("Who controls this character?")
        print("")

        let gcAuth = GameCenterManager.shared.isAuthenticated && totalCharacters >= 2
        var opts = ["Human Player", "Computer (AI)"]
        if gcAuth { opts.append("Remote Player") }

        showMenu(opts)

        closeHandler = { [weak self] in
            guard let self = self else { return }
            if self.creatingCharacterIndex > 0 {
                self.creatingCharacterIndex -= 1
                self.pendingRemoteSlots.remove(self.creatingCharacterIndex)
                if !self.pendingRemoteSlots.contains(self.creatingCharacterIndex) && !self.party.isEmpty {
                    self.party.removeLast()
                }
                self.chooseCharacterType()
            } else {
                let wasMultiplayer = self.isMultiplayer
                self.pendingRemoteSlots.removeAll()
                self.isMultiplayer = false
                if wasMultiplayer {
                    self.startMultiplayerNewGame()
                } else {
                    self.startNewGame()
                }
            }
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1:
                self.creatingAsAI = false
                self.startCharacterCreation()
            case 2:
                self.creatingAsAI = true
                self.autoCreateCharacter()
            case 3 where gcAuth:
                self.inviteRemotePlayer()
            default: break
            }
        }
    }

    /// Mark this character slot for a remote Game Centre player
    private func inviteRemotePlayer() {
        pendingRemoteSlots.insert(creatingCharacterIndex)

        clearTerminal()
        printSubtitle("Character \(creatingCharacterIndex + 1) of \(totalCharacters)")
        print("Slot \(creatingCharacterIndex + 1): Remote Player", color: .brightGreen, bold: true)
        print("A Game Centre friend will be invited to", color: .dimGreen)
        print("create this character.", color: .dimGreen)
        print("")

        waitForContinue()
        inputHandler = { [weak self] _ in
            guard let self = self else { return }
            self.creatingCharacterIndex += 1
            if self.creatingCharacterIndex < self.totalCharacters {
                self.chooseCharacterType()
            } else {
                self.finishPartySetup()
            }
        }
    }

    /// After all character slots assigned, show party review
    private func finishPartySetup() {
        showPartyReview()
    }

    /// Create a Game Centre match and show matchmaker for inviting remote players
    private func createMultiplayerMatch() {
        isMultiplayer = true
        let remoteCount = pendingRemoteSlots.count
        let totalParticipants = remoteCount + 1  // +1 for host

        clearTerminal()
        printTitle("Invite Players")
        print("Select \(remoteCount) friend\(remoteCount > 1 ? "s" : "") to invite...", color: .dimGreen)
        print("")
        print("The Game Centre matchmaker will", color: .dimGreen)
        print("appear. If you cancel it, use", color: .dimGreen)
        print("the Back button below.", color: .dimGreen)
        print("")

        showMenu(["Done"])
        menuHandler = { [weak self] _ in
            self?.showPartyReview()
        }

        // Show matchmaker — set exact player count so user invites the right number
        GameCenterManager.shared.showMatchmaker(minPlayers: totalParticipants, maxPlayers: totalParticipants)
        // When match is created, didReceiveTurn fires → matchCreatedFromInviteFlow handles it
    }

    /// Called when matchmaker creates the match after the integrated invite flow
    private func handleNewMatchFromInviteFlow(_ match: GKTurnBasedMatch) {
        GameCenterManager.shared.currentMatch = match

        guard localPlayerID != nil else {
            print("Error: Not authenticated with Game Center", color: .red)
            showMainMenu()
            return
        }

        // Keep placeholder characters for remote slots — remote players will see them
        // and can accept or customise. Track which characters are placeholders by slot index.
        let sortedRemoteIndices = pendingRemoteSlots.sorted()
        var placeholderCharsBySlot: [Int: Character] = [:]
        for idx in sortedRemoteIndices {
            if idx < party.count {
                placeholderCharsBySlot[idx] = party[idx]
            }
        }

        // Build player slots — host is first, remote players follow
        var players: [PlayerSlot] = []

        // Host slot (controls all locally-created characters except remote placeholders)
        let localCharIds = party.enumerated().compactMap { (i, c) -> UUID? in
            pendingRemoteSlots.contains(i) ? nil : c.id
        }
        players.append(PlayerSlot(
            gamePlayerID: localPlayerID ?? "",
            displayName: GKLocalPlayer.local.displayName,
            characterId: party.first(where: { localCharIds.contains($0.id) })?.id,
            controlledCharacterIds: localCharIds,
            isPartyLeader: true,
            slotIndex: 0
        ))

        // Remote player slots — keep their placeholder characters
        let remoteParticipants = match.participants.filter {
            $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID
        }
        for (i, participant) in remoteParticipants.enumerated() {
            let remoteSlotIdx = sortedRemoteIndices.indices.contains(i) ? sortedRemoteIndices[i] : -1
            let placeholder = placeholderCharsBySlot[remoteSlotIdx]
            players.append(PlayerSlot(
                gamePlayerID: participant.player?.gamePlayerID ?? "pending_\(i)",
                displayName: participant.player?.displayName ?? "Player \(i + 2)",
                characterId: placeholder?.id,
                controlledCharacterIds: placeholder.map { [$0.id] } ?? [],
                isPartyLeader: false,
                slotIndex: i + 1,
                needsConfirmation: true
            ))
        }

        // Build multiplayer state — party includes ALL characters (host + placeholders)
        multiplayerState = MultiplayerMatchState(
            version: MultiplayerMatchState.schemaVersion,
            matchId: match.matchID,
            players: players,
            activePlayerID: localPlayerID ?? "",
            phase: .characterCreation,
            party: party,
            dungeon: Dungeon(name: "Multiplayer Dungeon", level: 1),
            gameTimeMinutes: 360,
            adventureLog: [],
            monstersSlain: 0,
            combatsWon: 0,
            torchLit: false,
            torchTurnsRemaining: 0,
            combat: nil,
            recentActions: [],
            partyChatLog: [],
            dungeonLevel: 1
        )

        // Show lobby and send invite to first remote player
        showMultiplayerLobby(sendInvite: true)
    }

    /// Convert a running local game to multiplayer by creating a match with the current state
    private func handleLocalToMultiplayerConversion(match: GKTurnBasedMatch, remoteCharacterId: UUID) {
        GameCenterManager.shared.currentMatch = match
        pendingRemoteCharacterId = nil

        guard localPlayerID != nil else {
            print("Error: Not authenticated with Game Center", color: .red)
            isMultiplayer = false
            showPartyStatus()
            return
        }

        // Find the character being assigned to the remote player
        guard let remoteChar = party.first(where: { $0.id == remoteCharacterId }) else {
            isMultiplayer = false
            showPartyStatus()
            return
        }

        // Build player slots
        var players: [PlayerSlot] = []

        // Host controls all characters except the remote one
        let localCharIds = party.compactMap { $0.id != remoteCharacterId ? $0.id : nil }
        players.append(PlayerSlot(
            gamePlayerID: localPlayerID ?? "",
            displayName: GKLocalPlayer.local.displayName,
            characterId: party.first(where: { !$0.isComputerControlled })?.id ?? party.first?.id,
            controlledCharacterIds: localCharIds,
            isPartyLeader: true,
            slotIndex: 0
        ))

        // Remote player gets the AI character
        let remoteParticipants = match.participants.filter {
            $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID
        }
        if let remote = remoteParticipants.first {
            players.append(PlayerSlot(
                gamePlayerID: remote.player?.gamePlayerID ?? "pending_0",
                displayName: remote.player?.displayName ?? "Remote Player",
                characterId: remoteChar.id,
                controlledCharacterIds: [remoteChar.id],
                isPartyLeader: false,
                slotIndex: 1,
                needsConfirmation: true
            ))
        }

        // Mark the character as no longer AI (remote player will control it)
        remoteChar.unmarkAsAI()

        // Build multiplayer state from current game
        multiplayerState = MultiplayerMatchState(
            version: MultiplayerMatchState.schemaVersion,
            matchId: match.matchID,
            players: players,
            activePlayerID: localPlayerID ?? "",
            phase: .characterCreation,
            party: party,
            dungeon: dungeon ?? Dungeon(name: "Dungeon", level: 1),
            gameTimeMinutes: gameTimeMinutes,
            adventureLog: adventureLog,
            monstersSlain: monstersSlain,
            combatsWon: combatsWon,
            torchLit: torchLit,
            torchTurnsRemaining: torchTurnsRemaining,
            combat: nil,
            recentActions: [],
            partyChatLog: [],
            dungeonLevel: dungeon?.level ?? 1
        )

        isMultiplayer = true

        // Show lobby and send invite to the remote player for confirmation
        showMultiplayerLobby(sendInvite: true)
    }

    /// Display the lobby showing party status while waiting for remote players
    /// Set sendInvite=true only on first entry (after party setup) to send the invite
    private func showMultiplayerLobby(sendInvite: Bool = false) {
        guard let state = multiplayerState else { return }

        clearTerminal()
        printTitle("Party Lobby")
        print("")

        // Show party roster (host's characters)
        print("  Your Party:", color: .cyan, bold: true)
        let hostSlot = state.players.first(where: { $0.isPartyLeader })
        for char in party {
            let isHostChar = hostSlot?.controlledCharacterIds.contains(char.id) ?? false
            if isHostChar {
                print("    \(char.name) — \(char.race.rawValue) \(char.characterClass.rawValue)", color: .brightGreen)
            }
        }

        // Show remote slots with their placeholder characters
        let remoteSlots = state.players.filter { $0.gamePlayerID != localPlayerID }
        for player in remoteSlots {
            if player.needsConfirmation,
               let charId = player.characterId,
               let char = state.party.first(where: { $0.id == charId }) {
                // Placeholder character awaiting remote player confirmation
                print("    \(char.name) [\(player.displayName)] — \(char.race.rawValue) \(char.characterClass.rawValue)", color: .yellow)
                print("      Waiting for confirmation...", color: .dimGreen)
            } else if let charId = player.characterId,
                      let char = state.party.first(where: { $0.id == charId }) {
                // Character confirmed
                print("    \(char.name) (\(player.displayName)) — \(char.race.rawValue) \(char.characterClass.rawValue)", color: .brightGreen)
            } else {
                print("    \(player.displayName) — Waiting...", color: .yellow)
            }
        }
        print("")

        // Instructions for the host
        let waitingCount = remoteSlots.filter { $0.needsConfirmation || $0.characterId == nil }.count
        if waitingCount > 0 {
            print("  Waiting for \(waitingCount) remote player\(waitingCount > 1 ? "s" : "").", color: .dimGreen)
            print("")
            print("  Your friend needs to:", color: .cyan)
            print("    1. Install this app on their iPhone", color: .dimGreen)
            print("    2. Sign in to Game Centre", color: .dimGreen)
            print("    3. Open the app and tap the Game", color: .dimGreen)
            print("       Centre notification, or go to", color: .dimGreen)
            print("       Multiplayer Games from the menu", color: .dimGreen)
            print("    4. Create their character when prompted", color: .dimGreen)
            print("")
            print("  You'll get a notification when they're done.", color: .dimGreen)
        }
        print("")

        showMenuOptions([nudgeButtonOption(), MenuOption("How MP Works"), MenuOption("Cancel Match"), MenuOption("Main Menu")])
        menuHandler = { [weak self] choice in
            switch choice {
            case 1:
                if self?.nudgeOnCooldown == true { return }
                self?.nudgeRemotePlayer()
            case 2: self?.showMultiplayerHelp()
            case 3: self?.confirmCancelMatch()
            default:
                self?.isMultiplayer = false
                self?.multiplayerState = nil
                self?.pendingRemoteSlots.removeAll()
                self?.showMainMenu()
            }
        }
        menuLongPressHandler = { [weak self] choice in
            if choice == 1 { self?.handleNudgeLongPress() }
        }

        // Check if all remote players have confirmed
        let waitingRemotes = state.players.filter {
            $0.gamePlayerID != localPlayerID && ($0.needsConfirmation || $0.characterId == nil)
        }
        if waitingRemotes.isEmpty {
            // All characters created — start the adventure
            startMultiplayerAdventure()
        } else if sendInvite, let nextRemote = waitingRemotes.first {
            // First time entering lobby — send the invite
            sendLobbyInvite(state: state, nextRemote: nextRemote)
        }
    }

    /// Show detailed multiplayer help screen
    private func showMultiplayerHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Multiplayer — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Multiplayer lets friends control party members via Game Centre. The host controls exploration; each player takes their own combat turns.", indent: 2, color: .dimGreen)
        print("")

        print("  SETUP", color: .cyan, bold: true)
        printWrapped("On the Party Review screen, swap any AI slot to 'Remote', then tap 'Start Matchmaker' to invite a friend. They need this app and Game Centre sign-in.", indent: 2, color: .dimGreen)
        print("")

        print("  DURING PLAY", color: .cyan, bold: true)
        printWrapped("You don't need to be online at the same time — Game Centre sends notifications when it's your turn. If a player leaves, their character becomes AI-controlled.", indent: 2, color: .dimGreen)
        print("")

        print("  WHAT NEXT", color: .cyan, bold: true)
        printWrapped("Close (X) to return.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in
            if self?.multiplayerState != nil {
                self?.showMultiplayerLobby()
            } else {
                self?.showPlayMenu()
            }
        }
    }

    /// All characters created in multiplayer — generate dungeon and begin
    private func startMultiplayerAdventure() {
        guard var state = multiplayerState else { return }
        guard let myID = localPlayerID else {
            print("Error: Not authenticated with Game Center", color: .red)
            showMainMenu()
            return
        }

        state.phase = .exploring
        state.activePlayerID = myID

        state.dungeon = Dungeon(name: dungeonNames.randomElement()!, level: 1)
        state.party = party

        multiplayerState = state
        dungeon = state.dungeon
        if partyHasTorch() { torchLit = true }

        gameState = .exploring
        showExplorationView()
    }

    // MARK: - Character Creation

    private let suggestedNames = [
        // Stranger Things
        "Will the Wise", "Eleven", "Zoomer", "Sundar the Bold",
        "Eddie Munson", "Lady Applejack", "Steve", "Nancy",
        "Hopper", "Robin", "Jonathan", "Murray", "Joyce", "Nog",
        // Community (D&D episodes)
        "Abed", "Troy", "Hector the Well-Endowed", "Brutalitops",
        // Futurama (Bender's Game)
        "Titanius", "Leegola", "Frydo",
        // Big Bang Theory (D&D references)
        "Sheldon", "Raj", "Wolowitz",
        // Freaks and Geeks
        "Daniel Desario", "Carlos the Dwarf",
        // Honor Among Thieves
        "Edgin", "Holga", "Simon", "Doric", "Xenk",
        // Classic sci-fi (1960s-1980s)
        "Deckard", "Ripley", "Hicks", "Newt",
        "Atreides", "Stilgar", "Chani",
        "Bowman", "HAL", "Poole",
        "Case", "Molly", "Wintermute",
        "Ender", "Valentine", "Bean",
        "Zaphod", "Trillian", "Slartibartfast",
        "Kal-El", "Logan 5", "Korben",
        "Snake Plissken", "Riddick", "Quaid",
        "Neo", "Morpheus", "Trinity",
        // Famous robots (pre-1986 sci-fi)
        "Daneel", "Giskard", "Robbie",         // Asimov
        "Marvin", "Kryten",                     // Hitchhiker's / Red Dwarf
        "K-9", "Kamelion",                      // Doctor Who
        "Twiki", "Crichton",                    // Buck Rogers
        "Box", "Hector",                        // Logan's Run / Saturn 3
        "Maximilian", "V.I.N.CENT",             // The Black Hole
        "Gort", "Tobor",                        // The Day the Earth Stood Still
        "C-3PO", "R2-D2",                       // Star Wars
        "Bishop", "Ash",                        // Aliens
        "Roy Batty", "Pris", "Rachael",         // Blade Runner
        "Johnny Five", "Hymie",                 // Short Circuit / Get Smart
        "Metal Mickey", "Bubo",                 // TV / Clash of the Titans
        "Mechagodzilla", "Tik-Tok",             // Film / Oz
        "Maria", "Maschinenmensch",             // Metropolis
        // Jules Verne
        "Captain Nemo", "Phileas Fogg", "Passepartout",
        "Doct Lidenbrock", "Axel", "Hans",
        "Doct Ferguson", "Doct Clawbonny",
        // H.G. Wells
        "Dr. Moreau", "Griffin", "The Time Traveller",
        // Arthur Conan Doyle
        "Doct Watson", "Sherlock", "Professor Challenger",
        // Bram Stoker / Shelley / Stevenson
        "Van Helsing", "Dr. Frankenstein", "Dr. Jekyll",
        // Edgar Rice Burroughs
        "Doct Carter", "Dejah Thoris", "Tars Tarkas",
        // E.E. "Doc" Smith / pulp sci-fi
        "Doct Kimball", "Worsel", "Nadreck",
        // Karel Čapek (R.U.R.)
        "R. Helena", "R. Radius", "R. Primus",
        // Fritz Lang / early film
        "Rotwang", "Freder",
        // Alexandre Dumas
        "Athos", "Porthos", "Aramis", "D'Artagnan",
        // Victor Hugo
        "Valjean", "Javert", "Quasimodo", "Esmeralda",
        // Jonathan Swift / Samuel Butler
        "Gulliver", "Doct Higgs",
        // Homer / Greek myth
        "Odysseus", "Achilles", "Penelope", "Circe",
        // Norse myth
        "Sigurd", "Brynhild", "Volund",
    ]

    private let dungeonNames = [
        // Tolkien
        "Moria", "Dol Guldur", "Barad-dur", "Cirith Ungol", "Isengard",
        "Shelob's Lair", "Paths of the Dead", "Mount Doom",
        // D&D classic modules (pre-1985)
        "Tomb of Horrors", "White Plume Mountain", "Barrier Peaks",
        "Temple of Elemental Evil", "Ravenloft", "Castle Amber",
        "Vault of the Drow", "Steading of the Hill Giant Chief",
        "Caves of Chaos", "Keep on the Borderlands",
        // Moorcock
        "Tanelorn", "The Pulsing Cavern", "Melnibone",
        // Leiber
        "Quarmall", "Thieves' House", "Stardock",
        // Howard / Conan
        "The Tower of the Elephant", "The Scarlet Citadel",
        "Iron Shadows in the Moon",
        // Vance
        "Chasm of the Old", "Ampridatvir",
        // LeGuin
        "The Tombs of Atuan", "The Labyrinth",
        // Classic sci-fi settings
        "Trantor", "Terminus", "Foundation",    // Asimov
        "Arrakeen", "Sietch Tabr",              // Herbert
        "Solaris Station", "Rama",              // Lem / Clarke
        "Nostromo", "Acheron",                  // Alien
        "Tyrell Pyramid", "Sector 6",           // Blade Runner
        // Samuel Butler
        "Erewhon",
        // Jules Verne
        "The Nautilus", "Centre of the Earth",
        "Doct Ox's Experiment", "The Mysterious Island",
        // H.G. Wells
        "The Island of Dr. Moreau", "The Time Machine",
        // Jonathan Swift
        "Laputa", "Brobdingnag", "Lilliput",
        // Dante
        "The Inferno", "Malebolge",
        // Homer
        "Circe's Isle", "The Cyclops Cave",
        // Norse
        "Niflheim", "Muspelheim", "Helheim",
        // General fantasy
        "The Dark Depths", "Forgotten Crypts", "Shadow Depths",
        "The Sunless Citadel", "Grimstone Keep",
        "The Whispering Vault", "Thornhold",
        "Blackmoor Dungeon", "The Iron Tower",
    ]

    func startCharacterCreation() {
        clearTerminal()
        gameState = .characterCreation

        printSubtitle("Character \(creatingCharacterIndex + 1) of \(totalCharacters)")

        // Show name suggestions as tappable buttons
        let existingNames = Set(party.map { $0.name.lowercased() })
        let available = suggestedNames.filter { !existingNames.contains($0.lowercased()) }
        let suggestionList = Array(available.shuffled().prefix(4))
        if !party.isEmpty {
            let taken = party.map { $0.name }.joined(separator: ", ")
            print("  Already in party: \(taken)", color: .dimGreen)
        }
        print("")

        var menuOpts = suggestionList.map { String($0) }
        menuOpts.append("Random")
        menuOpts.append("Help")

        promptTextWithMenu("Name:", options: menuOpts)

        rerollHandler = { [weak self] in
            self?.startCharacterCreation()
        }

        closeHandler = { [weak self] in
            guard let self = self else { return }
            if self.creatingCharacterIndex > 0 {
                self.creatingCharacterIndex -= 1
                self.party.removeLast()
                self.chooseCharacterType()
            } else {
                self.startNewGame()
            }
        }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let menuIdx = choice - 1
            if menuIdx < suggestionList.count {
                // Tapped a suggestion name button
                self.inputHandler?(suggestionList[menuIdx])
            } else if menuOpts[menuIdx] == "Random" {
                // Random — submit empty name to trigger auto-name
                self.inputHandler?("")
            } else if menuOpts[menuIdx] == "Help" {
                self.showCharacterHelp()
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
            if name.isEmpty || lower == "a" || lower == "auto" {
                self.autoCreateCharacter()
                return
            }
            let cleanName = name
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
        let raceNames = races.map { "\($0.rawValue)" }

        showMenu(raceNames)
        closeHandler = { [weak self] in self?.startCharacterCreation() }

        menuHandler = { [weak self] choice in
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
        let classNames = classes.map { "\($0.rawValue) (d\($0.hitDie) HP)" }

        showMenu(classNames)
        closeHandler = { [weak self] in self?.chooseRace() }

        menuHandler = { [weak self] choice in
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

        showMenu(["Auto", "Standard Array", "Roll 4d6", "Help"])
        closeHandler = { [weak self] in self?.chooseClass() }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 4 {
                self.showAbilityScoreHelp()
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

        showMenu(["Accept", "Reroll"])
        closeHandler = { [weak self] in self?.startCharacterCreation() }
        rerollHandler = { [weak self] in self?.autoCreateCharacter() }
        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.finishCharacterCreation()
            case 2: self?.autoCreateCharacter()
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

        let abilityNames = remainingAbilities.map { ability -> String in
            let isPrimary = ability == tempClass?.primaryAbility
            return isPrimary ? "\(ability.rawValue) (Recommended)" : ability.rawValue
        }

        showMenu(abilityNames)
        closeHandler = { [weak self] in self?.chooseAbilityMethod() }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let ability = self.remainingAbilities[choice - 1]
            self.selectScoreForAbility(ability)
        }
    }

    func selectScoreForAbility(_ ability: Ability) {
        print("")
        print("Choose score for \(ability.rawValue):")

        let scoreOptions = remainingScores.map { String($0) }

        showMenu(scoreOptions)
        closeHandler = { [weak self] in self?.assignNextScore() }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let score = self.remainingScores[choice - 1]
            self.assignedScores[ability] = score
            self.remainingScores.remove(at: choice - 1)
            self.remainingAbilities.removeAll { $0 == ability }
            self.assignNextScore()
        }
    }

    private let skillsScreenKey = "skills"

    func chooseSkills() {
        guard let charClass = tempClass else { return }

        clearTerminal()
        printSubtitle("Choose Skills")

        selectedSkills = []
        clearUndoRedo(for: skillsScreenKey)
        currentUndoScreen = skillsScreenKey
        let availableSkills = charClass.skillChoices
        let numChoices = charClass.numSkillChoices

        print("Choose \(numChoices) skills from your class list:")
        print("")

        selectNextSkill(from: availableSkills, remaining: numChoices)
    }

    private func pushSkillSnapshot() {
        let rawValues = selectedSkills.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(rawValues) {
            pushScreenUndo(screen: skillsScreenKey, data: data)
        }
    }

    private func restoreSkillsFromData(_ data: Data) -> [Skill]? {
        guard let rawValues = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return rawValues.compactMap { Skill(rawValue: $0) }
    }

    private func undoSkill(from available: [Skill], total: Int) {
        let key = skillsScreenKey
        guard let data = popScreenUndo(screen: key) else { return }
        if let currentData = try? JSONEncoder().encode(selectedSkills.map { $0.rawValue }) {
            pushScreenRedo(screen: key, data: currentData)
        }
        if let restored = restoreSkillsFromData(data) {
            selectedSkills = restored
        }
        let remaining = total - selectedSkills.count
        clearTerminal()
        printSubtitle("Choose Skills")
        print("Choose \(total) skills from your class list:")
        print("")
        selectNextSkill(from: available, remaining: remaining)
    }

    private func redoSkill(from available: [Skill], total: Int) {
        let key = skillsScreenKey
        guard let data = popScreenRedo(screen: key) else { return }
        if let currentData = try? JSONEncoder().encode(selectedSkills.map { $0.rawValue }) {
            pushScreenUndo(screen: key, data: currentData)
        }
        if let restored = restoreSkillsFromData(data) {
            selectedSkills = restored
        }
        let remaining = total - selectedSkills.count
        clearTerminal()
        printSubtitle("Choose Skills")
        print("Choose \(total) skills from your class list:")
        print("")
        selectNextSkill(from: available, remaining: remaining)
    }

    private func updateSkillUndoRedoHandlers(from available: [Skill], total: Int) {
        undoHandler = screenHasUndo(skillsScreenKey) ? { [weak self] in self?.undoSkill(from: available, total: total) } : nil
        redoHandler = screenHasRedo(skillsScreenKey) ? { [weak self] in self?.redoSkill(from: available, total: total) } : nil
    }

    func selectNextSkill(from available: [Skill], remaining: Int) {
        guard let charClass = tempClass else { return }
        let total = charClass.numSkillChoices

        if remaining == 0 {
            showSkillConfirmation(from: available)
            return
        }

        if !selectedSkills.isEmpty {
            let chosen = selectedSkills.map { $0.rawValue }.joined(separator: ", ")
            print("Selected: \(chosen)", color: .brightGreen)
            print("")
        }

        let unselected = available.filter { !selectedSkills.contains($0) }
        // Auto first (top-left), then skills, then Help last
        var skillNames = ["Auto"] + unselected.map { $0.rawValue } + ["Help"]

        print("Skill \(selectedSkills.count + 1) of \(total):")
        showMenu(skillNames)
        closeHandler = { [weak self] in
            guard let self = self else { return }
            self.clearUndoRedo(for: self.skillsScreenKey)
            self.undoHandler = nil
            self.redoHandler = nil
            self.currentUndoScreen = nil
            self.chooseAbilityMethod()
        }

        updateSkillUndoRedoHandlers(from: available, total: total)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                // Auto — randomly select all remaining
                self.pushSkillSnapshot()
                self.autoSelectSkills(from: available, remaining: remaining)
                return
            }
            if choice == skillNames.count {
                // Help (last)
                self.showSkillsHelp()
                return
            }
            // Skill pick — offset by 1 for the Auto button
            let skill = unselected[choice - 2]
            self.pushSkillSnapshot()
            self.selectedSkills.append(skill)
            self.clearTerminal()
            self.printSubtitle("Choose Skills")
            self.print("Choose \(total) skills from your class list:")
            self.print("")
            self.selectNextSkill(from: available, remaining: remaining - 1)
        }

        // Long-press: pick this skill and auto-fill rest randomly
        // Skills are at indices 2...(unselected.count + 1) due to Auto at index 1
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            let skillIndex = choice - 2
            if skillIndex >= 0 && skillIndex < unselected.count {
                self.pushSkillSnapshot()
                self.selectedSkills.append(unselected[skillIndex])
                let stillNeeded = remaining - 1
                if stillNeeded > 0 {
                    let leftover = unselected.filter { !self.selectedSkills.contains($0) }
                    let autoSkills = Array(leftover.shuffled().prefix(stillNeeded))
                    self.selectedSkills.append(contentsOf: autoSkills)
                }
                self.showSkillConfirmation(from: available)
            }
        }
    }

    private func autoSelectSkills(from available: [Skill], remaining: Int) {
        let unselected = available.filter { !selectedSkills.contains($0) }
        let autoSkills = Array(unselected.shuffled().prefix(remaining))

        // Show each skill being selected with a brief delay
        func showNext(index: Int) {
            guard index < autoSkills.count else {
                // All done — show confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.showSkillConfirmation(from: available)
                }
                return
            }
            selectedSkills.append(autoSkills[index])
            let chosen = selectedSkills.map { $0.rawValue }.joined(separator: ", ")
            print("  \(autoSkills[index].rawValue)", color: .brightGreen)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showNext(index: index + 1)
            }
        }

        clearTerminal()
        printSubtitle("Choose Skills")
        // Show previously selected skills
        if !selectedSkills.isEmpty {
            let kept = selectedSkills.map { $0.rawValue }.joined(separator: ", ")
            print("Keeping: \(kept)", color: .brightGreen)
        }
        print("Auto-selecting remaining...", color: .cyan)
        print("")
        showNext(index: 0)
    }

    private func showSkillConfirmation(from available: [Skill]) {
        clearTerminal()
        printSubtitle("Skills Selected")
        print("")
        for skill in selectedSkills {
            print("  \(skill.rawValue)", color: .brightGreen)
            print("    (\(skill.ability.rawValue))", color: .dimGreen)
        }
        print("")

        showMenu(["Confirm", "Change"], defaultIndex: 1)
        closeHandler = { [weak self] in
            guard let self = self else { return }
            self.clearUndoRedo(for: self.skillsScreenKey)
            self.undoHandler = nil
            self.redoHandler = nil
            self.currentUndoScreen = nil
            self.chooseAbilityMethod()
        }
        undoHandler = nil
        redoHandler = nil

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                // Confirm
                self.clearUndoRedo(for: self.skillsScreenKey)
                self.undoHandler = nil
                self.redoHandler = nil
                self.currentUndoScreen = nil
                self.finishCharacterCreation()
            } else {
                // Change — go back to ability score method
                self.clearUndoRedo(for: self.skillsScreenKey)
                self.undoHandler = nil
                self.redoHandler = nil
                self.currentUndoScreen = nil
                self.chooseAbilityMethod()
            }
        }
    }

    private func showSkillsHelp() {
        guard let charClass = tempClass else { return }
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Skills Help")

        print("WHAT ARE SKILLS?", color: .cyan, bold: true)
        printWrapped("Skills represent your character's training. When you make an ability check, having proficiency in the relevant skill adds your proficiency bonus (+2 at level 1).", indent: 2)
        print("")
        print("YOUR CLASS", color: .cyan, bold: true)
        printWrapped("\(charClass.rawValue) can choose \(charClass.numSkillChoices) skills from:", indent: 2)
        for skill in charClass.skillChoices {
            print("  • \(skill.rawValue) (\(skill.ability.rawValue))", color: .dimGreen)
        }
        print("")
        print("SHORTCUTS", color: .cyan, bold: true)
        printWrapped("• Tap Auto to randomly select all remaining skills.", indent: 2)
        printWrapped("• Long-press any skill to pick it and auto-fill the rest.", indent: 2)
        printWrapped("• Use undo/redo to change your picks.", indent: 2)
        printWrapped("• X icon goes back to ability scores.", indent: 2)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.chooseSkills() }
        menuHandler = { [weak self] _ in self?.chooseSkills() }
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

        if creatingAsAI { character.markAsAI() }
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
            print("  Armour: \(a.name)", color: .cyan)
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
            } else if self.isMultiplayer, let lastChar = self.party.last {
                self.multiplayerCharacterCreated(character: lastChar)
            } else {
                self.showPartyReview()
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
                self.print("  Equipped armour: \(a.name)", color: .cyan)
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
                } else if self.isMultiplayer, let lastChar = self.party.last {
                    self.multiplayerCharacterCreated(character: lastChar)
                } else {
                    self.showPartyReview()
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
        clearAllUndoRedo()
        clearTerminal()
        printTitle("Adventure Awaits!")

        print("Your party is ready to enter a", color: .dimGreen)
        print("dungeon. Name it, or pick one:", color: .dimGreen)
        print("")

        // Pick 3 unique random dungeon names
        var suggestions: [String] = []
        var pool = dungeonNames.shuffled()
        while suggestions.count < 3 && !pool.isEmpty {
            let name = pool.removeFirst()
            if !suggestions.contains(name) { suggestions.append(name) }
        }

        var opts = suggestions.map { String($0.prefix(MenuOption.maxButtonLength)) }
        opts.append("Help")
        promptTextWithMenu("Name your dungeon, or choose a default:", options: opts)

        rerollHandler = { [weak self] in
            self?.startAdventure()
        }
        swipeLeftHandler = { [weak self] in
            self?.clearTerminal()
            self?.startNewGame()
        }
        closeHandler = { [weak self] in
            self?.clearTerminal()
            self?.startNewGame()
        }
        textLongPressHandler = { [weak self] _ in
            self?.showDungeonHelp()
        }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == suggestions.count + 1 {
                self.showDungeonHelp()
                return
            }
            if choice >= 1 && choice <= suggestions.count {
                let chosen = suggestions[choice - 1]
                self.tempDungeonName = chosen
                self.selectDifficulty(dungeonName: chosen)
            }
        }

        inputHandler = { [weak self] name in
            guard let self = self else { return }
            if self.isReservedWord(name) {
                self.clearTerminal()
                self.startNewGame()
                return
            }
            let raw = name.isEmpty ? suggestions.first ?? "The Dark Depths" : name
            let dungeonName = raw.capitalized
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

    /// Context-sensitive help for the New Adventure (party size) screen
    private func showNewGameHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Party Help")

        print("PARTY SIZE", color: .cyan, bold: true)
        printWrapped("Choose 1-4 adventurers. You control the first character; the rest are AI companions that fight alongside you.", indent: 2)
        print("")
        print("SHORTCUTS", color: .cyan, bold: true)
        printWrapped("• Long-press a party size to auto-create the entire party instantly.", indent: 2)
        printWrapped("• 'Random Party' creates a fully random group.", indent: 2)
        print("")
        print("PARTY TIPS", color: .cyan, bold: true)
        printWrapped("• A balanced party (fighter + healer + ranged) survives longer.", indent: 2)
        printWrapped("• Solo runs are possible but challenging — consider a Cleric or Ranger.", indent: 2)
        printWrapped("• Larger parties face tougher encounters but share the load.", indent: 2)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.startNewGame() }
        menuHandler = { [weak self] _ in self?.startNewGame() }
    }

    /// Context-sensitive help for character naming screen
    private func showCharacterHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Character Help")

        print("NAMING", color: .cyan, bold: true)
        printWrapped("Type a name, pick a suggestion, or tap Random. Tap the dice icon for new suggestions.", indent: 2)
        print("")
        print("CREATION FLOW", color: .cyan, bold: true)
        printWrapped("After naming: choose Race, Class, ability scores, and skills. Each step builds your character.", indent: 2)
        print("")
        print("SHORTCUTS", color: .cyan, bold: true)
        printWrapped("• Type 'a' or 'auto' to auto-create this character.", indent: 2)
        printWrapped("• Long-press any race or class to auto-fill the rest.", indent: 2)
        printWrapped("• Use the X icon to go back a step.", indent: 2)
        print("")
        print("RACE & CLASS TIPS", color: .cyan, bold: true)
        printWrapped("• Each class has a primary ability — scores are assigned to maximise it when using Auto.", indent: 2)
        printWrapped("• Fighters and Barbarians are tough melee combatants.", indent: 2)
        printWrapped("• Clerics heal and support. Rangers fight at range.", indent: 2)
        printWrapped("• Wizards and Rogues bring versatility.", indent: 2)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.startCharacterCreation() }
        menuHandler = { [weak self] _ in self?.startCharacterCreation() }
    }

    /// Context-sensitive help for ability score methods
    private func showAbilityScoreHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Ability Scores Help")

        print("THE SIX ABILITIES", color: .cyan, bold: true)
        printWrapped("Every character has six ability scores that define their capabilities:", indent: 2)
        print("  STR  Strength — melee attacks, carrying, athletics", color: .dimGreen)
        print("  DEX  Dexterity — ranged attacks, AC, stealth, reflexes", color: .dimGreen)
        print("  CON  Constitution — hit points, endurance, resilience", color: .dimGreen)
        print("  INT  Intelligence — arcana, history, investigation", color: .dimGreen)
        print("  WIS  Wisdom — perception, insight, healing magic", color: .dimGreen)
        print("  CHA  Charisma — persuasion, deception, sorcery", color: .dimGreen)
        print("")
        print("SCORE METHODS", color: .cyan, bold: true)
        printWrapped("• Auto — Uses the standard array (15, 14, 13, 12, 10, 8) and assigns scores optimally for your class. Quickest option.", indent: 2)
        printWrapped("• Standard Array — You assign 15, 14, 13, 12, 10, 8 to abilities yourself. Good control, balanced.", indent: 2)
        printWrapped("• Roll 4d6 — Rolls four dice and drops the lowest for each score. Random but can give very high (or low) scores.", indent: 2)
        print("")
        print("ASSIGNING SCORES", color: .cyan, bold: true)
        printWrapped("After choosing Standard Array or Roll 4d6, you'll assign each score to an ability one at a time. Put your highest score in your class's primary ability.", indent: 2)
        if let charClass = tempClass {
            print("")
            printWrapped("Your \(charClass.rawValue)'s primary ability is \(charClass.primaryAbility.rawValue).", indent: 2, color: .brightGreen)
        }
        print("")
        print("SHORTCUTS", color: .cyan, bold: true)
        printWrapped("• Long-press any option to auto-assign scores and finish character creation immediately.", indent: 2)
        printWrapped("• Use the X icon to go back to class selection.", indent: 2)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.chooseAbilityMethod() }
        menuHandler = { [weak self] _ in self?.chooseAbilityMethod() }
    }

    /// Context-sensitive help for the dungeon naming / Adventure Awaits screen
    private func showDungeonHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Dungeon Help")

        print("DUNGEON NAME", color: .cyan, bold: true)
        printWrapped("Type a custom name, pick a suggestion, or tap the dice icon for new options.", indent: 2)
        print("")
        print("DIFFICULTY", color: .cyan, bold: true)
        printWrapped("After naming, you'll choose difficulty:", indent: 2)
        printWrapped("• Easy (1) — great for beginners.", indent: 2)
        printWrapped("• Medium (2) — balanced challenge.", indent: 2)
        printWrapped("• Hard (3+) — for experienced parties.", indent: 2)
        print("")
        print("ONCE INSIDE", color: .cyan, bold: true)
        printWrapped("• Light your torch to see exits, treasure, and NPCs.", indent: 2)
        printWrapped("• Talk to NPCs — they give useful info and quests.", indent: 2)
        printWrapped("• Rest after combat. Long-press Rest for a full long rest.", indent: 2)
        printWrapped("• Ask the DM anything by typing a question.", indent: 2)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.startAdventure() }
        menuHandler = { [weak self] _ in self?.startAdventure() }
    }

    /// Context-sensitive help for the difficulty selection screen
    private func showDifficultyHelp(dungeonName: String) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Difficulty Help")

        print("DIFFICULTY LEVELS", color: .cyan, bold: true)
        printWrapped("Difficulty affects monster strength, encounter frequency, and treasure rarity.", indent: 2)
        print("")
        print("  0  Trivial — Very weak monsters, great for", color: .dimGreen)
        print("     learning the game.", color: .dimGreen)
        print("  1  Easy — Suitable for new players or small", color: .dimGreen)
        print("     parties. Forgiving combat.", color: .dimGreen)
        print("  2  Medium — Balanced challenge. The standard", color: .dimGreen)
        print("     D&D experience.", color: .dimGreen)
        print("  3  Hard — Tough encounters. Rest often and", color: .dimGreen)
        print("     manage resources carefully.", color: .dimGreen)
        print(" 4+  Brutal — Scaled-up monster HP and damage.", color: .dimGreen)
        print("     For experienced parties only.", color: .dimGreen)
        print("")
        print("CUSTOM LEVELS", color: .cyan, bold: true)
        printWrapped("You can type any number, including decimals (e.g. 1.5, 2.5). Values between whole numbers blend difficulty smoothly.", indent: 2)
        print("")
        print("TIPS", color: .cyan, bold: true)
        printWrapped("• A party of 1-2 characters should start on Easy.", indent: 2)
        printWrapped("• A full party of 4 can handle Medium comfortably.", indent: 2)
        printWrapped("• Long-press a difficulty to skip the confirmation screen.", indent: 2)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.selectDifficulty(dungeonName: dungeonName) }
        menuHandler = { [weak self] _ in self?.selectDifficulty(dungeonName: dungeonName) }
    }

    /// Convert a custom difficulty Double to a display name
    private func difficultyName(for level: Double) -> String {
        switch level {
        case ..<0.5: return "Trivial"
        case 0.5..<1.0: return "Very Easy"
        case 1.0: return "Easy"
        case 1.0..<2.0: return "Easy-Medium"
        case 2.0: return "Medium"
        case 2.0..<3.0: return "Medium-Hard"
        case 3.0: return "Hard"
        case 3.0..<4.0: return "Hard-Brutal"
        default: return "Brutal"
        }
    }

    /// Convert custom difficulty Double to dungeon level (1-3) and difficulty scale
    private func parseDifficulty(_ value: Double) -> (level: Int, scale: Double) {
        let clamped = max(0, value)
        let level = Int(max(1, min(3, round(clamped))))
        // Scale: 1.0 at standard levels, adjusted for custom values
        // e.g. 0 = 0.5x, 0.5 = 0.75x, 1 = 1.0x, 2 = 1.0x, 3 = 1.0x, 4 = 1.5x
        let scale: Double
        if clamped <= 1.0 {
            scale = 0.5 + (clamped * 0.5) // 0→0.5, 1→1.0
        } else if clamped <= 3.0 {
            scale = 1.0 // standard range
        } else {
            scale = 1.0 + ((clamped - 3.0) * 0.25) // 4→1.25, 5→1.5
        }
        return (level, scale)
    }

    /// Stored difficulty scale from custom level input (affects monster HP/damage)
    var difficultyScale: Double = 1.0

    func selectDifficulty(dungeonName: String) {
        clearTerminal()
        printTitle("Adventure Awaits!")
        printWrapped("Dungeon: \(dungeonName)", indent: 2, color: .brightGreen)
        let partyNames = party.map { $0.name }.joined(separator: ", ")
        printWrapped("Party: \(partyNames)", indent: 2, color: .dimGreen)
        print("")
        print("Choose difficulty, or type a custom level:")
        print("")
        print("  Level  Difficulty", color: .dimGreen)
        print("  ─────  ──────────", color: .dimGreen)
        print("    0    Trivial", color: .dimGreen)
        print("    1    Easy", color: .dimGreen)
        print("    2    Medium", color: .dimGreen)
        print("    3    Hard", color: .dimGreen)
        print("   4+    Brutal", color: .dimGreen)
        print("")

        promptTextWithMenu("", options: ["Easy (1)", "Medium (2)", "Hard (3)", "Help"])

        closeHandler = { [weak self] in
            self?.clearTerminal()
            self?.startAdventure()
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 4 {
                self.showDifficultyHelp(dungeonName: dungeonName)
                return
            }
            self.confirmAdventure(dungeonName: dungeonName, level: Double(choice))
        }
        inputHandler = { [weak self] text in
            guard let self = self else { return }
            guard let value = Double(text.trimmingCharacters(in: .whitespaces)) else {
                self.print("Enter a number (e.g. 1, 2.5, 3).", color: .yellow)
                self.selectDifficulty(dungeonName: dungeonName)
                return
            }
            if value < 0 {
                self.print("Even the bravest adventurers must face some challenge! Enter 0 or above.", color: .yellow)
                self.selectDifficulty(dungeonName: dungeonName)
                return
            }
            self.confirmAdventure(dungeonName: dungeonName, level: value)
        }

        // Long-press bypasses confirmation
        menuLongPressHandler = { [weak self] choice in
            guard let self = self, choice >= 1 && choice <= 3 else {
                self?.clearTerminal()
                self?.startAdventure()
                return
            }
            let diff = self.parseDifficulty(Double(choice))
            self.difficultyScale = diff.scale
            self.dungeon = Dungeon(name: dungeonName, level: diff.level)
            self.enterDungeon()
        }
    }

    /// Stack of (name, level) states for undo/redo in adventure confirmation
    private var adventureUndoStack: [(String, Double)] = []
    private var adventureRedoStack: [(String, Double)] = []

    private func confirmAdventure(dungeonName: String, level: Double) {
        clearTerminal()
        printTitle("Ready to Begin?")

        // Castle dragon on the entry screen
        DispatchQueue.main.async {
            self.dragonGifName = "dragon_castle"
        }

        let diffName = difficultyName(for: level)
        let levelStr = level.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(level))" : String(format: "%.1f", level)
        print("")
        print("  DUNGEON", color: .cyan, bold: true)
        printWrapped("  \(dungeonName)", indent: 2, color: .brightGreen)
        print("")
        print("  DIFFICULTY", color: .cyan, bold: true)
        print("  \(diffName) (Level \(levelStr))", color: .brightGreen)
        print("")
        print("  PARTY", color: .cyan, bold: true)
        for char in party {
            let hp = "HP \(char.currentHP)/\(char.maxHP)"
            print("  \(char.name) — Lv.\(char.level) \(char.characterClass.rawValue) (\(hp))", color: .dimGreen)
        }
        print("")

        var opts = ["Enter the Dungeon", "Difficulty", "Rename"]
        if !adventureUndoStack.isEmpty { opts.append("Undo") }
        if !adventureRedoStack.isEmpty { opts.append("Redo") }
        opts.append("Help")

        showMenu(opts)

        closeHandler = { [weak self] in
            self?.adventureUndoStack.removeAll()
            self?.adventureRedoStack.removeAll()
            self?.clearTerminal()
            self?.startNewGame()
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = opts[choice - 1]
            switch selected {
            case "Enter the Dungeon":
                self.adventureUndoStack.removeAll()
                self.adventureRedoStack.removeAll()
                let diff = self.parseDifficulty(level)
                self.difficultyScale = diff.scale
                self.dungeon = Dungeon(name: dungeonName, level: diff.level)
                self.enterDungeon()
            case "Difficulty":
                self.adventureUndoStack.append((dungeonName, level))
                self.adventureRedoStack.removeAll()
                self.changeDifficultyInline(currentName: dungeonName, currentLevel: level)
            case "Rename":
                self.adventureUndoStack.append((dungeonName, level))
                self.adventureRedoStack.removeAll()
                self.changeDungeonNameInline(currentName: dungeonName, currentLevel: level)
            case "Undo":
                if let prev = self.adventureUndoStack.popLast() {
                    self.adventureRedoStack.append((dungeonName, level))
                    self.confirmAdventure(dungeonName: prev.0, level: prev.1)
                }
            case "Redo":
                if let next = self.adventureRedoStack.popLast() {
                    self.adventureUndoStack.append((dungeonName, level))
                    self.confirmAdventure(dungeonName: next.0, level: next.1)
                }
            case "Help":
                self.showReadyToBeginHelp(dungeonName: dungeonName, level: level)
            default: break
            }
        }
    }

    private func showReadyToBeginHelp(dungeonName: String, level: Double) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Ready to Begin — Help")
        print("")
        print("  ENTER THE DUNGEON", color: .cyan, bold: true)
        printWrapped("Begin your adventure with the current dungeon and difficulty. Your party will enter the first room and the quest begins!", indent: 2, color: .dimGreen)
        print("")
        print("  DIFFICULTY", color: .cyan, bold: true)
        printWrapped("Change the difficulty level. Easy (1) suits small parties, Medium (2) is balanced for four, and Hard (3+) is for veterans. You can also enter custom values like 1.5 for fine-tuning.", indent: 2, color: .dimGreen)
        print("")
        print("  RENAME", color: .cyan, bold: true)
        printWrapped("Give your dungeon a custom name. Type anything you like, or leave it to get a randomly generated name.", indent: 2, color: .dimGreen)
        print("")
        print("  UNDO / REDO", color: .cyan, bold: true)
        printWrapped("Step back or forward through changes you've made to the dungeon name or difficulty on this screen.", indent: 2, color: .dimGreen)
        print("")

        showMenu(["< Back"])
        closeHandler = { [weak self] in self?.confirmAdventure(dungeonName: dungeonName, level: level) }
        menuHandler = { [weak self] _ in self?.confirmAdventure(dungeonName: dungeonName, level: level) }
    }

    private func changeDifficultyInline(currentName: String, currentLevel: Double) {
        clearTerminal()
        printTitle("Choose Difficulty")
        printWrapped("Dungeon: \(currentName)", indent: 2, color: .brightGreen)
        print("")
        print("Pick a preset or type a custom level:", color: .dimGreen)
        print("  (0 = trivial, 1 = easy, 2 = medium, 3 = hard, 4+ = brutal)", color: .dimGreen)

        promptTextWithMenu("", options: ["Easy (1)", "Medium (2)", "Hard (3)"])

        closeHandler = { [weak self] in
            self?.confirmAdventure(dungeonName: currentName, level: currentLevel)
        }
        menuHandler = { [weak self] choice in
            guard choice >= 1 && choice <= 3 else { return }
            self?.confirmAdventure(dungeonName: currentName, level: Double(choice))
        }
        inputHandler = { [weak self] text in
            guard let self = self else { return }
            guard let value = Double(text.trimmingCharacters(in: .whitespaces)) else {
                self.print("Enter a number (e.g. 1, 2.5, 3).", color: .yellow)
                self.changeDifficultyInline(currentName: currentName, currentLevel: currentLevel)
                return
            }
            if value < 0 {
                self.print("Even the bravest adventurers must face some challenge! Enter 0 or above.", color: .yellow)
                self.changeDifficultyInline(currentName: currentName, currentLevel: currentLevel)
                return
            }
            self.confirmAdventure(dungeonName: currentName, level: value)
        }
    }

    private func changeDungeonNameInline(currentName: String, currentLevel: Double) {
        clearTerminal()
        printTitle("Rename Dungeon")

        var suggestions: [String] = []
        var pool = dungeonNames.shuffled()
        while suggestions.count < 3 && !pool.isEmpty {
            let name = pool.removeFirst()
            if !suggestions.contains(name) && name != currentName { suggestions.append(name) }
        }

        promptTextWithMenu("Enter a name, or choose one:", options: suggestions.map { String($0.prefix(MenuOption.maxButtonLength)) })

        rerollHandler = { [weak self] in
            self?.changeDungeonNameInline(currentName: currentName, currentLevel: currentLevel)
        }
        closeHandler = { [weak self] in
            self?.confirmAdventure(dungeonName: currentName, level: currentLevel)
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= suggestions.count {
                self.confirmAdventure(dungeonName: suggestions[choice - 1], level: currentLevel)
            }
        }
        inputHandler = { [weak self] name in
            guard let self = self else { return }
            let newName = (name.isEmpty ? currentName : name).capitalized
            if !self.isNameAppropriate(newName) {
                self.print("The DM frowns. Choose a more suitable name.", color: .yellow)
                self.changeDungeonNameInline(currentName: currentName, currentLevel: currentLevel)
                return
            }
            self.confirmAdventure(dungeonName: newName, level: currentLevel)
        }
    }

    private func enterDungeon() {
        clearTerminal()
        gameState = .exploring
        gameTimeMinutes = 360  // 6:00 AM
        adventureLog = []
        partyChatLog = []
        roomsSinceLastSave = 0
        DMEngine.shared.clearHistory()
        dmChatLog = []
        logEvent("Entered \(dungeon?.name ?? "the dungeon")", category: "EXPLORE")
        if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }

        // Auto-light torch if the party has one
        if partyHasTorch() {
            torchLit = true
        }

        showExplorationView()
    }

    // MARK: - Exploration

    /// Estimate total available terminal lines for the current screen
    private func estimateAvailableLines() -> Int {
        #if os(iOS)
        let screenHeight = UIScreen.main.bounds.height
        let safeTop: CGFloat = 50   // status bar + notch
        let safeBottom: CGFloat = 34 // home indicator

        // D-pad: 3 rows × 44pt + 2 × 4pt spacing = 140pt
        let dpadHeight: CGFloat = 140 * fontScale
        // Menu buttons: ~10 buttons in 2-column compact grid
        // Each row: max(36, 32*scale) + 4pt spacing ≈ 40pt, 5 rows ≈ 200pt
        let menuButtonRows: CGFloat = 5
        let buttonRowHeight: CGFloat = max(36, 32 * fontScale) + 4
        let menuHeight = menuButtonRows * buttonRowHeight
        // Padding around button area
        let buttonAreaPadding: CGFloat = 24
        let buttonsHeight = dpadHeight + menuHeight + buttonAreaPadding

        let availableHeight = screenHeight - safeTop - safeBottom - buttonsHeight
        let lineHeight: CGFloat = (mapFontSize + 2) * fontScale  // font + spacing
        return max(10, Int(availableHeight / lineHeight))
        #elseif os(macOS)
        return 35  // reasonable default for macOS window
        #else
        return 30
        #endif
    }

    /// Estimate how many non-map lines the exploration view uses
    private func estimateExplorationLines() -> Int {
        // Torch warning (1), blank (1), room name (1), room desc (2-3 wrapped lines),
        // danger/treasure (1), exits (1), blank (1), multiplayer label (0-1),
        // level/time (1), party status (party.count), blank (1), status message (1)
        return 10 + party.count + (isMultiplayer ? 1 : 0)
    }

    /// Calculate the best map radius to fill the screen without scrolling.
    /// Returns (horizontal radius, vertical radius, compact).
    /// The map can be non-square — wider than tall — to avoid scrolling.
    private func bestMapRadius() -> (radius: Int, verticalRadius: Int, compact: Bool) {
        guard let dungeon = dungeon else { return (effectiveMapRadius(), effectiveMapRadius(), false) }
        let maxRadius = effectiveMapRadius()
        guard maxRadius > 0 else { return (0, 0, false) }

        let totalLines = estimateAvailableLines()
        let nonMapLines = estimateExplorationLines()
        let availableForMap = totalLines - nonMapLines

        // Try full square first, then shrink vertical before horizontal
        for r in stride(from: maxRadius, through: 1, by: -1) {
            // Try square at this radius
            let mapLines = dungeon.mapLineCount(visibilityRadius: r, torchLit: torchLit, compact: false)
            if mapLines <= availableForMap {
                return (r, r, false)
            }
            // Try square compact at this radius
            let compactLines = dungeon.mapLineCount(visibilityRadius: r, torchLit: torchLit, compact: true)
            if compactLines <= availableForMap {
                return (r, r, true)
            }
            // Try non-square: keep horizontal radius r, shrink vertical
            for vr in stride(from: r - 1, through: 1, by: -1) {
                let nsLines = dungeon.mapLineCount(visibilityRadius: r, torchLit: torchLit, compact: false, verticalRadius: vr)
                if nsLines <= availableForMap {
                    return (r, vr, false)
                }
                let nsCompact = dungeon.mapLineCount(visibilityRadius: r, torchLit: torchLit, compact: true, verticalRadius: vr)
                if nsCompact <= availableForMap {
                    return (r, vr, true)
                }
            }
        }

        // Even radius 1 doesn't fit — use 1 compact as minimum
        return (1, 1, true)
    }

    /// Redraws the full exploration screen: map + room description + party + menu
    /// Quick save from exploration — wraps performQuickSave
    private func quickSave() {
        performQuickSave()
    }

    /// Help screen for exploration — explains the map, buttons, and gameplay
    private func showExplorationHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Exploration Help")
        print("")
        print("  THE MAP", color: .cyan, bold: true)
        printWrapped("@ is your party. Rooms show their type ($ = Loot, ! = Danger, S = Shop, + = Shrine). Corridors connect rooms with -- (horizontal) or | (vertical). XX means a secured door.", indent: 2, color: .green)
        print("")
        print("  DIRECTIONS", color: .cyan, bold: true)
        printWrapped("Tap a direction (N/S/E/W) to move. Long-press a direction to secure or unsecure that door — barricading it blocks movement and reduces ambush risk when resting.", indent: 2, color: .dimGreen)
        print("")
        print("  BUTTONS", color: .cyan, bold: true)
        printWrapped("Search Room looks for hidden items and scavenges for supplies. Listen reveals what lurks beyond each exit. Rest (centre button) heals the party — hold for a long rest.", indent: 2, color: .dimGreen)
        print("")
        print("  CHAT & INPUT", color: .cyan, bold: true)
        printWrapped("Type in the text prompt to chat with your party and the DM. You can ask questions, make plans, or give commands. Say 'done' or tap ✕ to leave chat.", indent: 2, color: .dimGreen)
        print("")
        print("  NPCs", color: .cyan, bold: true)
        printWrapped("NPCs appear throughout the dungeon. Talk to them for information, healing, trading, and quests. The Gatekeeper at the entrance knows about the boss and offers quests — but not all NPCs are truthful! Some are evasive, and some outright lie.", indent: 2, color: .dimGreen)
        print("")
        print("  SAVE & QUIT", color: .cyan, bold: true)
        printWrapped("Save button quick-saves your game. The ✕ close icon opens the Save/Quit menu for manual saves or returning to the main menu.", indent: 2, color: .dimGreen)
        print("")
        printInputHelp()

        closeHandler = { [weak self] in self?.showExplorationView() }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showExplorationView() }
    }

    func showExplorationView() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }

        SpeechEngine.shared.stop()
        clearTerminal()

        // Dynamically size the map to fill screen without scrolling
        let (radius, verticalRadius, compact) = bestMapRadius()
        let mapLines = dungeon.getMapDisplay(visibilityRadius: radius, torchLit: torchLit, compact: compact, verticalRadius: verticalRadius)
        printLines(mapLines, color: torchMapColor, size: mapFontSize)
        if !torchLit {
            if partyHasTorch() {
                print("  Torch unlit — light it to see further!", color: .yellow)
            } else {
                print("  No torch — visibility reduced!", color: .yellow)
            }
        } else if torchTurnsRemaining > 0 && torchTurnsRemaining <= 5 {
            print("  Torch flickering... (\(torchTurnsRemaining) rooms left)", color: .yellow)
        }
        print("")

        // Room description — dim when torch is off
        if torchLit {
            print(room.name, color: .brightGreen, bold: true)
            printWrapped(room.roomDescription)
        } else {
            print(room.name, color: .dimGreen, bold: true)
            print("It's too dark to see clearly...", color: .gray)
        }

        if !room.cleared && room.encounter != nil {
            print("You sense danger here...", color: .red)
        }
        // NPC presence — harder to notice without a torch
        if let npc = room.npc, npcsEnabled {
            if torchLit {
                print("A \(npc.type.rawValue) is here.", color: .cyan)
            } else if Bool.random() {
                // 50% chance to notice NPC in the dark
                print("You hear someone nearby...", color: .cyan)
            }
        }
        if torchLit && !room.treasure.isEmpty && room.cleared {
            print("You see treasure on the ground.", color: .yellow)
        }
        if torchLit && !room.droppedItems.isEmpty {
            let names = room.droppedItems.map { $0.name }.joined(separator: ", ")
            print("Items on the floor: \(names)", color: .yellow)
        }

        if torchLit {
            let exitList = room.exits.keys.map { $0.rawValue }.joined(separator: ", ")
            if !exitList.isEmpty {
                print("Exits: \(exitList)", color: .dimGreen)
            }
        } else {
            print("Exits: You can feel openings...", color: .gray)
        }

        print("")

        // Multiplayer indicator
        if isMultiplayer {
            print("MULTIPLAYER", color: .magenta, bold: true)
        }

        // Party status
        let levelStr = dungeon.level > 0 ? "Level \(dungeon.level) | " : ""
        if gameTimeLimit > 0 {
            let remaining = max(0, gameTimeLimit - gameTimeMinutes)
            let remainStr = formatTimeRemaining(remaining)
            let timeColor: TerminalColor = remaining > 180 ? .dimGreen : (remaining > 60 ? .yellow : .red)
            print("\(levelStr)\(formattedGameTime())  ⏱ \(remainStr)", color: timeColor)
        } else {
            print("\(levelStr)\(formattedGameTime())", color: .dimGreen)
        }
        let maxNameLen = party.map { $0.name.count }.max() ?? 10
        for char in party {
            let padded = char.name.padding(toLength: maxNameLen, withPad: " ", startingAt: 0)
            let hp = "\(char.currentHP)/\(char.maxHP) HP"
            let poisonTag = char.isPoisoned ? " ☠" : ""
            let youTag = (isMultiplayer && char.id == localCharacterId) ? " <<" : ""
            let color: TerminalColor = char.isPoisoned ? .magenta : .cyan
            print(" \(padded)  \(hp)\(poisonTag)\(youTag)", color: color)
        }
        // Poison warning if any character is poisoned
        if party.contains(where: { $0.isPoisoned }) {
            let poisonedNames = party.filter { $0.isPoisoned }.map { $0.name }.joined(separator: ", ")
            print(" ☠ Poisoned: \(poisonedNames) — use Antidote, potion, or rest", color: .magenta)
        }
        print("")

        // Check for encounter — darkness gives a chance to sneak past
        if !room.cleared, let encounter = room.encounter {
            if !torchLit && Int.random(in: 1...100) <= 30 {
                room.cleared = true
                room.encounter = nil
                logEvent("Sneaked past enemies in \(room.name) (darkness)", category: "EXPLORE")
                logMultiplayerAction("The party crept past enemies in the dark")
                explorationStatusMessage = ("You creep past the enemies in darkness...", .dimGreen)
                showExplorationView()
                return
            }
            if !torchLit {
                print("You stumble in the dark!", color: .red)
                print("")
            }
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

        // Show transient status message if set
        if let msg = explorationStatusMessage {
            print("  \(msg.text)", color: msg.color)
            print("")
            explorationStatusMessage = nil
        }

        // Build direction exits for the D-pad
        var exits: [Direction: Bool] = [:]
        var secured: Set<Direction> = []
        if torchLit {
            for direction in Direction.allCases {
                let hasExit = room.exits[direction] != nil
                let isSecured = room.secured.contains(direction)
                exits[direction] = hasExit && !isSecured
                if hasExit && isSecured { secured.insert(direction) }
            }
        } else {
            // Torch off: show all directions as available (uncertain) — grey on D-pad
            for direction in Direction.allCases {
                exits[direction] = true
            }
        }
        DispatchQueue.main.async { self.securedExits = secured }

        // Build menu options — contextual actions at top, persistent buttons
        // at bottom in fixed relative order so positions stay stable.
        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        // --- Top row: Actions + contextual ---
        menuOpts.append(MenuOption("Actions"))
        actions.append { [weak self] in self?.showActionsMenu() }

        if room.roomType == .shop && (room.cleared || room.encounter == nil) {
            menuOpts.append(MenuOption("Merchant"))
            actions.append { [weak self] in if self?.torchLit == true { self?.visitShop() } }
        }

        // Talk to NPC — shown on the D-pad (SE corner) rather than in menu buttons
        // Without a torch, NPCs are harder to find (only show if already spoken to)
        if let npc = room.npc, npcsEnabled, (torchLit || npc.hasBeenTalkedTo) {
            let talkLabel = npc.hasBeenTalkedTo ? "Talk" : "Speak to \(npc.type.rawValue.components(separatedBy: " ").last ?? "Stranger")"
            DispatchQueue.main.async {
                self.dpadNPCLabel = talkLabel
                self.dpadNPCHandler = { [weak self] in self?.talkToNPC() }
            }
        }

        // --- Middle row: Inventory + Party Status ---
        menuOpts.append(MenuOption("Inventory"))
        actions.append { [weak self] in self?.showInventory() }

        menuOpts.append(MenuOption("Party Status"))
        actions.append { [weak self] in self?.showPartyStatus() }

        // --- Bottom row: Help ---
        menuOpts.append(MenuOption("Help", tint: .navigation))
        actions.append { [weak self] in self?.showExplorationHelp() }

        // --- Multiplayer ---
        if isMultiplayer {
            menuOpts.append(MenuOption("Pass Turn", tint: .cyan))
            actions.append { [weak self] in self?.multiplayerPassTurn() }
        }

        showMenuWithDirections(menuOpts, exits: exits)

        directionHandler = { [weak self] direction in
            self?.move(direction)
        }
        directionLongPressHandler = { [weak self] direction in
            guard let self = self, let room = self.dungeon?.currentRoom else { return }
            guard room.exits[direction] != nil else { return }
            if room.secured.contains(direction) {
                // Unsecure
                room.secured.remove(direction)
                self.advanceTime(3)
                self.logEvent("Unsecured \(direction.rawValue) exit in \(room.name)", category: "EXPLORE")
                self.explorationStatusMessage = ("Opened \(direction.rawValue.lowercased()) door.", .brightGreen)
            } else {
                // Secure
                room.secured.insert(direction)
                self.advanceTime(5)
                self.logEvent("Secured \(direction.rawValue) exit in \(room.name)", category: "EXPLORE")
                self.explorationStatusMessage = ("Barricaded \(direction.rawValue.lowercased()) door. 🔒", .yellow)
            }
            self.showExplorationView()
        }
        dpadCenterLabel = "Rest"
        dpadCenterHandler = { [weak self] in
            self?.rest()
        }
        dpadCenterLongPressHandler = { [weak self] in
            self?.performRest(isLongRest: true, fast: true)
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
        // Long-press handlers for exploration menu — fall through to normal tap for unhandled
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            // Unhandled long-press → treat as normal tap
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }

        // Close icon → if just saved, go straight to quit confirmation; otherwise Save/Quit menu
        closeHandler = { [weak self] in
            guard let self = self else { return }
            if let saved = self.lastSaveTime, Date().timeIntervalSince(saved) < 60,
               let slotId = self.activeSlotId {
                let slotName = self.activeSlotName ?? "Current Game"
                self.confirmQuitAfterRecentSave(slotId: slotId, slotName: slotName)
            } else {
                self.showSaveMenu()
            }
        }

        // Text input → enter chat mode (set after async to override showMenuWithDirections)
        inputHandler = { [weak self] input in
            guard let self = self else { return }
            let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            // Pre-seed chat with the user's message, then show chat
            self.showPartyChat(initialMessage: text)
        }
        DispatchQueue.main.async { self.awaitingTextInput = true }

        resetIdleTimer()
    }

    // MARK: - Dropped Items Pickup

    private func pickUpDroppedItems() {
        guard let room = dungeon?.currentRoom, !room.droppedItems.isEmpty else {
            showExplorationView()
            return
        }
        let item = room.droppedItems[0]
        room.droppedItems.removeFirst()
        showItemPickupMenu(item: item, source: "Left on the floor") { [weak self] in
            guard let self = self else { return }
            if let room = self.dungeon?.currentRoom, !room.droppedItems.isEmpty {
                self.pickUpDroppedItems()
            } else {
                self.showExplorationView()
            }
        }
    }

    // MARK: - Torch Mechanics

    /// Map colour based on torch state and remaining life.
    /// Flickers on activation (first few turns), steady for most, dims over last 10%.
    var torchMapColor: TerminalColor {
        guard torchLit else { return .gray }
        let life = torchTurnsRemaining
        let full = Item.torchFullLife  // 720
        let threshold = full / 10      // 72 min = last 10%

        if life <= 0 { return .gray }
        if life <= threshold / 2 {
            // Very low — flicker between gray and dimGreen
            return Bool.random() ? .dimGreen : .gray
        }
        if life <= threshold {
            // Last 10% — dimGreen, occasional flicker to gray
            return Int.random(in: 1...4) == 1 ? .gray : .dimGreen
        }
        // Steady burn — bright green
        return .brightGreen
    }

    /// Find the best torch to light (most life remaining)
    private func findBestTorch() -> (Character, Item)? {
        var best: (Character, Item)? = nil
        for char in party {
            for item in char.inventory where item.isTorch {
                let life = item.torchLife ?? Item.torchFullLife
                if life > 0, best == nil || life > (best!.1.torchLife ?? Item.torchFullLife) {
                    best = (char, item)
                }
            }
        }
        return best
    }

    /// Save remaining life back to the active torch item
    private func syncTorchLife() {
        guard let torchId = activeTorchId, torchTurnsRemaining > 0 else { return }
        for char in party {
            if let idx = char.inventory.firstIndex(where: { $0.id == torchId }) {
                char.inventory[idx].torchLife = torchTurnsRemaining
                return
            }
        }
    }

    private func lightTorch() {
        guard let (holder, torch) = findBestTorch() else {
            explorationStatusMessage = ("No torch to light!", .red)
            showExplorationView()
            return
        }
        activeTorchId = torch.id
        torchHolderId = holder.id
        torchTurnsRemaining = torch.torchLife ?? Item.torchFullLife
        torchLit = true
        logEvent("Lit a torch (\(torch.torchLifeDescription ?? "12h") left)", category: "EXPLORE")
        explorationStatusMessage = ("You light a torch. The shadows retreat.", .yellow)
        showExplorationView()
    }

    private func douseTorch() {
        syncTorchLife()
        torchLit = false
        logEvent("Doused torch (\(torchTurnsRemaining / 60)h \(torchTurnsRemaining % 60)m left)", category: "EXPLORE")
        torchTurnsRemaining = 0
        activeTorchId = nil
        torchHolderId = nil
        explorationStatusMessage = ("You extinguish the torch. Darkness closes in. Monsters may not notice you as easily, but you might stumble into things.", .gray)
        showExplorationView()
    }

    /// Current game context for hint weighting
    private var currentHintContext: String {
        switch gameState {
        case .combat: return "combat"
        case .exploring: return "exploration"
        case .mainMenu: return "settings"
        default: return "exploration"
        }
    }

    /// Occasionally show a gameplay tip after rest or combat
    private func maybeShowTip() {
        guard tipCooldown <= 0 else {
            tipCooldown -= 1
            return
        }
        guard Int.random(in: 1...100) <= 15 else { return }

        if let result = FAQData.contextWeightedTip(context: currentHintContext, excluding: shownTipIndices) {
            shownTipIndices.insert(result.index)
            tipCooldown = 5
            print("")
            print("  Tip: \(result.tip)", color: .dimGreen)
        } else {
            shownTipIndices.removeAll()
        }
    }

    /// Show a random gameplay hint in an alert-style popup, then return to previous screen via callback
    private func showRandomHint(onBack: @escaping () -> Void, context: String? = nil) {
        let ctx = context ?? currentHintContext
        if let result = FAQData.contextWeightedTip(context: ctx, excluding: shownTipIndices) {
            shownTipIndices.insert(result.index)

            clearTerminal()
            printTitle("Hint")
            print("")
            printWrapped(result.tip, indent: 2, color: .yellow)
            print("")

            showMenu(["Another Hint"])
            menuHandler = { [weak self] choice in
                if choice == 1 { self?.showRandomHint(onBack: onBack, context: context) }
            }
            closeHandler = { [weak self] in
                self?.closeHandler = nil
                onBack()
            }
        } else {
            shownTipIndices.removeAll()
            onBack()
        }
    }

    private func tickTorch() {
        guard torchLit else { return }
        torchTurnsRemaining -= 10  // 10 minutes per exploration move

        // Low torch warning
        if torchTurnsRemaining > 0 && torchTurnsRemaining <= 60 && torchTurnsRemaining % 30 == 0 {
            let mins = torchTurnsRemaining
            print("")
            print("  Your torch is burning low — about \(mins) minutes left.", color: .yellow)
        }

        if torchTurnsRemaining <= 0 {
            torchLit = false
            torchTurnsRemaining = 0
            // Consume the burned-out torch
            if let torchId = activeTorchId {
                for char in party {
                    if let idx = char.inventory.firstIndex(where: { $0.id == torchId }) {
                        char.inventory.remove(at: idx)
                        break
                    }
                }
            }
            activeTorchId = nil
            torchHolderId = nil
            print("")
            print("  Your torch sputters and goes out!", color: .red)
            logEvent("Torch burned out", category: "EXPLORE")
            printTorchHint()
        }
    }

    /// Called at combat start — small chance of torch blowing out
    func checkTorchBlowout() {
        guard torchLit else { return }
        let roll = Int.random(in: 1...20)
        if roll <= 1 {
            syncTorchLife()
            torchLit = false
            // Torch item stays — just needs relighting
            print("")
            print("  A gust of wind blows out your torch!", color: .red)
            logEvent("Torch blown out in combat", category: "COMBAT")
            printTorchHint()
        }
    }

    /// Random torch events during exploration (~3% chance per room)
    private func checkTorchEvent() {
        guard torchLit, torchTurnsRemaining > 60 else { return }
        let roll = Int.random(in: 1...100)
        guard roll <= 3 else { return }

        let event = Int.random(in: 1...100)
        if event <= 25 {
            // Gust of wind — torch goes out
            syncTorchLife()
            torchLit = false
            print("")
            print("  A strange gust of wind sweeps through the corridor!", color: .red)
            print("  Your torch goes out!", color: .red)
            logEvent("Torch blown out by gust", category: "EXPLORE")
            printTorchHint()
        } else if event <= 90 {
            // Flicker warning — cosmetic only
            let messages = [
                "Your torch flickers ominously in a draft...",
                "The flame dips low for a moment, then recovers.",
                "Shadows dance wildly as your torch sputters briefly.",
                "A cold draught makes your torch gutter and hiss.",
            ]
            print("")
            print("  \(messages.randomElement()!)", color: .yellow)
        } else {
            // Trip and drop — torch goes out
            syncTorchLife()
            torchLit = false
            let messages = [
                "You stumble on loose rubble and drop the torch! It goes out.",
                "Something brushes your arm — you fumble the torch and it dies.",
                "A loose flagstone trips you. The torch hits the ground and snuffs out.",
            ]
            print("")
            print("  \(messages.randomElement()!)", color: .red)
            logEvent("Torch dropped", category: "EXPLORE")
            printTorchHint()
        }
    }

    /// Hint to check inventory after torch goes out
    private func printTorchHint() {
        if partyHasTorch() {
            print("  Search your packs — you have another torch!", color: .yellow)
        } else {
            print("  You're out of torches. Find one at a shop.", color: .yellow)
        }
    }

    func move(_ direction: Direction) {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }

        // Cannot move through barricaded doors — must unsecure first
        if room.secured.contains(direction) {
            print("  That door is barricaded! Unsecure it first.", color: .yellow)
            print("  (Long-press the direction or use Secure from Actions)", color: .dimGreen)
            return
        }

        let result = dungeon.move(direction: direction)
        if result.success {
            advanceTime(10)
            tickTorch()
            checkTorchEvent()
            if let room = dungeon.currentRoom {
                logEvent("Moved \(direction.rawValue) to \(room.name)", category: "EXPLORE")
                logMultiplayerAction("The party entered \(room.name)")
            }
            autosaveIfNeeded()
        } else {
            if !torchLit {
                let darkMessages = [
                    "You grope in the darkness but find only a cold stone wall.",
                    "Your hands meet solid rock. No passage this way.",
                    "You stumble forward in the dark... nothing. Just a dead end.",
                    "The wall is unyielding. Try another direction.",
                ]
                explorationStatusMessage = (darkMessages.randomElement()!, .yellow)
            } else {
                print(result.message, color: .yellow)
            }
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
        logMultiplayerAction("\(target.name) triggered \(trap.name) — \(damage) damage! (\(target.currentHP)/\(target.maxHP) HP)")

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
            printExplorationMap()
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

        // Validate the exit actually exists and isn't barricaded
        if room.exits[dir] != nil && !room.secured.contains(dir) {
            let result = dungeon.move(direction: dir)
            if result.success {
                advanceTime(10)
                if let newRoom = dungeon.currentRoom {
                    logEvent("DM moved party \(dir.rawValue) to \(newRoom.name)", category: "DM")
                    print("")
                    print("  [Moved \(dir.rawValue) to \(newRoom.name)!]", color: .cyan, bold: true)
                    print("")
                    printExplorationMap()
                }
            }
        } else {
            print("  [No exit \(dir.rawValue) — the DM's path is blocked.]", color: .dimGreen)
        }
    }

    private func applyDMDropItem(_ itemName: String) {
        let lower = itemName.lowercased()
        for char in party {
            // Try exact contains first, then word-by-word matching
            if let item = char.inventory.first(where: { $0.name.lowercased().contains(lower) })
                ?? char.inventory.first(where: { lower.contains($0.name.lowercased()) })
                ?? char.inventory.first(where: {
                    let words = lower.split(separator: " ")
                    let itemWords = $0.name.lowercased().split(separator: " ")
                    return words.contains(where: { w in itemWords.contains(where: { $0 == w && w.count > 2 }) })
                }) {
                char.removeItem(item)
                if let room = dungeon?.currentRoom {
                    room.droppedItems.append(item)
                }
                print("  [Dropped: \(item.name)]", color: .yellow, bold: true)
                logEvent("DM: \(char.name) dropped \(item.name)", category: "DM")
                return
            }
            // Check equipped items (bidirectional match)
            if let w = char.equippedWeapon, (w.name.lowercased().contains(lower) || lower.contains(w.name.lowercased())) {
                char.unequipWeapon()
                char.removeItem(w)
                if let room = dungeon?.currentRoom { room.droppedItems.append(w) }
                print("  [Dropped: \(w.name)]", color: .yellow, bold: true)
                logEvent("DM: \(char.name) dropped \(w.name)", category: "DM")
                return
            }
            if let a = char.equippedArmor, (a.name.lowercased().contains(lower) || lower.contains(a.name.lowercased())) {
                char.unequipArmor()
                char.removeItem(a)
                if let room = dungeon?.currentRoom { room.droppedItems.append(a) }
                print("  [Dropped: \(a.name)]", color: .yellow, bold: true)
                logEvent("DM: \(char.name) dropped \(a.name)", category: "DM")
                return
            }
            if let s = char.equippedShield, (s.name.lowercased().contains(lower) || lower.contains(s.name.lowercased())) {
                char.unequipShield()
                char.removeItem(s)
                if let room = dungeon?.currentRoom { room.droppedItems.append(s) }
                print("  [Dropped: \(s.name)]", color: .yellow, bold: true)
                logEvent("DM: \(char.name) dropped \(s.name)", category: "DM")
                return
            }
        }
        print("  [No \(itemName) found to drop.]", color: .dimGreen)
    }

    /// Scan DM narrative for implied item state changes that lack command tags.
    /// Auto-applies drops, uses, and equips mentioned in text but not tagged.
    private func applyNarrativeFallbacks(text: String, alreadyApplied: DMCommandResult) -> Bool {
        let lower = text.lowercased()
        var changed = false

        // Collect all inventory item names for matching
        var allItems: [(char: Character, item: Item, equipped: Bool)] = []
        for char in party {
            for item in char.inventory {
                allItems.append((char, item, false))
            }
            if let w = char.equippedWeapon { allItems.append((char, w, true)) }
            if let a = char.equippedArmor { allItems.append((char, a, true)) }
            if let s = char.equippedShield { allItems.append((char, s, true)) }
        }

        // Drop patterns: "drops the X", "throws away X", "discards X", "sets down X", "tosses X"
        let dropPatterns = ["drops the ", "drop the ", "drops his ", "drops her ",
                            "throws away ", "discards the ", "sets down the ",
                            "tosses the ", "tosses away ", "gets rid of the ",
                            "puts down the ", "removes the ", "takes off the "]

        for item in allItems {
            let iName = item.item.name.lowercased()
            // Skip if already handled by a tag
            if alreadyApplied.droppedItems.contains(where: { $0.lowercased().contains(iName) || iName.contains($0.lowercased()) }) {
                continue
            }
            for pattern in dropPatterns {
                if lower.contains(pattern + iName) || lower.contains(pattern + iName.replacingOccurrences(of: " ", with: "")) {
                    // Narrative implies dropping this item
                    if item.equipped {
                        switch item.item.type {
                        case .weapon: item.char.unequipWeapon()
                        case .armor: item.char.unequipArmor()
                        case .shield: item.char.unequipShield()
                        default: break
                        }
                    }
                    item.char.removeItem(item.item)
                    if let room = dungeon?.currentRoom {
                        room.droppedItems.append(item.item)
                    }
                    print("  [Auto-applied: \(item.char.name) dropped \(item.item.name)]", color: .yellow)
                    logEvent("DM (auto): \(item.char.name) dropped \(item.item.name)", category: "DM")
                    changed = true
                    break
                }
            }
        }

        // Use patterns: "drinks the X", "eats the X", "uses the X", "consumes the X"
        let usePatterns = ["drinks the ", "drinks a ", "eats the ", "eats a ",
                           "uses the ", "uses a ", "consumes the ", "consumes a ",
                           "quaffs the ", "quaffs a "]
        for item in allItems where !item.equipped {
            let iName = item.item.name.lowercased()
            if alreadyApplied.usedItems.contains(where: { $0.lowercased().contains(iName) || iName.contains($0.lowercased()) }) {
                continue
            }
            for pattern in usePatterns {
                if lower.contains(pattern + iName) || lower.contains(pattern + iName.replacingOccurrences(of: " ", with: "")) {
                    if let healStr = item.item.potionStats?.healAmount {
                        item.char.removeItem(item.item)
                        let roll = Dice.rollDamage(healStr)
                        let amount = max(1, roll.total)
                        item.char.heal(amount)
                        print("  [Auto-applied: \(item.char.name) used \(item.item.name) — +\(amount) HP]", color: .brightGreen)
                        logEvent("DM (auto): \(item.char.name) used \(item.item.name), healed \(amount) HP", category: "DM")
                    } else {
                        item.char.removeItem(item.item)
                        print("  [Auto-applied: \(item.char.name) used \(item.item.name)]", color: .cyan)
                        logEvent("DM (auto): \(item.char.name) used \(item.item.name)", category: "DM")
                    }
                    changed = true
                    break
                }
            }
        }

        return changed
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
                if item.name.lowercased().contains("antidote") {
                    char.removeItem(item)
                    if char.isPoisoned {
                        char.curePoison()
                        print("  [\(char.name) drinks antidote — poison cured!]", color: .brightGreen, bold: true)
                        logEvent("DM: \(char.name) used antidote, cured poison", category: "DM")
                    } else {
                        print("  [\(char.name) drinks antidote (not poisoned).]", color: .dimGreen)
                    }
                } else if let healStr = item.potionStats?.healAmount {
                    char.removeItem(item)
                    let roll = Dice.rollDamage(healStr)
                    let amount = max(1, roll.total)
                    char.heal(amount)
                    if char.isPoisoned {
                        char.curePoison()
                        print("  [\(char.name) uses \(item.name): +\(amount) HP! Poison cured!]", color: .brightGreen, bold: true)
                    } else {
                        print("  [\(char.name) uses \(item.name): +\(amount) HP!]", color: .brightGreen, bold: true)
                    }
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

    private func applyDMLightTorch() {
        if torchLit {
            print("  [The torch is already lit.]", color: .dimGreen)
            return
        }
        if let (holder, torch) = findBestTorch() {
            activeTorchId = torch.id
            torchHolderId = holder.id
            torchTurnsRemaining = torch.torchLife ?? Item.torchFullLife
            torchLit = true
            print("  [Torch lit!]", color: .yellow, bold: true)
            logEvent("DM lit torch", category: "DM")
        } else {
            print("  [No torch to light.]", color: .dimGreen)
        }
    }

    private func applyDMDouseTorch() {
        if !torchLit {
            print("  [The torch is already out.]", color: .dimGreen)
            return
        }
        syncTorchLife()
        torchLit = false
        torchTurnsRemaining = 0
        activeTorchId = nil
        torchHolderId = nil
        print("  [Torch extinguished!]", color: .yellow, bold: true)
        logEvent("DM doused torch", category: "DM")
    }

    private func applyDMUnsecure(_ dirName: String) {
        guard let room = dungeon?.currentRoom else { return }
        let dirMap: [String: Direction] = ["north": .north, "south": .south, "east": .east, "west": .west]
        guard let dir = dirMap[dirName] else { return }
        if room.secured.contains(dir) {
            room.secured.remove(dir)
            logEvent("Removed barricade from \(dir.rawValue) door in \(room.name)", category: "EXPLORE")
        }
    }

    private func applyDMSecure(_ dirName: String) {
        guard let room = dungeon?.currentRoom else { return }
        let dirMap: [String: Direction] = ["north": .north, "south": .south, "east": .east, "west": .west]
        guard let dir = dirMap[dirName] else { return }
        if room.exits[dir] != nil && !room.secured.contains(dir) {
            room.secured.insert(dir)
            logEvent("Barricaded \(dir.rawValue) door in \(room.name)", category: "EXPLORE")
        }
    }

    // MARK: - Actions Submenu

    private func showActionsMenu() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { showExplorationView(); return }

        clearTerminal()

        // Same layout as exploration view — map, room info, party status
        let (radius, verticalRadius, compact) = bestMapRadius()
        let mapLines = dungeon.getMapDisplay(visibilityRadius: radius, torchLit: torchLit, compact: compact, verticalRadius: verticalRadius)
        printLines(mapLines, color: torchMapColor, size: mapFontSize)
        if !torchLit {
            if partyHasTorch() {
                print("  Torch unlit — light it to see further!", color: .yellow)
            } else {
                print("  No torch — visibility reduced!", color: .yellow)
            }
        } else if torchTurnsRemaining > 0 && torchTurnsRemaining <= 5 {
            print("  Torch flickering... (\(torchTurnsRemaining) rooms left)", color: .yellow)
        }
        print("")

        // Room description
        if torchLit {
            print(room.name, color: .brightGreen, bold: true)
            printWrapped(room.roomDescription)
        } else {
            print(room.name, color: .dimGreen, bold: true)
            print("It's too dark to see clearly...", color: .gray)
        }
        print("")

        // Party status
        let levelStr = dungeon.level > 0 ? "Level \(dungeon.level) | " : ""
        if gameTimeLimit > 0 {
            let remaining = max(0, gameTimeLimit - gameTimeMinutes)
            let remainStr = formatTimeRemaining(remaining)
            let timeColor: TerminalColor = remaining > 180 ? .dimGreen : (remaining > 60 ? .yellow : .red)
            print("\(levelStr)\(formattedGameTime())  ⏱ \(remainStr)", color: timeColor)
        } else {
            print("\(levelStr)\(formattedGameTime())", color: .dimGreen)
        }
        let maxNameLen = party.map { $0.name.count }.max() ?? 10
        for char in party {
            let padded = char.name.padding(toLength: maxNameLen, withPad: " ", startingAt: 0)
            let hp = "\(char.currentHP)/\(char.maxHP) HP"
            let poisonTag = char.isPoisoned ? " ☠" : ""
            let color: TerminalColor = char.isPoisoned ? .magenta : .cyan
            print(" \(padded)  \(hp)\(poisonTag)", color: color)
        }
        print("")

        // Direction exits (same as exploration)
        var exits: [Direction: Bool] = [:]
        var secured: Set<Direction> = []
        for direction in Direction.allCases {
            let hasExit = room.exits[direction] != nil
            let isSecured = room.secured.contains(direction)
            exits[direction] = hasExit && !isSecured
            if hasExit && isSecured { secured.insert(direction) }
        }
        DispatchQueue.main.async { self.securedExits = secured }

        // Action buttons
        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        // Helper: set return destination to actions menu before each action
        let returnToActions: () -> Void = { [weak self] in
            self?.autoReturnDestination = { self?.showActionsMenu() }
        }

        // Search Room (also scavenges)
        menuOpts.append(MenuOption("Search Room"))
        actions.append { [weak self] in returnToActions(); self?.searchRoom() }

        // Listen
        menuOpts.append(MenuOption("Listen"))
        actions.append { [weak self] in returnToActions(); self?.listenAtDoors() }

        // Pick Up Items (dropped loot)
        if !room.droppedItems.isEmpty {
            menuOpts.append(MenuOption("Pick Up Items"))
            actions.append { [weak self] in returnToActions(); self?.pickUpDroppedItems() }
        }

        // Take Treasure
        var takeTreasureIndex: Int? = nil
        if !room.treasure.isEmpty {
            takeTreasureIndex = menuOpts.count
            menuOpts.append(MenuOption("Take Treasure"))
            actions.append { [weak self] in returnToActions(); self?.collectTreasure() }
        }

        // Torch toggle
        if torchLit {
            menuOpts.append(MenuOption("Douse Torch"))
            actions.append { [weak self] in
                self?.douseTorch()
                self?.showActionsMenu()
            }
        } else if partyHasTorch() {
            menuOpts.append(MenuOption("Illuminate"))
            actions.append { [weak self] in
                self?.lightTorch()
                self?.showActionsMenu()
            }
        }

        // Secure (barricade doors)
        menuOpts.append(MenuOption("Secure"))
        actions.append { [weak self] in returnToActions(); self?.secureRoom() }

        // Open Pack
        let consciousParty = party.filter { $0.isConscious }
        let hasPackItems = consciousParty.contains { !$0.inventory.isEmpty }
        menuOpts.append(MenuOption("Inventory", isDisabled: !hasPackItems))
        actions.append { [weak self] in
            guard let self = self else { return }
            returnToActions()
            if consciousParty.count == 1, let char = consciousParty.first {
                self.showPackMenu(character: char, onBack: { self.showActionsMenu() })
            } else {
                self.showPackCharacterPicker(onBack: { self.showActionsMenu() })
            }
        }

        // Save (quick save)
        menuOpts.append(MenuOption("Save", tint: .navigation))
        actions.append { [weak self] in self?.quickSave() }

        showMenuWithDirections(menuOpts, exits: exits)

        directionHandler = { [weak self] direction in
            self?.move(direction)
        }
        dpadCenterLabel = "Rest"
        dpadCenterHandler = { [weak self] in
            self?.rest()
        }
        dpadCenterLongPressHandler = { [weak self] in
            self?.performRest(isLongRest: true, fast: true)
        }

        closeHandler = { [weak self] in self?.showExplorationView() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
        // Long-press on disabled buttons for dark actions
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            guard choice >= 1 && choice <= menuOpts.count else { return }
            let opt = menuOpts[choice - 1]
            if opt.isDisabled && !self.torchLit {
                if opt.text == "Search Room" { self.darkSearch() }
                else if opt.text == "Take Treasure" { self.collectTreasureInDark() }
            }
        }
    }

    func searchRoom() {
        guard let room = dungeon?.currentRoom else { return }

        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        let hasHiddenLoot = !room.hiddenItems.isEmpty || room.hiddenGold > 0

        // If nothing hidden left, try scavenging instead
        if !hasHiddenLoot {
            forageSupplies()
            return
        }

        advanceTime(15)

        // Perception check
        let roll = Dice.d20()
        let bestPerception = party.map { $0.skillModifier(for: .perception) }.max() ?? 0
        let total = roll + bestPerception

        if total >= 15 {
            // Success — find something from the room's hidden loot
            // Prefer items first, then gold
            if !room.hiddenItems.isEmpty {
                let item = room.hiddenItems.removeFirst()
                let source = searchSourceDescription(for: room.roomType)
                let searchNarrative = "You search the \(room.name.lowercased()) carefully...\n  ...and find \(item.name)!"
                showItemPickupMenu(item: item, source: source, narrative: searchNarrative) { [weak self] in
                    self?.showExplorationView()
                }
                return
            } else if room.hiddenGold > 0 {
                let gold = room.hiddenGold
                room.hiddenGold = 0
                let source = searchSourceDescription(for: room.roomType)
                let searchNarrative = "You search the \(room.name.lowercased()) carefully...\n  ...and find \(gold) gold pieces!"
                showGoldPickupMenu(gold: gold, source: source, narrative: searchNarrative) { [weak self] in
                    self?.showExplorationView()
                }
                return
            }
        } else {
            // Failed check — hint if there's still something here
            let hints = searchFailHints(for: room.roomType)
            printWrapped("You search the \(room.name.lowercased()) carefully...", indent: 2, color: .cyan)
            print("")
            printWrapped(hints, indent: 2, color: .dimGreen)
            logEvent("Searched \(room.name) — missed something", category: "EXPLORE")
            logMultiplayerAction("Searched \(room.name) — found nothing")
        }

        // Add an examine-style observation about the room
        print("")
        let observation = examineObservation(for: room)
        if !observation.isEmpty {
            printWrapped(observation, indent: 2, color: .dimGreen)
        }

        autoReturn()
    }

    /// Room-type flavour text (merged from former Examine action)
    private func examineObservation(for room: Room) -> String {
        switch room.roomType {
        case .library:
            return ["Faded journals hint at the dungeon's history.", "The books are mostly ruined, but one contains a partial map.", "Ancient texts warn of deeper dangers."].randomElement()!
        case .shrine:
            return ["The altar feels warm to the touch.", "Faded offerings surround the shrine.", "The shrine feels cold and unwelcoming."].randomElement()!
        case .armory:
            return ["Scratch marks suggest the contents were taken in haste.", "Dents in the wall suggest training dummies once stood here.", "The metalwork suggests skilled craftsmanship."].randomElement()!
        case .prison:
            return ["Scratches on the walls tell stories of desperate prisoners.", "Names carved into stone — some centuries old.", "One cell door hangs open. The lock was picked from inside."].randomElement()!
        case .trap:
            if room.trapTriggered {
                return "You study the sprung trap carefully. You learn to spot the telltale signs."
            } else {
                return "Something feels off about this room. Best tread carefully."
            }
        case .treasure:
            return "Empty mounting hooks line the walls. This was clearly a vault."
        case .boss:
            return "The air is heavy. Claw marks far larger than any you've seen scar the walls."
        case .shop:
            return "A surprisingly cosy corner of the dungeon."
        default:
            return ["The walls are damp and cold. Faded carvings hint at the room's former purpose.", "Dust lies thick on every surface.", "The stonework here is cruder than elsewhere.", "You spot faint footprints in the dust."].randomElement()!
        }
    }

    /// Easter egg: fumbling search in the dark (long-press disabled Search Room)
    private func darkSearch() {
        guard let room = dungeon?.currentRoom else { return }

        clearTerminal()
        printWrapped("You fumble around in the darkness...", indent: 2, color: .gray)
        print("")
        advanceTime(15)

        let hasHiddenLoot = !room.hiddenItems.isEmpty || room.hiddenGold > 0

        // Harder perception check in the dark (DC 18 instead of 15)
        let roll = Dice.d20()
        let bestPerception = party.map { $0.skillModifier(for: .perception) }.max() ?? 0
        let total = roll + bestPerception

        // Fumbling mishaps (30% chance)
        let mishapRoll = Int.random(in: 1...100)
        if mishapRoll <= 30 {
            let mishaps = [
                "Your hand lands in something cold and slimy. You'd rather not know what it was.",
                "You grab something furry. It squeaks and scurries away!",
                "Your fingers find something sticky. It smells terrible.",
                "You put your hand straight into a cobweb. Something skitters up your arm!",
                "You stub your toe painfully on a rock. Ouch!",
                "You kneel in something wet and foul-smelling.",
                "You grab what you think is a handle. It's a dead rat's tail.",
                "Your hand finds something squishy. It pops. You shudder.",
                "You brush against something sharp and nick your finger. (-1 HP)",
                "You trip over something and bang your knee.",
            ]
            let mishap = mishaps.randomElement()!
            printWrapped(mishap, indent: 2, color: .yellow)
            print("")
            if mishap.contains("-1 HP") {
                if let char = party.first(where: { !$0.isComputerControlled }) ?? party.first {
                    char.takeDamage(1)
                    printWrapped("\(char.name) takes 1 damage.", indent: 4, color: .red)
                    print("")
                }
            }
            logEvent("Dark search mishap in \(room.name)", category: "EXPLORE")
        }

        if hasHiddenLoot && total >= 18 {
            // Success despite the darkness!
            printWrapped("...against the odds, your fingers close around something!", indent: 2, color: .brightGreen)
            print("")

            if !room.hiddenItems.isEmpty {
                let item = room.hiddenItems.removeFirst()
                printWrapped("Found in the dark: \(item.name)!", indent: 4, color: .brightGreen)
                logEvent("Dark search found \(item.name) in \(room.name)", category: "EXPLORE")
                showItemPickupMenu(item: item, source: "Found in the dark") { [weak self] in
                    self?.showExplorationView()
                }
                return
            } else if room.hiddenGold > 0 {
                let gold = room.hiddenGold
                room.hiddenGold = 0
                printWrapped("Your hand closes on coins: \(gold) gold!", indent: 4, color: .yellow)
                logEvent("Dark search found \(gold) gold in \(room.name)", category: "EXPLORE")
                showGoldPickupMenu(gold: gold, source: "Found in the dark") { [weak self] in
                    self?.showExplorationView()
                }
                return
            }
        } else if hasHiddenLoot {
            printWrapped("...you feel around but can't find anything useful in this darkness.", indent: 2, color: .dimGreen)
            logEvent("Dark search failed in \(room.name)", category: "EXPLORE")
        } else {
            printWrapped("...you grope around blindly. There's nothing here.", indent: 2, color: .dimGreen)
            logEvent("Dark search — nothing to find in \(room.name)", category: "EXPLORE")
        }

        autoReturn()
    }

    /// Long-press Examine in the dark — risky fumbling examination
    private func darkExamine() {
        guard let room = dungeon?.currentRoom else { return }

        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        advanceTime(10)

        printWrapped("You grope around in the darkness, trying to make sense of this place...", indent: 2, color: .gray)
        print("")

        // 40% chance of a mishap / encounter
        let mishapRoll = Int.random(in: 1...100)
        if mishapRoll <= 20 {
            let mishaps = [
                "You knock something over. It shatters loudly. Hopefully nothing heard that.",
                "Your hand finds something sharp. You pull back, finger bleeding. (-1 HP)",
                "You trip over debris and land face-first in dust. Coughing echoes down the corridor.",
                "Something cold and wet drips on your neck. You'd rather not know what.",
            ]
            let mishap = mishaps.randomElement()!
            printWrapped(mishap, indent: 2, color: .yellow)
            if mishap.contains("-1 HP") {
                if let char = party.first(where: { !$0.isComputerControlled }) ?? party.first {
                    char.takeDamage(1)
                    printWrapped("\(char.name) takes 1 damage.", indent: 4, color: .red)
                }
            }
            print("")
        }

        // Harder check — 30% chance of learning something vs normal examine
        let roll = Dice.d20()
        let bestPerception = party.map { $0.skillModifier(for: .perception) }.max() ?? 0
        let total = roll + bestPerception

        if total >= 16 {
            let hints = [
                "By touch alone, you piece together the room's layout. It was once a \(room.roomType.rawValue.lowercased()).",
                "Your fingers trace carvings on the wall. You can't read them, but you sense their age.",
                "The air here is different — drier, warmer. Something important was kept here.",
                "You feel marks on the floor. Many feet have passed through here. Some recently.",
            ]
            printWrapped(hints.randomElement()!, indent: 2, color: .yellow)
        } else {
            printWrapped("In the darkness, you can barely tell which way is up. You learn nothing useful.", indent: 2, color: .dimGreen)
        }

        logEvent("Dark examine in \(room.name)", category: "EXPLORE")

        autoReturn()
    }

    /// Long-press Supplies in the dark — risky blind foraging
    private func darkForage() {
        guard let room = dungeon?.currentRoom else { return }

        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        advanceTime(15)
        room.searchedFor.insert("foraged")

        printWrapped("You scrabble around in the dark, feeling for anything useful...", indent: 2, color: .gray)
        print("")

        // 25% mishap chance
        let mishapRoll = Int.random(in: 1...100)
        if mishapRoll <= 25 {
            let mishaps = [
                "You grab something that wriggles. You drop it hastily.",
                "A pile of debris collapses on your foot. Ouch!",
                "You put your hand in something slimy. It stinks.",
                "Something skitters over your hand. You freeze, then it's gone.",
            ]
            printWrapped(mishaps.randomElement()!, indent: 2, color: .yellow)
            print("")
        }

        // Much lower chance of finding anything (15% vs normal ~35-45%)
        let roll = Int.random(in: 1...100)
        if roll <= 15 {
            // Found something basic
            let item = ItemCatalog.torch()
            printWrapped("...your hand closes on something familiar. A torch!", indent: 2, color: .brightGreen)
            logEvent("Dark forage found torch in \(room.name)", category: "EXPLORE")
            showItemPickupMenu(item: item, source: "Found in the dark") { [weak self] in
                self?.showExplorationView()
            }
            return
        } else {
            printWrapped("You find nothing but dust and debris. Hard to forage without light.", indent: 2, color: .dimGreen)
            logEvent("Dark forage — nothing found in \(room.name)", category: "EXPLORE")
        }

        autoReturn()
    }

    /// Thematic description of where an item was found, based on room type
    private func searchSourceDescription(for roomType: RoomType) -> String {
        switch roomType {
        case .armory:
            return ["Behind a weapon rack", "Under a fallen shield", "In a rusted locker",
                    "Beneath a pile of broken blades"].randomElement()!
        case .library:
            return ["Hidden behind old tomes", "In a scholar's desk drawer", "Tucked inside a hollowed book",
                    "Under a pile of scrolls"].randomElement()!
        case .shrine:
            return ["At the base of the altar", "In a prayer niche", "Behind a sacred tapestry",
                    "Inside a reliquary"].randomElement()!
        case .prison:
            return ["Hidden in a loose stone", "Under a pile of straw", "Wedged between iron bars",
                    "In a prisoner's hollow boot"].randomElement()!
        case .treasure:
            return ["In a hidden compartment", "Behind a false wall panel", "Under the main hoard",
                    "Inside a locked chest"].randomElement()!
        case .chamber:
            return ["In a crack in the wall", "Behind a fallen pillar", "Under broken furniture",
                    "In a dusty corner"].randomElement()!
        case .corridor:
            return ["In a gap between stones", "Behind a loose brick", "Wedged in a wall crack"].randomElement()!
        case .trap:
            return ["Near the trap mechanism", "Hidden by the trap builder", "In a maintenance alcove"].randomElement()!
        default:
            return "Hidden stash"
        }
    }

    /// Thematic hint when search fails but items remain
    private func searchFailHints(for roomType: RoomType) -> String {
        switch roomType {
        case .armory:
            return ["You don't find anything yet, but some of these weapon racks look like they have false backs...",
                    "Nothing this time, but you notice scratches near one of the armour stands...",
                    "You come up empty, but something glints in the shadows of the armoury..."].randomElement()!
        case .library:
            return ["You don't find anything, but some of these books look like they could be hiding something...",
                    "Nothing yet, but you notice a desk drawer that seems stuck — worth another look...",
                    "You come up empty, but a hollow sound from one of the shelves catches your attention..."].randomElement()!
        case .shrine:
            return ["You don't find anything, but the altar has carvings that might conceal a compartment...",
                    "Nothing yet, but there's a loose flagstone near the shrine...",
                    "You come up empty, but a faint shimmer near the offering bowl draws your eye..."].randomElement()!
        case .prison:
            return ["You don't find anything, but some of these stones look loose...",
                    "Nothing yet, but there are scratch marks near one of the cells — a hiding spot?",
                    "You come up empty, but a pile of straw in the corner looks recently disturbed..."].randomElement()!
        case .treasure:
            return ["You don't find anything more, but this room clearly held great wealth — there may be hidden compartments...",
                    "Nothing yet, but the walls have suspicious seams...",
                    "You come up empty, but you suspect a false panel nearby..."].randomElement()!
        case .chamber:
            return ["You don't find anything, but the room is large — there may be something you missed...",
                    "Nothing this time, but a draught from the walls suggests a hidden space...",
                    "You come up empty, though something in the shadows catches your eye..."].randomElement()!
        default:
            return ["You don't find anything, but you suspect there may still be something here...",
                    "Nothing this time. Still, something about this room nags at you...",
                    "You come up empty, but your instincts say there's more to find..."].randomElement()!
        }
    }

    // MARK: - Listen at Doors

    private func listenAtDoors() {
        guard let room = dungeon?.currentRoom, let dungeon = dungeon else { return }

        clearTerminal()
        printExplorationMap()
        print("")

        advanceTime(5)

        // Perception check — d20 + best perception vs DC 12
        let roll = Dice.d20()
        let bestPerception = party.map { $0.skillModifier(for: .perception) }.max() ?? 0
        // Bonus +2 in the dark (ears sharpen)
        let darkBonus = torchLit ? 0 : 2
        let total = roll + bestPerception + darkBonus

        SoundManager.shared.playListenStart()
        printWrapped("You press your ear to the cold stone...", indent: 2, color: .cyan)
        print("")

        if total >= 12 {
            // Success — reveal adjacent room hints with foley sounds
            var heard: [(text: String, sound: () -> Void)] = []
            for (direction, roomId) in room.exits {
                guard let adjRoom = dungeon.rooms[roomId] else { continue }
                let hint: String
                let sfx: () -> Void
                if adjRoom.roomType == .boss {
                    hint = "Something massive stirs to the \(direction.rawValue.lowercased()). Best prepare."
                    sfx = { SoundManager.shared.playListenBoss() }
                } else if adjRoom.encounter != nil && !adjRoom.cleared {
                    let sounds = [
                        ("Growling to the \(direction.rawValue.lowercased()).", { SoundManager.shared.playListenGrowl() }),
                        ("Scraping claws to the \(direction.rawValue.lowercased()).", { SoundManager.shared.playListenScraping() }),
                        ("Heavy breathing from the \(direction.rawValue.lowercased()).", { SoundManager.shared.playListenBreathing() }),
                        ("Movement to the \(direction.rawValue.lowercased()).", { SoundManager.shared.playListenScraping() }),
                    ]
                    let pick = sounds.randomElement()!
                    hint = pick.0; sfx = pick.1
                } else if adjRoom.roomType == .treasure || adjRoom.hiddenGold > 0 {
                    hint = "The clink of coins to the \(direction.rawValue.lowercased())."
                    sfx = { SoundManager.shared.playListenCoins() }
                } else if adjRoom.roomType == .shop {
                    hint = "Someone humming a tune to the \(direction.rawValue.lowercased())."
                    sfx = { SoundManager.shared.playListenHumming() }
                } else if adjRoom.npc != nil {
                    hint = "A voice murmuring to the \(direction.rawValue.lowercased())."
                    sfx = { SoundManager.shared.playListenHumming() }
                } else if adjRoom.roomType == .trap && !adjRoom.trapTriggered {
                    hint = "A faint clicking sound to the \(direction.rawValue.lowercased())."
                    sfx = { SoundManager.shared.playListenClicking() }
                } else {
                    hint = "Silence to the \(direction.rawValue.lowercased())."
                    sfx = { SoundManager.shared.playListenSilence() }
                }
                heard.append((hint, sfx))
            }

            // Play the most interesting sound heard
            if let bestSound = heard.first(where: { !$0.text.hasPrefix("Silence") }) ?? heard.first {
                bestSound.sound()
            }

            for h in heard {
                printWrapped("  \(h.text)", indent: 2, color: .yellow)
            }
            if !torchLit {
                print("")
                printWrapped("(Your hearing is keener in the dark.)", indent: 2, color: .dimGreen)
            }
            logEvent("Listened at doors in \(room.name) — heard \(heard.count) sounds", category: "EXPLORE")
        } else {
            SoundManager.shared.playListenHeartbeat()
            printWrapped("You press your ear to the stone... nothing. Just your own heartbeat.", indent: 2, color: .dimGreen)
            logEvent("Listened at doors in \(room.name) — heard nothing", category: "EXPLORE")
        }
        logMultiplayerAction("Listened at doors in \(room.name)")

        autoReturn()
    }

    // MARK: - Examine Room

    private func examineRoom() {
        guard let room = dungeon?.currentRoom, let dungeon = dungeon else { return }

        clearTerminal()
        printExplorationMap()
        print("")

        advanceTime(10)

        printWrapped("You examine the \(room.name.lowercased()) closely...", indent: 2, color: .cyan)
        print("")

        // Room-type-specific interactions
        switch room.roomType {
        case .library:
            let outcomes = [
                ("You find a faded journal hinting at the dungeon's history. Ancient builders feared what they awoke below.", TerminalColor.yellow, false),
                ("A scroll tucked between the books catches your eye — it describes a warding spell.", TerminalColor.brightGreen, false),
                ("The books are mostly ruined, but one contains a partial map of this level.", TerminalColor.yellow, false),
                ("You decipher an old text. It warns: 'The deeper chambers hold treasures guarded by the restless dead.'", TerminalColor.yellow, false),
            ]
            let (text, color, _) = outcomes.randomElement()!
            printWrapped(text, indent: 2, color: color)

        case .shrine:
            let roll = Dice.d20()
            if roll >= 10 {
                printWrapped("You study the altar and feel a warmth flow through you. A blessing!", indent: 2, color: .brightGreen)
                printWrapped("(+1 to your next roll)", indent: 2, color: .yellow)
                // Apply a minor blessing — store in status message
                explorationStatusMessage = ("Blessed: +1 to next roll", .yellow)
            } else {
                printWrapped("The shrine feels cold and unwelcoming. A sense of unease settles over you.", indent: 2, color: .dimGreen)
            }

        case .armory:
            let outcomes = [
                "You inspect the weapon racks. Most are broken, but the metalwork suggests skilled craftsmanship.",
                "The armour stands are mostly empty. Scratch marks suggest the contents were taken in haste.",
                "You find a whetstone wedged behind a rack. Could be useful for sharpening blades.",
                "Dents in the wall suggest training dummies once stood here. This was a practice hall.",
            ]
            printWrapped(outcomes.randomElement()!, indent: 2, color: .yellow)

        case .prison:
            let outcomes = [
                "The cells are empty now, but scratches on the walls tell stories of desperate prisoners.",
                "You find names carved into the stone. Some are centuries old.",
                "One cell door hangs open. The lock was picked from the inside — someone escaped.",
                "Bones lie in the corner of one cell. Whatever was here did not escape.",
            ]
            printWrapped(outcomes.randomElement()!, indent: 2, color: .yellow)

        case .trap:
            if room.trapTriggered {
                printWrapped("You study the sprung trap mechanism carefully. You learn to spot the telltale signs.", indent: 2, color: .brightGreen)
                printWrapped("(+2 to Perception checks for traps ahead)", indent: 2, color: .yellow)
            } else {
                printWrapped("The room looks ordinary, but something feels off. Best to tread carefully.", indent: 2, color: .dimGreen)
            }

        case .treasure:
            printWrapped("The room was clearly a vault. Empty mounting hooks line the walls, and lock mechanisms are built into the floor.", indent: 2, color: .yellow)

        case .boss:
            printWrapped("The air is heavy here. Something powerful has claimed this space. The walls bear claw marks far larger than any you've seen.", indent: 2, color: .red)

        case .shop:
            printWrapped("A makeshift market stall. Whoever runs this place has carved out a surprisingly cosy corner of the dungeon.", indent: 2, color: .yellow)

        default:
            let generic = [
                "The walls are damp and cold. Faded carvings hint at the room's former purpose.",
                "You notice old torch sconces along the walls. This corridor was once well-lit.",
                "Dust lies thick on every surface. No one has passed through here in some time.",
                "The stonework here is cruder than elsewhere — a later addition to the dungeon.",
                "You spot faint footprints in the dust. Something has been here recently.",
            ]
            printWrapped(generic.randomElement()!, indent: 2, color: .yellow)
        }

        logEvent("Examined \(room.name)", category: "EXPLORE")
        logMultiplayerAction("Examined \(room.name)")

        autoReturn()
    }

    // MARK: - Secure Room

    private func secureRoom() {
        guard let room = dungeon?.currentRoom, let dungeon = dungeon else { return }

        clearTerminal()
        printExplorationMap()
        print("")
        printSubtitle("Secure Exits")

        // Show current secured status
        let allExits = room.exits.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        for (dir, _) in allExits {
            let isSecured = room.secured.contains(dir)
            let icon = isSecured ? "🔒" : "🚪"
            let status = isSecured ? "Secured" : "Open"
            let color: TerminalColor = isSecured ? .brightGreen : .dimGreen
            print("  \(icon) \(dir.rawValue): \(status)", color: color)
        }
        print("")

        // Build options: secure unsecured doors, unsecure secured doors
        var options: [String] = []
        var actions: [() -> Void] = []

        let unsecuredExits = allExits.filter { !room.secured.contains($0.key) }
        let securedExits = allExits.filter { room.secured.contains($0.key) }

        for (dir, _) in unsecuredExits {
            options.append("Secure \(dir.rawValue)")
            actions.append { [weak self] in
                guard let self = self else { return }
                room.secured.insert(dir)
                self.advanceTime(5)
                self.logEvent("Secured \(dir.rawValue) exit in \(room.name)", category: "EXPLORE")
                self.logMultiplayerAction("Secured \(dir.rawValue) door in \(room.name)")
                self.secureRoom()  // Refresh the screen
            }
        }

        for (dir, _) in securedExits {
            options.append("Open \(dir.rawValue)")
            actions.append { [weak self] in
                guard let self = self else { return }
                room.secured.remove(dir)
                self.advanceTime(3)
                self.logEvent("Unsecured \(dir.rawValue) exit in \(room.name)", category: "EXPLORE")
                self.secureRoom()  // Refresh the screen
            }
        }

        options.append("Help")
        actions.append { [weak self] in self?.showSecureHelp() }

        showMenu(options)

        closeHandler = { [weak self] in self?.showExplorationView() }
        menuHandler = { choice in
            if choice >= 1 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showSecureHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Secure Help")
        print("")
        print("  SECURING EXITS", color: .cyan, bold: true)
        printWrapped("Barricade a door with debris to prevent monsters from entering through it. Secured exits show XX on the map.", indent: 2, color: .green)
        print("")
        print("  WHY SECURE?", color: .cyan, bold: true)
        printWrapped("Securing a door before resting reduces the chance of a random encounter. It also prevents monsters in adjacent rooms from surprising you.", indent: 2, color: .dimGreen)
        print("")
        print("  REOPENING", color: .cyan, bold: true)
        printWrapped("You can reopen a secured door at any time. You'll need to unsecure it before you can travel through it.", indent: 2, color: .dimGreen)
        print("")
        printInputHelp()

        waitForContinue()
        inputHandler = { [weak self] _ in self?.secureRoom() }
    }

    // MARK: - Forage Supplies

    private func forageSupplies() {
        guard let room = dungeon?.currentRoom, let dungeon = dungeon else { return }

        // Already scavenged this room
        if room.searchedFor.contains("foraged") {
            clearTerminal()
            printExplorationMap()
            print("")
            printWrapped("You've already scavenged this room — nothing left to find.", indent: 2, color: .yellow)
            autoReturn()
            return
        }

        clearTerminal()
        printExplorationMap()
        print("")

        advanceTime(15)
        room.searchedFor.insert("foraged")

        printWrapped("You scavenge the \(room.name.lowercased()) for useful supplies...", indent: 2, color: .cyan)
        print("")

        // Room-type-specific foraging
        var foundItem: Item? = nil
        var foundGold = 0
        var flavourText = ""

        switch room.roomType {
        case .library:
            let roll = Int.random(in: 1...100)
            if roll <= 40 {
                foundItem = Item(id: UUID(), name: "Ink & Parchment", description: "Valuable writing supplies.",
                                 type: .misc, weight: 0.5, value: 15, weaponStats: nil, armorStats: nil, potionStats: nil)
                flavourText = "You salvage some ink and usable parchment from the shelves."
            } else {
                flavourText = "The books are too damaged to salvage, but the knowledge lingers."
            }

        case .shrine:
            let roll = Int.random(in: 1...100)
            if roll <= 35 {
                foundItem = Item(id: UUID(), name: "Holy Water", description: "Blessed water. Bonus damage vs undead.",
                                 type: .misc, weight: 1.0, value: 25, weaponStats: nil, armorStats: nil, potionStats: nil)
                flavourText = "You fill a vial from the blessed font at the altar."
            } else {
                flavourText = "The shrine's offerings have long since been taken."
            }

        case .armory:
            let roll = Int.random(in: 1...100)
            if roll <= 45 {
                let supplies = [
                    Item(id: UUID(), name: "Whetstone", description: "Sharpens blades.",
                         type: .misc, weight: 1.0, value: 5, weaponStats: nil, armorStats: nil, potionStats: nil),
                ]
                foundItem = supplies.randomElement()!
                flavourText = "You find a usable whetstone among the debris."
            } else {
                flavourText = "The armoury has been picked clean. Nothing useful remains."
            }

        case .prison:
            let roll = Int.random(in: 1...100)
            if roll <= 40 {
                foundItem = ItemCatalog.thievesTools()
                flavourText = "You find a set of lockpicks hidden in a cell wall crack."
            } else {
                flavourText = "The cells yield nothing but despair."
            }

        default:
            let roll = Int.random(in: 1...100)
            if roll <= 30 {
                let genericSupplies: [() -> Item] = [ItemCatalog.torch, ItemCatalog.rope]
                foundItem = genericSupplies.randomElement()!()
                flavourText = "You scavenge something useful from the debris."
            } else if roll <= 45 {
                foundGold = Int.random(in: 1...8)
                flavourText = "You find \(foundGold) gold coins lodged in a crack."
            } else {
                flavourText = "You search thoroughly but find nothing worth taking."
            }
        }

        printWrapped(flavourText, indent: 2, color: foundItem != nil || foundGold > 0 ? .brightGreen : .dimGreen)

        if let item = foundItem {
            let source = "Foraged in \(room.name)"
            logEvent("Foraged \(item.name) in \(room.name)", category: "EXPLORE")
            logMultiplayerAction("Foraged supplies in \(room.name)")
            showItemPickupMenu(item: item, source: source) { [weak self] in
                self?.showExplorationView()
            }
            return
        } else if foundGold > 0 {
            let source = "Foraged in \(room.name)"
            logEvent("Foraged \(foundGold) gold in \(room.name)", category: "EXPLORE")
            logMultiplayerAction("Foraged supplies in \(room.name)")
            showGoldPickupMenu(gold: foundGold, source: source) { [weak self] in
                self?.showExplorationView()
            }
            return
        }

        logEvent("Foraged \(room.name) — nothing found", category: "EXPLORE")
        logMultiplayerAction("Foraged supplies in \(room.name)")

        autoReturn()
    }

    // MARK: - Talk to NPC

    private func talkToNPC() {
        guard let room = dungeon?.currentRoom, var npc = room.npc, let dungeon = dungeon else { return }

        clearTerminal()
        printExplorationMap()
        print("")

        // Show NPC art and info
        printLines(npc.type.asciiArt, color: .cyan)
        print("")
        print("  \(npc.type.rawValue)", color: .brightGreen, bold: true)
        printWrapped(npc.type.description, indent: 2, color: .dimGreen)
        print("")

        // Assign a voice to this NPC if they don't have one yet
        if npc.voiceIdentifier == nil {
            let charNames = party.map { $0.name }
            npc.voiceIdentifier = SpeechEngine.shared.pickNPCVoice(excludingCharacterNames: charNames)
        }

        // Greeting (first time)
        if !npc.hasBeenTalkedTo {
            let greeting = npc.type == .gatekeeper
                ? npc.type.gatekeeperGreeting(trustworthiness: npc.trustworthiness)
                : npc.type.greeting
            printWrapped("\"\(greeting)\"", indent: 2, color: .yellow)
            print("")
            npc.hasBeenTalkedTo = true
            room.npc = npc
            recordNPCEncounter(npc.type)
            logEvent("Met \(npc.type.rawValue) in \(room.name)", category: "NPC")
            // Speak greeting in NPC's voice — mark page as read so auto-read doesn't repeat
            if speakerModeOn, let voiceId = npc.voiceIdentifier {
                speakerHasReadCurrentPage = true
                SpeechEngine.shared.speakAsNPC(greeting, voiceId: voiceId)
            }
        } else {
            let returnGreetings = [
                "\"Back again? What do you need?\"",
                "\"Ah, you return. Ask away.\"",
                "\"Yes? I'm still here.\"",
            ]
            let greet = returnGreetings.randomElement()!
            printWrapped(greet, indent: 2, color: .yellow)
            print("")
            if speakerModeOn, let voiceId = npc.voiceIdentifier {
                speakerHasReadCurrentPage = true
                let cleanGreet = greet.replacingOccurrences(of: "\"", with: "")
                SpeechEngine.shared.speakAsNPC(cleanGreet, voiceId: voiceId)
            }
        }

        // Build capability menu
        var options: [MenuOption] = []
        var actions: [() -> Void] = []

        // Topic buttons
        for topic in npc.type.knownTopics {
            options.append(MenuOption("Ask: \(topic)", tint: .amber))
            actions.append { [weak self] in
                self?.askNPCAbout(topic: topic)
            }
        }

        // Capability buttons
        if npc.type.canTrade && !npc.hasTraded {
            options.append(MenuOption("Trade", tint: .cyan))
            actions.append { [weak self] in self?.tradeWithNPC() }
        }

        if npc.type.canHeal {
            options.append(MenuOption("Request Healing", tint: .cyan))
            actions.append { [weak self] in self?.requestNPCHealing() }
        }

        if npc.type.canRepair {
            options.append(MenuOption("Repair Gear", tint: .cyan))
            actions.append { [weak self] in self?.requestNPCRepair() }
        }

        if npc.type.canTeach && !npc.hasTaught {
            options.append(MenuOption("Learn", tint: .cyan))
            actions.append { [weak self] in self?.learnFromNPC() }
        }

        if npc.type.canCurePoison {
            let hasPoisoned = party.contains { $0.isPoisoned }
            if hasPoisoned {
                options.append(MenuOption("Cure Poison", tint: .cyan))
                actions.append { [weak self] in self?.requestNPCCurePoison() }
            }
        }

        showMenuOptions(options)
        closeHandler = { [weak self] in
            self?.showExplorationView()
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func askNPCAbout(topic: String) {
        guard let room = dungeon?.currentRoom, var npc = room.npc else { return }

        // Gatekeeper quest acceptance flow
        if npc.type == .gatekeeper && topic == "Quest" && !npc.questAccepted {
            showGatekeeperQuest(npc: npc, room: room)
            return
        }

        // Track how many times this topic has been asked
        let askCount = npc.recordAsk(topic: topic)
        room.npc = npc

        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        printLines(npc.type.asciiArt, color: .cyan)
        print("")
        print("  \(npc.type.rawValue)", color: .brightGreen, bold: true)
        print("")

        let bossType = dungeon?.rooms.values.first(where: { $0.roomType == .boss })?.encounter?.monsters.first?.type

        // Build context from actual dungeon state
        var ctx = NPCType.DungeonContext()
        if let dungeon = dungeon {
            ctx.totalRooms = dungeon.rooms.count
            ctx.clearedRooms = dungeon.rooms.values.filter { $0.cleared || $0.encounter == nil }.count
            for (_, adjId) in room.exits {
                if let adj = dungeon.rooms[adjId] {
                    if let enc = adj.encounter, !adj.cleared {
                        ctx.adjacentMonsterCount += 1
                        for m in enc.monsters {
                            if !ctx.adjacentMonsterNames.contains(m.name) {
                                ctx.adjacentMonsterNames.append(m.name)
                            }
                        }
                    }
                    if adj.roomType == .trap && !adj.trapTriggered { ctx.nearbyTrapCount += 1 }
                    if adj.roomType == .treasure { ctx.nearbyTreasureRooms += 1 }
                    if adj.roomType == .boss { ctx.bossDirection = room.exits.first(where: { $0.value == adjId })?.key.rawValue }
                    if adj.roomType == .shop { ctx.hasShop = true }
                }
            }
        }

        let response: String
        if npc.type == .gatekeeper {
            if topic == "Quest" && npc.questAccepted {
                response = "Your quest is underway. Slay the creature in the depths and return for your \(npc.questGold) gold reward."
            } else {
                response = npc.type.gatekeeperResponse(for: topic, trustworthiness: npc.trustworthiness, dungeonLevel: dungeon?.level ?? 1, bossType: bossType, questGold: npc.questGold, askCount: askCount)
            }
        } else {
            response = npc.type.response(for: topic, dungeonLevel: dungeon?.level ?? 1, bossType: bossType, context: ctx, askCount: askCount)
        }
        printWrapped("\"\(response)\"", indent: 2, color: .yellow)
        print("")

        // Speak response in NPC's voice — mark page as read so auto-read doesn't repeat
        if speakerModeOn, let voiceId = npc.voiceIdentifier {
            speakerHasReadCurrentPage = true
            SpeechEngine.shared.speakAsNPC(response, voiceId: voiceId)
        }

        logEvent("Asked \(npc.type.rawValue) about \(topic)", category: "NPC")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.talkToNPC()
        }
    }

    private func showGatekeeperQuest(npc: DungeonNPC, room: Room) {
        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        printLines(npc.type.asciiArt, color: .cyan)
        print("")
        print("  \(npc.type.rawValue)", color: .brightGreen, bold: true)
        print("")

        let bossType = dungeon?.rooms.values.first(where: { $0.roomType == .boss })?.encounter?.monsters.first?.type
        let questText = npc.type.gatekeeperResponse(for: "Quest", trustworthiness: npc.trustworthiness, dungeonLevel: dungeon?.level ?? 1, bossType: bossType, questGold: npc.questGold)
        printWrapped("\"\(questText)\"", indent: 2, color: .yellow)
        print("")
        print("  Quest: Slay the dungeon boss", color: .cyan)
        print("  Reward: \(npc.questGold) gold", color: .brightGreen)
        print("")

        showMenu(["Accept Quest", "Decline"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                var updatedNPC = npc
                updatedNPC.questAccepted = true
                room.npc = updatedNPC
                self.clearTerminal()
                if let dungeon = self.dungeon {
                    self.printExplorationMap()
                    self.print("")
                }
                self.printLines(npc.type.asciiArt, color: .cyan)
                self.print("")
                self.printWrapped("\"Good. May fortune favour you. Return when the deed is done.\"", indent: 2, color: .yellow)
                self.logEvent("Accepted quest from Gatekeeper: slay boss for \(npc.questGold) gold", category: "QUEST")
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in self?.talkToNPC() }
            } else {
                self.talkToNPC()
            }
        }
        closeHandler = { [weak self] in self?.talkToNPC() }
    }

    private func tradeWithNPC() {
        guard let room = dungeon?.currentRoom, var npc = room.npc, let dungeon = dungeon else { return }

        // Open the shop with NPC-specific inventory
        pickCharacter(title: "Who trades with the \(npc.type.rawValue)?") { [weak self] character in
            guard let self = self else { return }
            self.shopEngine.openShop(character: character, dungeonLevel: dungeon.level) { [weak self] in
                npc.hasTraded = true
                room.npc = npc
                self?.talkToNPC()
            }
        }
    }

    private func requestNPCHealing() {
        guard let room = dungeon?.currentRoom, let npc = room.npc else { return }

        let isFree = npc.type == .oldPriestess
        let cost = isFree ? 0 : 15

        pickCharacter(title: "Who receives healing?") { [weak self] character in
            guard let self = self else { return }

            self.clearTerminal()
            if let dungeon = self.dungeon {
                self.printExplorationMap()
                self.print("")
            }

            if character.currentHP >= character.maxHP {
                self.printWrapped("\"\(character.name) is already in full health. Save my aid for when you truly need it.\"", indent: 2, color: .yellow)
            } else if !isFree && character.gold < cost {
                self.printWrapped("\"I need \(cost) gold for my services. Come back when you can afford it.\"", indent: 2, color: .yellow)
            } else {
                if !isFree { character.gold -= cost }
                let healAmount = Dice.rollDamage("2d4+2").total
                character.heal(healAmount)
                self.printWrapped("The \(npc.type.rawValue) tends to \(character.name)'s wounds.", indent: 2, color: .cyan)
                self.print("")
                self.printWrapped("\(character.name) heals \(healAmount) HP!\(isFree ? "" : " (-\(cost) gold)")", indent: 2, color: .brightGreen)
                self.logEvent("\(npc.type.rawValue) healed \(character.name) for \(healAmount) HP", category: "NPC")
            }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.talkToNPC()
            }
        }
    }

    private func requestNPCRepair() {
        guard let room = dungeon?.currentRoom, let npc = room.npc else { return }
        let cost = 20

        pickCharacter(title: "Who pays for repairs?") { [weak self] character in
            guard let self = self else { return }

            self.clearTerminal()
            if let dungeon = self.dungeon {
                self.printExplorationMap()
                self.print("")
            }

            if character.gold < cost {
                self.printWrapped("\"Repairs cost \(cost) gold. \(character.name) hasn't got enough. Come back with coin!\"", indent: 2, color: .yellow)
            } else {
                character.gold -= cost
                self.printWrapped("The \(npc.type.rawValue) hammers away at your equipment.", indent: 2, color: .cyan)
                self.print("")
                self.printWrapped("\"Good as new! Well, almost. That'll be \(cost) gold.\"", indent: 2, color: .yellow)
                self.logEvent("\(npc.type.rawValue) repaired gear for \(character.name) (-\(cost) gold)", category: "NPC")
            }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.talkToNPC()
            }
        }
    }

    private func learnFromNPC() {
        guard let room = dungeon?.currentRoom, var npc = room.npc else { return }

        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        npc.hasTaught = true
        room.npc = npc

        let desc = npc.type.teachingDescription
        printWrapped(desc, indent: 2, color: .brightGreen)
        logEvent("Learned from \(npc.type.rawValue): \(desc)", category: "NPC")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.talkToNPC()
        }
    }

    private func requestNPCCurePoison() {
        guard let room = dungeon?.currentRoom, let npc = room.npc else { return }

        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        let poisoned = party.filter { $0.isPoisoned }
        if poisoned.isEmpty {
            printWrapped("\"None of your party is poisoned. Lucky you!\"", indent: 2, color: .yellow)
        } else {
            for char in poisoned {
                char.isPoisoned = false
                printWrapped("\(char.name)'s poison is cured!", indent: 2, color: .brightGreen)
            }
            printWrapped("\"The corruption is cleansed. Go carefully — not all venom can be drawn so easily.\"", indent: 2, color: .yellow)
            logEvent("\(npc.type.rawValue) cured poison for \(poisoned.count) party members", category: "NPC")
        }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.talkToNPC()
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
            printExplorationMap()
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
            logMultiplayerAction("Found treasure: \(itemNames.joined(separator: ", "))")
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

    /// Attempt to loot treasure in the dark — reduced success, chance of something unwanted
    func collectTreasureInDark() {
        guard let room = dungeon?.currentRoom, !room.treasure.isEmpty else {
            showExplorationView()
            return
        }

        clearTerminal()
        print("Fumbling in the Dark...", color: .gray, bold: true)
        print("")
        print("  You grope blindly for treasure...", color: .gray)
        print("")

        var totalGold = 0
        var pickableItems: [Item] = []
        var foundAnything = false

        for treasureItem in room.treasure {
            let roll = Int.random(in: 1...100)
            if roll <= 40 {
                // 40% chance: find nothing from this item
                continue
            } else if roll <= 55 {
                // 15% chance: something unwanted
                foundAnything = true
                let mishap = Int.random(in: 1...5)
                switch mishap {
                case 1:
                    print("  You grab something slimy! It wriggles away.", color: .red)
                    logEvent("Grabbed something slimy in the dark", category: "LOOT")
                case 2:
                    let dmg = Dice.rollSum(1, d: 4)
                    let victim = party.randomElement()!
                    victim.takeDamage(dmg)
                    print("  Ouch! You cut your hand on something sharp. (\(victim.name) -\(dmg) HP)", color: .red)
                    logEvent("\(victim.name) cut hand in the dark (-\(dmg) HP)", category: "LOOT")
                case 3:
                    print("  You knock something over — it shatters loudly!", color: .red)
                    print("  Monsters nearby may have heard that...", color: .yellow)
                    logEvent("Made noise fumbling in the dark", category: "LOOT")
                case 4:
                    print("  You grab a fistful of... dust and cobwebs.", color: .gray)
                case 5:
                    print("  Something skitters across your hand. You recoil!", color: .red)
                    logEvent("Something skittered across hand in dark", category: "LOOT")
                default: break
                }
            } else {
                // 45% chance: find it (reduced from 100%)
                foundAnything = true
                if treasureItem.type == .gold {
                    // Only find some of the gold
                    let portion = Int.random(in: 40...80)
                    let found = max(1, treasureItem.value * portion / 100)
                    totalGold += found
                    if found < treasureItem.value {
                        print("  You scoop up some coins — \(found)gp (some spilled!)", color: .yellow)
                    } else {
                        print("  You find \(found)gp!", color: .yellow)
                    }
                } else if treasureItem.type == .gem {
                    let gemItem = Item(id: UUID(), name: treasureItem.name,
                                       description: "A precious gem worth \(treasureItem.value)gp.",
                                       type: .gem, weight: 0.1, value: treasureItem.value,
                                       weaponStats: nil, armorStats: nil, potionStats: nil)
                    pickableItems.append(gemItem)
                    print("  You feel something smooth — a gem!", color: .brightGreen)
                } else if treasureItem.type == .potion || treasureItem.type == .item {
                    if let item = resolveItemByName(treasureItem.name) {
                        pickableItems.append(item)
                        print("  You grab something... a \(item.name)!", color: .brightGreen)
                    }
                }
            }
        }

        room.treasure.removeAll()

        if !foundAnything {
            print("  You fumble around but find nothing useful.", color: .gray)
            logEvent("Fumbled for treasure in the dark — found nothing", category: "LOOT")
        }

        print("")

        if totalGold > 0 || !pickableItems.isEmpty {
            waitForContinue()
            inputHandler = { [weak self] _ in
                self?.showLootSequence(gold: totalGold, goldSource: "Dark loot",
                                       items: pickableItems, itemSource: "Dark loot") { [weak self] in
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
    private func showItemPickupMenu(item: Item, source: String, narrative: String? = nil, onDone: @escaping () -> Void) {
        clearTerminal()

        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        if let narrative = narrative {
            for line in narrative.components(separatedBy: "\n") {
                printWrapped(line, indent: 2, color: .cyan)
            }
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

        if party.count > 1 {
            print("Who should pick up the \(item.name)?", color: .cyan)
        } else {
            print("What do you want to do with the \(item.name)?", color: .cyan)
        }
        print("")

        // Use combat-eligible characters if set, otherwise full party
        let eligible = combatLootEligible ?? party

        var options: [String] = []
        var actions: [() -> Void] = []

        // Pick up options — one per character for multi-party, or just "Pick Up"
        if eligible.count > 1 {
            for char in eligible {
                let canCarry = char.canCarry(item)
                let tag = canCarry ? "" : (char.isInventoryFull ? " [full]" : " [heavy]")
                options.append("Give to \(shortName(for: char))\(tag)")
                actions.append { [weak self] in
                    guard let self = self else { return }
                    if canCarry {
                        _ = char.addItem(item)
                        self.print("  \(char.name) takes the \(item.name).", color: .brightGreen)
                        self.logEvent("\(char.name) picked up \(item.name)", category: "LOOT")
                        self.waitForContinueWithTimeout { onDone() }
                    } else {
                        if char.isInventoryFull {
                            self.print("  \(char.name)'s bag is full! (\(char.inventory.count)/\(Character.maxInventorySlots))", color: .yellow)
                        } else {
                            self.print("  \(char.name) can't carry any more!", color: .yellow)
                        }
                        self.print("  Make room or choose someone else.", color: .dimGreen)
                        self.print("")
                        self.showMenu(["Inventory", "Choose Again", "Leave It"])
                        self.menuHandler = { [weak self] choice in
                            guard let self = self else { return }
                            if choice == 1 {
                                self.showInventoryFor(char, onBack: { [weak self] in
                                    self?.showItemPickupMenu(item: item, source: source, narrative: nil, onDone: onDone)
                                })
                            } else if choice == 2 {
                                self.showItemPickupMenu(item: item, source: source, narrative: nil, onDone: onDone)
                            } else {
                                // Drop on floor
                                if let room = self.dungeon?.currentRoom {
                                    room.droppedItems.append(item)
                                    self.print("  Left \(item.name) on the ground.", color: .dimGreen)
                                }
                                self.waitForContinueWithTimeout { onDone() }
                            }
                        }
                    }
                }
            }
        } else if let char = eligible.first ?? party.first {
            let canCarry = char.canCarry(item)
            let tag = canCarry ? "" : (char.isInventoryFull ? " [full]" : " [heavy]")
            options.append("Pick Up\(tag)")
            actions.append { [weak self] in
                guard let self = self else { return }
                if canCarry {
                    _ = char.addItem(item)
                    self.print("  \(char.name) takes the \(item.name).", color: .brightGreen)
                    self.logEvent("\(char.name) picked up \(item.name)", category: "LOOT")
                    self.waitForContinueWithTimeout { onDone() }
                } else {
                    if char.isInventoryFull {
                        self.print("  Bag is full! (\(char.inventory.count)/\(Character.maxInventorySlots))", color: .yellow)
                    } else {
                        self.print("  Too heavy to carry!", color: .yellow)
                    }
                    self.print("  Make room or leave it.", color: .dimGreen)
                    self.print("")
                    self.showMenu(["Inventory", "Try Again", "Leave It"])
                    self.menuHandler = { [weak self] choice in
                        guard let self = self else { return }
                        if choice == 1 {
                            self.showInventoryFor(char, onBack: { [weak self] in
                                self?.showItemPickupMenu(item: item, source: source, narrative: nil, onDone: onDone)
                            })
                        } else if choice == 2 {
                            self.showItemPickupMenu(item: item, source: source, narrative: nil, onDone: onDone)
                        } else {
                            if let room = self.dungeon?.currentRoom {
                                room.droppedItems.append(item)
                                self.print("  Left \(item.name) on the ground.", color: .dimGreen)
                            }
                            self.waitForContinueWithTimeout { onDone() }
                        }
                    }
                }
            }
        }

        // Equip option for weapon/armor/shield
        if item.type == .weapon || item.type == .armor || item.type == .shield {
            let label = item.type == .weapon ? "Equip" : (item.type == .shield ? "Equip Shield" : "Equip Armour")
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
                    self.print("  \(char.name) equips themselves with the \(item.name)!", color: .brightGreen)
                    self.logEvent("\(char.name) equipped \(item.name)", category: "LOOT")
                    self.waitForContinueWithTimeout { onDone() }
                }
                let equipEligible = self.combatLootEligible ?? self.party
                if equipEligible.count > 1 {
                    self.pickCharacter(title: "Who equips it?", from: equipEligible) { char in doEquip(char) }
                } else if let char = equipEligible.first {
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
                    self.waitForContinueWithTimeout { onDone() }
                }
                let useEligible = self.combatLootEligible ?? self.party
                if useEligible.count > 1 {
                    self.pickCharacter(title: "Who drinks it?", from: useEligible) { char in doUse(char) }
                } else if let char = useEligible.first {
                    doUse(char)
                }
            }
        }

        // Leave it — item stays in the room
        options.append("Leave It")
        actions.append { [weak self] in
            if let room = self?.dungeon?.currentRoom {
                room.droppedItems.append(item)
            }
            self?.print("  You leave the \(item.name) behind.", color: .dimGreen)
            self?.waitForContinueWithTimeout { onDone() }
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
    private func showGoldPickupMenu(gold: Int, source: String, narrative: String? = nil, onDone: @escaping () -> Void) {
        clearTerminal()

        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        if let narrative = narrative {
            for line in narrative.components(separatedBy: "\n") {
                printWrapped(line, indent: 2, color: .cyan)
            }
            print("")
        }

        printSubtitle("Found: \(gold) Gold Pieces")
        print("  \(source)", color: .dimGreen)
        print("")

        // Use combat-eligible characters if set, otherwise full party
        let eligible = combatLootEligible ?? party

        var options: [String] = []
        var actions: [() -> Void] = []

        if eligible.count > 1 {
            // Split equally
            let goldEach = gold / eligible.count
            let remainder = gold % eligible.count
            options.append("Split (\(goldEach)gp each)")
            actions.append { [weak self] in
                guard let self = self else { return }
                // Distribute remainder randomly one coin at a time
                var indices = Array(0..<eligible.count)
                indices.shuffle()
                for (i, char) in eligible.enumerated() {
                    let bonus = indices.firstIndex(of: i)! < remainder ? 1 : 0
                    char.gold += goldEach + bonus
                }
                if remainder > 0 {
                    self.print("  Gold split (\(goldEach)gp each, +\(remainder) extra spread around).", color: .yellow)
                } else {
                    self.print("  Gold split among the party (\(goldEach)gp each).", color: .yellow)
                }
                self.logEvent("Split \(gold) gold equally from \(source.lowercased())", category: "LOOT")
                self.logMultiplayerAction("Found \(gold) gold (\(source.lowercased()))")
                self.waitForContinueWithTimeout { onDone() }
            }

            // Give all to one character
            for char in eligible {
                options.append("\(shortName(for: char)) +\(gold)gp")
                actions.append { [weak self] in
                    char.gold += gold
                    self?.print("  \(char.name) takes all \(gold) gold.", color: .yellow)
                    self?.logEvent("\(char.name) took \(gold) gold from \(source.lowercased())", category: "LOOT")
                    self?.waitForContinueWithTimeout { onDone() }
                }
            }
        } else {
            // Solo — just pick up
            let char = eligible.first ?? party.first
            options.append("Take +\(gold)gp")
            actions.append { [weak self] in
                char?.gold += gold
                self?.print("  \(char?.name ?? "You") pocket\(char == nil ? "" : "s") \(gold) gold pieces.", color: .yellow)
                self?.logEvent("Picked up \(gold) gold from \(source.lowercased())", category: "LOOT")
                self?.waitForContinueWithTimeout { onDone() }
            }
        }

        // Leave it
        options.append("Leave It")
        actions.append { [weak self] in
            self?.print("  You leave \(gold) gold behind.", color: .dimGreen)
            self?.logEvent("Left \(gold) gold behind", category: "LOOT")
            self?.waitForContinueWithTimeout { onDone() }
        }

        showMenu(options)
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
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

    private func pickCharacter(title: String, from candidates: [Character]? = nil, onBack: (() -> Void)? = nil, action: @escaping (Character) -> Void) {
        let chars = candidates ?? party
        if chars.count == 1 {
            action(chars[0])
            return
        }

        clearTerminal()
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }
        printSubtitle(title)

        var options: [String] = []
        for char in chars {
            options.append("\(shortName(for: char)) \(char.currentHP)/\(char.maxHP)HP")
        }
        options.append("Done")

        showMenu(options)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == options.count {
                if let onBack = onBack { onBack() } else { self.showExplorationView() }
                return
            }
            guard choice > 0 && choice <= chars.count else { return }
            action(chars[choice - 1])
        }
    }

    func showInventory() {
        // Default to a random human-controlled character
        let humans = party.filter { !$0.isComputerControlled }
        let defaultChar = humans.randomElement() ?? party.first!
        let back: () -> Void = { [weak self] in self?.showExplorationView() }
        showInventoryFor(defaultChar, onBack: back)
    }

    private func showInventoryFor(_ character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        // Pack opening animation — only on first open per room
        let currentRoomId = dungeon?.currentRoom?.id
        if let roomId = currentRoomId, roomId != lastInventoryRoomId && !fromDM {
            lastInventoryRoomId = roomId
            showPackAnimation {
                self.renderInventory(character, onBack: onBack, fromDM: fromDM)
            }
            return
        }
        renderInventory(character, onBack: onBack, fromDM: fromDM)
    }

    private func showPackAnimation(completion: @escaping () -> Void) {
        clearTerminal()
        printExplorationMap()
        print("")

        let frames: [([String], TerminalColor)] = [
            (["    ╔════╗", "    ║▓▓▓▓║", "    ║▓▓▓▓║", "    ╚════╝"], .dimGreen),
            (["    ╔╗  ╔╗", "    ║ ╲╱ ║", "    ║    ║", "    ╚════╝"], .yellow),
            (["    ╔    ╗", "    ║ ⚔⚗ ║", "    ║ $$ ║", "    ╚════╝"], .orange),
        ]

        let artStart = terminalLines.count
        let firstFrame = frames[0].0
        printLines(firstFrame, color: frames[0].1)
        print("")

        var frameIndex = 1
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            DispatchQueue.main.async {
                if frameIndex < frames.count {
                    let (lines, color) = frames[frameIndex]
                    for (j, line) in lines.enumerated() {
                        let idx = artStart + j
                        if idx < self.terminalLines.count {
                            self.terminalLines[idx] = TerminalLine(line, color: color)
                        }
                    }
                    frameIndex += 1
                } else {
                    timer.invalidate()
                    completion()
                }
            }
        }
    }

    private func renderInventory(_ character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {

        clearTerminal()

        if let _ = dungeon {
            printExplorationMap()
            print("")
        }

        let playerCharId = isMultiplayer ? localCharacterId : party.first(where: { !$0.isComputerControlled })?.id
        let isOwnInventory = character.id == playerCharId
        let invName = character.isComputerControlled ? "R. \(character.name)" : character.name
        printTitle("Inventory — \(invName)", color: .orange)

        print("  Carry Weight: \(String(format: "%.0f", character.currentWeight)) / \(String(format: "%.0f", character.carryCapacity)) lb", color: character.isEncumbered ? .red : .cyan)
        print("  Gold: \(character.gold)", color: .yellow)
        // Torch status — show who holds the lit torch
        if torchLit, let holderId = torchHolderId {
            let holderName = party.first(where: { $0.id == holderId }).map { shortName(for: $0) } ?? "?"
            let activeTorch = activeTorchId.flatMap { tid in party.flatMap { $0.inventory }.first(where: { $0.id == tid }) }
            if character.id == holderId {
                // This character holds the torch
                if let desc = activeTorch?.torchLifeDescription {
                    print("  Torch: holding (lit, \(desc) left)", color: .orange)
                } else {
                    print("  Torch: holding (lit)", color: .orange)
                }
            } else {
                // Someone else has it
                print("  Torch: held by \(holderName)", color: .dimGreen)
            }
        } else {
            let charTorches = character.inventory.filter { $0.isTorch }
            if !charTorches.isEmpty {
                print("  Torch: unlit (\(charTorches.count) in bag)", color: .dimGreen)
            } else {
                let totalTorches = party.flatMap { $0.inventory }.filter { $0.isTorch }.count
                if totalTorches > 0 {
                    print("  Torch: none (party has \(totalTorches))", color: .dimGreen)
                } else {
                    print("  Torch: none", color: .dimGreen)
                }
            }
        }
        print("")

        print("  EQUIPPED:", color: .cyan, bold: true)
        print("    Weapon: \(character.equippedWeapon?.name ?? "(none)")", color: .brightGreen)
        print("    Armour:  \(character.equippedArmor?.name ?? "(none)")", color: .brightGreen)
        print("    Shield: \(character.equippedShield?.name ?? "(none)")", color: .brightGreen)
        print("")

        let slotColor: TerminalColor = character.isInventoryFull ? .red : .cyan
        print("  BAG (\(character.inventory.count)/\(Character.maxInventorySlots)):", color: slotColor, bold: true)
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
                let torchInfo: String
                if item.isTorch, let desc = item.torchLifeDescription {
                    let isActive = item.id == activeTorchId && torchLit
                    torchInfo = isActive ? " (\(desc) left, lit)" : " (\(desc) left)"
                } else {
                    torchInfo = ""
                }
                print("    \(tag) \(item.name)\(torchInfo) — \(String(format: "%.1f", item.weight))lb, \(item.value)gp", color: .green)
            }
        }
        print("")

        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        // Row 1: Equipment + Open Pack
        menuOpts.append(MenuOption("Equipment"))
        actions.append { [weak self] in self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM) }
        menuOpts.append(MenuOption("Open Pack", isDisabled: character.inventory.isEmpty))
        actions.append { [weak self] in self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM) }

        // Other party member packs (amber)
        if party.count > 1 {
            for other in party where other.id != character.id {
                let prefix = other.isComputerControlled ? "R." : ""
                menuOpts.append(MenuOption("\(prefix)\(shortName(for: other))'s Pack", tint: .amber))
                actions.append { [weak self] in
                    self?.showInventoryFor(other, onBack: onBack, fromDM: fromDM)
                }
            }
        }

        // Help
        menuOpts.append(MenuOption("Help"))
        actions.append { [weak self] in self?.showInventoryHelp(character: character, onBack: onBack, fromDM: fromDM) }

        // Cluster buttons by colour: normal first, then amber, then cyan
        let paired = zip(menuOpts, actions).map { ($0, $1) }
        let tintOrder: [MenuTint] = [.normal, .amber, .cyan, .danger, .navigation]
        let sorted = paired.sorted { a, b in
            let ai = tintOrder.firstIndex(of: a.0.tint) ?? 0
            let bi = tintOrder.firstIndex(of: b.0.tint) ?? 0
            return ai < bi
        }
        let sortedOpts = sorted.map { $0.0 }
        let sortedActions = sorted.map { $0.1 }

        showMenuOptions(sortedOpts)
        let backAction = onBack ?? { [weak self] in self?.showExplorationView() }
        closeHandler = { [weak self] in
            self?.closeHandler = nil
            backAction()
        }
        menuHandler = { choice in
            if choice > 0 && choice <= sortedActions.count {
                sortedActions[choice - 1]()
            }
        }
    }

    private func showInventoryHelp(character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Inventory — Help")
        print("")

        print("  OVERVIEW", color: .cyan, bold: true)
        printWrapped("Your inventory shows everything you're carrying: equipped gear, items in your pack, and your gold. Each character carries their own equipment.", indent: 2, color: .dimGreen)
        print("")

        print("  EQUIPPED GEAR", color: .cyan, bold: true)
        printWrapped("Weapon, Armour, and Shield slots show what you have equipped. Tap Equipment to change what's equipped from your pack. Equipping a new item swaps the old one back into your bag.", indent: 2, color: .dimGreen)
        print("")

        print("  BAG (PACK)", color: .cyan, bold: true)
        printWrapped("Your bag holds up to \(Character.maxInventorySlots) items. Item tags show type: [W] weapon, [A] armour, [S] shield, [P] potion, [?] scroll, [$] gem, [.] misc. Weight and gold value are shown for each item.", indent: 2, color: .dimGreen)
        print("")

        print("  OPEN PACK", color: .cyan, bold: true)
        printWrapped("Opens your bag to use potions, drop items, give items to party members, or inspect individual items in detail.", indent: 2, color: .dimGreen)
        print("")

        print("  CARRY WEIGHT", color: .cyan, bold: true)
        printWrapped("Each character can carry a limited weight based on their Strength score. If encumbered (over limit), movement and combat may be affected. Drop or give away items to lighten your load.", indent: 2, color: .dimGreen)
        print("")

        print("  PARTY PACKS", color: .cyan, bold: true)
        printWrapped("Tap a companion's pack to view their inventory. You can give items between party members using the Give option in Open Pack.", indent: 2, color: .dimGreen)
        print("")

        print("  TORCHES", color: .cyan, bold: true)
        printWrapped("Torches are vital for exploring. The inventory shows who holds the lit torch and how much burn time remains. Without a torch, searching and scavenging are much harder.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.renderInventory(character, onBack: onBack, fromDM: fromDM) }
    }

    private func showEquipMenu(character: Character, type: ItemType, label: String, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
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

        showPaginatedMenuOptions(options, pinned: ["Done"], handler: { [weak self] idx in
            guard idx >= 0 && idx < items.count else { return }
            let item = items[idx]

            switch type {
            case .weapon: character.equipWeapon(item)
            case .armor: character.equipArmor(item)
            case .shield: character.equipShield(item)
            default: break
            }
            self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
        }, pinnedHandler: { [weak self] _ in
            self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
        })
    }

    private func showUsePotionMenu(character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        let potions = character.inventory.filter { $0.type == .potion }

        clearTerminal()
        printSubtitle("Use Item")
        print("  \(character.name)'s usable items:", color: .cyan)
        print("")

        // Show party HP so player knows who needs healing
        let hasHealingPotion = potions.contains { $0.potionStats?.healAmount != nil }
        if hasHealingPotion && party.count > 1 {
            for char in party where char.isConscious {
                let hpPct = char.maxHP > 0 ? Double(char.currentHP) / Double(char.maxHP) : 1.0
                let color: TerminalColor = hpPct <= 0.33 ? .red : hpPct <= 0.66 ? .yellow : .dimGreen
                print("  \(shortName(for: char)): \(char.currentHP)/\(char.maxHP) HP", color: color)
            }
            print("")
        }

        var options: [String] = []
        for potion in potions {
            // Short label for button — just the name
            options.append(potion.name)
        }

        // Show item details above buttons
        for potion in potions {
            if let effect = potion.potionStats?.effect {
                print("  \(potion.name): \(effect)", color: .dimGreen)
            }
        }
        print("")

        closeHandler = { [weak self] in self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM) }

        showPaginatedMenu(options) { [weak self] idx in
            guard let self = self else { return }
            guard idx >= 0 && idx < potions.count else { return }
            let potion = potions[idx]

            let applyPotion = { (target: Character) in
                character.removeItem(potion)
                let isAntidote = potion.name.lowercased().contains("antidote")

                if isAntidote {
                    self.print("")
                    if target.isPoisoned {
                        target.curePoison()
                        self.print("  \(target.name) drinks the antidote!", color: .brightGreen)
                        self.print("  Poison cured!", color: .brightGreen)
                        self.logMultiplayerAction("\(target.name) uses antidote — poison cured!")
                    } else {
                        self.print("  \(target.name) drinks the antidote.", color: .dimGreen)
                        self.print("  (Not poisoned — no effect.)", color: .dimGreen)
                    }
                } else if let healStr = potion.potionStats?.healAmount {
                    let roll = Dice.rollDamage(healStr)
                    let amount = max(1, roll.total)
                    target.heal(amount)

                    self.print("")
                    self.print("  \(target.name) drinks \(potion.name)!", color: .brightGreen)
                    self.print("  Restored \(amount) HP! (\(target.currentHP)/\(target.maxHP))", color: .brightGreen)
                    if target.isPoisoned {
                        target.curePoison()
                        self.print("  Poison also cured!", color: .brightGreen)
                    }
                    self.logMultiplayerAction("\(target.name) drinks \(potion.name) — restored \(amount) HP (\(target.currentHP)/\(target.maxHP))")
                }

                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM)
                }
            }

            // Ask who should drink it when there are multiple party members
            if self.party.count > 1 {
                self.pickCharacter(title: "Who drinks the \(potion.name)?", onBack: {
                    self.showUsePotionMenu(character: character, onBack: onBack, fromDM: fromDM)
                }) { target in
                    applyPotion(target)
                }
            } else {
                applyPotion(character)
            }
        }
    }

    private func showDropItemMenu(character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        clearTerminal()
        printSubtitle("Drop Item")

        let items = character.inventory
        var options: [String] = []
        for item in items {
            options.append("\(item.name) (\(String(format: "%.1f", item.weight))lb)")
        }

        closeHandler = { [weak self] in self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM) }

        showPaginatedMenu(options) { [weak self] idx in
            guard let self = self else { return }
            guard idx >= 0 && idx < items.count else { return }
            let item = items[idx]

            // If multiple party members, offer to give to another character
            let others = self.party.filter { $0.id != character.id }
            if !others.isEmpty {
                self.showItemTransferMenu(item: item, from: character, others: others, onBack: onBack, fromDM: fromDM)
            } else {
                character.removeItem(item)
                if let room = self.dungeon?.currentRoom {
                    room.droppedItems.append(item)
                }
                self.print("")
                self.print("  Dropped \(item.name) in the room.", color: .yellow)
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM)
                }
            }
        }
    }

    private func showItemTransferMenu(item: Item, from: Character, others: [Character], onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        clearTerminal()
        printSubtitle("Give or Drop: \(item.name)")
        print("  \(from.name) has selected \(item.name).", color: .dimGreen)
        print("")

        var options: [String] = []
        var actions: [() -> Void] = []

        for other in others {
            let canCarry = other.canCarry(item)
            let tag = canCarry ? "" : (other.isInventoryFull ? " [full]" : " [heavy]")
            options.append("Give to \(shortName(for: other))\(tag)")
            actions.append { [weak self] in
                guard let self = self else { return }
                if canCarry {
                    from.removeItem(item)
                    _ = other.addItem(item)
                    self.print("")
                    self.print("  \(from.name) gives \(item.name) to \(other.name).", color: .brightGreen)
                    self.logEvent("\(from.name) gave \(item.name) to \(other.name)", category: "ITEM")
                } else {
                    self.print("")
                    self.print("  \(other.name) can't carry any more!", color: .yellow)
                }
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.showPackMenu(character: from, onBack: onBack, fromDM: fromDM)
                }
            }
        }

        options.append("Drop on Floor")
        actions.append { [weak self] in
            guard let self = self else { return }
            from.removeItem(item)
            if let room = self.dungeon?.currentRoom {
                room.droppedItems.append(item)
            }
            self.print("")
            self.print("  Dropped \(item.name) in the room.", color: .yellow)
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showPackMenu(character: from, onBack: onBack, fromDM: fromDM)
            }
        }

        showMenu(options)
        closeHandler = { [weak self] in self?.showDropItemMenu(character: from, onBack: onBack, fromDM: fromDM) }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showPackCharacterPicker(onBack: @escaping () -> Void) {
        let consciousParty = party.filter { $0.isConscious && !$0.inventory.isEmpty }
        guard !consciousParty.isEmpty else { onBack(); return }

        clearTerminal()
        printSubtitle("Whose Pack?")
        print("")

        var options: [String] = []
        for char in consciousParty {
            let count = char.inventory.count
            options.append("\(shortName(for: char))  (\(count) item\(count == 1 ? "" : "s"))")
        }

        showMenu(options)
        closeHandler = onBack
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice > 0 && choice <= consciousParty.count {
                let char = consciousParty[choice - 1]
                self.showPackMenu(character: char, onBack: onBack)
            }
        }
    }

    /// Pack sub-menu: Use Item, Give Item, Drop Item
    func showPackMenu(character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        clearTerminal()
        printSubtitle("Pack — \(shortName(for: character))")

        // List pack contents
        if character.inventory.isEmpty {
            print("  (empty)", color: .dimGreen)
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
                let torchInfo: String
                if item.isTorch, let desc = item.torchLifeDescription {
                    let isActive = item.id == activeTorchId && torchLit
                    torchInfo = isActive ? " (lit, \(desc))" : " (\(desc))"
                } else {
                    torchInfo = ""
                }
                print("  \(tag) \(item.name)\(torchInfo)", color: .green)
            }
        }
        print("")
        printWrapped("Items are things in your backpack — potions, torches, rope, etc. Equipment (weapons, armour, shields) is what you wear or wield.", indent: 2, color: .dimGreen)
        print("")

        let usableItems = character.inventory.filter { $0.type == .potion }
        let hasOthers = party.count > 1

        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        menuOpts.append(MenuOption("Use Item", isDisabled: usableItems.isEmpty))
        actions.append { [weak self] in self?.showUsePotionMenu(character: character, onBack: onBack, fromDM: fromDM) }

        menuOpts.append(MenuOption("Drop Item", isDisabled: character.inventory.isEmpty))
        actions.append { [weak self] in self?.showDropItemMenu(character: character, onBack: onBack, fromDM: fromDM) }

        menuOpts.append(MenuOption("Give Item", isDisabled: character.inventory.isEmpty || !hasOthers))
        actions.append { [weak self] in self?.showGiveItemMenu(character: character, onBack: onBack, fromDM: fromDM) }

        showMenuOptions(menuOpts)
        closeHandler = { [weak self] in
            self?.closeHandler = nil
            self?.showInventoryFor(character, onBack: onBack, fromDM: fromDM)
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showEquipmentMenu(character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        clearTerminal()
        printSubtitle("Equipment — \(shortName(for: character))")

        let weapons = character.inventory.filter { $0.type == .weapon }
        let armors = character.inventory.filter { $0.type == .armor }
        let shields = character.inventory.filter { $0.type == .shield }

        // Show current equipment status
        let wName = character.equippedWeapon?.name ?? "(none)"
        let aName = character.equippedArmor?.name ?? "(none)"
        let sName = character.equippedShield?.name ?? "(none)"
        print("  Weapon: \(wName)", color: character.equippedWeapon != nil ? .brightGreen : .dimGreen)
        print("  Armour: \(aName)", color: character.equippedArmor != nil ? .brightGreen : .dimGreen)
        print("  Shield: \(sName)", color: character.equippedShield != nil ? .brightGreen : .dimGreen)
        print("")

        var menuOpts: [MenuOption] = []
        var actions: [() -> Void] = []

        // Weapon slot: equip from bag or unequip current
        if character.equippedWeapon != nil {
            menuOpts.append(MenuOption("Remove Weapon"))
            actions.append { [weak self] in
                let w = character.equippedWeapon!
                character.unequipWeapon()
                self?.print("")
                self?.print("  Unequipped \(w.name).", color: .yellow)
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
                }
            }
        } else {
            menuOpts.append(MenuOption("Equip Weapon", isDisabled: weapons.isEmpty))
            actions.append { [weak self] in
                self?.showEquipMenu(character: character, type: .weapon, label: "Weapon", onBack: onBack, fromDM: fromDM)
            }
        }

        // Armour slot
        if character.equippedArmor != nil {
            menuOpts.append(MenuOption("Remove Armour"))
            actions.append { [weak self] in
                let a = character.equippedArmor!
                character.unequipArmor()
                self?.print("")
                self?.print("  Unequipped \(a.name).", color: .yellow)
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
                }
            }
        } else {
            menuOpts.append(MenuOption("Equip Armour", isDisabled: armors.isEmpty))
            actions.append { [weak self] in
                self?.showEquipMenu(character: character, type: .armor, label: "Armour", onBack: onBack, fromDM: fromDM)
            }
        }

        // Shield slot
        if character.equippedShield != nil {
            menuOpts.append(MenuOption("Remove Shield"))
            actions.append { [weak self] in
                let s = character.equippedShield!
                character.unequipShield()
                self?.print("")
                self?.print("  Unequipped \(s.name).", color: .yellow)
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
                }
            }
        } else {
            menuOpts.append(MenuOption("Equip Shield", isDisabled: shields.isEmpty))
            actions.append { [weak self] in
                self?.showEquipMenu(character: character, type: .shield, label: "Shield", onBack: onBack, fromDM: fromDM)
            }
        }

        // Pass Torch option — if this character holds the lit torch and there are others
        if torchLit && torchHolderId == character.id && party.count > 1 {
            let others = party.filter { $0.id != character.id }
            menuOpts.append(MenuOption("Pass Torch", tint: .amber))
            actions.append { [weak self] in
                guard let self = self else { return }
                self.clearTerminal()
                self.printSubtitle("Pass Torch To...")
                let names = others.map { self.shortName(for: $0) }
                self.showMenu(names)
                self.menuHandler = { [weak self] choice in
                    guard let self = self, choice > 0, choice <= others.count else { return }
                    let recipient = others[choice - 1]
                    // Move torch item from current holder to recipient
                    if let torchId = self.activeTorchId,
                       let idx = character.inventory.firstIndex(where: { $0.id == torchId }) {
                        let torch = character.inventory.remove(at: idx)
                        recipient.inventory.append(torch)
                    }
                    self.torchHolderId = recipient.id
                    self.print("")
                    self.print("  \(self.shortName(for: character)) passes the torch to \(self.shortName(for: recipient)).", color: .yellow)
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
                    }
                }
                self.closeHandler = { [weak self] in
                    self?.showEquipmentMenu(character: character, onBack: onBack, fromDM: fromDM)
                }
            }
        }

        showMenuOptions(menuOpts)
        closeHandler = { [weak self] in
            self?.closeHandler = nil
            self?.showInventoryFor(character, onBack: onBack, fromDM: fromDM)
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    private func showGiveItemMenu(character: Character, onBack: (() -> Void)? = nil, fromDM: Bool = false) {
        let others = party.filter { $0.id != character.id }
        guard !others.isEmpty else {
            showPackMenu(character: character, onBack: onBack, fromDM: fromDM)
            return
        }

        clearTerminal()
        printSubtitle("Give Item — \(shortName(for: character))")

        var options: [String] = []
        for item in character.inventory {
            options.append("\(item.name) (\(String(format: "%.1f", item.weight))lb)")
        }

        closeHandler = { [weak self] in self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM) }

        let inventoryItems = character.inventory
        showPaginatedMenu(options) { [weak self] idx in
            guard let self = self else { return }
            guard idx >= 0 && idx < inventoryItems.count else { return }
            let item = inventoryItems[idx]

            // Show recipient selection
            self.clearTerminal()
            self.printSubtitle("Give \(item.name) to...")

            var recipientOpts: [String] = []
            for other in others {
                let canCarry = other.canCarry(item)
                let tag = canCarry ? "" : (other.isInventoryFull ? " [full]" : " [heavy]")
                recipientOpts.append("\(self.shortName(for: other))\(tag)")
            }
            self.showMenu(recipientOpts)
            self.closeHandler = { [weak self] in self?.showGiveItemMenu(character: character, onBack: onBack, fromDM: fromDM) }
            self.menuHandler = { [weak self] rchoice in
                guard let self = self else { return }
                guard rchoice > 0 && rchoice <= others.count else { return }
                let recipient = others[rchoice - 1]
                if recipient.canCarry(item) {
                    character.removeItem(item)
                    _ = recipient.addItem(item)
                    self.print("")
                    self.print("  \(character.name) gives \(item.name) to \(recipient.name).", color: .brightGreen)
                    self.logEvent("\(character.name) gave \(item.name) to \(recipient.name)", category: "ITEM")
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        self?.showPackMenu(character: character, onBack: onBack, fromDM: fromDM)
                    }
                } else {
                    self.print("")
                    if recipient.isInventoryFull {
                        self.print("  \(recipient.name)'s bag is full! (\(recipient.inventory.count)/\(Character.maxInventorySlots))", color: .yellow)
                    } else {
                        self.print("  \(recipient.name) can't carry any more!", color: .yellow)
                    }
                    self.print("  Open their inventory or choose someone else.", color: .dimGreen)
                    self.print("")
                    self.showMenu(["Inventory", "Choose Again", "Cancel"])
                    self.menuHandler = { [weak self] choice in
                        guard let self = self else { return }
                        if choice == 1 {
                            self.showInventoryFor(recipient, onBack: { [weak self] in
                                self?.showGiveItemMenu(character: character, onBack: onBack, fromDM: fromDM)
                            })
                        } else if choice == 2 {
                            self.showGiveItemMenu(character: character, onBack: onBack, fromDM: fromDM)
                        } else {
                            self.showPackMenu(character: character, onBack: onBack, fromDM: fromDM)
                        }
                    }
                }
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
            printExplorationMap()
            print("")
        }

        printTitle("Party Status")

        // Game time & level
        if let level = dungeon?.level {
            print("  Dungeon Level: \(level)", color: .cyan)
        }
        print("  Time: \(formattedGameTime())", color: .cyan)
        let roomsVisited = dungeon?.rooms.values.filter { $0.visited }.count ?? 0
        let totalRooms = dungeon?.rooms.count ?? 0
        print("  Explored: \(roomsVisited)/\(totalRooms) rooms", color: .cyan)

        // Torch status
        if torchLit, let holderId = torchHolderId {
            let holderName = party.first(where: { $0.id == holderId }).map { shortName(for: $0) } ?? "?"
            let activeTorch = activeTorchId.flatMap { tid in party.flatMap { $0.inventory }.first(where: { $0.id == tid }) }
            let timeLeft = activeTorch?.torchLifeDescription ?? "?"
            print("  Torch: lit (\(timeLeft) left) — \(holderName)", color: .orange)
        } else {
            let totalTorches = party.flatMap { $0.inventory }.filter { $0.isTorch }.count
            if totalTorches > 0 {
                print("  Torch: unlit (\(totalTorches) available)", color: .dimGreen)
            } else {
                print("  Torch: none", color: .dimGreen)
            }
        }

        // Poison status
        let poisoned = party.filter { $0.isPoisoned }
        if !poisoned.isEmpty {
            let names = poisoned.map { shortName(for: $0) }.joined(separator: ", ")
            print("  ☠ Poisoned: \(names)", color: .magenta)
        }
        print("")

        // Character summary
        for char in party {
            let prefix = char.isComputerControlled ? "R. " : ""
            let hpFraction = Double(char.currentHP) / Double(char.maxHP)
            let hpColor: TerminalColor = hpFraction > 0.5 ? .brightGreen : (hpFraction > 0.25 ? .yellow : .red)

            // Line 1: Name + Race/Class
            let shortClass = String(char.characterClass.rawValue.prefix(3))
            print("  \(prefix)\(shortName(for: char))  \(char.race.rawValue) \(shortClass) L\(char.level)", color: .brightGreen, bold: true)

            // Line 2: HP bar + AC + Gold + XP
            let barLen = 8
            let filled = Int(hpFraction * Double(barLen))
            let hpBar = String(repeating: "█", count: filled) + String(repeating: "░", count: barLen - filled)
            let wpnStr = char.equippedWeapon.map { "  \(String($0.name.prefix(10)))" } ?? ""
            print("    [\(hpBar)] \(char.currentHP)/\(char.maxHP) AC\(char.armorClass) \(char.gold)gp\(wpnStr)", color: hpColor)
        }
        print("")

        // Build menu
        var menuOpts = ["Party Review", "Adventure Log", "Settings", "Help"]
        let hasPoisoned = party.contains(where: { $0.isPoisoned })
        if hasPoisoned {
            menuOpts.insert("Cure Poison", at: 0)
        }

        showMenu(menuOpts)

        closeHandler = { [weak self] in
            self?.showExplorationView()
        }

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = menuOpts[choice - 1]
            switch selected {
            case "Cure Poison":
                self.showPoisonInfo(onBack: { self.showPartyStatus() })
            case "Party Review":
                self.showInGamePartyReview()
            case "Adventure Log":
                self.showAdventureLog()
            case "Settings":
                self.showSettings()
            case "Help":
                self.showPartyStatusHelp()
            default:
                self.showExplorationView()
            }
        }
    }

    private func showPartyStatusHelp() {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Party Status — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Shows your dungeon map, then each character's class, race, HP bar, gold, and XP. Green HP = healthy (>50%), yellow = wounded (25-50%), red = critical (<25%). Characters at 0 HP are unconscious.", indent: 2, color: .dimGreen)
        print("")

        print("  BUTTONS", color: .cyan, bold: true)
        printWrapped("Party Review — edit characters (name, race, class, voice) and view their full stat cards. Select a character then use View Card to see detailed stats and equipment.", indent: 2, color: .dimGreen)
        printWrapped("Adventure Log — timeline of events in your adventure.", indent: 2, color: .dimGreen)
        printWrapped("Settings — access game settings (sound, DM, display, etc.).", indent: 2, color: .dimGreen)
        printWrapped("Cure Poison — appears when a party member is poisoned.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showPartyStatus() }
    }

    /// Shared helper — appends voice/text input explanation to any help screen
    private func printInputHelp() {
        print("  INPUT", color: .cyan, bold: true)
        if voiceMenuEnabled {
            printWrapped("You can tap the microphone icon to speak commands, or tap the text prompt (>) to type. The loudspeaker icon reads the screen aloud.", indent: 2, color: .dimGreen)
        } else {
            printWrapped("Tap the text prompt (>) to type commands. Enable Voice Menus in Settings > Accessibility to use voice input and screen reading.", indent: 2, color: .dimGreen)
        }
        print("")
    }

    /// Show a character card, browseable via swipe L/R
    private func showCharacterCard(index: Int) {
        cancelPartyStatusAnim()
        guard !party.isEmpty else { showPartyStatus(); return }
        let idx = max(0, min(index, party.count - 1))
        let char = party[idx]

        clearTerminal()

        let cardW = 27
        let border = String(repeating: "─", count: cardW)

        // Card position indicator
        if party.count > 1 {
            print("  \(idx + 1) of \(party.count) — swipe to browse", color: .dimGreen)
            print("")
        }

        // Top border
        print("  ╔\(border)╗", color: .cyan)

        // Name
        let nameLines = cardWrapText(char.name, width: cardW)
        for line in nameLines {
            let pad = max(0, cardW - line.count)
            let l = pad / 2; let r = pad - l
            print("  ║\(String(repeating: " ", count: l))\(line)\(String(repeating: " ", count: r))║", color: .brightGreen, bold: true)
        }

        // Class & Race
        let subtitle = "\(char.race.rawValue) \(char.characterClass.rawValue) L\(char.level)"
        let subDisplay = subtitle.count > cardW ? String(subtitle.prefix(cardW)) : subtitle
        let sPad = max(0, cardW - subDisplay.count)
        let sL = sPad / 2; let sR = sPad - sL
        print("  ║\(String(repeating: " ", count: sL))\(subDisplay)\(String(repeating: " ", count: sR))║", color: .yellow)

        print("  ╠\(border)╣", color: .cyan)

        // ASCII art
        for line in char.characterClass.asciiArt {
            let trimmed = line.count > 25 ? String(line.prefix(25)) : line
            let artPad = max(0, cardW - trimmed.count)
            let aL = artPad / 2; let aR = artPad - aL
            print("  ║\(String(repeating: " ", count: aL))\(trimmed)\(String(repeating: " ", count: aR))║", color: .green)
        }

        print("  ╠\(border)╣", color: .cyan)

        // Stats
        func statBar(_ label: String, _ val: Int) -> String {
            let scaled = max(1, min(10, val / 2))
            let bar = String(repeating: "█", count: scaled) + String(repeating: "░", count: 10 - scaled)
            let lbl = " \(label)".padding(toLength: 8, withPad: " ", startingAt: 0)
            let vStr = "\(val)".padding(toLength: 3, withPad: " ", startingAt: 0)
            return String("\(lbl)\(bar) \(vStr)".prefix(cardW))
        }
        let scores = char.abilityScores
        let stats = [("STR", scores.strength), ("DEX", scores.dexterity), ("CON", scores.constitution),
                     ("INT", scores.intelligence), ("WIS", scores.wisdom), ("CHA", scores.charisma)]
        for (label, val) in stats {
            let line = statBar(label, val)
            let lPad = max(0, cardW - line.count)
            print("  ║\(line)\(String(repeating: " ", count: lPad))║", color: .yellow)
        }

        // HP bar
        let hpPct = char.maxHP > 0 ? (char.currentHP * 10 / char.maxHP) : 0
        let hpBar = String(repeating: "█", count: hpPct) + String(repeating: "░", count: 10 - hpPct)
        let hpText = " HP".padding(toLength: 8, withPad: " ", startingAt: 0)
        let hpVal = "\(char.currentHP)/\(char.maxHP)".padding(toLength: 3, withPad: " ", startingAt: 0)
        let hpFull = String("\(hpText)\(hpBar) \(hpVal)".prefix(cardW))
        let hPad = max(0, cardW - hpFull.count)
        let hpColor: TerminalColor = char.currentHP <= char.maxHP / 3 ? .red : .yellow
        print("  ║\(hpFull)\(String(repeating: " ", count: hPad))║", color: hpColor)

        // Bottom border
        print("  ╚\(border)╝", color: .cyan)
        print("")

        // Equipment details
        var details: [String] = []
        if let weapon = char.equippedWeapon { details.append("Weapon: \(weapon.name)") }
        if let armour = char.equippedArmor { details.append("Armour: \(armour.name)") }
        if let shield = char.equippedShield { details.append("Shield: \(shield.name)") }
        details.append("AC: \(char.armorClass)  Gold: \(char.gold)  XP: \(char.experiencePoints)")
        if char.isPoisoned { details.append("☠ POISONED") }
        for detail in details {
            printWrapped(detail, indent: 2, color: .dimGreen)
        }

        // Name Lore match
        let heroes = nameEntries.filter { $0.category == "hero" }
        let cleanName = char.name.lowercased().hasPrefix("r. ") ? String(char.name.lowercased().dropFirst(3)) : char.name.lowercased()
        if heroes.contains(where: { cleanName.contains($0.name.lowercased()) || $0.name.lowercased().contains(cleanName) }) {
            print("")
            printWrapped("This character matches a hero in Name Lore!", indent: 2, color: .cyan)
        }

        // Swipe navigation — circular
        swipeLeftHandler = party.count > 1 ? { [weak self] in
            guard let self = self else { return }
            let next = (idx + 1) % self.party.count
            self.showCharacterCard(index: next)
        } : nil
        swipeRightHandler = party.count > 1 ? { [weak self] in
            guard let self = self else { return }
            let prev = (idx - 1 + self.party.count) % self.party.count
            self.showCharacterCard(index: prev)
        } : nil

        closeHandler = { [weak self] in
            self?.swipeLeftHandler = nil
            self?.swipeRightHandler = nil
            self?.showPartyStatus()
        }
    }

    private func showCardForCharacter(named charName: String) {
        guard let idx = party.firstIndex(where: { $0.name == charName }) else { return }
        showCharacterCard(index: idx)
    }

    /// Show character card from edit screen — swipe L/R to browse, close returns to edit
    private func showCharacterCardFromEdit(index: Int, inGame: Bool = false) {
        guard !party.isEmpty else { return }
        let idx = max(0, min(index, party.count - 1))
        let char = party[idx]

        clearTerminal()

        let cardW = 27
        let border = String(repeating: "─", count: cardW)

        if party.count > 1 {
            cardPositionLabel = "\(idx + 1)/\(party.count)"
        }

        // Top border
        print("  ╔\(border)╗", color: .cyan)

        // Name
        let nameLines = cardWrapText(char.name, width: cardW)
        for line in nameLines {
            let pad = max(0, cardW - line.count)
            let l = pad / 2; let r = pad - l
            print("  ║\(String(repeating: " ", count: l))\(line)\(String(repeating: " ", count: r))║", color: .brightGreen, bold: true)
        }

        // Class & Race
        let subtitle = "\(char.race.rawValue) \(char.characterClass.rawValue) L\(char.level)"
        let subDisplay = subtitle.count > cardW ? String(subtitle.prefix(cardW)) : subtitle
        let sPad = max(0, cardW - subDisplay.count)
        let sL = sPad / 2; let sR = sPad - sL
        print("  ║\(String(repeating: " ", count: sL))\(subDisplay)\(String(repeating: " ", count: sR))║", color: .yellow)

        print("  ╠\(border)╣", color: .cyan)

        // ASCII art
        for line in char.characterClass.asciiArt {
            let trimmed = line.count > 25 ? String(line.prefix(25)) : line
            let artPad = max(0, cardW - trimmed.count)
            let aL = artPad / 2; let aR = artPad - aL
            print("  ║\(String(repeating: " ", count: aL))\(trimmed)\(String(repeating: " ", count: aR))║", color: .green)
        }

        print("  ╠\(border)╣", color: .cyan)

        // Stats
        func statBar(_ label: String, _ val: Int) -> String {
            let scaled = max(1, min(10, val / 2))
            let bar = String(repeating: "█", count: scaled) + String(repeating: "░", count: 10 - scaled)
            let lbl = " \(label)".padding(toLength: 8, withPad: " ", startingAt: 0)
            let vStr = "\(val)".padding(toLength: 3, withPad: " ", startingAt: 0)
            return String("\(lbl)\(bar) \(vStr)".prefix(cardW))
        }
        let scores = char.abilityScores
        let stats = [("STR", scores.strength), ("DEX", scores.dexterity), ("CON", scores.constitution),
                     ("INT", scores.intelligence), ("WIS", scores.wisdom), ("CHA", scores.charisma)]
        for (label, val) in stats {
            let line = statBar(label, val)
            let lPad = max(0, cardW - line.count)
            print("  ║\(line)\(String(repeating: " ", count: lPad))║", color: .yellow)
        }

        // HP bar
        let hpPct = char.maxHP > 0 ? (char.currentHP * 10 / char.maxHP) : 0
        let hpBar = String(repeating: "█", count: hpPct) + String(repeating: "░", count: 10 - hpPct)
        let hpText = " HP".padding(toLength: 8, withPad: " ", startingAt: 0)
        let hpVal = "\(char.currentHP)/\(char.maxHP)".padding(toLength: 3, withPad: " ", startingAt: 0)
        let hpFull = String("\(hpText)\(hpBar) \(hpVal)".prefix(cardW))
        let hPad = max(0, cardW - hpFull.count)
        let hpColor: TerminalColor = char.currentHP <= char.maxHP / 3 ? .red : .yellow
        print("  ║\(hpFull)\(String(repeating: " ", count: hPad))║", color: hpColor)

        // Bottom border
        print("  ╚\(border)╝", color: .cyan)
        print("")

        // Equipment details
        var details: [String] = []
        if let weapon = char.equippedWeapon { details.append("Weapon: \(weapon.name)") }
        if let armour = char.equippedArmor { details.append("Armour: \(armour.name)") }
        if let shield = char.equippedShield { details.append("Shield: \(shield.name)") }
        details.append("AC: \(char.armorClass)  Gold: \(char.gold)  XP: \(char.experiencePoints)")
        if char.isPoisoned { details.append("☠ POISONED") }
        for detail in details {
            printWrapped(detail, indent: 2, color: .dimGreen)
        }

        // Swipe navigation — circular
        swipeLeftHandler = party.count > 1 ? { [weak self] in
            guard let self = self else { return }
            let next = (idx + 1) % self.party.count
            self.showCharacterCardFromEdit(index: next, inGame: inGame)
        } : nil
        swipeRightHandler = party.count > 1 ? { [weak self] in
            guard let self = self else { return }
            let prev = (idx - 1 + self.party.count) % self.party.count
            self.showCharacterCardFromEdit(index: prev, inGame: inGame)
        } : nil

        closeHandler = { [weak self] in
            self?.swipeLeftHandler = nil
            self?.swipeRightHandler = nil
            self?.cardPositionLabel = nil
            if inGame {
                self?.showInGameEditCharacter(index: idx)
            } else {
                self?.showEditCharacter(index: idx)
            }
        }
    }

    /// In-game party review — edit names, types, race, class — returns to Party Status
    private func showInGamePartyReview() {
        clearTerminal()
        printTitle("Party Review")

        for (i, char) in party.enumerated() {
            let tag: String
            if char.isComputerControlled {
                tag = " [Auto]"
            } else {
                tag = " [You]"
            }
            printWrapped("\(i + 1). \(char.name)\(tag) — \(char.race.rawValue) \(char.characterClass.rawValue)", indent: 2, color: .brightGreen)
            print("     HP:\(char.currentHP)/\(char.maxHP) AC:\(char.armorClass) \(char.characterClass.primaryAbility.abbreviation):\(char.abilityScores.score(for: char.characterClass.primaryAbility))", color: .dimGreen)
        }
        print("")

        var opts: [String] = []
        var actions: [() -> Void] = []

        if party.count >= 2 {
            for (i, char) in party.enumerated() {
                let shortN = shortName(for: char)
                opts.append("Edit \(shortN)")
                actions.append { [weak self] in
                    self?.showInGameEditCharacter(index: i)
                }
            }
        }

        // Rest button (long-press = fast long rest)
        let restIdx = opts.count
        opts.append("Rest")
        actions.append { [weak self] in self?.rest() }

        opts.append("Help")
        actions.append { [weak self] in self?.showPartyReviewHelp() }

        showMenu(opts)

        closeHandler = { [weak self] in
            guard let self = self else { return }
            // Enforce at least one local (human) player
            if !self.party.contains(where: { !$0.isComputerControlled }) {
                self.print("")
                self.print("  At least one character must be Local (You)!", color: .red)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showInGamePartyReview()
                }
                return
            }
            self.showPartyStatus()
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == restIdx + 1 {
                self.performRest(isLongRest: true, fast: true)
            }
        }
    }

    /// Edit a character mid-game — change name, type, race, class
    private func showInGameEditCharacter(index: Int) {
        guard index < party.count else { showInGamePartyReview(); return }
        let char = party[index]
        clearTerminal()

        // Start edit tracking if not already tracking this character
        if editingCharacterIndex != index {
            beginEditTracking(index: index)
        }

        printTitle("Edit — \(char.name)")

        printLines(char.characterClass.asciiArt, color: .cyan)
        print("")
        let typeStr = char.isComputerControlled ? "Auto (Robot)" : "Local (You)"
        print("  Type:  \(typeStr)", color: .yellow)
        print("  Race:  \(char.race.rawValue)", color: .green)
        print("  Class: \(char.characterClass.rawValue)", color: .green)
        print("  HP:    \(char.currentHP)/\(char.maxHP)  AC:\(char.armorClass)", color: .dimGreen)
        print("")

        var opts: [String] = []
        var actions: [() -> Void] = []

        opts.append("Change Name")
        actions.append { [weak self] in
            self?.showInGameChangeName(index: index)
        }

        opts.append("Change Type")
        actions.append { [weak self] in
            self?.showInGameChangeType(index: index)
        }

        opts.append("Change Class")
        actions.append { [weak self] in
            self?.showRetrainClass(index: index)
        }

        opts.append("Edit Voice")
        actions.append { [weak self] in
            self?.showCharacterVoiceEdit(index: index)
        }

        opts.append("View Card")
        actions.append { [weak self] in
            self?.showCharacterCardFromEdit(index: index, inGame: true)
        }

        showMenu(opts)

        // Restore undo/redo handlers after showMenu (which clears awaitingTextInput)
        updateUndoRedoHandlers(index: index)

        closeHandler = { [weak self] in
            self?.endEditTracking()
            self?.showInGamePartyReview()
        }
        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    // MARK: - Social Mobility (Class Change)

    /// Social tier for each class — lower = humbler origins
    private func socialTier(for cls: CharacterClass) -> Int {
        switch cls {
        case .barbarian: return 1  // tribal outsider
        case .fighter:   return 2  // common soldier
        case .ranger:    return 3  // woodsman
        case .rogue:     return 4  // street-smart
        case .cleric:    return 5  // educated clergy
        case .wizard:    return 6  // scholarly elite
        }
    }

    /// Change class mid-game — moving down the social ladder boosts you, moving up stretches you thinner
    private func showRetrainClass(index: Int) {
        guard index < party.count else { showInGameEditCharacter(index: index); return }
        let char = party[index]
        let oldClass = char.characterClass
        let oldLevel = char.level

        clearTerminal()
        printTitle("New Class — \(char.name)")
        print("  Current: \(oldClass.rawValue) Level \(oldLevel)", color: .yellow)
        print("")
        printWrapped("Tap a class to change. Long-press to preview what would happen.", indent: 2, color: .dimGreen)
        print("")

        let classes = CharacterClass.allCases.filter { $0 != oldClass }
        var opts = classes.map { $0.rawValue }
        opts.append("Help")
        showMenu(opts)

        closeHandler = { [weak self] in self?.showInGameEditCharacter(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == opts.count {
                self.showRetrainHelp(index: index)
                return
            }
            guard choice >= 1 && choice <= classes.count else { return }
            let newClass = classes[choice - 1]
            self.performRetrain(index: index, newClass: newClass)
        }
        // Long-press to preview retrain outcome
        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            guard choice >= 1 && choice <= classes.count else { return }
            let newClass = classes[choice - 1]
            self.previewRetrain(index: index, newClass: newClass)
        }
    }

    /// Preview what changing class would do, without applying changes
    private func previewRetrain(index: Int, newClass: CharacterClass) {
        guard index < party.count else { return }
        let char = party[index]
        let oldClass = char.characterClass
        let oldLevel = char.level

        // Social mobility calculation
        let oldTier = socialTier(for: oldClass)
        let newTier = socialTier(for: newClass)
        let tierDiff = oldTier - newTier // positive = moving down (boost), negative = moving up (stretch)

        // Calculate skill overlap
        let oldSkills = Set(oldClass.skillChoices)
        let newSkills = Set(newClass.skillChoices)
        let overlap = oldSkills.intersection(newSkills)
        let overlapCount = overlap.count

        // Estimate new level range
        var minLevel = 1
        if overlapCount >= 5 { minLevel += 2 }
        else if overlapCount >= 3 { minLevel += 1 }
        minLevel += (oldLevel - 1) / 2
        // Social mobility adjustment
        minLevel += tierDiff
        minLevel = max(1, minLevel)
        let maxLevel = min(minLevel + 1, oldLevel + max(0, tierDiff)) // +1 from lucky d4

        clearTerminal()
        printTitle("Preview — \(newClass.rawValue)")
        printLines(newClass.asciiArt, color: .cyan)
        print("")

        print("  \(oldClass.rawValue) L\(oldLevel) → \(newClass.rawValue) L\(minLevel)\(maxLevel > minLevel ? "-\(maxLevel)" : "")", color: .yellow, bold: true)
        print("")

        // Social mobility direction
        print("  SOCIAL MOBILITY", color: .cyan, bold: true)
        if tierDiff > 0 {
            printWrapped("Moving down the social ladder — your street smarts give you an edge. Level bonus: +\(tierDiff)", indent: 2, color: .brightGreen)
        } else if tierDiff < 0 {
            printWrapped("Moving up the social ladder — you'll need to learn new ways. Level adjustment: \(tierDiff)", indent: 2, color: .yellow)
        } else {
            printWrapped("Lateral move — similar social standing.", indent: 2, color: .dimGreen)
        }
        print("")

        // Skill overlap detail
        print("  SKILL OVERLAP: \(overlapCount)", color: .cyan, bold: true)
        if overlap.isEmpty {
            printWrapped("No shared skills — level bonus from overlap: +0", indent: 2, color: .dimGreen)
        } else {
            let sharedNames = overlap.map { $0.rawValue }.sorted().joined(separator: ", ")
            printWrapped("Shared: \(sharedNames)", indent: 2, color: .green)
            let bonus = overlapCount >= 5 ? 2 : (overlapCount >= 3 ? 1 : 0)
            printWrapped("Level bonus from overlap: +\(bonus)", indent: 2, color: .dimGreen)
        }
        print("")

        // What changes
        print("  WHAT CHANGES", color: .cyan, bold: true)
        printWrapped("New ability priorities, starting equipment, skills, and spells for \(newClass.rawValue). Old gear is lost.", indent: 2, color: .dimGreen)
        print("")

        // Primary ability
        print("  Primary: \(newClass.primaryAbility.rawValue)  Hit Die: d\(newClass.hitDie)", color: .green)
        print("")

        closeHandler = { [weak self] in self?.showRetrainClass(index: index) }
        waitForContinue()
        inputHandler = { [weak self] _ in self?.showRetrainClass(index: index) }
    }

    private func performRetrain(index: Int, newClass: CharacterClass) {
        guard index < party.count else { return }
        pushEditSnapshot(index: index)
        let char = party[index]
        let oldClass = char.characterClass
        let oldLevel = char.level
        let oldClassName = oldClass.rawValue

        // Calculate skill overlap between old and new class
        let oldSkills = Set(oldClass.skillChoices)
        let newSkills = Set(newClass.skillChoices)
        let overlap = oldSkills.intersection(newSkills).count

        // Social mobility calculation
        let oldTier = socialTier(for: oldClass)
        let newTier = socialTier(for: newClass)
        let tierDiff = oldTier - newTier // positive = moving down (boost), negative = moving up (stretch)

        // Calculate new level
        var newLevel = 1
        // Skill overlap bonus
        if overlap >= 5 { newLevel += 2 }
        else if overlap >= 3 { newLevel += 1 }
        // Current level bonus
        newLevel += (oldLevel - 1) / 2
        // Social mobility adjustment
        newLevel += tierDiff
        // Lucky roll bonus
        if Dice.d4() == 4 { newLevel += 1 }
        // Floor at 1 (can exceed old level when moving down)
        newLevel = max(1, newLevel)

        // Apply the class change
        char.characterClass = newClass
        char.level = newLevel

        // Re-prioritise ability scores
        let sorted = AbilityScores.standardArray.sorted(by: >)
        for (ability, bonus) in char.race.abilityBonuses {
            let current = char.abilityScores.score(for: ability)
            char.abilityScores.set(ability, to: current - bonus)
        }
        for (idx, ability) in newClass.abilityPriority.enumerated() {
            char.abilityScores.set(ability, to: sorted[idx])
        }
        for (ability, bonus) in char.race.abilityBonuses {
            let current = char.abilityScores.score(for: ability)
            char.abilityScores.set(ability, to: current + bonus)
        }

        // Recalculate HP for level 1, then add level-up HP gains
        let conMod = char.abilityScores.modifier(for: .constitution)
        let baseHP = newClass.startingHP + conMod
        var totalHP = max(1, baseHP)
        for _ in 2...max(2, newLevel) {
            if newLevel >= 2 {
                let hpRoll = Dice.rollSum(1, d: newClass.hitDie)
                totalHP += max(1, hpRoll + conMod)
            }
        }
        if newLevel < 2 { totalHP = max(1, baseHP) }
        char.maxHP = totalHP
        char.currentHP = min(char.currentHP, char.maxHP)

        // Update skills
        char.skillProficiencies.removeAll()
        let skills = Array(newClass.skillChoices.shuffled().prefix(newClass.numSkillChoices))
        for skill in skills { char.skillProficiencies.insert(skill) }

        // Update equipment
        char.inventory.removeAll()
        char.equippedWeapon = nil
        char.equippedArmor = nil
        char.equippedShield = nil
        let equipOptions = ItemCatalog.startingEquipmentOptions(for: newClass)
        if let (_, items) = equipOptions.first {
            for item in items { _ = char.addItem(item) }
        }
        autoEquip(char)

        // Update spells
        char.knownSpells = SpellCatalog.startingSpells(for: newClass)
        char.spellSlots = SpellCatalog.startingSlots(for: newClass, level: newLevel)

        // Set XP to match new level
        char.experiencePoints = Character.xpForLevel(newLevel)

        // Barbarian rage
        if newClass == .barbarian {
            char.rageUsesRemaining = char.rageMaxUses
        }

        // Show results
        clearTerminal()
        printTitle("Class Changed!")
        printLines(newClass.asciiArt, color: .cyan)
        print("")
        print("  \(char.name) changed from \(oldClassName) to \(newClass.rawValue)!", color: .brightGreen, bold: true)
        print("")
        if newLevel > oldLevel {
            print("  Level: \(oldLevel) → \(newLevel) (street smarts!)", color: .brightGreen)
        } else if newLevel < oldLevel {
            print("  Level: \(oldLevel) → \(newLevel) (learning the ropes)", color: .yellow)
        } else {
            print("  Level: \(newLevel) (preserved)", color: .brightGreen)
        }
        if tierDiff > 0 {
            print("  Social mobility: moved down — gained experience", color: .dimGreen)
        } else if tierDiff < 0 {
            print("  Social mobility: moved up — stretched thinner", color: .dimGreen)
        }
        if overlap > 0 {
            print("  Skill overlap: \(overlap) shared skills helped", color: .dimGreen)
        }
        print("  HP: \(char.currentHP)/\(char.maxHP)  AC: \(char.armorClass)", color: .green)
        print("")

        logEvent("\(char.name) changed class from \(oldClassName) L\(oldLevel) to \(newClass.rawValue) L\(newLevel)", category: "PARTY")
        logMultiplayerAction("\(char.name) changed class to \(newClass.rawValue) L\(newLevel)")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showInGameEditCharacter(index: index)
        }
    }

    private func showRetrainHelp(index: Int) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Class Change Help")
        print("")
        print("  SOCIAL MOBILITY", color: .cyan, bold: true)
        printWrapped("Change your class mid-adventure. Social standing affects the transition: dropping down the social ladder (e.g. Wizard to Fighter) means your worldly experience gives you an edge — you may gain levels. Climbing up (e.g. Barbarian to Wizard) means stretching what you know over unfamiliar ground — you may lose levels.", indent: 2, color: .green)
        print("")
        print("  CLASS HIERARCHY", color: .cyan, bold: true)
        printWrapped("From humble to elite: Barbarian → Fighter → Ranger → Rogue → Cleric → Wizard", indent: 2, color: .green)
        print("")
        print("  LEVEL CALCULATION", color: .cyan, bold: true)
        printWrapped("Your new level is based on:", indent: 2, color: .green)
        printWrapped("• Social direction (down = bonus, up = penalty)", indent: 4, color: .dimGreen)
        printWrapped("• Shared skills between old and new class", indent: 4, color: .dimGreen)
        printWrapped("• Your current level (higher = more carries over)", indent: 4, color: .dimGreen)
        printWrapped("• A touch of luck (small random bonus)", indent: 4, color: .dimGreen)
        printWrapped("Tap a class to change; long-press to preview first.", indent: 2, color: .dimGreen)
        print("")
        print("  WHAT CHANGES", color: .cyan, bold: true)
        printWrapped("Abilities are re-prioritised for your new class. You get new starting equipment, skills, and spells. Your old gear is lost — visit a shop to re-equip.", indent: 2, color: .dimGreen)
        print("")
        printInputHelp()

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showRetrainClass(index: index)
        }
    }

    /// Change character name mid-game
    private func showInGameChangeName(index: Int) {
        guard index < party.count else { showInGamePartyReview(); return }
        let char = party[index]
        clearTerminal()
        printTitle("Change Name — \(shortName(for: char))")

        print("  Current: \(char.name)", color: .yellow)
        print("")

        // Show suggestions as buttons
        let existingNames = Set(party.map { $0.name.lowercased() })
        let available = suggestedNames.filter { !existingNames.contains($0.lowercased()) }
        let suggestionList = Array(available.shuffled().prefix(4))

        print("  Type a name, or pick a suggestion:", color: .dimGreen)
        print("")

        var menuOpts = suggestionList.map { String($0) }
        menuOpts.append("Help")

        promptTextWithMenu("", options: menuOpts)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= suggestionList.count {
                self.confirmChangeName(index: index, newName: suggestionList[choice - 1])
            } else {
                self.showChangeNameHelp(index: index)
            }
        }

        inputHandler = { [weak self] name in
            guard let self = self else { return }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                self.showInGameEditCharacter(index: index)
                return
            }
            self.confirmChangeName(index: index, newName: trimmed)
        }

        // Dice icon → new random suggestions
        rerollHandler = { [weak self] in
            self?.showInGameChangeName(index: index)
        }

        closeHandler = { [weak self] in self?.showInGameEditCharacter(index: index) }
    }

    private func confirmChangeName(index: Int, newName: String) {
        let char = party[index]
        let oldName = char.name

        clearTerminal()
        printTitle("Confirm Name Change")
        print("")
        print("  \(oldName) → \(newName)", color: .yellow, bold: true)
        print("")

        // Check for Name Lore match
        let hasLore = nameEntries.contains(where: { $0.name.lowercased() == newName.lowercased() })
        if hasLore {
            print("  This name has a character card in Name Lore!", color: .brightGreen)
            print("")
        }

        showMenu(["Confirm", "Cancel"])
        closeHandler = { [weak self] in self?.showInGameChangeName(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.pushEditSnapshot(index: index)
                self.party[index].name = newName
            }
            self.showInGameEditCharacter(index: index)
        }
    }

    private func showChangeNameHelp(index: Int) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Change Name — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Shows the current character name and random suggestions from the name pool.", indent: 2, color: .dimGreen)
        print("")

        print("  HOW TO USE", color: .cyan, bold: true)
        printWrapped("Type a new name and press return to apply it. Tap the 🎲 icon above the keyboard for fresh suggestions. Names matching heroes from Name Lore will have character cards!", indent: 2, color: .dimGreen)
        print("")

        print("  UNDO / CANCEL", color: .cyan, bold: true)
        printWrapped("Tap close (X) to cancel without changing the name.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showInGameChangeName(index: index) }
    }

    /// Change player type mid-game (human/AI)
    private func showInGameChangeType(index: Int) {
        guard index < party.count else { showInGamePartyReview(); return }
        let char = party[index]
        let hasHumanElsewhere = party.enumerated().contains(where: { $0.offset != index && !$0.element.isComputerControlled })

        clearTerminal()
        printTitle("Player Type — \(shortName(for: char))")

        let currentType = char.isComputerControlled ? "Auto (Robot)" : "Local (You)"
        print("  Current: \(currentType)", color: .yellow)
        print("")

        var opts: [String] = []
        var typeLabels: [String] = []

        opts.append("Local (You)")
        typeLabels.append("Local (You)")

        let gcAuth = GameCenterManager.shared.isAuthenticated && party.count >= 2
        if gcAuth && (hasHumanElsewhere || !char.isComputerControlled) {
            opts.append("Remote Player")
            typeLabels.append("Remote Player")
        }

        // Auto (robot) option — not allowed for solo adventurers
        if party.count > 1 && (hasHumanElsewhere || !char.isComputerControlled) {
            opts.append("Auto (Robot)")
            typeLabels.append("Auto (Robot)")
        }

        opts.append("Help")

        showMenu(opts)

        closeHandler = { [weak self] in self?.showInGameEditCharacter(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == opts.count && opts.last == "Help" {
                self.showChangeTypeHelp(index: index)
                return
            }
            guard choice > 0 && choice <= typeLabels.count else { return }
            let newType = typeLabels[choice - 1]
            if newType == currentType {
                self.showInGameEditCharacter(index: index)
                return
            }
            self.confirmInGameChangeType(index: index, newType: newType, currentType: currentType)
        }
    }

    private func confirmInGameChangeType(index: Int, newType: String, currentType: String) {
        let char = party[index]
        clearTerminal()
        printTitle("Confirm Type Change")
        print("")
        print("  \(shortName(for: char)): \(currentType) → \(newType)", color: .yellow, bold: true)
        print("")

        print("  WHAT CHANGES:", color: .cyan, bold: true)
        switch newType {
        case "Local (You)":
            printWrapped("You will control \(char.name) directly in combat and exploration.", indent: 2, color: .dimGreen)
        case "Auto (Robot)":
            printWrapped("\(char.name) will act on their own using AI — choosing actions automatically.", indent: 2, color: .dimGreen)
        case "Remote Player":
            printWrapped("Another player will control \(char.name) via Game Centre multiplayer.", indent: 2, color: .dimGreen)
        default: break
        }
        print("")

        showMenu(["Confirm", "Cancel"])
        closeHandler = { [weak self] in self?.showInGameChangeType(index: index) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.pushEditSnapshot(index: index)
                switch newType {
                case "Local (You)":
                    self.party[index].unmarkAsAI()
                case "Auto (Robot)":
                    self.party[index].markAsAI()
                case "Remote Player":
                    self.party[index].unmarkAsAI()
                    self.convertLocalToMultiplayer(remoteCharacter: self.party[index])
                    return // convertLocalToMultiplayer handles navigation
                default: break
                }
            }
            self.showInGameEditCharacter(index: index)
        }
    }

    private func showChangeTypeHelp(index: Int) {
        clearTerminal()
        suppressAutoScroll = true
        printTitle("Player Type — Help")
        print("")

        print("  INFORMATION", color: .cyan, bold: true)
        printWrapped("Shows the current controller for this character.", indent: 2, color: .dimGreen)
        print("")

        print("  OPTIONS", color: .cyan, bold: true)
        printWrapped("Local (You) — you control this character's actions in combat and exploration.", indent: 2, color: .dimGreen)
        printWrapped("Auto (Robot) — the AI controls this character. They act on their own in combat and their name gets an \"R.\" prefix.", indent: 2, color: .dimGreen)
        printWrapped("Remote Player — invite a friend via Game Centre to control this character (requires 2+ party members and Game Centre sign-in).", indent: 2, color: .dimGreen)
        print("")

        print("  CANCEL", color: .cyan, bold: true)
        printWrapped("Tap close (X) to go back without changing the type.", indent: 2, color: .dimGreen)
        print("")

        printInputHelp()

        closeHandler = { [weak self] in self?.showInGameChangeType(index: index) }
    }

    private func startPartyStatusAnim(artLineRanges: [(charClass: CharacterClass, startIndex: Int, count: Int)]) {
        cancelPartyStatusAnim()
        partyStatusAnimFrame = 0

        partyStatusAnimTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.partyStatusAnimFrame += 1

                for range in artLineRanges {
                    let frames = range.charClass.asciiArtFrames
                    let frameIdx = self.partyStatusAnimFrame % frames.count
                    let frame = frames[frameIdx]

                    for (i, line) in frame.enumerated() {
                        let lineIdx = range.startIndex + i
                        if lineIdx < self.terminalLines.count {
                            self.terminalLines[lineIdx].text = line
                        }
                    }
                }
            }
        }
    }

    private func cancelPartyStatusAnim() {
        partyStatusAnimTimer?.invalidate()
        partyStatusAnimTimer = nil
    }

    /// Invite a remote player to take over an AI character in the current local game
    private func showInviteToCurrentGame() {
        let aiChars = party.filter { $0.isComputerControlled }
        guard !aiChars.isEmpty else {
            showPartyStatus()
            return
        }

        clearTerminal()
        printTitle("Invite Remote Player")
        print("Choose an AI character for the", color: .dimGreen)
        print("remote player to control:", color: .dimGreen)
        print("")

        var opts: [String] = []
        for char in aiChars {
            opts.append("\(char.name) — \(char.race.rawValue) \(char.characterClass.rawValue)")
        }
        opts.append("Done")

        showMenu(opts)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice >= 1 && choice <= aiChars.count {
                self.convertLocalToMultiplayer(remoteCharacter: aiChars[choice - 1])
            } else {
                self.showPartyStatus()
            }
        }
    }

    /// Convert a local game to multiplayer by assigning an AI character to a remote player
    private func convertLocalToMultiplayer(remoteCharacter: Character) {
        clearTerminal()
        printTitle("Invite Player")
        printWrapped("Inviting a player to control \(remoteCharacter.name)...", indent: 2, color: .dimGreen)
        print("")
        printWrapped("The Game Centre matchmaker will appear. Select a friend to invite.", indent: 2, color: .dimGreen)
        print("")

        // Store which character will be remote
        pendingRemoteCharacterId = remoteCharacter.id
        isMultiplayer = true

        // Close icon → cancel and go back to party review
        closeHandler = { [weak self] in
            self?.pendingRemoteCharacterId = nil
            self?.isMultiplayer = false
            self?.showInGamePartyReview()
        }

        // Show matchmaker for 2 players (us + 1 remote)
        GameCenterManager.shared.showMatchmaker(minPlayers: 2, maxPlayers: 2)
    }

    func showAdventureLog() {
        clearTerminal()
        printTitle("Adventure Log")
        print("  Time: \(formattedGameTime())", color: .cyan)
        print("  \(adventureLog.count) events", color: .dimGreen)
        print("")

        if adventureLog.isEmpty {
            print("  No events recorded yet.", color: .dimGreen)
        } else {
            // Filter to today's entries (current game day) for cleaner reading
            let currentDay = gameTimeMinutes / 1440 + 1
            let todayPrefix = "[Day \(currentDay),"
            let todayEntries = adventureLog.filter { $0.hasPrefix(todayPrefix) }

            let limit = adventureLogLimit
            let entries: [String]
            let source = todayEntries.isEmpty ? adventureLog : todayEntries
            if limit > 0 && source.count > limit {
                entries = Array(source.suffix(limit))
                print("  (Showing last \(limit) of \(source.count) today — change in Settings > Gameplay)", color: .dimGreen)
                print("")
            } else {
                entries = source
                if currentDay > 1 && !todayEntries.isEmpty {
                    print("  (Showing Day \(currentDay) — \(todayEntries.count) of \(adventureLog.count) events)", color: .dimGreen)
                    print("")
                } else if adventureLog.count > 200 {
                    print("  Long log! Change display limit in Settings > Gameplay if scrolling takes too long.", color: .dimGreen)
                    print("")
                }
            }
            let charColors: [TerminalColor] = [.brightGreen, .cyan, .magenta, .orange]
            for entry in entries {
                let color: TerminalColor
                if entry.contains("[COMBAT]") { color = .red }
                else if entry.contains("[LOOT]") { color = .yellow }
                else if entry.contains("[DM]") { color = .cyan }
                else if entry.contains("[LEVEL]") { color = .brightGreen }
                else if entry.contains("[TRAP]") { color = .red }
                else if entry.contains("[PARTY]") { color = .magenta }
                else if entry.contains("[CHAT]") {
                    if entry.contains("DM:") || entry.contains("Dungeon Master") {
                        color = .yellow
                    } else if let charIdx = party.firstIndex(where: { entry.contains($0.name) }) {
                        color = charColors[charIdx % charColors.count]
                    } else {
                        color = .green
                    }
                }
                else { color = .dimGreen }
                print("  \(entry)", color: color)
            }
        }

        print("")

        closeHandler = { [weak self] in
            self?.showPartyStatus()
        }
    }

    func rest() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        print("Choose rest type:")
        if torchLit {
            print("  Tip: Douse your torch before resting to save fuel.", color: .dimGreen)
        }
        // Check for unsecured exits and warn
        if let room = dungeon?.currentRoom {
            let openExits = room.exits.keys.filter { !room.secured.contains($0) }
            if !openExits.isEmpty {
                print("  Tip: Barricade doors before resting to reduce attack risk.", color: .dimGreen)
            } else {
                print("  All doors barricaded — safer to rest here.", color: .dimGreen)
            }
        }

        var options: [String] = ["Short Rest", "Long Rest"]
        if torchLit {
            options.append("Douse Torch")
        } else if partyHasTorch() {
            options.append("Illuminate")
        }
        if options.count % 2 == 0 {
            options.append("Hint")
        }

        showMenu(options)
        closeHandler = { [weak self] in self?.showExplorationView() }

        menuLongPressHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = options[choice - 1]
            if selected == "Long Rest" {
                self.performRest(isLongRest: true, fast: true)
            } else if selected == "Short Rest" {
                self.performRest(isLongRest: false, fast: true)
            }
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            let selected = options[choice - 1]
            switch selected {
            case "Short Rest":
                self.performRest(isLongRest: false)
            case "Long Rest":
                self.performRest(isLongRest: true)
            case "Douse Torch":
                self.torchLit = false
                self.print("")
                self.print("  You carefully douse the torch.", color: .yellow)
                self.print("  Darkness envelops the party...", color: .dimGreen)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.rest()
                }
            case "Illuminate":
                self.torchLit = true
                self.print("")
                self.print("  The torch flickers to life!", color: .yellow)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.rest()
                }
            case "Hint":
                self.showRandomHint(onBack: { self.rest() }, context: "rest")
            default:
                self.showExplorationView()
            }
        }
    }

    func performRest(isLongRest: Bool, fast: Bool = false) {
        let repeats = isLongRest ? 3 : 1
        let restDuration = isLongRest ? "8 hours" : "1 hour"
        let header = isLongRest ? "Taking a long rest (\(restDuration))..." : "Resting (\(restDuration))..."

        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        SoundManager.shared.stopMusic()
        print(header, color: .cyan, bold: true)
        if isHoldingScreen && !fast {
            print("(Hold screen to rest faster)", color: .dimGreen)
        }
        print("")

        playHourglassAnimation(repeats: repeats, fast: fast) { [weak self] in
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
                    // Short rest: CON save to fight off poison (fever breaks)
                    if char.isPoisoned {
                        let conMod = char.abilityScores.modifier(for: .constitution)
                        // Clerics, Rangers, and Druids are better at herbal remedies
                        let classBonus = (char.characterClass == .cleric || char.characterClass == .ranger) ? 3 : 0
                        let saveRoll = Dice.d20() + conMod + classBonus
                        if saveRoll >= 12 {
                            char.curePoison()
                            self.print("  The fever breaks — poison cured!", color: .brightGreen)
                            healed.append("\(char.name) cured")
                        } else {
                            self.print("  \(char.name) is still poisoned. Rest more or use an antidote.", color: .magenta)
                        }
                    }
                }
                self.logEvent("Short rest — \(healed.joined(separator: ", "))", category: "REST")
                self.logMultiplayerAction("Short rest — \(healed.joined(separator: ", "))")
            } else {
                self.advanceTime(480)
                self.print("")
                self.print("Long rest complete!", color: .cyan, bold: true)
                self.print("")
                for char in self.party {
                    char.heal(char.maxHP)
                    self.print("\(char.name) fully recovers!")
                    // Long rest always cures poison (body fights it off over 8 hours)
                    if char.isPoisoned {
                        char.curePoison()
                        self.print("  Poison cured after a full rest!", color: .brightGreen)
                    }
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
                self.logMultiplayerAction("Long rest — party fully recovered")
            }

            // Drain torch during rest
            if self.torchLit {
                let restMinutes = isLongRest ? 480 : 60
                self.torchTurnsRemaining -= restMinutes
                if self.torchTurnsRemaining <= 0 {
                    self.torchTurnsRemaining = 0
                    self.torchLit = false
                    // Consume the burned-out torch
                    if let torchId = self.activeTorchId {
                        for char in self.party {
                            if let idx = char.inventory.firstIndex(where: { $0.id == torchId }) {
                                char.inventory.remove(at: idx)
                                break
                            }
                        }
                    }
                    self.activeTorchId = nil
                    self.torchHolderId = nil
                    self.print("")
                    self.print("  Your torch burned out while resting.", color: .yellow)
                    self.printTorchHint()
                } else {
                    self.syncTorchLife()
                    if isLongRest {
                        let hours = self.torchTurnsRemaining / 60
                        self.print("")
                        self.print("  Your torch burned through the night — \(hours)h left.", color: .yellow)
                        self.print("  Tip: douse your torch before resting to save it.", color: .dimGreen)
                    }
                }
            }

            self.maybeShowTip()

            // Check for rest ambush from adjacent rooms
            if let ambushEncounter = self.checkRestAmbush(isLongRest: isLongRest) {
                self.print("")
                self.print("  *** AMBUSH! ***", color: .red, bold: true)
                self.print("  Monsters burst through an unsecured door!", color: .red)
                SoundManager.shared.playHit()
                // Sleep damage — halved because body is relaxed/untensed
                var ambushLog: [String] = []
                for char in self.party where char.isConscious {
                    let rawDmg = Dice.rollSum(1, d: 6)
                    let dmg = max(1, rawDmg / 2)
                    char.takeDamage(dmg)
                    self.print("  \(char.name) takes \(dmg) damage (caught off guard)", color: .yellow)
                    ambushLog.append("\(char.name) -\(dmg)HP")
                }
                self.logEvent("Ambushed during rest! \(ambushLog.joined(separator: ", "))", category: "COMBAT")
                self.print("")
                self.print("  Find somewhere safe to rest — barricade all doors first!", color: .dimGreen)
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    guard let self = self else { return }
                    if let room = self.dungeon?.currentRoom {
                        room.encounter = ambushEncounter
                        room.cleared = false
                    }
                    self.showExplorationView()
                }
            } else {
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    if self?.musicEnabled == true { SoundManager.shared.startMusic(.exploration, preference: self?.explorationMelodyChoice ?? 0) }
                    self?.showExplorationView()
                }
            }
        }
    }

    /// Check if monsters ambush during rest. Unsecured doors to uncleared rooms = danger.
    private func checkRestAmbush(isLongRest: Bool) -> Encounter? {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return nil }

        // Count unsecured exits leading to uncleared rooms with encounters
        var dangerousUnsecured = 0
        var dangerousSecured = 0
        for (dir, targetRoomId) in room.exits {
            guard let targetRoom = dungeon.rooms[targetRoomId] else { continue }
            guard !targetRoom.cleared && targetRoom.encounter != nil else { continue }
            if room.secured.contains(dir) {
                dangerousSecured += 1
            } else {
                dangerousUnsecured += 1
            }
        }

        guard dangerousUnsecured > 0 || dangerousSecured > 0 else { return nil }

        // Base chance: 5% per unsecured dangerous exit for short rest, 15% for long rest
        // Secured doors: only 2% chance (monsters batter through)
        let baseChance = isLongRest ? 15 : 5
        let securedChance = 2
        let totalChance = dangerousUnsecured * baseChance + dangerousSecured * securedChance
        let roll = Int.random(in: 1...100)

        guard roll <= totalChance else { return nil }

        // Spawn a small ambush encounter
        let level = dungeon.level
        let monsterTypes = MonsterType.forLevel(level)
        guard let monsterType = monsterTypes.randomElement() else { return nil }
        let count = Int.random(in: 1...2)
        let monsters = (0..<count).map { _ in Monster.create(monsterType) }
        return Encounter(monsters: monsters, difficulty: .easy)
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

    private func playHourglassAnimation(repeats: Int, fast: Bool = false, completion: @escaping () -> Void) {
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

            let delay = (fast || isHoldingScreen) ? 0.15 : 0.8
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
        inDMMode = true
        // If the current room has an encounter, start combat and return to DM after
        if let room = dungeon?.currentRoom, !room.cleared, let encounter = room.encounter {
            returnToDMAfterCombat = true
            startCombat(encounter: encounter)
            return
        }

        clearTerminal()

        // Snapshot state when entering DM mode
        if StateSnapshotManager.shared.dmEntrySnapshot == nil {
            let snapshot = StateSnapshot.capture(
                label: "dm_entry",
                party: party,
                dungeon: dungeon,
                gameTimeMinutes: gameTimeMinutes
            )
            StateSnapshotManager.shared.write(snapshot)
        }

        // Show map at top
        if let dungeon = dungeon {
            printExplorationMap()
            print("")
        }

        // Replay chat history (compact — newest bright, older dim)
        if !dmChatLog.isEmpty {
            let recentEntries = Array(dmChatLog.suffix(6))
            let lastIdx = recentEntries.count - 1
            for (ei, entry) in recentEntries.enumerated() {
                let isNewest = ei == lastIdx
                if entry.isUser {
                    print("> \(entry.text)", color: isNewest ? .cyan : .dimGreen)
                } else {
                    let color: TerminalColor = isNewest ? .yellow : .dimGreen
                    print("DM:", color: color, bold: isNewest)
                    for paragraph in entry.text.components(separatedBy: "\n") {
                        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { print("") }
                        else { print("  \(trimmed)", color: color) }
                    }
                }
                print("")
            }
        }

        // Inject recent actions into DM context and show as history
        if adventureLogIndexAtLastDM < adventureLog.count {
            let newEntries = Array(adventureLog[adventureLogIndexAtLastDM...])
            if !newEntries.isEmpty {
                let summary = newEntries.joined(separator: "\n")
                DMEngine.shared.injectContext("The party has been busy since we last talked. Here is a summary of recent events:\n\(summary)")
                for entry in newEntries {
                    print("  \(entry)", color: .dimGreen)
                }
                print("")
            }
            adventureLogIndexAtLastDM = adventureLog.count
        }

        dmPromptForQuestion()
    }

    private func leaveDMMode() {
        inDMMode = false
        SpeechEngine.shared.stop()

        let exitSnapshot = StateSnapshot.capture(
            label: "dm_exit",
            party: party,
            dungeon: dungeon,
            gameTimeMinutes: gameTimeMinutes
        )
        StateSnapshotManager.shared.write(exitSnapshot)

        // Show diff if we have an entry snapshot
        if let entrySnapshot = StateSnapshotManager.shared.dmEntrySnapshot {
            let diff = StateDiff.compute(before: entrySnapshot, after: exitSnapshot)
            if diff.hasChanges {
                clearTerminal()
                print("--- DM Session Summary ---", color: .cyan, bold: true)
                print("")
                for change in diff.changes {
                    print("  \(change.description)", color: change.color)
                }
                print("")
                print("--------------------------", color: .cyan)
                print("")

                StateSnapshotManager.shared.clearDMEntry()

                waitForContinue()
                inputHandler = { [weak self] _ in
                    self?.showExplorationView()
                }
                return
            }
        }

        StateSnapshotManager.shared.clearDMEntry()
        showExplorationView()
    }

    private func dmPromptForQuestion() {
        promptTextWithMenu("Ask the DM:", options: [])

        inputHandler = { [weak self] input in
            guard let self = self else { return }

            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            // Empty input or explicit exit commands — leave DM mode
            if trimmed.isEmpty || ["back", "b", "quit dm", "quit dm mode", "exit", "quit", "q", "leave"].contains(trimmed.lowercased()) {
                self.leaveDMMode()
                return
            }
            let lower = trimmed.lowercased()

            // Inventory shortcut — opens inventory, Back returns to DM mode
            if lower == "i" || lower == "inventory" {
                let back: () -> Void = { [weak self] in self?.askTheDM() }
                let humans = self.party.filter { !$0.isComputerControlled }
                let defaultChar = humans.randomElement() ?? self.party.first!
                self.showInventoryFor(defaultChar, onBack: back, fromDM: true)
                return
            }

            // Map shortcut — show minimap inline
            if lower == "m" || lower == "map" || lower == "where" || lower == "where am i" {
                self.print("")
                if let dungeon = self.dungeon {
                    self.printExplorationMap()
                }
                self.print("")
                self.dmPromptForQuestion()
                return
            }

            // Teleport shortcut — return to dungeon entrance
            if lower == "t" || lower == "teleport" {
                self.applyTeleportToEntrance()
                self.logEvent("Teleported to entrance", category: "DM")
                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.askTheDM()
                }
                return
            }

            // Stop any ongoing DM speech from previous response
            SpeechEngine.shared.stop()

            // Interpret N/S/E/W as movement shortcuts
            let directionMap: [String: Direction] = [
                "n": .north, "north": .north, "go north": .north,
                "s": .south, "south": .south, "go south": .south,
                "e": .east, "east": .east, "go east": .east,
                "w": .west, "west": .west, "go west": .west,
            ]
            if let dir = directionMap[lower] {
                // Move but stay in DM mode
                if let dungeon = self.dungeon, let current = dungeon.currentRoom,
                   let nextId = current.exits[dir], let _ = dungeon.rooms[nextId] {
                    let _ = dungeon.move(direction: dir)
                    self.logEvent("Moved \(dir.rawValue)", category: "MOVE")
                    self.roomsSinceLastSave += 1
                    self.tickTorch()
                    self.checkTorchEvent()
                    // Check for encounter
                    if let newRoom = dungeon.currentRoom, !newRoom.cleared, newRoom.encounter != nil {
                        self.returnToDMAfterCombat = true
                        self.askTheDM()
                        return
                    }
                    // Show map and room name inline
                    self.print("")
                    self.printExplorationMap()
                    if let newRoom = dungeon.currentRoom {
                        self.print("")
                        self.print(newRoom.name, color: .brightGreen, bold: true)
                        self.print(newRoom.roomDescription, color: .dimGreen)
                    }
                    self.print("")
                    self.dmPromptForQuestion()
                } else {
                    self.print("")
                    self.print("Can't go that way.", color: .red)
                    self.dmPromptForQuestion()
                }
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
                        if result.lightTorch {
                            self.applyDMLightTorch()
                            worldChanged = true
                        }
                        if result.douseTorch {
                            self.applyDMDouseTorch()
                            worldChanged = true
                        }
                        if let dir = result.unsecureDirection {
                            self.applyDMUnsecure(dir)
                            worldChanged = true
                        }
                        if let dir = result.secureDirection {
                            self.applyDMSecure(dir)
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
                        let maxN = self.party.map { $0.name.count }.max() ?? 8
                        for char in self.party {
                            let n = char.name.padding(toLength: maxN, withPad: " ", startingAt: 0)
                            self.print("  \(n)  \(char.currentHP)/\(char.maxHP) HP  \(char.gold)gp", color: .cyan)
                        }

                        // Snapshot after DM commands applied
                        let postSnapshot = StateSnapshot.capture(
                            label: "dm_command",
                            party: self.party,
                            dungeon: self.dungeon,
                            gameTimeMinutes: self.gameTimeMinutes
                        )
                        StateSnapshotManager.shared.write(postSnapshot)
                    }

                    // Auto-apply narrative-implied item changes that lack tags
                    if adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue {
                        let fallbackApplied = self.applyNarrativeFallbacks(
                            text: result.cleanText,
                            alreadyApplied: result
                        )
                        if fallbackApplied {
                            worldChanged = true
                        }
                    }

                    // Check for remaining missed commands (healing, damage, gold)
                    let missedHints = DMEngine.detectMissedCommands(
                        narrativeText: result.cleanText,
                        appliedResult: result
                    )
                    if !missedHints.isEmpty {
                        self.print("")
                        for hint in missedHints {
                            self.print("  \(hint)", color: .dimGreen)
                        }
                    }

                    // Speak the DM response (only if still in DM mode)
                    if self.inDMMode {
                        SpeechEngine.shared.speak(displayText)
                    }

                    self.print("")
                    self.logEvent("Asked DM: \(input)", category: "DM")

                    if worldChanged {
                        // World changed — handle loot pickup then stay in DM mode
                        self.waitForContinue()
                        self.inputHandler = { [weak self] _ in
                            self?.showLootSequence(gold: pendingGold, goldSource: "DM reward",
                                                   items: pendingPickupItems, itemSource: "DM gift") { [weak self] in
                                self?.askTheDM()
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

        promptTextWithMenu(">", options: ["Send", "Done"])

        menuHandler = { [weak self] choice in
            if choice == 2 {
                self?.showPlayerCombatMenu(characterId: characterId)
            }
            // choice 1 (Send) handled by view submitting text
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

                    // Auto-apply narrative-implied item changes in combat too
                    if adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue {
                        let fallbackApplied = self.applyNarrativeFallbacks(
                            text: result.cleanText,
                            alreadyApplied: result
                        )
                        if fallbackApplied { tookAction = true }
                    }

                    // Speak the DM response
                    SpeechEngine.shared.speak(displayText)

                    self.print("")
                    self.logEvent("Asked DM in combat: \(input)", category: "DM")

                    // Stay in DM conversation — don't leave DM mode after each action
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        if tookAction {
                            combat.checkCombatEnd()
                            if combat.state == .victory {
                                self?.handleCombatVictory()
                            } else if combat.state == .defeat {
                                self?.handleCombatDefeat()
                            } else {
                                self?.askTheDMInCombat(characterId: characterId)
                            }
                        } else {
                            self?.askTheDMInCombat(characterId: characterId)
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

        // Secured exits — explicit state for DM awareness
        var securedInfo: String? = nil
        if let room = room, !room.secured.isEmpty {
            let dirs = room.secured.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.rawValue }
            securedInfo = dirs.joined(separator: ", ")
        }

        // Dropped items on the floor
        var droppedInfo: String? = nil
        if let room = room, !room.droppedItems.isEmpty {
            let items = room.droppedItems.map { $0.name }
            droppedInfo = "Items on the floor: \(items.joined(separator: ", "))"
        }

        // Time limit
        var timeLimitInfo: String? = nil
        if gameTimeLimit > 0 {
            let remaining = max(0, gameTimeLimit - gameTimeMinutes)
            timeLimitInfo = "Time limit: \(formatTimeLimitValue(gameTimeLimit)), \(formatTimeRemaining(remaining))"
        }

        // NPC info
        var npcInfo: String? = nil
        if let room = room, let npc = room.npc {
            let capabilities = [
                npc.type.canTrade && !npc.hasTraded ? "trade" : nil,
                npc.type.canHeal ? "heal" : nil,
                npc.type.canRepair ? "repair" : nil,
                npc.type.canTeach && !npc.hasTaught ? "teach" : nil,
                npc.type.canCurePoison ? "cure poison" : nil,
            ].compactMap { $0 }
            let capStr = capabilities.isEmpty ? "" : " (can: \(capabilities.joined(separator: ", ")))"
            npcInfo = "NPC present: \(npc.type.rawValue)\(capStr) — \(npc.hasBeenTalkedTo ? "already spoken to" : "not yet spoken to")"
        }

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
            adventureLogSummary: logSummary,
            torchLit: torchLit,
            torchTurnsRemaining: torchTurnsRemaining,
            securedExits: securedInfo,
            dungeonLevel: dungeon?.level ?? 1,
            timeLimit: timeLimitInfo,
            droppedItems: droppedInfo,
            npcInfo: npcInfo
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

    /// Show an impact frame on the defender when hit
    private func renderHitImpact(_ report: AttackReport) {
        guard hitAnimationsEnabled else { return }
        let defArt = report.defenderArt
        let impactColor: TerminalColor = report.isCritical ? .yellow : .red

        // Impact sparks surrounding the defender
        let sparkPatterns: [[String]] = [
            ["  \\*/  ", "  -*=  ", "  /*/  "],
            ["  */\\  ", "  =*-  ", "  \\*\\  "],
            ["  |*|  ", "  *-*  ", "  |*|  "],
        ]
        let sparks = sparkPatterns[Int.random(in: 0..<sparkPatterns.count)]
        let midPoint = defArt.count / 2

        print("")
        for (i, line) in defArt.enumerated() {
            if i >= midPoint - 1 && i <= midPoint + 1 {
                let sparkIdx = i - (midPoint - 1)
                print(" \(sparks[sparkIdx])\(line)", color: impactColor, bold: true)
            } else {
                print("       \(line)", color: impactColor)
            }
        }
    }

    /// Show the defender collapsing when defeated — eyes replaced with x
    private func renderDefeatFrame(_ report: AttackReport) {
        guard hitAnimationsEnabled else { return }
        let defArt = report.defenderArt.map { deadEyes($0) }
        // "Collapse" the art by shifting each line right progressively and dimming
        print("")
        for (i, line) in defArt.enumerated() {
            let shift = String(repeating: " ", count: i)
            if i == defArt.count - 1 {
                // Last line = fallen
                print("  \(shift)\(line)  x_x", color: .dimGreen)
            } else {
                print("  \(shift)\(line)", color: .dimGreen)
            }
        }
    }

    /// Replace eye characters in ASCII art with "x" for a dead look
    private func deadEyes(_ line: String) -> String {
        var result = line
        for pattern in Self.eyePatterns {
            if result.contains(pattern.find) {
                let dead = pattern.find.unicodeScalars.map { c -> String in
                    let ch = Swift.Character(c)
                    return (ch == "o" || ch == "O" || ch == "@" || ch == ".") ? "x" : String(ch)
                }.joined()
                result = result.replacingOccurrences(of: pattern.find, with: dead)
                break
            }
        }
        return result
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
                self.renderHitImpact(report)
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
                self.renderHitImpact(report)
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
                        self.renderDefeatFrame(report)
                        self.print("  \(report.targetName) is defeated!", color: .yellow, bold: true)
                    } else if report.targetUnconscious {
                        SoundManager.shared.playDeath()
                        self.renderDefeatFrame(report)
                        self.print("  \(report.targetName) falls unconscious!", color: .red, bold: true)
                    } else {
                        self.print("  \(report.targetName): \(report.targetCurrentHP)/\(report.targetMaxHP) HP", color: .dimGreen)
                    }

                    if report.poisonApplied {
                        if self.poisonEnabled {
                            self.print("")
                            self.print("  POISONED! \(report.targetName) has been poisoned!", color: .magenta, bold: true)
                            self.print("  (takes damage each turn until cured or it wears off)", color: .dimGreen)
                        } else {
                            // Poison disabled — immediately cure
                            if let char = self.party.first(where: { $0.name == report.targetName }), char.isPoisoned {
                                char.curePoison()
                            }
                        }
                    }
                    self.print("")

                    self.logMultiplayerAttackReport(report)
                    self.waitForContinue()
                    self.inputHandler = { _ in completion() }
                }
            } else {
                self.logMultiplayerAttackReport(report)
                self.waitForContinue()
                self.inputHandler = { _ in completion() }
            }
        }
    }

    /// Log an attack report as a multiplayer action for remote player catch-up
    private func logMultiplayerAttackReport(_ report: AttackReport) {
        guard isMultiplayer else { return }
        var desc: String
        if report.hits, let damage = report.totalDamage {
            if report.isCritical {
                desc = "\(report.attackerName) CRITS \(report.targetName) with \(report.weaponName) — \(damage) damage!"
            } else {
                desc = "\(report.attackerName) hits \(report.targetName) with \(report.weaponName) — \(damage) damage"
            }
            if report.targetDefeated {
                desc += " — \(report.targetName) defeated!"
            } else if report.targetUnconscious {
                desc += " — \(report.targetName) falls unconscious!"
            } else {
                desc += " (\(report.targetCurrentHP)/\(report.targetMaxHP) HP)"
            }
        } else {
            desc = "\(report.attackerName) attacks \(report.targetName) — MISS"
        }
        multiplayerState?.addAction(
            playerName: report.isPlayerAttack ? report.attackerName : "Monster",
            description: desc
        )
    }

    private func logMultiplayerSpellReport(_ report: SpellReport) {
        guard isMultiplayer else { return }
        var desc: String
        switch report.spellType {
        case .healing:
            desc = "\(report.casterName) casts \(report.spellName) — heals \(report.healAmount) HP!"
        case .attack, .savingThrow, .autoHit:
            if report.totalDamage > 0 {
                desc = "\(report.casterName) casts \(report.spellName) — \(report.totalDamage) damage!"
                for defeated in report.targetsDefeated {
                    desc += " \(defeated) defeated!"
                }
            } else {
                desc = "\(report.casterName) casts \(report.spellName) — no effect"
            }
        case .buff:
            desc = "\(report.casterName) casts \(report.spellName)!"
        case .utility:
            desc = "\(report.casterName) casts \(report.spellName) on \(report.targetName ?? "ally")"
        }
        multiplayerState?.addAction(playerName: report.casterName, description: desc)
    }

    // MARK: - Combat

    func startCombat(encounter: Encounter) {
        gameState = .combat
        combatHesitating = false
        cancelCombatIdleTimer()

        // Balance monster ACs for ~65% hit rate (medium encounters)
        var balanced = encounter
        let avgAttackBonus: Int = {
            guard !party.isEmpty else { return 4 }
            let total = party.map { char -> Int in
                let strMod = char.abilityScores.modifier(for: .strength)
                let dexMod = char.abilityScores.modifier(for: .dexterity)
                let weaponMod = (char.equippedWeapon?.weaponStats?.isRanged == true ||
                                 (char.equippedWeapon?.weaponStats?.isFinesse == true && dexMod > strMod))
                    ? dexMod : strMod
                return weaponMod + char.proficiencyBonus
            }.reduce(0, +)
            return total / party.count
        }()
        balanced.balanceAC(partyAvgAttackBonus: avgAttackBonus)

        // Apply difficulty scale to monster HP (custom difficulty levels)
        if difficultyScale != 1.0 {
            for i in balanced.monsters.indices {
                let scaledHP = max(1, Int(Double(balanced.monsters[i].maxHP) * difficultyScale))
                balanced.monsters[i].maxHP = scaledHP
                balanced.monsters[i].currentHP = scaledHP
            }
        }

        currentCombat = Combat(party: party, encounter: balanced)
        if self.musicEnabled { SoundManager.shared.startMusic(.combat, preference: self.combatMelodyChoice) }
        SoundManager.shared.playBattleStart()
        checkTorchBlowout()

        let monsterNames = encounter.monsters.map { $0.name }.joined(separator: ", ")
        logEvent("Battle! Encountered \(monsterNames)", category: "COMBAT")
        logMultiplayerAction("Encountered \(monsterNames)!")

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
            for entry in combat.turnOrder {
                print("  \(entry.name): \(entry.initiative)")
            }
        }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.advanceCombat()
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
                    self.advanceCombat()
                }
            } else {
                combat.nextTurn()
                advanceCombat()
            }
        }
    }

    // MARK: - AI Combat Turn

    func runAICombatTurn(character: Character) {
        guard let combat = currentCombat else { return }

        let aliveMonsters = combat.encounter.aliveMonsters
        guard !aliveMonsters.isEmpty else { return }

        print("\(character.name) considers...", color: .cyan, bold: true)
        print("")

        // Decision priority:
        // 0. If poisoned and very hurt, try to use antidote/potion or play dead
        // 1. Barbarian: Rage if not raging and has uses
        // 2. Cleric: Heal if any ally below 30% HP
        // 3. Fighter: Second Wind if below 40% HP
        // 4. Attack the weakest (lowest HP) monster

        // 0. Poisoned — seek antidote or healing potion, or play dead
        if character.isPoisoned {
            // Try antidote first
            let antidoteIdx = character.inventory.firstIndex(where: {
                $0.name.lowercased().contains("antidote")
            })
            if let idx = antidoteIdx {
                let antidote = character.inventory[idx]
                character.inventory.remove(at: idx)
                character.curePoison()
                print("  \(character.name) drinks an \(antidote.name)!", color: .brightGreen)
                print("  Poison cured!", color: .brightGreen)
                logMultiplayerAction("\(character.name) uses antidote — poison cured!")
                combat.nextTurn()
                waitForContinue()
                inputHandler = { [weak self] _ in self?.advanceCombat() }
                return
            }

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
                logMultiplayerAction("\(character.name) drinks \(potion.name) (+\(healAmt) HP)")
                character.curePoison()
                print("  The poison is cleansed!", color: .brightGreen)
                combat.nextTurn()
                waitForContinue()
                inputHandler = { [weak self] _ in self?.advanceCombat() }
                return
            }

            // Very hurt and poisoned — might play dead
            let hpPercent = Double(character.currentHP) / Double(character.maxHP)
            if hpPercent < 0.25 {
                print("  \(character.name) is badly poisoned and collapses, playing dead!", color: .yellow)
                logMultiplayerAction("\(character.name) collapses, playing dead!")
                character.isPlayingDead = true
                combat.nextTurn()
                waitForContinue()
                inputHandler = { [weak self] _ in self?.advanceCombat() }
                return
            }
        }

        // 1. Barbarian Rage
        if character.characterClass == .barbarian && !character.isRaging && character.rageUsesRemaining > 0 {
            print("  \(character.name) enters a furious RAGE!", color: .red, bold: true)
            logMultiplayerAction("\(character.name) enters a furious RAGE!")
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
                            self?.advanceCombat()
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
            logMultiplayerAction("\(character.name) uses Second Wind!")
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
                        self?.advanceCombat()
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
                self?.advanceCombat()
            }
        } else {
            // Fallback: skip turn
            combat.nextTurn()
            advanceCombat()
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
                let hasDisadvantage = self.combatHesitating
                self.combatHesitating = false
                if let report = combat.playerAttack(characterId: characterId, targetId: monsterRef.id, disadvantage: hasDisadvantage) {
                    self.clearTerminal()
                    self.printLines(combat.displayStatus())
                    self.print("")
                    if hasDisadvantage {
                        self.print("  (Disadvantage — you hesitated!)", color: .yellow)
                        self.print("")
                    }
                    self.displayAttackReport(report) { [weak self] in
                        combat.checkCombatEnd()
                        combat.nextTurn()
                        self?.advanceCombat()
                    }
                }
            }
        }

        // Cast Spell (spellcasters with spells)
        if !character.knownSpells.isEmpty {
            let hasCantrips = character.knownSpells.contains { $0.level == .cantrip }
            let hasSlots = character.spellSlots.level1Current > 0 || character.spellSlots.level2Current > 0
            if hasCantrips || hasSlots {
                let slotInfo = character.spellSlots.isEmpty ? "" : " [\(character.spellSlots.level1Current)]"
                options.append("Spell\(slotInfo)")
                actions.append { [weak self] in
                    self?.showSpellMenu(characterId: characterId)
                }
            }
        }

        // Fighter: Second Wind
        if character.characterClass == .fighter && !character.secondWindUsed {
            options.append("Second Wind")
            actions.append { [weak self] in
                self?.useSecondWind(character: character)
            }
        }

        // Barbarian: Rage
        if character.characterClass == .barbarian && character.rageUsesRemaining > 0 && !character.isRaging {
            options.append("Rage!")
            actions.append { [weak self] in
                self?.activateRage(character: character)
            }
        }

        // Dodge
        options.append("Dodge")
        actions.append { [weak self] in
            guard let self = self else { return }
            self.clearTerminal()
            self.printLines(combat.displayStatus())
            self.print("")
            self.printLines(self.asciiDodge, color: .cyan)
            self.print("")
            character.isDodging = true
            self.logMultiplayerAction("\(character.name) takes a defensive stance (Dodge)")
            self.print("\(character.name) takes a defensive stance!", color: .cyan, bold: true)
            self.print("  Enemies attacking \(character.name) have DISADVANTAGE", color: .dimGreen)
            self.print("  (they roll twice, take the worse result)", color: .dimGreen)
            combat.checkCombatEnd()
            combat.nextTurn()
            self.waitForContinue()
            self.inputHandler = { [weak self] _ in self?.advanceCombat() }
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

        showPaginatedMenu(options) { [weak self] idx in
            self?.cancelCombatIdleTimer()
            if idx >= 0 && idx < actions.count {
                actions[idx]()
            }
        }
        resetIdleTimer()
        startCombatIdleTimer(characterId: characterId)
    }

    // MARK: - Combat Idle Timer

    private func startCombatIdleTimer(characterId: UUID) {
        cancelCombatIdleTimer()
        guard idlePromptsEnabled else { return }
        combatIdleTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: false) { [weak self] _ in
            guard let self = self, let combat = self.currentCombat else { return }
            // First warning at 2 min — disadvantage on next attack
            if !self.combatHesitating {
                self.combatHesitating = true
                self.print("")
                self.print("  You hesitate... the enemy senses your indecision!", color: .red)
                self.print("  (Disadvantage on your next attack)", color: .yellow)
                self.logEvent("Combat hesitation — disadvantage applied", category: "COMBAT")

                // Second timer at 60s more — monster gets a free attack
                self.combatIdleTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: false) { [weak self] _ in
                    guard let self = self, let combat = self.currentCombat else { return }
                    let aliveMonsters = combat.encounter.aliveMonsters
                    guard let attacker = aliveMonsters.randomElement(),
                          let character = self.party.first(where: { $0.id == characterId && $0.isConscious }) else { return }

                    self.print("")
                    self.print("  \(attacker.name) seizes the opening and strikes!", color: .red, bold: true)
                    self.logEvent("\(attacker.name) free attack — player too slow", category: "COMBAT")

                    if let report = combat.monsterAttack(monsterId: attacker.id, targetId: character.id) {
                        self.displayAttackReport(report) { [weak self] in
                            guard let self = self else { return }
                            combat.checkCombatEnd()
                            if combat.state == .defeat {
                                self.handleCombatDefeat()
                            } else {
                                // Re-show the player's combat menu — still their turn
                                self.showPlayerCombatMenu(characterId: characterId)
                            }
                        }
                    } else {
                        self.showPlayerCombatMenu(characterId: characterId)
                    }
                }
            }
        }
    }

    private func cancelCombatIdleTimer() {
        combatIdleTimer?.invalidate()
        combatIdleTimer = nil
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
                self.logMultiplayerAction("The party fled from combat!")
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

                // Fleeing exhaustion — everyone loses some HP from the desperate sprint
                self.print("  The desperate sprint takes its toll...", color: .yellow)
                for char in self.party where char.isConscious {
                    let exhaustion = max(1, Dice.d4())
                    char.takeDamage(exhaustion)
                    self.print("  \(char.name) loses \(exhaustion) HP from exhaustion", color: .yellow)
                }
                self.print("")

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

                if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }

                // Let the player choose which direction to flee
                guard let dungeon = self.dungeon, let room = dungeon.currentRoom else {
                    self.showExplorationView()
                    return
                }

                self.print("Which way do you run?", color: .cyan, bold: true)
                self.print("")

                var fleeOptions: [String] = []
                var fleeDirections: [Direction] = []
                for dir in Direction.allCases {
                    if room.exits[dir] != nil && !room.secured.contains(dir) {
                        fleeOptions.append(dir.rawValue)
                        fleeDirections.append(dir)
                    }
                }
                // Add "keep running" option — run in a straight line as far as possible
                fleeOptions.append("Keep Running!")

                self.showMenu(fleeOptions)
                self.menuHandler = { [weak self] choice in
                    guard let self = self else { return }
                    let idx = choice - 1
                    if idx < fleeDirections.count {
                        // Move one room in chosen direction
                        let dir = fleeDirections[idx]
                        self.move(dir)
                    } else {
                        // Keep running — pick a random valid direction and run as far as possible
                        self.keepRunning()
                    }
                }
            } else {
                self.print("You can't escape!", color: .red, bold: true)
                self.print("The monsters block your path!")
                self.print("")

                // Monsters get a free round of attacks
                combat.nextTurn()

                self.waitForContinue()
                self.inputHandler = { [weak self] _ in
                    self?.advanceCombat()
                }
            }
        }
    }

    /// Keep running — flee in a straight line as far as possible
    private func keepRunning() {
        guard let dungeon = dungeon, let startRoom = dungeon.currentRoom else {
            showExplorationView()
            return
        }

        // Pick a random valid direction to start running
        let validDirs = Direction.allCases.filter { dir in
            startRoom.exits[dir] != nil && !startRoom.secured.contains(dir)
        }
        guard let runDir = validDirs.randomElement() else {
            showExplorationView()
            return
        }

        clearTerminal()
        print("You keep running \(runDir.rawValue.lowercased())!", color: .yellow, bold: true)
        print("")

        var roomsTraversed = 0
        var currentRoom = startRoom

        // Run in a straight line until no more exits in that direction (max 5 rooms)
        while roomsTraversed < 5 {
            guard let nextRoomId = currentRoom.exits[runDir],
                  let nextRoom = dungeon.rooms[nextRoomId],
                  !currentRoom.secured.contains(runDir) else {
                break
            }

            // Stop if there's a monster in the next room (unless it's cleared)
            if nextRoom.encounter != nil && !nextRoom.cleared {
                print("  Danger ahead — you skid to a halt!", color: .red)
                break
            }

            dungeon.currentRoom = nextRoom
            nextRoom.visited = true
            currentRoom = nextRoom
            roomsTraversed += 1
            advanceTime(2)
            print("  ...through the \(nextRoom.name.lowercased())...", color: .dimGreen)
        }

        print("")
        if roomsTraversed > 0 {
            print("You ran through \(roomsTraversed) room\(roomsTraversed == 1 ? "" : "s") \(runDir.rawValue.lowercased()).", color: .brightGreen)
            logEvent("Fled \(runDir.rawValue.lowercased()) through \(roomsTraversed) rooms", category: "COMBAT")
        } else {
            print("Nowhere to run \(runDir.rawValue.lowercased()) — you stop here.", color: .yellow)
        }

        autoReturn()
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

                    if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }
                    let shouldReturnToDM = self.returnToDMAfterCombat
                    self.returnToDMAfterCombat = false
                    self.print("")
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        if shouldReturnToDM {
                            self?.askTheDM()
                        } else {
                            self?.showExplorationView()
                        }
                    }
                } else {
                    combat.nextTurn()
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in self?.advanceCombat() }
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
                self.inputHandler = { [weak self] _ in self?.advanceCombat() }
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

        let menuOpts = spellOptions.map { $0.name }

        showPaginatedMenuOptions(menuOpts, pinned: ["Done"], handler: { [weak self] idx in
            guard idx >= 0 && idx < spellOptions.count else { return }
            let spell = spellOptions[idx]
            self?.selectSpellTarget(characterId: characterId, spell: spell)
        }, pinnedHandler: { [weak self] _ in
            self?.clearTerminal()
            self?.printLines(combat.displayStatus())
            self?.print("")
            self?.showPlayerCombatMenu(characterId: characterId)
        })
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
                options.append("\(shortName(for: char)) (\(status))")
            }
            options.append("Done")

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
        options.append("Done")

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
            self?.advanceCombat()
        }
    }

    /// ASCII art frames for spell casting animation
    private func spellCastArt(spellType: SpellType) -> [[String]] {
        switch spellType {
        case .attack:
            return [
                ["       *        ",
                 "      ***       ",
                 "     *****      ",
                 "      ***       ",
                 "       *        "],
                ["      .*.       ",
                 "     .***.      ",
                 "    .*****.     ",
                 "     .***.      ",
                 "      .*.       "],
                ["     ~ * ~      ",
                 "    ~ *** ~     ",
                 "   ~ ***** ~    ",
                 "    ~ *** ~     ",
                 "     ~ * ~      "],
            ]
        case .healing:
            return [
                ["       +        ",
                 "      +++       ",
                 "     +++++      ",
                 "      +++       ",
                 "       +        "],
                ["      .+.       ",
                 "     .+++.      ",
                 "    .+++++.     ",
                 "     .+++.      ",
                 "      .+.       "],
            ]
        default:
            return [
                ["      ~ ~       ",
                 "     ~   ~      ",
                 "    ~  o  ~     ",
                 "     ~   ~      ",
                 "      ~ ~       "],
                ["     . ~ .      ",
                 "    .     .     ",
                 "   .   O   .    ",
                 "    .     .     ",
                 "     . ~ .      "],
            ]
        }
    }

    func displaySpellReport(_ report: SpellReport, completion: @escaping () -> Void) {
        logMultiplayerSpellReport(report)

        // Show spell casting animation if hit animations are on
        if hitAnimationsEnabled {
            let artFrames = spellCastArt(spellType: report.spellType)
            let artColor: TerminalColor = report.spellType == .healing ? .brightGreen : (report.spellType == .attack ? .red : .cyan)
            let firstFrame = artFrames[0]
            printLines(firstFrame, color: artColor)
            let artStart = terminalLines.count - firstFrame.count

            // Animate through frames
            var frameIdx = 0
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
                DispatchQueue.main.async {
                    guard let self = self else { timer.invalidate(); return }
                    frameIdx += 1
                    if frameIdx >= artFrames.count * 2 {
                        timer.invalidate()
                        return
                    }
                    let frame = artFrames[frameIdx % artFrames.count]
                    for (i, line) in frame.enumerated() {
                        let lineIdx = artStart + i
                        if lineIdx < self.terminalLines.count {
                            self.terminalLines[lineIdx].text = line
                        }
                    }
                }
            }
        }

        print("\(report.casterName) casts \(report.spellName)!", color: .cyan, bold: true)
        print("")

        DispatchQueue.main.asyncAfter(deadline: .now() + (hitAnimationsEnabled ? 1.0 : 0.5)) { [weak self] in
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
        logMultiplayerAction("\(character.name) uses Second Wind — healed \(healAmount) HP (\(character.currentHP)/\(character.maxHP))")

        SoundManager.shared.playHeal()
        printLines(diceArt(healRoll), color: .brightGreen)
        print("  Healed \(healAmount) HP! (\(character.currentHP)/\(character.maxHP))", color: .brightGreen)
        print("")

        combat.checkCombatEnd()
        combat.nextTurn()

        waitForContinue()
        inputHandler = { [weak self] _ in self?.advanceCombat() }
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
        logMultiplayerAction("\(character.name) enters a RAGE!")

        combat.checkCombatEnd()
        combat.nextTurn()

        waitForContinue()
        inputHandler = { [weak self] _ in self?.advanceCombat() }
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
            self.inputHandler = { [weak self] _ in self?.advanceCombat() }
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
        logMultiplayerAction("\(character.name) reached Level \(newLevel)!")
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

    /// Characters eligible for combat loot (those who actually fought); nil = whole party
    private var combatLootEligible: [Character]?

    func handleCombatVictory() {
        cancelCombatIdleTimer()
        combatHesitating = false
        guard let combat = currentCombat else { return }
        SoundManager.shared.playVictory()
        advanceTime(30)

        // Track stats
        monstersSlain += combat.encounter.monsters.count
        combatsWon += 1

        // Identify who actually fought — exclude those who fled or played dead
        let fighters = party.filter { !$0.hasFledCombat && !$0.isPlayingDead }
        let shirkers = party.filter { $0.hasFledCombat || $0.isPlayingDead }
        combatLootEligible = fighters.isEmpty ? nil : fighters

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

        // Celebratory dragon animation
        DispatchQueue.main.async {
            self.dragonGifName = "dragon_castle"
        }

        let xp = combat.encounter.totalXP
        let rewardParty = fighters.isEmpty ? party : fighters
        let xpEach = xp / rewardParty.count

        let defeated = combat.encounter.monsters.map { $0.name }.joined(separator: ", ")
        logEvent("Victory! Defeated \(defeated) (+\(xp) XP)", category: "COMBAT")
        logMultiplayerAction("Combat victory! \(combat.encounter.monsters.count) enemies slain (+\(xp) XP)")

        // Log party HP status after battle
        for char in party where char.isConscious {
            logMultiplayerAction("\(char.name): \(char.currentHP)/\(char.maxHP) HP after battle")
        }
        for char in party where !char.isConscious {
            logMultiplayerAction("\(char.name) is unconscious!")
        }

        print("All enemies defeated!", color: .brightGreen)
        print("")
        maybeShowTip()

        if !shirkers.isEmpty {
            let names = shirkers.map { $0.name }.joined(separator: ", ")
            print("\(names) did not fight and receive no spoils.", color: .dimGreen)
            print("")
        }

        print("Experience gained: \(xp) XP (\(xpEach) each)")

        for char in rewardParty {
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
                    logMultiplayerAction("\(monster.name) dropped \(loot.value) gold")
                } else if loot.type == .potion || loot.type == .item {
                    if let item = resolveItemByName(loot.name) {
                        lootItems.append(item)
                        print("  \(monster.name) dropped \(loot.name)!", color: .brightGreen)
                        logMultiplayerAction("\(monster.name) dropped \(loot.name)!")
                    }
                }
            }
        }
        // Mark room cleared
        dungeon?.currentRoom?.cleared = true
        dungeon?.currentRoom?.encounter = nil

        // Chance for NPC to appear in cleared room (15%)
        if npcsEnabled, let room = dungeon?.currentRoom, room.npc == nil, room.roomType != .boss {
            if Int.random(in: 1...100) <= 15 {
                if let npcType = NPCType.randomFor(roomType: room.roomType) ?? NPCType.allCases.randomElement() {
                    room.npc = DungeonNPC(type: npcType)
                    print("")
                    print("A \(npcType.rawValue) emerges from the shadows...", color: .cyan)
                    logEvent("\(npcType.rawValue) appeared in \(room.name) after combat", category: "NPC")
                }
            }
        }

        // Check for boss room
        if dungeon?.currentRoom?.roomType == .boss {
            handleGameVictory()
            return
        }

        currentCombat = nil
        gameState = .exploring
        if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }

        // If this was a trap room, trigger the trap after combat
        let pendingTrap = dungeon?.currentRoom?.roomType == .trap && dungeon?.currentRoom?.trapTriggered == false
        let shouldReturnToDM = returnToDMAfterCombat
        returnToDMAfterCombat = false

        waitForContinue()
        let continueAction: () -> Void = { [weak self] in
            guard let self = self else { return }
            // Show loot pickup first, then level-ups, then back to DM or exploration
            let afterLoot = { [weak self] in
                guard let self = self else { return }
                self.combatLootEligible = nil
                self.checkAndShowLevelUp {
                    if pendingTrap, let room = self.dungeon?.currentRoom {
                        room.trapTriggered = true
                        self.triggerTrap(in: room)
                    } else if shouldReturnToDM {
                        self.askTheDM()
                    } else {
                        self.showExplorationView()
                    }
                }
            }
            self.showLootSequence(gold: lootGold, goldSource: "Combat loot",
                                  items: lootItems, itemSource: "Combat loot", onDone: afterLoot)
        }
        // Auto-continue after 3x timeout (user can tap to continue sooner)
        let victoryTimer = Timer.scheduledTimer(withTimeInterval: infoTimeout * 3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.inputHandler != nil else { return }
                continueAction()
            }
        }
        inputHandler = { _ in
            victoryTimer.invalidate()
            continueAction()
        }
    }

    func handleCombatDefeat() {
        clearAllUndoRedo()
        cancelCombatIdleTimer()
        combatHesitating = false
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

        // Set closeHandler so the X icon is always available
        closeHandler = { [weak self] in
            self?.resetGame()
        }

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

    private func handleTimeLimitExpired() {
        SoundManager.shared.stopMusic()
        SoundManager.shared.playDefeat()
        clearTerminal()
        gameState = .gameOver

        let limitText = formatTimeLimitValue(gameTimeLimit)
        logEvent("Time's up! The party ran out of time (\(limitText)).", category: "DEFEAT")

        recordHallOfFame(outcome: .defeat)

        // Set closeHandler so the X icon is always available
        closeHandler = { [weak self] in
            self?.resetGame()
        }

        printLines(asciiSkull, color: .red)
        print("")
        printTitle("TIME'S UP!")
        print("Your time has run out...", color: .red, bold: true)
        print("")
        print("The dungeon seals shut as the hourglass empties.")
        print("Your party is lost to the depths forever.")
        print("")
        print("Time limit: \(limitText)", color: .dimGreen)
        print("Game time: \(formattedGameTime())", color: .dimGreen)

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.resetGame()
        }
    }

    private func formatTimeLimitValue(_ minutes: Int) -> String {
        if minutes >= 1440 {
            let days = minutes / 1440
            return days == 1 ? "1 Day" : "\(days) Days"
        } else {
            let hours = minutes / 60
            return "\(hours) Hours"
        }
    }

    private func formatTimeRemaining(_ minutes: Int) -> String {
        if minutes <= 0 { return "0m left" }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h\(m)m left" : "\(h)h left"
        }
        return "\(m)m left"
    }

    func handleGameVictory() {
        clearAllUndoRedo()
        SoundManager.shared.stopMusic()
        SoundManager.shared.playVictory()
        clearTerminal()
        gameState = .victory

        let currentLevel = dungeon?.level ?? 1
        let dungeonName = dungeon?.name ?? "The dungeon"
        logEvent("DUNGEON CONQUERED! \(dungeonName) has been cleared!", category: "EXPLORE")

        // Record in Hall of Fame + Game Center
        recordHallOfFame(outcome: .victory)

        // Set closeHandler early so the X icon is always visible
        closeHandler = { [weak self] in
            self?.resetGame()
        }

        printLines(asciiTrophy, color: .yellow)
        print("")
        printTitle("DUNGEON CONQUERED!")
        print("You have defeated the dungeon boss!", color: .brightGreen, bold: true)
        print("")
        print("Your party emerges victorious from \(dungeonName)!")
        print("")

        // Check for gatekeeper quest reward
        if let entrance = dungeon?.rooms[0], let gk = entrance.npc, gk.type == .gatekeeper && gk.questAccepted {
            let reward = gk.questGold
            let leader = party.first
            leader?.gold += reward
            print("Quest Complete!", color: .cyan, bold: true)
            print("  The Gatekeeper rewards you with \(reward) gold!", color: .brightGreen)
            logEvent("Gatekeeper quest complete! Reward: \(reward) gold", category: "QUEST")
            print("")
        }

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

        // No auto-dismiss — victory is a major milestone, let the player read it
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
            self.print("Your party descends deeper into \(dungeonName)...", color: .cyan)
            self.print("")
            self.print("The air grows heavier. Stronger foes await.", color: .dimGreen)
            self.print("")

            if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.clearTerminal()
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
        case settings
    }

    func showSaveMenu() {
        clearTerminal()
        printTitle("Save/Quit")
        startSaveMenuIdleTimer()

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

            // Help text
            print("  Save: save and continue playing", color: .dimGreen)
            print("  Quit+Save: save and exit to menu", color: .dimGreen)
            print("  Quit-Save: exit without saving", color: .dimGreen)
            print("")

            var options: [String] = []
            options.append("Save")              // 1
            options.append("Quit+Save")         // 2
            if slots.count < SaveGameManager.maxSlots {
                options.append("Save+NewName")   // 3
                options.append("Quit-Save")     // 4
                options.append("Main Menu")     // 5
                options.append("Info")          // 6
            } else {
                options.append("Quit-Save")     // 3
                options.append("Main Menu")     // 4
            }

            showMenu(options)
            closeHandler = { [weak self] in
                self?.closeHandler = nil
                self?.cancelSaveMenuIdleTimer()
                self?.showExplorationView()
            }
            menuHandler = { [weak self] choice in
                guard let self = self, choice >= 1 && choice <= options.count else { return }
                self.cancelSaveMenuIdleTimer()
                let selected = options[choice - 1]
                switch selected {
                case "Save":
                    self.performSave(slotId: self.activeSlotId!, slotName: slotName)
                case "Quit+Save":
                    self.confirmQuitAndSave(slotId: self.activeSlotId!, slotName: slotName)
                case "Save+NewName":
                    self.askForNewSlotName()
                case "Quit-Save":
                    self.confirmQuitWithoutSaving()
                case "Main Menu":
                    self.confirmExitToMainMenu()
                case "Info":
                    self.showSaveInfo()
                default:
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

    // MARK: Save Menu Idle Timer

    private func startSaveMenuIdleTimer() {
        saveMenuIdleTimer?.invalidate()
        saveMenuNagCount = 0
        guard idlePromptsEnabled else { return }
        saveMenuIdleTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.saveMenuIdleNag()
            }
        }
    }

    private func cancelSaveMenuIdleTimer() {
        saveMenuIdleTimer?.invalidate()
        saveMenuIdleTimer = nil
    }

    private func saveMenuIdleNag() {
        saveMenuNagCount += 1

        let nags: [(String, [String])] = [
            ("The DM taps the table impatiently...",
             ["    ╭─────╮",
              "    │ -_- │",
              "    │  >  │",
              "    ╰──┬──╯",
              "     ╱│╲",
              "      │",
              "     ╱ ╲"]),
            ("\"Whilst you deliberate, the dungeon grows restless...\"",
             ["    ╭─────╮",
              "    │ o_o │",
              "    │  ~  │",
              "    ╰──┬──╯",
              "    ╱╱│╲╲",
              "      │",
              "     ╱ ╲"]),
            ("The DM glances at a pocket watch.",
             ["    ╭─────╮",
              "    │ ¬_¬ │",
              "    │  .  │",
              "    ╰──┬──╯",
              "     ╲│  ◔",
              "      │",
              "     ╱ ╲"]),
            ("\"The monsters aren't going to slay themselves, you know.\"",
             ["    ╭─────╮",
              "    │ >_< │",
              "    │  o  │",
              "    ╰──┬──╯",
              "     ╱│╲",
              "      │",
              "     ╱ ╲"]),
            ("The DM starts rolling dice menacingly...",
             ["    ╭─────╮",
              "    │ ●_● │",
              "    │  ▽  │",
              "    ╰──┬──╯",
              "     ╱│╲ 🎲",
              "      │",
              "     ╱ ╲"]),
            ("\"I haven't got all day. Well, actually I have. But still.\"",
             ["    ╭─────╮",
              "    │ -_- │",
              "    │  ω  │",
              "    ╰──┬──╯",
              "    ╱╱ │ ╲╲",
              "       │",
              "      ╱ ╲"]),
        ]

        let index = (saveMenuNagCount - 1) % nags.count
        let (text, art) = nags[index]

        print("")
        for line in art {
            print(line, color: .dimGreen)
        }
        print("")
        print("  \(text)", color: .yellow)
        print("  [\(formattedGameTime())]", color: .dimGreen)
    }

    private func showSaveInfo() {
        clearTerminal()
        printTitle("Save Info")
        print("")

        // --- Last saved ---
        print("  LAST SAVED", color: .cyan, bold: true)
        if let slotId = activeSlotId {
            let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slotId)
            if let latest = breakpoints.first {
                let elapsed = Date().timeIntervalSince(latest.savedAt)
                let mins = Int(elapsed) / 60
                let timeAgo: String
                let timeColor: TerminalColor
                if mins < 1 {
                    timeAgo = "Just now"
                    timeColor = .brightGreen
                } else if mins < 60 {
                    timeAgo = "\(mins) min ago"
                    timeColor = mins > 15 ? .yellow : .brightGreen
                } else {
                    let hrs = mins / 60
                    timeAgo = "\(hrs)h \(mins % 60)m ago"
                    timeColor = .red
                }
                printWrapped(timeAgo, indent: 4, color: timeColor)
            } else {
                printWrapped("No saves yet.", indent: 4, color: .yellow)
            }
        } else {
            printWrapped("No saves yet for this adventure.", indent: 4, color: .yellow)
            printWrapped("You should save soon!", indent: 4, color: .yellow)
        }
        print("")

        // --- Recent saves ---
        if let slotId = activeSlotId {
            let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slotId)
            if !breakpoints.isEmpty {
                print("  RECENT SAVES", color: .cyan, bold: true)
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                for (i, bp) in breakpoints.prefix(3).enumerated() {
                    let dateStr = dateFormatter.string(from: bp.savedAt)
                    let day = bp.gameTimeMinutes / 1440 + 1
                    let label = i == 0 ? " (latest)" : ""
                    printWrapped("Day \(day) — \(bp.dungeonName) Lv\(bp.dungeonLevel)\(label)", indent: 4, color: .dimGreen)
                    printWrapped(dateStr, indent: 6, color: .gray)
                }
                print("")
            }
        }

        // --- Run stats ---
        print("  RUN STATS", color: .cyan, bold: true)
        let day = gameTimeMinutes / 1440 + 1
        let hourOfDay = (gameTimeMinutes % 1440) / 60
        let period = hourOfDay >= 12 ? "PM" : "AM"
        let hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay)
        printWrapped("Game time: Day \(day), \(hour12) \(period)", indent: 4, color: .dimGreen)
        printWrapped("Monsters slain: \(monstersSlain)", indent: 4, color: .dimGreen)
        printWrapped("Combats won: \(combatsWon)", indent: 4, color: .dimGreen)
        let totalGold = party.reduce(0) { $0 + $1.gold }
        printWrapped("Party gold: \(totalGold)", indent: 4, color: .dimGreen)
        if let dungeon = dungeon {
            let explored = dungeon.rooms.values.filter { $0.visited }.count
            printWrapped("Rooms explored: \(explored)/\(dungeon.rooms.count)", indent: 4, color: .dimGreen)
            printWrapped("Dungeon level: \(dungeon.level)", indent: 4, color: .dimGreen)
        }
        print("")

        // --- Torch ---
        print("  TORCH", color: .cyan, bold: true)
        let torches = party.flatMap { $0.inventory }.filter { $0.isTorch }
        if torchLit {
            let h = torchTurnsRemaining / 60
            let m = torchTurnsRemaining % 60
            printWrapped("Lit (\(h)h \(m)m remaining)", indent: 4, color: .yellow)
        } else if torches.isEmpty {
            printWrapped("None! Buy from Merchant.", indent: 4, color: .red)
        } else {
            printWrapped("\(torches.count) in packs (unlit)", indent: 4, color: .dimGreen)
        }
        print("")

        // --- Party summary ---
        print("  PARTY", color: .cyan, bold: true)
        for char in party {
            let hpPct = char.maxHP > 0 ? (char.currentHP * 100 / char.maxHP) : 0
            let hpColor: TerminalColor = hpPct > 50 ? .brightGreen : (hpPct > 25 ? .yellow : .red)
            printWrapped("\(char.name) (\(char.characterClass.rawValue) Lv\(char.level))", indent: 4, color: hpColor)
            printWrapped("HP \(char.currentHP)/\(char.maxHP)  Gold \(char.gold)  Items \(char.inventory.count)/\(Character.maxInventorySlots)", indent: 6, color: .dimGreen)
        }
        print("")

        closeHandler = { [weak self] in
            self?.showSaveMenu()
        }
    }

    static let maxSlotNameLength = 20

    private func askForNewSlotName() {
        let rawDefault = "\(party.first?.name ?? "Unknown") — \(dungeon?.name ?? "Dungeon")"
        let defaultName = String(rawDefault.prefix(Self.maxSlotNameLength))
        promptTextWithMenu("Enter a name, or use default:", options: [defaultName])

        closeHandler = { [weak self] in
            self?.showExplorationView()
        }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                let slotName = self.uniqueSlotName(defaultName)
                let slotId = UUID()
                self.performSave(slotId: slotId, slotName: slotName)
            }
        }

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

            let baseName: String
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                baseName = defaultName
            } else {
                baseName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxSlotNameLength))
            }

            let slotName = self.uniqueSlotName(baseName)
            let newSlotId = UUID()
            self.activeSlotId = newSlotId
            self.activeSlotName = slotName
            self.performSave(slotId: newSlotId, slotName: slotName)
        }
    }

    /// Returns a unique slot name, truncated to fit buttons. Appends " 002" etc. if a duplicate exists.
    private func uniqueSlotName(_ baseName: String) -> String {
        let maxLen = Self.maxSlotNameLength
        let truncated = String(baseName.prefix(maxLen))
        let existingNames = Set(SaveGameManager.shared.listSlots().map { $0.slotName })
        if !existingNames.contains(truncated) { return truncated }

        for n in 2...999 {
            let suffix = String(format: " %03d", n)
            let base = String(truncated.prefix(maxLen - suffix.count))
            let candidate = base + suffix
            if !existingNames.contains(candidate) { return candidate }
        }
        return String((truncated + " \(UUID().uuidString.prefix(4))").prefix(maxLen))
    }

    private func showOverwriteSlotMenu(slots: [SaveSlot]) {
        print("All \(SaveGameManager.maxSlots) adventure slots are full.", color: .yellow)
        print("Choose an adventure to replace:", color: .cyan)
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
        options.append("Done")

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

            self.showMenu(["Yes, Replace", "Different Slot", "Done"])
            self.menuHandler = { [weak self] confirm in
                guard let self = self else { return }
                switch confirm {
                case 1:
                    SaveGameManager.shared.deleteSlot(slotId: selected.slotId)
                    self.askForNewSlotName()
                case 2:
                    self.clearTerminal()
                    self.printTitle("Save/Quit")
                    self.showOverwriteSlotMenu(slots: slots)
                default:
                    self.showExplorationView()
                }
            }
        }
    }

    /// Quick save to active slot (or auto-create) and return to exploration
    private func performQuickSave() {
        guard let dungeon = dungeon else {
            explorationStatusMessage = ("Nothing to save.", .red)
            showExplorationView()
            return
        }

        let slotId: UUID
        let slotName: String
        if let existingId = activeSlotId {
            slotId = existingId
            slotName = activeSlotName ?? "\(party.first?.name ?? "Hero") — \(dungeon.name)"
        } else {
            slotId = UUID()
            slotName = "\(party.first?.name ?? "Hero") — \(dungeon.name)"
            activeSlotId = slotId
            activeSlotName = slotName
        }

        let partyDesc = party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", ")
        let chatEntries = dmChatLog.map { DMChatEntry(isUser: $0.isUser, text: $0.text) }
        let saveGame = SaveGame(
            id: UUID(), slotId: slotId, savedAt: Date(), slotName: slotName,
            partyDescription: partyDesc, dungeonName: dungeon.name, dungeonLevel: dungeon.level,
            party: party, dungeon: dungeon, gameState: .exploring,
            gameTimeMinutes: gameTimeMinutes, adventureLog: adventureLog,
            dmChatLog: chatEntries, torchLit: torchLit,
            torchTurnsRemaining: torchTurnsRemaining,
            partyChatLog: partyChatLog.suffix(20).map { $0 },
            monstersSlain: monstersSlain,
            combatsWon: combatsWon
        )

        do {
            try SaveGameManager.shared.save(saveGame)
            SoundManager.shared.playSave()
            logEvent("Quick save: \(slotName)", category: "SYSTEM")
            explorationStatusMessage = ("Game saved!", .brightGreen)
        } catch {
            explorationStatusMessage = ("Save failed: \(error.localizedDescription)", .red)
        }
        showExplorationView()
    }

    private func performSave(slotId: UUID, slotName: String) {
        guard let dungeon = dungeon else { return }

        // If saving during combat, clear the current room's encounter so
        // loading won't immediately throw the player back into battle.
        if gameState == .combat, let room = dungeon.currentRoom, !room.cleared {
            room.cleared = true
            room.encounter = nil
        }

        let partyDesc = party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", ")

        logEvent("Game saved: \(slotName)", category: "SYSTEM")

        let chatEntries = dmChatLog.map { DMChatEntry(isUser: $0.isUser, text: $0.text) }
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
            dmChatLog: chatEntries,
            torchLit: torchLit,
            torchTurnsRemaining: torchTurnsRemaining,
            partyChatLog: partyChatLog.suffix(20).map { $0 },
            monstersSlain: monstersSlain,
            combatsWon: combatsWon
        )

        do {
            try SaveGameManager.shared.save(saveGame)
            lastSaveTime = Date()
            SoundManager.shared.playSave()
            printLines(asciiScroll, color: .brightGreen)
            print("")
            print("Game saved!", color: .brightGreen, bold: true)
            print("")
            print("  \(slotName)", color: .cyan)
            print("  \(partyDesc)", color: .dimGreen)
            print("  \(dungeon.name) (Level \(dungeon.level))", color: .dimGreen)

            let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slotId)
            let slotCount = SaveGameManager.shared.listSlots().count
            print("")
            let bpWord = breakpoints.count == 1 ? "save" : "saves"
            print("  \(breakpoints.count) \(bpWord) in this adventure", color: .dimGreen)
            print("  \(slotCount)/\(SaveGameManager.maxSlots) adventures saved", color: .dimGreen)
        } catch {
            print("Failed to save: \(error.localizedDescription)", color: .red)
        }

        print("")

        showMenu(["Continue", "Load Game", "Main Menu"])

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

            closeHandler = { [weak self] in
                switch origin {
                case .mainMenu:
                    self?.clearTerminal()
                    self?.showMainMenu()
                case .exploration:
                    self?.showExplorationView()
                case .settings:
                    self?.showSaveSettings()
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

        var options = slots.map { slot -> String in
            let parts = slot.slotName.components(separatedBy: " — ")
            let charName = parts.first ?? slot.slotName
            let location = slot.latest.dungeonName
            let maxLen = 20
            if charName.count + location.count + 3 <= maxLen {
                return "\(charName) · \(location)"
            } else {
                let locBudget = max(4, maxLen - charName.count - 3)
                return "\(charName) · \(location.prefix(locBudget))"
            }
        }
        options.append("Manage Saves")

        showMenu(options)

        closeHandler = { [weak self] in
            switch origin {
            case .mainMenu:
                self?.clearTerminal()
                self?.showMainMenu()
            case .exploration:
                self?.showExplorationView()
            case .settings:
                self?.showSaveSettings()
            }
        }

        menuHandler = { [weak self] choice in
            if choice == options.count {
                self?.showManageSavesMenu(returnTo: origin)
                return
            }

            guard choice > 0 && choice <= slots.count else { return }
            let slot = slots[choice - 1]

            if slot.breakpointCount > 1 {
                self?.showBreakpointMenu(slot: slot, returnTo: origin)
            } else {
                self?.loadGame(slot.latest)
            }
        }

        // Long-press → load latest save directly (skip breakpoint menu)
        menuLongPressHandler = { [weak self] choice in
            guard choice > 0 && choice <= slots.count else { return }
            self?.loadGame(slots[choice - 1].latest)
        }
    }

    private func showBreakpointMenu(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle(slot.slotName)
        print("Select a save to load:", color: .cyan)
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

        let options = breakpoints.enumerated().map { i, _ in
            i == 0 ? "Load Latest" : "Load #\(i + 1)"
        }

        showMenu(options)

        closeHandler = { [weak self] in self?.showLoadGameMenu(returnTo: origin) }
        menuHandler = { [weak self] choice in
            guard choice > 0 && choice <= breakpoints.count else { return }
            self?.loadGame(breakpoints[choice - 1])
        }
    }

    private func showManageSavesMenu(returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle("Manage Saves")

        let slots = SaveGameManager.shared.listSlots()

        // Load remote matches asynchronously, then render the full menu
        if multiplayerEnabled && GameCenterManager.shared.isAuthenticated {
            print("Loading remote games...", color: .dimGreen)
            Task {
                let matches = (try? await GKTurnBasedMatch.loadMatches()) ?? []
                let activeMatches = matches.filter { $0.status == .open || $0.status == .matching }
                await MainActor.run {
                    self.renderManageSavesMenu(slots: slots, remoteMatches: activeMatches, returnTo: origin)
                }
            }
        } else {
            renderManageSavesMenu(slots: slots, remoteMatches: [], returnTo: origin)
        }
    }

    private func renderManageSavesMenu(slots: [SaveSlot], remoteMatches: [GKTurnBasedMatch], returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle("Manage Saves")

        let hasLocalSlots = !slots.isEmpty
        let hasRemoteMatches = !remoteMatches.isEmpty

        if !hasLocalSlots && !hasRemoteMatches {
            print("No saved games to manage.", color: .yellow)
            print("")
            print("Start an adventure first!", color: .dimGreen)
            let goBack: () -> Void = { [weak self] in
                switch origin {
                case .mainMenu: self?.showPlayMenu()
                case .exploration: self?.showExplorationView()
                case .settings: self?.showSettings()
                }
            }
            waitForContinue()
            inputHandler = { _ in goBack() }
            closeHandler = goBack
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        // List local save slots
        if hasLocalSlots {
            print("Local Saves", color: .cyan, bold: true)
            print("")
            for (index, slot) in slots.enumerated() {
                let dateStr = dateFormatter.string(from: slot.latest.savedAt)
                let bpInfo = slot.breakpointCount > 1 ? " (\(slot.breakpointCount) saves)" : ""
                print("\(index + 1). \(slot.slotName)\(bpInfo)", color: .brightGreen)
                print("   \(slot.latest.partyDescription)", color: .dimGreen)
                print("   \(dateStr)", color: .dimGreen)
                print("")
            }
        }

        // List remote multiplayer matches
        if hasRemoteMatches {
            print("Remote Games", color: .cyan, bold: true)
            print("")
            for (index, match) in remoteMatches.enumerated() {
                let opponentName = remoteMatchOpponentName(match)
                let phaseStr = remoteMatchPhaseString(match)
                let num = slots.count + index + 1
                print("\(num). vs. \(opponentName)", color: .brightGreen)
                print("   \(phaseStr)", color: .dimGreen)
                print("")
            }
        }

        // Build menu options
        var options: [String] = []
        var actions: [() -> Void] = []

        for slot in slots {
            options.append(slot.slotName)
            actions.append { [weak self] in
                self?.showSlotActions(slot: slot, returnTo: origin)
            }
        }

        for match in remoteMatches {
            let opponentName = remoteMatchOpponentName(match)
            options.append("vs. \(opponentName)")
            actions.append { [weak self] in
                self?.showRemoteMatchActions(match: match, returnTo: origin)
            }
        }

        if remoteMatches.count >= 2 {
            options.append("Delete All Remote Games")
            actions.append { [weak self] in
                self?.confirmDeleteAllRemoteMatches(matches: remoteMatches, returnTo: origin)
            }
        }

        print("Select a slot to manage:", color: .cyan)
        showMenu(options)

        closeHandler = { [weak self] in self?.showLoadGameMenu(returnTo: origin) }
        menuHandler = { choice in
            guard choice >= 1 && choice <= actions.count else { return }
            actions[choice - 1]()
        }
    }

    // MARK: - Remote Match Helpers

    private func remoteMatchOpponentName(_ match: GKTurnBasedMatch) -> String {
        let localID = GKLocalPlayer.local.gamePlayerID
        let opponent = match.participants.first(where: { $0.player?.gamePlayerID != localID })
        return opponent?.player?.displayName ?? "Unknown Player"
    }

    private func remoteMatchPhaseString(_ match: GKTurnBasedMatch) -> String {
        if match.status == .matching { return "Pending Invite" }
        guard let data = match.matchData, !data.isEmpty,
              let state = try? MultiplayerMatchState.decoded(from: data) else {
            return "Remote Game"
        }
        switch state.phase {
        case .characterCreation: return "Character Creation"
        case .exploring: return "Exploring — Level \(state.dungeonLevel)"
        case .combat: return "In Combat — Level \(state.dungeonLevel)"
        case .victory: return "Victory!"
        case .gameOver: return "Game Over"
        case .abandoned: return "Abandoned"
        }
    }

    // MARK: - Remote Match Actions

    private func showRemoteMatchActions(match: GKTurnBasedMatch, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        let opponentName = remoteMatchOpponentName(match)
        printSubtitle("vs. \(opponentName)")
        print("  \(remoteMatchPhaseString(match))", color: .dimGreen)
        print("")

        showMenu(["Delete Match"])

        closeHandler = { [weak self] in self?.showManageSavesMenu(returnTo: origin) }
        menuHandler = { [weak self] choice in
            if choice == 1 { self?.confirmDeleteRemoteMatch(match: match, returnTo: origin) }
        }
    }

    private func confirmDeleteRemoteMatch(match: GKTurnBasedMatch, returnTo origin: LoadGameOrigin) {
        let opponentName = remoteMatchOpponentName(match)
        print("")
        print("Delete this remote game with \(opponentName)?", color: .red, bold: true)
        print("The other player will be notified.", color: .yellow)
        print("")

        showMenu(["Yes, Delete", "No, Keep It"])

        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.executeDeleteRemoteMatch(match) {
                    self?.print("")
                    self?.print("Match deleted.", color: .red)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.showManageSavesMenu(returnTo: origin)
                    }
                }
            } else {
                self?.showRemoteMatchActions(match: match, returnTo: origin)
            }
        }
    }

    private func confirmDeleteAllRemoteMatches(matches: [GKTurnBasedMatch], returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle("Delete All Remote Games")
        print("")
        print("Delete all \(matches.count) remote games?", color: .red, bold: true)
        print("All other players will be notified.", color: .yellow)
        print("")

        showMenu(["Yes, Delete All", "No, Keep Them"])

        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.executeDeleteAllRemoteMatches(matches) {
                    self?.print("")
                    self?.print("All remote games deleted.", color: .red)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.showManageSavesMenu(returnTo: origin)
                    }
                }
            } else {
                self?.showManageSavesMenu(returnTo: origin)
            }
        }
    }

    private func executeDeleteRemoteMatch(_ match: GKTurnBasedMatch, completion: @escaping () -> Void) {
        Task {
            do {
                // Pending invites — decline and remove
                if match.status == .matching {
                    try? await match.declineInvite()
                    try? await match.remove()
                    await MainActor.run { completion() }
                    return
                }

                let hasOtherPlayers = match.participants.contains {
                    $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID && $0.status != .done
                }

                if hasOtherPlayers {
                    // Decode state, mark our character as AI, set phase to abandoned
                    if let data = match.matchData, !data.isEmpty,
                       var state = try? MultiplayerMatchState.decoded(from: data) {
                        state.relinkCombat()

                        if let slotIdx = state.players.firstIndex(where: { $0.gamePlayerID == self.localPlayerID }),
                           let charId = state.players[slotIdx].characterId,
                           let char = state.party.first(where: { $0.id == charId }) {
                            char.markAsAI()
                            state.addAction(
                                playerName: GKLocalPlayer.local.displayName,
                                description: "\(char.name) is now AI-controlled (player left)")
                        }
                        state.phase = .abandoned

                        if match.currentParticipant?.player == GKLocalPlayer.local {
                            let others = match.participants.filter {
                                $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID && $0.status != .done
                            }
                            if !others.isEmpty {
                                if let nextPlayer = others.first?.player?.gamePlayerID {
                                    state.activePlayerID = nextPlayer
                                }
                                var trimmed = state
                                trimmed.trimForTransfer()
                                let stateData = try trimmed.encoded()
                                try await match.participantQuitInTurn(
                                    with: .quit,
                                    nextParticipants: others,
                                    turnTimeout: GKTurnTimeoutDefault,
                                    match: stateData
                                )
                            } else {
                                for p in match.participants { p.matchOutcome = .quit }
                                try await match.endMatchInTurn(withMatch: match.matchData ?? Data())
                            }
                        } else {
                            // Not our turn — save the abandoned state, then quit out of turn
                            var trimmed = state
                            trimmed.trimForTransfer()
                            let stateData = try trimmed.encoded()
                            try await match.saveCurrentTurn(withMatch: stateData)
                            try await match.participantQuitOutOfTurn(with: .quit)
                        }
                    } else {
                        // No decodable state — just quit
                        if match.currentParticipant?.player == GKLocalPlayer.local {
                            let others = match.participants.filter { $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
                            try await match.participantQuitInTurn(
                                with: .quit,
                                nextParticipants: others,
                                turnTimeout: GKTurnTimeoutDefault,
                                match: match.matchData ?? Data()
                            )
                        } else {
                            try await match.participantQuitOutOfTurn(with: .quit)
                        }
                    }
                } else {
                    // Solo or no other active players — end and remove
                    for p in match.participants { p.matchOutcome = .quit }
                    if match.currentParticipant?.player == GKLocalPlayer.local {
                        try await match.endMatchInTurn(withMatch: match.matchData ?? Data())
                    }
                    try? await match.remove()
                }

                // Clear local multiplayer state if this was the active match
                await MainActor.run {
                    if GameCenterManager.shared.currentMatch?.matchID == match.matchID {
                        self.isMultiplayer = false
                        self.multiplayerState = nil
                        GameCenterManager.shared.currentMatch = nil
                    }
                    completion()
                }
            } catch {
                // Force remove on any error
                try? await match.remove()
                await MainActor.run {
                    if GameCenterManager.shared.currentMatch?.matchID == match.matchID {
                        self.isMultiplayer = false
                        self.multiplayerState = nil
                        GameCenterManager.shared.currentMatch = nil
                    }
                    completion()
                }
            }
        }
    }

    private func executeDeleteAllRemoteMatches(_ matches: [GKTurnBasedMatch], completion: @escaping () -> Void) {
        Task {
            for match in matches {
                await withCheckedContinuation { cont in
                    executeDeleteRemoteMatch(match) {
                        cont.resume()
                    }
                }
            }
            await MainActor.run { completion() }
        }
    }

    private func showSlotActions(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printSubtitle(slot.slotName)
        print("  \(slot.latest.partyDescription)", color: .dimGreen)
        print("  \(slot.latest.dungeonName) (Level \(slot.latest.dungeonLevel))", color: .dimGreen)
        let saveWord = slot.breakpointCount == 1 ? "save" : "saves"
        print("  \(slot.breakpointCount) \(saveWord)", color: .dimGreen)
        print("")

        var options = ["Delete Adventure"]
        options.append("Rename")
        if slot.breakpointCount > 1 {
            options.append("View Saves (\(slot.breakpointCount))")
        }

        showMenu(options)

        closeHandler = { [weak self] in
            self?.showManageSavesMenu(returnTo: origin)
        }
        menuHandler = { [weak self] choice in
            guard choice >= 1 && choice <= options.count else { return }
            let picked = options[choice - 1]
            if picked == "Rename" {
                self?.renameSlot(slot: slot, returnTo: origin)
            } else if picked.hasPrefix("View Saves") {
                self?.showBreakpointList(slot: slot, returnTo: origin)
            } else if picked == "Delete Adventure" {
                self?.confirmDeleteSlot(slot: slot, returnTo: origin)
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
                    dmChatLog: bp.dmChatLog,
                    torchLit: bp.torchLit,
                    torchTurnsRemaining: bp.torchTurnsRemaining,
                    partyChatLog: bp.partyChatLog,
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showManageSavesMenu(returnTo: origin)
            }
        }
    }

    private func showBreakpointList(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printSubtitle(slot.slotName)

        let breakpoints = SaveGameManager.shared.listBreakpoints(slotId: slot.slotId)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for (i, bp) in breakpoints.enumerated() {
            let dateStr = dateFormatter.string(from: bp.savedAt)
            let label = i == 0 ? " (latest)" : ""
            print("\(i + 1). \(dateStr)\(label)", color: .brightGreen)
            print("   \(bp.partyDescription)", color: .dimGreen)
            print("   \(bp.dungeonName) (Level \(bp.dungeonLevel))", color: .dimGreen)
            print("")
        }

        print("Select a save to delete:", color: .cyan)

        let options = breakpoints.enumerated().map { (i, bp) in
            let dateStr = dateFormatter.string(from: bp.savedAt)
            return "Delete \(i + 1). \(dateStr)"
        }

        showMenu(options)

        closeHandler = { [weak self] in
            self?.showSlotActions(slot: slot, returnTo: origin)
        }
        menuHandler = { [weak self] choice in
            guard choice >= 1 && choice <= options.count else { return }
            let bp = breakpoints[choice - 1]
            self?.confirmDeleteBreakpoint(bp, slot: slot, isLast: breakpoints.count == 1, returnTo: origin)
        }
    }

    private func confirmDeleteBreakpoint(_ bp: SaveGame, slot: SaveSlot, isLast: Bool, returnTo origin: LoadGameOrigin) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateStr = dateFormatter.string(from: bp.savedAt)

        print("")
        print("Delete save from \(dateStr)?", color: .red, bold: true)
        if isLast {
            print("This is the only save — deleting it removes the adventure.", color: .yellow)
        }
        print("")

        showMenu(["Yes, Delete", "No, Keep It"])

        menuHandler = { [weak self] choice in
            if choice == 1 {
                SaveGameManager.shared.delete(id: bp.id)
                if self?.activeSlotId == slot.slotId && isLast {
                    self?.activeSlotId = nil
                    self?.activeSlotName = nil
                }
                self?.print("")
                self?.print("Save deleted.", color: .red)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    let remaining = SaveGameManager.shared.listBreakpoints(slotId: slot.slotId)
                    if remaining.isEmpty {
                        self?.showManageSavesMenu(returnTo: origin)
                    } else {
                        let updated = SaveSlot(
                            slotId: slot.slotId,
                            slotName: slot.slotName,
                            latest: remaining.first!,
                            breakpointCount: remaining.count
                        )
                        self?.showBreakpointList(slot: updated, returnTo: origin)
                    }
                }
            } else {
                // Refresh slot in case something changed
                let remaining = SaveGameManager.shared.listBreakpoints(slotId: slot.slotId)
                let updated = SaveSlot(
                    slotId: slot.slotId,
                    slotName: slot.slotName,
                    latest: remaining.first ?? slot.latest,
                    breakpointCount: remaining.count
                )
                self?.showBreakpointList(slot: updated, returnTo: origin)
            }
        }
    }

    private func confirmDeleteSlot(slot: SaveSlot, returnTo origin: LoadGameOrigin) {
        print("")
        let saveWord = slot.breakpointCount == 1 ? "save" : "saves"
        print("Delete '\(slot.slotName)'?", color: .red, bold: true)
        print("This will delete all \(slot.breakpointCount) \(saveWord) for this adventure.", color: .yellow)
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
                self?.print("Adventure deleted.", color: .red)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
        // Restore torch state — if not saved, auto-light if anyone has a torch
        if let savedTorchLit = save.torchLit {
            torchLit = savedTorchLit
        } else {
            torchLit = partyHasTorch()
        }
        if let savedTurns = save.torchTurnsRemaining, savedTurns > 0 {
            torchTurnsRemaining = savedTurns
        } else if torchLit {
            torchTurnsRemaining = Item.torchFullLife
        } else {
            torchTurnsRemaining = 0
        }
        partyChatLog = save.partyChatLog ?? []

        // Reconnect active torch — find a torch with matching or closest life
        if torchLit, let (holder, torch) = findBestTorch() {
            activeTorchId = torch.id
            torchHolderId = holder.id
        } else {
            activeTorchId = nil
            torchHolderId = nil
        }

        // Restore DM chat log and seed AI conversation history
        if let savedChat = save.dmChatLog {
            dmChatLog = savedChat.map { (isUser: $0.isUser, text: $0.text) }
            DMEngine.shared.restoreHistory(from: savedChat)
        } else {
            dmChatLog = []
            DMEngine.shared.clearHistory()
        }

        // Track the loaded slot for future saves/autosaves
        activeSlotId = save.slotId
        activeSlotName = save.slotName

        // Reroll encounters so monsters are different each load
        dungeon?.rerollEncounters()

        logEvent("Game loaded: \(save.slotName)", category: "SYSTEM")
        if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }

        clearTerminal()
        print("Game loaded!", color: .brightGreen, bold: true)
        print("")
        print("Welcome back to \(save.dungeonName).", color: .cyan)
        print("Time: \(formattedGameTime())", color: .dimGreen)
        print("")

        autoReturn(after: 1.0)
    }

    private func confirmQuitAndSave(slotId: UUID, slotName: String) {
        clearTerminal()
        printTitle("Save & Quit")
        print("")
        print("Your adventure will be saved and", color: .yellow)
        print("you'll return to the main menu.", color: .yellow)
        print("")
        print("Save: \(slotName)", color: .dimGreen)
        print("")

        showMenu(["Yes, Save & Quit", "No, Keep Playing"], defaultIndex: 1)
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.performSave(slotId: slotId, slotName: slotName)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.performQuit()
                }
            } else {
                self.showExplorationView()
            }
        }
    }

    private func confirmQuitAfterRecentSave(slotId: UUID, slotName: String) {
        clearTerminal()
        printTitle("Quit?")
        print("")
        print("Game was saved moments ago.", color: .green)
        print("  \(slotName)", color: .dimGreen)
        print("")

        showMenu(["Quit", "Keep Playing", "Save Again"], defaultIndex: 1)
        closeHandler = { [weak self] in self?.showExplorationView() }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1: self.performQuit()
            case 3: self.showSaveMenu()
            default: self.showExplorationView()
            }
        }
    }

    private func confirmQuitWithoutSaving() {
        clearTerminal()
        print("Quit Without Saving?", color: .yellow, bold: true)
        print("")
        print("Unsaved progress will be lost.", color: .red)
        print("")

        showMenu(["Yes, Quit", "No, Stay"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.performQuit()
            } else {
                self?.showExplorationView()
            }
        }
    }

    func confirmExitToMainMenu() {
        clearTerminal()
        print("Return to Main Menu?", color: .yellow, bold: true)
        print("")
        print("Unsaved progress will be lost.", color: .red)
        print("")

        showMenu(["Yes, Main Menu", "No, Stay"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.resetGame()
            } else {
                self?.showExplorationView()
            }
        }
    }

    /// Fallback exit for victory/defeat/combat when closeHandler has been lost
    func emergencyExit() {
        if gameState == .victory || gameState == .gameOver {
            resetGame()
        } else if gameState == .combat {
            // Return to exploration if possible, otherwise reset
            if dungeon != nil && !party.isEmpty {
                currentCombat = nil
                gameState = .exploring
                showExplorationView()
            } else {
                resetGame()
            }
        } else {
            resetGame()
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
        torchLit = false
        torchTurnsRemaining = 0
        activeTorchId = nil
        torchHolderId = nil
        difficultyScale = 1.0
        showMainMenu()
    }

    func quitApp() {
        // If there's an active game that could be saved, offer to save first
        let hasUnsavedGame = dungeon != nil && !party.isEmpty && !isMultiplayer
        if hasUnsavedGame {
            clearTerminal()
            printTitle("Quit")
            print("You have an active adventure.", color: .yellow)
            print("Would you like to save before", color: .yellow)
            print("leaving?", color: .yellow)
            print("")

            showMenu(["Quit+Save", "Quit-Save", "Cancel"])
            menuHandler = { [weak self] choice in
                guard let self = self else { return }
                switch choice {
                case 1:
                    self.showSaveMenu()
                case 2:
                    self.performQuit()
                default:
                    self.showMainMenu()
                }
            }
            return
        }

        performQuit()
    }

    /// Timer for twinkling farewell stars
    private var starTwinkleTimer: Timer?
    /// Indices into terminalLines that hold star rows
    private var starLineIndices: [Int] = []

    private func randomStarLine(width: Int) -> String {
        let stars: [String] = ["·", "✦", "✧", "★", "☆", "*", "°", "∙"]
        var chars = Array(repeating: " ", count: width)
        let numStars = Int.random(in: 3...6)
        for _ in 0..<numStars {
            let pos = Int.random(in: 0..<width)
            chars[pos] = stars.randomElement()!
        }
        return chars.joined()
    }

    private func performQuit() {
        SoundManager.shared.stopMusic()
        SoundManager.shared.playQuit()
        clearTerminal()

        let w = 34

        // Star field (top)
        var starIndices: [Int] = []
        for _ in 0..<4 {
            starIndices.append(terminalLines.count)
            print(randomStarLine(width: w), color: .dimGreen)
        }
        print("")

        let farewells = [
            "May your dice roll true, adventurer.",
            "The dungeon will remember your name.",
            "Until we meet again at the tavern...",
            "Your legend grows with each adventure.",
            "The road goes ever on. Farewell.",
        ]
        print("  Thanks for playing!", color: .brightGreen, bold: true)
        print("")
        print("  \(farewells.randomElement()!)", color: .dimGreen)
        print("")

        // Star field (bottom)
        for _ in 0..<3 {
            starIndices.append(terminalLines.count)
            print(randomStarLine(width: w), color: .dimGreen)
        }
        print("")
        print("  Goodbye.", color: .dimGreen)
        print("")

        // Twinkle animation — update star lines every 400ms
        self.starLineIndices = starIndices
        starTwinkleTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                for idx in self.starLineIndices {
                    if idx < self.terminalLines.count {
                        self.terminalLines[idx].text = self.randomStarLine(width: w)
                    }
                }
            }
        }

        // Exit the app after the farewell tune finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.starTwinkleTimer?.invalidate()
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

    private var asciiFarewell: [[String]] {
        // Each entry is [frame1, frame2] for a waving animation
        let characters: [([String], [String], String)] = [
            // Wizard waving staff
            ([
                "     o     ",
                "    /|\\  * ",
                "    / \\ /| ",
                "        |  ",
            ], [
                "     o     ",
                "  * /|\\    ",
                "  |\\ / \\   ",
                "  |        ",
            ], "wizard"),
            // Knight saluting
            ([
                "    o/     ",
                "   /|      ",
                "   / \\     ",
                "  [===]    ",
            ], [
                "    \\o     ",
                "     |\\    ",
                "    / \\    ",
                "   [===]   ",
            ], "knight"),
            // Rogue bowing
            ([
                "     o     ",
                "    /|\\    ",
                "    / \\    ",
                "   ~ ~ ~   ",
            ], [
                "      _    ",
                "     o/    ",
                "    /|     ",
                "    / \\    ",
            ], "rogue"),
            // Dwarf raising ale
            ([
                "    o  U   ",
                "   /|\\/    ",
                "   /d\\     ",
                "   ^^^     ",
            ], [
                "   Uo      ",
                "    \\|\\    ",
                "    /d\\    ",
                "    ^^^    ",
            ], "dwarf"),
            // Elf waving
            ([
                "    o/~    ",
                "   /|      ",
                "   / \\     ",
                "  ~~~~     ",
            ], [
                "   ~\\o     ",
                "     |\\    ",
                "    / \\    ",
                "    ~~~~   ",
            ], "elf"),
        ]
        let pick = characters.randomElement()!
        return [pick.0, pick.1]
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

    private var asciiDragon: [String] {
        // Dragon art — matches the original splash screen layout exactly
        [
            "          ___====-_  _-====___",
            "    _--^^^#####//      \\\\#####^^^--_",
            " _-^##########// (    ) \\\\##########^-_",
            "    -############//  |\\^^/|  \\\\############-",
            "  _/############//   (@::@)   \\\\############\\_",
            " /#############((     \\\\//     ))#############\\",
            "-###############\\\\    (oo)    //###############-",
            "   -#################\\\\  / VV \\  //#################-",
            "  -###################\\\\/      \\//###################-",
            " _#/|##########/\\######(   /\\   )######/\\##########|\\#_",
            " |/ |#/\\#/\\#/\\/  \\#/\\##\\  |  |  /##/\\#/  \\/\\#/\\#/\\#| \\|",
            " `  |/  V  V  `   V  \\#\\| |  | |/#/  V   '  V  V  \\|  '",
            "    `   `  `      `   / | |  | | \\   '      '  '   '",
            "                       (  | |  | |  )",
            "                      __\\ | |  | | /__",
            "                     (vvv(VVV)(VVV)vvv)",
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

    // MARK: - Multiplayer

    private func showActiveMatches() {
        clearTerminal()
        printTitle("Active Matches")
        print("Loading...", color: .dimGreen)

        Task {
            do {
                let matches = try await GameCenterManager.shared.loadMatches()
                // Show open matches and pending invites (matching)
                let activeMatches = matches.filter { $0.status == .open || $0.status == .matching }

                await MainActor.run {
                    clearTerminal()
                    printTitle("Active Matches")

                    if activeMatches.isEmpty {
                        print("No active matches found.", color: .dimGreen)
                        print("")
                        print("If you were invited, check your", color: .dimGreen)
                        print("notification centre (swipe down", color: .dimGreen)
                        print("from top of screen) for a Game", color: .dimGreen)
                        print("Centre invite, then tap Refresh.", color: .dimGreen)
                        print("")
                        showMenu(["Refresh", "Done"])
                        menuHandler = { [weak self] choice in
                            if choice == 1 {
                                self?.showActiveMatches()
                            } else {
                                self?.showMultiplayerHub()
                            }
                        }
                        return
                    }

                    var opts: [String] = []
                    for match in activeMatches {
                        let players = match.participants.compactMap { $0.player?.displayName }.joined(separator: ", ")
                        let tag: String
                        if match.status == .matching {
                            tag = " (invite)"
                        } else if match.currentParticipant?.player == GKLocalPlayer.local {
                            tag = " (your turn)"
                        } else {
                            tag = " (waiting)"
                        }
                        opts.append("\(players.isEmpty ? "New Match" : players)\(tag)")
                    }
                    opts.append("Refresh")
                    opts.append("Done")

                    print("  (Long-press a match to delete it)", color: .dimGreen)
                    print("")

                    showMenu(opts)

                    menuHandler = { [weak self] choice in
                        if choice >= 1 && choice <= activeMatches.count {
                            let match = activeMatches[choice - 1]
                            GameCenterManager.shared.currentMatch = match
                            self?.loadMultiplayerMatch(match)
                        } else if choice == activeMatches.count + 1 {
                            self?.showActiveMatches()
                        } else {
                            self?.showMultiplayerHub()
                        }
                    }

                    menuLongPressHandler = { [weak self] choice in
                        if choice >= 1 && choice <= activeMatches.count {
                            let match = activeMatches[choice - 1]
                            self?.confirmLeaveMatch(match)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("Error loading matches: \(error.localizedDescription)", color: .red)
                    showMenu(["Refresh", "Done"])
                    menuHandler = { [weak self] choice in
                        if choice == 1 {
                            self?.showActiveMatches()
                        } else {
                            self?.showMultiplayerHub()
                        }
                    }
                }
            }
        }
    }

    private func confirmLeaveMatch(_ match: GKTurnBasedMatch) {
        clearTerminal()
        printTitle("Leave Match?")

        let players = match.participants.compactMap { $0.player?.displayName }.joined(separator: ", ")
        let otherPlayers = match.participants.filter { $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
        let hasOthers = !otherPlayers.isEmpty && otherPlayers.contains(where: { $0.status != .done })
        print("Match: \(players)", color: .brightGreen)
        print("")

        if hasOthers {
            print("Your character will become AI-", color: .dimGreen)
            print("controlled. The other player can", color: .dimGreen)
            print("continue without you.", color: .dimGreen)
        } else {
            print("This will permanently delete", color: .dimGreen)
            print("the match.", color: .dimGreen)
        }
        print("")

        showMenu(["Leave Match", "Cancel"])

        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.executeLeaveMatch(match, hasOtherPlayers: hasOthers)
            } else {
                self?.showPlayMenu()
            }
        }
    }

    private func executeLeaveMatch(_ match: GKTurnBasedMatch, hasOtherPlayers: Bool) {
        clearTerminal()
        print("Leaving match...", color: .dimGreen)

        Task {
            do {
                // Pending invites (not yet started) — just remove directly
                if match.status == .matching {
                    try? await match.declineInvite()
                    try? await match.remove()
                    await MainActor.run {
                        GameCenterManager.shared.currentMatch = nil
                        self.showPlayMenu()
                    }
                    return
                }

                if hasOtherPlayers {
                    // Mark our character as AI in the match state, then quit gracefully
                    if let data = match.matchData, !data.isEmpty,
                       var state = try? MultiplayerMatchState.decoded(from: data) {

                        // Convert our character to AI
                        if let slotIdx = state.players.firstIndex(where: { $0.gamePlayerID == localPlayerID }),
                           let charId = state.players[slotIdx].characterId,
                           let char = state.party.first(where: { $0.id == charId }) {
                            char.markAsAI()
                            state.addAction(
                                playerName: GKLocalPlayer.local.displayName,
                                description: "\(char.name) is now AI-controlled (player left)")
                        }

                        // If it's our turn, pass it along with the updated state
                        if match.currentParticipant?.player == GKLocalPlayer.local {
                            let others = match.participants.filter {
                                $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID && $0.status != .done
                            }
                            if !others.isEmpty {
                                // Update active player to the next person
                                if let nextPlayer = others.first?.player?.gamePlayerID {
                                    state.activePlayerID = nextPlayer
                                }
                                var trimmed = state
                                trimmed.trimForTransfer()
                                let stateData = try trimmed.encoded()
                                try await match.participantQuitInTurn(
                                    with: .quit,
                                    nextParticipants: others,
                                    turnTimeout: GKTurnTimeoutDefault,
                                    match: stateData
                                )
                            } else {
                                // No one else active — end it
                                for p in match.participants { p.matchOutcome = .quit }
                                try await match.endMatchInTurn(withMatch: match.matchData ?? Data())
                                try? await match.remove()
                            }
                        } else {
                            // Not our turn — quit out of turn
                            try await match.participantQuitOutOfTurn(with: .quit)
                        }
                    } else {
                        // No state data — just quit
                        if match.currentParticipant?.player == GKLocalPlayer.local {
                            let others = match.participants.filter { $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
                            try await match.participantQuitInTurn(
                                with: .quit,
                                nextParticipants: others,
                                turnTimeout: GKTurnTimeoutDefault,
                                match: match.matchData ?? Data()
                            )
                        } else {
                            try await match.participantQuitOutOfTurn(with: .quit)
                        }
                    }
                } else {
                    // Solo match — end and remove
                    for p in match.participants { p.matchOutcome = .quit }
                    if match.currentParticipant?.player == GKLocalPlayer.local {
                        try await match.endMatchInTurn(withMatch: match.matchData ?? Data())
                    }
                    try? await match.remove()
                }

                await MainActor.run {
                    GameCenterManager.shared.currentMatch = nil
                    self.showPlayMenu()
                }
            } catch {
                // Try harder — force remove on any error
                try? await match.remove()
                await MainActor.run {
                    GameCenterManager.shared.currentMatch = nil
                    self.print("The match has been abandoned.", color: .yellow)
                    self.print("")
                    self.showMenu(["Done"])
                    self.menuHandler = { [weak self] _ in self?.showPlayMenu() }
                }
            }
        }
    }

    private func loadMultiplayerMatch(_ match: GKTurnBasedMatch) {
        GameCenterManager.shared.currentMatch = match

        // Empty match — fresh start
        guard let data = match.matchData, !data.isEmpty else {
            startMultiplayerCharacterCreation(match: match)
            return
        }

        // Try to decode the match state
        var state: MultiplayerMatchState
        do {
            state = try MultiplayerMatchState.decoded(from: data)
        } catch {
            // Corrupt or incompatible match data
            clearTerminal()
            printTitle("Match Error")
            print("This match's data could not be read.", color: .yellow)
            print("It may be from an older version.", color: .dimGreen)
            print("")
            print("Error: \(error.localizedDescription)", color: .dimGreen)
            print("")
            showMenu(["Remove Match", "Done"])
            menuHandler = { [weak self] choice in
                if choice == 1 {
                    Task {
                        try? await match.remove()
                        await MainActor.run {
                            self?.showActiveMatches()
                        }
                    }
                } else {
                    self?.showActiveMatches()
                }
            }
            return
        }

        state.relinkCombat()

        // Fix up pending player IDs — when the match was created, remote participants
        // may not have had their player info yet, so IDs were stored as "pending_N".
        // Now that both players have joined, update with real Game Center IDs.
        for (i, slot) in state.players.enumerated() {
            if slot.gamePlayerID.hasPrefix("pending_") {
                // Find the matching participant by position (non-host participants)
                let remoteParticipants = match.participants.filter {
                    $0.player?.gamePlayerID != state.players.first(where: { $0.isPartyLeader })?.gamePlayerID
                }
                let pendingIndex = Int(slot.gamePlayerID.replacingOccurrences(of: "pending_", with: "")) ?? 0
                if pendingIndex < remoteParticipants.count,
                   let realID = remoteParticipants[pendingIndex].player?.gamePlayerID {
                    state.players[i].gamePlayerID = realID
                    state.players[i].displayName = remoteParticipants[pendingIndex].player?.displayName ?? slot.displayName
                }
            }
        }

        multiplayerState = state
        isMultiplayer = true

        // Check if all other players have quit — offer to convert to local game
        let otherPlayers = match.participants.filter { $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
        let allOthersQuit = !otherPlayers.isEmpty && otherPlayers.allSatisfy { $0.status == .done }
        if allOthersQuit && (state.phase == .exploring || state.phase == .combat) {
            // Ensure departed players' characters are marked as AI-controlled
            for slot in state.players where slot.gamePlayerID != localPlayerID {
                if let charId = slot.characterId,
                   let char = state.party.first(where: { $0.id == charId }) {
                    char.markAsAI()
                }
            }
            multiplayerState = state
            showPlayerLeftNotification(playerName: "The other player", characterName: "Their character")
            return
        }

        // If this player needs to confirm or create their character
        if state.phase == .characterCreation {
            let mySlot = state.players.first(where: { $0.gamePlayerID == localPlayerID })

            // Show invitation screen if placeholder character needs confirmation
            if mySlot?.needsConfirmation == true {
                showMatchInvitation(state: state)
                return
            }

            // No character at all — go to creation
            let needsCharacter = mySlot == nil || mySlot?.characterId == nil
            if needsCharacter {
                continueMultiplayerCharacterCreation(state: state)
                return
            }
        }

        showMultiplayerCatchUp(state: state) { [weak self] in
            self?.resumeMultiplayerPhase(state: state)
        }
    }

    private func resumeMultiplayerPhase(state: MultiplayerMatchState) {
        // Clear nudge state — we're back in the game
        lastNudgeTime = nil
        nudgeCooldownTimer?.invalidate()
        nudgeCooldownTimer = nil
        nudgeCooldownSeconds = 0
        nudgeCooldownSpeed = 1.0
        // Restore game state from multiplayer state
        party = state.party
        dungeon = state.dungeon
        gameTimeMinutes = state.gameTimeMinutes
        adventureLog = state.adventureLog
        monstersSlain = state.monstersSlain
        combatsWon = state.combatsWon
        torchLit = state.torchLit
        torchTurnsRemaining = state.torchTurnsRemaining

        switch state.phase {
        case .characterCreation:
            continueMultiplayerCharacterCreation(state: state)
        case .exploring:
            gameState = .exploring
            showExplorationView()
        case .combat:
            if let combat = state.combat {
                currentCombat = combat
                gameState = .combat
                multiplayerCombatTurn()
            } else {
                gameState = .exploring
                showExplorationView()
            }
        case .victory:
            showMultiplayerVictory()
        case .gameOver:
            showMultiplayerDefeat()
        case .abandoned:
            showMatchAbandoned()
        }
    }

    // MARK: - Multiplayer Catch-Up

    private func showMultiplayerCatchUp(state: MultiplayerMatchState, then: @escaping () -> Void) {
        clearTerminal()

        // Show who you're playing with
        let otherNames = state.players
            .filter { $0.gamePlayerID != localPlayerID }
            .map { $0.displayName }
        if !otherNames.isEmpty {
            print("  Playing with: \(otherNames.joined(separator: ", "))", color: .cyan)
            print("")
        }

        if state.phase == .combat {
            // Combat-specific catch-up
            printTitle("Battle Update")
            print("")

            // Show map for spatial context
            let mapLines = state.dungeon.getMapDisplay(visibilityRadius: state.torchLit ? mapRadius : 0, torchLit: state.torchLit)
            printLines(mapLines, color: state.torchLit ? .brightGreen : .gray, size: mapFontSize)
            print("")

            // Show recent combat actions
            if !state.recentActions.isEmpty {
                print("  Since your last turn:", color: .yellow, bold: true)
                for action in state.recentActions.suffix(15) {
                    print("    \(action.description)", color: .dimGreen)
                }
                print("")
            }

            // Full combat status panel (party + monsters with HP bars)
            if let combat = state.combat {
                printLines(combat.displayStatus())
                print("")

                // Show whose turn it is
                if let current = combat.currentCombatant {
                    let isYours = state.players.first(where: {
                        $0.gamePlayerID == localPlayerID &&
                        ($0.controlledCharacterIds.contains(current.id) || $0.characterId == current.id)
                    }) != nil
                    if isYours {
                        print("  It's \(current.name)'s turn (yours)!", color: .brightGreen, bold: true)
                    } else {
                        print("  Current turn: \(current.name)", color: .cyan)
                    }
                    print("")
                }
            } else {
                // Fallback: show party/enemy status inline
                print("  Party Status:", color: .cyan, bold: true)
                for char in state.party {
                    let myChar = state.players.first(where: {
                        $0.gamePlayerID == localPlayerID &&
                        ($0.controlledCharacterIds.contains(char.id) || $0.characterId == char.id)
                    }) != nil
                    let marker = myChar ? " (you)" : ""
                    var conditions: [String] = []
                    if char.isPoisoned { conditions.append("poisoned") }
                    if !char.isConscious { conditions.append("unconscious") }
                    if char.hasFledCombat { conditions.append("fled") }
                    if char.isPlayingDead { conditions.append("playing dead") }
                    let condStr = conditions.isEmpty ? "" : " [\(conditions.joined(separator: ", "))]"
                    let hpColor: TerminalColor = char.currentHP < char.maxHP / 3 ? .red :
                        (char.currentHP < char.maxHP * 2 / 3 ? .yellow : .green)
                    print("    \(char.name): \(char.currentHP)/\(char.maxHP) HP\(condStr)\(marker)", color: hpColor)
                }
                print("")
            }
        } else {
            // Exploration catch-up

            // Show map
            let mapLines = state.dungeon.getMapDisplay(visibilityRadius: state.torchLit ? mapRadius : 0, torchLit: state.torchLit)
            printLines(mapLines, color: state.torchLit ? .brightGreen : .gray, size: mapFontSize)
            print("")

            printTitle("Your Turn!")
            print("")

            // Show recent actions as a narrative
            if !state.recentActions.isEmpty {
                print("  Since your last turn:", color: .yellow, bold: true)
                for action in state.recentActions.suffix(15) {
                    print("    \(action.description)", color: .dimGreen)
                }
                print("")
            }

            // Party status with conditions
            print("  Party Status:", color: .cyan, bold: true)
            for char in state.party {
                let myChar = state.players.first(where: {
                    $0.gamePlayerID == localPlayerID &&
                    ($0.controlledCharacterIds.contains(char.id) || $0.characterId == char.id)
                }) != nil
                let marker = myChar ? " (you)" : ""
                var conditions: [String] = []
                if char.isPoisoned { conditions.append("poisoned") }
                if !char.isConscious { conditions.append("unconscious") }
                let condStr = conditions.isEmpty ? "" : " [\(conditions.joined(separator: ", "))]"
                let hpColor: TerminalColor = char.currentHP < char.maxHP / 3 ? .red :
                    (char.currentHP < char.maxHP * 2 / 3 ? .yellow : .green)
                print("    \(char.name): \(char.currentHP)/\(char.maxHP) HP  \(char.gold)gp\(condStr)\(marker)", color: hpColor)
            }
            print("")

            // Current location with description
            if let room = state.dungeon.currentRoom {
                print("  Location: \(room.name)", color: .cyan)
                if !room.roomDescription.isEmpty {
                    print("  \(room.roomDescription)", color: .dimGreen)
                }
                print("")
            }
        }

        // Show recent chat messages if any
        let recentChat = state.partyChatLog.suffix(5)
        if !recentChat.isEmpty {
            print("  Party Chat:", color: .cyan, bold: true)
            for msg in recentChat {
                if msg.isAI {
                    print("    \(msg.senderName): \(msg.message)", color: .cyan)
                } else {
                    print("    \(msg.senderName): \(msg.message)", color: .yellow)
                }
            }
            print("")
        }

        waitForContinue()
        inputHandler = { _ in then() }
    }

    // MARK: - Multiplayer Character Creation

    private func startMultiplayerCharacterCreation(match: GKTurnBasedMatch) {
        isMultiplayer = true
        GameCenterManager.shared.currentMatch = match

        let playerCount = match.participants.count

        // Initialize multiplayer state
        var players: [PlayerSlot] = []
        for (i, participant) in match.participants.enumerated() {
            players.append(PlayerSlot(
                gamePlayerID: participant.player?.gamePlayerID ?? "unknown_\(i)",
                displayName: participant.player?.displayName ?? "Player \(i + 1)",
                characterId: nil,
                controlledCharacterIds: [],
                isPartyLeader: i == 0,
                slotIndex: i
            ))
        }

        multiplayerState = MultiplayerMatchState(
            version: MultiplayerMatchState.schemaVersion,
            matchId: match.matchID,
            players: players,
            activePlayerID: localPlayerID ?? "",
            phase: .characterCreation,
            party: [],
            dungeon: Dungeon(name: "Multiplayer Dungeon", level: 1),
            gameTimeMinutes: 360,
            adventureLog: [],
            monstersSlain: 0,
            combatsWon: 0,
            torchLit: false,
            torchTurnsRemaining: 0,
            combat: nil,
            recentActions: [],
            partyChatLog: [],
            dungeonLevel: 1
        )

        // Create one character for this player
        totalCharacters = 1
        creatingCharacterIndex = 0
        party = []

        clearTerminal()
        printTitle("Create Your Character")
        print("Multiplayer game — \(playerCount) players", color: .dimGreen)
        print("Create your adventurer!", color: .dimGreen)
        print("")

        creatingAsAI = false
        startCharacterCreation()
    }

    private func continueMultiplayerCharacterCreation(state: MultiplayerMatchState) {
        // Check if this player already has a character
        if let slot = state.players.first(where: { $0.gamePlayerID == localPlayerID }),
           slot.characterId != nil {
            // Already created — skip to waiting or exploring
            if state.players.allSatisfy({ $0.characterId != nil }) {
                // All characters created — start exploring
                var updatedState = state
                updatedState.phase = .exploring
                multiplayerState = updatedState
                gameState = .exploring
                showExplorationView()
            } else {
                showWaitingForPlayers()
            }
            return
        }

        // This player needs to create a character
        totalCharacters = 1
        creatingCharacterIndex = 0
        party = state.party  // Include already-created characters

        clearTerminal()
        printTitle("Create Your Character")
        print("Join the party!", color: .dimGreen)
        print("")

        creatingAsAI = false
        startCharacterCreation()
    }

    // MARK: - Multiplayer Lobby Invite

    /// Send the invite from the lobby, showing connecting status with cancel/retry
    private func sendLobbyInvite(state: MultiplayerMatchState, nextRemote: PlayerSlot) {
        clearTerminal()
        printTitle("Sending Invite")
        print("Contacting the tavern's", color: .dimGreen)
        print("messenger service...", color: .dimGreen)
        print("")

        Task {
            do {
                guard let match = GameCenterManager.shared.currentMatch else {
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.clearTerminal()
                        self.printTitle("No Match")
                        self.print("No active Game Center match.", color: .red)
                        self.print("Try starting a new adventure.", color: .dimGreen)
                        self.print("")
                        self.showMenu(["Back to Play Menu", "Cancel Match"])
                        self.menuHandler = { [weak self] choice in
                            self?.isMultiplayer = false
                            self?.multiplayerState = nil
                            self?.showPlayMenu()
                        }
                    }
                    return
                }

                // Try exact match, then fallback for pending_ IDs
                let nextParticipant = match.participants.first(where: {
                    $0.player?.gamePlayerID == nextRemote.gamePlayerID
                }) ?? (nextRemote.gamePlayerID.hasPrefix("pending_") ? match.participants.first(where: {
                    $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID && $0.player != nil
                }) : nil)

                if nextParticipant == nil {
                    // Player hasn't joined Game Center match yet — save state and show waiting
                    try await GameCenterManager.shared.saveCurrentTurn(matchState: state)
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.clearTerminal()
                        self.printTitle("Invite Sent")
                        self.print("Waiting for the other player", color: .yellow)
                        self.print("to accept the Game Center", color: .yellow)
                        self.print("invite...", color: .yellow)
                        self.print("")
                        self.print("They'll receive a notification.", color: .dimGreen)
                        self.print("You can close the app — you'll", color: .dimGreen)
                        self.print("be notified when they join.", color: .dimGreen)
                        self.print("")
                        self.showMenuOptions([self.nudgeButtonOption(), MenuOption("Main Menu"), MenuOption("Cancel Match")])
                        self.menuHandler = { [weak self] choice in
                            switch choice {
                            case 1:
                                if self?.nudgeOnCooldown == true { return }
                                self?.nudgeRemotePlayer()
                            case 3: self?.confirmCancelMatch()
                            default:
                                self?.isMultiplayer = false
                                self?.multiplayerState = nil
                                self?.showMainMenu()
                            }
                        }
                        self.menuLongPressHandler = { [weak self] choice in
                            if choice == 1 { self?.handleNudgeLongPress() }
                        }
                    }
                    return
                }

                let next = nextParticipant!
                if match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID {
                    do {
                        try await GameCenterManager.shared.endTurn(
                            matchState: state,
                            nextParticipants: [next]
                        )
                    } catch {
                        // Fallback: save state so player can pick it up
                        try await GameCenterManager.shared.saveCurrentTurn(matchState: state)
                    }
                } else {
                    try await GameCenterManager.shared.saveCurrentTurn(matchState: state)
                }

                // Send push notification
                try? await match.sendReminder(
                    to: [next],
                    localizableMessageKey: "You've been invited to a D&D adventure!",
                    arguments: []
                )

                // Success — re-show lobby with nudge/cancel options
                await MainActor.run { [weak self] in
                    self?.showMultiplayerLobby()
                }
            } catch {
                let errorDesc = error.localizedDescription
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.clearTerminal()
                    self.printTitle("Connection Issue")
                    self.print("The messenger pigeon got lost.", color: .yellow)
                    self.print("", color: .dimGreen)
                    self.print("Error: \(errorDesc)", color: .dimGreen)
                    self.print("")
                    self.print("The other player may still be", color: .dimGreen)
                    self.print("able to find the game in their", color: .dimGreen)
                    self.print("Play menu.", color: .dimGreen)
                    self.print("")
                    self.showMenu(["Retry", "Back to Main Menu", "Cancel Match"])
                    self.menuHandler = { [weak self] choice in
                        switch choice {
                        case 1: self?.sendLobbyInvite(state: state, nextRemote: nextRemote)
                        case 3: self?.confirmCancelMatch()
                        default:
                            self?.isMultiplayer = false
                            self?.multiplayerState = nil
                            self?.showMainMenu()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Multiplayer Invitation Screen

    /// Show the invitation screen to a remote player with party details and their placeholder character
    private func showMatchInvitation(state: MultiplayerMatchState) {
        stopInvitePollTimer()
        clearTerminal()
        printTitle("Game Invite!")

        // Find the host
        let hostSlot = state.players.first(where: { $0.isPartyLeader })
        let hostName = hostSlot?.displayName ?? "Another player"
        print("")
        print("  \(hostName) invites you", color: .yellow, bold: true)
        print("  to join their adventure!", color: .yellow, bold: true)
        print("")

        // Show full party roster
        print("  The Party:", color: .cyan, bold: true)
        for slot in state.players {
            guard let charId = slot.characterId,
                  let char = state.party.first(where: { $0.id == charId }) else { continue }

            let tag: String
            if slot.gamePlayerID == localPlayerID {
                tag = " [You]"
            } else if slot.isPartyLeader {
                tag = " [Host]"
            } else {
                tag = ""
            }
            let color: TerminalColor = slot.gamePlayerID == localPlayerID ? .yellow : .brightGreen
            print("    \(char.name)\(tag) — \(char.race.rawValue) \(char.characterClass.rawValue) HP:\(char.maxHP)", color: color)
        }
        print("")

        // Show detailed view of the player's character
        let mySlot = state.players.first(where: { $0.gamePlayerID == localPlayerID })
        if let charId = mySlot?.characterId,
           let char = state.party.first(where: { $0.id == charId }) {
            print("  Your character:", color: .cyan, bold: true)
            print("    \(char.name)", color: .yellow, bold: true)
            print("    \(char.race.rawValue) \(char.characterClass.rawValue)", color: .dimGreen)
            print("    HP: \(char.maxHP), AC: \(char.armorClass)", color: .dimGreen)
            let s = char.abilityScores
            print("    STR:\(s.strength) DEX:\(s.dexterity) CON:\(s.constitution) INT:\(s.intelligence) WIS:\(s.wisdom) CHA:\(s.charisma)", color: .dimGreen)
            if let w = char.equippedWeapon {
                print("    Weapon: \(w.name)", color: .dimGreen)
            }
            if let a = char.equippedArmor {
                print("    Armour: \(a.name)", color: .dimGreen)
            }
            if !char.knownSpells.isEmpty {
                let spellNames = char.knownSpells.map { $0.name }.joined(separator: ", ")
                print("    Spells: \(spellNames)", color: .dimGreen)
            }
        }
        print("")

        showMenuOptions([
            MenuOption("Accept & Join!", isAlert: true),
            MenuOption("Customise Character"),
            MenuOption("Decline Invite")
        ])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            switch choice {
            case 1: self.acceptInvitationCharacter(state: state)
            case 2: self.customiseInvitationCharacter(state: state)
            case 3: self.declineInvitation()
            default: break
            }
        }
    }

    /// Accept the placeholder character as-is
    private func acceptInvitationCharacter(state: MultiplayerMatchState) {
        var updatedState = state

        // Mark confirmation done
        if let idx = updatedState.players.firstIndex(where: { $0.gamePlayerID == localPlayerID }) {
            updatedState.players[idx].needsConfirmation = false
            let charName = updatedState.party.first(where: { $0.id == updatedState.players[idx].characterId })?.name ?? "Unknown"
            updatedState.addAction(
                playerName: GKLocalPlayer.local.displayName,
                description: "\(charName) is ready to adventure!"
            )
        }

        multiplayerState = updatedState
        party = updatedState.party

        // Check if all players confirmed
        finishMultiplayerConfirmation(state: updatedState)
    }

    /// Replace the placeholder character with a custom one
    private func customiseInvitationCharacter(state: MultiplayerMatchState) {
        let mySlot = state.players.first(where: { $0.gamePlayerID == localPlayerID })
        pendingReplacementCharacterId = mySlot?.characterId

        totalCharacters = 1
        creatingCharacterIndex = 0
        party = state.party
        creatingAsAI = false
        startCharacterCreation()
    }

    /// Decline the invitation and leave the match
    private func declineInvitation() {
        Task {
            do {
                try await GameCenterManager.shared.quitMatch(outcome: .quit)
            } catch {
                // Ignore quit errors
            }
            await MainActor.run {
                isMultiplayer = false
                multiplayerState = nil
                GameCenterManager.shared.currentMatch = nil
                showMainMenu()
            }
        }
    }

    /// Check if all remote players have confirmed and transition to exploring if so
    private func finishMultiplayerConfirmation(state: MultiplayerMatchState) {
        let nextUnconfirmed = state.players.first(where: { $0.needsConfirmation })

        if let next = nextUnconfirmed {
            // Pass turn to next unconfirmed player
            var updatedState = state
            updatedState.activePlayerID = next.gamePlayerID
            multiplayerState = updatedState
            passTurnToPlayer(playerID: next.gamePlayerID, state: updatedState)
        } else {
            // All confirmed! Party leader starts exploring
            var updatedState = state
            updatedState.phase = .exploring
            updatedState.activePlayerID = state.players.first(where: { $0.isPartyLeader })?.gamePlayerID ?? ""

            // Only generate a new dungeon if the current one is a placeholder
            let hasRealDungeon = updatedState.dungeon.rooms.count > 1
            if !hasRealDungeon {
                updatedState.dungeon = Dungeon(name: self.dungeonNames.randomElement()!, level: 1)
            }

            multiplayerState = updatedState
            party = updatedState.party
            dungeon = updatedState.dungeon
            if partyHasTorch() { torchLit = true }

            if isPartyLeader {
                gameState = .exploring
                showExplorationView()
            } else {
                passTurnToPlayer(playerID: updatedState.activePlayerID, state: updatedState)
            }
        }
    }

    /// Called after a character is fully created in multiplayer mode
    func multiplayerCharacterCreated(character: Character) {
        guard var state = multiplayerState else {
            print("Error: Lost connection to multiplayer match.", color: .red)
            print("Your character was created but could not be saved to the match.", color: .yellow)
            isMultiplayer = false
            showMainMenu()
            return
        }

        // If replacing a placeholder character (from invitation customisation)
        if let replacementId = pendingReplacementCharacterId,
           let replaceIdx = state.party.firstIndex(where: { $0.id == replacementId }) {
            state.party[replaceIdx] = character
            pendingReplacementCharacterId = nil
        } else {
            state.party.append(character)
        }

        // Update this player's slot with character ID
        if let idx = state.players.firstIndex(where: { $0.gamePlayerID == localPlayerID }) {
            state.players[idx].characterId = character.id
            state.players[idx].controlledCharacterIds = [character.id]
            state.players[idx].needsConfirmation = false
        }

        // Add to recent actions
        state.addAction(
            playerName: GKLocalPlayer.local.displayName,
            description: "Created \(character.name) (\(character.race.rawValue) \(character.characterClass.rawValue))"
        )

        multiplayerState = state
        party = state.party

        // Use shared confirmation logic (checks needsConfirmation + characterId)
        finishMultiplayerConfirmation(state: state)
    }

    // MARK: - Multiplayer Turn Passing

    private func passTurnToPlayer(playerID: String, state: MultiplayerMatchState, retryCount: Int = 0) {
        let playerName = state.players.first(where: { $0.gamePlayerID == playerID })?.displayName ?? "other player"

        // Show connecting feedback
        if retryCount == 0 {
            clearTerminal()
            printTitle("Passing Turn")
            print("Sending to \(playerName)...", color: .dimGreen)
            print("")
        } else {
            print("Retry \(retryCount)/2...", color: .dimGreen)
        }

        Task {
            do {
                guard let match = GameCenterManager.shared.currentMatch else {
                    await MainActor.run {
                        clearTerminal()
                        printTitle("Connection Lost")
                        print("The crystal ball has gone dark.", color: .yellow)
                        print("No active match found.", color: .yellow)
                        print("")
                        showMenu(["Back to Main Menu"])
                        menuHandler = { [weak self] _ in
                            self?.isMultiplayer = false
                            self?.multiplayerState = nil
                            self?.showMainMenu()
                        }
                    }
                    return
                }
                // Try exact match first, then fallback to any non-local participant
                let nextParticipant = match.participants.first(where: { $0.player?.gamePlayerID == playerID })
                    ?? (playerID.hasPrefix("pending_") ? match.participants.first(where: {
                        $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID && $0.player != nil
                    }) : nil)
                guard let next = nextParticipant else {
                    await MainActor.run {
                        clearTerminal()
                        printTitle("Player Not Found")
                        print("The adventurer you seek has", color: .yellow)
                        print("vanished from the realm.", color: .yellow)
                        print("")
                        showMenu(["Back to Main Menu"])
                        menuHandler = { [weak self] _ in
                            self?.isMultiplayer = false
                            self?.multiplayerState = nil
                            self?.showMainMenu()
                        }
                    }
                    return
                }

                // Only endTurn if we're the current participant; otherwise save state
                if match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID {
                    do {
                        try await GameCenterManager.shared.endTurn(
                            matchState: state,
                            nextParticipants: [next]
                        )
                    } catch {
                        // Fallback: try saving state instead of ending turn
                        print("[MP] endTurn failed: \(error.localizedDescription), trying saveCurrentTurn")
                        try await GameCenterManager.shared.saveCurrentTurn(matchState: state)
                    }
                } else {
                    // Not our turn — save the state for the active player to pick up
                    try await GameCenterManager.shared.saveCurrentTurn(matchState: state)
                }

                // Auto-nudge: send push notification to remote player
                try? await match.sendReminder(
                    to: [next],
                    localizableMessageKey: "It's your turn in Dungeon Crawler!",
                    arguments: []
                )

                await MainActor.run {
                    clearTerminal()

                    // Always show map for spatial context
                    if let dungeon = self.dungeon {
                        let mapLines = dungeon.getMapDisplay(visibilityRadius: self.effectiveMapRadius(), torchLit: self.torchLit)
                        printLines(mapLines, color: self.torchMapColor, size: self.mapFontSize)
                        print("")
                    }

                    // Show combat status when fighting
                    if state.phase == .combat, let combat = state.combat {
                        printLines(combat.displayStatus())
                        print("")

                        // Show recent actions so waiting player sees what happened
                        let recentCombat = state.recentActions.suffix(5)
                        if !recentCombat.isEmpty {
                            for action in recentCombat {
                                print("  \(action.description)", color: .dimGreen)
                            }
                            print("")
                        }
                    } else {
                        // Party HP summary for exploration
                        for char in self.party where char.isConscious {
                            let hpColor: TerminalColor = char.currentHP < char.maxHP / 3 ? .red :
                                (char.currentHP < char.maxHP * 2 / 3 ? .yellow : .green)
                            print("  \(char.name): \(char.currentHP)/\(char.maxHP) HP", color: hpColor)
                        }
                        print("")
                    }

                    printTitle("Waiting")
                    if self.nudgeSent {
                        print("Waiting for \(playerName)...", color: .red, bold: true)
                        print("(Reminder sent)", color: .red)
                    } else {
                        print("Waiting for \(playerName)...", color: .dimGreen)
                    }
                    print("")
                    print("You'll be notified when it's", color: .dimGreen)
                    print("your turn.", color: .dimGreen)
                    print("")

                    showMenuOptions([self.nudgeButtonOption(), MenuOption("Quit Match", tint: .navigation), MenuOption("Main Menu")])
                    menuHandler = { [weak self] choice in
                        self?.stopMatchPolling()
                        switch choice {
                        case 1:
                            if self?.nudgeOnCooldown == true { return }
                            self?.nudgeRemotePlayer()
                        case 2: self?.confirmQuitMultiplayerMatch()
                        default:
                            self?.isMultiplayer = false
                            self?.multiplayerState = nil
                            self?.showMainMenu()
                        }
                    }
                    self.menuLongPressHandler = { [weak self] choice in
                        if choice == 1 { self?.handleNudgeLongPress() }
                    }

                    // Start polling for match updates so waiting player sees live combat
                    self.startMatchPolling(playerName: playerName)
                }
            } catch {
                // Retry up to 2 times on server errors
                if retryCount < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((retryCount + 1) * 2_000_000_000))
                    await MainActor.run { [weak self] in
                        self?.passTurnToPlayer(playerID: playerID, state: state, retryCount: retryCount + 1)
                    }
                    return
                }
                let errorDesc = error.localizedDescription
                let gcMatch = GameCenterManager.shared.currentMatch
                let matchStatus = gcMatch?.status.rawValue ?? -1
                let currentPlayer = gcMatch?.currentParticipant?.player?.displayName ?? "none"
                let participantCount = gcMatch?.participants.count ?? 0
                await MainActor.run {
                    clearTerminal()
                    printTitle("Connection Lost")
                    print("The magical link to the server", color: .yellow)
                    print("has been disrupted.", color: .yellow)
                    print("")
                    print("Error: \(errorDesc)", color: .dimGreen)
                    print("Status: \(matchStatus), turn: \(currentPlayer), players: \(participantCount)", color: .dimGreen)
                    print("")
                    print("Your progress has been saved.", color: .dimGreen)
                    print("You can retry or return later", color: .dimGreen)
                    print("from the Play menu.", color: .dimGreen)
                    print("")
                    showMenu(["Retry", "Back to Main Menu"])
                    menuHandler = { [weak self] choice in
                        if choice == 1 {
                            self?.passTurnToPlayer(playerID: playerID, state: state, retryCount: 0)
                        } else {
                            self?.isMultiplayer = false
                            self?.showMainMenu()
                        }
                    }
                }
            }
        }
    }

    private func showWaitingForPlayers() {
        clearTerminal()

        // Always show map
        if let dungeon = self.dungeon {
            let mapLines = dungeon.getMapDisplay(visibilityRadius: effectiveMapRadius(), torchLit: torchLit)
            printLines(mapLines, color: torchMapColor, size: mapFontSize)
            print("")
        }

        // Show combat status when fighting
        if let state = multiplayerState, state.phase == .combat, let combat = state.combat {
            printLines(combat.displayStatus())
            print("")
            // Recent combat actions
            let recentCombat = state.recentActions.suffix(5)
            if !recentCombat.isEmpty {
                for action in recentCombat {
                    print("  \(action.description)", color: .dimGreen)
                }
                print("")
            }
        } else {
            // Party HP for exploration
            for char in party where char.isConscious {
                let hpColor: TerminalColor = char.currentHP < char.maxHP / 3 ? .red :
                    (char.currentHP < char.maxHP * 2 / 3 ? .yellow : .green)
                print("  \(char.name): \(char.currentHP)/\(char.maxHP) HP", color: hpColor)
            }
            print("")
        }

        printTitle("Waiting")
        if nudgeSent {
            print("Waiting for other players...", color: .red, bold: true)
            print("(Reminder sent)", color: .red)
        } else {
            print("Waiting for other players...", color: .dimGreen)
        }
        print("")
        print("You'll be notified when they're", color: .dimGreen)
        print("ready.", color: .dimGreen)
        print("")

        showMenuOptions([nudgeButtonOption(), MenuOption("Quit Match", tint: .navigation), MenuOption("Main Menu")])
        menuHandler = { [weak self] choice in
            switch choice {
            case 1:
                if self?.nudgeOnCooldown == true { return }
                self?.nudgeRemotePlayer()
            case 2: self?.confirmQuitMultiplayerMatch()
            default:
                self?.isMultiplayer = false
                self?.multiplayerState = nil
                self?.showMainMenu()
            }
        }
        menuLongPressHandler = { [weak self] choice in
            if choice == 1 { self?.handleNudgeLongPress() }
        }
    }

    // MARK: - Multiplayer Nudge & Quit

    private var nudgeSent: Bool { lastNudgeTime != nil }
    private var nudgeOnCooldown: Bool { nudgeCooldownSeconds > 0 }

    private func nudgeButtonOption() -> MenuOption {
        if nudgeOnCooldown {
            return MenuOption("Nudge (\(nudgeCooldownSeconds)s)", isDisabled: true)
        } else {
            return MenuOption("Nudge Player")
        }
    }

    private func startNudgeCooldown() {
        nudgeCooldownSeconds = Self.nudgeCooldownDuration
        nudgeCooldownSpeed = 1.0
        nudgeCooldownTimer?.invalidate()
        nudgeCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let decrement = Int(self.nudgeCooldownSpeed)
                self.nudgeCooldownSeconds = max(0, self.nudgeCooldownSeconds - decrement)
                // Update the button text live
                if !self.currentMenuOptions.isEmpty {
                    self.currentMenuOptions[0] = self.nudgeButtonOption()
                }
                if self.nudgeCooldownSeconds <= 0 {
                    self.nudgeCooldownTimer?.invalidate()
                    self.nudgeCooldownTimer = nil
                    self.nudgeCooldownSpeed = 1.0
                }
            }
        }
    }

    private func handleNudgeLongPress() {
        guard nudgeOnCooldown else { return }
        // Easter egg: speed up the countdown
        nudgeCooldownSpeed = min(nudgeCooldownSpeed + 2.0, 10.0)
    }

    /// Send a Game Centre reminder to the current turn holder
    // MARK: - Match Polling (live updates while waiting)

    private func startMatchPolling(playerName: String) {
        stopMatchPolling()
        matchPollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.pollMatchForUpdates(playerName: playerName)
        }
    }

    private func stopMatchPolling() {
        matchPollTimer?.invalidate()
        matchPollTimer = nil
    }

    private func pollMatchForUpdates(playerName: String) {
        guard let match = GameCenterManager.shared.currentMatch else { return }

        Task {
            // Reload the match to get fresh data
            guard let matches = try? await GKTurnBasedMatch.loadMatches(),
                  let freshMatch = matches.first(where: { $0.matchID == match.matchID }),
                  let data = freshMatch.matchData, !data.isEmpty,
                  let freshState = try? MultiplayerMatchState.decoded(from: data) else {
                return
            }

            await MainActor.run { [weak self] in
                guard let self = self, self.matchPollTimer != nil else { return }

                // Check if there are new actions since we last displayed
                let oldCount = self.multiplayerState?.recentActions.count ?? 0
                let newCount = freshState.recentActions.count

                if newCount > oldCount {
                    // New actions — refresh all local state from fresh match data
                    self.multiplayerState = freshState
                    self.party = freshState.party
                    self.torchLit = freshState.torchLit
                    self.torchTurnsRemaining = freshState.torchTurnsRemaining

                    clearTerminal()

                    // Show map
                    if let dungeon = self.dungeon {
                        let mapLines = dungeon.getMapDisplay(visibilityRadius: self.effectiveMapRadius(), torchLit: freshState.torchLit)
                        printLines(mapLines, color: freshState.torchLit ? .brightGreen : .gray, size: self.mapFontSize)
                        print("")
                    }

                    // Show combat status if fighting
                    if freshState.phase == .combat, let combat = freshState.combat {
                        printLines(combat.displayStatus())
                        print("")
                    }

                    // Show new actions
                    let newActions = freshState.recentActions.suffix(max(1, newCount - oldCount))
                    for action in newActions {
                        print("  \(action.description)", color: .dimGreen)
                    }
                    print("")

                    printTitle("Waiting")
                    print("Waiting for \(playerName)...", color: .dimGreen)
                    print("")

                    showMenuOptions([self.nudgeButtonOption(), MenuOption("Quit Match", tint: .navigation), MenuOption("Main Menu")])
                    menuHandler = { [weak self] choice in
                        self?.stopMatchPolling()
                        switch choice {
                        case 1:
                            if self?.nudgeOnCooldown == true { return }
                            self?.nudgeRemotePlayer()
                        case 2: self?.confirmQuitMultiplayerMatch()
                        default:
                            self?.isMultiplayer = false
                            self?.multiplayerState = nil
                            self?.showMainMenu()
                        }
                    }
                    self.menuLongPressHandler = { [weak self] choice in
                        if choice == 1 { self?.handleNudgeLongPress() }
                    }
                }
            }
        }
    }

    private func nudgeRemotePlayer() {
        guard let match = GameCenterManager.shared.currentMatch else {
            print("No active match.", color: .red)
            return
        }

        // Find the participant whose turn it is (not us)
        let remoteParticipants = match.participants.filter {
            $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID
        }
        guard !remoteParticipants.isEmpty else {
            print("No remote players to nudge.", color: .yellow)
            return
        }

        clearTerminal()
        printTitle("Nudge")
        print("Sending reminder...", color: .dimGreen)
        print("")

        Task {
            do {
                try await match.sendReminder(
                    to: remoteParticipants,
                    localizableMessageKey: "It's your turn!",
                    arguments: []
                )
                await MainActor.run {
                    self.lastNudgeTime = Date()
                    self.startNudgeCooldown()
                    clearTerminal()
                    printTitle("Nudge Sent!")
                    print("Reminder sent to the other", color: .brightGreen)
                    print("player\(remoteParticipants.count > 1 ? "s" : "").", color: .brightGreen)
                    print("You can nudge again in \(Self.nudgeCooldownDuration)s.", color: .dimGreen)
                    print("")
                    showMenu(["Done"])
                    menuHandler = { [weak self] _ in
                        // Return to whatever waiting screen we came from
                        if self?.multiplayerState?.phase == .characterCreation {
                            self?.showMultiplayerLobby()
                        } else {
                            self?.showWaitingForPlayers()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    clearTerminal()
                    printTitle("Nudge")
                    print("The messenger pigeon has already", color: .yellow)
                    print("been sent. Your ally will receive", color: .yellow)
                    print("the summons in due time.", color: .yellow)
                    print("")
                    // Start cooldown even on error to prevent spam
                    if self.lastNudgeTime == nil {
                        self.lastNudgeTime = Date()
                        self.startNudgeCooldown()
                    }
                    showMenu(["Done"])
                    menuHandler = { [weak self] _ in
                        if self?.multiplayerState?.phase == .characterCreation {
                            self?.showMultiplayerLobby()
                        } else {
                            self?.showWaitingForPlayers()
                        }
                    }
                }
            }
        }
    }

    /// Confirm cancelling a match from the lobby (before adventure starts)
    private func confirmCancelMatch() {
        clearTerminal()
        printTitle("Cancel Match?")
        print("This will end the match for all", color: .yellow)
        print("players and delete it.", color: .yellow)
        print("")

        showMenu(["Yes, Cancel Match", "No, Go Back"], defaultIndex: 1)
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.executeCancelMatch()
            } else {
                self?.showMultiplayerLobby()
            }
        }
    }

    /// Execute match cancellation — end for all and remove
    private func executeCancelMatch() {
        guard let match = GameCenterManager.shared.currentMatch else {
            isMultiplayer = false
            multiplayerState = nil
            pendingRemoteSlots.removeAll()
            showMainMenu()
            return
        }

        clearTerminal()
        printTitle("Cancelling...")
        print("Ending match...", color: .dimGreen)

        Task {
            do {
                for participant in match.participants {
                    participant.matchOutcome = .quit
                }
                let matchData = match.matchData ?? Data()
                if match.currentParticipant?.player == GKLocalPlayer.local {
                    try await match.endMatchInTurn(withMatch: matchData)
                } else {
                    try await match.participantQuitOutOfTurn(with: .quit)
                }
                try? await match.remove()
            } catch {
                // Best effort — still clean up locally
                try? await match.remove()
            }

            await MainActor.run {
                isMultiplayer = false
                multiplayerState = nil
                pendingRemoteSlots.removeAll()
                GameCenterManager.shared.currentMatch = nil
                showMainMenu()
            }
        }
    }

    /// Confirm quitting a multiplayer match during gameplay
    private func confirmQuitMultiplayerMatch() {
        clearTerminal()
        printTitle("Quit Match?")
        print("Your character will become AI-", color: .yellow)
        print("controlled and the game continues", color: .yellow)
        print("for other players.", color: .yellow)
        print("")

        showMenu(["Yes, Quit Match", "No, Go Back"], defaultIndex: 1)
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.executeQuitMultiplayerMatch()
            } else {
                self?.showWaitingForPlayers()
            }
        }
    }

    /// Execute quitting — leave the match gracefully
    private func executeQuitMultiplayerMatch() {
        stopMatchPolling()
        clearTerminal()
        printTitle("Leaving...")
        print("Quitting match...", color: .dimGreen)

        Task {
            do {
                // Mark our character as AI before quitting so the other player can continue
                if let match = GameCenterManager.shared.currentMatch,
                   let data = match.matchData, !data.isEmpty,
                   var state = try? MultiplayerMatchState.decoded(from: data) {
                    if let slotIdx = state.players.firstIndex(where: { $0.gamePlayerID == localPlayerID }),
                       let charId = state.players[slotIdx].characterId,
                       let char = state.party.first(where: { $0.id == charId }) {
                        char.markAsAI()
                        state.addAction(
                            playerName: GKLocalPlayer.local.displayName,
                            description: "\(char.name) is now AI-controlled (player left)")
                    }
                    multiplayerState = state
                }

                try await GameCenterManager.shared.quitMatch(outcome: .quit, updatedState: self.multiplayerState)
            } catch {
                // Force remove on failure
                if let match = GameCenterManager.shared.currentMatch {
                    try? await match.remove()
                }
            }

            await MainActor.run {
                isMultiplayer = false
                multiplayerState = nil
                GameCenterManager.shared.currentMatch = nil
                showMainMenu()
            }
        }
    }

    // MARK: - Multiplayer Exploration

    /// Sync multiplayer state and pass turn after exploration action
    // MARK: - Party Chat

    /// Access the active chat log — multiplayer uses shared state, single-player uses local
    private var activeChatLog: [PartyChatMessage] {
        get { multiplayerState?.partyChatLog ?? partyChatLog }
    }

    func handleChatExit() {
        // Log state on leaving chat so normal mode has full context
        logChatStateExit()
        lastChatTarget = nil
        chatStatusRemarkAdded = false
        DispatchQueue.main.async { self.chatInputMode = false }
        SoundManager.shared.stopMusic()
        playCurrentMusic()
        SpeechEngine.shared.stop()
        if gameState == .combat {
            advanceCombat()
        } else {
            showExplorationView()
        }
    }

    /// Log a snapshot of game state when entering chat mode
    private func logChatStateEntry() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }
        var parts: [String] = []
        parts.append("Entered chat in \(room.name) (Level \(dungeon.level))")
        if !room.secured.isEmpty {
            let dirs = room.secured.map { $0.rawValue }.joined(separator: ", ")
            parts.append("Barricaded: \(dirs)")
        }
        let hp = party.map { "\($0.name) \($0.currentHP)/\($0.maxHP)HP" }.joined(separator: ", ")
        parts.append("Party: \(hp)")
        if let npc = room.npc {
            parts.append("NPC: \(npc.type.rawValue)\(npc.hasBeenTalkedTo ? " (spoken to)" : "")")
        }
        if !room.droppedItems.isEmpty {
            parts.append("Floor items: \(room.droppedItems.map { $0.name }.joined(separator: ", "))")
        }
        if torchLit { parts.append("Torch lit (\(torchTurnsRemaining) rooms)") }
        else { parts.append("Torch unlit") }
        if gameTimeLimit > 0 {
            let remaining = max(0, gameTimeLimit - gameTimeMinutes)
            parts.append("Time: \(formatTimeRemaining(remaining))")
        }
        logEvent(parts.joined(separator: " | "), category: "CHAT")
    }

    /// Log state changes when exiting chat mode
    private func logChatStateExit() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }
        var parts: [String] = []
        parts.append("Left chat in \(room.name)")
        let hp = party.map { "\($0.name) \($0.currentHP)/\($0.maxHP)HP" }.joined(separator: ", ")
        parts.append("Party: \(hp)")
        let totalGold = party.reduce(0) { $0 + $1.gold }
        parts.append("Gold: \(totalGold)")
        if !room.secured.isEmpty {
            let dirs = room.secured.map { $0.rawValue }.joined(separator: ", ")
            parts.append("Barricaded: \(dirs)")
        }
        logEvent(parts.joined(separator: " | "), category: "CHAT")
    }

    private func addChatMessage(senderName: String, message: String, isAI: Bool = false) {
        let msg = PartyChatMessage(timestamp: Date(), senderName: senderName, message: message, isAI: isAI)
        if isMultiplayer {
            multiplayerState?.addChatMessage(senderName: senderName, message: message, isAI: isAI)
        } else {
            partyChatLog.append(msg)
            if partyChatLog.count > 50 { partyChatLog.removeFirst() }
        }
    }

    private func removeChatMessage(at index: Int) {
        if isMultiplayer {
            if index < (multiplayerState?.partyChatLog.count ?? 0) {
                multiplayerState?.partyChatLog.remove(at: index)
            }
        } else {
            if index < partyChatLog.count {
                partyChatLog.remove(at: index)
            }
        }
    }

    private var localPlayerDisplayName: String {
        if GameCenterManager.shared.isAuthenticated {
            return GKLocalPlayer.local.displayName
        }
        // In single-player, use the first human-controlled character's name
        return party.first(where: { !$0.isComputerControlled })?.name ?? "You"
    }

    /// Tracks whether we've already added status remarks this chat session.
    private var chatStatusRemarkAdded = false

    /// Adds DM or companion remarks about party status conditions (poison, injury, exhaustion).
    /// Only fires once per chat session to avoid spam.
    private func addChatStatusRemarks() {
        guard !chatStatusRemarkAdded else { return }

        var remarks: [String] = []
        let conscious = party.filter { $0.isConscious }

        // Poisoned characters
        let poisoned = conscious.filter { $0.isPoisoned }
        if !poisoned.isEmpty {
            let names = poisoned.map { $0.name }.joined(separator: " and ")
            let hints = [
                "\(names) \(poisoned.count == 1 ? "is" : "are") looking green around the gills. ☠ A healing potion or a Cleric's spell can cure poison — or try resting it off.",
                "The poison coursing through \(names) won't wait. ☠ Use a Potion of Healing, a Cleric's cure, or rest to shake it off before it gets worse.",
                "I'd deal with that poison soon if I were you. \(names) \(poisoned.count == 1 ? "takes" : "take") damage every round in combat. A healing potion, rest, or Cleric spell will do the trick.",
            ]
            remarks.append(hints.randomElement()!)
        }

        // Badly injured characters (below 30% HP)
        let injured = conscious.filter { $0.currentHP > 0 && $0.currentHP <= $0.maxHP * 3 / 10 }
        if !injured.isEmpty {
            let names = injured.map { $0.name }.joined(separator: " and ")
            let hints = [
                "\(names) \(injured.count == 1 ? "is" : "are") badly wounded — one more solid hit could be the end. A potion, healing spell, or short rest would help.",
                "I wouldn't pick any fights just now. \(names) \(injured.count == 1 ? "is" : "are") barely standing. Rest up or use a healing potion before pushing deeper.",
            ]
            remarks.append(hints.randomElement()!)
        }

        // Low spell slots for casters
        let casters = conscious.filter { ($0.characterClass == .wizard || $0.characterClass == .cleric) && $0.spellSlots.level1Current == 0 && $0.spellSlots.level2Current == 0 && $0.level > 0 }
        if !casters.isEmpty {
            let names = casters.map { $0.name }.joined(separator: " and ")
            remarks.append("\(names) \(casters.count == 1 ? "has" : "have") no spell slots left. A long rest will restore them — hold the Rest button.")
        }

        if !remarks.isEmpty {
            chatStatusRemarkAdded = true
            // Pick one remark (most urgent first — poison > injury > spells)
            let remark = remarks.first!
            // Have a companion say it if possible, otherwise DM
            let companions = conscious.filter { $0.isComputerControlled }
            if let speaker = companions.randomElement() {
                addChatMessage(senderName: speaker.name, message: remark, isAI: true)
            } else {
                addChatMessage(senderName: "Dungeon Master", message: remark, isAI: true)
            }
        }
    }

    func showPartyChat(initialMessage: String? = nil) {
        // Switch to chat music
        if musicEnabled {
            SoundManager.shared.startMusic(.chat, preference: chatMelodyChoice)
        }

        DispatchQueue.main.async { self.chatInputMode = true }

        clearTerminal()
        printTitle("Chat")
        print("")

        // Log full state snapshot when entering chat for the first time this session
        if activeChatLog.isEmpty {
            lastDMBarricadeState = dungeon?.currentRoom?.secured ?? []
            logChatStateEntry()
            let partyNames = party.filter { $0.isConscious }.map { $0.name }
            let nameList = partyNames.count > 1
                ? partyNames.dropLast().joined(separator: ", ") + " and " + (partyNames.last ?? "")
                : partyNames.first ?? "the party"
            let roomName = dungeon?.currentRoom?.name ?? "the dungeon"
            let intros = [
                "The shadows press close around \(nameList) in \(roomName). Speak softly — the walls have ears.",
                "\(nameList) huddle together in \(roomName). The flickering light casts long shadows as you whisper amongst yourselves.",
                "A cold draught sweeps through \(roomName). \(nameList) gather close. Now is the time to plan your next move.",
                "The sound of dripping water echoes around \(nameList) in \(roomName). You have a moment to confer.",
            ]
            addChatMessage(senderName: "Dungeon Master", message: intros.randomElement()!, isAI: true)
        }

        // Status-aware DM/companion remarks — poison, injury, exhaustion
        addChatStatusRemarks()

        // Show recent chat messages (newest bright, older dim)
        let recentChat = Array(activeChatLog.suffix(12))
        if recentChat.isEmpty {
            print("  No messages yet.", color: .dimGreen)
        } else {
            let myName = localPlayerDisplayName
            let lastIndex = recentChat.count - 1
            for (mi, msg) in recentChat.enumerated() {
                let isNewest = mi == lastIndex
                let label: String
                let brightColor: TerminalColor
                if msg.senderName == "Dungeon Master" {
                    label = "DM"
                    brightColor = .cyan
                } else if msg.senderName == myName {
                    label = ">"
                    brightColor = .orange
                } else {
                    // Companions and NPCs in orange
                    label = msg.senderName
                    brightColor = .orange
                }
                let color: TerminalColor = isNewest ? brightColor : .dimGreen
                print("  \(label):", color: color, bold: isNewest)
                // Split message into paragraphs and indent each
                let paragraphs = msg.message.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                for (pi, para) in paragraphs.enumerated() {
                    printWrapped(para, indent: 4, color: color)
                    if pi < paragraphs.count - 1 {
                        print("")  // Blank line between paragraphs
                    }
                }
            }
        }
        print("")

        // Help text
        let playerCharId = isMultiplayer ? localCharacterId : party.first(where: { !$0.isComputerControlled })?.id
        let playerCharName = party.first(where: { $0.id == playerCharId })?.name ?? "You"
        let aiCharNames = party.filter { $0.id != playerCharId && $0.isConscious }.map { $0.name }
        let shortNames = aiCharNames.prefix(3).map { "@\(chatName(for: $0).prefix(3).lowercased())" }.joined(separator: " ")
        if let targetId = lastChatTarget,
           let targetChar = party.first(where: { $0.id == targetId && $0.isConscious }) {
            print("  \(playerCharName) → \(targetChar.name)  (@dm for DM)", color: .dimGreen)
        } else {
            print("  \(playerCharName) → DM", color: .dimGreen)
        }
        if !aiCharNames.isEmpty {
            print("  @ to talk to: \(shortNames)", color: .dimGreen)
        }
        print("  'done' or ✕ to leave chat", color: .dimGreen)
        print("")

        promptText("")

        inputHandler = { [weak self] input in
            guard let self = self else { return }

            // Interrupt any ongoing speech when user types
            SpeechEngine.shared.stop()

            let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty else {
                self.showPartyChat()
                return
            }

            // Check for exit commands
            let lower = message.lowercased()
            let exitWords = ["done", "exit", "quit", "leave", "back", "return", "d", "x", "q", "b"]
            if exitWords.contains(lower) {
                self.handleChatExit()
                return
            }

            // Inventory shortcut
            if lower == "i" || lower == "inventory" || lower == "packs" || lower == "pack" {
                let back: () -> Void = { [weak self] in self?.showPartyChat() }
                let humans = self.party.filter { !$0.isComputerControlled }
                let defaultChar = humans.randomElement() ?? self.party.first!
                self.showInventoryFor(defaultChar, onBack: back, fromDM: true)
                return
            }

            // Map shortcut — render the actual minimap in chat
            let mapWords: Set = ["m", "map", "minimap", "where", "where am i", "where am i?",
                                 "show map", "show minimap", "show me the map", "show me the minimap",
                                 "display map", "look at map", "open map"]
            if mapWords.contains(lower) || (lower.contains("show") && lower.contains("map")) {
                if let dungeon = self.dungeon {
                    let mapLines = dungeon.getMapDisplay(visibilityRadius: self.effectiveMapRadius(), torchLit: self.torchLit)
                    let roomName = dungeon.currentRoom?.name ?? "the dungeon"
                    let exits = dungeon.currentRoom?.exits.keys.map { $0.rawValue }.joined(separator: ", ") ?? ""
                    self.clearTerminal()
                    self.printTitle("Map")
                    self.print("")
                    self.printLines(mapLines, color: self.torchMapColor, size: self.mapFontSize)
                    self.print("")
                    self.print("  \(roomName)", color: .brightGreen, bold: true)
                    self.print("  Exits: \(exits)", color: .dimGreen)
                    self.print("")
                    self.waitForContinue()
                    self.inputHandler = { [weak self] _ in
                        self?.showPartyChat()
                    }
                } else {
                    self.showPartyChat()
                }
                return
            }

            // Light / douse torch shortcut
            if lower == "light torch" || lower == "torch" || lower == "light" {
                if !self.torchLit && self.partyHasTorch() {
                    self.torchLit = true
                    self.torchTurnsRemaining = 60
                    self.addChatMessage(senderName: "Dungeon Master",
                                        message: "You light a torch. The shadows retreat.",
                                        isAI: true)
                } else if self.torchLit {
                    self.addChatMessage(senderName: "Dungeon Master",
                                        message: "Your torch is already lit.",
                                        isAI: true)
                } else {
                    self.addChatMessage(senderName: "Dungeon Master",
                                        message: "You have no torches to light.",
                                        isAI: true)
                }
                self.showPartyChat()
                return
            }

            // Barricade / unbarricade shortcuts
            let barricadePatterns: [(pattern: String, secure: Bool)] = [
                ("barricade ", true), ("secure ", true), ("block ", true),
                ("unbarricade ", false), ("unsecure ", false), ("open ", false),
                ("remove barricade ", false), ("take down barricade ", false),
            ]
            for bp in barricadePatterns {
                if lower.hasPrefix(bp.pattern) {
                    let dirStr = String(lower.dropFirst(bp.pattern.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let dirMap: [String: Direction] = ["north": .north, "south": .south, "east": .east, "west": .west,
                                                       "n": .north, "s": .south, "e": .east, "w": .west]
                    if let dir = dirMap[dirStr], let room = self.dungeon?.currentRoom {
                        if bp.secure {
                            if room.exits[dir] != nil && !room.secured.contains(dir) {
                                room.secured.insert(dir)
                                self.advanceTime(5)
                                self.logEvent("Secured \(dir.rawValue) exit in \(room.name)", category: "EXPLORE")
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "The party heaves debris against the \(dir.rawValue) door, barricading it shut.",
                                                    isAI: true)
                            } else if room.secured.contains(dir) {
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "The \(dir.rawValue) door is already barricaded.",
                                                    isAI: true)
                            } else {
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "There is no exit to the \(dir.rawValue).",
                                                    isAI: true)
                            }
                        } else {
                            if room.secured.contains(dir) {
                                room.secured.remove(dir)
                                self.advanceTime(3)
                                self.logEvent("Unsecured \(dir.rawValue) exit in \(room.name)", category: "EXPLORE")
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "The party clears the barricade from the \(dir.rawValue) door. The way is open.",
                                                    isAI: true)
                            } else if room.exits[dir] != nil {
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "The \(dir.rawValue) door is not barricaded.",
                                                    isAI: true)
                            } else {
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "There is no exit to the \(dir.rawValue).",
                                                    isAI: true)
                            }
                        }
                        self.showPartyChat()
                        return
                    }
                }
            }

            // Check for direction commands — move the party if possible
            let cleaned = lower.trimmingCharacters(in: .punctuationCharacters)
            let directionMap: [String: Direction] = [
                "north": .north, "south": .south, "east": .east, "west": .west,
                "n": .north, "s": .south, "e": .east, "w": .west,
                "go north": .north, "go south": .south, "go east": .east, "go west": .west,
                "travel north": .north, "travel south": .south, "travel east": .east, "travel west": .west,
                "head north": .north, "head south": .south, "head east": .east, "head west": .west,
                "move north": .north, "move south": .south, "move east": .east, "move west": .west,
                "walk north": .north, "walk south": .south, "walk east": .east, "walk west": .west,
            ]
            if self.gameState == .exploring, let dir = directionMap[cleaned] {
                guard let dungeon = self.dungeon, let room = dungeon.currentRoom else {
                    self.showPartyChat()
                    return
                }
                if room.exits[dir] == nil {
                    self.addChatMessage(senderName: "Dungeon Master",
                                        message: "There is no exit to the \(dir.rawValue).",
                                        isAI: true)
                    self.showPartyChat()
                    return
                }
                if room.secured.contains(dir) {
                    self.addChatMessage(senderName: "Dungeon Master",
                                        message: "The \(dir.rawValue) door is barricaded. You'll need to remove the barricade first.",
                                        isAI: true)
                    self.showPartyChat()
                    return
                }
                let moveResult = dungeon.move(direction: dir)
                if moveResult.success {
                    self.advanceTime(10)
                    if let newRoom = dungeon.currentRoom {
                        self.logEvent("Moved \(dir.rawValue) to \(newRoom.name)", category: "EXPLORE")
                        self.addChatMessage(senderName: "Dungeon Master",
                                            message: "The party moves \(dir.rawValue) into \(newRoom.name).",
                                            isAI: true)
                        // Describe the new room in chat
                        if self.torchLit {
                            self.addChatMessage(senderName: "Dungeon Master",
                                                message: newRoom.roomDescription,
                                                isAI: true)
                        } else {
                            self.addChatMessage(senderName: "Dungeon Master",
                                                message: "It's too dark to see clearly...",
                                                isAI: true)
                        }
                        // Show exits
                        let exitList = newRoom.exits.keys.map { $0.rawValue }.joined(separator: ", ")
                        if !exitList.isEmpty {
                            self.addChatMessage(senderName: "Dungeon Master",
                                                message: "Exits: \(exitList)",
                                                isAI: true)
                        }
                        // Check for encounter
                        if !newRoom.cleared, newRoom.encounter != nil {
                            if !self.torchLit && Int.random(in: 1...100) <= 30 {
                                newRoom.cleared = true
                                newRoom.encounter = nil
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "You creep past enemies in the darkness...",
                                                    isAI: true)
                            } else {
                                self.addChatMessage(senderName: "Dungeon Master",
                                                    message: "You sense danger here... Enemies ahead! (Type 'done' to engage.)",
                                                    isAI: true)
                            }
                        }
                    }
                    self.autosaveIfNeeded()
                }
                self.showPartyChat()
                return
            }

            // Add message to chat log
            let senderName = self.localPlayerDisplayName
            self.addChatMessage(senderName: senderName, message: message)

            // In multiplayer, also log as a recent action and save state
            if self.isMultiplayer {
                self.logMultiplayerAction("💬 \(message)")
                self.saveChatState()
            }

            // Check if addressed to a specific party member with @ or voice ("hey X", "talk to X")
            if let target = self.resolveAtMention(in: message) {
                self.lastChatTarget = target.id
                self.generateTargetedChatResponse(to: message, from: target)
            } else if let voiceResult = self.resolveVoiceAddress(in: message) {
                if voiceResult.isDM {
                    self.lastChatTarget = nil
                    self.addChatMessage(senderName: "System", message: "Now talking to the Dungeon Master.", isAI: true)
                    self.showPartyChat()
                } else if let target = voiceResult.character {
                    self.lastChatTarget = target.id
                    self.addChatMessage(senderName: "System", message: "Now talking to \(target.name).", isAI: true)
                    self.showPartyChat()
                }
            } else if self.lastChatTarget != nil,
                      !self.looksLikeDMMessage(message),
                      let target = self.party.first(where: { $0.id == self.lastChatTarget && $0.isConscious }) {
                // Continue conversation with last @mentioned character
                self.generateTargetedChatResponse(to: message, from: target)
            } else {
                // Send to the DM (and clear any conversation target)
                self.lastChatTarget = nil
                self.generateDMChatResponse(to: message)
            }
        }

        // If called with an initial message from exploration, process it immediately
        if let initial = initialMessage, !initial.isEmpty {
            DispatchQueue.main.async {
                self.inputHandler?(initial)
            }
        }
    }

    /// Get the chat-friendly name for @mentions — strips "R. " prefix from robot names
    private func chatName(for name: String) -> String {
        // Robot names like "R. Floxxen" → "Floxxen" for @mention purposes
        if name.count > 3, name.hasPrefix("R. ") || name.hasPrefix("r. ") {
            return String(name.dropFirst(3))
        }
        return name
    }

    /// Resolve an @mention to a party member, supporting short-form (e.g. @r matches "Raj" if unique)
    private func resolveAtMention(in message: String) -> Character? {
        // Find @word at start or anywhere in the message
        let lower = message.lowercased()
        guard let atRange = lower.range(of: "@") else { return nil }

        // Extract the name fragment after @
        let afterAt = lower[atRange.upperBound...]
        let fragment = String(afterAt.prefix(while: { $0.isLetter || $0 == "'" || $0 == "-" }))
        guard !fragment.isEmpty else { return nil }

        // Don't match @dm — that should go to the DM
        if fragment == "dm" { return nil }

        // Get all party members except the player
        let playerCharId = isMultiplayer ? localCharacterId : party.first(where: { !$0.isComputerControlled })?.id
        let candidates = party.filter { $0.id != playerCharId && $0.isConscious }

        // Try exact match first (full name or chat name)
        if let exact = candidates.first(where: { $0.name.lowercased() == fragment || chatName(for: $0.name).lowercased() == fragment }) {
            return exact
        }

        // Try prefix match on both full name and chat name — only if unambiguous
        let prefixMatches = candidates.filter {
            $0.name.lowercased().hasPrefix(fragment) || chatName(for: $0.name).lowercased().hasPrefix(fragment)
        }
        if prefixMatches.count == 1 {
            return prefixMatches.first
        }

        return nil
    }

    /// Voice-friendly address resolution for phrases like "hey Snarti", "talk to Raj", "I'd like to talk to the DM"
    private struct VoiceAddressResult {
        let character: Character?
        let isDM: Bool
    }

    private func resolveVoiceAddress(in message: String) -> VoiceAddressResult? {
        let lower = message.lowercased().trimmingCharacters(in: .whitespaces)

        // Patterns that extract a name: "hey X", "talk to X", "speak to X", "I'd like to talk to X", "switch to X"
        let prefixes = [
            "hey ", "hi ", "hello ",
            "talk to ", "speak to ", "speak with ", "chat to ", "chat with ",
            "i'd like to talk to ", "id like to talk to ", "i would like to talk to ",
            "i want to talk to ", "i wanna talk to ",
            "switch to ", "go to ",
            "let me talk to ", "can i talk to ", "can i speak to ",
        ]

        var nameFragment: String?
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                let rest = String(lower.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                // Strip trailing punctuation
                let cleaned = rest.trimmingCharacters(in: CharacterSet.punctuationCharacters)
                if !cleaned.isEmpty {
                    nameFragment = cleaned
                    break
                }
            }
        }

        guard let fragment = nameFragment else { return nil }

        // Check for DM
        let dmNames = ["dm", "dungeon master", "the dm", "the dungeon master"]
        if dmNames.contains(fragment) {
            return VoiceAddressResult(character: nil, isDM: true)
        }

        // Get candidates (conscious party members, excluding player)
        let playerCharId = isMultiplayer ? localCharacterId : party.first(where: { !$0.isComputerControlled })?.id
        let candidates = party.filter { $0.id != playerCharId && $0.isConscious }

        // Try exact match
        if let exact = candidates.first(where: { $0.name.lowercased() == fragment }) {
            return VoiceAddressResult(character: exact, isDM: false)
        }

        // Try prefix match (tolerant — voice may truncate names)
        let prefixMatches = candidates.filter { $0.name.lowercased().hasPrefix(fragment) }
        if prefixMatches.count == 1 {
            return VoiceAddressResult(character: prefixMatches.first, isDM: false)
        }

        // Try contains match (voice may mangle names — "snarti" for "Snartibartfast")
        let containsMatches = candidates.filter { $0.name.lowercased().contains(fragment) }
        if containsMatches.count == 1 {
            return VoiceAddressResult(character: containsMatches.first, isDM: false)
        }

        // Fuzzy: check if fragment is a substring of a name or vice versa
        // Also check if the name starts with what they said (e.g., "snarti" → "Snartibartfast")
        let fuzzyMatches = candidates.filter { char in
            let charLower = char.name.lowercased()
            // Check if >50% of the characters match at the start (tolerant of voice transcription)
            let minLen = min(fragment.count, charLower.count)
            guard minLen >= 2 else { return false }
            let matchLen = zip(fragment, charLower).prefix(while: { $0 == $1 }).count
            return matchLen >= max(2, minLen / 2)
        }
        if fuzzyMatches.count == 1 {
            return VoiceAddressResult(character: fuzzyMatches.first, isDM: false)
        }

        return nil
    }

    /// Detect messages that are clearly directed at the DM rather than a party member
    private func looksLikeDMMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        // Explicit DM address
        if lower.hasPrefix("@dm") || lower.hasPrefix("dm,") || lower.hasPrefix("dm ") { return true }
        // Questions about the dungeon/environment — typically DM territory
        let dmKeywords = [
            "where", "what room", "what's here", "look around", "search", "investigate",
            "open door", "open chest", "pick lock", "trap", "listen", "perception",
            "cast ", "attack", "fight", "heal ", "rest", "camp",
            "give me", "i want", "can i", "can we", "let me", "let us",
            "hint", "help", "what do", "what can", "how do",
            "use ", "equip ", "drop ", "inventory",
        ]
        for keyword in dmKeywords {
            if lower.contains(keyword) { return true }
        }
        // Commands (gold, items, etc.) go to DM
        if lower.hasPrefix("/") || lower.hasPrefix("!") { return true }
        return false
    }

    /// Generate a response from a specific @mentioned party member
    private func generateTargetedChatResponse(to playerMessage: String, from character: Character) {
        // Use DMEngine for AI response if available, else use simple response
        if DMEngine.shared.isConfigured || DMEngine.shared.isAppleModelAvailable {
            let context = buildDMContext()
            let prompt = """
            You are \(character.name), a \(character.race.rawValue) \(character.characterClass.rawValue) in a D&D party. \
            Another party member is speaking directly to you. They said: "\(playerMessage)". \
            Reply in-character in 1-2 short sentences. Be brief and stay in character. \
            Do NOT use any command tags. Just reply as your character would.
            """

            DMEngine.shared.ask(prompt, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.addChatMessage(senderName: character.name, message: cleanResponse, isAI: true)
                    SpeechEngine.shared.speakAsCharacter(cleanResponse, characterName: character.name, race: character.race.rawValue, characterClass: character.characterClass.rawValue)
                    if self.isMultiplayer { self.saveChatState() }
                    self.showPartyChat()
                }
            }
        } else {
            let responses = [
                "You have my attention.",
                "Aye, I hear you.",
                "What would you have me do?",
                "I'm listening.",
                "Speak your mind.",
                "As you wish.",
                "Agreed, let's do it.",
                "I'm ready for anything.",
            ]
            let chosen = responses.randomElement()!
            addChatMessage(senderName: character.name, message: chosen, isAI: true)
            SpeechEngine.shared.speakAsCharacter(chosen, characterName: character.name, race: character.race.rawValue, characterClass: character.characterClass.rawValue)
            showPartyChat()
        }
    }

    /// Generate a DM response in the party chat
    private func generateDMChatResponse(to playerMessage: String) {
        guard DMEngine.shared.isConfigured || DMEngine.shared.isAppleModelAvailable else {
            addChatMessage(
                senderName: "Dungeon Master",
                message: "The Dungeon Master is not available. Set up an API key in Settings to enable the DM.",
                isAI: true
            )
            showPartyChat()
            return
        }

        // Snapshot state before DM interaction
        if StateSnapshotManager.shared.dmEntrySnapshot == nil {
            let snapshot = StateSnapshot.capture(
                label: "dm_entry",
                party: party,
                dungeon: dungeon,
                gameTimeMinutes: gameTimeMinutes
            )
            StateSnapshotManager.shared.write(snapshot)
        }

        // Inject recent adventure events so the DM knows what happened
        if adventureLogIndexAtLastDM < adventureLog.count {
            let newEntries = Array(adventureLog[adventureLogIndexAtLastDM...])
            if !newEntries.isEmpty {
                let summary = newEntries.joined(separator: "\n")
                DMEngine.shared.injectContext("The party has been busy since we last talked. Here is a summary of recent events:\n\(summary)")
            }
            adventureLogIndexAtLastDM = adventureLog.count
        }

        // Inject barricade state change if it differs from last DM call
        if let room = dungeon?.currentRoom {
            let currentBarricades = room.secured
            if currentBarricades != lastDMBarricadeState {
                let added = currentBarricades.subtracting(lastDMBarricadeState)
                let removed = lastDMBarricadeState.subtracting(currentBarricades)
                var changes: [String] = []
                for dir in removed {
                    changes.append("The \(dir.rawValue) door barricade has been REMOVED — that exit is now OPEN and passable.")
                }
                for dir in added {
                    changes.append("The \(dir.rawValue) door has been BARRICADED — that exit is now BLOCKED.")
                }
                if !changes.isEmpty {
                    DMEngine.shared.injectContext("BARRICADE STATE UPDATE: \(changes.joined(separator: " ")) The current barricade state in the system prompt below is authoritative — always trust it over previous conversation.")
                }
                lastDMBarricadeState = currentBarricades
            }
        }

        // Track in dmChatLog for DM conversation history
        dmChatLog.append((isUser: true, text: playerMessage))

        // Show thinking indicator
        addChatMessage(senderName: "Dungeon Master", message: "...", isAI: true)
        showPartyChat()

        let context = buildDMContext()

        DMEngine.shared.ask(playerMessage, context: context) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self else { return }

                let result = DMEngine.parseCommands(from: response)
                let adLibLevel = DMEngine.shared.adLibLevel
                let displayText = adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue ? result.cleanText : response

                // Remove the "..." thinking placeholder
                if let idx = self.activeChatLog.lastIndex(where: { $0.senderName == "Dungeon Master" && $0.message == "..." }) {
                    self.removeChatMessage(at: idx)
                }

                // Track in dmChatLog
                self.dmChatLog.append((isUser: false, text: displayText))

                // Add to party chat display
                self.addChatMessage(senderName: "Dungeon Master", message: displayText, isAI: true)

                // Speak the DM response
                SpeechEngine.shared.speak(displayText)

                // Check for missed commands in the narrative
                let missedHints = DMEngine.detectMissedCommands(
                    narrativeText: result.cleanText,
                    appliedResult: result
                )
                for hint in missedHints {
                    self.addChatMessage(senderName: "Dungeon Master", message: hint, isAI: true)
                }

                // Apply DM commands at moderate and full levels (same as askTheDM)
                var worldChanged = false
                var pendingPickupItems: [Item] = []
                var pendingGold = 0
                if adLibLevel.rawValue >= DMAdLibLevel.moderate.rawValue {
                    if result.bonusGold > 0 {
                        pendingGold = result.bonusGold
                        self.addChatMessage(senderName: "Dungeon Master", message: "[Found \(result.bonusGold) gold!]", isAI: true)
                        self.logEvent("DM awarded \(result.bonusGold) bonus gold", category: "DM")
                        worldChanged = true
                    }
                    if result.healAmount > 0 {
                        for char in self.party { char.heal(result.healAmount) }
                        self.addChatMessage(senderName: "Dungeon Master", message: "[+\(result.healAmount) HP healed!]", isAI: true)
                        self.logEvent("DM healed party for \(result.healAmount) HP", category: "DM")
                        worldChanged = true
                    }
                    if result.damageAmount > 0 {
                        for char in self.party { char.takeDamage(result.damageAmount) }
                        self.addChatMessage(senderName: "Dungeon Master", message: "[-\(result.damageAmount) HP!]", isAI: true)
                        self.logEvent("DM dealt \(result.damageAmount) damage to party", category: "DM")
                        worldChanged = true
                    }
                    if result.damagePartyAmount > 0 {
                        for char in self.party { char.takeDamage(result.damagePartyAmount) }
                        self.addChatMessage(senderName: "Dungeon Master", message: "[-\(result.damagePartyAmount) HP!]", isAI: true)
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
                    if result.lightTorch {
                        self.applyDMLightTorch()
                        worldChanged = true
                    }
                    if result.douseTorch {
                        self.applyDMDouseTorch()
                        worldChanged = true
                    }
                    if let dir = result.unsecureDirection {
                        self.applyDMUnsecure(dir)
                        worldChanged = true
                    }
                    if let dir = result.secureDirection {
                        self.applyDMSecure(dir)
                        worldChanged = true
                    }
                    for itemName in result.grantedItems {
                        if let item = self.resolveItemByName(itemName) {
                            pendingPickupItems.append(item)
                            self.addChatMessage(senderName: "Dungeon Master", message: "[Found: \(item.name)!]", isAI: true)
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

                    // Auto-apply narrative-implied item changes
                    let fallbackApplied = self.applyNarrativeFallbacks(
                        text: result.cleanText,
                        alreadyApplied: result
                    )
                    if fallbackApplied { worldChanged = true }
                }

                if worldChanged {
                    // Snapshot after DM commands applied
                    let postSnapshot = StateSnapshot.capture(
                        label: "dm_command",
                        party: self.party,
                        dungeon: self.dungeon,
                        gameTimeMinutes: self.gameTimeMinutes
                    )
                    StateSnapshotManager.shared.write(postSnapshot)
                }

                // Always log the chat interaction
                self.logEvent("Chat: \(playerMessage)", category: "CHAT")
                if !displayText.isEmpty && displayText != "..." {
                    self.logEvent("DM: \(String(displayText.prefix(120)))", category: "CHAT")
                }

                // Handle loot pickup if needed, then return to chat
                if !pendingPickupItems.isEmpty || pendingGold > 0 {
                    self.showLootSequence(gold: pendingGold, goldSource: "DM reward",
                                          items: pendingPickupItems, itemSource: "DM gift") { [weak self] in
                        self?.showPartyChat()
                    }
                } else {
                    if self.isMultiplayer { self.saveChatState() }
                    self.showPartyChat()
                }
            }
        }
    }

    /// Save multiplayer state so chat messages are visible to other players even out of turn
    private func saveChatState() {
        guard multiplayerState != nil else { return }
        Task {
            do {
                try await GameCenterManager.shared.saveCurrentTurn(matchState: multiplayerState!)
            } catch {
                // Silent failure — chat will still work locally
            }
        }
    }

    private func generateAIChatResponse(to playerMessage: String) {
        // In single-player, all non-first characters are AI companions
        // In multiplayer, only isComputerControlled characters respond
        let playerCharId = isMultiplayer ? localCharacterId : party.first(where: { !$0.isComputerControlled })?.id
        let aiChars = party.filter { char in
            char.id != playerCharId && char.isConscious
        }

        guard !aiChars.isEmpty else {
            showPartyChat()
            return
        }

        // Pick a random AI character to respond (always responds)
        let responder = aiChars.randomElement()!

        // Use DMEngine for AI response if available, else use simple response
        if DMEngine.shared.isConfigured || DMEngine.shared.isAppleModelAvailable {
            let context = buildDMContext()
            let prompt = """
            You are \(responder.name), a \(responder.race.rawValue) \(responder.characterClass.rawValue) in a D&D party. \
            Another party member just said: "\(playerMessage)". \
            Reply in-character in 1-2 short sentences. Be brief and stay in character. \
            Do NOT use any command tags. Just reply as your character would.
            """

            DMEngine.shared.ask(prompt, context: context) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.addChatMessage(senderName: responder.name, message: cleanResponse, isAI: true)
                    if self.isMultiplayer { self.saveChatState() }
                    self.showPartyChat()
                }
            }
        } else {
            // Simple responses when no AI available
            let responses = [
                "Aye, let's press on.",
                "Stay alert, friends.",
                "I've got a bad feeling about this...",
                "Together we stand!",
                "As you say.",
                "Watch the shadows...",
                "Agreed.",
                "Lead the way.",
                "My blade is ready.",
                "The dungeon grows darker...",
            ]
            let response = responses.randomElement() ?? "..."
            addChatMessage(senderName: responder.name, message: response, isAI: true)
            showPartyChat()
        }
    }

    func multiplayerPassTurn() {
        guard var state = multiplayerState else { return }

        // Sync current game state (preserves recentActions already logged)
        syncMultiplayerState(&state)

        // Find next player to pass to
        let currentIdx = state.players.firstIndex(where: { $0.gamePlayerID == localPlayerID }) ?? 0
        let nextIdx = (currentIdx + 1) % state.players.count
        let nextPlayerID = state.players[nextIdx].gamePlayerID

        state.activePlayerID = nextPlayerID
        multiplayerState = state

        passTurnToPlayer(playerID: nextPlayerID, state: state)
    }

    // MARK: - Multiplayer Combat

    func multiplayerCombatTurn() {
        guard let combat = currentCombat,
              let state = multiplayerState else {
            runCombatTurn()
            return
        }

        // Check combat end
        if combat.state == .victory {
            handleMultiplayerCombatVictory()
            return
        } else if combat.state == .defeat {
            handleMultiplayerCombatDefeat()
            return
        }

        guard let current = combat.currentCombatant else {
            combat.nextTurn()
            multiplayerCombatTurn()
            return
        }

        if current.isPlayer {
            // Find which player controls this character (check controlledCharacterIds first, then characterId)
            let ownerPlayerID = state.players.first(where: {
                $0.controlledCharacterIds.contains(current.id) || $0.characterId == current.id
            })?.gamePlayerID

            if ownerPlayerID == localPlayerID {
                // Our character — check if AI-controlled or human
                clearTerminal()
                printLines(combat.displayStatus())
                print("")

                if let character = party.first(where: { $0.id == current.id }) {
                    // Clear dodge
                    character.isDodging = false

                    // Skip if fled or playing dead
                    if character.hasFledCombat || character.isPlayingDead {
                        combat.nextTurn()
                        multiplayerCombatTurn()
                        return
                    }

                    // Tick poison
                    if character.isPoisoned {
                        let poisonResult = character.tickPoison()
                        if poisonResult.cured && poisonResult.damage == 0 {
                            print("  \(character.name) shakes off the poison!", color: .brightGreen, bold: true)
                        } else if poisonResult.damage > 0 {
                            print("  \(character.name) takes \(poisonResult.damage) poison damage!", color: .magenta)
                            logMultiplayerAction("\(character.name) takes \(poisonResult.damage) poison damage!")
                            if poisonResult.cured {
                                print("  The poison wears off.", color: .brightGreen)
                            }
                        }
                        if !character.isConscious {
                            combat.checkCombatEnd()
                            if combat.state == .defeat {
                                handleMultiplayerCombatDefeat()
                                return
                            }
                        }
                        print("")
                    }

                    // Death saving throw
                    if !character.isConscious {
                        showDeathSavingThrow(character: character)
                        return
                    }

                    // AI characters auto-play
                    if character.isComputerControlled {
                        runAICombatTurn(character: character)
                        return
                    }
                }

                showPlayerCombatMenu(characterId: current.id)
            } else {
                // Another player's character — pass turn to them
                // Re-read multiplayerState to capture any logged actions (attack reports, etc.)
                var updatedState = multiplayerState ?? state
                updatedState.activePlayerID = ownerPlayerID ?? ""
                updatedState.combat = combat
                updatedState.phase = .combat
                syncMultiplayerState(&updatedState)
                multiplayerState = updatedState
                passTurnToPlayer(playerID: ownerPlayerID ?? "", state: updatedState)
            }
        } else {
            // Monster turn — execute locally
            if let report = combat.runMonsterTurn() {
                displayAttackReport(report) { [weak self] in
                    guard let self = self else { return }
                    combat.checkCombatEnd()
                    combat.nextTurn()
                    self.multiplayerCombatTurn()
                }
            } else {
                combat.nextTurn()
                multiplayerCombatTurn()
            }
        }
    }

    /// Wrapper that routes to multiplayer or single-player combat
    func advanceCombat() {
        if isMultiplayer {
            multiplayerCombatTurn()
        } else {
            runCombatTurn()
        }
    }

    private func handleMultiplayerCombatVictory() {
        guard var state = multiplayerState else {
            handleCombatVictory()
            return
        }

        state.phase = .exploring
        state.combat = nil
        syncMultiplayerState(&state)
        multiplayerState = state

        // Run normal victory flow
        handleCombatVictory()
    }

    private func handleMultiplayerCombatDefeat() {
        guard var state = multiplayerState else {
            handleCombatDefeat()
            return
        }

        state.phase = .gameOver
        syncMultiplayerState(&state)
        multiplayerState = state

        // End the match for all players
        Task {
            try? await GameCenterManager.shared.endMatch(matchState: state, outcome: .lost)
        }

        handleCombatDefeat()
    }

    // MARK: - Multiplayer Match End

    private func showMultiplayerVictory() {
        clearTerminal()
        printTitle("VICTORY!")
        print("Your party has triumphed!", color: .brightGreen)
        print("")

        if let state = multiplayerState {
            for player in state.players {
                if let charId = player.characterId,
                   let char = state.party.first(where: { $0.id == charId }) {
                    print("  \(player.displayName): \(char.name) — Level \(char.level)", color: .cyan)
                }
            }
        }
        print("")

        showMenu(["Back to Main Menu"])
        menuHandler = { [weak self] _ in
            self?.isMultiplayer = false
            self?.multiplayerState = nil
            self?.showMainMenu()
        }
    }

    private func showMultiplayerDefeat() {
        clearTerminal()
        printTitle("DEFEAT")
        print("Your party has fallen...", color: .red)
        print("")

        showMenu(["Back to Main Menu"])
        menuHandler = { [weak self] _ in
            self?.isMultiplayer = false
            self?.multiplayerState = nil
            self?.showMainMenu()
        }
    }

    private func showMatchAbandoned() {
        clearTerminal()
        printTitle("Match Abandoned")
        print("This match has been abandoned.", color: .dimGreen)
        print("")

        // If we have game state, offer to continue as local game
        if let state = multiplayerState, !state.party.isEmpty, state.phase == .exploring || state.phase == .combat {
            print("You can continue this adventure", color: .yellow)
            print("as a local game. Other players'", color: .yellow)
            print("characters will become AI.", color: .yellow)
            print("")

            showMenu(["Continue as Local Game", "Back to Main Menu"])
            menuHandler = { [weak self] choice in
                if choice == 1 {
                    self?.convertToLocalGame()
                } else {
                    self?.isMultiplayer = false
                    self?.multiplayerState = nil
                    self?.showMainMenu()
                }
            }
        } else {
            showMenu(["Back to Main Menu"])
            menuHandler = { [weak self] _ in
                self?.isMultiplayer = false
                self?.multiplayerState = nil
                self?.showMainMenu()
            }
        }
    }

    /// Show notification when a remote player leaves mid-game
    private func showPlayerLeftNotification(playerName: String, characterName: String) {
        clearTerminal()
        printTitle("Player Left")
        print("\(playerName) has left the game.", color: .yellow)
        print("")
        print("\(characterName) will now be controlled", color: .dimGreen)
        print("by the AI.", color: .dimGreen)
        print("")
        print("You can continue as a local game", color: .dimGreen)
        print("or return to the main menu.", color: .dimGreen)
        print("")

        showMenu(["Continue as Local Game", "Back to Main Menu"])
        menuHandler = { [weak self] choice in
            if choice == 1 {
                self?.convertToLocalGame()
            } else {
                self?.isMultiplayer = false
                self?.multiplayerState = nil
                self?.showMainMenu()
            }
        }
    }

    /// Convert a multiplayer game to a local game, keeping all characters (AI-controlled ones stay AI)
    private func convertToLocalGame() {
        guard let state = multiplayerState else {
            showMainMenu()
            return
        }

        // Load party and dungeon from multiplayer state
        party = state.party
        dungeon = state.dungeon
        gameTimeMinutes = state.gameTimeMinutes
        adventureLog = state.adventureLog
        monstersSlain = state.monstersSlain
        combatsWon = state.combatsWon
        torchLit = state.torchLit
        torchTurnsRemaining = state.torchTurnsRemaining

        // Remove the match from Game Center before clearing the reference
        if let match = GameCenterManager.shared.currentMatch {
            Task { try? await match.remove() }
        }

        // Clear multiplayer state
        isMultiplayer = false
        multiplayerState = nil
        GameCenterManager.shared.currentMatch = nil

        clearTerminal()
        printTitle("Local Game")
        print("The adventure continues!", color: .brightGreen)
        print("")
        print("  Your party:", color: .cyan, bold: true)
        for char in party {
            let hpColor: TerminalColor = char.currentHP < char.maxHP / 3 ? .red :
                (char.currentHP < char.maxHP * 2 / 3 ? .yellow : .green)
            print("    \(char.name) — \(char.currentHP)/\(char.maxHP) HP", color: hpColor)
        }
        print("")

        if self.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: self.explorationMelodyChoice) }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.gameState = .exploring
            self?.showExplorationView()
        }
    }

    // MARK: - Multiplayer Helpers

    /// Sync current game state into multiplayer state
    private func syncMultiplayerState(_ state: inout MultiplayerMatchState) {
        state.party = party
        state.dungeon = dungeon ?? state.dungeon
        state.gameTimeMinutes = gameTimeMinutes
        state.adventureLog = adventureLog
        state.monstersSlain = monstersSlain
        state.combatsWon = combatsWon
        state.torchLit = torchLit
        state.torchTurnsRemaining = torchTurnsRemaining
    }
}

// MARK: - TurnBasedMatchDelegate

extension GameEngine: TurnBasedMatchDelegate {
    func didReceiveTurn(match: GKTurnBasedMatch, didBecomeActive: Bool) {
        stopMatchPolling()
        GameCenterManager.shared.currentMatch = match

        // Play D&D horn call to alert the player
        SoundManager.shared.playMultiplayerNotification()

        // If we just created this match from the integrated invite flow
        // (pendingRemoteSlots is set and match data is empty), set up the match state
        if !pendingRemoteSlots.isEmpty,
           match.matchData == nil || match.matchData?.isEmpty == true {
            handleNewMatchFromInviteFlow(match)
            return
        }

        // If converting a local game to multiplayer (AI char → remote player)
        if let remoteCharId = pendingRemoteCharacterId,
           match.matchData == nil || match.matchData?.isEmpty == true {
            handleLocalToMultiplayerConversion(match: match, remoteCharacterId: remoteCharId)
            return
        }

        // If didBecomeActive (user tapped notification), load directly
        if didBecomeActive {
            loadMultiplayerMatch(match)
            return
        }

        // Otherwise, show a prompt asking the player
        showIncomingTurnPrompt(match: match)
    }

    private func showIncomingTurnPrompt(match: GKTurnBasedMatch) {
        let players = match.participants.compactMap { $0.player?.displayName }
            .filter { $0 != GKLocalPlayer.local.displayName }
        let who = players.isEmpty ? "Another player" : players.joined(separator: ", ")

        // Determine if this is a new invite or a turn
        let isInvite = match.status == .matching
        let hasState = match.matchData != nil && !(match.matchData?.isEmpty ?? true)

        clearTerminal()
        printTitle("Multiplayer")
        print("")
        if isInvite || !hasState {
            print("  \(who) wants you to join", color: .cyan, bold: true)
            print("  a multiplayer adventure!", color: .cyan, bold: true)
        } else {
            print("  It's your turn!", color: .cyan, bold: true)
            print("  Game with: \(who)", color: .brightGreen)

            // Try to show match info
            if let data = match.matchData, !data.isEmpty,
               let state = try? MultiplayerMatchState.decoded(from: data) {
                print("  \(state.dungeon.name) (Lv\(state.dungeonLevel))", color: .dimGreen)
            }
        }
        print("")

        showMenuOptions([
            MenuOption("Connect", isDefault: true, tint: .cyan),
            MenuOption("Ignore"),
            MenuOption("< Not Now")
        ])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1:
                self?.loadMultiplayerMatch(match)
            case 2:
                // Ignore — decline the invite and remove the match
                self?.pendingInviteMatch = nil
                self?.executeDeleteRemoteMatch(match) {
                    if self?.gameState == .mainMenu {
                        self?.showMainMenu()
                    }
                }
            default:
                // Cache the match for later
                self?.pendingInviteMatch = match
                if self?.gameState == .mainMenu {
                    self?.showMainMenu()
                }
            }
        }
    }

    func matchEnded(match: GKTurnBasedMatch) {
        stopMatchPolling()
        guard let data = match.matchData, !data.isEmpty,
              let state = try? MultiplayerMatchState.decoded(from: data) else { return }

        multiplayerState = state
        isMultiplayer = true

        switch state.phase {
        case .victory: showMultiplayerVictory()
        case .gameOver: showMultiplayerDefeat()
        default: showMatchAbandoned()
        }
    }

    func playerWantsToQuit(match: GKTurnBasedMatch, player: GKPlayer) {
        // Try to get state from our local copy or the match data
        var state: MultiplayerMatchState
        if let localState = multiplayerState {
            state = localState
        } else if let data = match.matchData, !data.isEmpty,
                  let decoded = try? MultiplayerMatchState.decoded(from: data) {
            var mutable = decoded
            mutable.relinkCombat()
            state = mutable
        } else {
            print("\(player.displayName) left the game.", color: .yellow)
            return
        }

        // Mark quitting player's character as AI-controlled
        let quitterName: String
        if let slot = state.players.first(where: { $0.gamePlayerID == player.gamePlayerID }),
           let charId = slot.characterId,
           let char = state.party.first(where: { $0.id == charId }) {
            char.markAsAI()
            quitterName = char.name
        } else {
            quitterName = player.displayName
        }

        // If the party leader quit, promote next human player
        if let idx = state.players.firstIndex(where: { $0.gamePlayerID == player.gamePlayerID }),
           state.players[idx].isPartyLeader {
            state.players[idx].isPartyLeader = false
            if let nextHuman = state.players.first(where: { slot in
                slot.gamePlayerID != player.gamePlayerID &&
                !(state.party.first(where: { c in c.id == slot.characterId })?.isComputerControlled ?? true)
            }) {
                if let nextIdx = state.players.firstIndex(where: { $0.gamePlayerID == nextHuman.gamePlayerID }) {
                    state.players[nextIdx].isPartyLeader = true
                }
            }
        }

        state.addAction(playerName: player.displayName, description: "\(quitterName) is now AI-controlled (player left)")
        multiplayerState = state

        // Show notification and offer to convert to local game
        showPlayerLeftNotification(playerName: player.displayName, characterName: quitterName)
    }
}
