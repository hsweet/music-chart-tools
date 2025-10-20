#!/usr/bin/perl

=head1 NAME

lytranspose.pl - Process and transpose LilyPond music files for different instruments

=head1 SYNOPSIS

    lytranspose.pl [days_to_look_back]

=head1 DESCRIPTION

This script processes LilyPond music files (.ly) by:
1. Transposing them for different instruments (Bb, Eb, Bass)
2. Generating PDFs for each instrument
3. Combining PDFs into a single file
4. Compressing the output
5. Uploading to Google Drive via rclone

The script includes comprehensive error handling, input validation, and security
features to ensure safe and reliable operation.

=head1 CONFIGURATION

The script uses a configuration hashref at the top of the file that defines:
- Base directory paths
- Output directories for different instrument parts
- File patterns for LilyPond and PDF files
- External tool paths
- Rclone configuration

=head1 PREREQUISITES

=head2 Perl Version

- Perl 5.10 or later

=head2 Required Perl Modules

- File::Path
- File::Spec
- File::Basename
- Carp
- Scalar::Util
- Try::Tiny
- File::Spec::Functions
- IPC::System::Simple

=head2 External Tools

- LilyPond (for music notation processing)
- pdftk (for PDF manipulation)
- qpdf (for PDF compression)
- rclone (for cloud storage uploads, optional)

The script will check for all required tools at startup and report any missing dependencies.

=head1 USAGE

    # Process files modified in the last day
    lytranspose.pl 1
    
    # Process files modified in the last 7 days
    lytranspose.pl 7
    
    # Interactive mode (prompts for number of days)
    lytranspose.pl

=head1 FEATURES

=head2 Error Handling

- Validates all external tools are available at startup
- Checks file permissions and existence before operations
- Provides detailed error messages with [ERROR] and [WARNING] prefixes
- Continues processing remaining files if one fails
- Returns meaningful exit codes

=head2 Security

- Path traversal protection via safe_join_path()
- Filename sanitization to prevent malicious input
- Command whitelisting for external tool execution
- Input validation for all user-provided data

=head2 Robustness

- Graceful handling of missing files
- Automatic directory creation
- File size reporting for compression
- Progress indicators during processing

=cut

use strict;
use warnings;
use feature qw(say);
use File::Path qw(make_path remove_tree);
use File::Spec;
use File::Basename;
use autodie qw(:all);
use Carp qw(croak carp);
use Scalar::Util qw(looks_like_number);
use Try::Tiny;
use File::Spec::Functions qw(canonpath abs2rel);
use IPC::System::Simple qw(capturex);
use Cwd qw(getcwd);
use constant SECONDS_PER_DAY => 86400;

# ============ Configuration ============
# Base directory settings
our $config = {
    #base_path   => "/home/harry/Music/charts/world",
    # for testing
    base_path   => "/home/harry/bin/python/music-chart-tools/lytranspose",
    output_dirs => {
        combined  => 'combined',
        compressed=> 'compressed',
        Bb        => 'Bb',
        Eb        => 'Eb',
        Bass      => 'Bass'
    },
    
    # File patterns
    file_patterns => {
        lilypond => qr/\.ly$/,
        pdf      => qr/\.pdf$/
    },
    
    # External tools
    tools => {
        lilypond => 'lilypond',
        pdftk    => 'pdftk',  # PDF concantation tool
        qpdf     => 'qpdf',   # compression tool
        rclone   => 'rclone'  # google drive tool
    },
    
    # Rclone configuration
    rclone => {
        remote => 'charts:'  # Predefined rclone remote
    }
};

# Create full paths
$config->{paths} = {
    base       => $config->{base_path},
    combined   => "$config->{base_path}/$config->{output_dirs}{combined}",
    compressed => "$config->{base_path}/$config->{output_dirs}{combined}/$config->{output_dirs}{compressed}"
};

# Add instrument paths
foreach my $inst (keys %{$config->{output_dirs}}) {
    next if $inst eq 'combined' || $inst eq 'compressed';
    $config->{paths}{$inst} = "$config->{base_path}/$inst";
}

# ============ End Configuration ============

=head1 MAIN SCRIPT EXECUTION

=cut

