# Copyright & Trademark Review

Reviewed: 2026-03-14
Files searched: All `.swift` files in `ios/DnDTextRPG/`, data files in `data/`

Risk levels:
- **High** = WotC Product Identity, active trademark enforcement, or strong IP from litigious owners
- **Medium** = Copyrighted character from a specific work, but risk is lower (homage/reference context, older works, less litigious owners)
- **Low** = Public domain, SRD/OGL content, generic fantasy, mythology, or names too common to protect

---

## 1. Monsters (CombatModels.swift)

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Beholder | MonsterType enum, boss list, ASCII art | **WotC Product Identity** -- explicitly trademarked by Wizards of the Coast. NOT in the SRD. | **HIGH** |
| Mind Flayer | MonsterType enum, boss list, ASCII art | **WotC Product Identity** -- explicitly trademarked by WotC. NOT in the SRD. | **HIGH** |
| Displacer Beast | MonsterType enum, encounter list, ASCII art | **WotC Product Identity** -- explicitly trademarked by WotC. NOT in the SRD. | **HIGH** |
| Vecna | MonsterType enum, boss list, ASCII art, attack text "the Hand of Vecna" | **WotC Product Identity** -- Vecna is a named WotC NPC/deity, trademarked. NOT in the SRD. | **HIGH** |
| Demogorgon | MonsterType enum, boss list, ASCII art | **WotC Product Identity** -- Demogorgon is a named demon prince, Product Identity. The name predates D&D (from demonology) but the specific D&D usage is trademarked. Also strongly associated with Stranger Things (Netflix). | **HIGH** |
| Owlbear | MonsterType enum, encounter list, ASCII art | **WotC-originated creature** -- created for D&D. Was NOT in the original SRD 5.1, but was included in the CC-BY 5.1 SRD revision (2023). Status is ambiguous -- safer to treat as medium risk. | **Medium** |
| Rust Monster | MonsterType enum, encounter list, ASCII art | **WotC-originated creature** -- created for D&D. Not in the SRD. | **Medium** |
| Gelatinous Cube | MonsterType enum, encounter list, ASCII art | **WotC-originated creature** -- iconic D&D monster. Included in the 5.1 SRD (CC-BY), so likely safe. | Low |
| Gnoll | MonsterType enum, encounter list | In the 5.1 SRD. Generic enough. | Low |
| Bugbear | MonsterType enum, encounter list | In the SRD. From folklore. | Low |
| Mimic | MonsterType enum, encounter list | In the SRD. Widely used across games. | Low |
| Kobold | MonsterType enum | In the SRD. From Germanic folklore. | Low |
| All other monsters | Various | Goblin, Skeleton, Zombie, Wolf, Orc, Hobgoblin, Giant Rat, Giant Spider, Ogre, Troll, Minotaur, Basilisk, Wraith, Gargoyle, Stirge, Giant Bat, Crawling Claw, Young Dragon -- all SRD or generic folklore/mythology. | Low |

---

## 2. Hall of Fame Seed Data (HallOfFame.swift)

### Character Names

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Aragorn | Hall of Fame seed party | **J.R.R. Tolkien / Tolkien Estate / Middle-earth Enterprises**. Trademarked character name. | **HIGH** |
| Ged | Hall of Fame seed party | **Ursula K. Le Guin Estate** -- protagonist of the Earthsea series. Copyrighted character. | **Medium** |
| Granny Weatherwax | Hall of Fame seed party | **Terry Pratchett Estate / Narrativia** -- Discworld character. Copyrighted. | **Medium** |
| Madmartigan | Hall of Fame seed party | **Lucasfilm / Disney** -- character from Willow (1988). | **HIGH** |
| Willow | Hall of Fame seed party (as character name) | **Lucasfilm / Disney** -- Willow Ufgood from Willow (1988). The name "Willow" alone is generic but used in context of the film party. | **Medium** |
| Hawk | Hall of Fame seed party | **Warner Bros** -- from Ladyhawke (1985). The name alone is generic. | Low |
| Red Sonja | Hall of Fame seed party (appears twice) | **Red Sonja LLC / Dynamite Entertainment** -- actively trademarked character. | **HIGH** |
| Edgin | Hall of Fame seed party | **Paramount / Hasbro** -- from D&D: Honour Among Thieves (2023). | **Medium** |
| Holga | Hall of Fame seed party | **Paramount / Hasbro** -- from D&D: Honour Among Thieves (2023). | **Medium** |
| Xenk | Hall of Fame seed party | **Paramount / Hasbro** -- from D&D: Honour Among Thieves (2023). | **Medium** |
| Rincewind | Hall of Fame seed party | **Terry Pratchett Estate / Narrativia** -- Discworld character. | **Medium** |
| DEATH | Hall of Fame seed party | **Terry Pratchett Estate / Narrativia** -- as a named Discworld character (context makes this clear). The word itself is generic. | **Medium** |
| Ripley | Hall of Fame seed party | **20th Century Studios / Disney** -- Ellen Ripley from Alien. The surname alone is generic but used in sci-fi context. | Low |
| Atreides | Hall of Fame seed party | **Frank Herbert Estate / Legendary** -- from Dune. House name is distinctive. | **Medium** |
| Snake Plissken | Hall of Fame seed party | **StudioCanal** -- from Escape from New York (1981). Very distinctive name. | **Medium** |
| Top Cat | Hall of Fame seed party | **Hanna-Barbera / Warner Bros** -- cartoon character. | **Medium** |
| Danger Mouse | Hall of Fame seed party | **Cosgrove Hall / CBBC** -- cartoon character. | **Medium** |
| Penelope Pitstop | Hall of Fame seed party | **Hanna-Barbera / Warner Bros** -- cartoon character. | **Medium** |
| Daneel | Hall of Fame seed party | **Isaac Asimov Estate** -- R. Daneel Olivaw from the Robot/Foundation series. Distinctive name. | **Medium** |
| K-9 | Hall of Fame seed party | **BBC** -- Doctor Who character. | **Medium** |
| Marvin | Hall of Fame seed party | **Douglas Adams Estate** -- the Paranoid Android from Hitchhiker's Guide. Name alone is generic but used in robot context. | Low |
| Eddie Munson | Hall of Fame seed party | **Netflix** -- Stranger Things character. Full character name. | **Medium** |
| Will the Wise | Hall of Fame seed party | **Netflix** -- Stranger Things character's D&D name. | **Medium** |
| Eleven | Hall of Fame seed party | **Netflix** -- Stranger Things character. Distinctive in this context. | **Medium** |
| Doct Carter | Hall of Fame seed party | **Edgar Rice Burroughs Inc** -- John Carter of Mars (name slightly altered). Public domain as of 2007 (US). | Low |
| Conan | Hall of Fame seed party | **Conan Properties International** -- actively trademarked. The character name "Conan" in a barbarian context is distinctive. | **HIGH** |
| Athos, Porthos, Aramis, D'Artagnan | Hall of Fame seed party | **Alexandre Dumas** -- public domain (1844). | Low |

