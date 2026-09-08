//
//  ShopEngine.swift
//  DnDTextRPG
//
//  Marketplace / shop system — tiered, named merchants with bargaining,
//  under-the-counter rare goods, and occasional advice. Bargaining/rare-goods
//  outcomes are always resolved as real game mechanics (dice checks, item
//  tables); the DM only ever supplies narration on top, so everything works
//  identically with cloud AI, Apple on-device AI, or no AI at all.
//

import Foundation

class ShopEngine {

    private weak var game: GameEngine?
    private var stock: [Item] = []
    private var character: Character?
    private var merchant: Merchant?

    /// Mundane-but-uncommon items offered as "rare goods" — deliberately not
    /// part of the regular tiered stock rotation.
    private static let rareGoodsPool: [Item] = [
        ItemCatalog.chainMail(),
        ItemCatalog.greaterHealingPotion(),
        ItemCatalog.greataxe(),
        ItemCatalog.thievesTools(),
        ItemCatalog.holySymbol(),
        ItemCatalog.spellComponentPouch(),
    ]

    init(game: GameEngine) {
        self.game = game
    }

    func openShop(character: Character, dungeonLevel: Int, merchant: Merchant, completion: @escaping () -> Void) {
        self.character = character
        self.merchant = merchant
        self.stock = ItemCatalog.shopStock(forLevel: dungeonLevel)
        showShopMain(completion: completion)
    }

    // MARK: - Main Menu

    private func showShopMain(completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        game.clearTerminal()
        game.printTitle(merchant.shopName)
        game.print("")
        game.print("  \(merchant.name) — \(merchant.tier.rawValue)", color: .dimGreen)
        game.print("  \(merchant.greeting)", color: .cyan)
        game.print("")
        game.print("  Your gold: \(character.gold)", color: .yellow)
        game.print("  Carry weight: \(String(format: "%.0f", character.currentWeight))/\(String(format: "%.0f", character.carryCapacity)) lb", color: .dimGreen)
        game.print("  Stock: \(stock.count) items on the shelves", color: .dimGreen)
        game.print("")

        game.showMenu(["Buy", "Sell", "Haggle", "Ask About Rare Goods", "< Leave Shop"])

        game.menuHandler = { [weak self] choice in
            switch choice {
            case 1: self?.showBuyMenu(completion: completion)
            case 2: self?.showSellMenu(completion: completion)
            case 3: self?.showHaggleMenu(completion: completion)
            case 4: self?.showRareGoods(completion: completion)
            default: self?.maybeOfferAdvice(completion: completion)
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
            options.append("\(item.name)  \(item.value)gp  \(String(format: "%.1f", item.weight))lb")
        }

        let stockItems = self.stock
        game.showPaginatedMenuOptions(options, pinned: ["< Back"], handler: { [weak self] idx in
            guard let self = self, let game = self.game else { return }

            guard idx >= 0 && idx < stockItems.count else { return }
            let item = stockItems[idx]

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
        }, pinnedHandler: { [weak self] _ in
            self?.showShopMain(completion: completion)
        })
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
            options.append("\(item.name)  +\(sellValue)gp")
        }

        game.showPaginatedMenuOptions(options, pinned: ["< Back"], handler: { [weak self] idx in
            guard let self = self, let game = self.game else { return }

            guard idx >= 0 && idx < sellableItems.count else { return }
            let item = sellableItems[idx]
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
        }, pinnedHandler: { [weak self] _ in
            self?.showShopMain(completion: completion)
        })
    }

    // MARK: - Haggle

