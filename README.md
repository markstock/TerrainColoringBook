# TerrainColoringBook
Scripts and output for coloring book pages based on digital elevation data

### Introduction
Adult coloring books are all the rage. Most are hand-drawn, and subjects are wide-ranging.
I happen to love maps and landscape data, so I created an automated method to convert
digital elevation models (or any greyscale image, for that matter) into a color-able 
coloring book image.

### Usage
Before using the included Perl script, you'll need to make sure that the NetPBM and 
TurboJPEG packages are installed and in the user's path. You can do this on an RPM system
with:

    sudo yum install libjpeg-turbo-utils netpbm-progs

The script operates on whole directories. Every image in the `indir` (below) will be converted
and an output image file and thumbnail will be created in the `outdir` (which will be created
if it does not already exist). Run the script like so:

    makeOutlineImage.pl indir outdir

