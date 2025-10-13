#!/usr/bin/perl
use strict;
use warnings;
use constant TRANSPOSE_EB => 9; # written = concert + 9 semitones

# Comfortable sounding range (MIDI) — adjust if needed
my $sounding_low = 41; # F2
my $sounding_high = 84; # C6

# Written range = sounding range + transposition
my $written_low = $sounding_low + TRANSPOSE_EB; # 50
my $written_high = $sounding_high + TRANSPOSE_EB; # 93

#How many octave shifts to test each side (e.g., 1 => test -1,0,+1 octaves)
my $max_octave_shift = 1;

# Example concert MIDI notes (replace with your input)
my @concert = (65, 60, 60, 62, 64, 72, 74, 76, 84, 86, 88, 96, 98, 100, 108);

# Evaluate candidate global shifts k = -$max_octave_shift .. +$max_octave_shift
my @results; for my $k (-$max_octave_shift .. $max_octave_shift) {
     my $in_count = 0; my $out_distance_sum = 0;
      my @written = map { $_ + TRANSPOSE_EB + 12*$k } @concert;
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

my $decision; if ($best->{k} == 0) {
    $decision = "stay (no global octave shift)";
    } elsif ($best->{k} > 0) { $decision = "shift up +$best->{k} octave(s)";
    } else { $decision = "shift down " . $best->{k} . " octave(s)"; }

#Output summary
print "Concert notes: @concert\n";
print "Written range for Eb horn: $written_low .. $written_high (MIDI)\n\n";
print "Evaluated shifts (k octaves):\n";
for my $r (sort { $a->{k} <=> $b->{k} } @results) {
     printf " k=%+d : in=%2d / %2d out_sum=%3d\n", $r->{k}, $r->{in_count}, scalar(@concert), $r->{out_sum}; }
      print "\nBest global decision: $decision\n";
      printf " in-range notes: %d of %d\n", $best->{in_count}, scalar(@concert);
      printf " total out-of-range semitone distance: %d\n", $best->{out_sum};
      print "\nMapped written notes (MIDI -> scientific):\n";
      for my $i (0..$#concert) { my $c = $concert[$i];
          my $w = $best->{written_ref}[$i];
          printf " concert %3d -> written %3d (%s -> %s)\n", $c, $w, midi_to_sci($c), midi_to_sci($w);
          }

#Helper: MIDI -> scientific pitch name (C4=60)
sub midi_to_sci {
     my ($m) = @_;
     my @names = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B');
     my $pc = $m % 12;
     my $oct = int($m / 12) - 1; # MIDI 60 -> C4
     return sprintf("%s%d", $names[$pc], $oct);
    }
