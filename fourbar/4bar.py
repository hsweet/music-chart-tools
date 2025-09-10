#!/usr/bin/env python3

#****************** setup *************************
import os
import re
from barcheck import check_bar_timing, skip_partial_bar 
from transposer import Transposer
#from transpose import get_new_key
directory_path = "/home/harry/Music/charts/music_scripts/ly"  # Replace with your directory path

def print_header():
    print(r'\include "english.ly"')
    print(r'\version "2.24.3"')
    print(r"\paper{")
    print(r"  right-margin = 2\in")
    print("  tagline = #ff")
    print("  print-all-headers = ##t")    
    print("  set-paper-size = \"letter\"")
    print("}")
    print(r"melody = \relative c' {")

def print_footer():
    print(r'}')  # Closing brace for \music section
    print()
    print(r'\score {')
    print(r'  <<')
    print(f'    \\new Staff \\melody')
    print(r'  >>')
    print(r'\header {')
    print(r'  title = "Alltunes"')
    print(r'}')  # end header
    print(r'\layout {')
    print(r' \context {')
    print(r'  \Score')
    print(r'  \omit BarNumber')
    print(r'  indent = 0\cm')
    print(r'  }')  # end \layout
    print(r' }')   # end \context
    print(r'}')  # end \score

def get_transpose_directive(file_path):
    """
    Reads a file line by line to find the first line with a valid \transpose directive,
    ignoring lines that are commented out.
    Returns the line containing the \transpose directive if found, otherwise returns None.
    """
    try:
        with open(file_path, 'r') as f:
            for line in f:
                stripped_line = line.strip()
                
                # Check if the line is a comment or starts with a comment
                if stripped_line.startswith('%'):
                    continue  # Skip this line and move to the next
                
                # Now, check for the transpose directive on the cleaned line
                if "\\transpose" in stripped_line:
                    return stripped_line
    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
        return None
    return None

def get_new_key(directive, directives=None):
    """
    Extracts the starting and target notes from a LilyPond \transpose directive.
    Returns the target note if found, otherwise raises a ValueError.
    """
    pattern = r"\\transpose\s+([a-g][b#]?[',]*)\s+([a-g][b#]?[',]*)"
    match = re.search(pattern, directive)
    if match:
        starting_note = match.group(1).lower().strip("',")
        target_note = match.group(2).lower().strip("',")
        if directives is not None and 'key' in directives:
            # Preserve the original key's quality (major/minor)
            current_key = directives['key']
            key_quality = '\\major' if '\\major' in current_key.lower() else '\\minor' if '\\minor' in current_key.lower() else '\\major'
            # Update the key in directives with the new note but same quality
            directives['key'] = f"\\key {target_note} {key_quality}"
        return target_note
    else:
        raise ValueError("Invalid transpose directive format.")
    
def get_octave(line):
    '''
    Takes the "melody = \relative c' {" line  as input and returns the octave
    Ex. \relative c' -> c'
    '''
    pattern = r"\\relative\s+(c\'*)\s*{"
    match = re.search(pattern, line)
    if match:
        return match.group(1)
    else:
        raise ValueError("Invalid relative directive format.")



def transpose_measures(measures, transposer):
    '''
    Transpose a list of musical measures using the provided transposer.
    
    Parameters:
    - measures: list of str, the measures to transpose
    - transposer: Transposer instance for transposing notes
    
    Returns:
    - list of str: the transposed measures
    '''
    transposed_measures = []
    for measure in measures:
        # Get the cleaned notes for this measure
        notes_only = re.sub(r'\\\w+\s*', '', measure)
        if notes_only.endswith('~') or notes_only.endswith('|'):
            notes_only = notes_only[:-1]
            
        # Process each note in the measure
        notes = notes_only.split()
        transposed_notes = []
        
        for note in notes:
            # Extract note name, accidental, octave, duration, and articulations
            note_match = re.match(r'^([a-gA-G])([b#]?)([\',]*)(\d*\.?\d*)([^a-zA-Z0-9]*)', note)
            if note_match:
                note_name, accidental, octave, duration, articulations = note_match.groups()
                try:
                    # Transpose the note name and handle the accidental
                    transposed_note = transposer.transpose(note_name + accidental)
                    # Convert to english notation (s for sharp, f for flat)
                    transposed_note = transposed_note.replace('#', 's').replace('b', 'f')
                    # Reconstruct the note with octave, duration, and articulations
                    transposed_notes.append(f"{transposed_note}{octave}{duration}{articulations}")
                except ValueError:
                    # If transposition fails, keep the original note
                    transposed_notes.append(note)
            else:
                transposed_notes.append(note)
        
        # Replace the original measure with transposed notes
        transposed_measure = ' '.join(transposed_notes) + ('|' if measure.endswith('|') else '')
        transposed_measures.append(transposed_measure)
    
    return transposed_measures

