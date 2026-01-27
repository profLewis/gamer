"""AI player controller for computer-controlled characters."""

from typing import Dict, List, Optional, Any, TYPE_CHECKING
from enum import Enum
import random

from .player import Player

if TYPE_CHECKING:
    from ..combat.combat import CombatEncounter, Combatant
    from ..characters.character import Character


class AIPersonality(Enum):
    """AI personality types affecting decision making."""
    AGGRESSIVE = "aggressive"  # Prioritizes damage, targets weakest
    DEFENSIVE = "defensive"    # Prioritizes survival, uses defensive actions
    BALANCED = "balanced"      # Mix of offense and defense
    SUPPORTIVE = "supportive"  # Prioritizes healing and buffing allies


class AIPlayer(Player):
    """AI-controlled player for computer characters."""

    def __init__(self, name: str, personality: AIPersonality = AIPersonality.BALANCED):
        """Initialize AI player."""
        super().__init__(name)
        self.is_human = False
        self.personality = personality
        self.threat_memory: Dict[str, int] = {}  # Track threats

    def get_combat_action(self, combat: 'CombatEncounter',
                         combatant: 'Combatant') -> Dict[str, Any]:
        """Determine combat action using AI logic."""
        character = combatant.entity

        # Assess situation
        enemies = combat.get_valid_targets(combatant.entity_id, friendly=False)
        allies = combat.get_valid_targets(combatant.entity_id, friendly=True)

        hp_percentage = character.current_hp / character.max_hp

        # Emergency healing check
        if hp_percentage < 0.25 and self._can_heal(character):
            return self._try_heal_self(character, combatant.entity_id)

        # Supportive personality checks allies first
        if self.personality == AIPersonality.SUPPORTIVE:
            hurt_ally = self._find_hurt_ally(allies)
            if hurt_ally and self._can_heal(character):
                return self._try_heal_target(character, hurt_ally.entity_id)

        # Defensive personality might dodge if low
        if self.personality == AIPersonality.DEFENSIVE and hp_percentage < 0.4:
            if random.random() < 0.5:
                return {'action': 'dodge'}

        # Offensive action
        if enemies:
            target = self._select_target(enemies, character)

            # Spellcaster check
            if self._should_cast_spell(character, target):
                spell_action = self._choose_spell(character, target)
                if spell_action:
                    return spell_action

            # Regular attack
            weapon = self._choose_weapon(character, target)
            return {
                'action': 'attack',
                'target_id': target.entity_id,
                'weapon': weapon,
            }

        return {'action': 'end_turn'}

    def get_exploration_action(self, available_actions: List[str]) -> str:
        """Choose exploration action."""
        # Prioritize certain actions based on personality
        priorities = {
            AIPersonality.AGGRESSIVE: ['north', 'south', 'east', 'west', 'search'],
            AIPersonality.DEFENSIVE: ['search', 'rest', 'north', 'south', 'east', 'west'],
            AIPersonality.BALANCED: ['search', 'north', 'south', 'east', 'west'],
            AIPersonality.SUPPORTIVE: ['rest', 'search', 'north', 'south', 'east', 'west'],
        }

        for action in priorities.get(self.personality, available_actions):
            if action in available_actions:
                return action

        return random.choice(available_actions) if available_actions else 'wait'

    def get_dialogue_choice(self, options: List[str]) -> int:
        """Choose dialogue option based on personality."""
        # Simple keyword matching for personality-appropriate choices
        keywords = {
            AIPersonality.AGGRESSIVE: ['fight', 'attack', 'challenge', 'threat'],
            AIPersonality.DEFENSIVE: ['peace', 'careful', 'safe', 'avoid'],
            AIPersonality.BALANCED: ['help', 'information', 'quest'],
            AIPersonality.SUPPORTIVE: ['help', 'heal', 'aid', 'assist'],
        }

        personality_keywords = keywords.get(self.personality, [])

        for i, option in enumerate(options):
            option_lower = option.lower()
            for keyword in personality_keywords:
                if keyword in option_lower:
                    return i

        # Default to first non-aggressive option or random
        return random.randint(0, len(options) - 1)

    def choose_target(self, targets: List[Any]) -> Optional[str]:
        """Choose target based on AI logic."""
        if not targets:
            return None

        # Different targeting strategies based on personality
        if self.personality == AIPersonality.AGGRESSIVE:
            # Target lowest HP
            target = min(targets, key=lambda t: t.entity.current_hp if hasattr(t, 'entity') else 999)
        elif self.personality == AIPersonality.SUPPORTIVE:
            # Target highest threat to allies (random for now)
            target = random.choice(targets)
        else:
            # Balanced: target based on threat and HP
            target = self._balanced_target_selection(targets)

        return target.entity_id if hasattr(target, 'entity_id') else str(target)

    def confirm(self, prompt: str) -> bool:
        """AI auto-confirms based on personality."""
        # Generally conservative decisions
        if self.personality == AIPersonality.AGGRESSIVE:
            return True  # Aggressive AI takes risks
        elif self.personality == AIPersonality.DEFENSIVE:
            return False  # Defensive AI avoids risks
        else:
            return random.random() > 0.3  # Slight bias toward yes

    def notify(self, message: str) -> None:
        """AI doesn't need notifications but could log them."""
        pass  # AI ignores notifications

    def _select_target(self, enemies: List[Any], character: 'Character') -> Any:
        """Select best target for attack."""
        if self.personality == AIPersonality.AGGRESSIVE:
            # Target lowest HP enemy
            return min(enemies, key=lambda e: e.entity.current_hp)

        elif self.personality == AIPersonality.DEFENSIVE:
            # Target nearest or most threatening
            # For now, random selection
            return random.choice(enemies)

        else:  # BALANCED or SUPPORTIVE
            # Balance between low HP and threat
            # Score enemies: lower HP = higher score, higher damage = higher score
            def score_enemy(e):
                hp_score = 100 - (e.entity.current_hp / e.entity.max_hp * 100)
                return hp_score

            return max(enemies, key=score_enemy)

    def _balanced_target_selection(self, targets: List[Any]) -> Any:
        """Select target using balanced logic."""
        # Prefer targets with less than 50% HP
        low_hp = [t for t in targets if hasattr(t, 'entity') and
                  t.entity.current_hp < t.entity.max_hp * 0.5]
        if low_hp:
            return random.choice(low_hp)
        return random.choice(targets)

    def _can_heal(self, character: 'Character') -> bool:
        """Check if character can heal."""
        if not hasattr(character, 'spellbook') or not character.spellbook:
            return False

        healing_spells = ['cure wounds', 'healing word']
        for spell in healing_spells:
            if character.spellbook.can_cast(spell):
                return True
        return False

    def _try_heal_self(self, character: 'Character', self_id: str) -> Dict[str, Any]:
        """Attempt to heal self."""
        healing_spells = ['healing word', 'cure wounds']  # Prefer bonus action
        for spell in healing_spells:
            if character.spellbook.can_cast(spell):
                return {
                    'action': 'cast',
                    'spell': spell,
                    'target_id': self_id,
                }
        return {'action': 'dodge'}  # Fallback to defensive action

    def _try_heal_target(self, character: 'Character', target_id: str) -> Dict[str, Any]:
        """Attempt to heal a target."""
        healing_spells = ['healing word', 'cure wounds']
        for spell in healing_spells:
            if character.spellbook.can_cast(spell):
                return {
                    'action': 'cast',
                    'spell': spell,
                    'target_id': target_id,
                }
        return {'action': 'help', 'target_id': target_id}

    def _find_hurt_ally(self, allies: List[Any]) -> Optional[Any]:
        """Find an ally that needs healing."""
        for ally in allies:
            if hasattr(ally, 'entity'):
                hp_pct = ally.entity.current_hp / ally.entity.max_hp
                if hp_pct < 0.5:
                    return ally
        return None

    def _should_cast_spell(self, character: 'Character', target: Any) -> bool:
        """Determine if AI should cast a spell."""
        if not hasattr(character, 'spellbook') or not character.spellbook:
            return False

        # Check if has offensive spells available
        offensive_spells = ['fire bolt', 'magic missile', 'burning hands', 'guiding bolt']
        for spell in offensive_spells:
            if character.spellbook.can_cast(spell):
                return random.random() < 0.7  # 70% chance to cast if available

        return False

    def _choose_spell(self, character: 'Character', target: Any) -> Optional[Dict[str, Any]]:
        """Choose which spell to cast."""
        if not character.spellbook:
            return None

        # Prioritize damage spells
        damage_spells = ['fire bolt', 'guiding bolt', 'magic missile', 'burning hands', 'sacred flame']

        for spell in damage_spells:
            if character.spellbook.can_cast(spell):
                return {
                    'action': 'cast',
                    'spell': spell,
                    'target_id': target.entity_id,
                }

        return None

    def _choose_weapon(self, character: 'Character', target: Any) -> str:
        """Choose best weapon for the situation."""
        weapons = character.equipment.weapons
        if not weapons:
            return 'unarmed'

        # Prefer higher damage weapons
        # For now, just pick first weapon
        return weapons[0]

    def set_personality(self, personality: AIPersonality) -> None:
        """Change AI personality."""
        self.personality = personality

    def assess_threat(self, enemy_id: str, damage_dealt: int) -> None:
        """Update threat assessment for an enemy."""
        current_threat = self.threat_memory.get(enemy_id, 0)
        self.threat_memory[enemy_id] = current_threat + damage_dealt

    def get_highest_threat(self, enemies: List[Any]) -> Optional[Any]:
        """Get the highest threat enemy."""
        if not enemies:
            return None

        max_threat = 0
        highest_threat_enemy = None

        for enemy in enemies:
            enemy_id = enemy.entity_id if hasattr(enemy, 'entity_id') else str(enemy)
            threat = self.threat_memory.get(enemy_id, 0)
            if threat > max_threat:
                max_threat = threat
                highest_threat_enemy = enemy

        return highest_threat_enemy or random.choice(enemies)