### Dungeon/Location Names in Hall of Fame

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Moria | Hall of Fame seed data, dungeonNames array | **Tolkien Estate / Middle-earth Enterprises**. Trademarked location. | **HIGH** |
| Ravenloft | Hall of Fame seed data, dungeonNames array | **WotC Product Identity** -- trademarked D&D setting/adventure name. | **HIGH** |
| Tomb of Horrors | Hall of Fame seed data, dungeonNames array | **WotC Product Identity** -- trademarked D&D adventure name. | **HIGH** |
| Ankh-Morpork | Hall of Fame seed data, dungeonNames array | **Terry Pratchett Estate / Narrativia** -- Discworld location. Very distinctive. | **Medium** |
| Trantor | Hall of Fame seed data, dungeonNames array | **Isaac Asimov Estate** -- Foundation series. Distinctive fictional location. | **Medium** |
| Nostromo | Hall of Fame seed data, dungeonNames array | **20th Century Studios / Disney** -- from Alien (1979). Ship name from the film. | **Medium** |
| The Labyrinth | Hall of Fame seed data, dungeonNames array | Generic term. Also a 1986 Jim Henson film but the name itself is not trademarkable. | Low |
| Caves of Chaos | Hall of Fame seed data, dungeonNames array | **WotC Product Identity** -- D&D adventure name. | **HIGH** |
| The Scarlet Citadel | Hall of Fame seed data, dungeonNames array | **Conan Properties International** -- Robert E. Howard story title. Public domain (1933). | Low |
| The Iron Tower | Hall of Fame seed data, dungeonNames array | Generic fantasy name. Also a Dennis McKiernan book but name is too generic to protect. | Low |

---

## 3. Suggested Names (GameEngine.swift, suggestedNames array)

