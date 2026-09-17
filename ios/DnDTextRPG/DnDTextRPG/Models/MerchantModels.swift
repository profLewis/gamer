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
    /// Goods this one's greeting actually names. Whatever they mention is put
    /// at the front of the shop and so becomes the default button — the patter
    /// and the counter should agree. Defaulted, because Merchant is saved
    /// inside a game and merchants from older saves simply have none.
    var mentions: [String] = []

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
        /// See Merchant.mentions. Named here rather than picked out of the
        /// greeting: parsing English would be brittle, and would miss "the
        /// bread's still warm", where the noun is there but the sentence is
        /// not an offer. Only goods that genuinely exist in ItemCatalog.
        var mentions: [String] = []
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
                blurb: "Cutrate Cornelius is a fast-talking, overly theatrical bargain hawker who oversells everything and expects to be haggled down."),
        Persona(name: "Pip Thistlewick", shopNames: ["Thistlewick's Barrow", "The Pie & Pocket"],
                greeting: "\"Hungry? Lost? Both? I've a pie for one and a trinket for the other.\"",
                catchphrase: "\"A warm pie never let anyone down.\"",
                blurb: "Pip Thistlewick is a cheerful halfling who pushes a barrow of pies, buttons and oddments through the dark, chatters constantly and gives away more crumbs than he sells.",
                mentions: ["Jar of Honey"]),
        Persona(name: "Madame Ostra", shopNames: ["Ostra's Curiosities", "The Crystal Cart"],
                greeting: "\"Ah, I foresaw you coming. Also, I heard your boots.\"",
                catchphrase: "\"The cards say you'll buy something. The cards are rarely wrong.\"",
                blurb: "Madame Ostra sells charms and curios with a fortune-teller's flourish, half theatre and half real wisdom; she haggles in riddles."),
        Persona(name: "Grub", shopNames: ["Grub's Good Stuff", "The Shiny Things Wagon"],
                greeting: "\"Friend! Friend-friend! Grub has shinies. Grub is honest goblin. Mostly.\"",
                catchphrase: "\"Grub never steal from customers. Only from monsters.\"",
                blurb: "Grub is a small, friendly goblin who left his tribe to go into trade; he is thrilled by every sale and counts coins out loud."),
        Persona(name: "Brother Amble", shopNames: ["The Humble Satchel", "Amble's Almsbag"],
                greeting: "\"Peace be with you, traveller. And a candle, if you'd like one.\"",
                catchphrase: "\"A fair price is a small kindness.\"",
                blurb: "Brother Amble is a wandering monk who trades candles, bandages and herbs to fund his journey; gentle, patient and hard to rush.",
                mentions: ["Torch"]),
        Persona(name: "Nell Fairweather", shopNames: ["Fairweather Herbs", "The Green Satchel"],
                greeting: "\"Mind the moss — it's for sale. So is the mint.\"",
                catchphrase: "\"There's a leaf for every ache.\"",
                blurb: "Nell Fairweather is a brisk herbalist who knows every plant that grows in the dark and exactly what it's worth.",
                mentions: ["Pouch of Dried Herbs", "Antidote"]),
        Persona(name: "Tobias Crank", shopNames: ["Crank's Cogs & Keys", "The Ticking Trolley"],
                greeting: "\"Stand back, stand back — the trolley bites when it's excited.\"",
                catchphrase: "\"If it's broken, I can fix it. If it's fixed, I can improve it.\"",
                blurb: "Tobias Crank is an inventive tinker whose clockwork cart follows him about like a dog; he loves a customer who asks how things work.")
    ]
    private static let generalStorePersonas: [Persona] = [
        Persona(name: "Bartleby Cross", shopNames: ["The Rusty Coin", "Cross & Daughters General Goods"],
                greeting: "\"Welcome in. Mind the crates. What're you after?\"",
                catchphrase: "\"Quality goods, honest prices, no funny business — mostly.\"",
                blurb: "Bartleby Cross runs a no-nonsense general store. Businesslike but fair, will haggle if you make a decent case."),
        Persona(name: "Grumbling Greta", shopNames: ["The Bent Blade Emporium", "Greta's Odds & Ends"],
                greeting: "\"Don't dawdle by the door, you're letting the damp in. Come look properly.\"",
                catchphrase: "\"I've got a price for everything and a story for most of it.\"",
                blurb: "Grumbling Greta is gruff but knowledgeable, runs a cluttered general store, secretly enjoys customers who banter back."),
        Persona(name: "Hilda Stonebrew", shopNames: ["Stonebrew Provisions", "The Honest Loaf"],
                greeting: "\"Wipe your boots and grab a basket. The bread's still warm.\"",
                catchphrase: "\"Full bellies make brave hearts.\"",
                blurb: "Hilda Stonebrew is a dwarf grocer who bakes, brews and stocks everything a party needs; brusque, generous, and proud of her bread."),
        Persona(name: "Silas Marrow", shopNames: ["Marrow's Mercantile", "The Quiet Shelf"],
                greeting: "\"Oh! Customers. Good. Yes. Please don't make any sudden noises.\"",
                catchphrase: "\"Everything's in order. Probably. I check twice.\"",
                blurb: "Silas Marrow is a nervous but meticulous shopkeeper who jumps at shadows and keeps the tidiest shelves in the dungeon."),
        Persona(name: "Olwen Ashgrove", shopNames: ["Ashgrove Outfitters", "The Silver Leaf Store"],
                greeting: "\"Welcome, wanderers. Rest your feet — the prices will wait.\"",
                catchphrase: "\"Good gear is a promise to come home.\"",
                blurb: "Olwen Ashgrove is a calm elven outfitter with an eye for well-made things and little patience for cheap ones."),
        Persona(name: "Big Tam", shopNames: ["Tam's Tidy Stores", "The Gentle Giant"],
                greeting: "\"Come in, come in. Duck your head — no, not you, you're fine.\"",
                catchphrase: "\"Big shop, small prices.\"",
                blurb: "Big Tam is a huge, soft-spoken half-orc who runs a spotless store, folds everything neatly and hates to see a customer leave unhappy."),
        Persona(name: "Widow Pennywhistle", shopNames: ["Pennywhistle's Pantry", "The Button Jar"],
                greeting: "\"Sit down, dearie, you look half-starved. Now, what can I sell you?\"",
                catchphrase: "\"A penny saved is a penny I haven't got yet.\"",
                blurb: "Widow Pennywhistle is a sharp-eyed old lady who mothers every customer and drives the hardest bargain in the dungeon."),
        Persona(name: "Jory Flint", shopNames: ["Flint & Tinder", "The Retired Blade"],
                greeting: "\"Adventurers! I was one of you once. Then I took an arrow to the pension.\"",
                catchphrase: "\"I've used everything I sell. Some of it twice.\"",
                blurb: "Jory Flint is a retired adventurer turned shopkeeper who swaps war stories for discounts and knows which gear really works.")
    ]
    private static let tradingPostPersonas: [Persona] = [
        Persona(name: "Master Hollis Quill", shopNames: ["The Gilded Gauntlet Trading Post", "Quill's Crossroads Depot"],
                greeting: "\"Welcome to the Post. We deal fair, we deal fast, and we deal in volume.\"",
                catchphrase: "\"A satisfied customer tells one friend. A cheated one tells the whole road.\"",
                blurb: "Master Hollis Quill runs a respected multi-room trading post with a wide catalogue and firm-but-reasonable prices."),
        Persona(name: "Steward Della Vane", shopNames: ["Vane's Crossroads Trading Post", "The Last Waystop"],
                greeting: "\"Papers in order? Good. Now, what can the Post do for you today?\"",
                catchphrase: "\"Everything's catalogued, everything's fair, everything's for sale — at the right price.\"",
                blurb: "Steward Della Vane is efficient and a little imperious, running a well-organised trading post; respects a well-argued haggle."),
        Persona(name: "Captain Maris Holt", shopNames: ["The Anchor & Lantern", "Holt's Harbour Post"],
                greeting: "\"Welcome aboard! Well — welcome in. Old habits.\"",
                catchphrase: "\"Fair winds and fair prices.\"",
                blurb: "Captain Maris Holt is a former sea captain who runs her trading post like a ship: shipshape, loud, and fond of a good yarn."),
        Persona(name: "Sir Percival Dunmore", shopNames: ["Dunmore's Depot", "The Honour-Bound Post"],
                greeting: "\"Greetings, noble travellers. Every price here is sworn upon my honour.\"",
                catchphrase: "\"A knight never overcharges. Well, not twice.\"",
                blurb: "Sir Percival Dunmore is a courteous old knight turned trader who treats every sale as a solemn oath and every haggle as a joust."),
        Persona(name: "Zafira of the Caravans", shopNames: ["Caravan of Zafira", "The Dune Road Post"],
                greeting: "\"Sand in your boots? Silk on my shelves. Come and see.\"",
                catchphrase: "\"Everything travels. Everything has a price.\"",
                blurb: "Zafira brings goods from far-off deserts along roads nobody else dares; clever, amused and endlessly patient in a bargain."),
        Persona(name: "The Brothers Umber", shopNames: ["Umber & Umber", "The Twin Scales"],
                greeting: "\"Welcome! — Welcome! — He said it first. — I said it better.\"",
                catchphrase: "\"Two brothers, one price. Usually.\"",
                blurb: "The Brothers Umber are twins who finish each other's sentences and argue about every price, which can work in a clever customer's favour."),
        Persona(name: "Keeper Aldous Grey", shopNames: ["Grey's Maps & Means", "The Chart House"],
                greeting: "\"Mind the ink. Ah — you'll be wanting a map, I expect. Everyone does, eventually.\"",
                catchphrase: "\"The best treasure is knowing where you are.\"",
                blurb: "Keeper Aldous Grey is a scholarly trader who deals in maps, lamps and learning, and will talk your ear off about where things came from.")
    ]
    private static let superstorePersonas: [Persona] = [
        Persona(name: "The Floor Manager", shopNames: ["Bargain Barrow Hyperstore", "PACK-MULE™ Provisions Depot"],
                greeting: "\"Welcome to the Hyperstore! Today's special is... well, everything's on the shelf, take your pick!\"",
                catchphrase: "\"Our prices are fixed by corporate, but I *might* know a workaround.\"",
                blurb: "The Floor Manager oversees a sprawling, absurdly over-stocked dungeon superstore. Chipper, slightly corporate, easily flustered by aggressive haggling but has hidden discretionary discounts."),
        Persona(name: "Quartermaster Bosk", shopNames: ["Bosk's Bulk & Bargain", "The Last Copper Hyperstore"],
                greeting: "\"Aisle after aisle, friend. If we don't stock it, it probably doesn't exist.\"",
                catchphrase: "\"Buy in bulk, adventure in style.\"",
                blurb: "Quartermaster Bosk runs a vast, warehouse-scale outfitters. Businesslike, proud of the inventory, softens up if you compliment the selection."),
        Persona(name: "Madame Voss", shopNames: ["Voss & Sons Grand Emporium", "The Golden Aisle"],
                greeting: "\"Welcome to the Emporium. Do try not to breathe on the crystal.\"",
                catchphrase: "\"Only the finest, darling. Always the finest.\"",
                blurb: "Madame Voss runs a gleaming luxury emporium deep underground, looks down her nose at bargain-hunters and secretly loves being out-haggled."),
        Persona(name: "Assistant Deputy Clerk Wimble", shopNames: ["Wimble's Warehouse of Wonders", "The Mega-Mart of the Deep"],
                greeting: "\"Welcome! Please take a ticket. You are number four thousand and six.\"",
                catchphrase: "\"Your custom is important to us. Please hold.\"",
                blurb: "Assistant Deputy Clerk Wimble is buried in forms at a vast underground warehouse, ever so polite and hopelessly lost in the paperwork."),
        Persona(name: "Orla Brightcoin", shopNames: ["Brightcoin's Everything Store", "Gears & Goods Galore"],
                greeting: "\"Ding! That's the door-bell I invented. Welcome to the store I also invented!\"",
                catchphrase: "\"If I haven't got it, I'll build it by Tuesday.\"",
                blurb: "Orla Brightcoin is a gnome inventor whose department store is full of clever gadgets, moving shelves and price tags that sing."),
        Persona(name: "The Twelve-Armed Clerk", shopNames: ["The Many-Hands Market", "Stack & Shelf"],
                greeting: "\"GREETINGS. I CAN SERVE TWELVE CUSTOMERS AT ONCE. YOU ARE ONLY FOUR.\"",
                catchphrase: "\"EFFICIENCY IS ITS OWN REWARD. ALSO GOLD.\"",
                blurb: "The Twelve-Armed Clerk is a friendly clockwork construct that fetches, wraps and rings up goods all at once, and is baffled but charmed by haggling."),
        Persona(name: "Duchess Marigold", shopNames: ["Marigold's Magnificent Mart", "The Velvet Warehouse"],
                greeting: "\"Oh, how delightful — adventurers! Do come in, the tea is on.\"",
                catchphrase: "\"Shopping should always feel like a party.\"",
                blurb: "Duchess Marigold turned her family fortune into a sprawling, cheerful warehouse store; generous, chatty and very hard to say no to.")
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
        // A persona not already in this dungeon, if there is one.
        let all = personas(for: tier)
        let fresh = all.filter { NameRegistry.isFree($0.name) }
        let persona = (fresh.isEmpty ? all : fresh).randomElement()!
        return Merchant(
            name: NameRegistry.claim(persona.name),
            shopName: persona.shopNames.randomElement()!,
            tier: tier,
            greeting: persona.greeting,
            catchphrase: persona.catchphrase,
            personaBlurb: persona.blurb,
            mentions: persona.mentions
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
