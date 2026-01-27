"""AI Dungeon Master module for natural language interaction.

This module provides LLM-powered DM narration and free text input handling.
Supports multiple backends: Anthropic Claude, OpenAI, or local fallback.
"""

import os
import json
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field
from enum import Enum


class AIBackend(Enum):
    """Available AI backends."""
    ANTHROPIC = "anthropic"
    OPENAI = "openai"
    LOCAL = "local"  # Simple rule-based fallback


@dataclass
class DMContext:
    """Context for the DM to understand the game state."""
    dungeon_name: str = ""
    current_room: str = ""
    room_description: str = ""
    party_members: List[str] = field(default_factory=list)
    party_status: str = ""
    recent_events: List[str] = field(default_factory=list)
    combat_active: bool = False
    enemies: List[str] = field(default_factory=list)
    inventory_highlights: List[str] = field(default_factory=list)

    def to_prompt(self) -> str:
        """Convert context to a prompt string."""
        parts = []
        if self.dungeon_name:
            parts.append(f"Location: {self.dungeon_name}")
        if self.current_room:
            parts.append(f"Current Room: {self.current_room}")
        if self.room_description:
            parts.append(f"Description: {self.room_description}")
        if self.party_members:
            parts.append(f"Party: {', '.join(self.party_members)}")
        if self.party_status:
            parts.append(f"Party Status: {self.party_status}")
        if self.combat_active:
            parts.append("COMBAT IS ACTIVE")
            if self.enemies:
                parts.append(f"Enemies: {', '.join(self.enemies)}")
        if self.recent_events:
            parts.append("Recent Events:")
            for event in self.recent_events[-5:]:
                parts.append(f"  - {event}")
        return "\n".join(parts)


