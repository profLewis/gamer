"""AI Dungeon Master for narration and game management."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Tuple
import random

from ..world.dungeon import Dungeon, Room, RoomType, generate_dungeon
from ..world.encounters import (
    Encounter, generate_encounter, generate_boss_encounter,
    Difficulty, calculate_difficulty
)
from ..world.npcs import NPC, generate_npc, generate_quest_giver, NPCRole
from ..characters.character import Character
from ..utils.display import Colors


# Narration templates
NARRATION_TEMPLATES = {
    "enter_dungeon": [
        "You descend into the darkness. The air grows cold and damp.",
        "The dungeon entrance looms before you. You steel yourselves and enter.",
        "With a deep breath, you step across the threshold into the unknown.",
    ],
    "enter_room": [
        "You cautiously enter {room_name}.",
        "Moving forward, you find yourselves in {room_name}.",
        "The passage opens into {room_name}.",
    ],
    "encounter_start": [
        "Suddenly, enemies appear!",
        "You are not alone here...",
        "Movement in the shadows! Prepare for combat!",
    ],
    "encounter_victory": [
        "The last enemy falls. Victory is yours!",
        "With the final blow, silence returns to the chamber.",
        "You stand victorious over your fallen foes.",
    ],
    "encounter_defeat": [
        "Darkness closes in as your party falls...",
        "The dungeon claims more souls this day.",
        "Your adventure ends here, in the cold depths.",
    ],
    "trap_triggered": [
        "A click echoes through the chamber. You've triggered a trap!",
        "Too late, you notice the trap mechanism activate!",
        "The floor shifts beneath you - a trap!",
    ],
    "trap_avoided": [
        "You carefully avoid the trap.",
        "Your keen senses save you from the hidden danger.",
        "The trap mechanism fails to catch you.",
    ],
    "treasure_found": [
        "Glittering treasure catches your eye!",
        "You discover a cache of valuables!",
        "Hidden riches reveal themselves to you.",
    ],
    "rest_short": [
        "You take a moment to catch your breath and tend to your wounds.",
        "A brief respite allows you to recover somewhat.",
        "You rest briefly, regaining some strength.",
    ],
    "rest_long": [
        "You make camp and rest through the night, fully recovering.",
        "A full night's rest restores your strength and resolve.",
        "You awaken refreshed and ready to continue.",
    ],
    "npc_encounter": [
        "You notice someone ahead.",
        "A figure emerges from the shadows.",
        "You're not alone in this place.",
    ],
    "level_up": [
        "{name} has grown stronger! Level {level} achieved!",
        "Experience and skill combine - {name} reaches level {level}!",
        "Through trials overcome, {name} advances to level {level}!",
    ],
}

# Environmental descriptions
ENVIRONMENT_DETAILS = {
    "dungeon": [
        "Water drips somewhere in the darkness.",
        "Cobwebs brush against your face.",
        "The smell of decay lingers in the air.",
        "Your footsteps echo off the stone walls.",
        "Strange scratching sounds come from the walls.",
    ],
    "combat": [
        "Steel clashes against steel!",
        "The air fills with the sounds of battle!",
        "Adrenaline surges through your veins!",
    ],
}


@dataclass
class DungeonMaster:
    """The AI Dungeon Master that manages the game world."""

    dungeon: Optional[Dungeon] = None
    current_encounter: Optional[Encounter] = None
    active_npcs: Dict[str, NPC] = field(default_factory=dict)

    # Narrative state
    story_beats: List[str] = field(default_factory=list)
    tension_level: int = 0  # 0-10, affects narration tone
    rooms_cleared: int = 0
    encounters_won: int = 0

    def generate_dungeon(self, name: str, level: int = 1, num_rooms: int = 10) -> Dungeon:
        """Generate a new dungeon."""
        self.dungeon = generate_dungeon(name, level, num_rooms)
        self._populate_dungeon()
        return self.dungeon

    def _populate_dungeon(self) -> None:
        """Populate dungeon rooms with encounters and treasures."""
        if not self.dungeon:
            return

        for room in self.dungeon.rooms.values():
            # Skip entrance
            if room.room_type == RoomType.ENTRANCE:
                continue

            # Add encounters to appropriate rooms
            if room.room_type in [RoomType.CHAMBER, RoomType.BOSS]:
                if room.room_type == RoomType.BOSS:
                    # Boss room always has encounter
                    room.encounter = generate_boss_encounter([1, 1, 1, 1])  # Placeholder party
                elif random.random() < 0.6:  # 60% chance for other rooms
                    room.encounter = generate_encounter(
                        [1, 1, 1, 1],
                        Difficulty.MEDIUM
                    )

            # Add treasure to treasure rooms
            if room.room_type == RoomType.TREASURE:
                room.treasure = self._generate_treasure(self.dungeon.level)

            # Add NPC to rest/shrine areas occasionally
            if room.room_type in [RoomType.REST, RoomType.SHRINE]:
                if random.random() < 0.3:
                    npc = generate_npc(random.choice([NPCRole.MERCHANT, NPCRole.PRIEST]))
                    self.active_npcs[npc.id] = npc

    def _generate_treasure(self, dungeon_level: int) -> List[str]:
        """Generate treasure appropriate for dungeon level."""
        treasure = []
        gold = random.randint(10 * dungeon_level, 50 * dungeon_level)
        treasure.append(f"{gold} gold pieces")

        # Chance for potion
        if random.random() < 0.4:
            treasure.append("Potion of Healing")

        # Chance for gem
        if random.random() < 0.2:
            gem_value = random.choice([10, 25, 50, 100])
            treasure.append(f"Gem worth {gem_value} gp")

        return treasure

    def narrate(self, template_key: str, **kwargs) -> str:
        """Generate narration from a template."""
        templates = NARRATION_TEMPLATES.get(template_key, [""])
        template = random.choice(templates)
        return template.format(**kwargs)

    def describe_room(self, room: Room, first_visit: bool = True) -> str:
        """Generate a description of a room."""
        parts = []

        if first_visit:
            parts.append(self.narrate("enter_room", room_name=room.name))
            parts.append("")
            parts.append(room.description)

            # Add environmental detail
            if random.random() < 0.4:
                parts.append(random.choice(ENVIRONMENT_DETAILS["dungeon"]))
        else:
            parts.append(f"You are in {room.name}.")

        # Describe features
        if room.features:
            visible_features = [f for f in room.features if not f.hidden_dc or f.searched]
            if visible_features:
                parts.append("")
                parts.append("You notice: " + ", ".join(f.name for f in visible_features) + ".")

        # Describe exits
        parts.append("")
        parts.append(room.get_exits_description())

        # Warning about danger
        if room.encounter and not room.cleared:
            parts.append("")
            parts.append("You sense danger in this room...")

        return "\n".join(parts)

    def describe_encounter(self, encounter: Encounter) -> str:
        """Generate encounter description."""
        parts = [self.narrate("encounter_start")]
        parts.append("")
        parts.append(encounter.description)

        # List enemies
        parts.append("")
        parts.append("Enemies:")
        monster_counts: Dict[str, int] = {}
        for monster in encounter.monsters:
            monster_counts[monster.name] = monster_counts.get(monster.name, 0) + 1

        for name, count in monster_counts.items():
            if count > 1:
                parts.append(f"  - {count}x {name}")
            else:
                parts.append(f"  - {name}")

        parts.append("")
        parts.append(f"Encounter Difficulty: {encounter.difficulty.value}")

        return "\n".join(parts)

    def describe_victory(self, encounter: Encounter, party: List[Character]) -> str:
        """Generate victory description and rewards."""
        parts = [self.narrate("encounter_victory")]

        # XP reward
        xp_reward = encounter.get_xp_reward()
        xp_per_character = xp_reward // len(party)

        parts.append("")
        parts.append(f"Experience gained: {xp_per_character} XP each")

        # Check for level ups
        level_ups = []
        for char in party:
            old_level = char.level
            if char.gain_experience(xp_per_character):
                level_ups.append((char.name, char.level))

        if level_ups:
            parts.append("")
            for name, level in level_ups:
                parts.append(self.narrate("level_up", name=name, level=level))

        self.encounters_won += 1
        return "\n".join(parts)

    def describe_defeat(self) -> str:
        """Generate defeat description."""
        return self.narrate("encounter_defeat")

    def describe_trap(self, trap: Any, triggered: bool, damage: int = 0) -> str:
        """Describe trap encounter."""
        if triggered:
            text = self.narrate("trap_triggered")
            text += f"\n\nThe {trap.name} deals {damage} {trap.damage_type} damage!"
        else:
            text = self.narrate("trap_avoided")
            text += f"\n\nYou safely bypass the {trap.name}."
        return text

    def describe_treasure(self, treasure: List[str]) -> str:
        """Describe found treasure."""
        parts = [self.narrate("treasure_found")]
        parts.append("")
        parts.append("You find:")
        for item in treasure:
            parts.append(f"  - {item}")
        return "\n".join(parts)

    def describe_npc(self, npc: NPC) -> str:
        """Describe an NPC encounter."""
        parts = [self.narrate("npc_encounter")]
        parts.append("")
        parts.append(f"Before you stands {npc.name}, a {npc.race} {npc.role.value.lower()}.")
        parts.append(npc.description)
        return "\n".join(parts)

    def describe_rest(self, is_long_rest: bool, results: Dict[str, Dict]) -> str:
        """Describe rest results."""
        if is_long_rest:
            parts = [self.narrate("rest_long")]
        else:
            parts = [self.narrate("rest_short")]

        parts.append("")
        for char_name, result in results.items():
            hp_healed = result.get('hp_healed', 0)
            if hp_healed > 0:
                parts.append(f"  {char_name} recovers {hp_healed} HP")

        return "\n".join(parts)

    def get_action_description(self, action: str, actor: str, target: str = "",
                               result: str = "") -> str:
        """Generate description for a game action."""
        descriptions = {
            "attack": f"{actor} attacks {target}! {result}",
            "cast": f"{actor} casts a spell! {result}",
            "move": f"{actor} moves {target}.",
            "search": f"{actor} searches the area. {result}",
            "interact": f"{actor} interacts with {target}. {result}",
        }
        return descriptions.get(action, f"{actor} performs {action}.")

    def suggest_action(self, room: Room, party: List[Character]) -> str:
        """Suggest what the party might do next."""
        suggestions = []

        if room.encounter and not room.cleared:
            suggestions.append("Prepare for combat - enemies are present!")
        elif room.features:
            unsearched = [f for f in room.features if not f.searched]
            if unsearched:
                suggestions.append(f"You could search the {unsearched[0].name}.")
        elif room.treasure:
            suggestions.append("There may be treasure here to collect.")

        if len(room.exits) > 1:
            suggestions.append("Several passages lead onward.")

        # Check party health
        low_hp = [c for c in party if c.current_hp < c.max_hp * 0.5]
        if low_hp:
            names = ", ".join(c.name for c in low_hp)
            suggestions.append(f"{names} could use healing.")

        if not suggestions:
            suggestions.append("The way forward awaits.")

        return " ".join(suggestions)

    def get_dm_tip(self, context: str = "general") -> str:
        """Get a helpful DM tip for the player."""
        tips = {
            "general": [
                "Remember to check for traps before entering new rooms.",
                "Short rests can help recover hit points between encounters.",
                "Consider your party's resources before engaging in combat.",
            ],
            "combat": [
                "Focus fire on one enemy at a time for maximum efficiency.",
                "Use the environment to your advantage.",
                "Don't forget about bonus actions and reactions!",
            ],
            "exploration": [
                "Searching thoroughly can reveal hidden treasures.",
                "NPCs may have useful information or quests.",
                "Some doors may be locked or hidden.",
            ],
            "low_health": [
                "Consider taking a rest to recover.",
                "Potions of Healing can be lifesavers.",
                "A tactical retreat is sometimes the wisest choice.",
            ],
        }
        return random.choice(tips.get(context, tips["general"]))

    def to_dict(self) -> Dict:
        """Convert DM state to dictionary."""
        return {
            'dungeon': self.dungeon.to_dict() if self.dungeon else None,
            'story_beats': self.story_beats,
            'tension_level': self.tension_level,
            'rooms_cleared': self.rooms_cleared,
            'encounters_won': self.encounters_won,
            'active_npcs': {nid: npc.to_dict() for nid, npc in self.active_npcs.items()},
        }
