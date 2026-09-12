//
//  MerchantModels.swift
//  DnDTextRPG
//
//  Merchant NPCs: tiered shopkeepers with names, personas, and stock that scale
//  with dungeon depth. Bargaining/rare-goods/advice are resolved as game mechanics
//  (dice checks, tables) and merely *narrated* by whichever DM tier is active, so
//  they work identically whether the player has cloud AI, Apple on-device AI, or
//  no AI at all.
//

import Foundation

enum MerchantTier: String, CaseIterable, Codable {
    case wanderingPeddler = "Wandering Peddler"
    case generalStore = "General Store"
    case tradingPost = "Trading Post"
    case superstore = "Hyperstore"

    /// How many items the shop stocks.
    var stockCount: Int {
        switch self {
        case .wanderingPeddler: return 4
        case .generalStore: return 7
        case .tradingPost: return 11
        case .superstore: return 16
        }
    }

    /// Chance (0-100) that "Ask About Rare Goods" turns something up.
    var rareGoodsChance: Int {
        switch self {
        case .wanderingPeddler: return 35
        case .generalStore: return 45
        case .tradingPost: return 60
        case .superstore: return 80
        }
    }

    /// Price premium on rare/under-the-counter items.
    var rareGoodsMarkup: Double {
        switch self {
        case .wanderingPeddler: return 2.2
        case .generalStore: return 2.0
        case .tradingPost: return 1.8
        case .superstore: return 1.6
        }
    }

    /// Base difficulty of the merchant's haggle disposition — higher = harder to talk down.
    var haggleDC: Int {
        switch self {
        case .wanderingPeddler: return 11
        case .generalStore: return 13
        case .tradingPost: return 14
        case .superstore: return 16 // corporate pricing doesn't budge easily
        }
    }

    static func forDungeonLevel(_ level: Int) -> MerchantTier {
        switch level {
        case ..<2: return .wanderingPeddler
        case 2...3: return .generalStore
        case 4...5: return .tradingPost
        default: return .superstore
        }
    }
}

struct Merchant: Codable, Equatable {
    var name: String
    var shopName: String
    var tier: MerchantTier
    var greeting: String
    var catchphrase: String
    /// One-line persona summary handed to the DM as context for bargaining/advice/rare-goods narration.
    var personaBlurb: String

    /// Regular buy-list, rolled once and remembered from then on — a merchant
    /// who's shown you a Chain Mail shouldn't have a different (or no)
    /// Chain Mail if you leave and come back later.
    var stock: [Item] = []
    /// Rare "under the counter" item(s), remembered the same way once
    /// actually revealed — cleared again once bought.
    var rareGoodsOffered: [Item] = []
    var hasOfferedAdviceThisVisit: Bool = false

    static func == (lhs: Merchant, rhs: Merchant) -> Bool { lhs.name == rhs.name && lhs.shopName == rhs.shopName }

    private struct Persona {
        let name: String
        let shopNames: [String]
        let greeting: String
        let catchphrase: String
        let blurb: String
    }

    // Original, non-copyrighted personas. Small-tier merchants lean into a
    // grumpy-but-good-hearted haggling-apothecary archetype; bigger tiers get
    // more corporate/impersonal flavour as the operation scales up.
    private static let peddlerPersonas: [Persona] = [
        Persona(name: "Old Mordecai", shopNames: ["Mordecai's Pack", "The Wanderer's Bundle"],
                greeting: "\"Eh? Oh, a customer! Don't touch anything, I know exactly how much of it there is.\"",
                catchphrase: "\"Everything's negotiable except my knees.\"",
                blurb: "Old Mordecai is a cantankerous, wisecracking travelling peddler who insults customers fondly while secretly enjoying a good haggle. Gruff exterior, soft heart, sharp memory for prices."),
        Persona(name: "Auntie Fen", shopNames: ["Fen's Folding Cart", "The Tinker's Bindle"],
                greeting: "\"Sit, sit, don't loom. Let's see what you're carrying that I might want, hm?\"",
                catchphrase: "\"I've buried three husbands and a fortune in bad deals — I know a good one when I see it.\"",
                blurb: "Auntie Fen is a shrewd, motherly-but-ruthless wandering trader who bargains hard and enjoys the theatre of it. Warm insults, sharp business sense."),
        Persona(name: "Cutrate Cornelius", shopNames: ["Cornelius & Sundries", "The Bent Copper"],
                greeting: "\"Special today! Everything's special today, that's the whole business model.\"",
                catchphrase: "\"I'm practically giving this away. Practically.\"",
                blurb: "Cutrate Cornelius is a fast-talking, overly theatrical bargain hawker who oversells everything and expects to be haggled down.")
    ]
    private static let generalStorePersonas: [Persona] = [
        Persona(name: "Bartleby Cross", shopNames: ["The Rusty Coin", "Cross & Daughters General Goods"],
                greeting: "\"Welcome in. Mind the crates. What're you after?\"",
                catchphrase: "\"Quality goods, honest prices, no funny business — mostly.\"",
                blurb: "Bartleby Cross runs a no-nonsense general store. Businesslike but fair, will haggle if you make a decent case."),
        Persona(name: "Grumbling Greta", shopNames: ["The Bent Blade Emporium", "Greta's Odds & Ends"],
                greeting: "\"Don't dawdle by the door, you're letting the damp in. Come look properly.\"",
                catchphrase: "\"I've got a price for everything and a story for most of it.\"",
                blurb: "Grumbling Greta is gruff but knowledgeable, runs a cluttered general store, secretly enjoys customers who banter back.")
    ]
    private static let tradingPostPersonas: [Persona] = [
        Persona(name: "Master Hollis Quill", shopNames: ["The Gilded Gauntlet Trading Post", "Quill's Crossroads Depot"],
                greeting: "\"Welcome to the Post. We deal fair, we deal fast, and we deal in volume.\"",
                catchphrase: "\"A satisfied customer tells one friend. A cheated one tells the whole road.\"",
                blurb: "Master Hollis Quill runs a respected multi-room trading post with a wide catalogue and firm-but-reasonable prices."),
        Persona(name: "Steward Della Vane", shopNames: ["Vane's Crossroads Trading Post", "The Last Waystop"],
                greeting: "\"Papers in order? Good. Now, what can the Post do for you today?\"",
                catchphrase: "\"Everything's catalogued, everything's fair, everything's for sale — at the right price.\"",
                blurb: "Steward Della Vane is efficient and a little imperious, running a well-organised trading post; respects a well-argued haggle.")
    ]
    private static let superstorePersonas: [Persona] = [
        Persona(name: "The Floor Manager", shopNames: ["Bargain Barrow Hyperstore", "PACK-MULE™ Provisions Depot"],
                greeting: "\"Welcome to the Hyperstore! Today's special is... well, everything's on the shelf, take your pick!\"",
                catchphrase: "\"Our prices are fixed by corporate, but I *might* know a workaround.\"",
                blurb: "The Floor Manager oversees a sprawling, absurdly over-stocked dungeon superstore. Chipper, slightly corporate, easily flustered by aggressive haggling but has hidden discretionary discounts."),
        Persona(name: "Quartermaster Bosk", shopNames: ["Bosk's Bulk & Bargain", "The Last Copper Hyperstore"],
                greeting: "\"Aisle after aisle, friend. If we don't stock it, it probably doesn't exist.\"",
                catchphrase: "\"Buy in bulk, adventure in style.\"",
                blurb: "Quartermaster Bosk runs a vast, warehouse-scale outfitters. Businesslike, proud of the inventory, softens up if you compliment the selection.")
    ]

