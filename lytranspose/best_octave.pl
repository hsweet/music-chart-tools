#!/usr/bin/perl

=head1 NAME

best_octave.pl - Find optimal global octave shift for transposing instruments

=head1 SYNOPSIS

  # Use default Eb clarinet
  ./best_octave.pl

  # Specify instrument
  ./best_octave.pl alto_sax
  ./best_octave.pl Bb_clarinet
  ./best_octave.pl tenor_sax

  # Show available instruments
  ./best_octave.pl --help

=head1 DESCRIPTION

This script analyzes concert MIDI notes and determines the best global octave shift
to maximize the number of notes that fall within the instrument's comfortable range.

Available instruments:
- Eb_clarinet (default): F2-C6 sounding range, +9 semitones transposition
- alto_sax: A3-C6 sounding range, +9 semitones transposition
- Bb_clarinet: A#3-F6 sounding range, -2 semitones transposition
- tenor_sax: A#3-A5 sounding range, -2 semitones transposition
- trumpet: A#4-A#5 sounding range, -2 semitones transposition
- Eb_horn: F2-C6 sounding range, +9 semitones transposition

=cut

use strict;
use warnings;

# Instrument-specific ranges and transposition data (MIDI note numbers)
my %instruments = (
    'Eb_clarinet' => {
        sounding_low => 41,   # F2
        sounding_high => 84,  # C6
        transpose => 9        # semitones (written = concert + 9)
    },
    'alto_sax' => {
        sounding_low => 49,   # A3
        sounding_high => 84,  # C6
        transpose => 9
    },
    'Bb_clarinet' => {
        sounding_low => 50,   # A#3
        sounding_high => 89,  # F6
        transpose => -2       # semitones (written = concert - 2)
    },
    'tenor_sax' => {
        sounding_low => 54,   # A#3
        sounding_high => 81,  # A5
        transpose => -2
    },
    'trumpet' => {
        sounding_low => 58,   # A#4
        sounding_high => 82,  # A#5
        transpose => -2
    },
    'Eb_horn' => {
        sounding_low => 41,   # F2 (same as Eb clarinet)
        sounding_high => 84,  # C6
        transpose => 9
    }
);

# Default instrument (can be overridden via command line)
my $default_instrument = 'Eb_clarinet';

# Get instrument from command line argument if provided
my $selected_instrument = shift @ARGV;

# Handle help option
if ($selected_instrument && $selected_instrument eq '--help') {
    print "Usage: $0 [instrument_name]\n";
    print "\nAvailable instruments:\n";
    foreach my $inst (sort keys %instruments) {
        my $data = $instruments{$inst};
        printf "  %-12s: %3d-%3d sounding, %+d semitones\n",
               $inst,
               $data->{sounding_low},
               $data->{sounding_high},
               $data->{transpose};
    }
    print "\nExamples:\n";
    print "  $0                    # Use default Eb clarinet\n";
    print "  $0 alto_sax          # Use alto saxophone\n";
    print "  $0 Bb_clarinet       # Use Bb clarinet\n";
    print "  $0 tenor_sax         # Use tenor saxophone\n";
    print "  $0 --help            # Show this help\n";
    exit;
}

my $instrument_name = $selected_instrument // $default_instrument;

# Validate instrument exists
unless (exists $instruments{$instrument_name}) {
    die "Unknown instrument: $instrument_name\n" .
        "Use --help to see available instruments\n";
}

# Get instrument data
my $inst_data = $instruments{$instrument_name};
my $sounding_low = $inst_data->{sounding_low};
my $sounding_high = $inst_data->{sounding_high};
my $transpose_semitones = $inst_data->{transpose};

# Calculate written ranges
my $written_low = $sounding_low + $transpose_semitones;
my $written_high = $sounding_high + $transpose_semitones;

# Read MIDI numbers from STDIN if piped, otherwise use default test data
my @concert;

if (-p STDIN) {
    # Read from pipe
    while (<STDIN>) {
        chomp;
        if (/^MIDI:(.*)$/) {
            my $midi_str = $1;
            if ($midi_str) {
                @concert = split(/,/, $midi_str);
                # Convert to numbers and filter out empty strings
                @concert = grep { $_ ne '' } map { int($_) } @concert;
            }
            last;  # Only read the first MIDI line
        }
    } 
}

# Fallback to test data if no piped input or empty input
unless (@concert) {
    @concert = (65, 60, 60, 62, 64, 72, 74, 76, 84, 86, 88, 96, 98, 100, 108);
}

#How many octave shifts to test each side (e.g., 1 => test -1,0,+1 octaves)
my $max_octave_shift = 1;

