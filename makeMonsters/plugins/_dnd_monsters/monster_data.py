"""
D&D Monster Definitions

Contains monster configurations including morphs, accessories, skins, and size categories.
"""

# Monster categories for UI organization
MONSTER_CATEGORIES = {
    'Humanoid': ['Orc', 'Half-Orc', 'Goblin', 'Hobgoblin', 'Bugbear', 'Kobold', 'Gnoll'],
    'Large Humanoid': ['Ogre', 'Troll', 'Hill Giant', 'Frost Giant', 'Fire Giant', 'Stone Giant', 'Cloud Giant', 'Storm Giant'],
    'Near-Humanoid': ['Tiefling', 'Dragonborn', 'Lizardfolk', 'Minotaur', 'Satyr'],
}

# Detailed monster definitions
MONSTERS = {
    # === HUMANOID ===
    'Orc': {
        'size': 'Medium',
        'morphs': {
            'head/head-orcish-brow': 1.0,
            'jaw/jaw-underbite': 0.8,
            'nose/nose-flat': 0.7,
            'ears/ears-pointed-small': 0.5,
            'body/body-hulking': 0.6,
        },
        'accessories': {
            'tusks': 'orc-large',
        },
        'skins': ['orc-green', 'orc-gray', 'orc-brown'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Half-Orc': {
        'size': 'Medium',
        'morphs': {
            'head/head-orcish-brow': 0.5,
            'jaw/jaw-underbite': 0.4,
            'nose/nose-flat': 0.3,
            'body/body-hulking': 0.4,
        },
        'accessories': {
            'tusks': 'orc-small',
        },
        'skins': ['halforc-green', 'halforc-gray', 'halforc-tan'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Goblin': {
        'size': 'Small',
        'morphs': {
            'head/head-goblinoid': 1.0,
            'ears/ears-pointed-large': 1.0,
            'nose/nose-pointed': 0.6,
            'body/body-scrawny': 0.7,
        },
        'accessories': {},
        'skins': ['goblin-yellow', 'goblin-orange', 'goblin-green'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Hobgoblin': {
        'size': 'Medium',
        'morphs': {
            'head/head-goblinoid': 0.5,
            'ears/ears-pointed-large': 0.7,
            'nose/nose-flat': 0.4,
            'body/body-athletic': 0.6,
        },
        'accessories': {},
        'skins': ['hobgoblin-red', 'hobgoblin-orange', 'hobgoblin-brown'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Bugbear': {
        'size': 'Medium',
        'morphs': {
            'head/head-goblinoid': 0.3,
            'ears/ears-pointed-large': 0.8,
            'body/body-hulking': 0.8,
            'body/body-hunched': 0.4,
        },
        'accessories': {},
        'skins': ['bugbear-brown', 'bugbear-tan', 'bugbear-gray'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Kobold': {
        'size': 'Small',
        'morphs': {
            'head/head-reptilian': 0.8,
            'ears/ears-pointed-small': 0.6,
            'body/body-scrawny': 0.9,
        },
        'accessories': {
            'tail': 'kobold',
        },
        'skins': ['kobold-rust', 'kobold-red', 'kobold-brown'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Gnoll': {
        'size': 'Medium',
        'morphs': {
            'head/head-hyena': 1.0,
            'ears/ears-canine': 0.8,
            'body/body-hunched': 0.5,
            'body/body-athletic': 0.4,
        },
        'accessories': {},
        'skins': ['gnoll-tan', 'gnoll-spotted', 'gnoll-dark'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    # === LARGE HUMANOID ===
    'Ogre': {
        'size': 'Large',
        'morphs': {
            'head/head-brutish': 1.0,
            'jaw/jaw-underbite': 0.6,
            'body/body-hulking': 1.0,
            'body/body-fat': 0.5,
        },
        'accessories': {},
        'skins': ['ogre-yellow', 'ogre-gray', 'ogre-green'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Troll': {
        'size': 'Large',
        'morphs': {
            'head/head-brutish': 0.7,
            'nose/nose-long': 0.8,
            'body/body-lanky': 1.0,
            'body/body-hunched': 0.6,
        },
        'accessories': {},
        'skins': ['troll-green', 'troll-gray', 'troll-moss'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Hill Giant': {
        'size': 'Huge',
        'morphs': {
            'head/head-brutish': 0.8,
            'body/body-hulking': 1.0,
            'body/body-fat': 0.7,
        },
        'accessories': {},
        'skins': ['giant-tan', 'giant-brown', 'giant-ruddy'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Frost Giant': {
        'size': 'Huge',
        'morphs': {
            'head/head-nordic': 0.6,
            'body/body-hulking': 1.0,
        },
        'accessories': {},
        'skins': ['giant-blue', 'giant-ice', 'giant-pale'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Fire Giant': {
        'size': 'Huge',
        'morphs': {
            'head/head-dwarven': 0.5,
            'body/body-hulking': 1.0,
        },
        'accessories': {},
        'skins': ['giant-coal', 'giant-ember', 'giant-obsidian'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Stone Giant': {
        'size': 'Huge',
        'morphs': {
            'head/head-angular': 0.7,
            'body/body-hulking': 0.9,
            'body/body-lanky': 0.3,
        },
        'accessories': {},
        'skins': ['giant-gray', 'giant-granite', 'giant-slate'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Cloud Giant': {
        'size': 'Huge',
        'morphs': {
            'head/head-noble': 0.6,
            'body/body-hulking': 0.8,
        },
        'accessories': {},
        'skins': ['giant-pale-blue', 'giant-white', 'giant-silver'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Storm Giant': {
        'size': 'Huge',
        'morphs': {
            'head/head-noble': 0.8,
            'body/body-hulking': 1.0,
            'body/body-athletic': 0.5,
        },
        'accessories': {},
        'skins': ['giant-purple', 'giant-blue-green', 'giant-bronze'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    # === NEAR-HUMANOID ===
    'Tiefling': {
        'size': 'Medium',
        'morphs': {
            'head/head-angular': 0.3,
        },
        'accessories': {
            'horns': 'tiefling-curved',
            'tail': 'tiefling-thin',
        },
        'skins': ['tiefling-red', 'tiefling-purple', 'tiefling-blue', 'tiefling-lavender'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Dragonborn': {
        'size': 'Medium',
        'morphs': {
            'head/head-draconic': 1.0,
            'body/body-athletic': 0.5,
        },
        'accessories': {
            'tail': 'dragonborn-thick',
        },
        'skins': [
            'dragonborn-red', 'dragonborn-blue', 'dragonborn-green',
            'dragonborn-white', 'dragonborn-black',
            'dragonborn-gold', 'dragonborn-silver', 'dragonborn-bronze',
            'dragonborn-brass', 'dragonborn-copper',
        ],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Lizardfolk': {
        'size': 'Medium',
        'morphs': {
            'head/head-reptilian': 1.0,
            'body/body-athletic': 0.4,
        },
        'accessories': {
            'tail': 'lizardfolk',
        },
        'skins': ['lizardfolk-green', 'lizardfolk-brown', 'lizardfolk-gray'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Minotaur': {
        'size': 'Large',
        'morphs': {
            'head/head-bovine': 1.0,
            'body/body-hulking': 0.9,
        },
        'accessories': {
            'horns': 'minotaur-bull',
        },
        'skins': ['minotaur-brown', 'minotaur-black', 'minotaur-gray'],
        'muscle_target': 'torso/torso-muscle-scale',
    },

    'Satyr': {
        'size': 'Medium',
        'morphs': {
            'ears/ears-pointed-small': 0.5,
            'body/body-athletic': 0.3,
        },
        'accessories': {
            'horns': 'satyr-small',
        },
        'skins': ['satyr-tan', 'satyr-olive', 'satyr-ruddy'],
        'muscle_target': 'torso/torso-muscle-scale',
    },
}


def get_monster(name):
    """Get monster definition by name."""
    return MONSTERS.get(name)


def get_category_monsters(category):
    """Get list of monsters in a category."""
    return MONSTER_CATEGORIES.get(category, [])


def get_all_categories():
    """Get list of all monster categories."""
    return list(MONSTER_CATEGORIES.keys())
