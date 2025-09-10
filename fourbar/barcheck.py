import re

def skip_partial_bar(bar_string):
    partial_match = re.search(r'\\partial\s*(\d+/\d+|\d+)', bar_string)
    if partial_match:
        return True
    return False
    
def check_bar_timing(bar_string, time_signature=4/4, fix_bar=False, fix_mode='skip'):
    """
    Check if a Lilypond bar has the correct timing and optionally fix bad bars
    
    Args:
        bar_string (str): Lilypond string containing notes for one bar
        time_signature (float): Time signature in beats per measure (default: 4/4 = 1.0)
        fix_bar (bool): If True, will attempt to fix bad bars
        fix_mode (str): How to fix bars:
            'skip' - Add skips to short bars
            'rest' - Add rests to short bars
            'cut' - Cut notes from long bars
            'split' - Split long bars into multiple measures
        
    Returns:
        tuple: (is_valid, total_beats, fixed_bar_string)
    """
    #print(f"\nProcessing bar: {bar_string}")
    #print(f"Time signature: {time_signature}")
    #print(f"Fix bar: {fix_bar}")
    #print(f"Fix mode: {fix_mode}")
    
    # Initialize default values
    current_note_value = 4  # Default note value (quarter note)
    total_beats = 0
    fixed_notes = []
    
    # First, check if this is a partial bar and handle it immediately
    if skip_partial_bar(bar_string):
        print("Processing partial bar")
        
        # Extract notes without modifying them
        notes = [note.strip() for note in bar_string.split(" ") if note.strip() and not note.startswith('\\partial')]
        
        # Calculate total beats
        total_beats = 0
        current_note_value = 4  # Default note value (quarter note)
        
        for note in notes:
            letter_part = ''.join(filter(str.isalpha, note))
            number_part = ''.join(filter(str.isdigit, note))
            
            if number_part:
                note_value = int(number_part)
                note_beats = 1 / note_value
                total_beats += note_beats
                current_note_value = note_value
            else:
                note_beats = 1 / current_note_value
                total_beats += note_beats
        
        # For partial bars, we don't modify the bar
        fixed_bar = bar_string
        return True, total_beats, fixed_bar
    
    # For non-partial bars, use the time signature
    target_beats = time_signature
    
    # Extract and process notes
    notes = [note.strip() for note in bar_string.split(" ") if note.strip()]
    
    for note in notes:
        letter_part = ''.join(filter(str.isalpha, note))
        number_part = ''.join(filter(str.isdigit, note))
        
        if number_part:
            note_value = int(number_part)
            note_beats = 1 / note_value
            total_beats += note_beats
            current_note_value = note_value
        else:
            note_beats = 1 / current_note_value
            total_beats += note_beats
    
    # Check if total beats match the time signature
    is_valid = abs(total_beats - target_beats) < 1e-6
    
    # If bar is invalid and fix_bar is True, try to fix it
    if not is_valid and fix_bar:
        if fix_mode == 'skip':
            # Add skips to make up the difference
            difference = target_beats - total_beats
            if difference > 0:
                # Add skips to make up the difference
                skip_value = int(1 / difference)
                fixed_bar = f"{bar_string} s{skip_value}"
                total_beats += difference
                is_valid = True
            else:
                fixed_bar = bar_string
        elif fix_mode == 'rest':
            # Add rests to make up the difference
            difference = target_beats - total_beats
            if difference > 0:
                rest_value = int(1 / difference)
                fixed_bar = f"{bar_string} r{rest_value}"
                total_beats += difference
                is_valid = True
            else:
                fixed_bar = bar_string
        elif fix_mode == 'cut':
            # Cut notes from the end to make the bar fit
            fixed_bar = bar_string
        elif fix_mode == 'split':
            # Split long bars into multiple measures
            fixed_bar = bar_string
    else:
        fixed_bar = bar_string
    
    return is_valid, total_beats, fixed_bar

'''    
if __name__ == "__main__":
# Test cases
    bars = [
    "ef4 ^Tunename c'8 b8 a8",  # Short bar (.625 beats)
    "b4 c8 d8 e8",    # Short bar (.625 beats)
    "c4 e4 g4 c'4",   # Too long (1.0 beats)
    "ef4 c'8 b8 a",   # Short bar (.625 beats)
    "b4 c8 d e4",     # Good bar (.75 beats)
    "b4 c8 d e4 f4",  # Too long (1.25 beats)
    "\\partial 8 c16 d",  # Should be valid since 1/8 + 1/8 = 1/4
    "\\partial 4 c8 d8",   # Should be valid since 1/8 + 1/8 = 1/4
    "\\partial 4 c8 d8 e8" # Should be invalid since 1/8 + 1/8 + 1/8 = 3/8 != 1/4
    ]

time_signature = 3/4  # 3/4 time

# Test different fixing modes
modes = ['skip', 'rest', 'cut']

for mode in modes:
    print(f"\n=== Testing with fixing mode: {mode} ===")
    for bar in bars:
        is_valid, total_beats, fixed_bar = check_bar_timing(bar, time_signature, fix_bar=True, fix_mode=mode)
        print(f"\nOriginal Bar: {bar}")
        print(f"Fixed Bar: {fixed_bar}")
        print(f"Total beats: {total_beats}")
        if is_valid:
            print("Good bar")
        else:
            print("Bad bar")
'''