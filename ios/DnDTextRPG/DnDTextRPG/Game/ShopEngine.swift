//
//  ShopEngine.swift
//  DnDTextRPG
//
//  Marketplace / shop system
//

import Foundation

class ShopEngine {

    private weak var game: GameEngine?
    private var stock: [Item] = []
    private var character: Character?

    init(game: GameEngine) {
        self.game = game
    }

    func openShop(character: Character, dungeonLevel: Int, completion: @escaping () -> Void) {
        self.character = character
        self.stock = ItemCatalog.shopStock(forLevel: dungeonLevel)
        showShopMain(completion: completion)
    }

    // MARK: - Main Menu

    private func showShopMain(completion: @escaping () -> Void) {
        guard let game = game, let character = character else { return }

        game.clearTerminal()
        game.printTitle("Merchant's Shop")
        game.print("")
        game.print("  A hooded merchant eyes you from behind the counter.", color: .cyan)
        game.print("  \"Welcome, adventurer. Browse my wares...\"", color: .cyan)
        game.print("")
        game.print("  Your gold: \(character.gold)", color: .yellow)
        game.print("  Carry weight: \(String(format: "%.0f", character.currentWeight))/\(String(format: "%.0f", character.carryCapacity)) lb", color: .dimGreen)
        game.print("")

        game.showMenu(["Buy", "Sell", "< Leave Shop"])

        game.menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.showBuyMenu(completion: completion)
            case 2: self?.showSellMenu(completion: completion)
            default: completion()
            }
        }
    }

    // MARK: - Buy

    private func showBuyMenu(completion: @escaping () -> Void) {
        guard let game = game, let character = character else { return }

        game.clearTerminal()
        game.printTitle("Buy Items")
        game.print("  Gold: \(character.gold)", color: .yellow)
        game.print("")

        var options: [String] = []
        for item in stock {
            let affordable = character.gold >= item.value ? "" : " [can't afford]"
            let heavy = character.canCarry(item) ? "" : " [too heavy]"
            options.append("\(item.name) — \(item.value)gp (\(String(format: "%.1f", item.weight))lb)\(affordable)\(heavy)")
        }
        options.append("< Back")

        game.showMenu(options)

        game.menuHandler = { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            if choice == options.count {
                self.showShopMain(completion: completion)
                return
            }

            guard choice > 0 && choice <= self.stock.count else { return }
            let item = self.stock[choice - 1]

            guard character.gold >= item.value else {
                game.print("")
                game.print("  \"You haven't got enough gold for that, friend.\"", color: .red)
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in
                    self?.showBuyMenu(completion: completion)
                }
                return
            }

            guard character.canCarry(item) else {
                game.print("")
                game.print("  \"You can barely stand as it is! Lighten your load first.\"", color: .red)
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in
                    self?.showBuyMenu(completion: completion)
                }
                return
            }

            character.gold -= item.value
            let newItem = item.newInstance()
            _ = character.addItem(newItem)

            game.print("")
            game.print("  Purchased \(newItem.name) for \(item.value) gold.", color: .brightGreen)
            game.print("  Gold remaining: \(character.gold)", color: .yellow)

            game.waitForContinue()
            game.inputHandler = { [weak self] _ in
                self?.showBuyMenu(completion: completion)
            }
        }
    }

    // MARK: - Sell

    private func showSellMenu(completion: @escaping () -> Void) {
        guard let game = game, let character = character else { return }

        game.clearTerminal()
        game.printTitle("Sell Items")
        game.print("  Gold: \(character.gold)", color: .yellow)
        game.print("  (Items sell for half their value)", color: .dimGreen)
        game.print("")

        let sellableItems = character.inventory.filter { $0.value > 0 }

        if sellableItems.isEmpty {
            game.print("  \"You have nothing I want, adventurer.\"", color: .dimGreen)
            game.print("")
            game.showMenu(["< Back"])
            game.menuHandler = { [weak self] _ in
                self?.showShopMain(completion: completion)
            }
            return
        }

        var options: [String] = []
        for item in sellableItems {
            let sellValue = max(1, item.value / 2)
            options.append("\(item.name) — sells for \(sellValue)gp")
        }
        options.append("< Back")

        game.showMenu(options)

        game.menuHandler = { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            if choice == options.count {
                self.showShopMain(completion: completion)
                return
            }

            guard choice > 0 && choice <= sellableItems.count else { return }
            let item = sellableItems[choice - 1]
            let sellValue = max(1, item.value / 2)

            character.removeItem(item)
            character.gold += sellValue

            game.print("")
            game.print("  Sold \(item.name) for \(sellValue) gold.", color: .brightGreen)
            game.print("  Gold: \(character.gold)", color: .yellow)

            game.waitForContinue()
            game.inputHandler = { [weak self] _ in
                self?.showSellMenu(completion: completion)
            }
        }
    }
}
