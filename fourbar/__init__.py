"""
Four-bar extraction tools for processing LilyPond files.

This module provides functionality to:
- Extract the first four bars from LilyPond files
- Process transpose directives
- Format musical excerpts
"""

from .fourbar import extract_melody, get_transpose_directive, print_header, print_footer

__all__ = ['extract_melody', 'get_transpose_directive', 'print_header', 'print_footer']
