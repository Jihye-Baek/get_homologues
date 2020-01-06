#!/usr/bin/env bash

# 2015-8 Pablo Vinuesa (1) and Bruno Contreras-Moreira (2):
# 1: http://www.ccg.unam.mx/~vinuesa (Center for Genomic Sciences, UNAM, Mexico)
# 2: http://www.eead.csic.es/compbio (Laboratory of Computational Biology, EEAD/CSIC, Spain)

#: AIM: generate a distance matrix out of a [pangenome|average_identity] matrix.tab file produced with
#       get_homologues.pl and accompanying scripts, such as compare_clusters.pl with options -t 0 -m.
#       This script calls R functions from ape, cluster, gplots, grDevices, dendextend and factoextra on such matrices.
#
#: OUTPUT: ph + svg|pdf output of hclust and heatmap2. Computes optimal number of clusters


progname=${0##*/} 
VERSION='v1.2_5Jan20' # v1.2_5Jan20 changes:
                      #  * added -P option for selecting palettes generated by grDevices::colorRampPalette; 
                      #  * color scale is now continuous, with 256 breaks; 
		      #  * produces only row-dendrogram for heatmap
		      #  * changed gap_method=firstSEmax as default, instead of Tibs2001SEmax
		      #  * fixed dendro_cut_file=$(find . -name "*cut_at*")
		      #  * added function cleanup_R_script
		      
         #  v1.1_26Jan18 changed fviz_dend for dendextend to plot clustering results for better control of plot params
         #     and proper plotting of scale-bar in gower-distances-based hclus plots, which don't render 
	 #     correctly with fviz_dend. changed default distance back to gower. Improved documentation
	 #     Now depends also on 
         #  v1.1_25Jan18; Major upgrade: added the gap- and silhouette meand width goodness of clustering statistics
         #  to determine the optimal number of clusters automatically.
	 # Calls new package factoextra; fviz_dend; fviz_gap_stat
	 # Improved/updated documentation and extended user input checking
         # v0.6_124Dec17: remove the invariant (core-genome) and singleton columns from input table
         #v'0.5_14Oct17'; added options -A and -X to control the angle 
                      #                and character eXpansion factor of leaf labels
         #'0.4_7Sep17' # v0.4_7Sep17; added options -x <regex> to select specific rows (genomes) 
                     #                                       from the input pangenome_matrix_t0.tab
                     #                            -c <0|1> to print or not distances in heatmap cells
		     #                            -f <int> maximum number of decimals in matrix display (if -c 1)

         # v0.3_03Sep15 added ape's function write.tree() to generate a newick string from the hclust() object
         # v0.1_14Feb15, first version; generates hclust output in svg() and pdf(), formats,
		                  #  plus a heatmap in both formats

date_F=$(date +%F |sed 's/-/_/g')-
date_T=$(date +%T |sed 's/:/./g')
start_time="$date_F$date_T"

#---------------------------------------------------------------------------------#
#>>>>>>>>>>>>>>>>>>>>>>>>>>>> FUNCTION DEFINITIONS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#
#---------------------------------------------------------------------------------#

function  cleanup_R_script()
{
   R_script=$1
   
   perl -pe 's/^[>\+]//' "$R_script" > "${R_script}.tmp"
   mv "${R_script}.tmp" "$R_script" 
}
#---------------------------------------------------------------------------

function print_notes()
{
   cat << NOTES
    
    NOTES: 

    $progname is a simple shell wrapper for the ape, cluster and gplots packages,
    to wich dendextend and factoextra were added later on,
    calling functions to generate different distance matrices to compute distance 
    trees and ordered heatmaps with row dendrograms from the 
    pan_genome_matrix_t0.tab file generated by compare_clusters.pl 
    when using options -m and -t 0
   
    1) If the packages are not installed on your system, then proceed as follows:
    
    i) with root privileges, type the following into your shell console:
       sudo R
       > install.packages(c("ape", "gplots", "cluster", "grDevices", "dendextend", "factoextra"), dependencies=TRUE)
       > q()
       
       $ exit # quit root account
       $ R    # call R
       > library("gplots") # load the lib; do your stuff
       
    ii) without root privileges, intall the package into ~/lib/R as follows:
       $ mkdir -p ~/lib/R
       
       # set the R_LIBS environment variable before starting R as follows:
       $ export R_LIBS=~/lib/R     # bash syntax
       $ setenv R_LIBS=~/lib/R     # csh syntax
       # You can type the corresponding line into your .bashrc (or similar) configuration file
       # to make this options persistent
       
       # Call R from your terminal and type:
       > install.packages(c("ape", "gplots", "cluster", "dendextend", "factoextra"), dependencies=TRUE, lib="~/lib/R") 	
   
   iii) Once installed, you can read the documentation for packages and functions by typing the following into the R console:
      library("gplots")       # loads the lib into the environment
      help(package="gplots")  # read about the gplots package
      help(heatmap.2)         # read about the heatmap.2 function      
      help(svg)               # read about the svg function, which generates the svg ouput file     
      help(pdf)               # read about the pdf function, which generates the pdf ouput file     
      ...
     
   2. The pangenome_matrix ouput file will be automatically edited, changing PATH for Genome in cell 1,1
   
   3. Uses distance methods from the cluster::daisy() function.
   
      run ?daisy from within R for a detailed description of gower distances for categorical data
      
      http://rfunctions.blogspot.mx/2012/07/gowers-distance-modification.html
      http://pbil.univ-lyon1.fr/ade4/ade4-html/dist.binary.html
      https://stat.ethz.ch/R-manual/R-devel/library/cluster/html/daisy.html
      http://stats.stackexchange.com/questions/123624/gower-distance-with-r-functions-gower-dist-and-daisy
      http://cran.r-project.org/web/packages/StatMatch/StatMatch.pdf
      http://www.inside-r.org/packages/cran/StatMatch/docs/gower.dist
 
   4. For clustering see 
      http://www.statmethods.net/advstats/cluster.html for more details/options on hclust
      http://ecology.msu.montana.edu/labdsv/R/labs/lab13/lab13.html
      http://www.instantr.com/2013/02/12/performing-a-cluster-analysis-in-r/

