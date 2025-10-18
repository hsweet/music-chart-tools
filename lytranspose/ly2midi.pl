#!/usr/bin/perl

=head1 NAME

ly2midi.pl - Extract and convert LilyPond notes to MIDI note numbers

=head1 SYNOPSIS

  # Pipeline usage (clean output)
  lilypond file.ly | ./ly2midi.pl

  # Verbose mode with detailed analysis
  lilypond file.ly | ./ly2midi.pl -v

  # Standalone verbose analysis
  ./ly2midi.pl -v < lilypond_output.txt

=head1 DESCRIPTION

This script reads LilyPond output from STDIN and extracts musical notes,
converting them to MIDI note numbers. By default, outputs only the MIDI
numbers for pipeline use. Use -v for detailed analysis.

=cut

use strict;
use String::Util qw/ltrim/;
use List::Util qw( min max sum);
use Getopt::Long;
use v5.38;

# Command line options
my $verbose = 0;
GetOptions(
    'v|verbose' => \$verbose,
    'h|help'    => sub { show_help() }
) or die "Invalid options. Use -h for help.\n";

sub show_help {
    print "Usage: $0 [options]\n";
    print "Reads LilyPond output from STDIN and extracts MIDI note numbers.\n\n";
    print "Options:\n";
    print "  -v, --verbose    Show detailed analysis and statistics\n";
    print "  -h, --help       Show this help message\n";
    print "\nExamples:\n";
    print "  lilypond file.ly | $0              # Clean MIDI output for pipeline\n";
    print "  lilypond file.ly | $0 -v           # Verbose analysis mode\n";
    print "  cat output.txt | $0 -v             # Analyze existing output\n";
    exit;
}

my @midi;
my $cnt;
my $CEILING = 83;
my $FLOOR = 55;
my $CENTER = 72;  # C5 middle of staff in treble clef

# es or f = flat, is or s = sharp
my %note_value = (
# naturals
c => 0.0, d => 1.0, e => 2.0, f => 3.0, g => 4.0, a => 5.0, b => 6.0,
# sharps (two common LilyPond suffix forms: is and s)
cis => 0.5, cs  => 0.5,
dis => 1.5, ds  => 1.5,
eis => 3.0, es  => 3.0, # es == f (eis is E#). esh included in case of alternate typing 
fis => 3.5, fs  => 3.5,
gis => 4.5, gs  => 4.5,
ais => 5.5, as  => 5.5,  # as == bf
bis => 6.0, bs  => 6.0,  # bs ==  c

# flats (two common forms: es and f)
ces => 5.5, cf  => 5.5,   # ces == cb == bf
des => 1.5, df  => 1.5,
ees => 1.5, ef  => 1.5,   # ef == ds 
fes => 2.0, ff  => 2.0,   # fes == fb == e
ges => 3.5, gf  => 3.5,   
aes => 4.5, af  => 4.5,
bes => 5.5, bf  => 5.5,   # weird, looks like it should be 5.5  
);

# Start
system("clear");
say "Running Lilypond...";
sleep(1);
system("clear");
say "Extracting MIDI notes...";
sleep(1);
system("clear");
say "Analyzing...";
sleep(1);
system("clear");
say "Done!";
sleep(1);
system("clear");

# Read all input
my @input = <STDIN>;
my $all_input = join('', @input);

# Filter out \key command lines to avoid false note matches
my @filtered_input;
foreach my $line (@input) {
    # Skip lines that start with \key (key signature commands)
    $line =~ s/\\key\s+[a-g]\w*\s*\\(minor|major)//g;  # remove \key commands
    push @filtered_input, $line;
}
my $filtered_input = join('', @filtered_input);
# Verbose output: show filtered input if different from original
if ($verbose) {
    if ($filtered_input ne $all_input) {
        say "*" x 60;
        say "Filtered LilyPond input (removed \\key commands):";
        say $filtered_input;
        say "*" x 60;
    } else {
        say "*" x 60;
        say "Full LilyPond input:";
        say $all_input;
        say "*" x 60;
    }
}

