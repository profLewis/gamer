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
    @Published var awaitingTextInput: Bool = false
    @Published var awaitingContinue: Bool = false
    @Published var gameState: GameState = .mainMenu

    // MARK: - Game State

    @Published var party: [Character] = []
    @Published var dungeon: Dungeon?
    @Published var currentCombat: Combat?

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
    private var inputHandler: ((String) -> Void)?
    private var menuHandler: ((Int) -> Void)?

    // MARK: - Initialization

    init() {}

    // MARK: - Terminal Output

    func print(_ text: String, color: TerminalColor = .green, bold: Bool = false, size: CGFloat = 14) {
        DispatchQueue.main.async {
            self.terminalLines.append(TerminalLine(text, color: color, bold: bold, size: size))
        }
    }

    func printLines(_ lines: [String], color: TerminalColor = .green) {
        for line in lines {
            print(line, color: color)
        }
    }

    func printTitle(_ text: String) {
        let border = String(repeating: "═", count: text.count + 4)
        print("╔\(border)╗", color: .brightGreen, bold: true)
        print("║  \(text)  ║", color: .brightGreen, bold: true)
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
            self.currentMenuOptions = options.enumerated().map { index, text in
                MenuOption(text, isDefault: index == defaultIndex)
            }
            self.awaitingTextInput = false
            self.awaitingContinue = false
        }
    }

    func promptText(_ prompt: String) {
        print(prompt, color: .green)
        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.awaitingTextInput = true
            self.awaitingContinue = false
        }
    }

    func waitForContinue() {
        DispatchQueue.main.async {
            self.currentMenuOptions = []
            self.awaitingTextInput = false
            self.awaitingContinue = true
        }
    }

    func handleMenuChoice(_ choice: Int) {
        DispatchQueue.main.async {
            self.currentMenuOptions = []
        }

        if let handler = menuHandler {
            handler(choice)
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
        clearTerminal()
        showMainMenu()
    }

    // MARK: - Main Menu

    func showMainMenu() {
        gameState = .mainMenu

        printTitle("D&D 5e Text Adventure")
        print("A text-based role-playing game", color: .dimGreen)
        print("")

        showMenu(["New Game", "Load Game", "How to Play", "Quit"])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.startNewGame()
            case 2: self?.showLoadGameMenu(returnTo: .mainMenu)
            case 3: self?.showHowToPlay()
            case 4: self?.quitApp()
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

    func startCharacterCreation() {
        clearTerminal()
        gameState = .characterCreation

        printSubtitle("Character \(creatingCharacterIndex + 1) of \(totalCharacters)")
        promptText("Enter character name (or 'back'):")

        inputHandler = { [weak self] name in
            if name.lowercased() == "back" {
                self?.clearTerminal()
                self?.startNewGame()
                return
            }
            self?.tempCharacterName = name.isEmpty ? "Adventurer" : name
            self?.chooseRace()
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

        party.append(character)

        clearTerminal()
        print("\(character.name) joins the party!", color: .brightGreen, bold: true)
        print("")
        printLines(character.displaySheet())

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

    // MARK: - Adventure

    func startAdventure() {
        clearTerminal()
        printTitle("Adventure Awaits!")

        promptText("Name your dungeon (or press Enter for default):")

        inputHandler = { [weak self] name in
            let dungeonName = name.isEmpty ? "The Dark Depths" : name
            self?.tempDungeonName = dungeonName
            self?.selectDifficulty(dungeonName: dungeonName)
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
        showExplorationView()
    }

    // MARK: - Exploration

    /// Redraws the full exploration screen: map + room description + party + menu
    func showExplorationView() {
        guard let dungeon = dungeon, let room = dungeon.currentRoom else { return }

        clearTerminal()

        // Always show the map at the top
        let mapLines = dungeon.getMapDisplay()
        printLines(mapLines, color: .dimGreen)
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

        // Party status bar
        let partyStr = party.map { "\($0.name) \($0.currentHP)/\($0.maxHP)HP" }.joined(separator: "  ")
        print(partyStr, color: .cyan)
        print("")

        // Check for encounter
        if !room.cleared, let encounter = room.encounter {
            print("Enemies ahead!", color: .red, bold: true)
            startCombat(encounter: encounter)
            return
        }

        // Build menu options
        var options: [String] = []
        var actions: [() -> Void] = []

        for direction in Direction.allCases {
            if room.exits[direction] != nil {
                options.append("Go \(direction.rawValue)")
                actions.append { [weak self] in self?.move(direction) }
            }
        }

        options.append("Search Room")
        actions.append { [weak self] in self?.searchRoom() }

        if !room.treasure.isEmpty {
            options.append("Collect Treasure")
            actions.append { [weak self] in self?.collectTreasure() }
        }

        options.append("Party Status")
        actions.append { [weak self] in self?.showPartyStatus() }

        options.append("Rest")
        actions.append { [weak self] in self?.rest() }

        options.append("Save Game")
        actions.append { [weak self] in self?.showSaveMenu() }

        showMenu(options)

        menuHandler = { choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    func move(_ direction: Direction) {
        guard let dungeon = dungeon else { return }

        let result = dungeon.move(direction: direction)
        if !result.success {
            print(result.message, color: .yellow)
        }
        showExplorationView()
    }

    func searchRoom() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen)
            print("")
        }

        print("You search the room carefully...", color: .cyan)
        print("")

        let roll = Dice.d20()
        let bestPerception = party.map { $0.skillModifier(for: .perception) }.max() ?? 0
        let total = roll + bestPerception

        if total >= 15 {
            print("You found something!", color: .brightGreen)
            if Dice.d6() >= 4 {
                let gold = Dice.rollSum(2, d: 6) * 5
                print("Hidden stash: \(gold) gold pieces!")
                party.first?.gold += gold
            } else {
                print("A secret alcove, but it's empty.")
            }
        } else {
            print("You don't find anything of interest.")
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
            printLines(dungeon.getMapDisplay(), color: .dimGreen)
            print("")
        }

        print("Collected treasure:", color: .brightGreen, bold: true)
        print("")

        var totalGold = 0
        for item in room.treasure {
            print("  \(item.name)")
            if item.type == .gold {
                totalGold += item.value
            }
        }

        party.first?.gold += totalGold
        room.treasure.removeAll()

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    func showPartyStatus() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen)
            print("")
        }

        printLines(asciiParty, color: .cyan)
        print("")
        printTitle("Party Status")

        for char in party {
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

        showMenu(["< Back"])
        menuHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    func rest() {
        clearTerminal()

        // Show map at top
        if let dungeon = dungeon {
            printLines(dungeon.getMapDisplay(), color: .dimGreen)
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
                self.printLines(dungeon.getMapDisplay(), color: .dimGreen)
                self.print("")
            }

            SoundManager.shared.playHeal()
            if choice == 1 {
                self.print("Your party takes a short rest...", color: .cyan)
                for char in self.party {
                    let healAmount = Dice.rollSum(1, d: char.characterClass.hitDie)
                    char.heal(healAmount)
                    self.print("\(char.name) recovers \(healAmount) HP")
                }
            } else {
                self.print("Your party takes a long rest...", color: .cyan)
                for char in self.party {
                    char.heal(char.maxHP)
                    self.print("\(char.name) fully recovers!")
                }
            }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.showExplorationView()
            }
        }
    }

    // MARK: - Combat

    func startCombat(encounter: Encounter) {
        gameState = .combat
        currentCombat = Combat(party: party, encounter: encounter)
        SoundManager.shared.playBattleStart()

        clearTerminal()
        printLines(asciiSwords, color: .red)
        print("")
        printTitle("COMBAT!")

        for monster in encounter.monsters {
            print("\(monster.name) appears!", color: .red)
        }
        print("")
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
            showPlayerCombatMenu(characterId: current.id)
        } else {
            let result = combat.runMonsterTurn()

            // Show monster attack ASCII art and sound
            if result.contains("CRITICAL") {
                SoundManager.shared.playCrit()
                printLines(asciiCriticalHit, color: .red)
            } else if result.contains("deals") {
                SoundManager.shared.playMonsterAttack()
                printLines(asciiMonsterAttack, color: .red)
            } else {
                SoundManager.shared.playMiss()
                printLines(asciiMiss, color: .dimGreen)
            }
            print("")
            print(result)

            combat.checkCombatEnd()
            combat.nextTurn()

            waitForContinue()
            inputHandler = { [weak self] _ in
                self?.runCombatTurn()
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

        for monster in aliveMonsters {
            options.append("Attack \(monster.name)")
        }
        options.append("Dodge (defensive stance)")

        showMenu(options)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }

            if choice <= aliveMonsters.count {
                let targetId = aliveMonsters[choice - 1].id
                let targetName = aliveMonsters[choice - 1].name
                let result = combat.playerAttack(characterId: characterId, targetId: targetId)

                self.clearTerminal()
                self.printLines(combat.displayStatus())
                self.print("")

                // Show attack ASCII art and sound based on result
                if result.contains("CRITICAL") {
                    SoundManager.shared.playCrit()
                    self.printLines(self.asciiCriticalHit, color: .yellow)
                } else if result.contains("deals") {
                    SoundManager.shared.playHit()
                    self.printLines(self.asciiHit(attacker: character.name, target: targetName), color: .brightGreen)
                } else {
                    SoundManager.shared.playMiss()
                    self.printLines(self.asciiMiss, color: .dimGreen)
                }
                self.print("")
                self.print(result)
            } else {
                self.clearTerminal()
                self.printLines(combat.displayStatus())
                self.print("")
                self.printLines(self.asciiDodge, color: .cyan)
                self.print("")
                self.print("\(character.name) takes a defensive stance.")
            }

            combat.checkCombatEnd()
            combat.nextTurn()

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.runCombatTurn()
            }
        }
    }

    func handleCombatVictory() {
        guard let combat = currentCombat else { return }
        SoundManager.shared.playVictory()

        clearTerminal()
        printTitle("VICTORY!")

        let xp = combat.encounter.totalXP
        let xpEach = xp / party.count

        print("All enemies defeated!", color: .brightGreen)
        print("")
        print("Experience gained: \(xp) XP (\(xpEach) each)")

        for char in party {
            char.experiencePoints += xpEach
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

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.showExplorationView()
        }
    }

    func handleCombatDefeat() {
        SoundManager.shared.playDefeat()
        clearTerminal()
        gameState = .gameOver

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
        SoundManager.shared.playVictory()
        clearTerminal()
        gameState = .victory

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
        print("  Experience gained: \(totalXP)")
        print("")

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.resetGame()
        }
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

        promptText("Enter a name for this save (or press Enter for default):")

        inputHandler = { [weak self] name in
            self?.performSave(saveName: name)
        }
    }

    private func performSave(saveName: String) {
        guard let dungeon = dungeon else { return }

        let partyDesc = party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", ")

        let slotName: String
        if saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let timestamp = dateFormatter.string(from: Date())
            slotName = "\(party.first?.name ?? "Unknown") - \(timestamp)"
        } else {
            slotName = saveName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let saveGame = SaveGame(
            id: UUID(),
            savedAt: Date(),
            slotName: slotName,
            partyDescription: partyDesc,
            dungeonName: dungeon.name,
            dungeonLevel: dungeon.level,
            party: party,
            dungeon: dungeon,
            gameState: .exploring
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

        let saves = SaveGameManager.shared.listSaves()

        if saves.isEmpty {
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

        for (index, save) in saves.enumerated() {
            let dateStr = dateFormatter.string(from: save.savedAt)
            print("\(index + 1). \(save.slotName)", color: .brightGreen)
            print("   \(save.partyDescription)", color: .dimGreen)
            print("   \(save.dungeonName) (Level \(save.dungeonLevel)) - \(dateStr)", color: .dimGreen)
            print("")
        }

        var options = saves.map { $0.slotName }
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

            let selectedSave = saves[choice - 1]
            self?.loadGame(selectedSave)
        }
    }

    private func showManageSavesMenu(returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printTitle("Manage Saves")

        let saves = SaveGameManager.shared.listSaves()

        if saves.isEmpty {
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

        for (index, save) in saves.enumerated() {
            let dateStr = dateFormatter.string(from: save.savedAt)
            print("\(index + 1). \(save.slotName)", color: .brightGreen)
            print("   \(save.partyDescription)", color: .dimGreen)
            print("   \(dateStr)", color: .dimGreen)
            print("")
        }

        var options = saves.map { $0.slotName }
        options.append("< Back")

        print("Select a save to manage:", color: .cyan)
        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice == options.count {
                self?.showLoadGameMenu(returnTo: origin)
                return
            }
            let selectedSave = saves[choice - 1]
            self?.showSaveActions(save: selectedSave, returnTo: origin)
        }
    }

    private func showSaveActions(save: SaveGame, returnTo origin: LoadGameOrigin) {
        clearTerminal()
        printSubtitle(save.slotName)
        print("  \(save.partyDescription)", color: .dimGreen)
        print("  \(save.dungeonName) (Level \(save.dungeonLevel))", color: .dimGreen)
        print("")

        showMenu(["Rename", "Delete", "< Back"])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.renameSave(save: save, returnTo: origin)
            case 2: self?.confirmDeleteSave(save: save, returnTo: origin)
            default: self?.showManageSavesMenu(returnTo: origin)
            }
        }
    }

    private func renameSave(save: SaveGame, returnTo origin: LoadGameOrigin) {
        print("")
        promptText("Enter new name for this save:")

        inputHandler = { [weak self] newName in
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                self?.print("Name cannot be empty.", color: .yellow)
                self?.showSaveActions(save: save, returnTo: origin)
                return
            }

            let renamed = SaveGame(
                id: save.id,
                savedAt: save.savedAt,
                slotName: trimmed,
                partyDescription: save.partyDescription,
                dungeonName: save.dungeonName,
                dungeonLevel: save.dungeonLevel,
                party: save.party,
                dungeon: save.dungeon,
                gameState: save.gameState
            )

            SaveGameManager.shared.delete(id: save.id)
            do {
                try SaveGameManager.shared.save(renamed)
                self?.print("")
                self?.print("Renamed to '\(trimmed)'", color: .brightGreen)
            } catch {
                self?.print("Error saving: \(error.localizedDescription)", color: .red)
            }

            self?.print("")
            self?.waitForContinue()
            self?.inputHandler = { [weak self] _ in
                self?.showManageSavesMenu(returnTo: origin)
            }
        }
    }

    private func confirmDeleteSave(save: SaveGame, returnTo origin: LoadGameOrigin) {
        print("")
        print("Delete '\(save.slotName)'?", color: .red, bold: true)
        print("This cannot be undone.", color: .yellow)
        print("")

        showMenu(["Yes, Delete", "No, Keep It"])

        menuHandler = { [weak self] choice in
            if choice == 1 {
                SaveGameManager.shared.delete(id: save.id)
                self?.print("")
                self?.print("Save deleted.", color: .red)
                self?.print("")
                self?.waitForContinue()
                self?.inputHandler = { [weak self] _ in
                    self?.showManageSavesMenu(returnTo: origin)
                }
            } else {
                self?.showSaveActions(save: save, returnTo: origin)
            }
        }
    }

    private func loadGame(_ save: SaveGame) {
        party = save.party
        dungeon = save.dungeon
        currentCombat = nil
        gameState = .exploring

        clearTerminal()
        print("Game loaded!", color: .brightGreen, bold: true)
        print("")
        print("Welcome back to \(save.dungeonName).", color: .cyan)
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
        clearTerminal()
        showMainMenu()
    }

    func quitApp() {
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
            "  .     .       .  .   . .   .   . .    +  .",
            "    .     .  :     .    .. :. .___---------_.",
            "         .  .   .    .  :.:. _\".^ .^ ^.  '.. \\",
            "      .  :       .  .  .:../:            . .=;.",
            "    .   . :: +.  .  :  | ..    .;/        .-\"",
            "     .  :    .     . . . ..    /   .   .    .",
            "            .   . .. .   .. :/    .:        .",
            "      +   .   .  .  . :  .:../       .  +  .",
            "         .          .  . ..:./ .          .",
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
        [
            "  o   o   o   o",
            " /|\\ /|\\ /|\\ /|\\",
            " / \\ / \\ / \\ / \\",
            " [=] [~] [+] [*]",
        ]
    }
}
