#!/usr/bin/env perl

# 2017-9 Bruno Contreras-Moreira (1) and Pablo Vinuesa (2):
# 1: http://www.eead.csic.es/compbio (Estacion Experimental Aula Dei/CSIC/Fundacion ARAID, Spain)
# 2: http://www.ccg.unam.mx/~vinuesa (Center for Genomic Sciences, UNAM, Mexico)

# This script can be used to get user-defined subsets of pangenome matrices generated by compare_clusters.pl

# Takes 2 lists (A & B) with taxon names (as those used by get_homologues and compare_clusters)
# in order to analyze clusters present/absent in one with respect to the other.
# Can also be used to plot shell genome distribution (PDF and PNG, requires R http://www.r-project.org)

# Please edit %RGBCOLORS variable below if you wish to change the default colors of pangenome compartments

$|=1;

use strict;
use warnings;
use Getopt::Std;
use File::Basename;
use FindBin '$Bin';
use lib "$Bin/lib";
use lib "$Bin/lib/bioperl-1.5.2_102/";
use phyTools;
use marfil_homology;
use Bio::Graphics;
use Bio::SeqFeature::Generic;

my $CUTOFF = 100; # percentage of genomes to be used as cutoff for presence/absence

# globals used while producing R plots
my $VERBOSE   = 0;    # set to 1 to see R messages
my $YLIMRATIO = 1.2;  # controls the length of (rounded) Y-axis marks with respect to max value in barplots

my %COLORS = ('cloud'=>'"red"','shell'=>'"orange"','soft_core'=>'"yellow"','core'=>'"white"'); # default plot colors

# optional RGB colors in 0-255 range 
# guide to prepare friendly figures for colorblind people [http://jfly.iam.u-tokyo.ac.jp/color/index.html]
# uncomment and edit colors below to use RGB colors
my %RGBCOLORS = ( 
#  'cloud'    =>'rgb(0,0,0,maxColorValue=255)',
#  'shell'    =>'rgb(230,159,0,maxColorValue=255)',
#  'soft_core'=>'rgb(86,180,233,maxColorValue=255)',
#  'core'     =>'rgb(0,158,115,maxColorValue=255)'
);


# globals used only with -p flag
my $DEFAULTGBKFEATURES = 'CDS,tRNA,rRNA'; # defines GenBank features to be parsed 
my $MAKESVGGRAPH       = 0; # default PNG, SVG is vectorial but requires module GD::SVG
my $PLOT_FULL_LABELS   = 0; # if 0 shows cluster numbers, otherwise adds gene names to numbers
my $PLOTWIDTH          = 1024; 

my @FEATURES2CHECK = ('EXE_R');
check_installed_features(@FEATURES2CHECK);

my ($INP_matrix,$INP_absent,$INP_expansions,$INP_includeA,$INP_includeB,%opts) = ('',0,0,'','');
my ($INP_refgenome,$INP_list_taxa,$INP_plotshell,$INP_cutoff,$needAB,$Rparams) = ('',0,0,$CUTOFF,0,'');
my ($INP_absentB,$INP_skip_singletons,$INP_shared_matrix,$INP_taxa_file,$needB) = (0,0,0,'');

getopts('hagselxp:m:I:A:B:P:S:', \%opts);

if(($opts{'h'})||(scalar(keys(%opts))==0))
{
  print   "\n[options]: \n";
  print   "-h \t this message\n";
  print   "-m \t input pangenome matrix .tab                               (required, made by compare_clusters.pl)\n"; #, ideally with -t 0)\n";
  print   "-s \t report cloud,shell,soft core and core clusters            (optional, creates plot if R is installed)\n";
  print   "-l \t list taxa names present in clusters reported in -m matrix (optional, recommended before using -p option)\n";
  print   "-x \t produce matrix of intersection pangenome clusters         (optional, requires -s)\n";
  print   "-I \t use only taxon names included in file                     (optional, ignores -A,-g,-e)\n";
  print   "-A \t file with taxon names (.faa,.gbk,.nucl files) of group A  (optional, example -A clade_list_pathogenic.txt)\n";
  print   "-B \t file with taxon names (.faa,.gbk,.nucl files) of group B  (optional, example -B clade_list_symbiotic.txt)\n";
  print   "-a \t find genes/clusters which are absent in B                 (optional, requires -B)\n";
  print   "-g \t find genes/clusters present in A which are absent in B    (optional, requires -A & -B)\n";
  print   "-e \t find gene family expansions in A with respect to B        (optional, requires -A & -B)\n";
  print   "-S \t skip clusters with occupancy <S                           (optional, requires -x/-a/-g, example -S 2)\n";
  print   "-P \t percentage of genomes that must comply presence/absence   (optional, default=$CUTOFF, requires -g)\n";
  if(eval{ require GD } ) # show only if GD is available
  {
    print   "-p \t plot pangenes on the genome map of this group A taxon     ".
      "(optional, example -p 'Escherichia coli K12',\n".
      "   \t                                                         ".
      "   requires -g, -A & -B, only works with clusters\n".
      "   \t                                                         ".
      "   derived from input files in GenBank format)\n";
  }
  exit(-1);
}

if(defined($opts{'m'})){ 
  $INP_matrix = $opts{'m'};
  if($INP_matrix =~ /.tr.tab/){
    die "\n# $0 : cannot use a transposed -m matrix, exit\n";
  }
}
else{ die "\n# $0 : need -m parameter, exit\n"; }

