import re

class Transposer:
    '''
    Transposer class to transpose a melody from one key to another.

    Attributes:
    - starting_note: str, the starting note of the melody
    - target_note: str, the target note of the melody
    - note_values: dict, a dictionary of note values
    - value_to_note: dict, a dictionary of note values to note names
    - interval: int, the transposition interval
    '''
    def __init__(self, starting_note, target_note):
        self.note_values = {
            # Natural notes
            "c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11,
            # Sharps in LilyPond English format
            "cs": 1, "ds": 3, "fs": 6, "gs": 8, "as": 10,
            # Flats in LilyPond English format
            "df": 1, "ef": 3, "gf": 6, "af": 8, "bf": 10, "cf": 10
        }
        # Map each value to its preferred note name (using sharps for consistency)
        self.value_to_note = {
            0: "c", 1: "cs", 2: "d", 3: "ef", 4: "e", 5: "f",
            6: "fs", 7: "g", 8: "gs", 9: "a", 10: "bf", 11: "b"
        }

        # Calculate and store the transposition interval (n)
        self.interval = (self.note_values[target_note] - self.note_values[starting_note]) % 12

    @classmethod
    def from_lilypond_directive(cls, directive):
        """
        Parses a LilyPond transpose directive and creates a Transposer instance.
        """
        import re
        pattern = r"\\transpose\s+([a-g][b#]?[',]*)\s+([a-g][b#]?[',]*)"
        match = re.search(pattern, directive)
        
        if match:
            starting_note = match.group(1).lower().strip("',")
            target_note = match.group(2).lower().strip("',")
            return cls(starting_note, target_note)
        else:
            raise ValueError("Invalid transpose directive format.")

    def parse_lilypond_note(self, note_string):
        """
        Parses a LilyPond note string to separate the note name from its duration/accidental.
        Returns a tuple (note_name, remainder)  like ("c", "8") or ("ef", "8")
        """
        if len(note_string) >= 2 and note_string[:2] in self.note_values:
            note_name = note_string[:2]
            remainder = note_string[2:]
        elif note_string and note_string[0] in self.note_values:
            note_name = note_string[0]
            remainder = note_string[1:]
        else:
            raise ValueError(f"Could not parse note: {note_string}")
        
        return (note_name, remainder)

    def transpose(self, notes_to_transpose):
        if isinstance(notes_to_transpose, list):
            return [self.transpose_single_note(note) for note in notes_to_transpose]
        return self.transpose_single_note(notes_to_transpose)
        
    def transpose_single_note(self, note):
        transposed_value = (self.note_values[note] + self.interval) % 12
        return self.value_to_note[transposed_value]

#################################################################
# Main program logic
if __name__ == "__main__":
    transpose_directive = r"\transpose g c\relative c''"
    # calculate the transposition interval from the transpose directive
    transposer = Transposer.from_lilypond_directive(transpose_directive)
    #print(transposer.interval) 
    transposed_note = transposer.transpose("c")
    print(f"transposed_note: ", {transposed_note})
    # Test with a variety of note names (sharps, flats, and naturals)
    test_notes = ["c", "cs", "df", "d", "ds", "ef", "e", "f", "fs", 
                 "gf", "g", "gs", "af", "a", "as", "bf", "b"]
    
    print("Original notes:  ", test_notes)
    transposed_notes = transposer.transpose(test_notes)
    print("Transposed notes:", transposed_notes)
    
    # Also test with the original chord
    chord = ["d", "g", "bf", "a", "c"]
    print("\nOriginal chord:", chord)
    transposed_chord = transposer.transpose(chord)
    print("Transposed chord:", transposed_chord)
    
    #print(transposer.transpose("c"))
    #print(transposer.transpose("g"))

'''
transposition_interval = ("c", "d")
transposer = Transposer(transposition_interval[0], transposition_interval[1])

# ... your main loop would then call transposer.transpose()

# Example of the class-based approach
# One transposer for C to D
transposer_c_to_d = Transposer("c", "d")

# Another transposer for C to A
transposer_c_to_a = Transposer("c", "a")

# Now you can use them independently
c_note = transposer_c_to_d.transpose("c")  # returns 'd'
a_note = transposer_c_to_a.transpose("c")  # returns 'a'

print(c_note)
print(a_note)
'''