    private static func personas(for tier: MerchantTier) -> [Persona] {
        switch tier {
        case .wanderingPeddler: return peddlerPersonas
        case .generalStore: return generalStorePersonas
        case .tradingPost: return tradingPostPersonas
        case .superstore: return superstorePersonas
        }
    }

    static func random(tier: MerchantTier) -> Merchant {
        let persona = personas(for: tier).randomElement()!
        return Merchant(
            name: persona.name,
            shopName: persona.shopNames.randomElement()!,
            tier: tier,
            greeting: persona.greeting,
            catchphrase: persona.catchphrase,
            personaBlurb: persona.blurb
        )
    }

    /// Templated advice lines used when no AI is available to generate one.
    static let adviceLines = [
        "\"Short on coin? Sell what you're not using — dead weight doesn't pay rent.\"",
        "\"Cleared rooms sometimes hide gold if you search properly. Don't rush past them.\"",
        "\"Monsters drop better loot than you'd think. Worth finishing a fight properly.\"",
        "\"If you can't afford it today, come back after your next haul. I'm not going anywhere.\"",
        "\"Treasure rooms are worth a careful look. People walk past gold all the time.\"",
        "\"A well-timed sale funds a well-timed purchase. Think about what you actually need.\""
    ]

    /// Offline-safe (no AI required) flavour for haggling, rare goods, and advice —
    /// built from this merchant's own name/catchphrase so it still feels personal
    /// with zero AI available. AI tiers use DMEngine.merchantNarration() instead;
    /// these are the guaranteed fallback.
    func offlineHaggleSuccessLine() -> String {
        ["\"" + "Fine, FINE. " + catchphrase.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) + " You drive a hard bargain.\"",
         "\(name) sighs theatrically. \"You've got a silver tongue. Deal.\"",
         "\"Don't tell the others I did this,\" \(name) mutters, waving off part of the price."].randomElement()!
    }
    func offlineHaggleFailLine() -> String {
        ["\"" + "Nice try. " + catchphrase.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) + "\"",
         "\(name) crosses their arms. \"The price is the price.\"",
         "\"I like you,\" says \(name), \"but not that much.\""].randomElement()!
    }
    func offlineHaggleCounterLine() -> String {
        ["\(name) rubs their chin. \"Not quite — but let's meet partway.\"",
         "\"" + "You're close. " + catchphrase.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) + " Here's my counter.\"",
         "\(name) taps the counter. \"Tell you what — I'll do it for this instead.\""].randomElement()!
    }
    func offlineRareGoodsFoundLine() -> String {
        "\(name) glances around, then reaches under the counter. \"Don't tell my usual suppliers I still have this.\""
    }
    func offlineRareGoodsNoneLine() -> String {
        "\(name) shrugs. \"Nothing special today, adventurer — check back after I've restocked.\""
    }

    /// A goodbye line as the player leaves the shop, tailored to whether
    /// anything was actually bought or sold this visit.
    func offlineFarewellLine(bought: Bool, sold: Bool) -> String {
        if bought && sold {
            return ["\"Pleasure doing business both ways! Come back soon, adventurer.\"",
                    "\(name) waves. \"Buying and selling both — now that's how it's done. Safe travels.\""].randomElement()!
        } else if bought {
            return ["\"" + catchphrase.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) + " Enjoy your purchase, and mind the dark corners out there.\"",
                    "\(name) grins. \"A pleasure! Come back when your purse is full again.\""].randomElement()!
        } else if sold {
            return ["\"Thanks for thinking of me. Every little bit helps.\" \(name) pockets the coin.",
                    "\(name) nods. \"Good trading with you. Safe travels, adventurer.\""].randomElement()!
        } else {
            return ["\"Nothing today? No matter — I'll be here.\" \(name) shrugs amiably.",
                    "\(name) waves you off. \"Come back anytime, coin or no coin.\""].randomElement()!
        }
    }
}
