"""NPC generation and dialogue for D&D 5e."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from enum import Enum
import random
import uuid


class NPCAttitude(Enum):
    """NPC attitude toward players."""
    HOSTILE = "Hostile"
    UNFRIENDLY = "Unfriendly"
    INDIFFERENT = "Indifferent"
    FRIENDLY = "Friendly"
    HELPFUL = "Helpful"


class NPCRole(Enum):
    """Common NPC roles."""
    MERCHANT = "Merchant"
    GUARD = "Guard"
    INNKEEPER = "Innkeeper"
    BLACKSMITH = "Blacksmith"
    PRIEST = "Priest"
    NOBLE = "Noble"
    PEASANT = "Peasant"
    BEGGAR = "Beggar"
    SCHOLAR = "Scholar"
    ADVENTURER = "Adventurer"
    CRIMINAL = "Criminal"
    QUEST_GIVER = "Quest Giver"


@dataclass
class DialogueLine:
    """A line of NPC dialogue."""
    text: str
    condition: Optional[str] = None  # Condition for this line to appear
    responses: List['DialogueResponse'] = field(default_factory=list)


@dataclass
class DialogueResponse:
    """A player response option."""
    text: str
    next_dialogue: Optional[str] = None  # Key to next dialogue
    effect: Optional[str] = None  # Effect of choosing this response


@dataclass
class Quest:
    """A quest that can be given by an NPC."""
    id: str
    name: str
    description: str
    objectives: List[str]
    reward_gold: int = 0
    reward_xp: int = 0
    reward_items: List[str] = field(default_factory=list)
    completed: bool = False


@dataclass
class NPC:
    """A non-player character."""
    id: str
    name: str
    role: NPCRole
    race: str
    description: str
    attitude: NPCAttitude = NPCAttitude.INDIFFERENT

    # Dialogue
    greeting: str = ""
    dialogue_tree: Dict[str, DialogueLine] = field(default_factory=dict)

    # Merchant inventory (if applicable)
    inventory: List[str] = field(default_factory=list)
    gold: int = 0

    # Quest (if applicable)
    quest: Optional[Quest] = None

    # Personality traits
    traits: List[str] = field(default_factory=list)
    ideals: str = ""
    bonds: str = ""
    flaws: str = ""

    def get_greeting(self) -> str:
        """Get appropriate greeting based on attitude."""
        if self.greeting:
            return self.greeting

        greetings = {
            NPCAttitude.HOSTILE: [
                "What do you want?",
                "Get out of my sight!",
                "You've got some nerve showing your face here.",
            ],
            NPCAttitude.UNFRIENDLY: [
                "Make it quick.",
                "I don't have time for this.",
                "*sigh* What is it?",
            ],
            NPCAttitude.INDIFFERENT: [
                "Can I help you?",
                "Yes?",
                "What brings you here?",
            ],
            NPCAttitude.FRIENDLY: [
                "Well met, traveler!",
                "Good to see you!",
                "Welcome, friend!",
            ],
            NPCAttitude.HELPFUL: [
                "Ah, perfect timing! I was hoping to see you.",
                "My friend! How can I assist you?",
                "Welcome! I have something that might interest you.",
            ],
        }

        return random.choice(greetings.get(self.attitude, ["Hello."]))

    def get_dialogue(self, key: str = "start") -> Optional[DialogueLine]:
        """Get a dialogue line by key."""
        return self.dialogue_tree.get(key)

    def improve_attitude(self) -> bool:
        """Try to improve NPC attitude. Returns True if improved."""
        attitude_order = [
            NPCAttitude.HOSTILE,
            NPCAttitude.UNFRIENDLY,
            NPCAttitude.INDIFFERENT,
            NPCAttitude.FRIENDLY,
            NPCAttitude.HELPFUL,
        ]

        current_index = attitude_order.index(self.attitude)
        if current_index < len(attitude_order) - 1:
            self.attitude = attitude_order[current_index + 1]
            return True
        return False

    def worsen_attitude(self) -> bool:
        """Worsen NPC attitude. Returns True if worsened."""
        attitude_order = [
            NPCAttitude.HOSTILE,
            NPCAttitude.UNFRIENDLY,
            NPCAttitude.INDIFFERENT,
            NPCAttitude.FRIENDLY,
            NPCAttitude.HELPFUL,
        ]

        current_index = attitude_order.index(self.attitude)
        if current_index > 0:
            self.attitude = attitude_order[current_index - 1]
            return True
        return False

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'id': self.id,
            'name': self.name,
            'role': self.role.value,
            'race': self.race,
            'description': self.description,
            'attitude': self.attitude.value,
            'inventory': self.inventory,
            'gold': self.gold,
        }


# Name generators
FIRST_NAMES = {
    "human": {
        "male": ["Aldric", "Bram", "Cedric", "Dorian", "Edmund", "Finn", "Gareth", "Hugo"],
        "female": ["Adeline", "Brenna", "Clara", "Diana", "Elena", "Fiona", "Gwendolyn", "Helena"],
    },
    "elf": {
        "male": ["Aelindor", "Caelum", "Eldrin", "Faenor", "Galathil", "Ithelan", "Lyran", "Thaelon"],
        "female": ["Aelindra", "Caelia", "Elara", "Faelwen", "Galadria", "Ithilwen", "Lyria", "Thaelwen"],
    },
    "dwarf": {
        "male": ["Balin", "Dain", "Fargrim", "Gundren", "Harbek", "Kildrak", "Morgran", "Thorin"],
        "female": ["Amber", "Bardryn", "Diesa", "Eldeth", "Gunnloda", "Helja", "Kathra", "Riswynn"],
    },
    "halfling": {
        "male": ["Alton", "Cade", "Eldon", "Garrett", "Lyle", "Merric", "Osborn", "Roscoe"],
        "female": ["Andry", "Bree", "Cora", "Euphemia", "Jillian", "Kithri", "Lavinia", "Portia"],
    },
}

LAST_NAMES = {
    "human": ["Ashford", "Blackwood", "Coldwell", "Dunmore", "Fairfax", "Greenleaf", "Hartley", "Ironside"],
    "elf": ["Amastacia", "Galanodel", "Holimion", "Liadon", "Meliamne", "Nailo", "Siannodel", "Xiloscient"],
    "dwarf": ["Battlehammer", "Boulderstone", "Dankil", "Fireforge", "Ironfist", "Loderr", "Rumnaheim", "Torunn"],
    "halfling": ["Brushgather", "Goodbarrel", "Greenbottle", "High-hill", "Hilltopple", "Leagallow", "Tealeaf", "Thorngage"],
}

# NPC templates
NPC_TEMPLATES: Dict[NPCRole, Dict] = {
    NPCRole.MERCHANT: {
        "descriptions": [
            "A shrewd-looking trader with keen eyes.",
            "A portly merchant in fine clothes.",
            "A weathered traveler with goods from distant lands.",
        ],
        "traits": ["Greedy", "Fair", "Suspicious of strangers", "Knowledgeable about goods"],
        "inventory_types": ["weapons", "armor", "supplies", "potions"],
    },
    NPCRole.GUARD: {
        "descriptions": [
            "A stern guard in well-maintained armor.",
            "A bored-looking sentry leaning on their spear.",
            "A vigilant watchman scanning the surroundings.",
        ],
        "traits": ["Dutiful", "Alert", "By-the-book", "Weary"],
    },
    NPCRole.INNKEEPER: {
        "descriptions": [
            "A jovial innkeeper wiping down the bar.",
            "A tired but friendly host managing the busy common room.",
            "A gruff proprietor keeping order in the establishment.",
        ],
        "traits": ["Hospitable", "Gossipy", "Practical", "Protective of guests"],
    },
    NPCRole.BLACKSMITH: {
        "descriptions": [
            "A muscular smith with soot-stained arms.",
            "A skilled craftsman examining a blade.",
            "A sweating worker at the forge.",
        ],
        "traits": ["Hardworking", "Proud of craft", "Straightforward", "Strong"],
    },
    NPCRole.PRIEST: {
        "descriptions": [
            "A serene cleric in holy vestments.",
            "A devout priest clutching a sacred symbol.",
            "A wise religious figure with kind eyes.",
        ],
        "traits": ["Devout", "Compassionate", "Wise", "Judgmental"],
    },
    NPCRole.QUEST_GIVER: {
        "descriptions": [
            "A worried citizen seeking help.",
            "A mysterious figure with an urgent request.",
            "A noble looking for capable adventurers.",
        ],
        "traits": ["Desperate", "Secretive", "Grateful", "Demanding"],
    },
}

# Quest templates
QUEST_TEMPLATES = [
    {
        "name": "Clear the {location}",
        "description": "The {location} has been overrun by {enemies}. Clear them out!",
        "objectives": ["Enter the {location}", "Defeat all {enemies}", "Return for reward"],
        "reward_xp": 100,
        "reward_gold": 50,
    },
    {
        "name": "Retrieve the {item}",
        "description": "A valuable {item} has been stolen by {enemies}. Retrieve it!",
        "objectives": ["Find the {enemies}' hideout", "Recover the {item}", "Return the {item}"],
        "reward_xp": 150,
        "reward_gold": 75,
    },
    {
        "name": "Escort {person}",
        "description": "{person} needs safe passage through dangerous territory.",
        "objectives": ["Meet {person}", "Escort them safely", "Reach the destination"],
        "reward_xp": 100,
        "reward_gold": 100,
    },
    {
        "name": "Investigate the {location}",
        "description": "Strange occurrences have been reported at the {location}. Investigate!",
        "objectives": ["Travel to the {location}", "Discover the cause", "Report findings"],
        "reward_xp": 75,
        "reward_gold": 40,
    },
]


def generate_name(race: str, gender: str = "male") -> str:
    """Generate a random name for a race and gender."""
    race_lower = race.lower()

    # Default to human names for unknown races
    if race_lower not in FIRST_NAMES:
        race_lower = "human"

    first_names = FIRST_NAMES[race_lower].get(gender, FIRST_NAMES[race_lower]["male"])
    last_names = LAST_NAMES.get(race_lower, LAST_NAMES["human"])

    return f"{random.choice(first_names)} {random.choice(last_names)}"


def generate_npc(
    role: NPCRole,
    race: Optional[str] = None,
    name: Optional[str] = None,
    attitude: NPCAttitude = NPCAttitude.INDIFFERENT
) -> NPC:
    """Generate a random NPC."""
    # Random race if not specified
    if not race:
        race = random.choice(["human", "human", "human", "elf", "dwarf", "halfling"])

    # Generate name if not specified
    if not name:
        gender = random.choice(["male", "female"])
        name = generate_name(race, gender)

    # Get template
    template = NPC_TEMPLATES.get(role, NPC_TEMPLATES[NPCRole.QUEST_GIVER])

    # Generate description
    description = random.choice(template.get("descriptions", ["A nondescript individual."]))

    # Create NPC
    npc = NPC(
        id=str(uuid.uuid4()),
        name=name,
        role=role,
        race=race.capitalize(),
        description=description,
        attitude=attitude,
        traits=random.sample(template.get("traits", []), min(2, len(template.get("traits", [])))),
    )

    # Add role-specific features
    if role == NPCRole.MERCHANT:
        npc.gold = random.randint(50, 200)
        npc.inventory = ["potion_of_healing", "torch", "rope", "rations"]

    # Add basic dialogue
    _add_basic_dialogue(npc)

    return npc


def generate_quest_giver(quest_type: Optional[str] = None) -> Tuple[NPC, Quest]:
    """Generate an NPC with a quest."""
    npc = generate_npc(NPCRole.QUEST_GIVER)

    # Select quest template
    template = random.choice(QUEST_TEMPLATES)

    # Fill in template variables
    locations = ["old mine", "abandoned tower", "dark cave", "ruined temple"]
    enemies = ["goblins", "bandits", "undead", "orcs"]
    items = ["ancient artifact", "stolen heirloom", "sacred relic", "merchant's goods"]
    people = ["a merchant", "a noble's child", "a priest", "a scholar"]

    quest = Quest(
        id=str(uuid.uuid4()),
        name=template["name"].format(
            location=random.choice(locations),
            item=random.choice(items),
            person=random.choice(people),
        ),
        description=template["description"].format(
            location=random.choice(locations),
            enemies=random.choice(enemies),
            item=random.choice(items),
            person=random.choice(people),
        ),
        objectives=[obj.format(
            location=random.choice(locations),
            enemies=random.choice(enemies),
            item=random.choice(items),
            person=random.choice(people),
        ) for obj in template["objectives"]],
        reward_xp=template["reward_xp"],
        reward_gold=template["reward_gold"],
    )

    npc.quest = quest

    # Update dialogue for quest
    npc.dialogue_tree["quest"] = DialogueLine(
        text=f"I need your help! {quest.description}",
        responses=[
            DialogueResponse("I'll help you.", next_dialogue="accept", effect="accept_quest"),
            DialogueResponse("What's the reward?", next_dialogue="reward"),
            DialogueResponse("Not interested.", next_dialogue="decline"),
        ]
    )

    npc.dialogue_tree["reward"] = DialogueLine(
        text=f"I can offer you {quest.reward_gold} gold pieces for your trouble.",
        responses=[
            DialogueResponse("Deal. I'll do it.", next_dialogue="accept", effect="accept_quest"),
            DialogueResponse("I need more.", next_dialogue="negotiate"),
            DialogueResponse("No thanks.", next_dialogue="decline"),
        ]
    )

    npc.dialogue_tree["accept"] = DialogueLine(
        text="Thank you! Please hurry!",
    )

    npc.dialogue_tree["decline"] = DialogueLine(
        text="I understand. Perhaps another time.",
    )

    return npc, quest


def _add_basic_dialogue(npc: NPC) -> None:
    """Add basic dialogue options to an NPC."""
    npc.dialogue_tree["start"] = DialogueLine(
        text=npc.get_greeting(),
        responses=[
            DialogueResponse("Who are you?", next_dialogue="introduction"),
            DialogueResponse("What is this place?", next_dialogue="location"),
            DialogueResponse("Farewell.", next_dialogue="goodbye"),
        ]
    )

    npc.dialogue_tree["introduction"] = DialogueLine(
        text=f"I am {npc.name}, a {npc.role.value.lower()} here.",
        responses=[
            DialogueResponse("Tell me more.", next_dialogue="more_info"),
            DialogueResponse("Thanks.", next_dialogue="start"),
        ]
    )

    npc.dialogue_tree["location"] = DialogueLine(
        text="This is a place of adventure and danger. Watch your step.",
        responses=[
            DialogueResponse("Any advice?", next_dialogue="advice"),
            DialogueResponse("Thanks.", next_dialogue="start"),
        ]
    )

    npc.dialogue_tree["advice"] = DialogueLine(
        text="Keep your weapons ready and don't trust everyone you meet.",
    )

    npc.dialogue_tree["more_info"] = DialogueLine(
        text=npc.description,
    )

    npc.dialogue_tree["goodbye"] = DialogueLine(
        text="Safe travels.",
    )

    if npc.role == NPCRole.MERCHANT:
        npc.dialogue_tree["start"].responses.insert(0, DialogueResponse("Show me your wares.", next_dialogue="shop", effect="open_shop"))

        npc.dialogue_tree["shop"] = DialogueLine(
            text="Take a look at what I have. Fair prices, I assure you.",
        )
