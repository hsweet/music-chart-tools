#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration ---
my $input_file = "music_data.txt";

# --- Subroutines ---

# Calculates the MIDI number based on LilyPond's internal pitch components.
# FIX: Corrects the diatonic name to semitone mapping and adjusts the C4 offset.
sub calculate_midi {
    my ($octave, $name, $alter) = @_;
    
    # 1. Map Diatonic Name (0-6) to Semitone Value (0-11)
    # C=0, D=2, E=4, F=5, G=7, A=9, B=11
    my @semitone_map = (0, 2, 4, 5, 7, 9, 11);
    my $semitone_value = 0;
    
    if ($name >= 0 && $name <= 6) {
        $semitone_value = $semitone_map[$name];
    } else {
        warn "Invalid note name index: $name. Assuming C (0 semitones).\n";
    }
    
    # Handle fractional alterations like 1/2 or -1/2.
    my $adjusted_alter = $alter;
    if ($alter =~ /^-?\d+\/\d+$/) {
        eval { $adjusted_alter = eval $alter; };
        if ($@) {
             $adjusted_alter = 0;
             warn "Warning: Failed to evaluate alteration '$alter'. Assuming 0.\n";
        }
    }

    # Calculate total semitones from C0
    my $total_semitones = $semitone_value + $adjusted_alter;
    my $rounded_semitones = int($total_semitones + 0.5);

    # 2. Calculate MIDI number (C4/Middle C is MIDI 60)
    # We use +60 as the offset, as LilyPond often reports C4 as (octave 0, name 0).
    my $midi_num = ($octave * 12) + $rounded_semitones + 60;
    return $midi_num;
}

# Calculates the position of the note on the staff relative to Middle C (C4=0).
# This uses a deterministic formula based on diatonic steps (C=0, D=1, E=2, F=3, G=4, A=5, B=6).
# This function is necessary for correct transposition and is independent of accidentals.
sub get_staff_position {
    my ($midi_num) = @_;
    
    my $C0_MIDI = 12;
    
    # 1. Semitone value relative to C (0-11)
    my $semitone_in_octave = $midi_num % 12;
    
    # Mapping semitone value (0-11) to diatonic step (0-6)
    # 0(C)->0, 1(C#)->0, 2(D)->1, 3(D#)->1, 4(E)->2, 5(F)->3, 6(F#)->3, 7(G)->4, 8(G#)->4, 9(A)->5, 10(A#)->5, 11(B)->6
    my @diatonic_map = (0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6);
    
    # Calculate the step within the octave
    my $step_in_octave = $diatonic_map[$semitone_in_octave];
    
    # Total semitone distance from C0
    my $semitone_dist_from_C0 = $midi_num - $C0_MIDI;
    
    # Total octaves above C0 (using floor division, handles all positive/negative ranges)
    my $octaves_from_C0 = int($semitone_dist_from_C0 / 12);
    
    # Total steps above C0
    my $steps_from_C0 = ($octaves_from_C0 * 7) + $step_in_octave;
    
    # Final step: Adjust relative to C4. C4 is 28 steps above C0.
    my $final_staff_position = $steps_from_C0 - 28; 
    
    return $final_staff_position;
}


# --- SIMPLIFIED analyze_staff_placement ---
# Determines if the note is on the staff, above, or below (for Treble Clef)
# using MIDI number as a simple range check, as suggested.
sub analyze_staff_placement {
    my ($midi_num) = @_;
    
    # Treble Clef staff ranges from G4 (MIDI 55, Line 1) to F5 (MIDI 65, Line 5/Space 4).
    my $STAFF_LOWEST_MIDI = 55; # G4
    my $STAFF_HIGHEST_MIDI = 80; # F5
    
    if ($midi_num > $STAFF_HIGHEST_MIDI) {
        return "Above Staff (MIDI > 65)";
    } elsif ($midi_num < $STAFF_LOWEST_MIDI) {
        return "Below Staff (MIDI < 55)";
    } else {
        return "On Staff or Space";
    }
}


# --- Main Logic ---

print "--- Starting MIDI Data Extraction from $input_file ---\n";

