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

    /// What happened this visit — feeds the farewell line when leaving
    /// (see showFarewell). Reset in openShop().
    private var itemsBoughtThisVisit: [String] = []
    private var itemsSoldThisVisit: [String] = []

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
        // Item count needs its own visible cap (Character.maxInventorySlots)
        // — without it, a refusal to carry something well within the
        // weight limit reads as a bug, since nothing on screen hints that
        // item SLOTS are a separate, independent cap from weight.
        game.print("  Gold: \(character.gold)  |  Carrying: \(game.formatWeightPair(character.currentWeight, character.carryCapacity)) (\(character.inventory.count)/\(Character.maxInventorySlots) items)", color: .yellow)
    }

    /// Builds a buy/sell list button label as "Name  <price>  <weight>" —
    /// MenuOption's own trimToFit hard-cuts from the END once a button's
    /// text passes its length cap, which silently chopped the price/weight
    /// off a long item name instead of the name itself. Reserves room for
    /// the price/weight suffix first and shortens just the name to fit
    /// what's left, so both are always visible.
    private func shopButtonLabel(name: String, priceLabel: String, weight: String) -> String {
        let suffix = "  \(priceLabel)  \(weight)"
        let maxLength = MenuOption.maxButtonLength
        guard name.count + suffix.count > maxLength else { return name + suffix }
        let available = maxLength - suffix.count
        guard available > 3 else { return String(name.prefix(max(1, maxLength - 1))) + "…" + suffix }
        let trimmedName = String(name.prefix(available - 1)) + "…"
        return trimmedName + suffix
    }

    func openShop(character: Character, dungeonLevel: Int, merchant: Merchant, completion: @escaping () -> Void) {
        self.character = character
        self.merchant = merchant
        // Roll stock once per merchant and remember it from then on — a
        // merchant who's shown you an item shouldn't have a different (or
        // no) selection if you leave and come back later.
        if merchant.stock.isEmpty {
            self.stock = ItemCatalog.shopStock(forLevel: dungeonLevel)
            self.merchant?.stock = self.stock
            syncMerchantToRoom()
        } else {
            self.stock = merchant.stock
        }
        self.hasShownOneAtATimeQuip = false
        self.itemsBoughtThisVisit = []
        self.itemsSoldThisVisit = []
        game?.setBreadcrumb("ShopEngine.openShop(\(merchant.name),lvl:\(dungeonLevel),stock:\(stock.count))")
        game?.logEvent("Visited \(merchant.name) at \(merchant.shopName)", category: "SHOP")
        if let game = game, game.musicEnabled { SoundManager.shared.startMusic(.shop, preference: game.shopMelodyChoice) }
        showShopMain(completion: completion)
    }

    /// ShopEngine holds its own copy of the merchant struct while the visit
    /// is open — write any changes (stock, rare goods revealed) back to the
    /// room so they're remembered on the next visit, and actually saved.
    /// Covers both a room's own shop/armoury merchant AND a Wandering
    /// Trader NPC's merchant (a Merchant nested inside room.npc rather than
    /// on the room directly).
    private func syncMerchantToRoom() {
        guard let merchant = self.merchant, let room = game?.dungeon?.currentRoom else { return }
        if room.merchant != nil {
            room.merchant = merchant
        } else if var npc = room.npc, npc.merchant != nil {
            npc.merchant = merchant
            room.npc = npc
        }
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
        game.print("  Carry weight: \(game.formatWeightPair(character.currentWeight, character.carryCapacity))  (\(character.inventory.count)/\(Character.maxInventorySlots) items)", color: .green)
        game.print("  Stock: \(stock.count) items on the shelves", color: .green)
        game.print("")

        game.showMenu(["Buy", "Sell", "Haggle", "Ask About Rare Goods", "?", "< Leave Shop"])

        game.menuHandler = { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            switch choice {
            case 1: self.showBuyMenu(completion: completion)
            case 2: self.showSellMenu(completion: completion)
            case 3: self.showHaggleMenu(completion: completion)
            case 4: self.showRareGoods(completion: completion)
            case 5:
                game.showInlineHelp {
                    game.printTitle("\(merchant.shopName) — Help")
                    game.print("")
                    game.print("  BUY", color: .cyan, bold: true)
                    game.printWrapped("Purchase items from the merchant's stock at the listed price.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.print("  SELL", color: .cyan, bold: true)
                    game.printWrapped("Sell items from your inventory for half their value.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.print("  HAGGLE", color: .cyan, bold: true)
                    game.printWrapped("Name your own price on an item in stock — a Persuasion check decides whether the merchant accepts.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.print("  ASK ABOUT RARE GOODS", color: .cyan, bold: true)
                    game.printWrapped("A chance the merchant has something special under the counter, at a premium — also haggleable.", indent: 2, color: .dimGreen)
                    game.print("")
                }
            default:
                self.showFarewell(completion: completion)
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
        // Exact printed-line range per item (printWrapped-free here, but
        // itemUsageHint's line can still wrap) so tapping the green
        // description text, not just the numbered button, buys the item.
        var itemLineRanges: [Range<Int>] = []
        for item in stock {
            let lineStart = game.terminalLines.count
            options.append(shopButtonLabel(name: item.name, priceLabel: "\(item.value)gp", weight: game.formatWeight(item.weight)))
            // Price/weight only ever appeared on the button label above, and
            // the description used dimGreen — a colour speaker mode treats
            // as a decorative nav hint and skips. Between the two, nothing
            // about an item was ever actually read aloud. Folding price and
            // weight into this line and switching to a readable colour
            // fixes both at once.
            game.print("  \(item.name) — \(item.value)gp, \(game.formatWeight(item.weight)): \(item.description)", color: .green)
            game.print("    \(game.itemUsageHint(item))", color: .yellow)
            itemLineRanges.append(lineStart..<game.terminalLines.count)
        }
        game.print("")

        let stockItems = self.stock

        let selectItem: (Int) -> Void = { [weak self] idx in
            guard let self = self, idx >= 0 && idx < stockItems.count else { return }
            self.showBuyConfirm(item: stockItems[idx], completion: completion)
        }

        game.setBreadcrumb("ShopEngine.showBuyMenu.beforeShowPaginated(opts:\(options.count))")
        game.showPaginatedMenuOptions(options, pinned: ["?", "< Back"], handler: { idx in
            selectItem(idx)
        }, pinnedHandler: { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            if choice == 0 {
                game.showInlineHelp {
                    game.printTitle("Buy Items — Help")
                    game.print("")
                    game.printWrapped("Tap an item's button, or its green description text, to buy it — you'll be shown the price and asked to confirm.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.printWrapped("Gold and carry weight are shown at the top; an item you can't afford or can't carry is refused with a reason.", indent: 2, color: .dimGreen)
                    game.print("")
                }
            } else {
                self.showShopMain(completion: completion)
            }
        })
        game.textLongPressHandler = { lineIndex in
            guard let idx = itemLineRanges.firstIndex(where: { $0.contains(lineIndex) }) else { return }
            selectItem(idx)
        }
    }

    /// Confirmation step before actually buying `item` — shows what it
    /// costs and weighs, and your gold/carry weight/item count now versus
    /// after the purchase, so nothing about the transaction is a surprise.
    /// An item you can't afford or can't carry is refused here with the
    /// specific reason instead of a confirm prompt for an impossible buy.
    private func showBuyConfirm(item: Item, completion: @escaping () -> Void) {
        guard let game = game, let character = character else { return }

        guard character.gold >= item.value else {
            game.clearTerminal()
            game.print("")
            game.print("  \"You haven't got enough gold for that, friend.\"", color: .red)
            game.print("  \(item.name) costs \(item.value)gp — you have \(character.gold)gp.", color: .dimGreen)
            game.print("")
            game.printWrapped("\"...unless you'd like to make an offer?\"", indent: 2, color: .yellow)
            game.print("")
            let backToList: () -> Void = { [weak self] in self?.showBuyMenu(completion: completion) }
            game.showMenu(["Haggle", "Barter", "< No Thanks"])
            game.closeHandler = backToList
            game.menuHandler = { [weak self] choice in
                guard let self = self else { return }
                switch choice {
                case 1:
                    self.showNegotiation(item: item, askingPrice: item.value, attempt: 1, isRareGood: false,
                                          backAction: backToList, returnTo: backToList, completion: completion)
                case 2:
                    self.showBarterMenu(item: item, askingPrice: item.value, backAction: backToList, returnTo: backToList, completion: completion)
                default:
                    backToList()
                }
            }
            return
        }
        if let reason = character.carryBlockReason(for: item) {
            game.clearTerminal()
            game.print("")
            game.print("  \"\(reason)\"", color: .red)
            game.waitForContinue()
            game.inputHandler = { [weak self] _ in self?.showBuyMenu(completion: completion) }
            return
        }

        game.clearTerminal()
        game.printTitle("Buy \(item.name)?")
        game.print("")
        game.print("  Price: \(item.value)gp   Weight: \(game.formatWeight(item.weight))", color: .brightGreen, bold: true)
        game.printWrapped("  \(item.description)", indent: 2, color: .dimGreen)
        game.print("")
        game.print("  Gold: \(character.gold) → \(character.gold - item.value)", color: .yellow)
        let newWeight = character.currentWeight + item.weight
        game.print("  Carry: \(game.formatWeightPair(character.currentWeight, character.carryCapacity)) → \(game.formatWeightPair(newWeight, character.carryCapacity))", color: .yellow)
        game.print("  Items: \(character.inventory.count)/\(Character.maxInventorySlots) → \(character.inventory.count + 1)/\(Character.maxInventorySlots)", color: .yellow)
        game.print("")

        game.showMenu(["Buy", "< Cancel"])
        let backToList: () -> Void = { [weak self] in self?.showBuyMenu(completion: completion) }
        game.closeHandler = backToList
        game.menuHandler = { [weak self] choice in
            guard let self = self, let character = self.character else { return }
            guard choice == 1 else { backToList(); return }
            self.completePurchase(item: item, price: item.value, buyer: character,
                                   lines: [("  Purchased \(item.name) for \(item.value) gold.", .brightGreen),
                                           ("  Gold remaining: \(character.gold - item.value)", .yellow)],
                                   returnTo: backToList, completion: completion)
        }
    }

    /// Completes a purchase of `item` at `price` for `buyer` — deducts
    /// gold, adds the item to inventory, logs the sale, tracks it for the
    /// farewell summary, prints `lines`, then offers post-purchase options
    /// (equip/drink/gift). The single place every purchase path (Buy,
    /// Haggle, Rare Goods, Rare Goods Haggle) funnels through once its own
    /// gold/carry checks have passed — previously only a plain Buy offered
    /// equip/drink/gift afterward, and each path duplicated the
    /// deduct/add/log/track steps with slightly different wording, which
    /// is what made haggling feel like several different, inconsistent
    /// systems instead of one.
    private func completePurchase(item: Item, price: Int, buyer: Character, lines: [(String, TerminalColor)], returnTo: @escaping () -> Void, completion: @escaping () -> Void) {
        guard let game = game else { return }
        buyer.gold -= price
        let newItem = item.newInstance()
        _ = buyer.addItem(newItem)
        itemsBoughtThisVisit.append(newItem.name)
        game.logEvent("\(buyer.name) bought \(newItem.name) for \(price) gold from \(merchant?.name ?? "a merchant")", category: "SHOP")
        // If this was the remembered "under the counter" item (bought via
        // haggling/barter rather than the direct "Buy it" path — that one
        // clears it itself), it's no longer on offer.
        if merchant?.rareGoodsOffered.contains(where: { $0.name == item.name }) == true {
            merchant?.rareGoodsOffered = []
            syncMerchantToRoom()
        }
        game.print("")
        for (text, color) in lines { game.print(text, color: color) }
        showPostPurchaseOptions(item: newItem, buyer: buyer, returnTo: returnTo, completion: completion)
    }

    /// Right after a successful purchase — what to do with it. Equippable
    /// gear offers "Equip Now", potions offer "Drink Now", and (party size
    /// permitting) any item can be handed to a teammate as a present. Skips
    /// straight past to the plain "keep browsing" continue if none of that
    /// applies (a key, a gem, a scroll, solo party). `returnTo` is wherever
    /// the purchase happened (Buy list, Haggle list, or the shop's main
    /// menu for rare goods) — where "keep it for later" (or finishing
    /// equip/drink/gift) goes back to.
    private func showPostPurchaseOptions(item: Item, buyer: Character, returnTo: @escaping () -> Void, completion: @escaping () -> Void) {
        guard let game = game else { return }

        let canEquip: Bool = [.weapon, .armor, .shield].contains(item.type)
        let canDrink = item.type == .potion
        let canGift = party.count > 1

        var options: [String] = []
        if canEquip { options.append("Equip Now") }
        if canDrink { options.append("Drink Now") }
        if canGift { options.append("Give as a Present") }
        options.append(options.isEmpty ? "Continue" : "Keep It For Later")

        guard options.count > 1 else {
            // Nothing applicable — same as before, just wait and return.
            game.waitForContinueWithTimeout { returnTo() }
            return
        }

        game.print("")
        game.print("  What would you like to do with it?", color: .cyan)
        game.showMenu(options)
        game.closeHandler = returnTo
        game.menuHandler = { [weak self] choice in
            guard let self = self, choice >= 1, choice <= options.count else { return }
            switch options[choice - 1] {
            case "Equip Now":
                self.equipNow(item: item, buyer: buyer, returnTo: returnTo)
            case "Drink Now":
                self.drinkNow(item: item, buyer: buyer, returnTo: returnTo)
            case "Give as a Present":
                self.giveAsPresent(item: item, from: buyer, returnTo: returnTo)
            default:
                game.print("")
                game.print("  \(buyer.name) tucks the \(item.name) away for later.", color: .dimGreen)
                game.waitForContinueWithTimeout { returnTo() }
            }
        }
    }

    /// Access to the full party — ShopEngine only ever deals with the one
    /// visiting character otherwise, but gifting needs everyone else.
    private var party: [Character] { game?.party ?? [] }

    private func equipNow(item: Item, buyer: Character, returnTo: @escaping () -> Void) {
        guard let game = game else { return }
        switch item.type {
        case .weapon: buyer.equipWeapon(item)
        case .armor: buyer.equipArmor(item)
        case .shield: buyer.equipShield(item)
        default: break
        }
        game.print("")
        game.print("  \(buyer.name) equips the \(item.name).", color: .brightGreen)
        game.logMultiplayerAction("\(buyer.name) equips \(item.name)")
        game.waitForContinueWithTimeout { returnTo() }
    }

    private func drinkNow(item: Item, buyer: Character, returnTo: @escaping () -> Void) {
        guard let game = game else { return }
        buyer.removeItem(item)
        game.print("")
        let isAntidote = item.name.lowercased().contains("antidote")
        if isAntidote {
            if buyer.isPoisoned {
                buyer.curePoison()
                game.print("  \(buyer.name) drinks the antidote! Poison cured!", color: .brightGreen)
            } else {
                game.print("  \(buyer.name) drinks the antidote. (Not poisoned — no effect.)", color: .dimGreen)
            }
        } else if let healStr = item.potionStats?.healAmount, healStr != "0" {
            let roll = Dice.rollDamage(healStr)
            let amount = max(1, roll.total)
            buyer.heal(amount)
            game.print("  \(buyer.name) drinks \(item.name)! Restored \(amount) HP! (\(buyer.currentHP)/\(buyer.maxHP))", color: .brightGreen)
        } else {
            game.print("  \(buyer.name) drinks \(item.name).", color: .dimGreen)
        }
        game.logMultiplayerAction("\(buyer.name) drinks \(item.name)")
        game.waitForContinueWithTimeout { returnTo() }
    }

    /// Something clever, per request: the recipient's reaction is flavoured
    /// by their relationship to gifts in general — always warm, sometimes
    /// a little playful about it — rather than a flat "item transferred."
    private static let giftReactions: [String] = [
        "\"For me? You shouldn't have.\" %@ grins and stows it away.",
        "%@'s eyes light up. \"Now THIS is what I call a party.\"",
        "\"Aw, you remembered.\" %@ takes it with a genuine smile.",
        "%@ inspects it, nods approvingly. \"Good taste. I'll put it to use.\"",
        "\"I owe you one,\" says %@, pocketing the gift.",
    ]

    private func giveAsPresent(item: Item, from buyer: Character, returnTo: @escaping () -> Void) {
        guard let game = game else { return }
        let recipients = party.filter { $0.id != buyer.id }
        game.pickCharacter(title: "Give the \(item.name) to whom?", cancelLabel: "Never Mind", from: recipients, onBack: returnTo) { [weak self] recipient in
            guard let self = self, let game = self.game else { return }
            guard recipient.canCarry(item) else {
                game.print("")
                game.print("  \(recipient.name) can't carry anything more right now.", color: .red)
                game.waitForContinueWithTimeout { returnTo() }
                return
            }
            buyer.removeItem(item)
            _ = recipient.addItem(item)
            game.print("")
            game.print("  \(buyer.name) hands the \(item.name) to \(recipient.name).", color: .brightGreen)
            let reaction = String(format: Self.giftReactions.randomElement()!, recipient.name)
            game.print("  \(reaction)", color: .cyan)
            game.logMultiplayerAction("\(buyer.name) gives \(item.name) to \(recipient.name)")
            game.waitForContinueWithTimeout { returnTo() }
        }
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
            game.showMenu(["?", "< Back"])
            game.menuHandler = { [weak self] choice in
                guard let self = self, let game = self.game else { return }
                if choice == 1 {
                    game.showInlineHelp {
                        game.printTitle("Sell Items — Help")
                        game.print("")
                        game.printWrapped("Nothing in your inventory is worth anything to \(self.merchant?.name ?? "this merchant") right now.", indent: 2, color: .dimGreen)
                        game.print("")
                    }
                } else {
                    self.showShopMain(completion: completion)
                }
            }
            return
        }

        var options: [String] = []
        // Exact printed-line range per item so tapping the green
        // description text, not just the numbered button, sells it.
        var itemLineRanges: [Range<Int>] = []
        for item in sellableItems {
            let lineStart = game.terminalLines.count
            let sellValue = max(1, item.value / 2)
            options.append(shopButtonLabel(name: item.name, priceLabel: "+\(sellValue)gp", weight: game.formatWeight(item.weight)))
            game.print("  \(item.name) — sells for \(sellValue)gp, \(game.formatWeight(item.weight)): \(item.description)", color: .green)
            itemLineRanges.append(lineStart..<game.terminalLines.count)
        }

        let sellItem: (Int) -> Void = { [weak self] idx in
            guard let self = self, let game = self.game else { return }
            guard idx >= 0 && idx < sellableItems.count else { return }
            let item = sellableItems[idx]
            let sellValue = max(1, item.value / 2)

            character.removeItem(item)
            character.gold += sellValue
            game.logEvent("\(character.name) sold \(item.name) for \(sellValue) gold to \(self.merchant?.name ?? "a merchant")", category: "SHOP")

            game.print("")
            self.itemsSoldThisVisit.append(item.name)
            game.print("  Sold \(item.name) for \(sellValue) gold.", color: .brightGreen)
            game.print("  Gold: \(character.gold)", color: .yellow)

            game.waitForContinue()
            game.inputHandler = { [weak self] _ in
                self?.showSellMenu(completion: completion)
            }
        }

        game.showPaginatedMenuOptions(options, pinned: ["?", "< Back"], handler: { idx in
            sellItem(idx)
        }, pinnedHandler: { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            if choice == 0 {
                game.showInlineHelp {
                    game.printTitle("Sell Items — Help")
                    game.print("")
                    game.printWrapped("Tap an item's button, or its green description text, to sell it to \(self.merchant?.name ?? "the merchant") for half its value.", indent: 2, color: .dimGreen)
                    game.print("")
                }
            } else {
                self.showShopMain(completion: completion)
            }
        })
        game.textLongPressHandler = { lineIndex in
            guard let idx = itemLineRanges.firstIndex(where: { $0.contains(lineIndex) }) else { return }
            sellItem(idx)
        }
    }

    // MARK: - Barter

    /// Trade an inventory item (at half its value, same rate Sell uses)
    /// toward `askingPrice`, topping up with whatever gold is still needed.
    /// Reached only when gold alone falls short — see showBuyConfirm() and
    /// the "make an offer" prompt there.
    private func showBarterMenu(item: Item, askingPrice: Int, backAction: @escaping () -> Void,
                                 returnTo: @escaping () -> Void, completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        let sellables = character.inventory.filter { $0.value > 0 }
        guard !sellables.isEmpty else {
            game.clearTerminal()
            game.print("  \"You've nothing on you worth trading in.\"", color: .red)
            game.waitForContinue()
            game.inputHandler = { _ in backAction() }
            return
        }

        game.clearTerminal()
        game.printTitle("Barter for \(item.name)")
        printPurseAndCarryLine(character)
        game.print("  Asking price: \(askingPrice)gp", color: .brightGreen, bold: true)
        game.printWrapped("Offer something from your pack (traded in at half value, same as selling) to make up the gap.", indent: 2, color: .dimGreen)
        game.print("")

        var options: [String] = []
        var itemLineRanges: [Range<Int>] = []
        for offered in sellables {
            let credit = max(1, offered.value / 2)
            let lineStart = game.terminalLines.count
            options.append("\(offered.name) (worth \(credit)gp)")
            game.print("  \(offered.name) — trade-in value \(credit)gp: \(offered.description)", color: .green)
            itemLineRanges.append(lineStart..<game.terminalLines.count)
        }

        let tryBarter: (Int) -> Void = { [weak self] idx in
            guard let self = self, let game = self.game, let character = self.character, let merchant = self.merchant,
                  idx >= 0, idx < sellables.count else { return }
            let offeredItem = sellables[idx]
            let credit = max(1, offeredItem.value / 2)
            game.print("")

            // Some merchants just aren't in a bartering mood today — coin only.
            if Int.random(in: 1...100) <= 15 {
                game.print("  \"\(merchant.name) isn't interested in trade goods today — coin only, I'm afraid.\"", color: .red)
                game.waitForContinue()
                game.inputHandler = { _ in backAction() }
                return
            }

            let combinedValue = character.gold + credit
            guard combinedValue >= askingPrice else {
                game.print("  \"That, plus your coin, still isn't enough.\" (Combined \(combinedValue)gp, need \(askingPrice)gp.)", color: .red)
                game.waitForContinue()
                game.inputHandler = { _ in backAction() }
                return
            }

            let goldSpent = max(0, askingPrice - credit)
            character.removeItem(offeredItem)
            let flavor = goldSpent > 0
                ? "  \"Deal.\" \(merchant.name) takes your \(offeredItem.name) and \(goldSpent) gold in exchange for \(item.name)."
                : "  \"Deal.\" \(merchant.name) takes your \(offeredItem.name) in exchange for \(item.name)."
            self.completePurchase(item: item, price: goldSpent, buyer: character,
                                  lines: [(flavor, .brightGreen)], returnTo: returnTo, completion: completion)
        }

        game.showPaginatedMenuOptions(options, pinned: ["?", "< Back"], handler: { idx in
            tryBarter(idx)
        }, pinnedHandler: { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            if choice == 0 {
                game.showInlineHelp {
                    game.printTitle("Barter — Help")
                    game.print("")
                    game.printWrapped("Tap an item to offer it in trade — it's valued at half price, same as selling — plus whatever gold you have, toward the asking price. Some merchants occasionally aren't interested in trade goods at all.", indent: 2, color: .dimGreen)
                    game.print("")
                }
            } else {
                backAction()
            }
        })
        game.textLongPressHandler = { lineIndex in
            guard let idx = itemLineRanges.firstIndex(where: { $0.contains(lineIndex) }) else { return }
            tryBarter(idx)
        }
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
        // Exact printed-line range per item so tapping the green
        // description text, not just the numbered button, starts haggling.
        var itemLineRanges: [Range<Int>] = []
        for item in stock {
            let lineStart = game.terminalLines.count
            options.append("Try: \(item.name) (\(item.value)gp)")
            game.print("  \(item.name) — asking \(item.value)gp: \(item.description)", color: .green)
            itemLineRanges.append(lineStart..<game.terminalLines.count)
        }
        let stockItems = self.stock

        let startHaggle: (Int) -> Void = { [weak self] idx in
            guard let self = self else { return }
            guard idx >= 0 && idx < stockItems.count else { return }
            let item = stockItems[idx]
            self.showNegotiation(item: item, askingPrice: item.value, attempt: 1, isRareGood: false,
                                  backAction: { self.showHaggleMenu(completion: completion) },
                                  returnTo: { self.showShopMain(completion: completion) },
                                  completion: completion)
        }

        game.showPaginatedMenuOptions(options, pinned: ["?", "< Back"], handler: { idx in
            startHaggle(idx)
        }, pinnedHandler: { [weak self] choice in
            guard let self = self, let game = self.game else { return }
            if choice == 0 {
                game.showInlineHelp {
                    game.printTitle("Haggle — Help")
                    game.print("")
                    game.printWrapped("Tap an item's button, or its green description text, then name your price. The merchant accepts or refuses based on a Persuasion check — refused once, you can try again with a better offer.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.printWrapped("Offering the asking price or more buys it outright, no negotiation needed.", indent: 2, color: .dimGreen)
                    game.print("")
                }
            } else {
                self.showShopMain(completion: completion)
            }
        })
        game.textLongPressHandler = { lineIndex in
            guard let idx = itemLineRanges.firstIndex(where: { $0.contains(lineIndex) }) else { return }
            startHaggle(idx)
        }
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

    /// The one negotiation mechanism in the shop — used for both regular
    /// stock (Haggle) and under-the-counter rare goods (Ask About Rare
    /// Goods > Haggle). Previously these were two separate, near-identical
    /// implementations that had drifted slightly apart (different outright-
    /// accept flavour, different follow-up after a purchase completes) —
    /// reconciled into one function parametrized by `isRareGood`, which
    /// only affects the floor (rare goods are already a favour, so the max
    /// discount is smaller) and the Persuasion DC (+3 harder). Everything
    /// else — buttons, retry flow, wording, and what happens on success —
    /// is now identical regardless of which kind of item you're haggling
    /// over.
    private func showNegotiation(item: Item, askingPrice: Int, attempt: Int, isRareGood: Bool,
                                  backAction: @escaping () -> Void, returnTo: @escaping () -> Void,
                                  completion: @escaping () -> Void) {
        guard let game = game, let character = character, let merchant = merchant else { return }

        game.clearTerminal()
        printPurseAndCarryLine(character)
        game.print("")
        let priceLabel = isRareGood ? "under-the-counter price" : "asking price"
        game.print("  \(item.name) — \(priceLabel) \(askingPrice)gp", color: .brightGreen, bold: true)
        if attempt > 1 {
            game.print("  Attempt \(attempt) of \(Self.maxHaggleAttempts) — \(merchant.name)'s patience is wearing thin.", color: .yellow)
        }
        game.print("")

        // A floor keeps offers sane — the merchant won't entertain an
        // insultingly low bid no matter the roll — and offering the full
        // asking price isn't haggling at all, so that's rejected too. Rare
        // goods are already a favour, so their floor allows less of a
        // discount than ordinary stock.
        let floor = isRareGood ? max(1, askingPrice - askingPrice / 5) : max(1, askingPrice / 4)
        // Capped at what's actually in the purse — an offer above your own
        // gold only ever made sense here as a typo or a bug. Below the
        // floor, `suggestedOffers` just returns no buttons (still handled
        // below) rather than blocking the whole screen — a gold total that
        // can't quite reach the floor is not the same as "definitely
        // cannot afford anything here," and Barter is always offered as a
        // button on this same screen regardless, not gated behind a
        // separate failure state.
        let ceiling = min(askingPrice - 1, character.gold)

        let retry: () -> Void = { [weak self] in
            self?.showNegotiation(item: item, askingPrice: askingPrice, attempt: attempt + 1, isRareGood: isRareGood,
                                   backAction: backAction, returnTo: returnTo, completion: completion)
        }

        func resolveOffer(_ offer: Int) {
            guard let game = self.game, let character = self.character, let merchant = self.merchant else { return }
            if offer == 0 {
                game.print("  You step back from the table.", color: .dimGreen)
                game.waitForContinue()
                game.inputHandler = { _ in backAction() }
                return
            }
            // A typed/spoken offer can still exceed the purse even though
            // the suggested buttons never do — catch it before wasting a
            // Persuasion roll on a price that couldn't be paid anyway.
            guard offer <= character.gold else {
                game.print("  You don't have \(offer) gold to offer.", color: .red)
                game.printWrapped("Care to barter something toward it instead?", indent: 2, color: .dimGreen)
                game.print("")
                game.showMenu(["Barter", "Try Again"])
                game.closeHandler = backAction
                game.menuHandler = { [weak self] choice in
                    guard let self = self else { return }
                    if choice == 1 {
                        self.showBarterMenu(item: item, askingPrice: askingPrice, backAction: backAction, returnTo: returnTo, completion: completion)
                    } else {
                        retry()
                    }
                }
                return
            }
            // Asking price or more — no haggling needed, just sell it. No
            // Persuasion check: there's nothing to persuade the merchant of.
            guard offer < askingPrice else {
                if let reason = character.gold < offer ? "You don't have \(offer) gold." : character.carryBlockReason(for: item) {
                    game.print("  (You agreed a price of \(offer)gp, but: \(reason))", color: .yellow)
                    game.waitForContinue()
                    game.inputHandler = { _ in returnTo() }
                } else {
                    let overpaidBy = offer - askingPrice
                    let flavor: String = overpaidBy > 0
                        ? "  \"Well, aren't you generous.\" \(merchant.name) pockets the extra \(overpaidBy) gold without complaint."
                        : "  \"A fair price, no haggling needed.\" \(merchant.name) hands over the \(item.name)."
                    self.completePurchase(item: item, price: offer, buyer: character,
                                           lines: [(flavor, .brightGreen), ("  Purchased \(item.name) for \(offer) gold.", .yellow)],
                                           returnTo: returnTo, completion: completion)
                }
                return
            }
            guard offer >= floor else {
                game.print("  \"\(offer) gold? You insult me.\" \(merchant.name) won't even consider it.", color: .red)
                let canRetry = attempt < Self.maxHaggleAttempts
                game.waitForContinue()
                game.inputHandler = { _ in canRetry ? retry() : returnTo() }
                return
            }

            let discountPct = Double(askingPrice - offer) / Double(askingPrice)
            let persuasionMod = character.skillModifier(for: .persuasion)
            let roll = Dice.roll(20)
            let total = roll + persuasionMod
            // Steeper asks need a better roll; each repeat attempt on this
            // same item also stiffens the merchant's resolve a little; rare
            // goods are harder to talk down further still.
            let effectiveDC = merchant.tier.haggleDC + (isRareGood ? 3 : 0) + Int((discountPct * 40).rounded()) + (attempt - 1) * 2

            game.print("")
            game.print("  \(character.name) offers \(offer)gp and rolls Persuasion: d20[\(roll)] + \(persuasionMod) = \(total) vs DC \(effectiveDC)", color: .cyan)

            if total >= effectiveDC {
                self.narrate(situation: "The player offers \(offer) gold for a \(item.name) (asking price \(askingPrice)) and makes a successful Persuasion check. React in character, agreeing to the price.",
                             offline: merchant.offlineHaggleSuccessLine(), color: .brightGreen) {
                    if let reason = character.gold < offer ? "You don't have \(offer) gold." : character.carryBlockReason(for: item) {
                        game.print("  (You agreed a price of \(offer)gp, but: \(reason))", color: .yellow)
                        game.waitForContinue()
                        game.inputHandler = { _ in returnTo() }
                    } else {
                        self.completePurchase(item: item, price: offer, buyer: character,
                                               lines: [("  Purchased \(item.name) for \(offer) gold (haggled down from \(askingPrice)).", .yellow)],
                                               returnTo: returnTo, completion: completion)
                    }
                }
            } else {
                let canRetry = attempt < Self.maxHaggleAttempts
                // A near-miss (within 5 of the DC) gets a real counter-offer
                // instead of a flat refusal — the merchant meets partway,
                // and the player gets an explicit button to accept it,
                // rather than only ever being able to accept their OWN offer.
                let nearMiss = total >= effectiveDC - 5 && offer < askingPrice - 1
                if nearMiss {
                    let counter = min(askingPrice - 1, offer + max(1, (askingPrice - offer) / 2))
                    self.narrate(situation: "The player offers \(offer) gold for a \(item.name) (asking price \(askingPrice)) and narrowly fails the Persuasion check. Instead of a flat refusal, counter with a price of \(counter) gold. React in character, meeting the player partway.",
                                 offline: merchant.offlineHaggleCounterLine(), color: .yellow) {
                        game.print("  \(merchant.name) offers \(counter)gp instead.", color: .yellow)
                        game.showMenu(["Accept \(counter)gp", canRetry ? "Try Again" : "< Back"])
                        game.menuHandler = { [weak self] choice in
                            guard let self = self, let game = self.game, let character = self.character else { return }
                            if choice == 1 {
                                if let reason = character.gold < counter ? "You don't have \(counter) gold." : character.carryBlockReason(for: item) {
                                    game.print("  (You agreed a price of \(counter)gp, but: \(reason))", color: .yellow)
                                    game.waitForContinue()
                                    game.inputHandler = { _ in returnTo() }
                                } else {
                                    self.completePurchase(item: item, price: counter, buyer: character,
                                                           lines: [("  Purchased \(item.name) for \(counter) gold (merchant's counter-offer).", .yellow)],
                                                           returnTo: returnTo, completion: completion)
                                }
                            } else {
                                canRetry ? retry() : returnTo()
                            }
                        }
                    }
                } else {
                    self.narrate(situation: "The player offers \(offer) gold for a \(item.name) (asking price \(askingPrice)) but fails the Persuasion check. React in character, refusing that price\(canRetry ? ", but leave room for a better offer" : " and firmly end the negotiation").",
                                 offline: merchant.offlineHaggleFailLine(), color: .red) {
                        game.logEvent("\(character.name) offered \(offer) gold for \(item.name) with \(merchant.name) — refused", category: "SHOP")
                        game.waitForContinue()
                        game.inputHandler = { _ in canRetry ? retry() : returnTo() }
                    }
                }
            }
        }

        // Offer a few suggested prices as buttons — in ascending order —
        // so haggling doesn't require typing a number, while still
        // accepting a typed (or spoken) custom offer too. Varies each
        // time this prompt is shown; ">>" re-rolls a fresh batch on demand.
        let offers = suggestedOffers(floor: floor, ceiling: ceiling)
        // Barter is always here as its own button — not just a fallback
        // shown when gold alone falls short — so trading in an item toward
        // the price is always one tap away, whether or not gold alone
        // would've been enough.
        let options = offers.map { "\($0)gp" } + [">>", "Barter", "?", "< Back"]
        if ceiling < floor {
            game.print("  Your purse alone won't quite cover a lowball offer here.", color: .yellow)
            game.print("")
        }
        game.promptTextWithMenu("Name your price (\(floor)gp or more — \(askingPrice)gp or above buys it outright), or 0 to walk away:", options: options)
        game.closeHandler = backAction
        game.menuHandler = { [weak self] choice in
            if choice >= 1 && choice <= offers.count {
                resolveOffer(offers[choice - 1])
                return
            }
            switch choice - offers.count {
            case 1:
                self?.showNegotiation(item: item, askingPrice: askingPrice, attempt: attempt, isRareGood: isRareGood,
                                       backAction: backAction, returnTo: returnTo, completion: completion)
            case 2:
                guard let self = self else { return }
                self.showBarterMenu(item: item, askingPrice: askingPrice, backAction: backAction, returnTo: returnTo, completion: completion)
            case 3:
                guard let game = self?.game else { return }
                game.showInlineHelp {
                    game.printTitle("Name Your Price — Help")
                    game.print("")
                    game.printWrapped("Tap a suggested price, or type (or speak) your own. \">>\" shows a fresh set of suggestions. Barter trades an item in toward the price instead of (or alongside) gold.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.printWrapped("Offering \(askingPrice)gp or more buys it outright. Below \(floor)gp is refused outright as insulting. Anything in between is a Persuasion check — the lower you go, the harder it is to land.", indent: 2, color: .dimGreen)
                    game.print("")
                    game.printWrapped("0 walks away from the item entirely.", indent: 2, color: .dimGreen)
                    game.print("")
                }
            default:
                backAction()
            }
        }
        game.inputHandler = { text in
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard let offer = Int(trimmed), offer >= 0 else {
                game.print("  \"Speak plainly — a number, adventurer.\"", color: .yellow)
                game.waitForContinue()
                game.inputHandler = { [weak self] _ in
                    self?.showNegotiation(item: item, askingPrice: askingPrice, attempt: attempt, isRareGood: isRareGood,
                                           backAction: backAction, returnTo: returnTo, completion: completion)
                }
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

        // Once revealed, a rare item stays remembered (same item, same
        // price) across this and future visits until actually bought —
        // "let me check" shouldn't turn up something different, or nothing
        // at all, next time you ask.
        let alreadyOffered = merchant.rareGoodsOffered.first
        let roll = Int.random(in: 1...100)
        if let rareItem = alreadyOffered ?? (roll <= merchant.tier.rareGoodsChance ? Self.rareGoodsPool.randomElement() : nil) {
            let price = max(1, Int((Double(rareItem.value) * merchant.tier.rareGoodsMarkup).rounded()))
            if alreadyOffered == nil {
                self.merchant?.rareGoodsOffered = [rareItem]
                syncMerchantToRoom()
            }
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
                        self.showNegotiation(item: rareItem, askingPrice: price, attempt: 1, isRareGood: true,
                                              backAction: { self.showShopMain(completion: completion) },
                                              returnTo: { self.showShopMain(completion: completion) },
                                              completion: completion)
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
        if let reason = character.carryBlockReason(for: item) {
            game.print("  \"\(reason)\"", color: .red)
            game.waitForContinue()
            game.inputHandler = { [weak self] _ in self?.showShopMain(completion: completion) }
            return
        }
        // Bought — no longer remembered as "on offer" for next time.
        self.merchant?.rareGoodsOffered = []
        syncMerchantToRoom()
        let returnTo: () -> Void = { [weak self] in self?.showShopMain(completion: completion) }
        completePurchase(item: item, price: price, buyer: character,
                          lines: [("  You purchase the \(item.name) for \(price) gold.", .brightGreen)],
                          returnTo: returnTo, completion: completion)
    }

    // MARK: - Farewell

    /// Always narrates a goodbye tailored to what happened this visit
    /// (bought/sold/neither), then — 25% of the time, once per visit —
    /// tacks on a piece of unsolicited advice, then hands off to
    /// `completion` (which returns to exploration). Restores exploration
    /// music before completion, since the shop's own musak (started in
    /// openShop) would otherwise just keep playing.
    private func showFarewell(completion: @escaping () -> Void) {
        guard let game = game, let merchant = merchant else { completion(); return }

        let bought = !itemsBoughtThisVisit.isEmpty
        let sold = !itemsSoldThisVisit.isEmpty
        let summary = visitSummary()

        game.print("")
        if !summary.isEmpty {
            game.print("  \(summary)", color: .dimGreen)
        }

        let situation: String
        if bought || sold {
            situation = "The player is leaving your shop after this visit: \(summary) React in character with a brief farewell that acknowledges what they bought or sold, and says you hope to see them again."
        } else {
            situation = "The player is leaving your shop without buying or selling anything this visit. React in character with a brief, good-natured farewell."
        }

        self.narrate(situation: situation, offline: merchant.offlineFarewellLine(bought: bought, sold: sold), color: .cyan) { [weak self] in
            self?.maybeOfferAdvice(completion: completion)
        }
    }

    /// e.g. "You bought a Longsword and a Healing Potion, and sold an old
    /// Torch." Empty string if nothing happened this visit.
    private func visitSummary() -> String {
        var parts: [String] = []
        if !itemsBoughtThisVisit.isEmpty {
            parts.append("bought \(Self.listNames(itemsBoughtThisVisit))")
        }
        if !itemsSoldThisVisit.isEmpty {
            parts.append("sold \(Self.listNames(itemsSoldThisVisit))")
        }
        guard !parts.isEmpty else { return "" }
        return "You " + parts.joined(separator: ", and ") + "."
    }

    /// "a Sword", "a Sword and a Torch", "a Sword, a Torch, and 2 Potions"
    /// — groups duplicate names ("Potion" x2 -> "2 Potions") rather than
    /// repeating each instance.
    private static func listNames(_ names: [String]) -> String {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for name in names {
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        let items = order.map { name -> String in
            let count = counts[name] ?? 1
            if count > 1 { return "\(count) \(name)s" }
            let article = "AEIOU".contains(name.first ?? " ") ? "an" : "a"
            return "\(article) \(name)"
        }
        switch items.count {
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }

    private func maybeOfferAdvice(completion: @escaping () -> Void) {
        guard let game = game, var merchant = merchant else { completion(); return }
        defer {
            // Whatever happens above, leaving the shop always restores
            // exploration music in place of its musak.
            if game.musicEnabled { SoundManager.shared.startMusic(.exploration, preference: game.explorationMelodyChoice) }
        }
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
