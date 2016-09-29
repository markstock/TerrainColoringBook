#!/usr/bin/perl
#
# makeOutlineImage.pl - generate a coloring book page from a DEM
#
# (c) 2016 Mark J. Stock
#

# final page size
my $inWide = 8.0;
my $inHigh = 10.5;
my $desiredAR = $inWide / $inHigh;

# thumbnail size, in vertical dimension, and border size
my $ythumb = 220;
my $bthumb = 10;

my $nargs = @ARGV;
if ($nargs < 2) {
  print "Need source and destination directories on the command-line:\n";
  print "    makeOutlineImage.pl in_dir out_dir\n";
  exit();
}

my $indir = $ARGV[0];
print "Working on ${indir}\n";

# does input directory exist?
if (! -d ${indir}) {
  print "Input directory does not exist, quitting.\n";
  exit(1);
}

my $outdir = $ARGV[1];
print "Writing to ${outdir}\n";

# does output directory exist?
if (! -d ${outdir}) {
  print "Output directory does not exist, creating it.\n";
  mkdir $outdir;
}

my $command = "";
# make a series of smoothing kernels
for (my $r=1; $r<25; $r++) {
  my $res = 2 * $r + 1;
  my $sig = $r / 1.5;
  $command = "pamgauss $res $res -sigma $sig -tupletype=GRAYSCALE -maxval=65535 | pamtopnm > ${outdir}/.gauss${r}.pgm";
  system $command;
}

# write the html file new every time
my $htmlfile = "${outdir}/index.html";
open(HTML,">${htmlfile}") or die "Can't open ${htmlfile}: $!";

# get all the images
@infiles = glob("${indir}/*.png");

# seed random number generator
srand(scalar @infiles);