These names appear as character name suggestions the player can pick from.

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Will the Wise | suggestedNames | **Netflix** -- Stranger Things. | **Medium** |
| Eleven | suggestedNames | **Netflix** -- Stranger Things. | **Medium** |
| Eddie Munson | suggestedNames | **Netflix** -- Stranger Things. Full name. | **Medium** |
| Hopper | suggestedNames | **Netflix** -- Stranger Things. Surname is generic. | Low |
| Hector the Well-Endowed | suggestedNames | **NBC/Sony** -- Community TV show D&D episode. Distinctive full title. | **Medium** |
| Brutalitops | suggestedNames | **NBC/Sony** -- Community TV show. Invented name. | **Medium** |
| Titanius | suggestedNames | **20th Century Studios / Disney** -- Futurama. Invented name. | Low |
| Leegola | suggestedNames | **20th Century Studios / Disney** -- Futurama. Invented name. | Low |
| Frydo | suggestedNames | **20th Century Studios / Disney** -- Futurama. Obvious reference. | Low |
| Sheldon | suggestedNames | Generic first name. Big Bang Theory reference but name is common. | Low |
| Daniel Desario | suggestedNames | **NBC/DreamWorks** -- Freaks and Geeks. Full character name. | Low |
| Carlos the Dwarf | suggestedNames | **NBC/DreamWorks** -- Freaks and Geeks D&D character. | Low |
| Edgin, Holga, Doric, Xenk, Simon | suggestedNames | **Paramount / Hasbro** -- Honour Among Thieves characters. | **Medium** |
| Deckard | suggestedNames | **Warner Bros** -- Blade Runner. Distinctive surname. | Low |
| Ripley | suggestedNames | **Disney** -- Alien. Generic surname. | Low |
| Atreides | suggestedNames | **Frank Herbert Estate / Legendary** -- Dune. | **Medium** |
| Stilgar, Chani | suggestedNames | **Frank Herbert Estate / Legendary** -- Dune characters. Distinctive names. | **Medium** |
| Bowman, HAL, Poole | suggestedNames | **Arthur C. Clarke Estate / MGM** -- 2001: A Space Odyssey. HAL is distinctive. | **Medium** (HAL), Low (others) |
| Case, Molly, Wintermute | suggestedNames | **William Gibson** -- Neuromancer. Wintermute is distinctive. | **Medium** |
| Ender, Valentine, Bean | suggestedNames | **Orson Scott Card** -- Ender's Game. Common names but distinctive in context. | Low |
| Zaphod, Trillian, Slartibartfast | suggestedNames | **Douglas Adams Estate** -- Hitchhiker's Guide. Very distinctive invented names. | **Medium** |
| Kal-El | suggestedNames | **DC Comics / Warner Bros** -- Superman's birth name. Trademarked. | **HIGH** |
| Logan 5 | suggestedNames | **MGM** -- Logan's Run. Distinctive. | Low |
| Korben | suggestedNames | **Gaumont / EuropaCorp** -- The Fifth Element. | Low |
| Snake Plissken | suggestedNames | **StudioCanal** -- Escape from New York. Very distinctive. | **Medium** |
| Riddick | suggestedNames | **Universal / Vin Diesel** -- trademarked character. | **Medium** |
| Neo, Morpheus, Trinity | suggestedNames | **Warner Bros** -- The Matrix. Neo and Morpheus are distinctive in context. | **Medium** |
| C-3PO, R2-D2 | suggestedNames | **Lucasfilm / Disney** -- Star Wars. Trademarked character names. | **HIGH** |
| Roy Batty, Pris, Rachael | suggestedNames | **Warner Bros** -- Blade Runner replicant names. | **Medium** |
| Daneel, Giskard | suggestedNames | **Isaac Asimov Estate** -- Robot series. Distinctive names. | **Medium** |
| Marvin | suggestedNames | Generic name; Douglas Adams reference in context. | Low |
| Kryten | suggestedNames | **BBC / Grant Naylor** -- Red Dwarf. Distinctive. | **Medium** |
| K-9, Kamelion | suggestedNames | **BBC** -- Doctor Who characters. | **Medium** |
| Twiki, Crichton | suggestedNames | **NBCUniversal** -- Buck Rogers. | Low |
| Maximilian, V.I.N.CENT | suggestedNames | **Disney** -- The Black Hole. V.I.N.CENT is distinctive. | **Medium** |
| Gort | suggestedNames | **20th Century Studios** -- The Day the Earth Stood Still. Iconic but old film (1951). | Low |
| Johnny Five | suggestedNames | **TriStar / Sony** -- Short Circuit. Distinctive. | **Medium** |
| Metal Mickey | suggestedNames | **ITV** -- UK TV show character. | Low |
| Mechagodzilla | suggestedNames | **Toho Co.** -- trademarked. | **HIGH** |
| Maria, Maschinenmensch | suggestedNames | **UFA / public domain** -- Metropolis (1927). Public domain in most territories. | Low |
| Captain Nemo | suggestedNames | **Jules Verne** -- public domain (1870). | Low |
| Phileas Fogg, Passepartout | suggestedNames | **Jules Verne** -- public domain (1873). | Low |
| Dr. Moreau | suggestedNames | **H.G. Wells** -- public domain (1896). | Low |
| Sherlock, Doct Watson | suggestedNames | **Arthur Conan Doyle Estate** -- mostly public domain (post-2023 all stories are PD in US). | Low |
| Professor Challenger | suggestedNames | **Arthur Conan Doyle** -- public domain. | Low |
| Van Helsing | suggestedNames | **Bram Stoker** -- public domain (1897). | Low |
| Dr. Frankenstein, Dr. Jekyll | suggestedNames | Public domain (Shelley 1818, Stevenson 1886). | Low |
| Dejah Thoris, Tars Tarkas | suggestedNames | **Edgar Rice Burroughs** -- public domain in US (1912/1917). | Low |
| Odysseus, Achilles, Penelope, Circe | suggestedNames | Greek mythology -- public domain. | Low |
| Sigurd, Brynhild, Volund | suggestedNames | Norse mythology -- public domain. | Low |
| Athos, Porthos, Aramis, D'Artagnan | suggestedNames | **Alexandre Dumas** -- public domain (1844). | Low |
| Valjean, Javert, Quasimodo, Esmeralda | suggestedNames | **Victor Hugo** -- public domain (1862/1831). | Low |
| Gulliver | suggestedNames | **Jonathan Swift** -- public domain (1726). | Low |