    private func showHaggleMenu(completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        game.clearTerminal()
        game.printTitle("Haggle")
        game.print("  \(merchant.greeting)", color: .cyan)
        game.print("  Pick an item to try talking down the price on.", color: .dimGreen)
        game.print("")

        var options: [String] = []
        for item in stock {
            options.append("\(item.name)  \(item.value)gp")
        }
        let stockItems = self.stock

        game.showPaginatedMenuOptions(options, pinned: ["< Back"], handler: { [weak self] idx in
            guard let self = self, let game = self.game, let character = self.character, let merchant = self.merchant else { return }
            guard idx >= 0 && idx < stockItems.count else { return }
            let item = stockItems[idx]

            let persuasionMod = character.skillModifier(for: .persuasion)
            let roll = Dice.roll(20)
            let total = roll + persuasionMod
            let dc = merchant.tier.haggleDC

            game.print("")
            game.print("  \(character.name) rolls Persuasion: d20[\(roll)] + \(persuasionMod) = \(total) vs DC \(dc)", color: .dimGreen)

            if total >= dc {
                let discount = Double.random(in: 0.15...0.30)
                let newPrice = max(1, Int((Double(item.value) * (1 - discount)).rounded()))
                self.narrate(situation: "The player successfully haggles over the price of a \(item.name) with a Persuasion check. React in character, agreeing (grudgingly or graciously) to a lower price of \(newPrice) gold instead of \(item.value).",
                             offline: merchant.offlineHaggleSuccessLine(), color: .brightGreen) {
                    if character.gold >= newPrice, character.canCarry(item) {
                        character.gold -= newPrice
                        let newItem = item.newInstance()
                        _ = character.addItem(newItem)
                        game.print("  Purchased \(newItem.name) for \(newPrice) gold (haggled down from \(item.value)).", color: .yellow)
                    } else {
                        game.print("  (You agreed a price of \(newPrice)gp but couldn't complete the purchase.)", color: .dimGreen)
                    }
                    game.waitForContinue()
                    game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                }
            } else {
                self.narrate(situation: "The player tries to haggle over the price of a \(item.name) but fails to persuade you. React in character, firmly refusing to lower the price.",
                             offline: merchant.offlineHaggleFailLine(), color: .red) {
                    game.waitForContinue()
                    game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                }
            }
        }, pinnedHandler: { [weak self] _ in
            self?.showShopMain(completion: completion)
        })
    }

    // MARK: - Rare Goods

    private func showRareGoods(completion: @escaping () -> Void) {
        guard let game = game, let merchant = merchant else { return }

        game.clearTerminal()
        game.printTitle("Under the Counter")

        let roll = Int.random(in: 1...100)
        if roll <= merchant.tier.rareGoodsChance, let rareItem = Self.rareGoodsPool.randomElement() {
            let price = max(1, Int((Double(rareItem.value) * merchant.tier.rareGoodsMarkup).rounded()))
            self.narrate(situation: "The player asks if you have anything special or rare hidden away. You do — reveal a \(rareItem.name) from under the counter, offered at a premium price. React in character, making it feel like a small secret.",
                         offline: merchant.offlineRareGoodsFoundLine(), color: .cyan) {
                game.print("")
                game.print("  \(rareItem.name) — \(price)gp (normally \(rareItem.value)gp)", color: .yellow)
                game.showMenu(["Buy it", "< No thanks"])
                game.menuHandler = { [weak self] choice in
                    guard let self = self, let game = self.game, let character = self.character else { return }
                    if choice == 1 {
                        guard character.gold >= price else {
                            game.print("  \"Not enough coin for that, friend.\"", color: .red)
                            game.waitForContinue()
                            game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                            return
                        }
                        guard character.canCarry(rareItem) else {
                            game.print("  \"You can barely stand as it is! Lighten your load first.\"", color: .red)
                            game.waitForContinue()
                            game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                            return
                        }
                        character.gold -= price
                        let newItem = rareItem.newInstance()
                        _ = character.addItem(newItem)
                        game.print("  You purchase the \(newItem.name) for \(price) gold.", color: .brightGreen)
                    }
                    game.waitForContinue()
                    game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                }
            }
        } else {
            self.narrate(situation: "The player asks if you have anything special or rare hidden away, but you don't have anything unusual today. React in character.",
                         offline: merchant.offlineRareGoodsNoneLine(), color: .dimGreen) {
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
            }
        }
    }

    // MARK: - Advice

    private func maybeOfferAdvice(completion: @escaping () -> Void) {
        guard let game = game, var merchant = merchant else { completion(); return }
        guard !merchant.hasOfferedAdviceThisVisit, Int.random(in: 1...100) <= 25 else {
            completion()
            return
        }
        merchant.hasOfferedAdviceThisVisit = true
        self.merchant = merchant

        game.print("")
        self.narrate(situation: "Before the player leaves your shop, offer one short piece of unsolicited practical advice about surviving or profiting in the dungeon, in character.",
                     offline: Merchant.adviceLines.randomElement()!, color: .cyan) {
            completion()
        }
    }

    // MARK: - Narration helper

    /// Narrates via the active DM tier when any AI is available; otherwise uses
    /// the guaranteed offline-safe line. Either way `then` runs once the line
    /// has been printed.
    private func narrate(situation: String, offline: String, color: TerminalColor, then: @escaping () -> Void) {
        guard let game = game, let merchant = merchant else { then(); return }
        if DMEngine.shared.hasAnyAI {
            game.merchantNarration(situation, merchant: merchant) { line in
                game.print("  \(line)", color: color)
                then()
            }
        } else {
            game.print("  \(offline)", color: color)
            then()
        }
    }
}