if ($^O eq 'MSWin32') { system("cls"); } else { system("clear"); }

# Check for required tools at startup and get their full paths
sub check_required_tools {
    my $missing_tools = 0;
    my %tool_paths;
    
    foreach my $tool_name (keys %{$config->{tools}}) {
        my $tool = $config->{tools}{$tool_name};
        my $path = '';
        
        # Skip if already an absolute path
        if (File::Spec->file_name_is_absolute($tool) && -x $tool) {
            $path = $tool;
        } else {
            # Find in PATH
            for my $dir (split(':', $ENV{PATH} || '')) {
                my $full_path = "$dir/$tool";
                if (-x $full_path) {
                    $path = $full_path;
                    last;
                }
            }
        }
        
        if ($path) {
            $tool_paths{$tool_name} = $path;
        } else {
            carp "[WARNING] Required tool '$tool' not found in PATH";
            $missing_tools++;
        }
    }
    
    croak "[ERROR] $missing_tools required tools are missing. Please install them before proceeding." if $missing_tools;
    
    # Update config with full paths
    $config->{tool_paths} = \%tool_paths;
}

# Get and validate cutoff days
sub get_cutoff_days {
    my $cutoff;
    if (@ARGV) {
        $cutoff = $ARGV[0];
        unless (looks_like_number($cutoff) && $cutoff >= 0) {
            croak "[ERROR] Days to look back must be a positive number";
        }
    } else {
        local $| = 1;  # autoflush
        say "How many days to look back?";
        $cutoff = <STDIN>;
        chomp $cutoff;
        unless (looks_like_number($cutoff) && $cutoff >= 0) {
            croak "[ERROR] Please enter a valid positive number";
        }
    }
    return int($cutoff);
}

# Initialize with error checking
check_required_tools();
my $cutoff_age = get_cutoff_days();

say "\nProcessing files modified in the last $cutoff_age days\n";


# Change to base directory
chdir($config->{paths}{base}) or die "Cannot change to directory $config->{paths}{base}: $!\n";
# Define instruments in the desired order for PDF concatenation
my @instruments = qw(Bb Eb Bass);
my @tune_list = tunes(); 

#*********************** Exit if no recent files ******** 
if (scalar(@tune_list) == 0) {
		say "Nothing to do. Try looking further back.\n";
		say "No charts newer than $cutoff_age days old\n";
		say "Usage \"transpose.pl [days to look back]\"";
		exit 1;
   } else {
       #say "-" x 60;
	   say "Files to be processed\n";
	   say "-" x 60;
	   foreach (@tune_list){say} #list tunes
	   say "-" x 60;
	   say "\nProceed?..(y/n)";
	   my $go = <STDIN>;
	   chomp $go;
	   exit 0 if $go eq "n";
	   }

#********** Transpose or just recompile? ***************
say "\nIs this a new or modified C instrument chart?.. y/n \n";
my $is_newchart = <STDIN>;
chomp $is_newchart;

if ($is_newchart eq "y"){
	foreach my $instrument (@instruments) {
		transpose($instrument); 
	}  
} 
	
#****** But always compile, combine and compress *****
my $combined_pdf = makepdf(@instruments);

if ($combined_pdf) {
	say "-" x 60;
    say "Finished generating combined pdf file(s).";
    
    # Open the compressed directory in file manager
    my $compressed_path = safe_join_path($config->{paths}{combined}, $config->{output_dirs}{compressed});
    if (fork() == 0) {
		# Child process - use absolute path
        # open compressed directory in file manager
		exec("xdg-open", $compressed_path);
		exit 0;
	}
	# Parent process continues here
} else {
    say "Failed to generate the combined PDF.";
}

compress();
#upload();

# ============ SUBROUTINES ============

=head1 SUBROUTINES

=head2 pdfname

Convert a LilyPond filename to its corresponding PDF filename.

Returns the base filename with .pdf extension, removing any existing extension.
Includes input validation.

=cut

# basename() is now provided by File::Basename
# tune.ly ==> tune.pdf
sub pdfname {
    my ($tune) = @_;
    croak "[ERROR] No filename provided to pdfname()" unless defined $tune;
    
    my ($name, $path, $suffix) = fileparse($tune, qr/\.[^.]*/);
    return "$name.pdf";
}

