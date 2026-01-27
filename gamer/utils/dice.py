"""Dice rolling utilities for D&D 5e."""

import random
from typing import List, Tuple


def roll_dice(num_dice: int, die_size: int, modifier: int = 0) -> Tuple[int, List[int]]:
    """
    Roll dice and return total and individual rolls.

    Args:
        num_dice: Number of dice to roll
        die_size: Size of dice (e.g., 6 for d6)
        modifier: Flat modifier to add to total

    Returns:
        Tuple of (total, list of individual rolls)
    """
    rolls = [random.randint(1, die_size) for _ in range(num_dice)]
    total = sum(rolls) + modifier
    return total, rolls


def roll(notation: str) -> Tuple[int, List[int], int]:
    """
    Roll dice using standard notation (e.g., '2d6+3', '1d20-1', '4d6').

    Args:
        notation: Dice notation string

    Returns:
        Tuple of (total, individual rolls, modifier)
    """
    notation = notation.lower().replace(' ', '')

    # Parse modifier
    modifier = 0
    if '+' in notation:
        parts = notation.split('+')
        notation = parts[0]
        modifier = int(parts[1])
    elif '-' in notation:
        parts = notation.split('-')
        notation = parts[0]
        modifier = -int(parts[1])

    # Parse dice
    if 'd' in notation:
        num_dice, die_size = notation.split('d')
        num_dice = int(num_dice) if num_dice else 1
        die_size = int(die_size)
    else:
        # Just a number, no dice
        return int(notation) + modifier, [], modifier

    total, rolls = roll_dice(num_dice, die_size, modifier)
    return total, rolls, modifier


def d4(num: int = 1, modifier: int = 0) -> int:
    """Roll d4(s) and return total."""
    total, _ = roll_dice(num, 4, modifier)
    return total


def d6(num: int = 1, modifier: int = 0) -> int:
    """Roll d6(s) and return total."""
    total, _ = roll_dice(num, 6, modifier)
    return total


def d8(num: int = 1, modifier: int = 0) -> int:
    """Roll d8(s) and return total."""
    total, _ = roll_dice(num, 8, modifier)
    return total


def d10(num: int = 1, modifier: int = 0) -> int:
    """Roll d10(s) and return total."""
    total, _ = roll_dice(num, 10, modifier)
    return total


def d12(num: int = 1, modifier: int = 0) -> int:
    """Roll d12(s) and return total."""
    total, _ = roll_dice(num, 12, modifier)
    return total


def d20(num: int = 1, modifier: int = 0) -> int:
    """Roll d20(s) and return total."""
    total, _ = roll_dice(num, 20, modifier)
    return total


def d100(num: int = 1, modifier: int = 0) -> int:
    """Roll d100(s) and return total."""
    total, _ = roll_dice(num, 100, modifier)
    return total


def roll_with_advantage() -> Tuple[int, int, int]:
    """Roll 2d20, return (higher, roll1, roll2)."""
    roll1 = random.randint(1, 20)
    roll2 = random.randint(1, 20)
    return max(roll1, roll2), roll1, roll2


def roll_with_disadvantage() -> Tuple[int, int, int]:
    """Roll 2d20, return (lower, roll1, roll2)."""
    roll1 = random.randint(1, 20)
    roll2 = random.randint(1, 20)
    return min(roll1, roll2), roll1, roll2


def roll_ability_scores() -> List[int]:
    """Roll ability scores using 4d6 drop lowest method."""
    scores = []
    for _ in range(6):
        rolls = [random.randint(1, 6) for _ in range(4)]
        rolls.sort(reverse=True)
        scores.append(sum(rolls[:3]))  # Drop lowest
    return scores


def standard_array() -> List[int]:
    """Return the standard array for ability scores."""
    return [15, 14, 13, 12, 10, 8]
