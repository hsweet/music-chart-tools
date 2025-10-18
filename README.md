# music-chart-tools

Tools for managing LilyPond files and pdf music charts

## Setlist tools
- *setlist.py* - Make setlists from a selection of pdf files.  Join any set of pdf files into a single pdf file with a table of contents.
- *chart_selector.py* - Find pdf files to add to the selection file
- *fourbar.py* - Print four bars of a set of LilyPond files (in development)

## Transposition tools
- *lytranspose.pl* - Transpose LilyPond files to Bb, Eb and bass clef, and send to google drive as a single combined pdf file
- *lyt.pl* - Run the complete pipeline to analyze LilyPond files and determine the optimal global octave shift for transposing instruments
- *ly2midi.pl* - Extract and convert LilyPond notes to MIDI note numbers.  
    - Input is a LilyPond file using \displayLilyMusic, output is a list of MIDI note numbers
- *best_octave.pl* - To find optimal octave shift for transposing instruments.  
    - Input is a list of MIDI note numbers, output is a LilyPond \transpose command