=head2 age

Calculate the age of a file in days.

Returns the number of days since the file was last modified.
Returns -1 if the file cannot be accessed.
Returns 0 for files with future modification times.

=cut

sub age {
    my ($file) = @_;
    croak "[ERROR] No file specified for age check" unless defined $file;
    
    my @stat = stat($file);
    unless (@stat) {
        carp "[WARNING] Cannot stat file '$file': $!";
        return -1;  # Return -1 to indicate error
    }
    
    my $mtime = $stat[9];
    my $days_old = ((time) - $mtime) / SECONDS_PER_DAY;
    
    return $days_old >= 0 ? $days_old : 0;  # Ensure non-negative
}

=head2 safe_system

Execute external commands safely with validation and error handling.

Takes a command name and arguments, validates the command is in the whitelist,
uses the full path to the executable, and captures output safely using
IPC::System::Simple. Returns a tuple of (success_boolean, output_string).

=cut

sub safe_system {
    my ($cmd, @args) = @_;
    croak "[ERROR] No command specified" unless defined $cmd;
    
    # Ensure the command is in our allowed list
    my ($tool_name) = ($cmd =~ /([^\/]+)$/);
    unless (exists $config->{tool_paths}{$tool_name}) {
        croak "[SECURITY] Attempted to execute unauthorized command: $cmd";
    }
    
    # Use the full path to the command
    my $full_cmd = $config->{tool_paths}{$tool_name};
    
    # Execute safely
    try {
        my $output = capturex($full_cmd, @args);
        return (1, $output);
    } catch {
        chomp(my $error = $_);
        return (0, "Command failed: $error");
    };
}

=head2 safe_join_path

Safely join path components with directory traversal protection.

Constructs a file path from base directory and path components, resolves it
to an absolute path, and validates that the result is within the base directory.
Throws an error if path traversal is detected (e.g., using ../ sequences).

=cut

sub safe_join_path {
    my ($base, @parts) = @_;
    my $path = File::Spec->catfile($base, @parts);
    my $abs_path = File::Spec->rel2abs($path);
    my $base_abs = File::Spec->rel2abs($config->{base_path});
    
    # Check if the resulting path is under the base directory
    if (index($abs_path, $base_abs) != 0) {
        croak "[SECURITY] Attempted path traversal detected: $path";
    }
    
    return $abs_path;
}

=head2 sanitize_filename

Sanitize a filename to remove potentially dangerous characters.

Removes directory path components, filters out special characters (keeping only
alphanumeric, dash, underscore, and dot), and prevents hidden files. Throws an
error if the filename becomes empty after sanitization.

=cut

sub sanitize_filename {
    my ($filename) = @_;
    return '' unless defined $filename;
    
    # Remove any directory components
    $filename =~ s#^.*/##s;
    
    # Remove potentially dangerous characters (keep only word chars, dash, dot)
    $filename =~ s/[^\w\-\.]//g;
    
    # Ensure it's not a hidden file
    $filename =~ s/^\.+//;
    
    # Ensure it's not empty after sanitization
    croak "[ERROR] Invalid filename after sanitization" unless $filename;
    
    return $filename;
}

=head2 tunes

Find all LilyPond files modified within the specified number of days.

Scans the base directory for .ly files and returns a sorted list of
filenames that have been modified within the cutoff period. Uses
safe path handling to prevent directory traversal.

=cut

sub tunes {
    my $tune_type = qr/\.ly$/i;
    my $base_dir = $config->{paths}{base};
    
    opendir(my $dh, $base_dir) 
        or croak "[ERROR] Cannot open directory '$base_dir': $!";
    
    my @tunes2use;
    while (my $entry = readdir($dh)) {
        next unless $entry =~ $tune_type;
        
        my $file = safe_join_path($base_dir, $entry);
        next unless -f $file;
        
        my $age = age($file);
        next if $age == -1;  # Skip if stat failed
        
        push @tunes2use, $entry if $age < $cutoff_age;
    }
    closedir($dh);
    
    return sort @tunes2use;
}

=head2 transpose

Transpose music files for different instruments