NOTES

   exit 0

}
#---------------------------------------------------------------------------

function check_dependencies()
{
    for prog in R
    do 
       bin=$(type -P $prog)
       if [ -z $bin ]; then
          echo
          echo "# ERROR: $prog not in place!"
          echo "# ... you will need to install \"$prog\" first or include it in \$PATH"
          echo "# ... exiting"
          exit 1
       fi
    done

    echo
    echo '# Run check_dependencies() ... looks good: R is installed.'
    echo   
}
#---------------------------------------------------------------------------

function print_help()
{
    cat << HELP
    
    USAGE synopsis for: [$progname v.$VERSION]:
       $progname -i <string (name of matrix file)> [-d <distance> -a <algorithm> -o <format> ...]
    
    REQUIRED
       -i <string> name of matrix file 
    OPTIONAL:
     * Clustering
       -a <string> algorithm/method for clustering 
             [ward.D|ward.D2|single|complete|average(=UPGMA)]      [def: $algorithm]
       -d <string> distance type [euclidean|manhattan|gower]       [def: $distance]
     * Goodness of clustering
       -s <string> goodness of clustering statistic [gap|sil]      [def: $clust_stat]
       -S <integer> number of random starts (gap statistic)        [def: $n_start]
       -M <string>  method: [firstSEmax|Tibs2001SEmax|
                             globalSEmax|firstmax|globalmax]       [def: $gap_method]
       -n <integer> num. of bootstrap replicates (gap stat.)       [def: $n_boot]                                                   
       -k <integer> max. number of clusters                        [def: ${k}; NOTE: 2<= k <= n-1 ]
   
     * Plotting
       -c <int> 1|0 to display or not the distace values           [def:$cell_note]
                    in the heatmap cells 
       -f <int> maximum number of decimals in matrix display       [1,2; def:$decimals]
       -t <string> text for Main title                             [def:$text]
       -m <integer> margins_horizontal                             [def:$margin_hor]
       -v <integer> margins_vertical                               [def:$margin_vert]
       -o <string> output file format  [svg|pdf]                   [def:$outformat]
       -p <integer> points for plotting device                     [def:$points]    
       -H <integer> ouptupt device height                          [def:$height]    
       -W <integer> ouptupt device width                           [def:$width]     
       -A <'integer,integer'> angle to rotate row,col labels       [def $angle]
       -X <float> leaf label character expansion factor            [def $charExp]
       -P palette <string> [white-black|white-blue|white-red|heat] [def $palette]

     * Filter input pangenome_matrix_t0.tab using regular expressions:
       -x <string> regex, like: 'Escherichia|Salmonella'           [def $regex]
       
     * Miscelaneous
       -N <flag> print Notes and exit                              [flag]

    EXAMPLE:
      $progname -i pangenome_matrix_t0.tab -t "Pan-genome tree" -a ward.D2 -d gower -o pdf -x 'maltoph|genosp' -A '35,NULL' -X 0.8 -k 50 -P white-red

    AIM: compute a distance matrix from a pangenome_matrix.tab file produced after running 
         get_homologues.pl and compare_clusters.pl with options -t 0 -m .
         The pangenome_matrix.tab file processed by hclust(), and gplots::heatmap.2()
    
    OUTPUT: a newick file with extension .ph and svg|pdf output of hclust and heatmap.2 calls +
             goodness of clustering (gap|silhouette width) dentrogram and stats plot.
     
    DEPENDENCIES:
         R packages: ape, cluster, gplots, grDevices, dendextend and factoextra. Run $progname -N for installation instructions.
	 
    IMPORTANT NOTES: 
        1. to get the best display of your genome lables, these should be made as short as possible.
           This can be simply done by executing sed commands such as: 
	   sed 's/LongGenusName/L/g; s/speciesname/spn/g' pangenome_matrix_t0.tab > pangenome_matrix_t0.tabed
	2. The gap-statistic of clustering goodness is compuationally intensive and takes a long time 
	   (up to hours) to run on a large pan-genome matrix (n_genomes > 50; n_clusters > 8000) with a reasonalbe 
	   (n >= 500) number of bootstrap replicates and independent searches (S >= 20) and large numbers 
	   of potential clusters (k >= 15). The default option is the silhouette-width statistic, which is 
	   much faster to run, although also less powerful and much more conservative.
HELP

  check_dependencies

exit 0

}

