#!/usr/bin/env python3
"""
D&D Monster Creator - MakeHuman Plugin Installer

Cross-platform installation script that auto-detects MakeHuman installation
and copies plugin files to the correct locations.

Usage:
    python install.py                    # Auto-detect and install
    python install.py --path /custom/mh  # Install to custom path
    python install.py --uninstall        # Remove installed files
"""

import os
import sys
import shutil
import argparse
from pathlib import Path


# Files and directories to install
PLUGIN_FILES = [
    'plugins/7_dnd_monsters.py',
    'plugins/_dnd_monsters/__init__.py',
    'plugins/_dnd_monsters/monster_data.py',
]

DATA_DIRS = [
    'data/targets/dnd-monsters',
    'data/skins/dnd-monsters',
    'data/dnd-monsters',
]


def find_makehuman_paths():
    """Find possible MakeHuman installation directories."""
    paths = []
    home = Path.home()

    if sys.platform == 'darwin':  # macOS
        paths.extend([
            home / 'Applications' / 'MakeHuman.app' / 'Contents' / 'Resources',
            Path('/Applications/MakeHuman.app/Contents/Resources'),
            home / 'Documents' / 'makehuman' / 'v1py3',
            home / '.makehuman',
        ])
    elif sys.platform == 'win32':  # Windows
        appdata = os.environ.get('APPDATA', '')
        localappdata = os.environ.get('LOCALAPPDATA', '')
        paths.extend([
            Path(appdata) / 'makehuman' if appdata else None,
            Path(localappdata) / 'makehuman' if localappdata else None,
            Path('C:/Program Files/MakeHuman'),
            Path('C:/Program Files (x86)/MakeHuman'),
            home / 'Documents' / 'makehuman',
        ])
    else:  # Linux
        paths.extend([
            home / '.local' / 'share' / 'makehuman',
            home / '.makehuman',
            Path('/usr/share/makehuman'),
            Path('/opt/makehuman'),
        ])

    # Filter None and non-existent paths
    return [p for p in paths if p and p.exists()]


def find_user_data_path():
    """Find MakeHuman user data directory (for when main install is read-only)."""
    home = Path.home()

    if sys.platform == 'darwin':
        candidates = [
            home / 'Documents' / 'makehuman' / 'v1py3',
            home / '.makehuman',
        ]
    elif sys.platform == 'win32':
        appdata = os.environ.get('APPDATA', '')
        candidates = [
            Path(appdata) / 'makehuman' if appdata else None,
            home / 'Documents' / 'makehuman',
        ]
    else:
        candidates = [
            home / '.local' / 'share' / 'makehuman',
            home / '.makehuman',
        ]

    for path in candidates:
        if path and path.exists():
            return path

    # Create default user data path if none exists
    default = candidates[0] if candidates[0] else home / '.makehuman'
    return default


def is_writable(path):
    """Check if a path is writable."""
    try:
        test_file = path / '.write_test'
        test_file.touch()
        test_file.unlink()
        return True
    except (OSError, PermissionError):
        return False


def get_source_dir():
    """Get the directory containing this install script."""
    return Path(__file__).parent.resolve()


def copy_file(src, dst):
    """Copy a file, creating parent directories as needed."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"  Copied: {dst}")


def copy_directory(src, dst):
    """Copy a directory recursively."""
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    print(f"  Copied: {dst}")


def install(target_path, source_dir):
    """Install plugin files to the target MakeHuman directory."""
    target = Path(target_path)
    source = Path(source_dir)

    if not target.exists():
        print(f"Error: Target directory does not exist: {target}")
        return False

    if not is_writable(target):
        print(f"Warning: {target} is not writable, using user data directory...")
        target = find_user_data_path()
        target.mkdir(parents=True, exist_ok=True)
        print(f"Installing to: {target}")

    print(f"\nInstalling D&D Monster Creator to: {target}\n")

    # Copy plugin files
    print("Installing plugins...")
    for rel_path in PLUGIN_FILES:
        src = source / rel_path
        if src.exists():
            dst = target / rel_path
            copy_file(src, dst)
        else:
            print(f"  Warning: Source file not found: {src}")

    # Copy data directories
    print("\nInstalling data files...")
    for rel_path in DATA_DIRS:
        src = source / rel_path
        if src.exists():
            dst = target / rel_path
            copy_directory(src, dst)
        else:
            print(f"  Warning: Source directory not found: {src}")

    print("\nInstallation complete!")
    print("\nTo use the plugin:")
    print("  1. Restart MakeHuman")
    print("  2. Go to Utilities > D&D Monsters")

    return True


def uninstall(target_path):
    """Remove installed plugin files."""
    target = Path(target_path)

    print(f"\nUninstalling D&D Monster Creator from: {target}\n")

    # Remove plugin files
    for rel_path in PLUGIN_FILES:
        file_path = target / rel_path
        if file_path.exists():
            file_path.unlink()
            print(f"  Removed: {file_path}")

    # Remove plugin package directory if empty
    pkg_dir = target / 'plugins' / '_dnd_monsters'
    if pkg_dir.exists() and not any(pkg_dir.iterdir()):
        pkg_dir.rmdir()
        print(f"  Removed: {pkg_dir}")

    # Remove data directories
    for rel_path in DATA_DIRS:
        dir_path = target / rel_path
        if dir_path.exists():
            shutil.rmtree(dir_path)
            print(f"  Removed: {dir_path}")

    print("\nUninstall complete!")
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Install D&D Monster Creator plugin for MakeHuman'
    )
    parser.add_argument(
        '--path', '-p',
        help='Custom MakeHuman installation path'
    )
    parser.add_argument(
        '--uninstall', '-u',
        action='store_true',
        help='Uninstall the plugin'
    )
    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='List detected MakeHuman installations'
    )

    args = parser.parse_args()
    source_dir = get_source_dir()

    if args.list:
        print("Detected MakeHuman installations:")
        paths = find_makehuman_paths()
        if paths:
            for p in paths:
                writable = "writable" if is_writable(p) else "read-only"
                print(f"  {p} ({writable})")
        else:
            print("  No MakeHuman installations found.")
            print(f"\nUser data directory: {find_user_data_path()}")
        return 0

    # Determine target path
    if args.path:
        target_path = Path(args.path)
        if not target_path.exists():
            print(f"Error: Specified path does not exist: {target_path}")
            return 1
    else:
        paths = find_makehuman_paths()
        if paths:
            # Prefer writable paths
            writable_paths = [p for p in paths if is_writable(p)]
            target_path = writable_paths[0] if writable_paths else paths[0]
        else:
            target_path = find_user_data_path()
            print(f"No MakeHuman installation found. Using user data directory.")
            target_path.mkdir(parents=True, exist_ok=True)

    # Execute install or uninstall
    if args.uninstall:
        return 0 if uninstall(target_path) else 1
    else:
        return 0 if install(target_path, source_dir) else 1


if __name__ == '__main__':
    sys.exit(main())
