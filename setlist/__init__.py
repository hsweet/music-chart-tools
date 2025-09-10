"""
Setlist tools for managing PDF music charts and creating setlists.

This module provides functionality to:
- Create numbered setlists from PDF selections
- Compile multiple PDFs into a single setlist document
- Manage backups of setlist selections
"""

from .setlist import create_setlist, compile_setlist, list_backups, use_backup

__all__ = ['create_setlist', 'compile_setlist', 'list_backups', 'use_backup']
