#!/usr/bin/env python3
"""
D&D 5e Text-Based RPG
Run this file to start the game.
"""

import sys
import os

# Ensure we can import the gamer package
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gamer.main import main

if __name__ == "__main__":
    main()
