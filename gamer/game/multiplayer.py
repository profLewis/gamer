"""
Multiplayer support for D&D 5e Text-Based RPG.

Supports multiple players joining a game session via:
1. Shared game state file (for local/network file systems)
2. Simple socket-based server (for network play)

Players can join by:
- Session ID (game name)
- Connecting to a host's IP:port
"""

import os
import json
import time
import socket
import threading
import fcntl
from pathlib import Path
from typing import Dict, List, Optional, Callable, Any
from dataclasses import dataclass, asdict, field
from enum import Enum
from datetime import datetime


class PlayerRole(Enum):
    """Role of a player in multiplayer."""
    HOST = "host"       # Controls DM, manages game state
    PLAYER = "player"   # Controls their character(s)
    SPECTATOR = "spectator"  # Can watch but not act


@dataclass
class MultiplayerPlayer:
    """Represents a connected player."""
    player_id: str
    name: str
    role: PlayerRole
    character_ids: List[str] = field(default_factory=list)
    last_seen: str = ""
    ready: bool = False

    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "name": self.name,
            "role": self.role.value,
            "character_ids": self.character_ids,
            "last_seen": self.last_seen,
            "ready": self.ready
        }

    @classmethod
    def from_dict(cls, data: dict) -> 'MultiplayerPlayer':
        return cls(
            player_id=data["player_id"],
            name=data["name"],
            role=PlayerRole(data["role"]),
            character_ids=data.get("character_ids", []),
            last_seen=data.get("last_seen", ""),
            ready=data.get("ready", False)
        )


@dataclass
class GameAction:
    """An action taken by a player."""
    action_id: str
    player_id: str
    action_type: str
    action_data: Dict[str, Any]
    timestamp: str
    processed: bool = False

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> 'GameAction':
        return cls(**data)


@dataclass
class MultiplayerState:
    """Shared state for multiplayer games."""
    session_id: str
    host_id: str
    players: Dict[str, MultiplayerPlayer] = field(default_factory=dict)
    pending_actions: List[GameAction] = field(default_factory=list)
    game_state: Dict[str, Any] = field(default_factory=dict)
    current_turn_player: Optional[str] = None
    waiting_for_input: bool = False
    last_update: str = ""
    messages: List[Dict[str, str]] = field(default_factory=list)  # Chat/notifications

    def to_dict(self) -> dict:
        return {
            "session_id": self.session_id,
            "host_id": self.host_id,
            "players": {k: v.to_dict() for k, v in self.players.items()},
            "pending_actions": [a.to_dict() for a in self.pending_actions],
            "game_state": self.game_state,
            "current_turn_player": self.current_turn_player,
            "waiting_for_input": self.waiting_for_input,
            "last_update": self.last_update,
            "messages": self.messages[-50:]  # Keep last 50 messages
        }

    @classmethod
    def from_dict(cls, data: dict) -> 'MultiplayerState':
        return cls(
            session_id=data["session_id"],
            host_id=data["host_id"],
            players={k: MultiplayerPlayer.from_dict(v) for k, v in data.get("players", {}).items()},
            pending_actions=[GameAction.from_dict(a) for a in data.get("pending_actions", [])],
            game_state=data.get("game_state", {}),
            current_turn_player=data.get("current_turn_player"),
            waiting_for_input=data.get("waiting_for_input", False),
            last_update=data.get("last_update", ""),
            messages=data.get("messages", [])
        )


