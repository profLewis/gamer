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
        print("Press Enter to use default options", color: .gray)
        print("")

        showMenu(["New Game", "Load Game", "How to Play", "Quit"])

        menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.startNewGame()
            case 2: self?.print("No saved games found.", color: .yellow)
                    self?.showMainMenu()
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
        print("• Tap menu options to select")
        print("• Type text when prompted")
        print("• Tap 'Continue' to advance")
        print("")
        print("GAMEPLAY:", color: .cyan, bold: true)
        print("• Create a party of adventurers")
        print("• Explore procedurally generated dungeons")
        print("• Fight monsters in turn-based combat")
        print("• Collect treasure and gain experience")
        print("")
        print("COMBAT:", color: .cyan, bold: true)
        print("• Initiative determines turn order")
        print("• Roll d20 + modifiers vs AC to hit")
        print("• Defeat all enemies to win!")
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

        showMenu(["1 Character (Solo)", "2 Characters", "3 Characters", "4 Characters (Full Party)"])

        menuHandler = { [weak self] choice in
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
        promptText("Enter character name:")

        inputHandler = { [weak self] name in
            self?.tempCharacterName = name.isEmpty ? "Adventurer" : name
            self?.chooseRace()
        }
    }

    func chooseRace() {
        clearTerminal()
        printSubtitle("Choose Race for \(tempCharacterName)")

        let races = Race.allCases
        let raceNames = races.map { "\($0.rawValue)" }

        showMenu(raceNames)

        menuHandler = { [weak self] choice in
            self?.tempRace = races[choice - 1]
            self?.chooseClass()
        }
    }

    func chooseClass() {
        clearTerminal()
        printSubtitle("Choose Class for \(tempCharacterName)")

        let classes = CharacterClass.allCases
        let classNames = classes.map { "\($0.rawValue) (d\($0.hitDie) HP)" }

        showMenu(classNames)

        menuHandler = { [weak self] choice in
            self?.tempClass = classes[choice - 1]
            self?.chooseAbilityMethod()
        }
    }

    func chooseAbilityMethod() {
        clearTerminal()
        printSubtitle("Ability Score Method")

        print("Choose how to generate ability scores:")
        print("")

        showMenu(["Standard Array [15,14,13,12,10,8]", "Roll 4d6 drop lowest"])

        menuHandler = { [weak self] choice in
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

        let abilityNames = remainingAbilities.map { ability -> String in
            let isPrimary = ability == tempClass?.primaryAbility
            return isPrimary ? "\(ability.rawValue) (Recommended)" : ability.rawValue
        }

        showMenu(abilityNames)

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

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
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
        let skillNames = unselected.map { $0.rawValue }

        print("Skill \(selectedSkills.count + 1):")
        showMenu(skillNames)

        menuHandler = { [weak self] choice in
            guard let self = self else { return }
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
            self?.selectDifficulty(dungeonName: dungeonName)
        }
    }

    func selectDifficulty(dungeonName: String) {
        print("")
        print("Choose difficulty:")

        showMenu(["Easy (Level 1)", "Medium (Level 2)", "Hard (Level 3)"])

        menuHandler = { [weak self] choice in
            self?.dungeon = Dungeon(name: dungeonName, level: choice)
            self?.clearTerminal()
            self?.print("Entering \(dungeonName)...", color: .brightGreen, bold: true)
            self?.print("")

            if let room = self?.dungeon?.currentRoom {
                self?.print(room.describe())
            }

            self?.gameState = .exploring
            self?.showExplorationMenu()
        }
    }

    // MARK: - Exploration

    func showExplorationMenu() {
        guard let room = dungeon?.currentRoom else { return }

        print("")

        // Show party status
        print("PARTY:", color: .cyan)
        for char in party {
            let hp = "\(char.currentHP)/\(char.maxHP)"
            print("  \(char.name): \(hp) HP")
        }
        print("")

        // Check for encounter
        if !room.cleared, let encounter = room.encounter {
            print("⚔️ Enemies ahead!", color: .red, bold: true)
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

        options.append("View Map")
        actions.append { [weak self] in self?.showMap() }

        options.append("Party Status")
        actions.append { [weak self] in self?.showPartyStatus() }

        options.append("Rest")
        actions.append { [weak self] in self?.rest() }

        showMenu(options)

        menuHandler = { [weak self] choice in
            if choice > 0 && choice <= actions.count {
                actions[choice - 1]()
            }
        }
    }

    func move(_ direction: Direction) {
        guard let dungeon = dungeon else { return }

        let result = dungeon.move(direction: direction)
        clearTerminal()
        print(result.message)

        if result.success {
            showExplorationMenu()
        } else {
            showExplorationMenu()
        }
    }

    func searchRoom() {
        clearTerminal()
        print("You search the room carefully...")
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
            self?.clearTerminal()
            if let room = self?.dungeon?.currentRoom {
                self?.print(room.describe())
            }
            self?.showExplorationMenu()
        }
    }

    func collectTreasure() {
        guard let room = dungeon?.currentRoom, !room.treasure.isEmpty else {
            print("No treasure to collect.")
            showExplorationMenu()
            return
        }

        clearTerminal()
        print("Collected treasure:", color: .brightGreen, bold: true)
        print("")

        var totalGold = 0
        for item in room.treasure {
            print("  • \(item.name)")
            if item.type == .gold {
                totalGold += item.value
            }
        }

        party.first?.gold += totalGold
        room.treasure.removeAll()

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.clearTerminal()
            if let room = self?.dungeon?.currentRoom {
                self?.print(room.describe())
            }
            self?.showExplorationMenu()
        }
    }

    func showMap() {
        clearTerminal()
        if let map = dungeon?.getMapDisplay() {
            print(map)
        }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.clearTerminal()
            if let room = self?.dungeon?.currentRoom {
                self?.print(room.describe())
            }
            self?.showExplorationMenu()
        }
    }

    func showPartyStatus() {
        clearTerminal()
        printTitle("Party Status")

        for char in party {
            printLines(char.displaySheet())
            print("")
        }

        waitForContinue()
        inputHandler = { [weak self] _ in
            self?.clearTerminal()
            if let room = self?.dungeon?.currentRoom {
                self?.print(room.describe())
            }
            self?.showExplorationMenu()
        }
    }

    func rest() {
        clearTerminal()
        print("Choose rest type:")

        showMenu(["Short Rest (Recover some HP)", "Long Rest (Full Recovery)"])

        menuHandler = { [weak self] choice in
            guard let self = self else { return }

            self.clearTerminal()

            if choice == 1 {
                // Short rest
                self.print("Your party takes a short rest...")
                for char in self.party {
                    let healAmount = Dice.rollSum(1, d: char.characterClass.hitDie)
                    char.heal(healAmount)
                    self.print("\(char.name) recovers \(healAmount) HP")
                }
            } else {
                // Long rest
                self.print("Your party takes a long rest...")
                for char in self.party {
                    char.heal(char.maxHP)
                    self.print("\(char.name) fully recovers!")
                }
            }

            self.waitForContinue()
            self.inputHandler = { [weak self] _ in
                self?.clearTerminal()
                if let room = self?.dungeon?.currentRoom {
                    self?.print(room.describe())
                }
                self?.showExplorationMenu()
            }
        }
    }

    // MARK: - Combat

    func startCombat(encounter: Encounter) {
        gameState = .combat
        currentCombat = Combat(party: party, encounter: encounter)

        clearTerminal()
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
            // Player turn
            showPlayerCombatMenu(characterId: current.id)
        } else {
            // Monster turn
            print("\(current.name)'s turn...", color: .red)
            print("")

            let result = combat.runMonsterTurn()
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
                let result = combat.playerAttack(characterId: characterId, targetId: targetId)
                self.print("")
                self.print(result)
            } else {
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
            self?.clearTerminal()
            if let room = self?.dungeon?.currentRoom {
                self?.print(room.describe())
            }
            self?.showExplorationMenu()
        }
    }

    func handleCombatDefeat() {
        clearTerminal()
        gameState = .gameOver

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
        clearTerminal()
        gameState = .victory

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

    func resetGame() {
        party = []
        dungeon = nil
        currentCombat = nil
        clearTerminal()
        showMainMenu()
    }
}