#------------------------------------------------------------------------#
#------------------------------ GET OPTIONS -----------------------------#
#------------------------------------------------------------------------#
tab_file=
regex=

runmode=0
check_dep=0
cell_note=0
decimals=2

algorithm=ward.D2
distance=gower

clust_stat=sil
n_start=25
n_boot=100     
k=15
gap_method=firstSEmax


text="Pan-genome clusters"
width=15
height=17
points=15
margin_hor=15
margin_vert=5
outformat=pdf

charExp=0.7
angle='NULL,NULL'
#colTax=1

subset_matrix=0

palette="heat"

# See bash cookbook 13.1 and 13.2
while getopts ':a:A:c:d:f:i:k:t:m:M:n:o:p:s:S:v:x:X:H:W:P:R:hND?:' OPTIONS
do
   case $OPTIONS in

   a)   algorithm=$OPTARG
        ;;
   A)   angle=$OPTARG
        ;;
   c)   cell_note=$OPTARG
        ;;
   d)   distance=$OPTARG
        ;;
   f)   decimals=$OPTARG
        ;;
   i)   tab_file=$OPTARG
        ;;
   k)	k=$OPTARG
	;;
   m)   margin_hor=$OPTARG
        ;;
   M)   gap_method=$OPTARG
        ;;
   n)	n_boot=$OPTARG
        ;;	
   v)   margin_vert=$OPTARG
        ;;
   o)   outformat=$OPTARG
        ;;
   p)   points=$OPTARG
        ;;
   s)   clust_stat=$OPTARG
        ;;
   S)   n_start=$OPTARG
        ;;
   t)   text=$OPTARG
        ;;
   x)   regex=$OPTARG
        ;;
   X)   charExp=$OPTARG
        ;;
   C)   reorder_clusters=0
        ;;
   H)   height=$OPTARG
        ;;
   W)   width=$OPTARG
        ;;
   P)   palette=$OPTARG
        ;;
   R)   runmode=$OPTARG
        ;;
   N)   print_notes
        ;;
   D)   DEBUG=$OPTARG
        ;;
   \:)   printf "argument missing from -%s option\n" $OPTARG
   	 print_help
     	 exit 2 
     	 ;;
   \?)   echo "need the following args: "
   	 print_help
         exit 3
	 ;;
    *)   echo "An  unexpected parsing error occurred"
         echo
         print_help
	 exit 4
	 ;;	 
   esac >&2   # print the ERROR MESSAGES to STDERR
done

shift $(($OPTIND - 1))

if [ -z $tab_file ]
then
       echo "# ERROR: no input tab file defined!"
       print_help
       exit 1    
fi

if [ $clust_stat != "sil" -a $clust_stat != "gap" ]
then
       echo "# ERROR: goodness of clustering stats must be sil|gap"
       print_help
       exit 1	 
fi