# Evaluate candidate global shifts k = -$max_octave_shift .. +$max_octave_shift
my @results; for my $k (-$max_octave_shift .. $max_octave_shift) {
     my $in_count = 0; my $out_distance_sum = 0;
      my @written = map { $_ + $transpose_semitones + 12*$k } @concert;
       for my $w (@written) {
           if ($w >= $written_low && $w <= $written_high) { $in_count++; }
           elsif ($w < $written_low) { $out_distance_sum += ($written_low - $w); }
           else { $out_distance_sum += ($w - $written_high); }
       }
       push @results, { k => $k, in_count => $in_count, out_sum => $out_distance_sum, written_ref => \@written };
   }

# Choose best result: maximize in_count, tiebreaker minimize out_sum, then minimize |k|
@results = sort { $b->{in_count} <=> $a->{in_count} || $a->{out_sum} <=> $b->{out_sum} || abs($a->{k}) <=> abs($b->{k}) || $a->{k} <=> $b->{k} } @results;
my $best = $results[0];

my $total_transposition = $transpose_semitones + (12 * $best->{k});
my $decision; if ($best->{k} == 0) {
    $decision = "stay (no global octave shift)";
    } elsif ($best->{k} > 0) { $decision = "shift up +$best->{k} octave(s)";
    } else { $decision = "shift down " . abs($best->{k}) . " octave(s)"; }

#Output summary
print "Concert notes: @concert\n";
print "Instrument: $instrument_name\n";
print "Sounding range: $sounding_low .. $sounding_high (MIDI)\n";
print "Written range: $written_low .. $written_high (MIDI)\n";
print "Transposition: $transpose_semitones semitones\n\n";
print "Evaluated shifts (k octaves):\n";
for my $r (sort { $a->{k} <=> $b->{k} } @results) {
    printf " k=%+d : in=%2d / %2d out_sum=%3d\n", $r->{k}, $r->{in_count}, scalar(@concert), $r->{out_sum}; }
    print "\nBest global decision: $decision\n";
    printf " in-range notes: %d of %d\n", $best->{in_count}, scalar(@concert);
    printf " total out-of-range semitone distance: %d\n", $best->{out_sum};

# Output LilyPond transpose command
print "\nLilyPond \\transpose command:\n";
print lilypond_transpose_command($transpose_semitones, $best->{k}) . "  % Instrument: $transpose_semitones semitones, Octave: $decision\n";

      print "\nMapped written notes (MIDI -> scientific):\n";
      for my $i (0..$#concert) { my $c = $concert[$i];
          my $w = $best->{written_ref}[$i];
          printf " concert %3d -> transposed %3d (%s -> %s)\n", $c, $w, midi_to_sci($c), midi_to_sci($w);
          }

#Helper: Generate LilyPond transpose command from semitone offset and octave shift
sub lilypond_transpose_command {
    my ($semitones, $octave_shift) = @_;
    
    # For zero semitones, no transpose needed
    if ($semitones == 0 && $octave_shift == 0) {
        return "\\transpose c c";
    }
    
    my @note_names = ('c', 'df', 'd', 'ef', 'e', 'f', 'fs', 'g', 'gs', 'a', 'bf', 'b');
    
    # Get the pitch class from instrument transposition
    my $abs_semitones = abs($semitones);
    my $pitch_class = $abs_semitones % 12;
    my $base_octaves = int($abs_semitones / 12);
    
    my $target_note = $note_names[$pitch_class];
    my $source_note = 'c';
    
    # Combine instrument octaves with the octave shift
    my $total_octaves = $base_octaves + $octave_shift;
    
    # Add octave notation based on direction of instrument transposition
    if ($semitones > 0) {
        # Positive instrument transposition
        if ($total_octaves > 0) {
            $target_note .= "'" x $total_octaves;
        } elsif ($total_octaves < 0) {
            $target_note .= "," x abs($total_octaves);
        }
    } else {
        # Negative instrument transposition
        if ($total_octaves > 0) {
            $target_note .= "'" x $total_octaves;
        } elsif ($total_octaves < 0) {
            $target_note .= "," x abs($total_octaves);
        }
    }
    
    return "\\transpose $source_note $target_note";
}

#Helper: MIDI -> scientific pitch name (C4=60)
sub midi_to_sci {
    my ($m) = @_;
    my @names = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B');
    my $pc = $m % 12;
    my $oct = int($m / 12) - 1; # MIDI 60 -> C4
    return sprintf("%s%d", $names[$pc], $oct);
    }

