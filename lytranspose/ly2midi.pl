#!/usr/bin/perl
use strict;
use warnings;

# --- Configuration ---
my $input_file = "music_data.txt";

# --- Subroutine ---

# Calculates the MIDI number based on LilyPond's internal pitch components.
# The arguments must be supplied as: ($octave, $name, $alteration)
# 1. $octave: Octave number (0 = C4/c', 1 = C5/c'', etc.)
# 2. $name: Note name (0 = C, 1 = D, ..., 6 = B)
# 3. $alter: Alteration (0 = natural, 1 = sharp, -1 = flat, 1/2 = quarter-tone sharp, etc.)
sub calculate_midi {
    my ($octave, $name, $alter) = @_;
    
    # Handle fractional alterations like 1/2 or -1/2.
    my $adjusted_alter = $alter;
    if ($alter =~ /^-?\d+\/\d+$/) {
        # 'eval' is necessary here to calculate the fractional value (e.g., 1/2 = 0.5)
        # We must protect eval to prevent runtime errors if the string is malformed
        eval { $adjusted_alter = eval $alter; };
        if ($@) {
             # If eval fails, assume zero alteration as a fallback
             $adjusted_alter = 0;
             warn "Warning: Failed to evaluate alteration '$alter'. Assuming 0.\n";
        }
    }

    # Round the total number of semitones
    my $semitones = $name + $adjusted_alter;
    my $rounded_semitones = int($semitones + 0.5);

    # Calculate MIDI number
    my $midi_num = ($octave * 12) + $rounded_semitones + 12;
    return $midi_num;
}

# --- Main Logic ---

print "--- Starting MIDI Data Extraction from $input_file ---\n";

# 1. Open the file for reading.
my $fh; 
unless (open($fh, '<', $input_file)) { 
    die "Error: Cannot open $input_file: $!";
}

print "--- Extracted MIDI Values ---\n";
my $event_count = 0;
my $note_count = 0;
my @pitch_lines = ();

# 2. Read the file line-by-line and filter for relevant events.
while (my $line = <$fh>) {
    # Check for NoteEvent pitch line
    if ($line =~ /ly:make-pitch/) {
        # Clean up whitespace and push the line to be processed
        $line =~ s/^\s+|\s+$//g; # trim leading/trailing space
        push @pitch_lines, $line;
    } 
    # Check for RestEvent lines (which often just contain 'RestEvent')
    elsif ($line =~ /RestEvent/) {
        # We push a marker for RestEvent
        push @pitch_lines, "RestEvent";
    }
}
close($fh); 

# 3. Process the filtered lines.
foreach my $event_line (@pitch_lines) {
    
    if ($event_line eq "RestEvent") {
        print "Event $event_count: RestEvent - \#f\n";
        $note_count++;
        
    } elsif ($event_line =~ /ly:make-pitch/) {
        # 4. Extract pitch components from a filtered line
        # The internal structure is: (ly:make-pitch OCTAVE NAME [ALTERATION])
        
        my ($octave, $name, $alter) = (0, 0, 0); # Default values

        # Attempt 1: Match the 3-argument signature (full pitch)
        if ($event_line =~ /ly:make-pitch\s+([-\d]+)\s+([-\d\/]+)\s+([-\d\/]+)/) {
            $octave = $1;
            $name = $2;
            $alter = $3;
            
        # Attempt 2: Match the 2-argument signature (zero alteration)
        } elsif ($event_line =~ /ly:make-pitch\s+([-\d]+)\s+([-\d\/]+)/) {
            $octave = $1;
            $name = $2;
            $alter = 0; # Alteration is implicitly 0
            
        } else {
            # This should ideally not happen if filtering worked correctly
            print "Event $event_count: NoteEvent - Pitch information malformed in line: $event_line\n";
            $event_count++;
            next; # Skip to the next event
        }
        
        # Calculate and display
        my $midi = calculate_midi($octave, $name, $alter); 
        print "Event $event_count: NoteEvent - MIDI $midi (Octave:$octave, Name:$name, Alter:$alter)\n";
        $note_count++;
    }
    # Increment event count only for things we actually process (notes/rests)
    $event_count++;
}

if ($note_count == 0) {
    print "Warning: No Note or Rest events were found. The parser did not find music events.\n";
}

print "--- Extraction Complete ---\n";
