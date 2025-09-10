from simple_transposer import SimpleTransposer

def test_transposition():
    # Test cases: (transpose_directive, input_notes, expected_output)
    test_cases = [
        (r"\transpose c d", "c d e f g a b c'", "d e f# g a b c#' d'"),
    ]
    
    print("\n=== Testing Transposition ===")
    
    for i, (directive, input_notes, expected) in enumerate(test_cases, 1):
        print(f"\nTest {i}: {directive}")
        print("-" * 50)
        
        # Create transposer from directive
        transposer = SimpleTransposer.parse_transpose_directive(directive)
        
        # Transpose the notes
        result = transposer.transpose(input_notes)
        
        print(f"Input:    {input_notes}")
        print(f"Expected: {expected}")
        print(f"Result:   {result}")
        print(f"Match:    {result == expected}")

def test_with_actual_ly():
    # A simple LilyPond example
    ly_content = """
    \\relative c' {
        \\key c \\major
        \\time 4/4
        c4 d e f |
        g a b c' |
        d'4. c'8 b a g f |
        e4 d c2 |
    }
    """
    
    print("\n=== Testing with LilyPond Content ===")
    
    print("\nTesting with actual LilyPond content:")
    print("-" * 50)
    
    # Transpose up a perfect fourth (C to F)
    transposer = SimpleTransposer('c', 'f')
    transposed = transposer.transpose(ly_content)
    
    print("Original:")
    print(ly_content)
    print("\nTransposed (C to F):")
    print(transposed)
    
    # Write to a file for easier inspection
    with open('transposed_simple.ly', 'w') as f:
        f.write(transposed)
    print("\nTransposed output written to 'transposed_simple.ly'")

if __name__ == "__main__":
    test_transposition()
    test_with_actual_ly()
