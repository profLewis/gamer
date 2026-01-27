# D&D 5e Monster Creator for MakeHuman

A MakeHuman plugin for creating humanoid D&D 5e monsters using custom morph targets, accessories, and skin materials.

## Supported Monsters

### Humanoid
Orc, Half-Orc, Goblin, Hobgoblin, Bugbear, Kobold, Gnoll

### Large Humanoid
Ogre, Troll, Hill Giant, Frost Giant, Fire Giant, Stone Giant, Cloud Giant, Storm Giant

### Near-Humanoid
Tiefling, Dragonborn, Lizardfolk, Minotaur, Satyr

## Installation

### Automatic
```bash
python install.py
```

### Options
```bash
python install.py --path /custom/path  # Custom install path
python install.py --list               # List detected installations
python install.py --uninstall          # Remove plugin files
```

## Usage

1. Open MakeHuman
2. Go to **Utilities > D&D Monsters**
3. Select monster category and type
4. Adjust sliders (Feature Intensity, Muscle Mass, Height)
5. Toggle accessories (horns, tail, tusks)
6. Select skin variant
7. Click **Apply Monster**
8. Export via **File > Export**

## Free 3D Model Resources

- [mz4250 on Thingiverse](https://www.thingiverse.com/mz4250/designs) - 6,000+ free D&D models
- [mz4250 on Printables](https://www.printables.com/@MZ4250) - Updated collection
- [CGTrader](https://www.cgtrader.com/3d-models/orc) - Free/premium orcs, goblins, dragonborn
- [TurboSquid](https://www.turbosquid.com/3d-model/dungeons-and-dragons) - D&D models in FBX/OBJ
- [Meshy](https://www.meshy.ai/tags/tiefling) - Free models + AI generation

## Creating Morph Targets

1. Install Blender + MakeTarget addon
2. Load MakeHuman base mesh
3. Sculpt desired morph
4. Export as `.target` file
5. Place in `data/targets/dnd-monsters/`

## License

Plugin provided as-is. D&D is a trademark of Wizards of the Coast.
Monster designs inspired by Open Gaming License SRD 5.1.