# 1. Open the file for reading.
my $fh; 
unless (open($fh, '<', $input_file)) { 
    die "Error: Cannot open $input_file: $!";
}

print "--- Extracted MIDI Values and Staff Placement ---\n";
my $event_count = 1;
my $note_count = 0;
my @pitch_lines = ();
my @midi_data = (); # Array to store MIDI numbers for later analysis

# 2. Read the file line-by-line and filter for relevant events.
while (my $line = <$fh>) {
    if ($line =~ /ly:make-pitch/) {
        $line =~ s/^\s+|\s+$//g;
        push @pitch_lines, $line;
    } 
    elsif ($line =~ /RestEvent/) {
        push @pitch_lines, "RestEvent";
    }
}
close($fh); 

# 3. Process the filtered lines.
foreach my $event_line (@pitch_lines) {
    
    if ($event_line eq "RestEvent") {
        printf("Event %2d: RestEvent - StaffPos: N/A, Placement: N/A\n", $event_count);
        
    } elsif ($event_line =~ /ly:make-pitch/) {
        # 4. Extract pitch components
        
        my ($octave, $name, $alter) = (0, 0, 0); 

        # Attempt 1: Match the 3-argument signature (OCTAVE NAME ALTERATION)
        if ($event_line =~ /ly:make-pitch\s+([-\d]+)\s+([-\d\/]+)\s+([-\d\/]+)/) {
            $octave = $1;
            $name = $2;
            $alter = $3;
            
        # Attempt 2: Match the 2-argument signature (OCTAVE NAME, ALTERATION=0)
        } elsif ($event_line =~ /ly:make-pitch\s+([-\d]+)\s+([-\d\/]+)/) {
            $octave = $1;
            $name = $2;
            $alter = 0; 
            
        } else {
            print "Event $event_count: NoteEvent - Failed to parse pitch components.\n";
            $event_count++;
            next; 
        }
        
        # Calculate and analyze
        my $midi = calculate_midi($octave, $name, $alter); 
        my $staff_pos = get_staff_position($midi);  # how many steps from C4
        my $placement = analyze_staff_placement($midi); # Pass MIDI to the simplified function
        
        # Store MIDI data for transposition analysis later
        push @midi_data, { 
            event_num => $event_count,
            midi => $midi, 
            staff_pos => $staff_pos, 
            placement => $placement 
        };
        
        printf("Event %2d: MIDI %-3d | StaffPos: %-4d | Placement: %s\n", 
               $event_count, $midi, $staff_pos, $placement);
               
        $note_count++;
    }
    $event_count++;
}

if ($note_count == 0) {
    print "\nWarning: No Note or Rest events were found. Check your LilyPond output format.\n";
}

print "\n--- Transposition Recommendation ---\n";

# Transposition Analysis (Your suggested logic, modified to use array of hashes)
# Define a target MIDI range (e.g., one octave centered around middle C)
my $TARGET_LOW = 55; # G4 (Lowest staff line)
my $TARGET_HIGH = 79; # G5 (Highest note for comfortable treble staff display with ledger lines)

# For a single boolean check, we can use a strict cutoff, like MIDI 60 (Middle C)
my $LOW_COUNT = 0;
my $HIGH_COUNT = 0;

foreach my $data (@midi_data) {
    if ($data->{midi} < $TARGET_LOW) {
        $LOW_COUNT++;
    } elsif ($data->{midi} > $TARGET_HIGH) {
        $HIGH_COUNT++;
    }
}

my $action = "None";

if ($LOW_COUNT > $HIGH_COUNT * 2) { # If significantly more low notes
    $action = "Up (+12 Semitones)";
} elsif ($HIGH_COUNT > $LOW_COUNT * 2) { # If significantly more high notes
    $action = "Down (-12 Semitones)";
} else {
    $action = "Stay (Well-centered or balanced)";
}

printf("Total notes: %d\n", $note_count);
printf("Notes below MIDI %d (Target Low): %d\n", $TARGET_LOW, $LOW_COUNT);
printf("Notes above MIDI %d (Target High): %d\n", $TARGET_HIGH, $HIGH_COUNT);
printf("Recommended Transposition Action: %s\n", $action);

print "--- Extraction Complete ---\n";