---

## 4. Name Gallery Entries (GameEngine.swift, nameEntries array)

These appear in the NPC Gallery / character card browser with descriptions, ASCII art, and stats.

### Heroes

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Flash Gordon | nameEntries | **King Features Syndicate** -- actively licensed character. | **HIGH** |
| Buck Rogers | nameEntries | **The Dille Family Trust** -- actively trademarked. | **HIGH** |
| Dan Dare | nameEntries | **Dan Dare Corporation / Zephyr** -- trademarked UK character. | **Medium** |
| Prince Valiant | nameEntries (implied by comic source) | **King Features Syndicate** -- trademarked. | **Medium** |
| The Phantom | nameEntries (implied by comic source) | **King Features Syndicate** -- trademarked. | **Medium** |
| Judge Dredd | nameEntries (implied by comic source) | **Rebellion Developments** -- trademarked. | **Medium** |
| Will the Wise | nameEntries | **Netflix** -- Stranger Things. | **Medium** |
| Eleven | nameEntries | **Netflix** -- Stranger Things. | **Medium** |
| Eddie Munson | nameEntries | **Netflix** -- Stranger Things. | **Medium** |
| Hopper | nameEntries | **Netflix** -- Stranger Things. Generic surname. | Low |
| Steve | nameEntries | **Netflix** -- Stranger Things. Generic name. | Low |
| Hector the Well-Endowed | nameEntries | **NBC/Sony** -- Community. | **Medium** |
| Brutalitops | nameEntries | **NBC/Sony** -- Community. | **Medium** |
| Titanius | nameEntries | **Disney** -- Futurama. | Low |
| Leegola | nameEntries | **Disney** -- Futurama. | Low |
| Edgin | nameEntries | **Paramount / Hasbro** -- Honour Among Thieves. | **Medium** |
| Holga | nameEntries | **Paramount / Hasbro** -- Honour Among Thieves. | **Medium** |
| Xenk | nameEntries | **Paramount / Hasbro** -- Honour Among Thieves. | **Medium** |
| Ripley | nameEntries | **Disney** -- Alien. | Low |
| Deckard | nameEntries | **Warner Bros** -- Blade Runner. | Low |
| Atreides | nameEntries | **Herbert Estate / Legendary** -- Dune. | **Medium** |
| Snake Plissken | nameEntries | **StudioCanal** -- Escape from New York. | **Medium** |
| Daneel | nameEntries | **Asimov Estate** -- Robot series. | **Medium** |
| Marvin | nameEntries | **Douglas Adams Estate** -- Hitchhiker's Guide. | Low |
| K-9 | nameEntries | **BBC** -- Doctor Who. | **Medium** |
| Roy Batty | nameEntries | **Warner Bros** -- Blade Runner. | **Medium** |
| Madmartigan | nameEntries | **Lucasfilm / Disney** -- Willow. | **HIGH** |
| Willow (Ufgood) | nameEntries | **Lucasfilm / Disney** -- Willow. | **Medium** |
| Atreyu | nameEntries | **Constantin Film** -- The NeverEnding Story. | **Medium** |
| Conan | nameEntries (appears twice: film & book) | **Conan Properties International** -- actively trademarked. | **HIGH** |
| Connor MacLeod | nameEntries | **StudioCanal** -- Highlander. | **Medium** |
| Jareth | nameEntries | **Jim Henson Company / Sony** -- Labyrinth. | **Medium** |
| Darkness | nameEntries | **Universal** -- Legend (1985). Generic word but specific character. | Low |
| Taran | nameEntries | **Disney** (animated film) / **Lloyd Alexander Estate** (books). | Low |
| Hawk | nameEntries | **Warner Bros** -- Ladyhawke. Generic name. | Low |
| Red Sonja | nameEntries | **Red Sonja LLC / Dynamite** -- actively trademarked. | **HIGH** |
| Beast Master | nameEntries | **MGM** -- The Beastmaster. | Low |
| Valerian | nameEntries | Generic name; used for Dragonslayer character. | Low |
| Elric | nameEntries | **Michael Moorcock** -- copyrighted character. Actively managed. | **Medium** |
| Ged | nameEntries | **Le Guin Estate** -- Earthsea. | **Medium** |
| Drizzt | nameEntries (+ description references) | **WotC / Hasbro Product Identity** -- Drizzt Do'Urden is explicitly trademarked. Also mentions Menzoberranzan, Twinkle, Icingdeath, Guenhwyvar. | **HIGH** |
| Raistlin | nameEntries | **WotC / Hasbro Product Identity** -- Dragonlance character. Trademarked. | **HIGH** |
| Tasslehoff | nameEntries | **WotC / Hasbro Product Identity** -- Dragonlance character. Trademarked. | **HIGH** |
| Rincewind | nameEntries | **Pratchett Estate / Narrativia** -- Discworld. | **Medium** |
| Granny Weatherwax | nameEntries | **Pratchett Estate / Narrativia** -- Discworld. | **Medium** |
| Belgarion | nameEntries | **David Eddings Estate** -- The Belgariad. | **Medium** |
| Fafhrd | nameEntries | **Fritz Leiber Estate** -- Fafhrd and Grey Mouser. | **Medium** |
| Grey Mouser | nameEntries | **Fritz Leiber Estate** -- Fafhrd and Grey Mouser. | **Medium** |
| Thomas Covenant | nameEntries | **Stephen Donaldson** -- The Chronicles of Thomas Covenant. | **Medium** |
| Tenar | nameEntries | **Le Guin Estate** -- Earthsea. | **Medium** |
| John Carter | nameEntries | **ERB Inc** -- public domain in US (1912). | Low |
| Aragorn | nameEntries | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| DEATH | nameEntries | **Pratchett Estate** -- Discworld character. | **Medium** |
| Corwin | nameEntries | **Roger Zelazny Estate** -- Chronicles of Amber. | **Medium** |
| Corum | nameEntries | **Michael Moorcock** -- Eternal Champion. | **Medium** |
| Sauron | nameEntries | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| He-Man | nameEntries | **Mattel** -- actively trademarked. | **HIGH** |
| Skeletor | nameEntries | **Mattel** -- actively trademarked. | **HIGH** |
| Ming the Merciless | nameEntries | **King Features Syndicate** -- trademarked. | **HIGH** |
| Lion-O | nameEntries | **Warner Bros** -- ThunderCats. Trademarked. | **HIGH** |
| Noggin (the Nog) | nameEntries | **Smallfilms / Oliver Postgate Estate** -- UK TV. | Low |
| Nogbad the Bad | nameEntries | **Smallfilms / Oliver Postgate Estate** -- UK TV. | Low |
| The Doctor | nameEntries | **BBC** -- Doctor Who. The title is generic but context is specific. | **Medium** |
| Davros | nameEntries | **BBC** -- Doctor Who villain. | **Medium** |
| Avon | nameEntries | **BBC** -- Blake's 7. Generic name but specific reference. | Low |
| Ulysses (31) | nameEntries | **DIC Entertainment / TMS** -- Ulysses 31. Name from mythology, show context. | Low |
| Esteban | nameEntries | **DIC Entertainment / NHK** -- Mysterious Cities of Gold. Generic name. | Low |
| Robin of Loxley | nameEntries | Public domain (Robin Hood). | Low |
| Dogtanian | nameEntries | **BRB Internacional** -- Dogtanian and the Three Muskehounds. | Low |
| Top Cat | nameEntries | **Hanna-Barbera / Warner Bros** -- trademarked cartoon. | **Medium** |
| Benny the Ball | nameEntries | **Hanna-Barbera / Warner Bros** -- Top Cat character. | **Medium** |
| Officer Dibble | nameEntries | **Hanna-Barbera / Warner Bros** -- Top Cat character. | **Medium** |
| Choo-Choo | nameEntries | **Hanna-Barbera / Warner Bros** -- Top Cat character. | Low |
| Dick Dastardly | nameEntries | **Hanna-Barbera / Warner Bros** -- Wacky Races. | **Medium** |
| Muttley | nameEntries | **Hanna-Barbera / Warner Bros** -- Wacky Races. | **Medium** |
| Penelope Pitstop | nameEntries | **Hanna-Barbera / Warner Bros** -- Wacky Races. | **Medium** |
| Wile E. Coyote | nameEntries | **Warner Bros** -- Looney Tunes. Trademarked. | **HIGH** |
| Road Runner | nameEntries | **Warner Bros** -- Looney Tunes. Trademarked. | **HIGH** |
| Danger Mouse | nameEntries | **FremantleMedia / CBBC** -- trademarked. | **Medium** |
| Penfold | nameEntries | **FremantleMedia / CBBC** -- Danger Mouse character. | **Medium** |
| Pinky | nameEntries | **Warner Bros** -- Pinky and the Brain. | **Medium** |
| The Brain | nameEntries | **Warner Bros** -- Pinky and the Brain. | **Medium** |
| Peter Perfect | nameEntries | **Hanna-Barbera / Warner Bros** -- Wacky Races. | **Medium** |
| Professor Pat P. | nameEntries | **Hanna-Barbera / Warner Bros** -- Wacky Races. | Low |
| Gosseyn | nameEntries | **A.E. van Vogt Estate** -- The World of Null-A. | Low |
| Ted Benteley | nameEntries | **Philip K. Dick Estate** -- Solar Lottery. | Low |
| Floyd Jones | nameEntries | **Philip K. Dick Estate** -- The World Jones Made. | Low |
| Dr Parsons | nameEntries | **Philip K. Dick Estate** -- Dr. Futurity. Generic name. | Low |
| Donal Graeme | nameEntries | **Gordon R. Dickson Estate** -- Dorsai. | Low |
| Dosvard Rhyn | nameEntries | **Andre Norton Estate** -- Star Rangers. | Low |
| Nine Lives | nameEntries | **Harlan Ellison Estate**. Generic title. | Low |