# for each image in the input...
foreach my $infile (@infiles) {
  print "Working on ${infile}\n";

  # assemble the output file name

  my @tokens = split('/',$infile);
  my $rootname = $tokens[1];
  $rootname =~ s/.png//;
  my $outfile = "${outdir}/$tokens[1]";
  print "Creating ${outfile}\n";

  # does outfile exist?
  if (! -f "$outfile") {

    # get the pixel size of the image
    my @res = &findres($infile);
    print "res is @res \n";
    my $xres = $res[0];
    my $yres = $res[1];
    my $maxres = $res[2];
    if ($maxres == -1) { }
    my $fileAR = (1.0 * $xres) / $yres;

    # first, blur and crop the input image
    my $command = "cat ${infile}";
    $command .= " | pngtopam | ppmtopgm";
    # randomized smoothing
    my $smo = int(6 + rand(16));
    $command .= " | pnmconvol -nooffset ${outdir}/.gauss${smo}.pgm";
    my $buf = 25;
    my $newx = $xres - 2*$buf;
    my $newy = $yres - 2*$buf;
    $xres = $newx;
    $yres = $newy;
    my $fileAR = (1.0 * $xres) / $yres;
    $command .= " | pamcut -width $xres -height $yres -left $buf -top $buf";
    $command .= " > ${outdir}/.temp.pgm";
    print "${command}\n"; system $command;

    # what should be our minimum file size to maintain complexity
    # anything from 0.1 to 0.3 is reasonable
    #my $minBpp = 0.2;
    # smoother images need less information content
    my $minBpp = 0.12 + 0.16*rand() - 0.01*($smo-14);

    # try multiple times to match a specific file size
    my $levels = 3;
    my $keepgoing = 1;
    my $lastsize = 0;
    while ($keepgoing) {

      # assemble the command
      #my $command = "cat ${infile}";
      my $command = "cat ${outdir}/.temp.pgm";

      # convert to greyscale pnm
      #$command .= " | pngtopam | ppmtopgm";

      # blur the input image
      #$command .= " | pnmconvol -nooffset ${outdir}/.gauss7.pgm";

      # do a posterize operation
      $command .= " | pnmquant $levels";

      # blur here?
      $command .= " | pnmconvol -nooffset ${outdir}/.gauss1.pgm";

      # find edges and convert
      $command .= " | pamedge | pnminvert | pnmnorm -bpercent 5";
      #$command .= " | pamedge | pnminvert";

      # to 8-bit
      $command .= " | pnmdepth 255";

      # rotate
      if ($xres > $yres) {
        $command .= " | pamflip -ccw";
      }

      # crop (this needs to be more adaptive)
      if ($xres > $yres) {
        my $desiredx = int($desiredAR * $xres);
        if ($desiredx > $yres) {
          my $desiredy = int($yres / $desiredAR);
          # crop in y
          $command .= " | pamcut -width $yres -height $desiredy";
        } else {
          # crop in x
          $command .= " | pamcut -width $desiredx -height $xres";
        }

      } else {
        my $desiredx = int($desiredAR * $yres);
        if ($desiredx > $xres) {
          my $desiredy = int($xres / $desiredAR);
          # crop in y
          $command .= " | pamcut -width $xres -height $desiredy";
        } else {
          # crop in x
          $command .= " | pamcut -width $desiredx -height $yres";
        }
      }

      # write out
      $command .= " | pnmtopng > ${outfile}";

      print "${command}\n";
      system $command;

      # how large is the file?
      my $size = &CalcFileComplexity($outfile);
      print "  $levels levels gives $size bytes per pixel\n\n";
      #my $size = -s $outfile;
      #print "  $levels levels gives file size of $size bytes\n\n";

      # is this big enough?
      if ($size > $minBpp) {
        $keepgoing = 0;
      }

      # did we try enough?
      if ($levels > 50) {
        $keepgoing = 0;
      }

      # did file size *decrease*?
      if ($size < $lastsize - 100) {
        $keepgoing = 0;
      }
      $lastsize = $size;

      $levels += 1;
    }
  }

  # make a PDF?
  my $pdfname = $outfile;
  $pdfname =~ s/png/pdf/;
  if (! -f "${pdfname}") {
  }


  # thumbnail image file name
  my $thumbname = $outfile;
  $thumbname =~ s/\//\/thumb_/;
  $thumbname =~ s/png/jpg/;

  # does thumbnail exist?
  if (! -f "${thumbname}") {
    print "Making thumbnail ${thumbname}\n";

    my $command = "cat ${outfile}";
    $command .= " | pngtopam | ppmtopgm";
    $command .= " | pamscale -ysize ${ythumb}";
    $command .= " | pnmmargin -white ${bthumb}";
    $command .= " | ppmtopgm";
    #$command .= " | pnmnorm -bpercent 1";
    $command .= " | pnmnorm -bvalue 180";
    $command .= " | cjpeg -q 90 > ${thumbname}";
    print "${command}\n";
    system $command;
  }


  # write the html file new every time
  print HTML "<a href=\"${rootname}.png\"><img src=\"thumb_${rootname}.jpg\"></a>\n";

  #exit(0);
}

# close the html
close(HTML);

# clean up temporaries
unlink glob("${outdir}/.*pgm");

exit;

# ===================================================

sub findres {

  my $xsize = 0;
  my $ysize = 0;
  my $maxsize = -1;

  if (-f "$_[0]") {
    $temp = `pngtopam $_[0] | pamfile`;
    @tokens = split(' ',$temp);
    $xsize = $tokens[3];
    $ysize = $tokens[5];
    print "  image size is ${xsize} ${ysize} pixels\n";
    if ($xsize > $ysize) {
      $maxsize = $xsize;
    } else {
      $maxsize = $ysize;
    }
  }

  return ($xsize, $ysize, $maxsize);
}

sub CalcFileComplexity {
  my $infile = $_[0];

  # first, find actual image resolution
  my ($xs, $ys, $dummy) = &findres($infile);

  # find jpeg file size
  my $tmpjpg = $infile;
  $tmpjpg =~ s/png/jpg/;
  my $command = "pngtopam $infile | ppmtopgm | cjpeg -q 90 > $tmpjpg";
  print "  $command\n"; system $command;

  # calculate file size
  my $size = -s $tmpjpg;
  unlink $tmpjpg;
  print "  size is $xs * $ys / $size\n";

  # and complexity
  my $bpp = $size / (($xs+1.0)*($ys+1.0));

  return ($bpp);
}