# Extract all note pitches using regex
# Pattern matches complete note specifications at word boundaries
# Examples: c, d', e'', f, gis, bes,, c4, e'4, etc.
my @raw_notes = $filtered_input =~ /(\b[a-g](?:is|es|s|f)?(?:\d+)?[']*(?:,+)?)\b/g;

if ($verbose) {
    say "Found " . scalar(@raw_notes) . " note elements";
    say "Raw notes: " . join(", ", @raw_notes);
}

# Process notes: separate note names from octave indicators
my @notes;
foreach my $full_note (@raw_notes) {
    # Skip rests
    next if $full_note =~ /^r/;
    
    # Extract octave indicators (apostrophes and commas at the end)
    my $octave_indicators = '';
    if ($full_note =~ s/([']+)$//) {
        $octave_indicators .= $1;
    }
    if ($full_note =~ s/([,]+)$//) {
        $octave_indicators .= $1;
    }
    
    # Remove duration numbers for lookup
    $full_note =~ s/\d+$//;
    
    push @notes, [$full_note, $octave_indicators];
}

if ($verbose) {
    say "Processed " . scalar(@notes) . " notes";
}

foreach my $note_ref (@notes) {
    $note_ref->[0] =~ s/\d+$//;  # remove trailing numbers (durations) from note name
}

if ($verbose) {
    #say "Final notes to process:";
    #foreach my $note_ref (@notes) {
    #    say "  " . $note_ref->[0] . $note_ref->[1];
    #}
}

# Function to convert LilyPond note to MIDI note number
sub note_to_midi {
    my ($note_name, $octave_indicators) = @_;

    # Calculate octave offset from indicators
    my $octave_count = ($octave_indicators =~ tr/'//) - ($octave_indicators =~ tr/,//);

    # Clean the note name for hash lookup (remove octaves but keep accidentals)
    my $clean_note = $note_name;
    $clean_note =~ s/['']//g;  # remove apostrophes
    $clean_note =~ s/,//g;     # remove commas

    if ($verbose) {
        say "Converting note: $note_name with octaves: $octave_indicators -> clean: $clean_note";
    }

    if(exists $note_value{$clean_note}){
        my $midi_note = ($note_value{$clean_note}) + ($octave_count * 12) + 48;  # 60 = MIDI note for C4 (octave 0)
        if ($verbose) {
            say "MIDI calculation: $clean_note -> $note_value{$clean_note}, octaves: $octave_count, final: $midi_note";
        }
        return $midi_note;
    } else {
        if ($verbose) {
            warn "Unknown note: $clean_note (from $note_name)";
        }
        return undef;
    }
}

# convert notes to midi numbers using note_to_midi function
for my $note_ref (@notes){
    my $note_name = $note_ref->[0];
    my $octave_indicators = $note_ref->[1];

    my $midi_note = note_to_midi($note_name, $octave_indicators);

    if(defined $midi_note){
        if ($verbose) {
            say "Adding MIDI note: $midi_note";
        }
        push @midi, $midi_note;   # push midi numbers to array
    } else {
        if ($verbose) {
            say "Skipping undefined MIDI note for: $note_name";
        }
    }
}
 
# Output based on mode
if ($verbose) {
    if (@midi) {
        say "\nMidi notes: " . join(", ", @midi);
        say "Lowest note: " . min(@midi);
        say "Highest note: " . max(@midi);
        say "Average note: " . int(sum(@midi) / @midi);
        # 55 to 83 are violin 1st position
        for (@midi){
            if($_ >= $FLOOR && $_ <= $CEILING){   # if note is in violin 1st position
                $cnt++;
            }
        }
        my $low_notes = 0;
        my $high_notes = 0;
        for (@midi){
            if($_ < $FLOOR){   # low notes below violin 1st position
                $low_notes++;
            }
            if($_ > $CEILING){   # high notes above violin 1st position
                $high_notes++;
            }
        }
       my $percent = int(($cnt / scalar(@midi)) * 100); 
       $percent = sprintf("%.2f", $percent);
       my $total_notes = scalar(@midi);
       say "Number of notes in violin 1st position: $cnt"; 
       say "Percentage of notes in violin 1st position: $percent";
       say "Number of low notes (< $FLOOR): $low_notes";
       say "Number of high notes (> $CEILING): $high_notes";
    } else {
        say "\nNo valid MIDI notes found in input.";
    }
} else {
    # Clean output for pipeline use
    if (@midi) {
        say "MIDI:" . join(",", @midi);
    } else {
        say "MIDI:";  # Empty MIDI output
    }
}