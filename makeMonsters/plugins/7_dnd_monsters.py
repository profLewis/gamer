#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
D&D 5e Monster Creator Plugin for MakeHuman

Creates humanoid D&D monsters using morphs, accessories, and custom skins.
"""

import os
import gui3d
import gui
import log
from core import G

# Import monster data
try:
    from ._dnd_monsters import monster_data
    from ._dnd_monsters.monster_data import MONSTERS, MONSTER_CATEGORIES
except ImportError:
    # Fallback for development/testing
    import sys
    plugin_dir = os.path.dirname(__file__)
    sys.path.insert(0, plugin_dir)
    from _dnd_monsters import monster_data
    from _dnd_monsters.monster_data import MONSTERS, MONSTER_CATEGORIES


class DnDMonsterTaskView(gui3d.TaskView):
    """Main task view for the D&D Monster Creator plugin."""

    def __init__(self, category):
        gui3d.TaskView.__init__(self, category, 'D&D Monsters')

        self.human = G.app.selectedHuman

        # Left panel - Monster Selection
        selectBox = self.addLeftWidget(gui.GroupBox('Monster Type'))

        # Category selector
        self.categoryList = selectBox.addWidget(gui.ListView())
        self.categoryList.setData(list(MONSTER_CATEGORIES.keys()))
        self.categoryList.setCurrentRow(0)

        # Monster selector
        self.monsterList = selectBox.addWidget(gui.ListView())
        self._updateMonsterList()

        # Right panel - Customization
        customBox = self.addRightWidget(gui.GroupBox('Customization'))

        # Feature intensity slider
        self.featureSlider = customBox.addWidget(
            gui.Slider(value=1.0, min=0.0, max=1.5, label="Feature Intensity")
        )

        # Muscle slider
        self.muscleSlider = customBox.addWidget(
            gui.Slider(value=0.5, min=0.0, max=1.0, label="Muscle Mass")
        )

        # Height slider
        self.heightSlider = customBox.addWidget(
            gui.Slider(value=0.5, min=0.0, max=1.0, label="Height")
        )

        # Accessory toggles
        accessoryBox = self.addRightWidget(gui.GroupBox('Accessories'))

        self.hornsCheck = accessoryBox.addWidget(gui.CheckBox("Horns"))
        self.tailCheck = accessoryBox.addWidget(gui.CheckBox("Tail"))
        self.tusksCheck = accessoryBox.addWidget(gui.CheckBox("Tusks"))

        # Skin selection
        skinBox = self.addRightWidget(gui.GroupBox('Skin'))

        self.skinList = skinBox.addWidget(gui.ListView())
        self.skinList.setData(['Default', 'Variant 1', 'Variant 2'])

        # Action buttons
        buttonBox = self.addRightWidget(gui.GroupBox('Actions'))

        self.applyBtn = buttonBox.addWidget(gui.Button('Apply Monster'))
        self.resetBtn = buttonBox.addWidget(gui.Button('Reset'))
        self.savePresetBtn = buttonBox.addWidget(gui.Button('Save Preset'))

        # Connect signals
        self.categoryList.selectionChanged.connect(self._onCategoryChanged)
        self.monsterList.selectionChanged.connect(self._onMonsterChanged)
        self.applyBtn.clicked.connect(self._onApplyMonster)
        self.resetBtn.clicked.connect(self._onReset)
        self.savePresetBtn.clicked.connect(self._onSavePreset)

        self.featureSlider.valueChanged.connect(self._onSliderChanged)
        self.muscleSlider.valueChanged.connect(self._onSliderChanged)
        self.heightSlider.valueChanged.connect(self._onSliderChanged)

        self.hornsCheck.stateChanged.connect(self._onAccessoryChanged)
        self.tailCheck.stateChanged.connect(self._onAccessoryChanged)
        self.tusksCheck.stateChanged.connect(self._onAccessoryChanged)

        # State tracking
        self._currentMonster = None
        self._appliedMorphs = {}

    def _updateMonsterList(self):
        """Update monster list based on selected category."""
        category = self.categoryList.currentItem()
        if category and category in MONSTER_CATEGORIES:
            monsters = MONSTER_CATEGORIES[category]
            self.monsterList.setData(monsters)
            if monsters:
                self.monsterList.setCurrentRow(0)

    def _onCategoryChanged(self, item):
        """Handle category selection change."""
        self._updateMonsterList()

    def _onMonsterChanged(self, item):
        """Handle monster selection change."""
        if item:
            self._updateUIForMonster(item)

    def _updateUIForMonster(self, monster_name):
        """Update UI controls based on selected monster."""
        if monster_name not in MONSTERS:
            return

        monster = MONSTERS[monster_name]

        # Update accessory checkboxes based on monster defaults
        accessories = monster.get('accessories', {})
        self.hornsCheck.setChecked(accessories.get('horns', False))
        self.tailCheck.setChecked(accessories.get('tail', False))
        self.tusksCheck.setChecked(accessories.get('tusks', False))

        # Update skin options
        skins = monster.get('skins', ['Default'])
        self.skinList.setData(skins)
        self.skinList.setCurrentRow(0)

    def _onApplyMonster(self):
        """Apply the selected monster configuration."""
        monster_name = self.monsterList.currentItem()
        if not monster_name or monster_name not in MONSTERS:
            log.warning("No monster selected")
            return

        monster = MONSTERS[monster_name]
        self._currentMonster = monster_name

        log.message(f"Applying monster: {monster_name}")

        # Apply morphs
        self._applyMorphs(monster)

        # Apply accessories
        self._applyAccessories(monster)

        # Apply skin
        self._applySkin(monster)

        # Refresh the view
        self.human.applyAllTargets()
        gui3d.app.redraw()

    def _applyMorphs(self, monster):
        """Apply morph targets for the monster."""
        morphs = monster.get('morphs', {})
        intensity = self.featureSlider.getValue()
        muscle = self.muscleSlider.getValue()
        height = self.heightSlider.getValue()

        # Clear previous morphs
        for target_name in self._appliedMorphs:
            try:
                self.human.setDetail(target_name, 0)
            except Exception:
                pass
        self._appliedMorphs.clear()

        # Apply base morphs
        for target_name, base_value in morphs.items():
            value = base_value * intensity
            try:
                self.human.setDetail(target_name, value)
                self._appliedMorphs[target_name] = value
            except Exception as e:
                log.warning(f"Could not apply morph {target_name}: {e}")

        # Apply muscle modifier
        muscle_target = monster.get('muscle_target', 'torso/torso-muscle-scale')
        try:
            self.human.setDetail(muscle_target, muscle)
            self._appliedMorphs[muscle_target] = muscle
        except Exception:
            pass

        # Apply height modifier based on monster size
        size = monster.get('size', 'Medium')
        base_height = {'Small': 0.85, 'Medium': 1.0, 'Large': 1.3, 'Huge': 1.6}.get(size, 1.0)
        height_value = base_height * (0.8 + height * 0.4)  # 80% to 120% of base
        try:
            self.human.setDetail('measure/measure-height', height_value)
            self._appliedMorphs['measure/measure-height'] = height_value
        except Exception:
            pass

    def _applyAccessories(self, monster):
        """Apply accessories (horns, tail, tusks) for the monster."""
        accessories = monster.get('accessories', {})

        # Horns
        if self.hornsCheck.isChecked() and accessories.get('horns'):
            horn_type = accessories['horns']
            self._loadProxy(f'dnd-horns/{horn_type}')

        # Tail
        if self.tailCheck.isChecked() and accessories.get('tail'):
            tail_type = accessories['tail']
            self._loadProxy(f'dnd-tails/{tail_type}')

        # Tusks
        if self.tusksCheck.isChecked() and accessories.get('tusks'):
            tusk_type = accessories['tusks']
            self._loadProxy(f'dnd-tusks/{tusk_type}')

    def _loadProxy(self, proxy_path):
        """Load a proxy/clothes item."""
        try:
            # Full path to proxy
            import mh
            data_path = mh.getSysDataPath('clothes')
            proxy_file = os.path.join(data_path, proxy_path, f'{os.path.basename(proxy_path)}.mhclo')

            if os.path.exists(proxy_file):
                gui3d.app.loadClothing(proxy_file)
                log.message(f"Loaded accessory: {proxy_path}")
            else:
                log.warning(f"Accessory not found: {proxy_file}")
        except Exception as e:
            log.warning(f"Could not load accessory {proxy_path}: {e}")

    def _applySkin(self, monster):
        """Apply skin material for the monster."""
        skin_idx = self.skinList.currentRow()
        skins = monster.get('skins', [])

        if skins and skin_idx < len(skins):
            skin_name = skins[skin_idx]
            skin_file = f'skins/dnd-monsters/{skin_name}.mhmat'

            try:
                import mh
                skin_path = mh.getSysDataPath(skin_file)
                if os.path.exists(skin_path):
                    self.human.material.loadFromFile(skin_path)
                    log.message(f"Applied skin: {skin_name}")
            except Exception as e:
                log.warning(f"Could not apply skin {skin_name}: {e}")

    def _onReset(self):
        """Reset all monster modifications."""
        # Clear morphs
        for target_name in self._appliedMorphs:
            try:
                self.human.setDetail(target_name, 0)
            except Exception:
                pass
        self._appliedMorphs.clear()
        self._currentMonster = None

        # Reset sliders
        self.featureSlider.setValue(1.0)
        self.muscleSlider.setValue(0.5)
        self.heightSlider.setValue(0.5)

        # Reset checkboxes
        self.hornsCheck.setChecked(False)
        self.tailCheck.setChecked(False)
        self.tusksCheck.setChecked(False)

        self.human.applyAllTargets()
        gui3d.app.redraw()
        log.message("Monster configuration reset")

    def _onSliderChanged(self, value):
        """Handle slider value changes - reapply current monster if set."""
        if self._currentMonster:
            monster = MONSTERS.get(self._currentMonster)
            if monster:
                self._applyMorphs(monster)
                self.human.applyAllTargets()
                gui3d.app.redraw()

    def _onAccessoryChanged(self, state):
        """Handle accessory checkbox changes."""
        if self._currentMonster:
            monster = MONSTERS.get(self._currentMonster)
            if monster:
                self._applyAccessories(monster)
                gui3d.app.redraw()

    def _onSavePreset(self):
        """Save current configuration as a preset."""
        monster_name = self._currentMonster or 'custom'
        log.message(f"Saving preset for: {monster_name}")
        # TODO: Implement preset saving
        gui3d.app.statusMessage(f"Preset saving not yet implemented")

    def onShow(self, event):
        """Called when the task view is shown."""
        gui3d.TaskView.onShow(self, event)
        self.human = G.app.selectedHuman

    def onHide(self, event):
        """Called when the task view is hidden."""
        gui3d.TaskView.onHide(self, event)


def load(app):
    """Load the plugin."""
    category = app.getCategory('Utilities')
    taskview = category.addTask(DnDMonsterTaskView(category))
    log.message("D&D Monster Creator plugin loaded")


def unload(app):
    """Unload the plugin."""
    pass