Transposition rules:
- Bb Clarinet: C -> D  Up a 2nd or 9th
- Eb Horn: C -> A  Up a 6th or 13th or down minor 1/3rd
- Bass: Change clef (no transposition)
- Range Bb3 -> C6

=cut

# Helpers for transpose() (defined before use)
sub target_for_instrument {
    my ($instrument) = @_;
    return 'd'    if $instrument eq 'Bb';
    return 'a'    if $instrument eq 'Eb';
    return 'bass' if $instrument eq 'Bass';
    croak "[ERROR] Unknown instrument: $instrument";
}

sub change_instrument_name {
    my ($line, $instrument) = @_;
    $line =~ s/(instrument\s*=\s*")(Violin|)(")/qq($1$instrument$3)/ige;
    return $line;
}

sub rewrite_target_line {
    my ($line, $target) = @_;
    if ($target ne 'bass') {
        $line =~ s/\\score \{/\\score \{\\transpose c $target/;
        if ($target eq 'a') {
            # Eb adjustments of relative
            $line =~ s/relative c(?=\s)/relative c,/g;
            $line =~ s/relative c'(?=\s)/relative c/g;
            $line =~ s/relative c''(?=\s)/relative c'/g;
        }
    } else {
        $line =~ s/clef treble/clef bass/;
        $line =~ s/relative c'*/relative c/;
    }
    return $line;
}

sub strip_midi {
    my ($line) = @_;
    $line =~ s/\\midi\s*\{[^}]+\}//gs;
    return $line;
}


sub transpose {
    my ($instrument) = @_;
    croak "[ERROR] Invalid instrument: $instrument" 
        unless exists $config->{output_dirs}{$instrument};
    
    say "\nTransposing chart for $instrument\n";
    
    # \transpose c $target in lilypond
    my $target = target_for_instrument($instrument);

    # Create output directory safely
    my $output_dir = safe_join_path($config->{base_path}, $instrument);
    mkdir_if_absent($output_dir);

    foreach my $tune (@tune_list) {
        # Sanitize input filename
        my $safe_tune = sanitize_filename($tune);
        
        my $input_file = safe_join_path($config->{paths}{base}, $safe_tune);
        my $output_file = safe_join_path($output_dir, $safe_tune);
        
        # Check if input file exists and is readable
        unless (-r $input_file) {
            carp "[WARNING] Cannot read input file: $input_file";
            next;
        }
        
        say "$instrument/$safe_tune...";
        
        # Read input file
        open(my $input_fh, "<", $input_file) 
            or do { carp "[WARNING] Cannot open file $input_file: $!"; next };
        
        my @text = <$input_fh>;
        close($input_fh);
        
        # Check for absolute mode (no \relative and multiple octave marks)
        my $has_relative = 0;
        my $octave_mark_count = 0;
        foreach my $check_line (@text) {
            $has_relative = 1 if $check_line =~ /\\relative/;
            # Count octave marks (single or double quotes after note names)
            # Match patterns like: cis''8 or d''16 or b'8
            $octave_mark_count++ while $check_line =~ /[a-g](?:is|es)?''+/gi;
        }
        
        # Warn if file appears to be in absolute mode
        if (!$has_relative && $octave_mark_count > 15) {
            say "[WARNING] $safe_tune appears to be in ABSOLUTE mode (no \\relative directive, $octave_mark_count octave marks found)";
            say "          Transposition may produce unexpected results. Consider converting to relative mode.";
        }
        
        # Process and write output file
        open(my $output_fh, ">", $output_file) 
            or do { carp "[WARNING] Cannot create file $output_file: $!"; next };
        
        foreach my $line (@text) {
            $line = change_instrument_name($line, $instrument);
            $line = rewrite_target_line($line, $target);
            $line = strip_midi($line);
            print $output_fh $line;
        }
        
        close($output_fh) or carp "[WARNING] Error closing $output_file: $!";
    }
}

=head2 makepdf

Generate PDFs from LilyPond files and combine them

=cut

# Helper subs (defined before makepdf to ensure availability)
sub mkdir_if_absent {
    my ($path) = @_;
    make_path($path) unless -d $path;
    return -d $path ? 1 : 0;
}

sub compile_lilypond_file {
    my ($dir, $file) = @_;
    unless (defined $dir && defined $file) {
        return { ok => 0, err => 'Missing directory or file' };
    }
    my $cwd = getcwd();
    unless (chdir($dir)) {
        return { ok => 0, err => "Cannot change to directory: $dir" };
    }
    my $cmd = $config->{tool_paths}{lilypond};  # fancy call to lilypond
    my ($success, $output) = safe_system($cmd, '-s', $file);
    unless (chdir($cwd)) {
        carp "[WARNING] Cannot restore working directory to $cwd: $!";
    }
    return $success ? { ok => 1, out => $output } : { ok => 0, err => $output };
}

sub compile_original_pdf {
    my ($tune) = @_;
    my $safe_tune = sanitize_filename($tune // '');
    my $base_dir = $config->{paths}{base};
    my $base_input = safe_join_path($base_dir, $safe_tune);
    return { ok => 0, err => "Original file not found: $base_input" } unless -f $base_input;
    return compile_lilypond_file($base_dir, $base_input);
}

sub compile_transposed_pdfs {
    my ($tune, $instruments_ref) = @_;
    my $safe_tune = sanitize_filename($tune // '');
    my @results;
    foreach my $inst (@{$instruments_ref // []}) {
        my $inst_dir = safe_join_path($config->{base_path}, $inst);
        my $input_file = safe_join_path($inst_dir, $safe_tune);
        if (-f $input_file) {
            push @results, compile_lilypond_file($inst_dir, $input_file);
        } else {
            push @results, { ok => 0, err => "Input file not found: $input_file" };
        }
    }
    return \@results;
}

sub pdf_paths_for_tune {
    my ($tune, $instruments_ref) = @_;
    my $pdf = pdfname($tune // '');
    my @pdfs;
    my $base_pdf = safe_join_path($config->{paths}{base}, $pdf);
    push @pdfs, $base_pdf if -f $base_pdf;
    foreach my $inst (@{$instruments_ref // []}) {
        my $p = safe_join_path($config->{base_path}, $inst, $pdf);
        push @pdfs, $p if -f $p;
    }
    return \@pdfs;
}

sub combine_pdfs_for_tune {
    my ($tune, $pdfs_ref, $dest_dir) = @_;
    my $pdf = pdfname($tune // '');
    my $output_pdf = safe_join_path($dest_dir, $pdf);
    my $cmd = $config->{tool_paths}{pdftk};
    my ($success, $output) = safe_system($cmd, @{$pdfs_ref // []}, 'cat', 'output', $output_pdf);
    return $success ? { ok => 1, output_pdf => $output_pdf } : { ok => 0, err => $output };
}

sub makepdf {
    # Create combined directory if it doesn't exist
    my $combined_dir = safe_join_path($config->{base_path}, $config->{output_dirs}{combined});
    mkdir_if_absent($combined_dir);

    # **********`make individual pdfs**************
    say "-" x 60;
    say "\nCompiling Lilypond Files";

    foreach my $tune (@tune_list) {
        # Compile original C instrument
        my $orig = compile_original_pdf($tune);
        unless ($orig->{ok}) {
            carp "[WARNING] Failed to compile original C instrument: $orig->{err}";
        }

        # Compile transposed instruments
        my $results = compile_transposed_pdfs($tune, \@instruments);
        for my $res (@{$results}) {
            unless ($res->{ok}) {
                carp "[WARNING] Failed to compile transposed chart: $res->{err}";
            }
        }
    }

    #***********combine pdfs*************
    say "-" x 60;
    say "\nCombining PDFs";

    my @successful_pdfs;

    foreach my $tune (@tune_list) {
        my $pdfs = pdf_paths_for_tune($tune, \@instruments);
        my $expected = 1 + scalar(@instruments); # base + instruments

        unless (@{$pdfs} == $expected) {
            carp "[WARNING] Missing PDFs for $tune (have " . scalar(@{$pdfs}) . "/$expected)";
            next;
        }

        my $combined = combine_pdfs_for_tune($tune, $pdfs, $combined_dir);
        if ($combined->{ok}) {
            push @successful_pdfs, $combined->{output_pdf};
            say "Created: $combined->{output_pdf}";
        } else {
            carp "[WARNING] Failed to combine PDFs for $tune: $combined->{err}";
        }
    }

    return @successful_pdfs ? 1 : 0;
}

=cut

=head2 compress

Compress PDF files using qpdf

=cut

sub compress {
    say "-" x 60;
    say "Compressing files .. ";
    say "-" x 60;
    
    my $in_path = safe_join_path($config->{base_path}, $config->{output_dirs}{combined});
    my $out_path = safe_join_path($in_path, $config->{output_dirs}{compressed});
    
    # Create compressed directory if it doesn't exist
    mkdir_if_absent($out_path);
    
    my $compressed_count = 0;
    
    foreach my $tune (@tune_list) {
        my $pdf = pdfname($tune);
        my $in_file = safe_join_path($in_path, $pdf);
        my $out_file = safe_join_path($out_path, $pdf);
        
        # Skip if input file doesn't exist
        unless (-f $in_file) {
            carp "[WARNING] Input file not found: $in_file";
            next;
        }
        
        say "Compressing: $pdf";
        
        # Use qpdf to compress the PDF
        my $cmd = $config->{tool_paths}{qpdf};
        my ($success, $output) = safe_system(
            $cmd,
            '--stream-data=compress',
            '--object-streams=generate',
            '--linearize',
            $in_file,
            $out_file
        );
        
        if ($success) {
            $compressed_count++;
            my $in_size = -s $in_file;
            my $out_size = -s $out_file;
            my $saved = $in_size - $out_size;
            my $percent = $in_size > 0 ? int(($saved / $in_size) * 100) : 0;
            
            printf("  %s -> %s (saved %d%%, %d bytes)\n",
                format_size($in_size),
                format_size($out_size),
                $percent,
                $saved
            );
        } else {
            carp "[WARNING] Failed to compress $pdf: $output";
        }
    }
    
    say "\nCompressed $compressed_count files to $out_path";
    return $compressed_count;
}

=head2 format_size

Format file sizes in human-readable format (B, KB, MB, GB, TB).

Takes a size in bytes and returns a formatted string with appropriate units.
Used for displaying compression statistics.

=cut

sub format_size {
    my ($bytes) = @_;
    return '0 B' unless $bytes;
    
    my @units = qw(B KB MB GB TB);
    my $unit = 0;
    
    while ($bytes > 1024 && $unit < $#units) {
        $bytes /= 1024;
        $unit++;
    }
    
    return sprintf('%.1f %s', $bytes, $units[$unit]);
}

=head2 upload

Upload processed files to Google Drive using rclone

=cut

sub upload {
    my $in_path = safe_join_path($config->{base_path}, $config->{output_dirs}{combined});
    my $compressed_path = safe_join_path($in_path, $config->{output_dirs}{compressed});
    
    # Check if rclone is configured
    unless (exists $config->{tool_paths}{rclone}) {
        carp "[WARNING] rclone not found or not configured. Skipping upload.";
        return 0;
    }
    
    # Check if remote is configured
    unless (exists $config->{rclone}{remote} && $config->{rclone}{remote}) {
        carp "[WARNING] rclone remote not configured. Skipping upload.";
        return 0;
    }
    
    my $uploaded = 0;
    
    foreach my $tune (@tune_list) {
        my $pdf = pdfname($tune);
        my $local_file = safe_join_path($compressed_path, $pdf);
        
        # Skip if file doesn't exist
        unless (-f $local_file) {
            carp "[WARNING] File not found for upload: $local_file";
            next;
        }
        
        say "-" x 60;
        say "Uploading $pdf";
        say "-" x 60;
        
        # Use rclone to upload the file
        my $cmd = $config->{tool_paths}{rclone};
        my ($success, $output) = safe_system(
            $cmd,
            'copy',
            '--progress',
            $local_file,
            $config->{rclone}{remote}
        );
        
        if ($success) {
            $uploaded++;
            say "Uploaded: $pdf";
        } else {
            carp "[WARNING] Failed to upload $pdf: $output";
        }
    }
    
    say "\nUploaded $uploaded files to $config->{rclone}{remote}";
    return $uploaded;
}