if [ $distance != "gower" -a $distance != "manhattan" -a $distance != "euclidean" ]
then
       echo "# ERROR: distances must be one of gower|manhattan|euclidean"
       print_help
       exit 1	 
fi


if [ -z $DEBUG ]
then
     DEBUG=0 
fi


if [ -z "$text" ]
then
    text=$(echo $tab_file)
fi

if [ ! -z "$regex" ]
then
    subset_matrix=1
fi

if [ $gap_method != "Tibs2001SEmax" -a $gap_method != "firstSEmax" -a $gap_method != "globalSEmax" -a $gap_method != "firstmax" -a $gap_method != "globalmax" ]
then
    echo "ERROR: gat_metod must be one of: firstSEmax|Tibs2001SEmax|globalSEmax|firstmax|globalmax"
    print_help
    exit 1
fi

if [ $palette != "white-black" -a $palette != "white-blue" -a $palette != "white-red" -a $palette != "heat" ]
then
    echo "ERROR: palette must be one of: white-black|white-blue|white-red|heat"
    print_help
    exit 1
fi

                           
#-------------------#
#>>>>>> MAIN <<<<<<<#
#-------------------#

# 0) print run's parameter setup
wkdir=$(pwd)

cat << PARAMS

##############################################################################################
>>> $progname v$VERSION run started at $start_time
        
	# General
	working direcotry:$wkdir
        input tab_file:$tab_file | regex:$regex
	distance:$distance|dist_cutoff:$dist_cutoff|hclustering_meth:$algorithm
	
	# Heatmaps
	cell_note:$cell_note
        text:$text|margin_hor:$margin_hor|margin_vert:$margin_vert|points:$points
        width:$width|height:$height|outformat:$outformat
	angle:"$angle"|charExp:$charExp
	palette:"$palette"
	
	# Goodnes of clustering stats
          * gap satistic
	     n_start:$n_start|n_boot:$n_boot|gap_model:$gap_model
	  * gap and silhouette width
	     k:$k
	      
##############################################################################################

PARAMS