### Dungeon/Location Name Entries

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Moria | nameEntries, dungeonNames | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Barad-dur | nameEntries, dungeonNames | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Cirith Ungol | nameEntries, dungeonNames | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Isengard | nameEntries, dungeonNames | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Mount Doom | nameEntries, dungeonNames | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Minas Morgul | nameEntries | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Dol Guldur | nameEntries, dungeonNames | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Helm's Deep | nameEntries | **Tolkien Estate / Middle-earth Enterprises** -- trademarked. | **HIGH** |
| Shelob's Lair | dungeonNames | **Tolkien Estate** -- trademarked character name Shelob. | **HIGH** |
| Paths of the Dead | dungeonNames | **Tolkien Estate** -- distinctive LotR location. | **HIGH** |
| Tomb of Horrors | nameEntries, dungeonNames | **WotC Product Identity** -- trademarked adventure title. | **HIGH** |
| Ravenloft | nameEntries, dungeonNames | **WotC Product Identity** -- trademarked D&D setting. | **HIGH** |
| White Plume Mountain | nameEntries, dungeonNames | **WotC Product Identity** -- trademarked adventure title. | **HIGH** |
| Caves of Chaos | nameEntries, dungeonNames | **WotC Product Identity** -- from Keep on the Borderlands. | **HIGH** |
| Barrier Peaks | nameEntries, dungeonNames | **WotC Product Identity** -- trademarked adventure. | **HIGH** |
| Temple of Elemental Evil | nameEntries, dungeonNames | **WotC Product Identity** -- trademarked adventure/setting. | **HIGH** |
| Castle Amber | dungeonNames | **WotC Product Identity** -- D&D module name. | **HIGH** |
| Vault of the Drow | dungeonNames | **WotC Product Identity** -- D&D module name. Also "Drow" may be Product Identity. | **HIGH** |
| Steading of the Hill Giant Chief | dungeonNames | **WotC Product Identity** -- D&D module name. | **HIGH** |
| Keep on the Borderlands | dungeonNames | **WotC Product Identity** -- trademarked adventure title. | **HIGH** |
| Isle of Dread | nameEntries | **WotC Product Identity** -- D&D module name. | **HIGH** |
| The Sunless Citadel | dungeonNames | **WotC Product Identity** -- D&D adventure title (3e era). | **HIGH** |
| Blackmoor Dungeon | dungeonNames | **WotC / Arneson Estate** -- Blackmoor is a trademarked D&D setting. | **HIGH** |
| Melnibone | nameEntries, dungeonNames | **Michael Moorcock** -- copyrighted fictional location. | **Medium** |
| Tanelorn | nameEntries, dungeonNames | **Michael Moorcock** -- copyrighted fictional location. | **Medium** |
| Lankhmar | nameEntries | **Fritz Leiber Estate** -- copyrighted fictional city. | **Medium** |
| Ankh-Morpork | nameEntries, dungeonNames | **Pratchett Estate / Narrativia** -- Discworld. Very distinctive. | **Medium** |
| Gormenghast | nameEntries | **Mervyn Peake Estate** -- copyrighted. | **Medium** |
| Cimmeria | nameEntries | **Conan Properties / Robert E. Howard** -- Conan's homeland. | **Medium** |
| Barsoom | nameEntries | **ERB Inc** -- public domain in US. | Low |
| Tombs of Atuan | nameEntries, dungeonNames | **Le Guin Estate** -- Earthsea. | **Medium** |
| Roke | nameEntries | **Le Guin Estate** -- Earthsea. | **Medium** |
| The Dry Land | nameEntries | **Le Guin Estate** -- Earthsea. | **Medium** |
| Selidor | nameEntries | **Le Guin Estate** -- Earthsea. | **Medium** |
| Havnor | nameEntries | **Le Guin Estate** -- Earthsea. | **Medium** |
| Nostromo | nameEntries, dungeonNames | **20th Century Studios / Disney** -- Alien. | **Medium** |
| Trantor | nameEntries, dungeonNames | **Asimov Estate** -- Foundation. | **Medium** |
| Castle Greyskull | nameEntries | **Mattel** -- He-Man. Trademarked. | **HIGH** |
| The Labyrinth | nameEntries, dungeonNames | Generic word; Jim Henson film context in nameEntry. | Low |
| Fantasia | nameEntries | **Constantin Film** -- The NeverEnding Story. Also generic word. | Low |
| Snake Mountain | nameEntries | **Mattel** -- He-Man. Trademarked. | **HIGH** |
| Death Star | nameEntries | **Lucasfilm / Disney** -- Star Wars. Trademarked. | **HIGH** |
| Skull Island | nameEntries | **Legendary / Warner Bros** -- King Kong franchise. Trademarked. | **Medium** |
| Krell Laboratory | nameEntries | **MGM** -- Forbidden Planet (1956). | Low |
| Quarmall | dungeonNames | **Fritz Leiber Estate** -- Fafhrd & Grey Mouser. | Low |
| Thieves' House | dungeonNames | **Fritz Leiber Estate**. | Low |
| Stardock | dungeonNames | **Fritz Leiber Estate**. | Low |
| Tower of the Elephant | dungeonNames | **Conan Properties** -- Robert E. Howard story. | **Medium** |
| Scarlet Citadel | dungeonNames | **Conan Properties** -- Robert E. Howard story. Public domain. | Low |
| Chasm of the Old | dungeonNames | **Jack Vance Estate** -- Dying Earth. | Low |
| Ampridatvir | dungeonNames | **Jack Vance Estate** -- Dying Earth. | Low |
| Arrakeen, Sietch Tabr | dungeonNames | **Herbert Estate / Legendary** -- Dune. | **Medium** |
| Solaris Station | dungeonNames | **Stanislaw Lem Estate** -- Solaris. | Low |
| Rama | dungeonNames | **Arthur C. Clarke Estate** -- Rendezvous with Rama. | Low |
| Acheron | dungeonNames | **20th Century Studios** -- Aliens. Also mythological. | Low |
| Tyrell Pyramid, Sector 6 | dungeonNames | **Warner Bros** -- Blade Runner. | Low |
| Erewhon | dungeonNames | **Samuel Butler** -- public domain (1872). | Low |
| The Nautilus | dungeonNames | **Jules Verne** -- public domain (1870). | Low |
| Laputa, Brobdingnag, Lilliput | dungeonNames | **Jonathan Swift** -- public domain (1726). | Low |
| The Inferno, Malebolge | dungeonNames | **Dante** -- public domain (1320). | Low |
| Circe's Isle, The Cyclops Cave | dungeonNames | **Homer** -- public domain (ancient). | Low |
| Niflheim, Muspelheim, Helheim | dungeonNames | Norse mythology -- public domain. | Low |
| Gateway | nameEntries | **Murray Leinster / Estate**. Generic word. | Low |
| Isher | nameEntries | **A.E. van Vogt Estate**. | Low |
| Big Planet | nameEntries | **Jack Vance Estate**. Generic phrase. | Low |
| Millgate | nameEntries | **Philip K. Dick Estate**. Generic name. | Low |
| The Big Time | nameEntries | **Fritz Leiber Estate**. | Low |
| The Island of Dr. Moreau | dungeonNames | **H.G. Wells** -- public domain (1896). | Low |
| The Time Machine | dungeonNames | **H.G. Wells** -- public domain (1895). | Low |

