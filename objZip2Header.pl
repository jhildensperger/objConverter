#! /usr/bin/perl
=head1 NAME

 obj2opengl - converts obj files to arrays for glDrawArrays
 
=head1 SYNOPSIS

 obj2opengl [options] file

 use -help or -man for further information

=head1 DESCRIPTION

This script expects and OBJ file consisting of vertices,
texture coords and normals. Each face must contain
exactly 3 vertices. The texture coords are two dimonsional.

The resulting .H file offers three float arrays to be rendered
with glDrawArrays.

=head1 AUTHOR

Heiko Behrens (http://www.HeikoBehrens.net)

=head1 VERSION

25th August 2009 (initial version)

=head1 COPYRIGHT

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 ACKNOWLEDGEMENTS

This script is based on the work of Margaret Geroch.

=head1 REQUIRED ARGUMENTS

The first or the last argument has to be an OBJ file according 
to this () specification.

=head1 OPTIONS

=over

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the extended manual page and exits.

=item B<-noScale>    

Prevents automatic scaling. Otherwise the object will be scaled
such the the longest dimension is 1 unit.

=item B<-scale <float>>

Sets the scale factor explicitly. Please be aware that negative numbers
are not handled correctly regarding the orientation of the normals.

=item B<-noMove>

Prevents automatic scaling. Otherwise the object will be moved to the center of
its vertices.

=item B<-o>, B<-outputFilename>

Name of the output file name. If omitted, the output file the same as the
input filename but with the extension .h

=item B<-nameOfObject>

Specifies the name of the generated variables. If omitted, same as 
output filename without path and extension.

=item B<-noverbose>

Runs this script silently.
   
=cut

use Getopt::Long;
use File::Basename;
use File::Path;
use Pod::Usage;
use Archive::Zip;

# -----------------------------------------------------------------
# Main Program
# -----------------------------------------------------------------
unZipFiles();

my $objDir = dirname(dirname($0)) . "/Object Files/";
opendir(DIR, $objDir);

startOutput();

while (my $objFile = readdir(DIR)) 
{	
	unless($objFile eq "." || $objFile eq ".." || $objFile eq "__MACOSX")
	{
		handleArguments("$objFile");

		loadData();

		printStatistics();
		writeObjData();
	}
}

#end writing to file
endOutput();

#delete the .obj files
$files_deleted = rmtree($objDir);
print "Process Complete! \n";
closedir(DIR);


# -----------------------------------------------------------------
# Sub Routines
# -----------------------------------------------------------------

sub handleArguments() 
{
	my $help = 0;
	my $man = 0;
	my $noscale = 1;
	my $nomove = 0;
	$errorInOptions = !GetOptions (
		"help" => \$help,
		"man"  => \$man,
		"noScale" => \$noscale,
		"scale=f" => \$scalefac,
		"noMove" => \$nomove,
		"center=f{3}" => \@center,
		"headerFilename=s" => \$headerFilename,
		"nameOfObject=s" => \$object,
		);
	
	if($noscale) 
	{
		$scalefac = 50;
	}
	
	if($nomove) 
	{
		@center = (0, 0, 0);
	}
	
	if(defined(@center)) 
	{
		$xcen = $center[0];
		$ycen = $center[1];
		$zcen = $center[2];
	}

	#$_[0] is the variable passed to handleArguments
	$objFilename = $objDir . $_[0];

	my ($file, $dir, $ext) = fileparse($objFilename, qr{\..*});
	$object = $file;
	
	if($errorInOptions || $man || $help)
	{
		pod2usage(-verbose => 2) if $man;
		pod2usage(-verbose => 1) if $help;
		pod2usage(); 
	}
	
	# check wheter file exists
	open ( INFILE, "<$objFilename" ) || die "Can't find file '$objFilename' ...exiting \n";
	
	close(INFILE);
}

sub unZipFiles()
{
	if($#ARGV == 0) 
	{
		my ($zipFile, $zipDir, $zipExt) = fileparse($ARGV[0], qr/\.[^.]*/);
		$zipFileName = $zipDir . $zipFile . $zipExt;
	}
	# extract a zip file
	print "Extracting $zipFileName to Object Files/\n";
	$zip = Archive::Zip->new();
	die 'Error reading zip file.' if $zip->read( $zipFileName) != AZ_OK;

	my @members = $zip->memberNames();
	die "Read of $zipName failed\n" if $status != AZ_OK;
	
	foreach (@members) 
	{
	    $zip->extractMember("$_", "Object Files/$_");
	}
	print "Extraction Complete!\n";
}

# Stores center of object in $xcen, $ycen, $zcen
# and calculates scaling factor $scalefac to limit max
#   side of object to 1.0 units
sub calcSizeAndCenter() 
{
	open ( INFILE, "<$objFilename" ) || die "Can't find .obj file $objFilename...exiting \n";

	$numVertices = 0;
	
	my (
		$xsum, $ysum, $zsum, 
		$xmin, $ymin, $zmin,
		$xmax, $ymax, $zmax,
		);

	while ( $line = <INFILE> ) 
	{
	  chop $line;
	  
	  if ($line =~ /v\s+.*/)
	  {
	  
	    $numVertices++;
	    @tokens = split(' ', $line);
	    
	    $xsum += $tokens[1];
	    $ysum += $tokens[2];
	    $zsum += $tokens[3];
	    
	    if ( $numVertices == 1 )
	    {
	      $xmin = $tokens[1];
	      $xmax = $tokens[1];
	      $ymin = $tokens[2];
	      $ymax = $tokens[2];
	      $zmin = $tokens[3];
	      $zmax = $tokens[3];
	    }
	    else
	    {   
	        if ($tokens[1] < $xmin)
	      {
	        $xmin = $tokens[1];
	      }
	      elsif ($tokens[1] > $xmax)
	      {
	        $xmax = $tokens[1];
	      }
	    
	      if ($tokens[2] < $ymin) 
	      {
	        $ymin = $tokens[2];
	      }
	      elsif ($tokens[2] > $ymax) 
	      {
	        $ymax = $tokens[2];
	      }
	    
	      if ($tokens[3] < $zmin) 
	      {
	        $zmin = $tokens[3];
	      }
	      elsif ($tokens[3] > $zmax) 
	      {
	        $zmax = $tokens[3];
	      }
	    
	    }
	 
	  }
	 
	}
	close INFILE;
	
	#  Calculate the center
	#unless(defined($xcen)) {
		$xcen = $xsum / $numVertices;
		$ycen = $ysum / $numVertices;
		$zcen = $zsum / $numVertices;
	#}
	
	#  Calculate the scale factor
	unless(defined($scalefac)) {
		my $xdiff = ($xmax - $xmin);
		my $ydiff = ($ymax - $ymin);
		my $zdiff = ($zmax - $zmin);
		
		if ( ( $xdiff >= $ydiff ) && ( $xdiff >= $zdiff ) ) 
		{
		  $scalefac = $xdiff;
		}
		elsif ( ( $ydiff >= $xdiff ) && ( $ydiff >= $zdiff ) ) 
		{
		  $scalefac = $ydiff;
		}
		else 
		{
		  $scalefac = $zdiff;
		}
		$scalefac = 1.0 / $scalefac;
	}
}

sub printStatistics() 
{
	print "----------------\n";
	print "Input file     : $objFilename\n";
	print "Output file    : $headerFilename\n";
	print "Object name    : $object\n";
	#print "Center         : <$xcen, $ycen, $zcen>\n";
	print "Scale by       : $scalefac\n";
	print "Vertices       : $numVertices\n";
	print "Indices        : $numIndices\n";
	print "Texture Coords : $numTexture\n";
	print "Normals        : $numNormals\n";
	print "----------------\n";
}

# reads vertices into $xcoords[], $ycoords[], $zcoords[]
#   where coordinates are moved and scaled according to
#   $xcen, $ycen, $zcen and $scalefac
# reads texture coords into $tx[], $ty[] 
#   where y coordinate is mirrowed
# reads normals into $nx[], $ny[], $nz[]
#   but does not normalize, see normalizeNormals()
# reads faces and establishes lookup data where
#   va_idx[], vb_idx[], vc_idx[] for vertices
#   ta_idx[], tb_idx[], tc_idx[] for texture coords
#   na_idx[], nb_idx[], nc_idx[] for normals
#   store indizes for the former arrays respectively
#   also, $face_line[] store actual face string
sub loadData()
{
	$numVertices = 0;
	$numFaces = 0;
	$numIndices = 0;
	$numTexture = 0;
	$numNormals = 0;
	
	open ( INFILE, "<$objFilename" ) || die "Can't find .obj file: $objFilename...exiting \n";
	
	while ($line = <INFILE>) 
	{
		chop $line;
	  
		#vertices
	  	if ($line =~ /v\s+.*/)
	  	{
			@tokens= split(' ', $line);
			
			if (abs($tokens[1]) < .01)
			{ 
				$x = "0.00000";
			}
			else
			{
				$x = $tokens[1] * $scalefac;
			}
			
			if (abs($tokens[2]) < .01)
			{
				$y = "0.00000";
			}
			else
			{
				if ($scalefac == 1)
				{
					$y = $tokens[2];
				}
				else
				{
					$y = -1 * $tokens[2] * $scalefac;
				}
			}
			
			if (abs($tokens[3]) < .01)
			{
				$z = "0.00000";
	    	}
	    	else
	    	{
	    		$z = $tokens[3] * $scalefac;   
	    	}
	    	
	    	$xcoords[$numVertices] = $x; 
	    	$ycoords[$numVertices] = $y;
	    	$zcoords[$numVertices] = $z;
	
	    	$numVertices++;
	  	}
	  
	  	# texture coords
	  	if ($line =~ /vt\s+.*/)
	  	{
	    	@tokens= split(' ', $line);
	    	$x = $tokens[1];
	    	$y = 1 - $tokens[2];
	    	$tx[$numTexture] = $x;
	    	$ty[$numTexture] = $y;
	    
	    	$numTexture++;
	  	}
	  
	  	#normals
	  	if ($line =~ /vn\s+.*/)
	  	{
	    	@tokens= split(' ', $line);
	    	$x = $tokens[1];
	    	$y = $tokens[2];
	    	$z = $tokens[3];
	    	$nx[$numNormals] = $x; 
	    	$ny[$numNormals] = $y;
	    	$nz[$numNormals] = $z;
	
	    	$numNormals++;
	  	}
	  
	  	# faces
		if ($line =~ /f\s+.*/) 
		{
			@tokens= split(' ', $line);
	  	
	    	$a = $tokens[1];
	    	$b = $tokens[2];
	    	$c = $tokens[3];
	    
	  		$va_idx[$numFaces] = $a-1;
	  		$vb_idx[$numFaces] = $b-1;
	  		$vc_idx[$numFaces] = $c-1;
			$numFaces++;
		}  
		
		$numIndices = 3*$numFaces
	}
	
	close INFILE;
}

sub normalizeNormals()
{
	for ( $j = 0; $j < $numNormals; ++$j) 
	{
		$d = sqrt ( $nx[$j]*$nx[$j] + $ny[$j]*$ny[$j] + $nz[$j]*$nz[$j] );
	  
	  	if ( $d == 0 )
	  	{
	    	$nx[$j] = 1;
	    	$ny[$j] = 0;
	    	$nz[$j] = 0;
		}
		
		else
		{
	    	$nx[$j] = $nx[$j] / $d;
	    	$ny[$j] = $ny[$j] / $d;
	    	$nz[$j] = $nz[$j] / $d;
		}
	    
	}
}

sub startOutput()
{
	my ($file, $dir, $ext) = fileparse($ARGV[0], qr/\.[^.]*/);
	$headerFilename = $dir . $file . ".h";

	open ( OUTFILE, ">$headerFilename" ) || die "Can't create file header: $headerFilename -> exiting\n";

	print OUTFILE "// created from $file.zip with objZip2Header.pl\n\n";
	
	print OUTFILE "typedef struct {\n";
    print OUTFILE "	GLfloat x;\n";
    print OUTFILE "	GLfloat y;\n";
    print OUTFILE "	GLfloat z;\n";
    print OUTFILE "}Point3D;\n\n";

    print OUTFILE "static inline Point3D Point3DMake(CGFloat with_x, CGFloat with_y, CGFloat with_z)\n";
    print OUTFILE "{\n";
    print OUTFILE "	Point3D ret;\n";
    print OUTFILE "	ret.x = with_x;\n";
    print OUTFILE "	ret.y = with_y;\n";
    print OUTFILE "	ret.z = with_z; \n";   
    print OUTFILE "	return ret;\n";
    print OUTFILE "}\n\n";

    print OUTFILE "typedef struct {\n";
    print OUTFILE "	GLfloat r;\n";
    print OUTFILE "	GLfloat g;\n";
    print OUTFILE "	GLfloat b;\n";
    print OUTFILE "	GLfloat a;\n";
    print OUTFILE "}RGBAColor;\n\n";

    print OUTFILE "static inline RGBAColor RGBAColorMake(CGFloat with_red, CGFloat with_blue, CGFloat with_green, GLfloat with_alpha)\n";
    print OUTFILE "{\n";
    print OUTFILE "	RGBAColor ret;\n";
    print OUTFILE "	ret.r = with_red;\n";
    print OUTFILE "	ret.g = with_green;\n";
    print OUTFILE "	ret.b = with_blue;\n";
    print OUTFILE "	ret.a = with_alpha;\n";
    print OUTFILE "	return ret;\n";
    print OUTFILE "}\n\n";

    print OUTFILE "typedef struct { \n";
	print OUTFILE "	Point3D position; \n";
	print OUTFILE "	RGBAColor color;\n"; 
    print OUTFILE "}Vertex;\n\n";

    print OUTFILE "static inline Vertex VertexMake(CGFloat with_x, CGFloat with_y, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)\n";
    print OUTFILE "{\n";
    print OUTFILE "	Vertex ret;\n";
    print OUTFILE "	ret.position.x = with_x;\n";
    print OUTFILE "	ret.position.y = with_y;\n";
    print OUTFILE "	ret.position.z = 0.0f;\n";
    print OUTFILE "	ret.color.r = red;\n";
    print OUTFILE "	ret.color.g = green;\n";
    print OUTFILE "	ret.color.b = blue;\n";
    print OUTFILE "	ret.color.a = alpha;\n";
    print OUTFILE "	return ret;\n";
    print OUTFILE "}\n\n";

    print OUTFILE "typedef enum _ClefType {\n";
    print OUTFILE "	TREBLECLEF,\n";
    print OUTFILE "	BASSCLEF\n";
    print OUTFILE "} ClefType;\n\n";
}
	
sub writeObjData()
{	
	# needed static constant for glDrawArrays
	print OUTFILE "#pragma mark - $object\n\n";
	print OUTFILE "static const GLuint ".$object."NumVertices = ".($numVertices ).";\n\n";
	print OUTFILE "static const GLuint ".$object."NumIndices = ".($numIndices ).";\n\n";
	# write center
	#print OUTFILE "GLfloat ".$object."Center[] = {\n";
	#print OUTFILE "		$xcen, $ycen, $zcen\n";
	#print OUTFILE "};\n\n";
	
	# write verts
	print OUTFILE "#pragma mark Vertices\n\n";
	print OUTFILE "static const Vertex ".$object."Vertices[] = {\n"; 
	#print OUTFILE "static const Vertex Vertices[] = {\n";
	for( $j = 0; $j < $numVertices; $j++)
	{
		print OUTFILE "	{{$xcoords[$j], $ycoords[$j], $zcoords[$j]}, {0,0,0,1}},\n";
	}
	print OUTFILE "};\n\n";
	
	# write indices
	print OUTFILE "#pragma mark Indices\n\n";
	print OUTFILE "static const GLuint ".$object."Indices[] = {\n"; 
	#print OUTFILE "static const GLuint Indices[] = {\n";
	for( $j = 0; $j < $numFaces; $j++)
	{	
		if($va_idx[$j] != -1 && $va_idx[$j] != -1 && $vc_idx[$j] != -1) 
		{
			print OUTFILE "	$va_idx[$j], $vb_idx[$j], $vc_idx[$j],\n";
		}
		else
		{
			if($vb_idx[$j] == -1 && $vc_idx[$j] == -1) 
			{
				print OUTFILE "	$va_idx[$j],\n";
			}
			else #if ($vc_idx[$j] == -1)
			{
				print OUTFILE "	$va_idx[$j], $vb_idx[$j], \n";
			}
		}
	}
	print OUTFILE "};\n\n";
	
	#not currently set up for normals or textures
	
	# write normals
	print OUTFILE "#pragma mark Normals\n\n";
	print OUTFILE "static const GLfloat ".$object."Normals[] = {\n"; 
	for( $j = 0; $j < $numVertices; $j++)
	{
		print OUTFILE "	$xcoords[$j], $ycoords[$j], $zcoords[$j],\n";
	}
	print OUTFILE "};\n\n";
	
	#if($numNormals > 0) 
	#{
	#	print OUTFILE "float ".$object."Normals \[\] = {\n"; 
	#	for( $j = 0; $j < $numFaces; $j++) 
	#	{
	#		$ia = $na_idx[$j];
	#		$ib = $nb_idx[$j];
	#		$ic = $nc_idx[$j];
	#		#print OUTFILE "  // $face_line[$j]\n";
	#		print OUTFILE "  $nx[$ia], $ny[$ia], $nz[$ia],\n";
	#		print OUTFILE "  $nx[$ib], $ny[$ib], $nz[$ib],\n";
	#		print OUTFILE "  $nx[$ic], $ny[$ic], $nz[$ic],\n";
	#	}
	#	
	#	print OUTFILE "};\n\n";
	#}
	
	# write texture coords
	#if($numTexture) 
	#{
	#	print OUTFILE "float ".$object."TexCoords \[\] = {\n"; 
	#	for( $j = 0; $j < $numFaces; $j++) 
	#	{
	#		$ia = $ta_idx[$j];
	#		$ib = $tb_idx[$j];
	#		$ic = $tc_idx[$j];
	#		#print OUTFILE "  // $face_line[$j]\n";
	#		print OUTFILE "  $tx[$ia], $ty[$ia],\n";
	#		print OUTFILE "  $tx[$ib], $ty[$ib],\n";
	#		print OUTFILE "  $tx[$ic], $ty[$ic],\n";
	#	}
	#	
	#	print OUTFILE "};\n\n";
	#}
	
	
}

sub endOutput()
{
	#print OUTFILE "}\n";
	close OUTFILE;
}