if(defined($opts{'l'})){ $INP_list_taxa = 1 }

if(defined($opts{'s'}))
{
	$INP_plotshell = 1;
	
	if(defined($opts{'x'}))
	{
		$INP_shared_matrix = 1;

		if($opts{'S'} && $opts{'S'} > 0)
		{
			$INP_skip_singletons = $opts{'S'};
		}
	}
}

if(defined($opts{'I'}))
{ 
  $INP_taxa_file = $opts{'I'};

  if(defined($opts{'a'}))
  {
    $INP_absentB = 1;
    $needB = 1;
  }

  if(defined($opts{'B'}))
  {
    $INP_includeB = $opts{'B'};
  }
  elsif($needB){ die "\n# $0 : need -B parameter, exit\n"; }

  if($INP_absentB && $opts{'S'} && $opts{'S'} > 0)
  {
    $INP_skip_singletons = $opts{'S'};
  }
}
else
{
  if(defined($opts{'a'}))
  {
    $INP_absentB = 1;
    $needB = 1;
  }
  elsif(defined($opts{'g'}))
  {
    $INP_absent = 1;
    $needAB = 1;

    if(defined($opts{'P'}) && $opts{'P'} > 0 && $opts{'P'} <= 100)
    {
      $CUTOFF = $opts{'P'};
      $INP_cutoff = $CUTOFF;
    }
  }
  elsif(defined($opts{'e'}))
  {
    $INP_expansions = 1;
    $needAB = 1;
  }

  if(defined($opts{'p'}))
  {
    $INP_refgenome = $opts{'p'};
    $needAB = 1;
  }

  if(defined($opts{'A'}))
  {
    $INP_includeA = $opts{'A'};
  }
  elsif($needAB){ die "\n# $0 : need -A parameter, exit\n"; }

  if(defined($opts{'B'}))
  {
    $INP_includeB = $opts{'B'};
  }
  elsif($needAB || $needB){ die "\n# $0 : need -B parameter, exit\n"; }

  if(($INP_absentB ||$INP_absent) && $opts{'S'} && $opts{'S'} > 0)
  {
    $INP_skip_singletons = $opts{'S'};
  }
}

printf("\n# %s -m %s -I %s -A %s -B %s -a %d -g %d -e %d -p %s -s %d -l %d -x %d -P %d -S %d\n\n",
	$0,$INP_matrix,$INP_taxa_file,$INP_includeA,$INP_includeB,$INP_absentB,$INP_absent,
	$INP_expansions,$INP_refgenome,$INP_plotshell,$INP_list_taxa,$INP_shared_matrix,
	$INP_cutoff,$INP_skip_singletons);

if(!$needB && !$needAB && !$INP_plotshell && !$INP_list_taxa)
{
  die "# $0: error, need either -s or -l option\n";
}

$CUTOFF /= 100; # use 0-1 float from now on

#################################### MAIN PROGRAM  ################################################

my (%cluster_names,%pangemat,%included_taxa,$col,$cluster_dir);
my (%included_input_filesA,%included_input_filesB);
my ($n_of_clusters,$n_of_includedA,$n_of_includedB) = (0,0,0);
my ($outfile_root,$outpanfileA,$outexpanfileA,$taxon);
my ($shell_input,$shell_output_png,$shell_output_pdf,$shell_circle_png,$shell_circle_pdf,$shell_estimates);
my ($cloudlistfile,$shelllistfile,$softcorelistfile,$corelistfile,$intersection_file);
my (@pansetA,@pansetB,@expA,@expB,@shell);

$outfile_root = $INP_refgenome; $outfile_root =~ s/\W+//g;
$outfile_root = (split(/\.tab/,$INP_matrix))[0] . '_' . $outfile_root;
if($INP_taxa_file)
{
  $outfile_root .= '_'.basename($INP_taxa_file);
}
$shell_input      = $outfile_root . '_shell_input.txt';
$shell_estimates  = $outfile_root . '_shell_estimates.tab';
$shell_output_png = $outfile_root . '_shell.png';
$shell_output_pdf = $outfile_root . '_shell.pdf';
$shell_circle_png = $outfile_root . '_shell_circle.png';
$shell_circle_pdf = $outfile_root . '_shell_circle.pdf';
$cloudlistfile    = $outfile_root . '_cloud_list.txt';
$shelllistfile    = $outfile_root . '_shell_list.txt';
$softcorelistfile = $outfile_root . '_softcore_list.txt';
$corelistfile     = $outfile_root . '_core_list.txt';
$outpanfileA      = $outfile_root . '_pangenes_list.txt';
$outexpanfileA    = $outfile_root . '_expansions_list.txt';
$intersection_file= $outfile_root . '_intersection.tab';

if($INP_skip_singletons)
{
  $intersection_file= $outfile_root . "_intersection_min_occup$INP_skip_singletons.tab";
  $outpanfileA = $outfile_root . '_pangenes_min_occup'.$INP_skip_singletons.'_list.txt';
}

## 0) read include file if required
if($INP_taxa_file)
{
  open(INCLUDE_FILE,"<",$INP_taxa_file) || die "# EXIT : cannot read $INP_taxa_file\n";
  while(<INCLUDE_FILE>)
  {
    $included_taxa{(split)[0]} = 1;
  }
  close(INCLUDE_FILE); 
}