# 1) prepare R's output file names
heatmap_outfile="hclust_${distance}-${algorithm}_${tab_file%.*}_heatmap.$outformat"
heatmap_outfile=${heatmap_outfile//\//_}
tree_file="hclust_${distance}-${algorithm}_${tab_file%.*}_tree.$outformat"
tree_file=${tree_file//\//_}
newick_file="hclust_${distance}-${algorithm}_${tab_file%.*}_tree.ph"
newick_file=${newick_file//\//_}

aRow=$(echo "$angle" | cut -d, -f1)
aCol=$(echo "$angle" | cut -d, -f2)


echo ">>> Plotting files $tree_file and $heatmap_outfile ..."
echo "     this will take some time, please be patient"
echo

# 2) replace path with "Genome" in first col of 1st row of source $tab_file (pangenome_matrix_t0.tab)
perl -pe 's/^source\S+/Genome/' $tab_file | sed 's/\.f[an]a//g; s/\.gbk//g; s/-/_/g; s/__/_/g' > ${tab_file}ed

# 3) call R using a heredoc and write the resulting script to file 
R --no-save -q <<RCMD > ${progname%.*}_script_run_at_${start_time}.R
suppressPackageStartupMessages(library("gplots"))
library("cluster")
library("grDevices")
library("ape")
suppressPackageStartupMessages(library("dendextend"))
suppressPackageStartupMessages(library("factoextra"))

# 0.1 save original parameters
opar <- par(no.readonly = TRUE)

# 0.2 set options
options(expressions = 100000) #https://stat.ethz.ch/pipermail/r-help/2004-January/044109.html

# 1. read cleaned pan-genome matrix
table <- read.table(file="${tab_file}ed", header=TRUE, sep="\t")

# 2. Note that silhouette statistics are only defined if 2 <= k <= n -1 genomes
#   so make sure the user provides a usable k or set it to maximum possible value automatically
n_tax <- dim(table)[1]
k <- $k
max_k <- n_tax -1 
if( k >= n_tax) k <- max_k

# 3. remove the invariant (core-genome) columns
#cat("Removing invariant (core-genome) columns from ${tab_file} ...\n")
table <- table[sapply(table,  function(x) length(unique(x))>1)]

write.table(table, file="pangenome_matrix_variable_sites_only.tsv", sep="\t", 
            row.names = FALSE)

# 4. filter rows with user-provided regex
if($subset_matrix > 0 ){
  include_list <- grep("$regex", table\$Genome)
   table <- table[include_list, ]
}

# for goodness of clustering stats we require a dfr without the strain names
# using good ol' base R to avoid more dependencies ... may enforce tydiverse in the future ... 
#  ... It is likely not wise to attempt escaping the gravity of the tidyverse ;)
#  As a matter of fact, factoextra meakes use of ggplot2, a core tidyverse package.
#dfr.num <- table %>% select(2:dim(table)[2])
dfr.num <- table[,2:ncol(table)]
dfr.num <- droplevels.data.frame(dfr.num)

# 5.1 convert dfr.num to matrix
dfr.num.mat <- as.matrix(dfr.num)

# 5.2 add rownmaes to each matrix and dfr
genomes <- table\$Genome
rownames(dfr.num.mat) <- genomes
rownames(dfr.num) <- genomes

# 6.1 compute distances from the numeric matrix
my_dist <- suppressWarnings(daisy(dfr.num.mat, metric="$distance", stand=FALSE))

# 6.2 write the distance matrix to disk
write.table(as.matrix(my_dist), file="${distance}_dist_matrix.tab", row.names=TRUE, col.names=FALSE, sep="\t")

# 7.1 compute dendrograms and phylogenies using hclust and write Newick-formatted string to disk
dendro <- as.dendrogram(hclust(my_dist, method="$algorithm"))
nwk_tree <- as.phylo(hclust(my_dist, method="$algorithm"), hang=-1, main="$algorithm clustering with $distance dist", cex = $charExp)
write.tree(phy=nwk_tree, file="$newick_file")

# 7,2 plot the dendrogram
$outformat("$tree_file", width=$width, height=$height, pointsize=$pointsize)
plot(hclust(my_dist, method="$algorithm"), hang=-1, main="$algorithm clustering with $distance dist", cex = $charExp)
dev.off()

# 8. Plot heatmap; 
# Prepare palette. NOTE: must have one more break than colour, i.e. 256,255

hmcols <- c()

if ("$palette" == "white-black")
{
    hmcols<-rev(colorRampPalette(c("white","grey", "black"))(255)) 
}

if ("$palette" == "white-blue") 
{
    hmcols<-rev(colorRampPalette(c("white", "deepskyblue", "blue3"))(255))
}

if ("$palette" == "white-red")
{
    hmcols<-rev(colorRampPalette(c("white", "darkgoldenrod1", "darkred"))(255))
}

if ("$palette" == "heat")
{
   hmcols <- heat.colors(255, alpha = 1, rev = FALSE)
}

# 8.1 Plot heatmaps without cell values
if($cell_note == 0){
   $outformat(file="$heatmap_outfile", width=$width, height=$height, pointsize=$pointsize)
       heatmap.2(as.matrix(my_dist), main="$text", breaks=256, key.title=NA, key.xlab="${distance}-dist", notecol="black", 
       density="density", trace="none", dendrogram="row", margins=c($margin_vert,$margin_hor), lhei = c(1,5), 
       cexRow=$charExp, cexCol=$charExp, srtRow=$aRow, labCol=FALSE, col=hmcols)
   dev.off()
}

# 8.2 Plot heatmaps with cell values
if($cell_note == 1){
   $outformat(file="$heatmap_outfile", width=$width, height=$height, pointsize=$pointsize)
       heatmap.2(as.matrix(my_dist), cellnote=round(as.matrix(my_dist),$decimals), main="$text", breaks=256, key.title=NA, 
       key.xlab="${distance}-dist", notecol="black", density="density", trace="none", dendrogram="row", 
       margins=c($margin_vert,$margin_hor), lhei = c(1,5), cexRow=$charExp, cexCol=$charExp, srtRow=$aRow, labCol=FALSE, col=hmcols)
   dev.off()
}    

# 9. compute goodness of clustering stats [gap|silhouette-width]
# 9.1 gap-statistic

if("$clust_stat" == "gap"){
    # compute the gap_statistic using cluster::clusGap
    gap_stat <- clusGap(dfr.num, diss = my_dist, FUN = hcut, nstart = $n_start, d.power = 2, K.max = k, B = $n_boot, method = "$gap_method")
    
    # cluster::maxSE gets the optimal number of clusters;
    gap_n_clust <- maxSE(gap_stat\$Tab[, "gap"], gap_stat\$Tab[, "SE.sim"], method = "$gap_method")
       
    dend <- color_branches(dendro, k = gap_n_clust)
    
    gap_plot_name <- paste("gap-statistic_plot_${algorithm}-${distance}", ".${outformat}", sep = "")
    
    gap_stat_plot <- fviz_gap_stat(gap_stat, maxSE = list(method = "$gap_method", SE.factor= 1))
    
    $outformat(gap_plot_name)
    plot(gap_stat_plot)
    dev.off()

    # plot with clusters delimited by rectangles
    gap_hc_plot_name <- paste("hcluster_${algorithm}-${distance}_cut_at_gap-stat_k", gap_n_clust, ".${outformat}", sep = "")
    title <- paste("hc of pan-genome (${algorithm}-${distance}; gap-statistic: k = ", gap_n_clust, ")", sep="")
    
    $outformat(gap_hc_plot_name)
       par(mar=c(3,1,1,8))
       #plot(d_plot)
       #dend %>% set("branches_k_color", value = 3:gap_n_clust, k = gap_n_clust ) %>% 
       dend %>% set("branches_k_color", k = gap_n_clust ) %>% 
              set("labels_cex", c($charExp)) %>% plot(horiz = TRUE) 
     
       dend %>% rect.dendrogram(k = gap_n_clust, horiz = TRUE, border = 8, lty = 5, lwd = 1)
   dev.off()
   par(opar)
}

# 9.2 silhouette-width statistic
if("$clust_stat" == "sil"){
   # compute the silhouette-width statistic using factoextra::fviz_nbclust
   my_dist.nbc.sil <- fviz_nbclust(dfr.num, diss = my_dist, FUN = hcut, method = "silhouette", k.max = k)

   # extract the number of optimal clusters:
   sil_max <- max(my_dist.nbc.sil\$data\$y)
   sil_n_clust <- as.integer(my_dist.nbc.sil\$data[my_dist.nbc.sil\$data\$y==sil_max,][1])
   
   # use dendextend::color_branches
   dend <- color_branches(dendro, k = sil_n_clust)
     
   sil_plot_name <- paste("silhouette_width_statistic_plot_", "${algorithm}", "-", "$distance", ".${outformat}", sep = "")
   
   $outformat(sil_plot_name)
      plot(my_dist.nbc.sil)
   dev.off()
   
   sil_hc_plot_name <- paste("hcluster_", "${algorithm}", "-", "${distance}", "_cut_at_silhouette_mean_width_k", sil_n_clust, ".${outformat}", sep = "")
   title <- paste("hc of pan-genome (", "${algorithm}", "-", "{$distance}", "; silhouette mean width: k = ", sil_n_clust, ")", sep="")
   
    $outformat(sil_hc_plot_name)
    par(mar=c(3,1,1,8))
       #plot(d_plot)
       #dend %>% set("branches_k_color", value = 3:sil_n_clust, k = sil_n_clust ) %>% 
       dend %>% set("branches_k_color", k = sil_n_clust ) %>% 
             set("labels_cex", c($charExp)) %>% plot(horiz = TRUE) 
      dend %>% rect.dendrogram(k = sil_n_clust, horiz = TRUE, border = 8, lty = 5, lwd = 1)
    dev.off()
    par(opar)
}

RCMD

if [ -s $tree_file ]
then
     echo ">>> File $tree_file was generated"
else
     echo ">>> ERROR: File $tree_file was  NOT generated!"
fi


if [ -s ${distance}_dist_matrix.tab ]
then
     echo ">>> File ${distance}_dist_matrix.tab was generated"
else
     echo ">>> ERROR: File ${distance}_dist_matrix.tab was NOT generated!"
fi

if [ -s $heatmap_outfile ] 
then
     echo ">>> File $heatmap_outfile was generated"
else
     echo ">>> ERROR: File $heatmap_outfile was NOT generated!"
fi

if [ -s $newick_file ] 
then
     echo ">>> File $newick_file was generated"
else
     echo ">>> ERROR: File $newick_file was NOT generated!"
fi

goodness_of_clust_plot=$(find . -name '*statistic_plot*')
if [ -s "$goodness_of_clust_plot" ]
then
     echo ">>> File $goodness_of_clust_plot was generated"
else
     echo ">>> ERROR: File $goodness_of_clust_plot was NOT generated!"
fi

dendro_cut_file=$(find . -name "*cut_at*")
if [ -s "$dendro_cut_file" ]
then
     echo ">>> File $dendro_cut_file was generated"
else
     echo ">>> ERROR: File $dendro_cut_file was NOT generated!"
fi

cleanup_R_script ${progname%.*}_script_run_at_${start_time}.R