def extract_melody(file_path, filename, directives=None, transposer=None):
    '''
    Extract and format the first four measures of a melody from a Lilypond file.
       
    Parameters:
    - file_path: str, the path to the Lilypond file to be processed.
    - filename: str, the name of the file, used to derive the title for the output.
    - directives: dict, optional dictionary containing Lilypond directives
    - transposer: Transposer instance, optional for transposing notes
    
    Returns:
    - tuple: (title, formatted_output, directives)
    '''

    with open(file_path, 'r') as file:
        lines = file.readlines()

    melody_started = False
    measures = []
    if directives is None:
        directives = {}
    title = os.path.splitext(os.path.basename(filename))[0]

    # Only extract directives if they weren't provided
    if not directives:
        directives = {}
        
    # Extract directives and melody content
    for line in lines:
        if 'melody =' in line:
            directives['octave'] = get_octave(line)
            melody_started = True
            continue  # Skip to the next line after finding the melody

        if not melody_started:
            # Only extract directives if they weren't provided
            if r'\clef' in line and 'clef' not in directives:
                directives['clef'] = line.strip()
            elif r'\key' in line and 'key' not in directives:
                directives['key'] = line.strip()
            elif r'\time' in line and 'time' not in directives:
                directives['time'] = line.strip()

        if melody_started:
            # get the first 4 measures of the melody
            if '}' in line:
                break
            
            stripped_line = line.strip()
            if stripped_line and not stripped_line.startswith('%') and not stripped_line.startswith('\\'):
                measures.append(stripped_line)

            # Check if we have 4 measures
            if len(measures) >= 4:
                break  # Stop after finding 4 measures

    # Check timing for each measure before any formatting
    if 'time' not in directives:
        # If no time signature found, default to 4/4
        directives['time'] = '\\time 4/4'

    fixed_measures = []
    for measure in measures:
        # Extract just the notes from the measure (remove any Lilypond directives)
        notes_only = re.sub(r'\\\w+\s*', '', measure)
        # remove any trailing ~ or |
        if notes_only.endswith('~')  or notes_only.endswith('|'): 
            notes_only = notes_only[:-1]    
        # print (f"notes_only: type({type(notes_only)}) {notes_only}") 
        # Extract time signature value from the string
        time_match = re.search(r'\time\s*(\d+/\d+)', directives['time'])
        if time_match:
            time_signature = eval(time_match.group(1))  # Convert string like '4/4' to float 1.0
        else:
            time_signature = 4/4  # Default to 4/4 if time signature not found
        
        # check bar timing and fix if necessary
        is_valid, total_beats, fixed_measure = check_bar_timing(notes_only, time_signature, fix_bar=True, fix_mode='skip')
        fixed_measures.append(fixed_measure)
    measures = fixed_measures

    # Transpose measures if transposer is provided
    if transposer and measures:
        measures = transpose_measures(measures, transposer)

    # Format the output
    output = []
    
    # Add directives (except octave which is handled separately)
    for key, directive in directives.items():
        if key != 'octave':  # Skip octave as it's not a directive
            output.append(f"  {directive}")
    
    # Add reset relative octave using the stored octave value
    output.append(f"  \\resetRelativeOctave {directives.get('octave', 'c\'')}")
    
    # Add measures with title after first note
    if measures:
        # Split the first measure into first note and the rest of the line
        first_note, *rest = measures[0].split(' ', 1)
        # Add title after first note
        measures[0] = f"{first_note} ^{title} {rest[0] if rest else ''}"
    
    output.append('\n'.join(measures))
    
    return title, '\n'.join(output), directives  # Return title, formatted output, and directives
    

try:
    # Get all .ly files and sort them alphabetically
    ly_files = [f for f in os.listdir(directory_path) if f.endswith('.ly')]
    ly_files.sort()  # Sort the files alphabetically
    
    # Print version and includes once at the top
    print_header()

    # Extract melodies from each file
    melodies = []
    for filename in ly_files:
        file_path = os.path.join(directory_path, filename)
        
        #print(f"\n{'='*80}\nProcessing file: {filename}")
        try:
            with open(file_path, 'r') as f:
         
            # get the transpose directive
                # Initialize directives dictionary
                directives = {}
                
                # Check for transpose directive first
                directive_line = get_transpose_directive(file_path)
                transposer = None
                
                if directive_line:
                    # Create transposer instance if there's a transpose directive
                    transposer = Transposer.from_lilypond_directive(directive_line)
                    # Get the new key and update the directives
                    new_key = get_new_key(directive_line, {})
                    # Update directives with the new key
                    if 'key' in directives:
                        directives['key'] = f"\\key {new_key} \\major"
                
                # Extract the melody with optional transposition
                title, melody_content, directives = extract_melody(file_path, filename, directives, transposer)
                
                # Add the processed melody to the output
                print(f"\n% {title}")
                print(melody_content)
                print()
                
                melodies.append(melody_content)
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    # Print all melodies
    print('\n'.join(melodies))
    print_footer()

except FileNotFoundError:
    print(f"Error: Directory '{directory_path}' not found.")
except Exception as e:
    print(f"An error occurred: {e}")