class SharedFileMultiplayer:
    """
    Multiplayer implementation using a shared file.
    Works on local networks with shared file systems (NFS, SMB, etc.)
    """

    MULTIPLAYER_DIR = Path.home() / ".dnd_multiplayer"
    POLL_INTERVAL = 0.5  # seconds
    TIMEOUT = 30  # seconds before player considered disconnected

    def __init__(self, player_name: str):
        self.player_id = f"{player_name}_{int(time.time() * 1000)}"
        self.player_name = player_name
        self.session_id: Optional[str] = None
        self.role: PlayerRole = PlayerRole.PLAYER
        self.state: Optional[MultiplayerState] = None
        self.running = False
        self._poll_thread: Optional[threading.Thread] = None
        self._on_state_change: Optional[Callable[[MultiplayerState], None]] = None
        self._on_action_received: Optional[Callable[[GameAction], None]] = None

        # Ensure multiplayer directory exists
        self.MULTIPLAYER_DIR.mkdir(exist_ok=True)

    def _get_session_file(self, session_id: str) -> Path:
        return self.MULTIPLAYER_DIR / f"{session_id}.json"

    def _get_lock_file(self, session_id: str) -> Path:
        return self.MULTIPLAYER_DIR / f"{session_id}.lock"

    def _read_state(self) -> Optional[MultiplayerState]:
        """Read the current multiplayer state."""
        if not self.session_id:
            return None

        session_file = self._get_session_file(self.session_id)
        if not session_file.exists():
            return None

        try:
            with open(session_file, 'r') as f:
                data = json.load(f)
                return MultiplayerState.from_dict(data)
        except (json.JSONDecodeError, IOError):
            return None

    def _write_state(self, state: MultiplayerState) -> bool:
        """Write the multiplayer state with file locking."""
        if not self.session_id:
            return False

        session_file = self._get_session_file(self.session_id)
        lock_file = self._get_lock_file(self.session_id)

        try:
            # Create lock file if it doesn't exist
            lock_file.touch(exist_ok=True)

            with open(lock_file, 'w') as lock:
                # Acquire exclusive lock
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
                try:
                    state.last_update = datetime.now().isoformat()
                    with open(session_file, 'w') as f:
                        json.dump(state.to_dict(), f, indent=2)
                    return True
                finally:
                    fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
        except IOError as e:
            print(f"Error writing state: {e}")
            return False

    def _poll_loop(self):
        """Background thread to poll for state changes."""
        last_update = ""
        while self.running:
            new_state = self._read_state()
            if new_state and new_state.last_update != last_update:
                last_update = new_state.last_update
                self.state = new_state

                # Check for actions meant for us
                for action in new_state.pending_actions:
                    if not action.processed and action.player_id != self.player_id:
                        if self._on_action_received:
                            self._on_action_received(action)

                if self._on_state_change:
                    self._on_state_change(new_state)

            time.sleep(self.POLL_INTERVAL)

    def host_game(self, session_name: str) -> str:
        """
        Host a new multiplayer game.

        Returns the session ID other players can use to join.
        """
        self.session_id = session_name.replace(" ", "_").lower()
        self.role = PlayerRole.HOST

        # Create initial state
        self.state = MultiplayerState(
            session_id=self.session_id,
            host_id=self.player_id,
            players={
                self.player_id: MultiplayerPlayer(
                    player_id=self.player_id,
                    name=self.player_name,
                    role=PlayerRole.HOST,
                    last_seen=datetime.now().isoformat(),
                    ready=True
                )
            }
        )

        if not self._write_state(self.state):
            raise RuntimeError("Failed to create multiplayer session")

        # Start polling
        self.running = True
        self._poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._poll_thread.start()

        return self.session_id

    def join_game(self, session_id: str) -> bool:
        """Join an existing multiplayer game."""
        self.session_id = session_id
        self.role = PlayerRole.PLAYER

        # Read existing state
        self.state = self._read_state()
        if not self.state:
            return False

        # Add ourselves
        self.state.players[self.player_id] = MultiplayerPlayer(
            player_id=self.player_id,
            name=self.player_name,
            role=PlayerRole.PLAYER,
            last_seen=datetime.now().isoformat()
        )

        # Add join message
        self.state.messages.append({
            "type": "system",
            "text": f"{self.player_name} has joined the game!",
            "timestamp": datetime.now().isoformat()
        })

        if not self._write_state(self.state):
            return False

        # Start polling
        self.running = True
        self._poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._poll_thread.start()

        return True

    def list_sessions(self) -> List[Dict[str, Any]]:
        """List available multiplayer sessions."""
        sessions = []
        for session_file in self.MULTIPLAYER_DIR.glob("*.json"):
            try:
                with open(session_file, 'r') as f:
                    data = json.load(f)
                    state = MultiplayerState.from_dict(data)

                    # Check if session is still active
                    last_update = datetime.fromisoformat(state.last_update)
                    age = (datetime.now() - last_update).total_seconds()

                    if age < 3600:  # Sessions active in last hour
                        sessions.append({
                            "session_id": state.session_id,
                            "host": state.players.get(state.host_id, {}).name if state.host_id in state.players else "Unknown",
                            "player_count": len(state.players),
                            "last_active": state.last_update
                        })
            except (json.JSONDecodeError, IOError):
                continue

        return sessions

    def send_action(self, action_type: str, action_data: Dict[str, Any]) -> bool:
        """Send an action to the game."""
        if not self.state:
            return False

        action = GameAction(
            action_id=f"{self.player_id}_{int(time.time() * 1000)}",
            player_id=self.player_id,
            action_type=action_type,
            action_data=action_data,
            timestamp=datetime.now().isoformat()
        )

        self.state.pending_actions.append(action)
        return self._write_state(self.state)

    def send_message(self, text: str) -> bool:
        """Send a chat message."""
        if not self.state:
            return False

        self.state.messages.append({
            "type": "chat",
            "player": self.player_name,
            "text": text,
            "timestamp": datetime.now().isoformat()
        })
        return self._write_state(self.state)

    def update_game_state(self, game_data: Dict[str, Any]) -> bool:
        """Update the shared game state (host only)."""
        if not self.state or self.role != PlayerRole.HOST:
            return False

        self.state.game_state = game_data
        return self._write_state(self.state)

    def set_current_turn(self, player_id: Optional[str], waiting: bool = True) -> bool:
        """Set whose turn it is (host only)."""
        if not self.state or self.role != PlayerRole.HOST:
            return False

        self.state.current_turn_player = player_id
        self.state.waiting_for_input = waiting
        return self._write_state(self.state)

    def mark_action_processed(self, action_id: str) -> bool:
        """Mark an action as processed (host only)."""
        if not self.state or self.role != PlayerRole.HOST:
            return False

        for action in self.state.pending_actions:
            if action.action_id == action_id:
                action.processed = True

        # Clean up old processed actions
        self.state.pending_actions = [
            a for a in self.state.pending_actions
            if not a.processed or
            (datetime.now() - datetime.fromisoformat(a.timestamp)).total_seconds() < 60
        ]

        return self._write_state(self.state)

    def assign_character(self, character_id: str) -> bool:
        """Assign a character to this player."""
        if not self.state:
            return False

        if self.player_id in self.state.players:
            self.state.players[self.player_id].character_ids.append(character_id)
            return self._write_state(self.state)
        return False

    def set_ready(self, ready: bool = True) -> bool:
        """Mark this player as ready."""
        if not self.state:
            return False

        if self.player_id in self.state.players:
            self.state.players[self.player_id].ready = ready
            return self._write_state(self.state)
        return False

    def all_players_ready(self) -> bool:
        """Check if all players are ready."""
        if not self.state:
            return False
        return all(p.ready for p in self.state.players.values())

    def is_my_turn(self) -> bool:
        """Check if it's this player's turn."""
        if not self.state:
            return False
        return (self.state.current_turn_player == self.player_id and
                self.state.waiting_for_input)

    def heartbeat(self):
        """Update last_seen timestamp."""
        if self.state and self.player_id in self.state.players:
            self.state.players[self.player_id].last_seen = datetime.now().isoformat()
            self._write_state(self.state)

    def get_active_players(self) -> List[MultiplayerPlayer]:
        """Get list of active players (seen in last TIMEOUT seconds)."""
        if not self.state:
            return []

        active = []
        now = datetime.now()
        for player in self.state.players.values():
            if player.last_seen:
                last_seen = datetime.fromisoformat(player.last_seen)
                if (now - last_seen).total_seconds() < self.TIMEOUT:
                    active.append(player)
        return active

    def on_state_change(self, callback: Callable[[MultiplayerState], None]):
        """Register callback for state changes."""
        self._on_state_change = callback

    def on_action_received(self, callback: Callable[[GameAction], None]):
        """Register callback for received actions."""
        self._on_action_received = callback

    def leave_game(self):
        """Leave the current game."""
        if self.state and self.player_id in self.state.players:
            self.state.messages.append({
                "type": "system",
                "text": f"{self.player_name} has left the game.",
                "timestamp": datetime.now().isoformat()
            })
            del self.state.players[self.player_id]
            self._write_state(self.state)

        self.running = False
        if self._poll_thread:
            self._poll_thread.join(timeout=1)

        self.session_id = None
        self.state = None

    def close_session(self):
        """Close the session (host only)."""
        if self.role == PlayerRole.HOST and self.session_id:
            session_file = self._get_session_file(self.session_id)
            lock_file = self._get_lock_file(self.session_id)

            try:
                if session_file.exists():
                    session_file.unlink()
                if lock_file.exists():
                    lock_file.unlink()
            except IOError:
                pass

        self.running = False
        if self._poll_thread:
            self._poll_thread.join(timeout=1)


