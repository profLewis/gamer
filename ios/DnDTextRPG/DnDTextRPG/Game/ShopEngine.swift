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
    /// Shown at most once per shop visit (not on every trip back to the
    /// main menu after buying/selling) — reset in openShop().
    private var hasShownOneAtATimeQuip = false

    /// Only one party member ever visits a merchant at once (see
    /// GameEngine.visitShop's pickCharacter picker) — this occasionally
    /// has the merchant say so, to make the rule feel like an in-world
    /// choice by the merchant rather than an unexplained limitation.
    private static let oneAtATimeQuips: [String] = [
        "\"One at a time, if you please — no crowding my stall.\"",
        "\"Tell the rest of your party to wait outside. This aisle's not built for a crowd.\"",
        "\"I deal with one customer at a time, thank you. Bad for the till otherwise.\"",
        "\"Your friends can browse when you're done. One in the shop's plenty.\"",
    ]

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

    /// Gold + carry weight — shown on every sub-screen (buy/sell/haggle), not
    /// just the shop's main landing screen, since it's exactly what you need
    /// to know while deciding whether you can afford or carry something.
    private func printPurseAndCarryLine(_ character: Character) {
        guard let game = game else { return }
        game.print("  Gold: \(character.gold)  |  Carrying: \(String(format: "%.0f", character.currentWeight))/\(String(format: "%.0f", character.carryCapacity))lb (\(character.inventory.count) items)", color: .yellow)
    }

    func openShop(character: Character, dungeonLevel: Int, merchant: Merchant, completion: @escaping () -> Void) {
        self.character = character
        self.merchant = merchant
        self.stock = ItemCatalog.shopStock(forLevel: dungeonLevel)
        self.hasShownOneAtATimeQuip = false
        game?.setBreadcrumb("ShopEngine.openShop(\(merchant.name),lvl:\(dungeonLevel),stock:\(stock.count))")
        game?.logEvent("Visited \(merchant.name) at \(merchant.shopName)", category: "SHOP")
        showShopMain(completion: completion)
    }

    // MARK: - Main Menu

    private func showShopMain(completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        game.clearTerminal()
        game.printTitle(merchant.shopName)
        game.print("")
        game.print("  \(merchant.name) — \(merchant.tier.rawValue)", color: .green)
        game.print("  \(merchant.greeting)", color: .cyan)
        if !hasShownOneAtATimeQuip {
            hasShownOneAtATimeQuip = true
            if Int.random(in: 1...100) <= 35, let quip = Self.oneAtATimeQuips.randomElement() {
                game.print("  \(quip)", color: .cyan)
            }
        }
        game.print("")
        game.print("  Your gold: \(character.gold)", color: .yellow)
        game.print("  Carry weight: \(String(format: "%.0f", character.currentWeight))/\(String(format: "%.0f", character.carryCapacity)) lb", color: .green)
        game.print("  Stock: \(stock.count) items on the shelves", color: .green)
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
        game.setBreadcrumb("ShopEngine.showBuyMenu(stock:\(stock.count))")

        game.clearTerminal()
        game.setBreadcrumb("ShopEngine.showBuyMenu.afterClear")
        game.printTitle("Buy Items")
        printPurseAndCarryLine(character)
        game.print("")

        var options: [String] = []
        for item in stock {
            options.append("\(item.name)  \(item.value)gp  \(String(format: "%.1f", item.weight))lb")
            // Price/weight only ever appeared on the button label above, and
            // the description used dimGreen — a colour speaker mode treats
            // as a decorative nav hint and skips. Between the two, nothing
            // about an item was ever actually read aloud. Folding price and
            // weight into this line and switching to a readable colour
            // fixes both at once.
            game.print("  \(item.name) — \(item.value)gp, \(String(format: "%.1f", item.weight))lb: \(item.description)", color: .green)
            game.print("    \(game.itemUsageHint(item))", color: .yellow)
        }
        game.print("")

        let stockItems = self.stock
        game.setBreadcrumb("ShopEngine.showBuyMenu.beforeShowPaginated(opts:\(options.count))")
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
            game.logEvent("Bought \(newItem.name) for \(item.value) gold from \(self.merchant?.name ?? "a merchant")", category: "SHOP")

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
        printPurseAndCarryLine(character)
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
            game.logEvent("Sold \(item.name) for \(sellValue) gold to \(self.merchant?.name ?? "a merchant")", category: "SHOP")

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

    /// Attempts allowed per item per shop visit before the merchant ends
    /// negotiation on it — without a cap, a losing player could just keep
    /// re-rolling the same lowball offer forever.
    private static let maxHaggleAttempts = 3

    private func showHaggleMenu(completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        game.clearTerminal()
        game.printTitle("Haggle")
        printPurseAndCarryLine(character)
        game.print("  \(merchant.greeting)", color: .cyan)
        game.print("  Tap an item below, then name your price — the merchant accepts or refuses. Refused once, you can try again with a better offer.", color: .green)
        game.print("")

        var options: [String] = []
        for item in stock {
            options.append("Try: \(item.name) (\(item.value)gp)")
        }
        let stockItems = self.stock

        game.showPaginatedMenuOptions(options, pinned: ["< Back"], handler: { [weak self] idx in
            guard let self = self else { return }
            guard idx >= 0 && idx < stockItems.count else { return }
            self.showHaggleOfferPrompt(item: stockItems[idx], attempt: 1, completion: completion)
        }, pinnedHandler: { [weak self] _ in
            self?.showShopMain(completion: completion)
        })
    }

    /// A handful of suggested offers spread across [floor, ceiling], sorted
    /// ascending for display as buttons — varies each time this prompt is
    /// shown rather than being the same fixed spread every visit.
    private func suggestedOffers(floor: Int, ceiling: Int, count: Int = 3) -> [Int] {
        guard ceiling >= floor else { return [] }
        let span = ceiling - floor + 1
        if span <= count { return Array(floor...ceiling) }
        var values = Set<Int>()
        let bucketSize = span / count
        for i in 0..<count {
            let bucketStart = floor + i * bucketSize
            let bucketEnd = (i == count - 1) ? ceiling : min(ceiling, bucketStart + bucketSize - 1)
            if bucketStart <= bucketEnd {
                values.insert(Int.random(in: bucketStart...bucketEnd))
            }
        }
        while values.count < min(count, span) {
            values.insert(Int.random(in: floor...ceiling))
        }
        return values.sorted()
    }

    /// Prompts for a gold offer on `item`, then resolves it against a
    /// Persuasion check whose difficulty scales with how steep a discount
    /// was asked for (and stiffens slightly on each repeat attempt for the
    /// same item, capped at maxHaggleAttempts).
    private func showHaggleOfferPrompt(item: Item, attempt: Int, completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        game.clearTerminal()
        printPurseAndCarryLine(character)
        game.print("")
        game.print("  \(item.name) — asking price \(item.value)gp", color: .brightGreen, bold: true)
        if attempt > 1 {
            game.print("  Attempt \(attempt) of \(Self.maxHaggleAttempts) — \(merchant.name)'s patience is wearing thin.", color: .yellow)
        }
        game.print("")

        // A floor keeps offers sane — the merchant won't entertain an
        // insultingly low bid no matter the roll — and offering the full
        // asking price isn't haggling at all, so that's rejected too.
        let floor = max(1, item.value / 4)
        let ceiling = item.value - 1

        func resolveOffer(_ offer: Int) {
            guard let game = self.game, let character = self.character, let merchant = self.merchant else { return }
            if offer == 0 {
                game.print("  You step back from the table.", color: .dimGreen)
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in self?.showHaggleMenu(completion: completion) }
                return
            }
            // Asking price or more — no haggling needed, just sell it. No
            // Persuasion check: there's nothing to persuade the merchant of.
            guard offer < item.value else {
                if character.gold >= offer, character.canCarry(item) {
                    character.gold -= offer
                    let newItem = item.newInstance()
                    _ = character.addItem(newItem)
                    let overpaidBy = offer - item.value
                    if overpaidBy > 0 {
                        game.print("  \"Well, aren't you generous.\" \(merchant.name) pockets the extra \(overpaidBy) gold without complaint.", color: .brightGreen)
                    } else {
                        game.print("  \"A fair price, no haggling needed.\" \(merchant.name) hands over the \(newItem.name).", color: .brightGreen)
                    }
                    game.print("  Purchased \(newItem.name) for \(offer) gold.", color: .yellow)
                    game.logEvent("Bought \(item.name) for \(offer) gold with \(merchant.name)", category: "SHOP")
                } else {
                    game.print("  (You agreed a price of \(offer)gp but couldn't complete the purchase.)", color: .yellow)
                }
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                return
            }
            guard offer >= floor else {
                game.print("  \"\(offer) gold? You insult me.\" \(merchant.name) won't even consider it.", color: .red)
                let canRetry = attempt < Self.maxHaggleAttempts
                game.waitForContinue()
                if canRetry {
                    game.inputHandler = { [weak self] _ in self?.showHaggleOfferPrompt(item: item, attempt: attempt + 1, completion: completion) }
                } else {
                    game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                }
                return
            }

            let discountPct = Double(item.value - offer) / Double(item.value)
            let persuasionMod = character.skillModifier(for: .persuasion)
            let roll = Dice.roll(20)
            let total = roll + persuasionMod
            // Steeper asks need a better roll; each repeat attempt on this
            // same item also stiffens the merchant's resolve a little.
            let effectiveDC = merchant.tier.haggleDC + Int((discountPct * 40).rounded()) + (attempt - 1) * 2

            game.print("")
            game.print("  \(character.name) offers \(offer)gp and rolls Persuasion: d20[\(roll)] + \(persuasionMod) = \(total) vs DC \(effectiveDC)", color: .cyan)

            if total >= effectiveDC {
                self.narrate(situation: "The player offers \(offer) gold for a \(item.name) (asking price \(item.value)) and makes a successful Persuasion check. React in character, agreeing to the price.",
                             offline: merchant.offlineHaggleSuccessLine(), color: .brightGreen) {
                    if character.gold >= offer, character.canCarry(item) {
                        character.gold -= offer
                        let newItem = item.newInstance()
                        _ = character.addItem(newItem)
                        game.print("  Purchased \(newItem.name) for \(offer) gold (haggled down from \(item.value)).", color: .yellow)
                        game.logEvent("Haggled \(item.name) down to \(offer) gold (from \(item.value)) with \(merchant.name)", category: "SHOP")
                    } else {
                        game.print("  (You agreed a price of \(offer)gp but couldn't complete the purchase.)", color: .yellow)
                    }
                    game.waitForContinue()
                    game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                }
            } else {
                let canRetry = attempt < Self.maxHaggleAttempts
                self.narrate(situation: "The player offers \(offer) gold for a \(item.name) (asking price \(item.value)) but fails the Persuasion check. React in character, refusing that price\(canRetry ? ", but leave room for a better offer" : " and firmly end the negotiation").",
                             offline: merchant.offlineHaggleFailLine(), color: .red) {
                    game.logEvent("Offered \(offer) gold for \(item.name) with \(merchant.name) — refused", category: "SHOP")
                    game.waitForContinue()
                    if canRetry {
                        game.inputHandler = { [weak self] _ in self?.showHaggleOfferPrompt(item: item, attempt: attempt + 1, completion: completion) }
                    } else {
                        game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
                    }
                }
            }
        }

        // Offer a few suggested prices as buttons — in ascending order —
        // so haggling doesn't require typing a number, while still
        // accepting a typed (or spoken) custom offer too. Varies each
        // time this prompt is shown.
        let offers = suggestedOffers(floor: floor, ceiling: ceiling)
        let options = offers.map { "\($0)gp" }
        game.promptTextWithMenu("Name your price (\(floor)gp or more — \(item.value)gp or above buys it outright), or 0 to walk away:", options: options)
        game.closeHandler = { [weak self] in self?.showHaggleMenu(completion: completion) }
        game.menuHandler = { choice in
            guard choice >= 1, choice <= offers.count else { return }
            resolveOffer(offers[choice - 1])
        }
        game.inputHandler = { text in
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard let offer = Int(trimmed), offer >= 0 else {
                game.print("  \"Speak plainly — a number, adventurer.\"", color: .yellow)
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in self?.showHaggleOfferPrompt(item: item, attempt: attempt, completion: completion) }
                return
            }
            resolveOffer(offer)
        }
    }

    // MARK: - Rare Goods

    private func showRareGoods(completion: @escaping () -> Void) {
        guard let game = game, let merchant = merchant else { return }

        game.clearTerminal()
        game.printTitle("Under the Counter")
        if let character = character { printPurseAndCarryLine(character) }

        let roll = Int.random(in: 1...100)
        if roll <= merchant.tier.rareGoodsChance, let rareItem = Self.rareGoodsPool.randomElement() {
            let price = max(1, Int((Double(rareItem.value) * merchant.tier.rareGoodsMarkup).rounded()))
            self.narrate(situation: "The player asks if you have anything special or rare hidden away. You do — reveal a \(rareItem.name) from under the counter, offered at a premium price. React in character, making it feel like a small secret.",
                         offline: merchant.offlineRareGoodsFoundLine(), color: .cyan) {
                game.print("")
                game.print("  \(rareItem.name) — \(price)gp (normally \(rareItem.value)gp)", color: .yellow)
                game.showMenu(["Buy it", "Haggle", "< No thanks"])
                game.menuHandler = { [weak self] choice in
                    guard let self = self else { return }
                    switch choice {
                    case 1:
                        self.buyRareGood(rareItem, price: price, completion: completion)
                    case 2:
                        self.haggleRareGood(rareItem, price: price, completion: completion)
                    default:
                        // A plain decline with no new reaction to read —
                        // return straight to the shop instead of making the
                        // player tap through an extra "continue" first.
                        self.showShopMain(completion: completion)
                    }
                }
            }
        } else {
            self.narrate(situation: "The player asks if you have anything special or rare hidden away, but you don't have anything unusual today. React in character.",
                         offline: merchant.offlineRareGoodsNoneLine(), color: .dimGreen) {
                game.logEvent("Asked \(merchant.name) about rare goods — nothing on offer", category: "SHOP")
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
            }
        }
    }

    private func buyRareGood(_ item: Item, price: Int, completion: @escaping () -> Void) {
        guard let game = game, let character = character else { return }
        guard character.gold >= price else {
            game.print("  \"Not enough coin for that, friend.\"", color: .red)
            game.waitForContinue()
            game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
            return
        }
        guard character.canCarry(item) else {
            game.print("  \"You can barely stand as it is! Lighten your load first.\"", color: .red)
            game.waitForContinue()
            game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
            return
        }
        character.gold -= price
        let newItem = item.newInstance()
        _ = character.addItem(newItem)
        game.logEvent("Bought under-the-counter \(newItem.name) for \(price) gold from \(merchant?.name ?? "a merchant")", category: "SHOP")
        game.print("  You purchase the \(newItem.name) for \(price) gold.", color: .brightGreen)
        game.waitForContinue()
        game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
    }

    private func haggleRareGood(_ item: Item, price: Int, completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }
        let persuasionMod = character.skillModifier(for: .persuasion)
        let roll = Dice.roll(20)
        let total = roll + persuasionMod
        // Under-the-counter goods are already a favour — harder to talk down further.
        let dc = merchant.tier.haggleDC + 3

        game.print("")
        game.print("  \(character.name) rolls Persuasion: d20[\(roll)] + \(persuasionMod) = \(total) vs DC \(dc)", color: .dimGreen)

        if total >= dc {
            let discount = Double.random(in: 0.10...0.20)
            // Guarantee a real discount even after rounding — see showHaggleMenu.
            let newPrice = min(price - 1, max(1, Int((Double(price) * (1 - discount)).rounded())))
            self.narrate(situation: "The player haggles over the price of the \(item.name) you just showed them under the counter. React in character, agreeing to a lower price of \(newPrice) gold instead of \(price).",
                         offline: merchant.offlineHaggleSuccessLine(), color: .brightGreen) { [weak self] in
                self?.buyRareGood(item, price: newPrice, completion: completion)
            }
        } else {
            self.narrate(situation: "The player tries to haggle over the price of the \(item.name) but fails to persuade you. React in character, refusing to lower the price on a rare item.",
                         offline: merchant.offlineHaggleFailLine(), color: .red) { [weak self] in
                self?.buyRareGoodsRetry(item, price: price, completion: completion)
            }
        }
    }

    private func buyRareGoodsRetry(_ item: Item, price: Int, completion: @escaping () -> Void) {
        guard let game = game else { return }
        game.showMenu(["Buy it at \(price)gp", "< No thanks"])
        game.menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 {
                self.buyRareGood(item, price: price, completion: completion)
            } else {
                // A plain decline with no new reaction to read — return
                // straight to the shop instead of an extra "continue" tap.
                self.showShopMain(completion: completion)
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

    /// Always resolves immediately with the offline-safe line (which is itself
    /// randomly picked from a small pool per call, so it isn't repetitive) —
    /// `then` never waits on the DM. If any AI is available, a request for
    /// richer flavour fires in the background and, if it comes back within a
    /// few seconds, is appended as a bonus extra line; if it's slow, times
    /// out, or never resolves, it's silently dropped. This is deliberate:
    /// merchant AI narration used to gate the whole interaction, so a slow or
    /// hung DM call meant the player never even saw what was for sale.
    private func narrate(situation: String, offline: String, color: TerminalColor, then: @escaping () -> Void) {
        guard let game = game, let merchant = merchant else { then(); return }

        game.print("  \(offline)", color: color)
        then()

        guard DMEngine.shared.hasAnyAI else { return }

        final class ResolutionFlag { var done = false }
        let flag = ResolutionFlag()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { flag.done = true }

        game.merchantNarration(situation, merchant: merchant) { line in
            DispatchQueue.main.async {
                guard !flag.done else { return }
                flag.done = true
                game.print("  \(line)", color: color)
            }
        }
    }
}