---

## 5. In-Game Text References (GameEngine.swift)

| Name | Where Found | Source/Concern | Risk Level |
|------|-------------|----------------|------------|
| Drizzt | Description text, stat calibration examples (lines 2925, 4264) | **WotC Product Identity** -- trademarked character name used as a reference/calibration point. | **HIGH** |
| Conan | Description text, stat calibration examples (lines 2922, 4255) | **Conan Properties International** -- trademarked name used as reference. | **Medium** |
| Granny Weatherwax | Stat calibration example (line 2923) | **Pratchett Estate** -- used as a reference point. | Low |
| Rincewind | Stat calibration example (line 4255) | **Pratchett Estate** -- used as a reference point. | Low |
| Hogwarts | nameEntries description for Roke: "Hogwarts wishes it were Roke" | **Warner Bros / J.K. Rowling** -- trademarked. Passing reference in text. | Low |
| Red Wizards of Thay | nameEntries description for Edgin | **WotC Product Identity** -- Forgotten Realms setting element. | **Medium** |
| Menzoberranzan | nameEntries description for Drizzt | **WotC Product Identity** -- Forgotten Realms location. | **HIGH** |
| Twinkle, Icingdeath, Guenhwyvar | nameEntries description for Drizzt | **WotC Product Identity** -- Drizzt's weapons and companion. | **HIGH** |

