import re

def skip_partial_bar(bar_string):
    partial_match = re.search(r'\\partial\s*(\d+/\d+|\d+)', bar_string)
    if partial_match:
        return True
    return False
    
def check_partial_bar(bar_string):

    # Extract the partial duration
    partial_match = re.search(r'\\partial\s*(\d+/\d+|\d+)', bar_string)
    if not partial_match:
        return False, 0, "Not a partial bar"
    
    # Get the duration (1/4 for \partial 4, 3/8 for \partial 3/8)
    duration = partial_match.group(1)
    #print(duration)
    if '/' in duration:
        numerator, denominator = map(int, duration.split('/'))
        target_duration = numerator / denominator
        #print(target_duration)
    else:
        target_duration = 1 / int(duration)
    
    # Extract the notes - everything after the partial duration
    partial_end = partial_match.end()
    notes = [note.strip() for note in bar_string[partial_end:].split() 
             if note.strip()]
    print(notes)
    
    # Calculate total duration of notes
    total_duration = 0
    # Store the last duration we saw
    last_duration = 4  # Start with default quarter note
    
    for note in notes:
        # Extract note letter and duration if present
        letter_part = ''.join(filter(str.isalpha, note))
        number_part = ''.join(filter(str.isdigit, note))
        
        if number_part:
            # Note has a duration (like c4)
            duration = int(number_part)
            total_duration += 1 / duration
            if duration != last_duration:  # Only update last_duration if it's different
                last_duration = duration
        else:
            # Note uses previous duration
            if last_duration:  # Only use previous duration if we've seen one
                total_duration += 1 / last_duration
            else:
                total_duration += 1 / 4  # Default to quarter note if no previous duration
                last_duration = 4  # Set default duration
        
        print(total_duration)
    
    # Check if total matches target
    is_valid = abs(total_duration - target_duration) < 1e-6
    return is_valid, total_duration, bar_string

def test_partial_bars():
    # Test cases:
    # 1. Valid partial bar with fraction
    print("\nTest 1: Valid partial bar with fraction")
    print(check_partial_bar("\\partial 3/8 c8 d8 e8"))  # Should be True (3/8 = 0.375)
    
    # 2. Valid partial bar with integer
    print("\nTest 2: Valid partial bar with integer")
    print(check_partial_bar("\\partial 4 c16 d16 e16 f16"))  # Should be True (1/4 = 0.25)
    
    # 3. Invalid partial bar (too short)
    print("\nTest 3: Invalid partial bar (too short)")
    print(check_partial_bar("\\partial 3/8 c8 d8"))  # Should be False (0.25 != 0.375)
    
    # 4. Invalid partial bar (too long)
    print("\nTest 4: Invalid partial bar (too long)")
    print(check_partial_bar("\\partial 4 c8 d8 e8"))  # Should be False (0.75 != 0.25)
    
    # 5. Partial bar with mixed durations
    print("\nTest 5: Partial bar with mixed durations")
    print(check_partial_bar("\\partial 3/8 c8 d16 e16 f16"))  # Should be True (0.375)
    
    # 6. Partial bar with no duration specified
    print("\nTest 6: Partial bar with no duration specified")
    print(check_partial_bar("\\partial c8 d8"))  # Should be False (not a valid partial bar)
    
    # 7. Partial bar with default duration
    print("\nTest 7: Partial bar with default duration")
    print(check_partial_bar("\\partial 4 c d e f"))  # Should be True (1/4 = 0.25)
    
    # 8. Partial bar with duration 4/4
    print("\nTest 8: Partial bar with duration 4/4")
    print(check_partial_bar("\\partial 4/4 c4 d4 e4 f4"))  # Should be True (1.0 = 1.0)

if __name__ == "__main__":
    #test_partial_bars()
    print(skip_partial_bar("\\partial 4/4 c4 d4 e4 f4"))
    print(skip_partial_bar("4/4 c4 d4 e4 f4"))