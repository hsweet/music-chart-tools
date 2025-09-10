import re

'''
def transpose1(directive):
            
    if not melody_started and r'\transpose' in line and not line.strip().startswith('%%'):
        line_stripped = line.strip()
        print(f"Found transpose line: {line_stripped}")
        try:
            # Check if this is a standalone transpose line (like in Yiddishe-Mamme.ly)
            if 'harmonies' in line_stripped:
                # Format: \transpose g c \harmonies
                match = re.search(r'\\transpose\s+[a-g][b#]?[\',]*\s+([a-g][b#]?[\',]*)', line_stripped)
                if match:
                    target_key = match.group(1).lower()
                    # Clean up the target key
                    target_key = re.sub(r'[\',\\].*', '', target_key)
                    print(f"Harmonies transpose target_key: {target_key}, {title}")
                    directives['key'] = f'\\key {target_key} \\major'
                    melody_lines.insert(0, directives['key'])
                    print(f"Setting key to: {directives['key']}")
                    #continue  # Skip to next line after processing
            
            # Handle other transpose formats
            match = re.search(r'\\transpose\s+[a-g][b#]?[\',]*\s+([a-g][b#]?[\',]*)', line_stripped)
            if not match:
                match = re.search(r'\\transpose[^a-g]*([a-g][b#]?)[\',\\]', line_stripped)
            print(f"match: {match}")
            if match:
                target_key = match.group(1).lower()
                # Clean up the target key
                target_key = re.sub(r'[\',\\].*', '', target_key)
                print(f"target_key: {target_key}, {title}")
                
                # Set the key in the directives
                directives['key'] = f'\\key {target_key} \\major'
                # Set the global transpose_directive for later use
                transpose_directive = target_key
                
                # Add the key to the beginning of the melody lines
                melody_lines.insert(0, directives['key'])
                print(f"Setting key to: {directives['key']}")
        except ValueError:
            # If the transpose directive is invalid, just ignore it
            pass
'''

def transpose2(directive):

    pattern = r"\\transpose\s+([a-g][b#]?[',]*)\s+([a-g][b#]?[',]*)"
    match = re.search(pattern, directive)
    
    if match:
        starting_note = match.group(1).lower().strip("',")
        target_note = match.group(2).lower().strip("',")
        print(f"directive: {directive}")
        print(f"starting_note: {starting_note}")
        print(f"target_note: {target_note}")
        return (starting_note, target_note)
    else:
        raise ValueError("Invalid transpose directive format.")



transpose2(r"%\transpose g c#dsafd")
