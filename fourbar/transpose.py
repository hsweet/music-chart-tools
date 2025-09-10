import re

note_values = {
    "c": 0, "c#": 1, "db": 1, "d": 2, "d#": 3, "eb": 3, "e": 4, "f": 5, "f#": 6,
    "gb": 6, "g": 7, "g#": 8, "ab": 8, "a": 9, "a#": 10, "bb": 10, "b": 11
}

value_to_note = {v: k for k, v in note_values.items() if len(k) == 1 or k in ["c#", "d#", "f#", "g#", "a#"]}

def parse_lilypond_note(note_string):
    """
    Separates the note name from its duration/accidental.
    Ex. c8. -> (c, 8.)
    Returns a tuple (note_name, remainder)
    """
    if note_string[:2] in note_values:
        note_name = note_string[:2]
        remainder = note_string[2:]
    elif note_string[0] in note_values:
        note_name = note_string[0]
        remainder = note_string[1:]
    else:
        raise ValueError(f"Could not parse note: {note_string}")
    
    return (note_name, remainder)

def transpose_note(starting_note, target_note, note_to_transpose):
    '''
    Transposes a note to a new key.
    Ex. c -> e
    '''
    n = (note_values[target_note] - note_values[starting_note]) % 12
    transposed_value = (note_values[note_to_transpose] + n) % 12
    return value_to_note[transposed_value]

def get_transposition_notes(directive):
    """
    Extracts the starting and target notes from a LilyPond \transpose directive
    
    # Pattern to find two consecutive notes after \transpose
    # A note is a letter (a-g), followed by an optional accidental (# or b),
    # and optional octave marks (' or ,)
    """
    pattern = r"\\transpose\s+([a-g][b#]?[',]*)\s+([a-g][b#]?[',]*)"
    
    match = re.search(pattern, directive)
    
    if match:
        starting_note = match.group(1)
        target_note = match.group(2)
        return (starting_note, target_note)
    else:
        raise ValueError(f"Could not parse transposition notes from: {directive}")

if __name__ == "__main__":

    transpose_directive = r"\transpose c gs\%some stupid comment"  
    transposition_interval= get_transposition_notes(transpose_directive)
    transposed_pieces = []

    lily_notes = ("a8. g16 a8 bf c b a g")
    lily_list = lily_notes.split()
    
    for note in lily_list:
        # separate note name from duration/accidental
        note_name, remainder = parse_lilypond_note(note)
        # transpose note
        new_note_name = transpose_note(transposition_interval[0], transposition_interval[1], note_name)
        # add transposed note to list
        transposed_pieces.append(f"{new_note_name}{remainder}")

    # join list into string
    result = ' '.join(transposed_pieces)

    print(f"Original notes: {lily_notes}")
    print(f"Transposed notes: {result}")
