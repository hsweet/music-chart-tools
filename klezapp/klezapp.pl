#!/usr/bin/perl
use strict;
use warnings;
use feature qw(say);
use File::Path qw(make_path remove_tree);

=HEAD1
Transpose recently changed lilypond files:
useage ...  tran_load.pl [number of days to look back]
ex. transpose.pl 7 looks back a week

This function calls the tunes()to get a list of all the 
Lilypond files that need to be processed. Then, it loops through that
list and uses lilypond to create PDFs for each instrument 
(Bb, Eb, and Bass) in their respective folders.

Next, it loops through the list again and creates a combined PDF file 
for each Lilypond file using pdftk.  Files are then compressed.
Finally, it calls rclone to send the finished chart to google drive
and opens a file browser.

order = transpose() if new tune, makepdf(), compress()

Bf Clarinet C==>D		Ef Horn C==>A   Bass just change clef
=cut
#************  Setup ************
#my $cutoff_age = $ARGV[0] || 1;
say "How many days to look back?";
my $cutoff_age = <STDIN>; 
chomp $cutoff_age;

my $basepath = "/home/harry/Music/charts/world";
chdir($basepath);
my @instruments = qw(Bb Eb Bass);
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

#************** Subroutines *********************
sub basename{
	my ($tune) = @_;
	my @basename= split(/\./,$tune);
    my $pdf = "$basename[0].pdf";
    return $pdf;
	}

sub age {
    my ($file) = @_;
    my @is_recent = stat($file);
    my $mtime = $is_recent[9];
    my $days_old = ((time) - $mtime) / 86400;
    return $days_old;
}
	
sub tunes {
    my $tune_type = "\.ly";
    opendir(my $dh, $basepath) || die "Cannot open directory: $!";
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
        my $input_file = "$basepath/$tune";
        my $output_file = "$basepath/$instrument/$tune";
        open(my $input_fh, "<", $input_file) || die "Cannot open file $input_file: $!";
        my @text = <$input_fh>;
        close($input_fh);
        say "$instrument/$tune...";
        open(my $output_fh, ">", $output_file) || die "Cannot create file $output_file: $!";
        
        foreach my $line (@text) {
        $line =~ s/Violin/$instrument/; # display which transposition

		if ($target ne "bass") {
			$line =~ s/\\score \{/\\score \{\\transpose c $target/;
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

sub makepdf {
    # **********make pdfs**************
    say "-" x 60;
    say "\nCompiling Lilypond Files";
    foreach my $tune (@tune_list){
        chdir "$basepath/Bb";
        my $x= `lilypond -s $basepath/Bb/$tune`;
        #system ("rm *.midi");
        chdir "$basepath/Eb";
        $x= `lilypond -s $basepath/Eb/$tune`;
        #system ("rm *.midi");
        chdir "$basepath/Bass";
        $x= `lilypond -s $basepath/Bass/$tune`;
        #system ("rm *.midi");
    }
    #***********combine pdfs*************
    say "-" x 60;
    say "\nCombining PDFs";
    foreach my $tune (@tune_list){ 
        my $pdf=basename($tune);  
        chdir $basepath; 
        system("pdftk $pdf Bb/$pdf Eb/$pdf Bass/$pdf cat output combined/$pdf")
    }
    return 1;
    
}

sub compress{
    say "-" x 60;
    say "Compressing files .. ";
    say "-" x 60;
    my $in_path = "$basepath/combined";
    my $out_path = "$basepath/combined/compressed";
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

sub upload{
	for (@tune_list){
		say "-" x 60;
		say "Uploading $_";
		say "-" x 60;
		#  charts is predefined in rclone as a folder in gdrive
		system("rclone copy -P $basepath/combined/$_ charts:");
	}
}

