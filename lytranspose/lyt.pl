#!/usr/bin/perl

=head1 NAME

ly2transpose.pl - Complete LilyPond to transpose analysis pipeline

=head1 SYNOPSIS

  # Basic usage with default Eb clarinet
  ./ly2transpose.pl mypiece.ly

  # Specify different instrument
  ./ly2transpose.pl mypiece.ly alto_sax
  ./ly2transpose.pl mypiece.ly Bb_clarinet

  # Show help
  ./ly2transpose.pl --help

=head1 DESCRIPTION

This script runs the complete pipeline to analyze LilyPond files and determine
the optimal global octave shift for transposing instruments:

1. lilypond --include=lytranspose/ file.ly (compile with displayLilyMusic)
2. ly2midi.pl (extract MIDI note numbers)
3. best_octave.pl instrument (analyze octave shifts and output transpose command)

The script outputs both the analysis and the LilyPond \\transpose command
to use in your score.

=cut

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

# Get the directory where this script is located
my $script_dir = dirname(abs_path($0));

# Command line arguments
my $lilypond_file = shift @ARGV;
my $instrument = shift @ARGV // 'Eb_clarinet';

# Handle help option
if (!$lilypond_file || $lilypond_file eq '--help' || $lilypond_file eq '-h') {
    print "Usage: $0 <lilypond_file.ly> [instrument]\n";
    print "\nAnalyzes LilyPond file and determines optimal transpose for target instrument.\n\n";
    print "Arguments:\n";
    print "  lilypond_file.ly    LilyPond file to analyze\n";
    print "  instrument          Target instrument (default: Eb_clarinet)\n";
    print "\nAvailable instruments:\n";
    print "  Eb_clarinet, alto_sax, Bb_clarinet, tenor_sax, trumpet, Eb_horn\n";
    print "\nExamples:\n";
    print "  $0 mypiece.ly                    # Default Eb clarinet\n";
    print "  $0 mypiece.ly alto_sax          # Alto saxophone\n";
    print "  $0 mypiece.ly Bb_clarinet       # Bb clarinet\n";
    print "  $0 --help                       # Show this help\n";
    print "\nOutput includes:\n";
    print "  - Instrument analysis and range information\n";
    print "  - Optimal octave shift recommendation\n";
    print "  - LilyPond \\transpose command to use\n";
    exit;
}

# Validate input file exists and is readable
unless (-f $lilypond_file && -r $lilypond_file) {
    die "Error: Cannot read LilyPond file '$lilypond_file'\n";
}

# Check if lytranspose directory exists (relative to script location)
my $lytranspose_dir = "$script_dir/..";
unless (-d $lytranspose_dir) {
    die "Error: Cannot find lytranspose directory at '$lytranspose_dir'\n";
}

# Build the command pipeline
my $cmd = "lilypond --include=\"$lytranspose_dir\" \"$lilypond_file\" | " .
          "\"$script_dir/ly2midi.pl\" | " .
          "\"$script_dir/best_octave.pl\" \"$instrument\"";

print "Running: $cmd\n";
print "=" x 60 . "\n";

# Execute the pipeline
my $exit_code = system($cmd);

if ($exit_code != 0) {
    die "\nPipeline failed with exit code: $exit_code\n";
}

print "=" x 60 . "\n";
print "Pipeline completed successfully!\n";