class SocketMultiplayer:
    """
    Multiplayer implementation using TCP sockets.
    Works across networks without shared file systems.
    """

    DEFAULT_PORT = 5555
    BUFFER_SIZE = 65536

    def __init__(self, player_name: str):
        self.player_id = f"{player_name}_{int(time.time() * 1000)}"
        self.player_name = player_name
        self.role: PlayerRole = PlayerRole.PLAYER
        self.state: Optional[MultiplayerState] = None

        self.server_socket: Optional[socket.socket] = None
        self.client_socket: Optional[socket.socket] = None
        self.clients: Dict[str, socket.socket] = {}

        self.running = False
        self._threads: List[threading.Thread] = []
        self._on_state_change: Optional[Callable[[MultiplayerState], None]] = None
        self._on_action_received: Optional[Callable[[GameAction], None]] = None
        self._lock = threading.Lock()

    def host_game(self, port: int = DEFAULT_PORT) -> str:
        """
        Host a multiplayer game.

        Returns the connection info (IP:port) for other players.
        """
        self.role = PlayerRole.HOST

        # Get local IP
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)

        # Create server socket
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind(('0.0.0.0', port))
        self.server_socket.listen(5)

        # Initialize state
        self.state = MultiplayerState(
            session_id=f"{local_ip}:{port}",
            host_id=self.player_id,
            players={
                self.player_id: MultiplayerPlayer(
                    player_id=self.player_id,
                    name=self.player_name,
                    role=PlayerRole.HOST,
                    last_seen=datetime.now().isoformat(),
                    ready=True
                )
            }
        )

        # Start accepting connections
        self.running = True
        accept_thread = threading.Thread(target=self._accept_connections, daemon=True)
        accept_thread.start()
        self._threads.append(accept_thread)

        return f"{local_ip}:{port}"

    def _accept_connections(self):
        """Accept incoming connections."""
        while self.running and self.server_socket:
            try:
                self.server_socket.settimeout(1.0)
                client_socket, address = self.server_socket.accept()

                # Start client handler thread
                handler = threading.Thread(
                    target=self._handle_client,
                    args=(client_socket, address),
                    daemon=True
                )
                handler.start()
                self._threads.append(handler)
            except socket.timeout:
                continue
            except OSError:
                break

    def _handle_client(self, client_socket: socket.socket, address):
        """Handle a connected client."""
        player_id = None
        try:
            while self.running:
                client_socket.settimeout(1.0)
                try:
                    data = client_socket.recv(self.BUFFER_SIZE)
                    if not data:
                        break

                    message = json.loads(data.decode('utf-8'))
                    msg_type = message.get('type')

                    if msg_type == 'join':
                        player_id = message['player_id']
                        with self._lock:
                            self.clients[player_id] = client_socket
                            self.state.players[player_id] = MultiplayerPlayer(
                                player_id=player_id,
                                name=message['player_name'],
                                role=PlayerRole.PLAYER,
                                last_seen=datetime.now().isoformat()
                            )
                            self.state.messages.append({
                                "type": "system",
                                "text": f"{message['player_name']} has joined!",
                                "timestamp": datetime.now().isoformat()
                            })
                        self._broadcast_state()

                    elif msg_type == 'action':
                        action = GameAction.from_dict(message['action'])
                        with self._lock:
                            self.state.pending_actions.append(action)
                        if self._on_action_received:
                            self._on_action_received(action)
                        self._broadcast_state()

                    elif msg_type == 'message':
                        with self._lock:
                            self.state.messages.append(message['message'])
                        self._broadcast_state()

                    elif msg_type == 'ready':
                        with self._lock:
                            if message['player_id'] in self.state.players:
                                self.state.players[message['player_id']].ready = message['ready']
                        self._broadcast_state()

                    elif msg_type == 'heartbeat':
                        with self._lock:
                            if message['player_id'] in self.state.players:
                                self.state.players[message['player_id']].last_seen = datetime.now().isoformat()

                except socket.timeout:
                    continue
                except json.JSONDecodeError:
                    continue

        except Exception as e:
            print(f"Client error: {e}")

        finally:
            if player_id:
                with self._lock:
                    if player_id in self.clients:
                        del self.clients[player_id]
                    if self.state and player_id in self.state.players:
                        name = self.state.players[player_id].name
                        del self.state.players[player_id]
                        self.state.messages.append({
                            "type": "system",
                            "text": f"{name} has left the game.",
                            "timestamp": datetime.now().isoformat()
                        })
                self._broadcast_state()
            client_socket.close()

    def _broadcast_state(self):
        """Send current state to all clients."""
        if not self.state:
            return

        with self._lock:
            self.state.last_update = datetime.now().isoformat()
            data = json.dumps({
                'type': 'state',
                'state': self.state.to_dict()
            }).encode('utf-8')

        dead_clients = []
        for player_id, client in self.clients.items():
            try:
                client.sendall(data)
            except (OSError, BrokenPipeError):
                dead_clients.append(player_id)

        for player_id in dead_clients:
            with self._lock:
                if player_id in self.clients:
                    del self.clients[player_id]

    def join_game(self, host_address: str) -> bool:
        """Join a game by host address (IP:port)."""
        try:
            if ':' in host_address:
                host, port = host_address.rsplit(':', 1)
                port = int(port)
            else:
                host = host_address
                port = self.DEFAULT_PORT

            self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.client_socket.connect((host, port))

            # Send join message
            join_msg = json.dumps({
                'type': 'join',
                'player_id': self.player_id,
                'player_name': self.player_name
            }).encode('utf-8')
            self.client_socket.sendall(join_msg)

            # Start receive thread
            self.running = True
            recv_thread = threading.Thread(target=self._receive_loop, daemon=True)
            recv_thread.start()
            self._threads.append(recv_thread)

            # Start heartbeat thread
            hb_thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
            hb_thread.start()
            self._threads.append(hb_thread)

            return True

        except Exception as e:
            print(f"Failed to join: {e}")
            return False

    def _receive_loop(self):
        """Receive messages from server."""
        while self.running and self.client_socket:
            try:
                self.client_socket.settimeout(1.0)
                data = self.client_socket.recv(self.BUFFER_SIZE)
                if not data:
                    break

                message = json.loads(data.decode('utf-8'))
                if message['type'] == 'state':
                    self.state = MultiplayerState.from_dict(message['state'])
                    if self._on_state_change:
                        self._on_state_change(self.state)

            except socket.timeout:
                continue
            except json.JSONDecodeError:
                continue
            except OSError:
                break

    def _heartbeat_loop(self):
        """Send periodic heartbeats."""
        while self.running and self.client_socket:
            try:
                msg = json.dumps({
                    'type': 'heartbeat',
                    'player_id': self.player_id
                }).encode('utf-8')
                self.client_socket.sendall(msg)
            except OSError:
                break
            time.sleep(5)

    def send_action(self, action_type: str, action_data: Dict[str, Any]) -> bool:
        """Send an action."""
        action = GameAction(
            action_id=f"{self.player_id}_{int(time.time() * 1000)}",
            player_id=self.player_id,
            action_type=action_type,
            action_data=action_data,
            timestamp=datetime.now().isoformat()
        )

        if self.role == PlayerRole.HOST:
            with self._lock:
                self.state.pending_actions.append(action)
            self._broadcast_state()
            return True
        elif self.client_socket:
            try:
                msg = json.dumps({
                    'type': 'action',
                    'action': action.to_dict()
                }).encode('utf-8')
                self.client_socket.sendall(msg)
                return True
            except OSError:
                return False
        return False

    def send_message(self, text: str) -> bool:
        """Send a chat message."""
        message = {
            "type": "chat",
            "player": self.player_name,
            "text": text,
            "timestamp": datetime.now().isoformat()
        }

        if self.role == PlayerRole.HOST:
            with self._lock:
                self.state.messages.append(message)
            self._broadcast_state()
            return True
        elif self.client_socket:
            try:
                msg = json.dumps({
                    'type': 'message',
                    'message': message
                }).encode('utf-8')
                self.client_socket.sendall(msg)
                return True
            except OSError:
                return False
        return False

    def set_ready(self, ready: bool = True) -> bool:
        """Mark ready."""
        if self.role == PlayerRole.HOST:
            with self._lock:
                if self.player_id in self.state.players:
                    self.state.players[self.player_id].ready = ready
            self._broadcast_state()
            return True
        elif self.client_socket:
            try:
                msg = json.dumps({
                    'type': 'ready',
                    'player_id': self.player_id,
                    'ready': ready
                }).encode('utf-8')
                self.client_socket.sendall(msg)
                return True
            except OSError:
                return False
        return False

    def update_game_state(self, game_data: Dict[str, Any]) -> bool:
        """Update game state (host only)."""
        if self.role != PlayerRole.HOST:
            return False

        with self._lock:
            self.state.game_state = game_data
        self._broadcast_state()
        return True

    def set_current_turn(self, player_id: Optional[str], waiting: bool = True) -> bool:
        """Set current turn (host only)."""
        if self.role != PlayerRole.HOST:
            return False

        with self._lock:
            self.state.current_turn_player = player_id
            self.state.waiting_for_input = waiting
        self._broadcast_state()
        return True

    def on_state_change(self, callback: Callable[[MultiplayerState], None]):
        """Register state change callback."""
        self._on_state_change = callback

    def on_action_received(self, callback: Callable[[GameAction], None]):
        """Register action received callback."""
        self._on_action_received = callback

    def is_my_turn(self) -> bool:
        """Check if it's this player's turn."""
        if not self.state:
            return False
        return (self.state.current_turn_player == self.player_id and
                self.state.waiting_for_input)

    def all_players_ready(self) -> bool:
        """Check if all players ready."""
        if not self.state:
            return False
        return all(p.ready for p in self.state.players.values())

    def close(self):
        """Close connections."""
        self.running = False

        if self.client_socket:
            try:
                self.client_socket.close()
            except OSError:
                pass

        if self.server_socket:
            try:
                self.server_socket.close()
            except OSError:
                pass

        for client in self.clients.values():
            try:
                client.close()
            except OSError:
                pass

        for thread in self._threads:
            thread.join(timeout=1)


def get_local_ip() -> str:
    """Get the local IP address for network play."""
    try:
        # Create a socket to determine the local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return socket.gethostbyname(socket.gethostname())