## 1) parse pangenome matrix
open(MAT,$INP_matrix) || die "# EXIT : cannot read $INP_matrix\n";
while(<MAT>)
{
  next if(/^#/ || /^$/);
  chomp;
  my @data = split(/\t/,$_);
  
  next if($data[0] =~ /^reference/ || $data[0] =~ /^redundant/); # nr matrices
  
  if($data[0] =~ /^source:(\S+)/) #source:path/to/clusters/t101964_thrB.fna/t101965_thrC.fna/t...
  {
    $cluster_dir = $1;
    if($INP_list_taxa)
    {
      # print full list of taxa names present in clusters reported in pangenome matrix
      my ($t,%cluster,%taxa,%alltaxa);
      foreach $col (1 .. $#data)
      {
        %cluster = read_FASTA_sequence( $cluster_dir.'/'.$data[$col] );
        %taxa = find_taxa_FASTA_headers(\%cluster);
        foreach $t (keys(%taxa)){ $alltaxa{$t}++; }
      }
      print "# list of taxa present in clusters (to be used with -p option):\n";
      foreach $t (sort keys(%alltaxa))
      {
        print "$t $alltaxa{$t}\n";
      }
      exit;
    }
    else
    {
      foreach $col (1 .. $#data){ $cluster_names{$col} = $data[$col] }
      $n_of_clusters = $#data;
    }
  }
  elsif($data[0] =~ /^non-redundant/) #non-redundant	24_Brdisv1ABR21043430m.faa+1	297_Brdisv1ABR21026756m.faa	
  {
    if($INP_list_taxa)
    {
      print "# EXIT: cannot list taxa present in clusters of non-redundant matrix\n";
      exit;
    }
    
    my $cl_name;
    foreach $col (1 .. $#data)
    {
      $cl_name = $data[$col];
      $cl_name = (split(/\+\d/,$cl_name))[0]; 
      $cluster_names{$col} = $cl_name;
      $n_of_clusters = $col;
    }
  }
  else 
  {
    #_Escherichia_coli_ETEC_H10407_uid42749.gbk     1       1	...
    #Bd3-1_r.1.cds.fna.nucl	1	2 ...
    
    # skip taxon if not in include file, only if requested
    next if($INP_taxa_file && !$included_taxa{$data[0]});

    foreach $col (1 .. $#data)
    {
      $pangemat{$data[0]}[$col] = $data[$col];
      $shell[$col]++ if($data[$col] > 0);
    }
  }
}
close(MAT);
print "# matrix contains $n_of_clusters clusters and ".scalar(keys(%pangemat))." taxa\n\n"; 

if($needB)
{
  ## 2.0) parse include_file B
  open(INCL,$INP_includeB) || die "# EXIT : cannot read $INP_includeB\n";
  while(<INCL>)
  {
    next if(/^#/ || /^$/);
    $taxon = (split)[0];
    $included_input_filesB{$taxon} = 1;
    if(!$pangemat{$taxon})
    {
      die "# cannot match $taxon in $INP_matrix (included in $INP_includeB)\n";
    }
  }
  close(INCL);
  $n_of_includedB = scalar(keys(%included_input_filesB));
  print "# taxa included in group B = $n_of_includedB\n\n";  
}
elsif($needAB)
{
  ## 2.1) parse include_file A
  open(INCL,$INP_includeA) || die "# EXIT : cannot read $INP_includeA\n";
  while(<INCL>)
  {
    next if(/^#/ || /^$/);
    $taxon = (split)[0];
    $included_input_filesA{$taxon} = 1;
    if(!$pangemat{$taxon})
    {
      die "# cannot match $taxon in $INP_matrix (included in $INP_includeA)\n";
    }
  }
  close(INCL);
  $n_of_includedA = scalar(keys(%included_input_filesA));
  print "# taxa included in group A = $n_of_includedA\n\n";

  ## 2.2) parse include_file B
  open(INCL,$INP_includeB) || die "# EXIT : cannot read $INP_includeB\n";
  while(<INCL>)
  {
    next if(/^#/ || /^$/);
    $taxon = (split)[0];
    $included_input_filesB{$taxon} = 1;
    if(!$pangemat{$taxon})
    {
      die "# cannot match $taxon in $INP_matrix (included in $INP_includeB)\n";
    } 
  }
  close(INCL);
  $n_of_includedB = scalar(keys(%included_input_filesB));
  print "# taxa included in group B = $n_of_includedB\n\n";
}



## 3) perform requested operations
if($INP_absentB)
{
  print "\n# finding genes which are absent in B ...\n";
  foreach $col (1 .. $n_of_clusters)
  {
    next if(!$shell[$col]);

    my ($presentA,$absentA,$absentB,$presentB) = (0,0,0,0);
    foreach $taxon (keys(%pangemat))
    {
      if($pangemat{$taxon}[$col])
      {
        if($included_input_filesB{$taxon}){ $presentB++ }
        else{ $presentA++ }
      }
      else
      {
        if($included_input_filesB{$taxon}){ $absentB++ }
        else{ $absentA++ }
      }
    }

    if($presentA > 0 && $absentB == $n_of_includedB)
    {
      # pan gene in set A
      next if($INP_skip_singletons && $presentA < $INP_skip_singletons);
      push(@pansetA,$cluster_names{$col});
    }
  }

  print "# file with genes absent in B (".scalar(@pansetA)."): $outpanfileA\n";
  open(OUTLIST,">$outpanfileA") || die "# $0 : cannot create $outpanfileA\n";
  printf OUTLIST ("# %s -m %s -A %s -B %s -g %d -e %d -p %s -P %d -S %d\n",
    $0,$INP_matrix,$INP_includeA,$INP_includeB,$INP_absent,$INP_expansions,
    $INP_refgenome,$INP_cutoff,$INP_skip_singletons);
  
  if($INP_skip_singletons)
  {
    print OUTLIST "# genes absent in B with occupancy>=$INP_skip_singletons (".scalar(@pansetA)."):\n";
  }
  else{ print OUTLIST "# genes absent in B (".scalar(@pansetA)."):\n"; }
  foreach $col (@pansetA){ print OUTLIST "$col\n" }
  close(OUTLIST);
}
elsif($INP_absent)
{
  print "\n# finding genes present in A which are absent in B ...\n";
  foreach $col (1 .. $n_of_clusters)
  {
    my ($presentA,$absentA,$absentB,$presentB) = (0,0,0,0);
    foreach $taxon (keys(%pangemat))
    {
      if($pangemat{$taxon}[$col])
      {
        if($included_input_filesA{$taxon}){ $presentA++ }
        elsif($included_input_filesB{$taxon}){ $presentB++ }
      }
      else
      {
        if($included_input_filesA{$taxon}){ $absentA++ }
        elsif($included_input_filesB{$taxon}){ $absentB++ }
      }
    }

    if($presentA >= ($n_of_includedA*$CUTOFF) && $absentB >= ($n_of_includedB*$CUTOFF))
    {
      # pan gene in set A
      #print "$cluster_names{$col} present only in ($n_of_includedA) taxa in set A\n";
      next if($INP_skip_singletons && $presentA < $INP_skip_singletons);
      push(@pansetA,$cluster_names{$col});
    }
    elsif($presentB >= ($n_of_includedB*$CUTOFF) && $absentA >= ($n_of_includedA*$CUTOFF))
    {
      # pan gene in set B
      #print "$cluster_names{$col} present only in ($n_of_includedB) taxa in set B\n";
      #push(@pansetB,$cluster_names{$col});
    }
  }

  print "# file with genes present in set A and absent in B (".scalar(@pansetA)."): $outpanfileA\n";
  open(OUTLIST,">$outpanfileA") || die "# $0 : cannot create $outpanfileA\n";  
  printf OUTLIST ("# %s -m %s -A %s -B %s -g %d -e %d -p %s -P %d -S %d\n",
    $0,$INP_matrix,$INP_includeA,$INP_includeB,$INP_absent,$INP_expansions,
    $INP_refgenome,$INP_cutoff,$INP_skip_singletons);
  
  if($INP_skip_singletons)
  {
    print OUTLIST "# genes present in set A and absent in B with occupancy>=$INP_skip_singletons (".scalar(@pansetA)."):\n";
  }
  else{ print OUTLIST "# genes present in set A and absent in B (".scalar(@pansetA)."):\n"; }
  foreach $col (@pansetA){ print OUTLIST "$col\n" }
  close(OUTLIST);

  # commented out Apr2012: user should reverse -A,-B options to get this
  # print "# genes present in set B and absent in A (".scalar(@pansetB)."):\n";
  # foreach $col (@pansetB){ print "$col\n" }
}
elsif($INP_expansions)
{
  print "\n# finding gene family expansions in group A ...\n";
  foreach $col (1 .. $n_of_clusters)
  {
    my ($presentA,$presentB,@sizeA,@sizeB) = (0,0);
    my ($minA,$maxA,$minB,$maxB);
    foreach $taxon (keys(%pangemat))
    {
      if($pangemat{$taxon}[$col])
      {
        if($included_input_filesA{$taxon})
        {
          $presentA++;
          push(@sizeA,$pangemat{$taxon}[$col]);
        }
        elsif($included_input_filesB{$taxon})
        {
          $presentB++;
          push(@sizeB,$pangemat{$taxon}[$col]);
        }
      }
    }

    if($presentA == $n_of_includedA && $presentB == $n_of_includedB)
    {
      @sizeA = sort {$a<=>$b} @sizeA;
      $minA = $sizeA[0];
      $maxA = $sizeA[$#sizeA];

      @sizeB = sort {$a<=>$b} @sizeB;
      $minB = $sizeB[0];
      $maxB = $sizeB[$#sizeB];

      # exapansions in set A: all A taxa must have sizeA > sizeB in all B taxa
      if($minA > $maxB)
      {
        #print "$cluster_names{$col} expanded in set A\n";
        push(@expA,$cluster_names{$col});
      }
      elsif($minB > $maxA)
      {
        #print "$cluster_names{$col} expanded in set B\n";
        #push(@expB,$cluster_names{$col});
      }
    }
  }

  print "# file with genes expanded in set A (".scalar(@expA)."): $outexpanfileA\n";
  open(OUTEXPANLIST,">$outexpanfileA") || die "# $0 : cannot create $outexpanfileA\n";
  printf OUTEXPANLIST ("# %s -m %s -A %s -B %s -g %d -e %d -p %s -P %d -S %d\n",
    $0,$INP_matrix,$INP_includeA,$INP_includeB,$INP_absent,$INP_expansions,
    $INP_refgenome,$INP_cutoff,$INP_skip_singletons);
    
  print OUTEXPANLIST "# genes expanded in set A (".scalar(@expA)."):\n";
  foreach $col (@expA){ print OUTEXPANLIST "$col\n" }
  close(OUTEXPANLIST);

  # commented out Apr2012: user should reverse -A,-B options to get this
  #print "# genes expanded in set B (".scalar(@expB)."):\n";
  #foreach $col (@expB){ print "$col\n" }
}

# plot genomic map
if($INP_refgenome)
{
  eval{ import GD; };
  my ($start,$end,$strand,$gi,$feat,$pancluster,$source,$included,%contig);

  print "\n# plotting pangenes in genomic context...\n";

  # read $INP_refgenome GenBank file if format is ok | OLD VERSION
  # my $ref_sources_features = extract_features_from_genbank($INP_refgenome,0,$DEFAULTGBKFEATURES);

  # find reference genes contained in @pansetA clusters
  my $taxonOK = 0;
  foreach $pancluster (@pansetA)
  {
    my $fasta_ref = read_FASTA_file_array( $cluster_dir.'/'.$pancluster );
    foreach my $seq ( 0 .. $#{$fasta_ref} )
    {

      # escapa posibles caracteres especiales como [ del nombre del taxon
      if($fasta_ref->[$seq][NAME] =~ /\Q$INP_refgenome\E/)
      {
        $taxonOK++;

        #|NC_002528(640681):579687-580265:-1
        $feat = (split(/\|/,$fasta_ref->[$seq][NAME]))[5];
        if($feat && $feat =~ /(\S+)?\((\d+)\):(\d+)-(\d+):(-*1)/)
        {
          $contig{$1}{'size'} = $2;
          push(@{$contig{$1}{'clusters'}},[$3,$4,$5,$pancluster]);#print "# $1 $2 $3 $4 $5\n";
        }
      }
    }
  }

  if(!$taxonOK)
  {
    die "# $0: error, cannot find reference genome '$INP_refgenome' in pangenomic clusters, please check spelling\n";
  }
  elsif(!keys(%contig))
  {
    die "# $0: error, cannot find genome coordinates in pangenomic clusters, cannot make plot\n";
  }

  # plot genome, contig by contig (source)
  foreach $source (sort keys(%contig))
  {
    my $mapfile = $outfile_root . "_$source.png";
    if($MAKESVGGRAPH)
    {
      $mapfile = $outfile_root . "_$source.svg"; # for full resolution images
    }

    print "# chromosome/contig= $source size= $contig{$source}{'size'} outfile= $mapfile\n";

    my $panel;
    if($MAKESVGGRAPH)
    {
      $panel = Bio::Graphics::Panel->new(
        -image_class=>'GD::SVG',
        -length => $contig{$source}{'size'}, -width => $PLOTWIDTH,
        -pad_left => 20,-pad_right => 20,
        );
    }
    else
    {
      $panel = Bio::Graphics::Panel->new(
        -length => $contig{$source}{'size'}, -width => $PLOTWIDTH,
        -pad_left => 20,-pad_right => 20,
        );
    }

    my $full_length = Bio::SeqFeature::Generic->new( -start => 1, -end => $contig{$source}{'size'} );
    $panel->add_track($full_length,
      -glyph   => 'arrow', -fgcolor => 'black',
      -tick    => 2,-double  => 1
      );

    my $track = $panel->add_track( -glyph => 'generic', -strand_arrow => 1, -label => 1 );

    #push(@{$contig{$1}{'clusters'}},[$3,$4,$5,$pancluster]);
    foreach $feat (sort {$a->[0]<=>$b->[0]} @{$contig{$source}{'clusters'}})
    {
      ($start,$end,$strand,$pancluster) = @$feat;
      if(!$PLOT_FULL_LABELS){ $pancluster = (split(/_/,$pancluster))[0] }
      my $feature = Bio::SeqFeature::Generic->new(
        -display_name => $pancluster,
        -start        => $start,
        -end          => $end,
        -strand       => $strand
        );
      $track->add_feature($feature);
    }

    open(GRAPH,">$mapfile");
    if($MAKESVGGRAPH){ print GRAPH $panel->svg() }
    else
    {
      binmode GRAPH;
      print GRAPH $panel->png();
    }
    close(GRAPH);
  }
}

# plot shell genome
if($INP_plotshell)
{
  unlink($shell_output_png,$shell_output_pdf);
  my @taxa = sort keys(%pangemat);
  my @occup_class = qw( cloud shell soft_core core );
  my $n_of_taxa = scalar(@taxa);
  my ($cloudpos,$cloudmax,$cluster,$s,$class,%stats,%total,%taxa_total) = (-1,-1);
  my $softcorepos = int($SOFTCOREFRACTION*$n_of_taxa);  
  
  if($n_of_taxa < 5)
  {
    die "# EXIT : need at least 5 taxa to perform -s analysis\n";
  }  

  # calculate shell sums, fill gaps and get final number of clusters
  $n_of_clusters = 0;
  foreach $cluster (1 .. $#shell)
  { 
    next if(!$shell[$cluster]);      
    $stats{$shell[$cluster]}++; 
    $n_of_clusters++;
  }
  foreach $s ( 1 .. $n_of_taxa ){ if(!$stats{$s}){ $stats{$s} = 0 } }

  open(SINP,">$shell_input") || die "# EXIT : cannot create $shell_input\n";
  foreach $s (sort {$a<=>$b} keys(%stats))
  {
    print SINP "$stats{$s}\n";
    if($stats{$s}>$cloudmax && $s+1 < $softcorepos)
    {
      $cloudmax = $stats{$s};
      $cloudpos = $s + 1 ; # arbitrarily take max plus next column in plot
    }
  }
  close(SINP); 

  # print lists of genomic compartments
  open(CLOUDF,">$cloudlistfile") || die "# EXIT : cannot create $cloudlistfile\n";
  open(SHELLF,">$shelllistfile") || die "# EXIT : cannot create $shelllistfile\n";
  open(SCOREF,">$softcorelistfile") || die "# EXIT : cannot create $softcorelistfile\n";
  open(COREF,">$corelistfile") || die "# EXIT : cannot create $corelistfile\n";
  foreach $cluster (1 .. $#shell)
  {
    next if(!$shell[$cluster]);
    if($shell[$cluster] <= $cloudpos)
    {
      print CLOUDF "$cluster_names{$cluster}\n";
      $total{'cloud'}++;

      # record which taxa contribute this sequence 
      foreach $taxon (@taxa){ if($pangemat{$taxon}[$cluster] > 0){ $taxa_total{'cloud'}{$taxon}++ } }  
    }
    elsif($shell[$cluster] >= $softcorepos)
    {
      print SCOREF "$cluster_names{$cluster}\n";
      $total{'soft_core'}++;
      foreach $taxon (@taxa){ if($pangemat{$taxon}[$cluster] > 0){ $taxa_total{'soft_core'}{$taxon}++ } }

      if($shell[$cluster] == $n_of_taxa)
      {
        print COREF "$cluster_names{$cluster}\n";
        $total{'core'}++;
        foreach $taxon (@taxa){ if($pangemat{$taxon}[$cluster] > 0){ $taxa_total{'core'}{$taxon}++ } }
      }
    }
    else
    {
      print SHELLF "$cluster_names{$cluster}\n";
      $total{'shell'}++;
      foreach $taxon (@taxa){ if($pangemat{$taxon}[$cluster] > 0){ $taxa_total{'shell'}{$taxon}++ } }
    }
  }
  close(CLOUDF);
  close(CLOUDF);
  close(SCOREF);
  close(COREF);

  if(!$total{'cloud'}){ $total{'cloud'} = 0 }
  if(!$total{'shell'}){ $total{'shell'} = 0 }
  if(!$total{'soft_core'}){ $total{'soft_core'} = 0 }
  if(!$total{'core'}){ $total{'core'} = 0 }

  print "# cloud size: $total{'cloud'} list: $cloudlistfile\n";
  print "# shell size: $total{'shell'} list: $shelllistfile\n";
  print "# soft core size: $total{'soft_core'} list: $softcorelistfile\n";
  print "# core size: $total{'core'} (included in soft core) list: $corelistfile\n";

  # create graphs and fit mix models if possible
  if(feature_is_installed('R'))
  {
    # set colors
    my %colors;
    if(keys(%RGBCOLORS))
    { 
      %colors = %RGBCOLORS;
      print "\n# using RGB colors, defined in \%RGBCOLORS\n"; 
    }
    else
    { 
      %colors = %COLORS;
      print "\n# using default colors, defined in \%COLORS\n"; 
    }
  
    # calculate circle radii and sort colors accordingly
    my (@radius,@color,$max);
    for $s (sort {$total{$b}<=>$total{$a}} keys(%total))
    {
      push(@color,$colors{$s});
      if(!defined($max)){ $max = $total{$s} }
      push(@radius,sqrt($total{$s}/$max));
    } #foreach my $ii (0 .. 3){ printf("%f %f\n",$radius[$ii],3.14159*($radius[$ii]**2)) }

    if(!$VERBOSE){ $Rparams = '-q 2>&1 > /dev/null' }
    
    print "\n# globals controlling R plots: \$YLIMRATIO=$YLIMRATIO\n";

    open(RSHELL,"|R --no-save $Rparams ") || die "# cannot call R: $!\n";
    print RSHELL<<EOR;
		shell = read.table("$shell_input",header=F);
		colors = c( rep($colors{'cloud'},each=$cloudpos), 
      rep($colors{'shell'},each=$softcorepos-$cloudpos-1), 
		  rep($colors{'soft_core'},each=$n_of_taxa-$softcorepos), 
      $colors{'core'}
    );
	
    pdf(file="$shell_output_pdf");
	  bars = barplot(shell\$V1,xlab='number of genomes in clusters (occupancy)',ylab='number of gene clusters',
      main='',names.arg=1:$n_of_taxa,col=colors,ylim=c(0,$YLIMRATIO*max(shell\$V1)));
      
		mtext(sprintf("total clusters = %s",format($n_of_clusters,big.mark=",",scientific=FALSE)),side=3,cex=0.8,line=0.5);
		#text(x=bars[$n_of_taxa],y=$stats{$n_of_taxa}/2,labels=sprintf("%d",$stats{$n_of_taxa}),cex=0.8); # core size
		legend('top', c('cloud','shell','soft core','core'), cex=1.0, 
      fill=c($colors{'cloud'},$colors{'shell'},$colors{'soft_core'},$colors{'core'}) );
	
    png(file="$shell_output_png");
		bars = barplot(shell\$V1,xlab='number of genomes in clusters (occupancy)',ylab='number of gene clusters',
		  main='',names.arg=1:$n_of_taxa,col=colors,ylim=c(0,$YLIMRATIO*max(shell\$V1))); 
    mtext(sprintf("total clusters = %s",format($n_of_clusters,big.mark=",",scientific=FALSE)),side=3,cex=0.8,line=0.5);
    #text(x=bars[$n_of_taxa],y=$stats{$n_of_taxa}/2,labels=sprintf("%d",$stats{$n_of_taxa}),cex=0.8);        
		legend('top', c('cloud','shell','soft core','core'), cex=1.0, 
      fill=c($colors{'cloud'},$colors{'shell'},$colors{'soft_core'},$colors{'core'}) );

		## now make circle plots
		circle <- function(x, y, r, ...)
		{
			ang <- seq(0, 2*pi, length = 100)
			xx <- x + r * cos(ang)
			yy <- y + r * sin(ang)
			polygon(xx, yy, ...)
		}

		pdf(file="$shell_circle_pdf");
		par(mar=c(0,0,0,0));
		plot(-3,-3,ylim=c(0,3), xlim=c(0,3),axes=F);
		circle(x=1.5,y=1.5,r=$radius[0],col=$color[0], border=NA);
		circle(x=1.5,y=1.5,r=$radius[1],col=$color[1], border=NA);
		circle(x=1.5,y=1.5,r=$radius[2],col=$color[2], border=NA);
		circle(x=1.5,y=1.5,r=$radius[3],col=$color[3], border=NA);
		text(1.5,0.25,sprintf("total gene clusters = %s   taxa = %d",
      format($n_of_clusters,big.mark=",",scientific=FALSE),$n_of_taxa),cex=0.8);	
		legend('topright', c(
			"cloud  ($total{'cloud'} , genomes<=$cloudpos)",
			"shell  ($total{'shell'})",
			"soft core  ($total{'soft_core'} , genomes>=$softcorepos)",
			"core  ($total{'core'} , genomes=$n_of_taxa)"),
			cex=1.0, fill=c($colors{'cloud'},$colors{'shell'},$colors{'soft_core'},$colors{'core'}));

		png(file="$shell_circle_png");
		par(mar=c(0,0,0,0));
    plot(-3,-3,ylim=c(0,3), xlim=c(0,3),axes=F);
    circle(x=1.5,y=1.5,r=$radius[0],col=$color[0], border=NA);
    circle(x=1.5,y=1.5,r=$radius[1],col=$color[1], border=NA);
    circle(x=1.5,y=1.5,r=$radius[2],col=$color[2], border=NA);
    circle(x=1.5,y=1.5,r=$radius[3],col=$color[3], border=NA);
		text(1.5,0.25,sprintf("total gene clusters = %s   taxa = %d",
      format($n_of_clusters,big.mark=",",scientific=FALSE),$n_of_taxa),cex=0.8);
    legend('topright', c(
      "cloud  ($total{'cloud'} , genomes<=$cloudpos)",
      "shell  ($total{'shell'})",
      "soft core  ($total{'soft_core'} , genomes>=$softcorepos)",
      "core  ($total{'core'} , genomes=$n_of_taxa)"),
      cex=1.0, fill=c($colors{'cloud'},$colors{'shell'},$colors{'soft_core'},$colors{'core'}));
	
		negTruncLogLike <- function( p, y, core.p )
		{
			#   The negative zero-truncated log-likelihood function to be minimized
			#   by binomix.
			#   Originally by Lars Snipen
			#   Biostatistics, Norwegian University of Life Sciences.
      np <- length( p )/2
		  p.det <- c( core.p, p[(np+1):length(p)] )
		  p.mix <- c( 1-sum( p[1:np] ), p[1:np] )
			G <- length( y )
		  K <- length( p.mix )
		  n <- sum( y )
    
	    theta_0 <- choose( G, 0 ) * sum( p.mix * (1-p.det)^G )
			L <- -n* log( 1 - theta_0 )
			for( g in 1:G )
			{
        theta_g <- choose( G, g ) * sum( p.mix * p.det^g * (1-p.det)^(G-g) )
        L <- L + y[g] * log( theta_g )
    	}
    	return( -L )
		}

		binomix <- function( y, ncomp=(2:5), core.detect.prob=1.0 )
		{   
			#   Function that estimates pan- and core-genome size using the zero-truncated
			#   binomial mixture model.
			#   
			#   y must be the number of genes found in 1,...,G genomes. ncomp must be a 
			#   vector specifying the possible number of components (2 or more) to consider.
			#   core.detect.prob is the fixed detection probability of the core component. Usually
			#   core genes have detection probability 1.0, i.e. always detected, but due to
			#   inaccuracies in all computations, some core genes may not be detected in some 
			#   genomes, hence the detection probability could be set fractionally less than 1.0.
			#   
			#   A matrix of results is returned, together with a list of mixture models, one 
			#   for each possible number of components specified in ncomp. The result matrix
			#   has one row for each number of components, and four columns. The columns are
			#   Core.size, Pan.size, BIC and LogLikelihood.
			#   
			#   Originally by Lars Snipen
			#   Biostatistics, Norwegian University of Life Sciences.
			#   http://www.biomedcentral.com/content/pdf/1471-2164-10-385.pdf
			#   BMC Genomics 2009,10:385 doi:10.1186/1471-2164-10-385

			n <- sum( y )
			G <- length( y )
   	 
			res.tab <- matrix( NA, nrow=length(ncomp)+1, ncol=4 )
		    	colnames( res.tab ) <- c( "Core.size", "Pan.size", "BIC", "LogLikelihood" )
			rownames( res.tab ) <- c( paste( ncomp, "components" ), "Sample" )
		    	mix.list <- list( length(ncomp) )
		    	ctr <- list( maxit=300, reltol=1e-6 )
			for( i in 1:length( ncomp ) )
			{
        nc <- ncomp[i]
			  np <- nc - 1
			  pmix0 <- rep( 1, np )/nc            # flat mixture proportions
			  pdet0 <- (1:np)/(np+1)              # "all" possible detection probabilities
        p.initial <- c(pmix0,pdet0)
			  A <- rbind( c(rep(1,np),rep(0,np)), c(rep(-1,np),rep(0,np)), diag(np+np), -1*diag(np+np) )
			  b <- c(0,-1,rep(0,np+np),rep(-1,np+np))
		        
			  est <- constrOptim( theta=p.initial, f=negTruncLogLike, grad=NULL, 
				method="Nelder-Mead", control=ctr, ui=A, ci=b, y=y, core.p=core.detect.prob )
			  res.tab[i,4] <- -1*est\$value                        # the log-likelihood
			  res.tab[i,3] <- -2*res.tab[i,4] + log(n)*(np+nc)    # the BIC-criterion
			  p.mix <- c( 1 - sum( est\$par[1:np] ), est\$par[1:np] )
			  p.det <- c( core.detect.prob, est\$par[(np+1):length( est\$par )] )
			        
			  theta_0 <- choose( G, 0 ) * sum( p.mix * (1-p.det)^G )
			  y_0 <- n * theta_0/(1-theta_0)
			  res.tab[i,2] <- n + round( y_0 )
			  ixx <- which( p.det >= core.detect.prob )
			  res.tab[i,1] <- round( res.tab[i,2] * sum( p.mix[ixx] ) )
			        
			  mix.list[[i]] <- list( Mixing.prop=p.mix, Detect.prob=p.det )
		  }
			
			res.tab[(length(ncomp)+1),2] <- n
			res.tab[(length(ncomp)+1),1] <- y[length(y)]
			return( list( Result.matrix=res.tab, Mix.list=mix.list ) )
		}
	
		maxcomp <- min($n_of_taxa,10)	
		estimates <- binomix( shell\$V1 , ncomp=2:maxcomp )
		write.table(estimates\$Result.matrix,quote=F,file="$shell_estimates")
		
		q()
EOR

    close(RSHELL);

    print "\n# shell bar plots: $shell_output_png , $shell_output_pdf\n";
    print "# shell circle plots: $shell_circle_png , $shell_circle_pdf\n\n";

    print "# pan-genome size estimates (Snipen mixture model PMID:19691844): $shell_estimates\n";
    open(MIXTMOD,$shell_estimates);
    while(<MIXTMOD>)
    {
      print;
    }
    close(MIXTMOD);
  }
  else
  {
    die "# $0 : cannot create plots as this script requires the software R to be installed; please install it (http://www.r-project.org)\n";
  }

  # print occupnacy stats per taxon
  print "\n\n# occupancy stats:\n";
  foreach $class (@occup_class){ print "\t$class" } print "\n";
  foreach $taxon (@taxa)
  {
    print $taxon;
    foreach $class (@occup_class)
    {
      printf("\t%d",$taxa_total{$class}{$taxon} || 0);
    } print "\n";
  }

  # produce intersection matrix if required
  if($INP_shared_matrix)
  {
		my ($taxon2,$intersect);
    my ($mean_pan_clusters,$mean_intersection) = (0,0);

		open(INTERSECTIONF,">$intersection_file") 
			|| die "# EXIT : cannot create $intersection_file\n";

		print INTERSECTIONF "intersection";
		foreach $taxon (@taxa){ print INTERSECTIONF "\t$taxon" } 
		print INTERSECTIONF "\n";  
		foreach $taxon (@taxa)
		{
			print INTERSECTIONF "$taxon";
			foreach $taxon2 (@taxa)
			{
				$intersect = 0;
				foreach $cluster (1 .. $#shell)
				{
					next if(!$shell[$cluster]);
					next if($INP_skip_singletons && 
						$shell[$cluster] < $INP_skip_singletons);

					if($pangemat{$taxon}[$cluster] > 0 && 
						$pangemat{$taxon2}[$cluster] > 0)
					{
						$intersect++;
					}
				}	
				print INTERSECTIONF "\t$intersect";	

        if($taxon eq $taxon2){ $mean_pan_clusters += $intersect }
        $mean_intersection += $intersect;
			}
			print INTERSECTIONF "\n";
		}

		close(INTERSECTIONF);

		print "\n# intersection pangenome matrix: $intersection_file\n";		
    printf("# mean %%cluster intersection: %1.2f\n",
      100 * ($mean_intersection/($n_of_taxa ** 2)) /
      ($mean_pan_clusters/$n_of_taxa));
  }
}

