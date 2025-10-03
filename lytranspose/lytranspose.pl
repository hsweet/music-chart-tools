#!/usr/bin/perl

=head1 NAME

klezapp.pl - Process and transpose LilyPond music files for different instruments

=head1 SYNOPSIS

    klezapp.pl [days_to_look_back]

=head1 DESCRIPTION

This script processes LilyPond music files (.ly) by:
1. Transposing them for different instruments (Bb, Eb, Bass)
2. Generating PDFs for each instrument
3. Combining PDFs into a single file
4. Compressing the output
5. Uploading to Google Drive via rclone

=head1 CONFIGURATION

The script uses a configuration hashref at the top of the file that defines:
- Base directory paths
- Output directories for different instrument parts
- File patterns for LilyPond and PDF files
- External tool paths
- Rclone configuration

=head1 PREREQUISITES

- Perl 5.10 or later
- LilyPond (for music notation processing)
- pdftk (for PDF manipulation)
- qpdf (for PDF compression)
- rclone (for cloud storage uploads)

=head1 USAGE

    # Process files modified in the last day
    klezapp.pl 1
    
    # Process files modified in the last 7 days
    klezapp.pl 7

=cut

use strict;
use warnings;
use feature qw(say);
use File::Path qw(make_path remove_tree);

# ============ Configuration ============
# Base directory settings
our $config = {
    base_path   => "/home/harry/Music/charts/world",
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

# Get cutoff days from command line or prompt if not provided
my $cutoff_age;
if (@ARGV) {
    $cutoff_age = $ARGV[0];
} else {
    print "How many days to look back? ";
    $cutoff_age = <STDIN>;
    chomp $cutoff_age;
}

# Validate input
unless (defined $cutoff_age && $cutoff_age =~ /^\d+$/) {
    die "Error: Please provide a valid number of days\n";
}

say "Processing files modified in the last $cutoff_age days";


# Change to base directory
chdir($config->{paths}{base}) or die "Cannot change to directory $config->{paths}{base}: $!\n";
my @instruments = keys %{$config->{output_dirs}};
# Remove non-instrument directories
@instruments = grep { $_ ne 'combined' && $_ ne 'compressed' } @instruments;
my @tune_list = tunes(); 

#*********************** Exit if no recent files ******** 
if (scalar(@tune_list) == 0) {
		say "Nothing to do. Try looking further back.\n";
		say "No charts newer than $cutoff_age days old\n";
		say "Usage \"transpose.pl [days to look back]\"";
		exit 1;
   } else {
	   say "These are the files that will be processed";
	   say "-" x 60;
	   foreach (@tune_list){say} #list tunes
	   say "-" x 60;
	   say "Proceed?..(y/n)";
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
    if (fork() == 0) {
		# Child process
		system("xdg-open combined/compressed");
		exit 0;
	}
	# Parent process continues here
} else {
    say "Failed to generate the combined PDF.";
}

compress();
upload();

# ============ SUBROUTINES ============

=head1 SUBROUTINES

=head2 basename

Extract the base filename without extension

=cut

sub basename {
	my ($tune) = @_;
	my @basename= split(/\./,$tune);
    my $pdf = "$basename[0].pdf";
    return $pdf;
	}

=head2 age

Calculate the age of a file in days

=cut

sub age {
    my ($file) = @_;
    my @is_recent = stat($file);
    my $mtime = $is_recent[9];
    my $days_old = ((time) - $mtime) / 86400;
    return $days_old;
}
	
=head2 tunes

Find all LilyPond files modified within the specified number of days

=cut

sub tunes {
    my $tune_type = "\.ly";
    opendir(my $dh, $config->{paths}{base}) || die "Cannot open directory: $!";
    my @files = readdir($dh);
    closedir($dh);

    my @tunes2use;
    foreach my $tune (@files) {
        if ($tune =~ /$tune_type/ && age($tune) < $cutoff_age) {
            push @tunes2use, $tune;
        }
    }
    return sort @tunes2use;  # recent lilypond files
}

=head2 transpose

Transpose music files for different instruments

Transposition rules:
- Bb Clarinet: C -> D
- Eb Horn: C -> A
- Bass: Change clef (no transposition)

=cut

sub transpose {
    my ($instrument) = @_;
    say "\nTransposing chart\n";
    my $target;
    if ($instrument eq "Bb") {
        $target = "d";
    } elsif ($instrument eq "Eb") {
        $target = "a";
    } elsif ($instrument eq "Bass") {
        $target = "bass";
    }

    make_path($instrument);

    foreach my $tune (@tune_list) {
        my $input_file = "$config->{paths}{base}/$tune";
        my $output_file = "$config->{paths}{$instrument}/$tune";
        open(my $input_fh, "<", $input_file) || die "Cannot open file $input_file: $!";
        my @text = <$input_fh>;
        close($input_fh);
        say "$instrument/$tune...";
        open(my $output_fh, ">", $output_file) || die "Cannot create file $output_file: $!";
        
        foreach my $line (@text) {
        $line =~ s/Violin/$instrument/; # display which transposition

		if ($target ne "bass") {
			$line =~ s/\\score \{/\\score \{\\transpose c $target/;
            # for Eb Horn. This ensures the music remains in a playable
            # range after transposition, as Eb instruments sound a 
            #minor third higher than written.
			if ($target eq "a") {
				$line =~ s/relative c(?=\s)/relative c,/g;
				$line =~ s/relative c'(?=\s)/relative c/g;
				$line =~ s/relative c''(?=\s)/relative c'/g;		              
			}
			} elsif ($target eq "bass") {
				$line =~ s/clef treble/clef bass/;
				$line =~ s/relative c'*/relative c/;
		    }
				# Remove the MIDI block
			$line =~s/\\midi\s*{[^}]+}//gs;		 
			print $output_fh $line;
        }
        close($output_fh);
    }
}

=head2 makepdf

Generate PDFs from LilyPond files and combine them

=cut

sub makepdf {
    # **********make pdfs**************
    say "-" x 60;
    say "\nCompiling Lilypond Files";
    foreach my $tune (@tune_list){
        foreach my $inst (@instruments) {
            chdir $config->{paths}{$inst} or die "Cannot change to $inst directory: $!\n";
            my $cmd = "$config->{tools}{lilypond} -s $config->{paths}{$inst}/$tune";
            my $x = `$cmd`;
            #system ("rm *.midi");
        }
    }
    #***********combine pdfs*************
    say "-" x 60;
    say "\nCombining PDFs";
    foreach my $tune (@tune_list){ 
        my $pdf=basename($tune);  
        chdir $config->{paths}{base}; 
        my $pdf_list = join(' ', map { "$_/$pdf" } @instruments);
        my $cmd = "$config->{tools}{pdftk} $pdf_list cat output $config->{paths}{combined}/$pdf";
        system($cmd)
    }
    return 1;
    
}

=head2 compress

Compress PDF files using qpdf

=cut

sub compress{
    say "-" x 60;
    say "Compressing files .. ";
    say "-" x 60;
    my $in_path = $config->{paths}{combined};
    my $out_path = $config->{paths}{compressed};
    make_path($out_path) unless -d $out_path;  # Create compressed directory if it doesn't exist
    for (@tune_list){
		s/\.ly/\.pdf/;
		my $in_file = "$in_path/$_";
		my $out_file = "$out_path/$_";
		#say "$in_file";
		#say "$out_file";
		say;
		system("qpdf --stream-data=compress --object-streams=generate --linearize \"$in_file\" \"$out_file\"");
	}
}

=head2 upload

Upload processed files to Google Drive using rclone

=cut

sub upload{
    # rclone must be installed and configured.
	for (@tune_list){
		say "-" x 60;
		say "Uploading $_";
		say "-" x 60;
		#  charts is predefined in rclone as a folder in gdrive
		my $cmd = "$config->{tools}{rclone} copy -P $config->{paths}{combined}/$_ $config->{rclone}{remote}";
        system($cmd);
	}
}

