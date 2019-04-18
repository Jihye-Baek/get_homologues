## GET_HOMOLOGUES: a versatile software package for pan-genome analysis

This software is maintained by Bruno Contreras-Moreira (bcontreras _at_ eead.csic.es) and Pablo Vinuesa (vinuesa _at_ ccg.unam.mx). 
The original version, **suitable for bacterial genomes**, was described in:

![**Legend.** Main features of GET_HOMOLOGUES.](./pics/summary.jpg)

[Contreras-Moreira B, Vinuesa P (2013) Appl. Environ. Microbiol. 79:7696-7701](http://aem.asm.org/content/79/24/7696.long)

[Vinuesa P, Contreras-Moreira B (2015) Methods in Molecular Biology Volume 1231, 203-232](http://link.springer.com/protocol/10.1007%2F978-1-4939-1720-4_14)

The software was then adapted to the study of **intra-specific eukaryotic pan-genomes** resulting in script GET_HOMOLOGUES-EST, described in:

![**Legend.** Flowchart and features of GET_HOMOLOGUES-EST.](./pics/EST.jpg)

[Contreras-Moreira B, Cantalapiedra CP et al (2017) Front. Plant Sci. 10.3389/fpls.2017.00184](http://journal.frontiersin.org/article/10.3389/fpls.2017.00184/full)

GET_HOMOLOGUES-EST has been tested with genomes and transcriptomes of *Arabidopsis thaliana* and *Hordeum vulgare*, available at [http://floresta.eead.csic.es/plant-pan-genomes](http://floresta.eead.csic.es/plant-pan-genomes). It was also used to produce the *Brachypodium distachyon* pangenome at [https://brachypan.jgi.doe.gov](https://brachypan.jgi.doe.gov).

A [tutorial](http://digital.csic.es/handle/10261/146411) is available, covering typical examples of both GET_HOMOLOGUES and GET_HOMOLOGUES-EST.

A [Docker image](https://hub.docker.com/r/csicunam/get_homologues) is available with GET_HOMOLOGUES 
bundled with [GET_PHYLOMARKERS](https://github.com/vinuesa/get_phylomarkers), ready to use. 
The GET_PHYLOMARKERS [manual](https://vinuesa.github.io/get_phylomarkers/#get_phylomarkers-tutorial) 
explains how to use clusters from with GET_HOMOLOGUES to compute robust multi-gene and pangenome phylogenies.

The code is regularly patched (see [CHANGES.txt](./CHANGES.txt) in each release, <!--and [TODO.txt](./TODO.txt)),-->
and has been used in a variety of studies 
(see citing papers [here](https://scholar.google.es/scholar?start=0&hl=en&as_sdt=2005&cites=5259912818944685430) and 
[here](https://scholar.google.es/scholar?oi=bibs&hl=en&cites=14330917787074873427&as_sdt=5), respectively).

We kindly ask you to report errors or bugs in the program to the authors and to acknowledge the use of the program in scientific publications.

*Funding:* Fundacion ARAID, Consejo Superior de Investigaciones Cientificas, DGAPA-PAPIIT UNAM, CONACyT, FEDER, MINECO, DGA-Obra Social La Caixa.

![logo CSIC](pics/logoCSIC.png) ![logo ARAID](pics/logoARAID.gif) ![logo UNAM](pics/logoUNAM.png)

Installation instructions are summarized on [README.txt](./README.txt) and full documentation is available in two flavours:

|version|HTML|
|-------|----|
|original, for the analysis of bacterial pan-genomes|[manual](http://eead-csic-compbio.github.io/get_homologues/manual/)|
|EST, for the analysis of intra-species eukaryotic pan-genomes, tested on plants|[manual-est](http://eead-csic-compbio.github.io/get_homologues/manual-est/)|

