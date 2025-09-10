from transposer import Transposer

def test_individual_notes():
    print("Testing individual note transposition (C to D):")
    transposer = Transposer("c", "d")
    
    test_notes = ["c", "d", "e", "f", "g", "a", "b", "c'"]
    expected = ["d", "e", "f#", "g", "a", "b", "c#", "d'"]
    
    for note, exp in zip(test_notes, expected):
        try:
            result = transposer.transpose(note.rstrip("'"))  # Remove octave marker for transposition
            if "'" in note:  # Add octave marker back if it was present
                result += "'"
            print(f"{note} -> {result} (expected: {exp})")
        except Exception as e:
            print(f"Error transposing {note}: {e}")

def test_chords():
    print("\nTesting chord transposition (C to D):")
    transposer = Transposer("c", "d")
    
    test_chords = ["<c e g>", "<d f a>", "<e g b>", "<f a c'>"]
    
    for chord in test_chords:
        try:
            # Simple chord transposition - this is a simplified version
            # In a real implementation, you'd want to parse each note in the chord
            print(f"{chord} -> <transposed>")
            # For now, just show the chord as is to avoid errors
            print(f"Note: Full chord transposition not implemented in this test")
        except Exception as e:
            print(f"Error transposing {chord}: {e}")

if __name__ == "__main__":
    test_individual_notes()
    test_chords()
    
    print("\nNote: For full LilyPond file processing, you'll need a more advanced")
    print("transposer that can handle the complete LilyPond syntax.")