---

## 6. Spells (SpellModels.swift)

All spells used are from the D&D 5e SRD: Fire Bolt, Ray of Frost, Shocking Grasp, Magic Missile, Burning Hands, Sleep, Sacred Flame, Toll the Dead, Spare the Dying, Cure Wounds, Guiding Bolt, Healing Word, Hunter's Mark. **All Low risk -- SRD content.**

---

## 7. Items (ItemModels.swift)

All items are generic D&D SRD equipment: Longsword, Shortsword, Greataxe, Longbow, Dagger, Quarterstaff, Mace, Rapier, Handaxe, Leather Armour, Chain Mail, Scale Mail, Studded Leather, Shield, Potion of Healing, Potion of Greater Healing, Antidote, Torch, Rope, Spell Component Pouch, Holy Symbol, Thieves' Tools. **All Low risk -- SRD content or generic items.**

---

## 8. Races & Classes (CharacterModels.swift)

All races and classes are from the D&D 5e SRD: Human, High Elf, Wood Elf, Hill Dwarf, Mountain Dwarf, Lightfoot Halfling, Stout Halfling, Half-Elf, Half-Orc, Rock Gnome, Tiefling, Dragonborn, Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian. **All Low risk -- SRD content.**

Note: "Halfling" was originally Tolkien's "Hobbit" (which IS trademarked), but WotC's "Halfling" is SRD and safe.

---

## 9. NPC Types (NPCModels.swift)

