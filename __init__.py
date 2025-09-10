"""
Music Chart Tools - A collection of utilities for managing LilyPond files and PDF music charts.

This package provides tools for:
- Creating setlists from PDF files (setlist module)
- Processing LilyPond files and extracting four-bar excerpts (fourbar module)
- Transposing music files (klezapp module)
"""

__version__ = "0.1.0"
__author__ = "Harry Sweet"

# Import main functions from submodules for easy access
try:
    from .setlist.setlist import create_setlist, compile_setlist, list_backups, use_backup
    from .fourbar.fourbar import extract_melody, get_transpose_directive
    SETLIST_AVAILABLE = True
except ImportError:
    SETLIST_AVAILABLE = False

# Define what gets imported with "from music_chart_tools import *"
__all__ = [
    'create_setlist',
    'compile_setlist', 
    'list_backups',
    'use_backup',
    'extract_melody',
    'get_transpose_directive',
    'SETLIST_AVAILABLE'
]
