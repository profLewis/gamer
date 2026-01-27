"""Main game engine and state management."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Callable
from enum import Enum, auto

from .dm import DungeonMaster
from .session import Session, save_session, auto_save
from ..characters.character import Character
from ..characters.abilities import Abilities, AbilityScores, Ability
from ..characters.races import get_race, get_all_races
from ..characters.classes import get_class, get_all_classes
from ..combat.combat import CombatEncounter, CombatState
from ..world.dungeon import Dungeon, Room, Direction, RoomType
from ..world.encounters import Encounter
from ..players.player import Player
from ..utils.dice import d20, roll, roll_ability_scores, standard_array


class GameState(Enum):
    """Possible game states."""
    MAIN_MENU = auto()
    CHARACTER_CREATION = auto()
    PARTY_SETUP = auto()
    EXPLORING = auto()
    IN_COMBAT = auto()
    RESTING = auto()
    SHOPPING = auto()
    DIALOGUE = auto()
    LEVEL_UP = auto()
    GAME_OVER = auto()
    VICTORY = auto()


@dataclass
class GameEngine:
    """Main game engine that manages the game loop."""

    state: GameState = GameState.MAIN_MENU
    session: Optional[Session] = None
    dm: DungeonMaster = field(default_factory=DungeonMaster)

    # Party management
    party: List[Character] = field(default_factory=list)
    players: Dict[str, Player] = field(default_factory=dict)  # character_id -> Player

    # Current situation
    current_combat: Optional[CombatEncounter] = None
    current_npc_id: Optional[str] = None

    # Game settings
    max_party_size: int = 4
    auto_save_enabled: bool = True

    def new_game(self, session_name: str) -> None:
        """Start a new game."""
        self.session = Session(name=session_name)
        self.party = []
        self.players = {}
        self.state = GameState.PARTY_SETUP

    def load_game(self, session: Session) -> bool:
        """Load an existing game."""
        self.session = session
        self.party = session.get_characters()

        # Restore dungeon state if exists
        if session.dungeon_state:
            # Would need to reconstruct dungeon from state
            pass

        if session.dm_state:
            # Would need to reconstruct DM state
            pass

        self.state = GameState.EXPLORING if self.party else GameState.PARTY_SETUP
        return True

    def save_game(self) -> bool:
        """Save the current game."""
        if not self.session:
            return False

        # Update session with current state
        self.session.party = [char.to_dict() for char in self.party]

        if self.dm.dungeon:
            self.session.dungeon_state = self.dm.dungeon.to_dict()

        self.session.dm_state = self.dm.to_dict()

        return save_session(self.session)

    def create_character(
        self,
        name: str,
        race_name: str,
        class_name: str,
        ability_scores: List[int],
        skill_proficiencies: List[str],
    ) -> Optional[Character]:
        """Create a new character and add to party."""
        race = get_race(race_name)
        char_class = get_class(class_name)

        if not race or not char_class:
            return None

        # Create ability scores
        ability_order = [
            Ability.STRENGTH, Ability.DEXTERITY, Ability.CONSTITUTION,
            Ability.INTELLIGENCE, Ability.WISDOM, Ability.CHARISMA
        ]
        scores = AbilityScores.from_list(ability_scores, ability_order)
        abilities = Abilities(scores)

        # Create character
        character = Character(name, race, char_class, abilities)

        # Add skill proficiencies
        for skill in skill_proficiencies[:char_class.num_skill_choices]:
            character.skills.add_proficiency(skill)

        # Add starting spells for spellcasters
        if character.spellbook:
            self._add_starting_spells(character)

        return character

    def _add_starting_spells(self, character: Character) -> None:
        """Add appropriate starting spells to a character."""
        from ..characters.spells import get_spells_by_class, get_cantrips

        class_name = character.char_class.name.lower()

        # Get available cantrips and spells
        class_cantrips = [s for s in get_cantrips() if class_name in s.classes]
        class_spells = [s for s in get_spells_by_class(class_name) if s.level == 1]

        # Add cantrips
        spell_slots = character.char_class.get_spell_slots(1)
        for cantrip in class_cantrips[:spell_slots.cantrips]:
            character.spellbook.learn_spell(cantrip.name)

        # Add level 1 spells (Wizards know 6, others prepare from class list)
        if class_name == "wizard":
            for spell in class_spells[:6]:
                character.spellbook.learn_spell(spell.name)
        else:
            # Prepared casters know all spells but prepare a subset
            for spell in class_spells:
                character.spellbook.learn_spell(spell.name)

    def add_character_to_party(self, character: Character, player: Player) -> bool:
        """Add a character to the party with their player controller."""
        if len(self.party) >= self.max_party_size:
            return False

        self.party.append(character)
        self.players[character.id] = player

        if self.session:
            self.session.add_character(character)

        return True

    def remove_character(self, character_id: str) -> bool:
        """Remove a character from the party."""
        for i, char in enumerate(self.party):
            if char.id == character_id:
                self.party.pop(i)
                self.players.pop(character_id, None)
                return True
        return False

    def start_adventure(self, dungeon_name: str = "The Dark Depths",
                        difficulty: int = 1) -> str:
        """Start the adventure by generating a dungeon."""
        num_rooms = 8 + difficulty * 2
        self.dm.generate_dungeon(dungeon_name, difficulty, num_rooms)

        self.state = GameState.EXPLORING

        # Return entrance description
        return self.dm.narrate("enter_dungeon") + "\n\n" + \
               self.dm.describe_room(self.dm.dungeon.current_room, first_visit=True)

    def explore(self, direction: Direction) -> str:
        """Move the party in a direction."""
        if self.state != GameState.EXPLORING:
            return "Cannot explore right now."

        if not self.dm.dungeon:
            return "No dungeon to explore."

        success, message = self.dm.dungeon.move(direction)

        if success:
            room = self.dm.dungeon.current_room
            description = self.dm.describe_room(room, first_visit=not room.visited)

            # Update session stats
            if self.session and not room.visited:
                self.session.rooms_explored += 1

            # Check for encounter
            if room.encounter and not room.cleared:
                self.state = GameState.IN_COMBAT
                self.start_combat(room.encounter)
                description += "\n\n" + self.dm.describe_encounter(room.encounter)

            # Check for trap
            elif room.trap and not room.trap.triggered and not room.trap.disarmed:
                trap_result = self._check_trap(room)
                description += "\n\n" + trap_result

            # Auto-save after movement
            if self.auto_save_enabled and self.session:
                auto_save(self.session)

            return description

        return message

    def _check_trap(self, room: Room) -> str:
        """Check for and potentially trigger a trap."""
        trap = room.trap

        # Passive perception check
        highest_perception = max(char.passive_perception for char in self.party)

        if highest_perception >= trap.detection_dc:
            return f"You notice a {trap.name}! (DC {trap.detection_dc})"

        # Trap triggers
        trap.triggered = True

        # Each party member makes saving throw
        total_damage = 0
        results = []

        for char in self.party:
            save_mod = char.get_saving_throw_modifier(
                Ability.DEXTERITY if trap.save_ability == "dex" else Ability.STRENGTH
            )
            save_roll = d20(modifier=save_mod)

            damage_roll, _, _ = roll(trap.damage)

            if save_roll >= trap.save_dc:
                damage_roll //= 2
                results.append(f"{char.name} saves! ({damage_roll} damage)")
            else:
                results.append(f"{char.name} fails! ({damage_roll} damage)")

            char.take_damage(damage_roll)
            total_damage += damage_roll

        return self.dm.describe_trap(trap, True, total_damage) + "\n" + "\n".join(results)

    def start_combat(self, encounter: Encounter) -> None:
        """Initialize combat with an encounter."""
        self.current_combat = CombatEncounter()

        # Add party members
        for char in self.party:
            if char.is_alive:
                self.current_combat.add_player(char)

        # Add monsters
        for monster in encounter.monsters:
            self.current_combat.add_monster(monster)

        self.current_combat.start_combat()
        self.state = GameState.IN_COMBAT

    def process_combat_turn(self) -> str:
        """Process the current combat turn."""
        if not self.current_combat:
            return "No combat in progress."

        combatant = self.current_combat.get_current_combatant()
        if not combatant:
            return "Combat has ended."

        # Check if it's a player's turn
        if combatant.is_player:
            player = self.players.get(combatant.entity_id)
            if player:
                return player.get_combat_action(self.current_combat, combatant)
        else:
            # AI monster turn
            return self._process_monster_turn(combatant)

        return ""

    def _process_monster_turn(self, combatant: Any) -> str:
        """Process an AI monster's turn."""
        # Simple AI: attack nearest player
        targets = self.current_combat.get_valid_targets(combatant.entity_id, friendly=False)

        if not targets:
            self.current_combat.next_turn()
            return f"{combatant.name} has no valid targets."

        # Attack random target
        import random
        target = random.choice(targets)

        # Get primary attack
        monster = combatant.entity
        attack = monster.get_primary_attack()

        if attack:
            result = self.current_combat.attack(
                combatant.entity_id,
                target.entity_id,
                attack.name
            )
            self.current_combat.next_turn()
            return result.description

        self.current_combat.next_turn()
        return f"{combatant.name} does nothing."

    def execute_player_action(self, action: str, target_id: Optional[str] = None,
                              **kwargs) -> str:
        """Execute a player's chosen action in combat."""
        if not self.current_combat:
            return "No combat in progress."

        combatant = self.current_combat.get_current_combatant()
        if not combatant or not combatant.is_player:
            return "Not your turn."

        result = None

        if action == "attack" and target_id:
            weapon = kwargs.get('weapon', 'unarmed')
            result = self.current_combat.attack(combatant.entity_id, target_id, weapon)

        elif action == "cast" and target_id:
            spell_name = kwargs.get('spell', '')
            result = self.current_combat.cast_spell(combatant.entity_id, spell_name, target_id)

        elif action == "dodge":
            result = self.current_combat.dodge(combatant.entity_id)

        elif action == "dash":
            result = self.current_combat.dash(combatant.entity_id)

        elif action == "disengage":
            result = self.current_combat.disengage(combatant.entity_id)

        elif action == "help" and target_id:
            result = self.current_combat.help_action(combatant.entity_id, target_id)

        elif action == "end_turn":
            self.current_combat.next_turn()
            return "Turn ended."

        if result:
            # Check for combat end
            if self.current_combat.state == CombatState.VICTORY:
                return self._handle_combat_victory()
            elif self.current_combat.state == CombatState.DEFEAT:
                return self._handle_combat_defeat()

            # Move to next turn
            self.current_combat.next_turn()
            return result.description

        return "Invalid action."

    def _handle_combat_victory(self) -> str:
        """Handle victory in combat."""
        room = self.dm.dungeon.current_room
        encounter = room.encounter

        # Mark room as cleared
        room.cleared = True

        # Award XP
        description = self.dm.describe_victory(encounter, self.party)

        # Update session stats
        if self.session:
            self.session.monsters_defeated += len(encounter.monsters)
            self.session.total_xp_earned += encounter.get_xp_reward()

        self.state = GameState.EXPLORING
        self.current_combat = None

        # Check for treasure
        if room.treasure:
            description += "\n\n" + self.dm.describe_treasure(room.treasure)

        return description

    def _handle_combat_defeat(self) -> str:
        """Handle defeat in combat."""
        if self.session:
            self.session.deaths += 1

        self.state = GameState.GAME_OVER
        self.current_combat = None

        return self.dm.describe_defeat()

    def rest(self, is_long_rest: bool = False) -> str:
        """Rest the party."""
        results = {}

        for char in self.party:
            if is_long_rest:
                result = char.long_rest()
            else:
                result = char.short_rest()
            results[char.name] = result

        if self.auto_save_enabled and self.session:
            auto_save(self.session)

        return self.dm.describe_rest(is_long_rest, results)

    def search_room(self) -> str:
        """Search the current room."""
        if not self.dm.dungeon:
            return "Nothing to search."

        room = self.dm.dungeon.current_room
        found_items = []

        # Check for hidden features
        for feature in room.features:
            if feature.hidden_dc and not feature.searched:
                # Investigation check
                for char in self.party:
                    check = d20(modifier=char.get_skill_modifier("investigation"))
                    if check >= feature.hidden_dc:
                        feature.searched = True
                        found_items.append(f"Found: {feature.name}")
                        break

        # Check for hidden doors
        for direction in list(room.secret_doors):
            for char in self.party:
                check = d20(modifier=char.get_skill_modifier("perception"))
                if check >= 15:  # DC 15 for secret doors
                    room.secret_doors.remove(direction)
                    found_items.append(f"Discovered a secret passage to the {direction.name.lower()}!")
                    break

        if found_items:
            return "Searching the room...\n" + "\n".join(found_items)
        return "You search carefully but find nothing new."

    def collect_treasure(self) -> str:
        """Collect treasure in the current room."""
        if not self.dm.dungeon:
            return "No treasure to collect."

        room = self.dm.dungeon.current_room
        if not room.treasure:
            return "No treasure here."

        treasure_list = room.treasure.copy()
        room.treasure = []

        # Parse gold and add to party
        total_gold = 0
        for item in treasure_list:
            if "gold" in item.lower():
                try:
                    gold = int(item.split()[0])
                    total_gold += gold
                except ValueError:
                    pass

        # Distribute gold evenly
        if total_gold and self.party:
            gold_each = total_gold // len(self.party)
            for char in self.party:
                char.equipment.gold += gold_each

            if self.session:
                self.session.gold_collected += total_gold

        return f"Collected: {', '.join(treasure_list)}"

    def get_party_status(self) -> str:
        """Get a summary of party status."""
        lines = ["=== Party Status ==="]

        for char in self.party:
            hp_pct = (char.current_hp / char.max_hp) * 100
            hp_bar = "█" * int(hp_pct / 10) + "░" * (10 - int(hp_pct / 10))
            lines.append(f"{char.name}: [{hp_bar}] {char.current_hp}/{char.max_hp} HP")

            if char.conditions:
                lines.append(f"  Conditions: {', '.join(char.conditions)}")

        return "\n".join(lines)

    def get_available_actions(self) -> List[str]:
        """Get available actions based on current state."""
        if self.state == GameState.EXPLORING:
            actions = ["north", "south", "east", "west", "search", "rest", "status", "map"]
            room = self.dm.dungeon.current_room if self.dm.dungeon else None
            if room and room.treasure:
                actions.append("collect")
            return actions

        elif self.state == GameState.IN_COMBAT:
            return ["attack", "cast", "dodge", "dash", "disengage", "help", "end_turn"]

        elif self.state == GameState.MAIN_MENU:
            return ["new_game", "load_game", "quit"]

        return []

    def get_game_summary(self) -> str:
        """Get a summary of game progress."""
        if not self.session:
            return "No active game."

        return self.session.get_summary()
