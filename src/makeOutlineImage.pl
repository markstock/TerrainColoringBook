#!/usr/bin/perl
#
# makeOutlineImage.pl - generate a coloring book page from a DEM
#

my $inWide = 8.0;
my $inHigh = 10.5;

my $nargs = @ARGV;
if ($nargs < 1) {
  print "Need a source file on the command-line:\n";
  print "    makeOutlineImage.pl img.png\n";
  exit();
}

my $infile = $ARGV[0];
print "Working on ${infile}\n";
my $outfile = $ARGV[1];
print "Writing to ${outfile}\n";

# get the pixel size of the image

#my @tokens = split('.',$infile);
#my $outfile = "temp17.png";
#my $outfile = "temp17.png";

my $command = "cat ${infile}";

# convert to greyscale pnm
$command .= " | pngtopam | ppmtopgm";

# do a posterize operation
$command .= " | pnmquant 3";

# find edges and convert
$command .= " | pamedge | pnminvert | pnmnorm -bpercent 30 | pnmdepth 255";

# rotate and crop (this needs to be more adaptive)
$command .= " | pamflip -ccw | pamcut -width 2160 -height 2835";

# write out
$command .= " | pnmtopng > ${outfile}";

print "${command}\n";
system $command;

# how large is the file?
my $size = -s $outfile;
print "Output file is $size bytes\n";