All NPC types are generic fantasy archetypes: Wandering Trader, Prisoner, Hermit, Ghostly Scholar, Dwarven Smith, Elf Scout, Goblin Defector, Mysterious Stranger, Wounded Knight, Mad Alchemist, Old Priestess, Rat Catcher, Gatekeeper. **All Low risk.**

---

## Summary of HIGH Risk Items Requiring Immediate Action

### WotC Product Identity Monsters (must rename or remove):
1. **Beholder** -- rename to e.g. "Eye Tyrant", "Gazer Lord", "Orb of Many Eyes"
2. **Mind Flayer** -- rename to e.g. "Brain Eater", "Psionic Horror", "Tentacle Fiend"
3. **Displacer Beast** -- rename to e.g. "Phase Stalker", "Shifting Panther", "Shadow Cat"
4. **Vecna** -- rename to e.g. "The Undying King", "The Lich Lord", "The Deathless One"
5. **Demogorgon** -- rename to e.g. "The Two-Headed Horror", "The Abyssal Prince", "The Maw"

### WotC Product Identity Dungeon Names (must rename or remove):
6. **Tomb of Horrors** -- rename
7. **Ravenloft** -- rename
8. **White Plume Mountain** -- rename
9. **Caves of Chaos** -- rename
10. **Barrier Peaks** -- rename
11. **Temple of Elemental Evil** -- rename
12. **Castle Amber** -- rename
13. **Vault of the Drow** -- rename (also "Drow" itself may be PI)
14. **Steading of the Hill Giant Chief** -- rename
15. **Keep on the Borderlands** -- rename
16. **Isle of Dread** -- rename
17. **The Sunless Citadel** -- rename
18. **Blackmoor Dungeon** -- rename

### WotC Product Identity Characters/References:
19. **Drizzt** (nameEntries + text references, including Menzoberranzan, Twinkle, Icingdeath, Guenhwyvar)
20. **Raistlin** (nameEntries) -- Dragonlance
21. **Tasslehoff** (nameEntries) -- Dragonlance

### Tolkien Estate (Middle-earth Enterprises actively enforces):
22. **Aragorn** (nameEntries + Hall of Fame)
23. **Sauron** (nameEntries)
24. **Moria** (dungeonNames + Hall of Fame)
25. **Barad-dur** (nameEntries + dungeonNames)
26. **Cirith Ungol** (nameEntries + dungeonNames)
27. **Isengard** (nameEntries + dungeonNames)
28. **Mount Doom** (nameEntries + dungeonNames)
29. **Minas Morgul** (nameEntries)
30. **Dol Guldur** (nameEntries + dungeonNames)
31. **Helm's Deep** (nameEntries)
32. **Shelob's Lair** (dungeonNames)
33. **Paths of the Dead** (dungeonNames)

### Other Actively Trademarked:
34. **C-3PO, R2-D2** (suggestedNames) -- Lucasfilm/Disney Star Wars
35. **Death Star** (nameEntries) -- Lucasfilm/Disney Star Wars
36. **Kal-El** (suggestedNames) -- DC Comics Superman
37. **He-Man, Skeletor** (nameEntries) -- Mattel
38. **Castle Greyskull, Snake Mountain** (nameEntries) -- Mattel
39. **Lion-O** (nameEntries) -- Warner Bros ThunderCats
40. **Flash Gordon** (nameEntries) -- King Features Syndicate
41. **Buck Rogers** (nameEntries) -- Dille Family Trust
42. **Ming the Merciless** (nameEntries) -- King Features Syndicate
43. **Wile E. Coyote, Road Runner** (nameEntries) -- Warner Bros Looney Tunes
44. **Madmartigan** (nameEntries + Hall of Fame) -- Lucasfilm/Disney Willow
45. **Conan** (nameEntries + Hall of Fame) -- Conan Properties International
46. **Red Sonja** (nameEntries + Hall of Fame) -- Red Sonja LLC
47. **Mechagodzilla** (suggestedNames) -- Toho Co.

---

## Recommendations

1. **Immediate**: Rename the 5 WotC Product Identity monsters. These are the highest legal risk since WotC actively enforces these trademarks and the monsters are core gameplay elements, not just references.

2. **Immediate**: Remove or rename all WotC Product Identity dungeon names (Tomb of Horrors, Ravenloft, etc.) and character names (Drizzt, Raistlin, Tasslehoff).

3. **High Priority**: Remove or rename all Tolkien Estate names. Middle-earth Enterprises (now owned by Embracer Group) actively enforces trademarks on all LotR names.

4. **High Priority**: Remove Star Wars (C-3PO, R2-D2, Death Star), DC (Kal-El), Mattel (He-Man, Skeletor, Castle Greyskull), Warner Bros (Lion-O, Wile E. Coyote, Road Runner), and other actively trademarked character names.

5. **Medium Priority**: Review all Medium-risk names. Many of these (Pratchett, Le Guin, Moorcock, Leiber, Adams characters) are copyrighted but used in a homage/reference context. The legal risk is lower but not zero, especially for names used as playable character suggestions rather than just cultural references.

6. **Low Priority**: Public domain names (Dumas, Verne, Wells, mythology) and generic SRD content are fine to keep.