class AIDM:
    """AI-powered Dungeon Master for natural language interaction."""

    SYSTEM_PROMPT = """You are a Dungeon Master for a D&D 5th Edition text-based game called "DnD".

Your role is to:
- Narrate the adventure in an engaging, atmospheric way
- Describe rooms, encounters, and events vividly but concisely
- Respond to player actions and questions naturally
- Stay true to D&D 5e rules and mechanics
- Keep responses SHORT (2-4 sentences for descriptions, 1-2 for acknowledgments)
- Be dramatic during combat, mysterious during exploration
- Occasionally hint at dangers or treasures

Style guidelines:
- Use second person ("You see...", "You hear...")
- Be atmospheric but not verbose
- Add occasional sound effects in *asterisks*
- Reference the game state provided in context

IMPORTANT: Keep responses under 100 words unless specifically asked for more detail."""

    def __init__(self, backend: AIBackend = AIBackend.LOCAL):
        self.backend = backend
        self.context = DMContext()
        self.conversation_history: List[Dict[str, str]] = []
        self._client = None
        self._model = None

        # Try to initialize the requested backend
        if backend == AIBackend.ANTHROPIC:
            self._init_anthropic()
        elif backend == AIBackend.OPENAI:
            self._init_openai()
        # LOCAL doesn't need initialization

    def _init_anthropic(self):
        """Initialize Anthropic Claude client."""
        try:
            import anthropic
            api_key = os.environ.get("ANTHROPIC_API_KEY")
            if api_key:
                self._client = anthropic.Anthropic(api_key=api_key)
                self._model = "claude-3-haiku-20240307"  # Fast and cheap
                print("AI DM: Using Claude API")
            else:
                print("AI DM: No ANTHROPIC_API_KEY found, falling back to local")
                self.backend = AIBackend.LOCAL
        except ImportError:
            print("AI DM: anthropic package not installed, falling back to local")
            self.backend = AIBackend.LOCAL

    def _init_openai(self):
        """Initialize OpenAI client."""
        try:
            import openai
            api_key = os.environ.get("OPENAI_API_KEY")
            if api_key:
                self._client = openai.OpenAI(api_key=api_key)
                self._model = "gpt-3.5-turbo"  # Fast and cheap
                print("AI DM: Using OpenAI API")
            else:
                print("AI DM: No OPENAI_API_KEY found, falling back to local")
                self.backend = AIBackend.LOCAL
        except ImportError:
            print("AI DM: openai package not installed, falling back to local")
            self.backend = AIBackend.LOCAL

    def update_context(self, **kwargs):
        """Update the DM context with current game state."""
        for key, value in kwargs.items():
            if hasattr(self.context, key):
                setattr(self.context, key, value)

    def add_event(self, event: str):
        """Add an event to recent history."""
        self.context.recent_events.append(event)
        # Keep only last 10 events
        if len(self.context.recent_events) > 10:
            self.context.recent_events = self.context.recent_events[-10:]

    def narrate(self, situation: str) -> str:
        """Get DM narration for a situation."""
        prompt = f"[Game Context]\n{self.context.to_prompt()}\n\n[Narrate this]: {situation}"
        return self._get_response(prompt)

    def respond_to_player(self, player_input: str) -> str:
        """Respond to free-form player input."""
        prompt = f"[Game Context]\n{self.context.to_prompt()}\n\n[Player says]: {player_input}"
        return self._get_response(prompt)

    def describe_room(self, room_name: str, room_type: str, features: List[str] = None) -> str:
        """Generate a room description."""
        features_str = ", ".join(features) if features else "nothing special"
        prompt = f"Briefly describe entering a {room_type} room called '{room_name}'. Features: {features_str}"
        return self._get_response(prompt)

    def describe_combat_start(self, enemies: List[str]) -> str:
        """Describe the start of combat."""
        enemies_str = ", ".join(enemies)
        prompt = f"Combat begins! Enemies appearing: {enemies_str}. Describe this dramatically in 2-3 sentences."
        return self._get_response(prompt)

    def describe_action_result(self, actor: str, action: str, target: str,
                               success: bool, damage: int = 0) -> str:
        """Describe the result of a combat action."""
        result = "hits" if success else "misses"
        damage_str = f" dealing {damage} damage" if success and damage > 0 else ""
        prompt = f"{actor} attacks {target} and {result}{damage_str}. Describe briefly."
        return self._get_response(prompt)

    def _get_response(self, prompt: str) -> str:
        """Get a response from the AI backend."""
        if self.backend == AIBackend.ANTHROPIC:
            return self._anthropic_response(prompt)
        elif self.backend == AIBackend.OPENAI:
            return self._openai_response(prompt)
        else:
            return self._local_response(prompt)

    def _anthropic_response(self, prompt: str) -> str:
        """Get response from Anthropic Claude."""
        try:
            message = self._client.messages.create(
                model=self._model,
                max_tokens=200,
                system=self.SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}]
            )
            return message.content[0].text
        except Exception as e:
            print(f"AI DM error: {e}")
            return self._local_response(prompt)

    def _openai_response(self, prompt: str) -> str:
        """Get response from OpenAI."""
        try:
            response = self._client.chat.completions.create(
                model=self._model,
                max_tokens=200,
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": prompt}
                ]
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"AI DM error: {e}")
            return self._local_response(prompt)

    def _local_response(self, prompt: str) -> str:
        """Simple rule-based fallback responses."""
        prompt_lower = prompt.lower()

        # Combat descriptions
        if "combat begins" in prompt_lower:
            enemies = self.context.enemies
            if enemies:
                return f"*Danger!* {', '.join(enemies)} block your path! Roll for initiative!"
            return "Enemies emerge from the shadows! Prepare for battle!"

        # Room descriptions
        if "describe entering" in prompt_lower or "describe room" in prompt_lower:
            room = self.context.current_room or "chamber"
            return f"You enter the {room}. The air is thick with dust and the smell of ancient stone."

        # Action results
        if "attacks" in prompt_lower and "hits" in prompt_lower:
            return "The blow lands true! Your enemy staggers from the impact."
        if "attacks" in prompt_lower and "misses" in prompt_lower:
            return "The attack goes wide, finding only empty air."

        # Player input handling
        if "[player says]" in prompt_lower:
            player_text = prompt.split("[Player says]:")[-1].strip().lower()

            # Look around
            if any(word in player_text for word in ["look", "examine", "search", "inspect"]):
                return "You scan your surroundings carefully, searching for anything of interest..."

            # Ask about something
            if any(word in player_text for word in ["what", "who", "where", "why", "how"]):
                return "The ancient stones hold many secrets. Perhaps exploring further will reveal answers."

            # Greetings
            if any(word in player_text for word in ["hello", "hi", "greetings", "hey"]):
                return "The dungeon echoes your words back at you. No response comes."

            # Actions
            if any(word in player_text for word in ["attack", "fight", "hit", "strike"]):
                if self.context.combat_active:
                    return "Choose your target from the menu to attack!"
                return "There's nothing to fight here... yet."

            if any(word in player_text for word in ["rest", "sleep", "heal"]):
                return "Use the Rest option from the menu to recover your strength."

            if any(word in player_text for word in ["north", "south", "east", "west", "go", "move"]):
                return "Use the directional options to move through the dungeon."

            # Default
            return "The DM ponders your words... Try using the menu options or ask something specific about your surroundings."

        # Default narration
        return "The dungeon awaits your next move..."


# Singleton instance for game-wide use
_ai_dm: Optional[AIDM] = None


def get_ai_dm(backend: str = "local") -> AIDM:
    """Get or create the AI DM instance."""
    global _ai_dm
    if _ai_dm is None:
        backend_enum = AIBackend(backend.lower())
        _ai_dm = AIDM(backend_enum)
    return _ai_dm


def set_ai_dm_backend(backend: str):
    """Change the AI DM backend."""
    global _ai_dm
    backend_enum = AIBackend(backend.lower())
    _ai_dm = AIDM(backend_enum)
