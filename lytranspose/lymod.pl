#!/usr/bin/perl

use v5.38;
use strict;
use File::Path;
use File::Copy;
use Cwd;

say "I am running";
say "to delete -o files, run: rm *-o.*";

# Inject \displayLilyMusic into a collection of lilypond files

my $in_place = 0;  # Set to 1 to modify files in place (with backup)
my $backup_suffix = '.bak';

# Check for command line arguments
my $i = 0;
while ($i < @ARGV) {
    my $arg = $ARGV[$i];
    if ($arg eq '--in-place' || $arg eq '-i') {
        $in_place = 1;
    } elsif ($arg eq '--backup-suffix' || $arg eq '-b') {
        if ($i + 1 < @ARGV) {
            $backup_suffix = $ARGV[$i + 1];
            $i += 2;  # Skip this argument and the next one
            next;
        }
    }
    $i++;
}

my $file_type="\." . "ly";
my $base_dir = "/home/harry/bin/python/music-chart-tools/lytranspose/samples";
chdir $base_dir;

sub process_file {
    my ($input_file) = @_;
    
    open(my $fh, '<', $input_file) || die "Can't open file $input_file: $!";
    my @content = <$fh>;
    close $fh;
    
    # Create output - either new file or temp file for in-place modification
    my $output_file;
    my $backup_file;
    
    if ($in_place) {
        $backup_file = "$input_file$backup_suffix";
        $output_file = "$input_file.tmp";
        
        # Create backup
        if (-e $backup_file) {
            warn "Backup file $backup_file already exists, skipping backup for $input_file\n";
        } else {
            copy($input_file, $backup_file) || die "Failed to create backup $backup_file: $!";
            say "Created backup: $backup_file";
        }
    } else {
        $input_file =~ s/\.ly$//;
        $output_file = "${input_file}-o.ly";
    }
    
    open(my $out, '>', $output_file) || die "Can't create output file $output_file: $!";
    
    my $i = 0;
    my $skip_next = 0;
    my $modified = 0;
    
    foreach my $line (@content){
        if ($skip_next) {
            $skip_next = 0;
            next;
        }
        
        my $original_line = $line;
        
        # Check for \new Staff pattern
        if ($line =~ /\s*\\new\s+Staff\s*$/) {
            # Look ahead to see if next line has \melody
            if ($i + 1 < @content && $content[$i + 1] =~ /\s*\\melody\s*$/) {
                # Combine into one line with \displayLilyMusic
                $line =~ s/(\s*\\new\s+Staff)\s*$/$1 \\displayLilyMusic \\melody/;
                $modified = 1;
                # Skip the next line (the \melody line)
                $skip_next = 1;
            } else {
                # No \melody on next line, just output the line as is
                # Could be modified later if needed
            }
        } elsif ($line =~ /\s*\\new\s+Staff\s+\\melody\s*$/) {
            # Handle same-line case
            $line =~ s/(\s*\\new\s+Staff)\s+(\s*\\melody\s*$)/$1 \\displayLilyMusic $2/;
            $modified = 1;
        }
        
        print $out $line;
        $i++;
    }
    close $out;
    
    if ($in_place) {
        # Atomic move: remove original, rename temp to original
        unlink $input_file || die "Failed to remove original file $input_file: $!";
        rename $output_file, $input_file || die "Failed to rename $output_file to $input_file: $!";
        say "Modified $input_file in place (backup: $backup_file)";
    } else {
        say "Created $output_file" . ($modified ? " (modified)" : " (no changes)");
    }
}

sub get_tunes {
    # Make a list of all the lilypond files in a folder
    # this could be done with a system call to ls
    
    my $tune_type = qr/\.ly$/i;  #lily files
    opendir(my $dir,$base_dir) || die "$base_dir is not a valid directory: $!";
    my @files=grep(/$file_type/, readdir $dir);	#Just lily files
    return @files;
} 

foreach my $tune (get_tunes){
    eval { process_file($tune); };
    if ($@) {
        warn "Error processing $tune: $@";
    }
}

say "Processing complete.";


#$_ = "    \\new Staff   \\melody";
#s/\s*\\new\s*Staff\s*\\melody/\\new Staff \\displayLilyMusic \\melody/;


__END__
# Test against next line
$_ = "    \\key e \\major";
s\\\w*\s+[a-g]\s*\\(minor|major)/--/;
#print"If you see nothing it is working";
#say;
