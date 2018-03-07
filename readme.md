######################################################
# Spatially varying cis-regulatory divergence in     #
# Drosophila embryos elucidates cis-regulatory logic #
######################################################
_Peter A. Combs and Hunter B. Fraser_

_Department of Biology, Stanford University_

This repository contains the analysis code for Combs and Fraser 2017 ([bioRxiv
preprint](http://www.biorxiv.org/content/early/2017/08/10/175059); currently
submitted for review). Raw and processed data files available from the [Gene
Expression Omnibus](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE102233).

Very briefly, the data analyses in these scripts do two things:

1. Process RNA-seq data from cryosliced D. melanogaster x simulans hybrid
   embryos. We are looking for genes with spatially varying allele-specific
expression (svASE) is different in one part of the embryo compared to the
other.

2. Perform modeling of the cis-regulatory input functions of genes using a
   modeling approach inspired in large part by Ilsley, et al (2013). Using
genome alignments and motif searches, we can then make inferences about which
cis-regulatory changes actually produced the spatially varying ASE that we
observed in part 1.

Almost all of the code is written in either Python 3 or
[Snakemake](http://snakemake.readthedocs.io/en/stable/).  Known dependencies
include:

* SRA Tools
* Snakemake
* Bowtie2 (Reference gDNA alignment)
* STAR (RNA-seq alignment)
* Cufflinks (RNA-seq quantification)
* Bedtools
* Samtools
* Various python modules
	- pysam
	- progressbar
	- numpy/scipy/pandas/matplotlib
	- svgwrite
	- pyemd
	- BioPython
	- statsmodels


####
# RNA-seq and finding svASE
###

You should be able to go from raw reads to summary data tables by doing: 

    Snakemake

Though you probably want to run this on a pretty high-powered machine---or,
ideally, a compute cluster.



###############################
# NOTES ON FRASER LAB SCRIPTS #
###############################

Last updated 2015.03.27 by Carlo


BED2FASTA.pl
------------

	This script takes an annotation file in BED format as well as a genome in FASTA format and
	outputs a new FASTA file containing the sequences of the annotations (e.g., spliced genes).

	USAGE: perl BED2FASTA.pl --genome <genome.fa> --bed <annotation.bed> --out <annotation.fa> --rev

	Options and formatting are as follows:

	--rev
		If this option is specified, reverse transcribe genes on the negative strand so that 
		their sequence is 5' - 3'. 
	
	--help or --h
		Print this text.
		

ConcatenateTables.pl
--------------------

	This script will concatenate any number of tab-delimited tables based on a list of common 
	identifiers. Tables that do not contain the identifier will have \'NA\'s in place of the
	missing cells. 

	USAGE: perl ConcatenateTables.pl <LIST> <0-based search column> <OUTFILE> <TABLE 1> <TABLE 2> ... <TABLE N>

	The <LIST> should contain the identifiers, each on a separate line. The <0-based search 
	column>	tells the script in which column in each table to look for the identifiers (usually
	the first, or 0). After specifying the <OUTFILE>, each table should be separated by a 
	space. They will be concatenated in the order specified.
	
	--help or --h
		Print this text.


CountFASTANucs.py
-----------------

	Counts the number of each nucleotide in a FASTA file and prints the result. By specifying 
	-e/--each, it prints nucleotide count for each entry in the FASTA file. Note that the 
	script counts the incidence of all characters, including missing (N) and masked (X) 
	nucleotides, but also IUPAC codes.

	USAGE: CountFASTANucs.py -i  [-e] [-h]

	Required arguments::
	  -i , --infile   FASTA file
	  -e, --each      Print count for each entry in FASTA

	Optional arguments::
	  -h, --help      show this help message and exit		


GTF2FASTA.pl
------------

	This script takes an annotation file in GTF format as well as a genome in FASTA format and
	outputs a new FASTA file containing the sequences of the annotations (e.g., spliced genes).

	USAGE: perl GTF2FASTA.pl --genome <genome.fa> --bed <annotation.bed> --out <annotation.fa> --rev

	Options and formatting are as follows:

	--rev
		If this option is specified, reverse transcribe genes on the negative strand so that 
		their sequence is 5' - 3'. 
	
	--help or --h
		Print this text.


PerformRankedSignTest.pl
------------------------

	This script takes a list of genes with ASE values as well as a group of functional 
	categories 	and determines whether any of the functional categories shows significant 
	parental bias in 	directionality by way of a chi-square test. It then permutes 
	gene-category assignments to determine how often such a degree of bias would be observed 
	by chance, producing a category-specific false-discovery rate.

	USAGE: perl PerformRankedSignTest.pl --asetable [GENE ASE VALUES] --funcats [FUNCTIONAL CATEGORIES] --output [OUTPUT FILE] --fraction [#] --min [#] --perms [#]

	Options and formatting are as follows:

	--asetable 
		A tab-delimited file with two columns, the first of which is the gene name and the 
		second is the log2(species 1 allele/species 2 allele) ASE value. i.e.:

		[GENE]	[LOG2 ASE]

	--funcats
		A tab-delimited list of genes and the functional categories in which they belong. The 
		genes must be in the first column and the functional categories in the second. Genes 
		that belong	to multiple categories should separate categories by |. i.e.:

		[GENE]	[FUNCAT 1]|[FUNCAT 2]|[FUNCAT 3]

	--output
		The tab-delimited file where test values are written with the following columns:
		
		CATEGORY		The functional category
		SP1_BIASED		Number of genes showing species 1 bias (i.e., positive Log2(ASE) values)
		SP2_BIASED		Number of genes showing species 1 bias (i.e., negative Log2(ASE) values)
		SP1_EXPECTED		Number of expected genes showing sp1 bias given the proportion of sp1 biased genes among all genes
		SP2_EXPECTED		Number of expected genes showing sp2 bias given the proportion of sp2 biased genes among all genes
		CHI_SQ			Chi-square value
		FDR			How often (1/#perms) is an equal or higher chi-square value observed among permuted data	
		SP1_GENES		Species 1 biased genes, seperated by |
		SP2_GENES		Species 2 biased genes, seperated by |

	--fraction [Default 1]
		Analyze only the top X fraction (e.g., 0.25) most biased genes from each species. 
		Allows you to look for enrichment of direction bias in tails of the ASE distribution. 
		By default, the script uses all genes.

	--min	[Default 10]
		The minimum number of genes that a functional category must posess to attempt the test. 
		Due to multiple testing, categories with fewer than ~10 genes typically can't acheive 
		significance.
		
	--perms [Default 1000]
		The number of permutations to run for the purpose of determining the category-specific 
		FDR.
	
	--help or --h
		Print this text.

		
ASE PIPELINE
------------

	Scripts: MaskReferencefromBED.pl, CountSNPASE.py, GetGeneASE.py

	Required software installed in PATH:
		samtools
		STAR (for mapping, but can use others)

	Pipeline Flow
	-------------


	1. 	First generate a FASTA formatted file containing the genome where each SNP position has
		been masked by 'N'. An existing genome file can be masked using the 
		MaskReferencefromBED.pl script:
	   	
		usage: MaskReferencefromBED.pl <SNP BED FILE> <GENOME FASTA FILE> <MASKED OUTPUT FASTA>
	
		A list of SNPs in BED format must be supplied as follows:
   
		CHR \t 0-POSITION \t 1-POSITION \t REF|ALT
   
		e.g.
   
		chr02	1242	1243	A|G
	

	2. 	The pipeline requires that reads mapped to the masked genome be supplied in SAM or BAM
		format. Assuming that reads will be mapped with STAR 
		(http://bioinformatics.oxfordjournals.org/content/29/1/15): The masked reference must 
		be used to create a STAR index. STAR's efficiency at mapping spliced transcripts is 
		strongly aided by supplying an annotation file in GTF format. The command to generate a
		STAR index is:
	   
		STAR --runThreadN <NUMBER OF CORES> --runMode genomeGenerate --genomeDir <LOCATION FOR INDEX OUTPUT> --genomeFastaFiles <FIXED MASKED GENOME>.fa --sjdbGTFfile  <ANNOTATION>.gtf --sjdbOverhang <READ LENGTH - 1>
	   

	3. 	Now map the FASTQ files to the genome using STAR with the following flags. It is 
		critical that SAM/BAM files contain the MD flag for the pipeline to identify SNPs. 
		Also, because of the increased incidence of errors in the first 6 bp of reads, we trim 
		them off.
	   
	   	STAR --runThreadN <NUMBER OF CORES> --genomeDir <LOCATION OF INDEX> --outFilterMultimapNmax 1 --outFileNamePrefix <PREFIX FOR OUTPUT> --outSAMtype BAM SortedByCoordinate --outSAMattributes MD NH --clip5pNbases 6
	   

	4. 	Next, we must remove duplicate reads from the mapped output. If we use the the samtools
		or the PICARD tools, we'll create a slight reference allele bias, therefore we should 
		use the XXXX program in the WASP package 
		(see: http://biorxiv.org/content/early/2014/11/07/011221)
	   	
	   	
	5.	The duplicate-removed BAM file then needs to be sorted by mate-pair name rather than 
		coordinates:
		
		samtools sort -n [DUPLICATES REMOVED].bam [SORTED PREFIX]
		
	
	6.	Now we can count reads overlapping each SNP. The CountSNPASE.py script does this:
	
		usage: CountSNPASE.py -m mode -s <BED> -r <[S/B]AM> [-p] [-b] [-t] [-n] [-h] [-j] [-w] [-k] [-f]

		Required arguments:
		  -m mode, --mode mode  Operation mode (default: None)
		  -s <BED>, --snps <BED>
								SNP BED file (default: None)
		  -r <[S/B]AM>, --reads <[S/B]AM>
								Mapped reads file [sam or bam] (default: None)

		Universal optional arguments:
		  -p , --prefix         Prefix for temp files and output (default: TEST)
		  -b, --bam             Mapped read file type is bam (auto-detected if *.bam)
								(default: False)
		  -t, --single          Mapped reads are single-end (default: False)
		  -n, --noclean         Do not delete intermediate files (for debuging)
								(default: False)
		  -h, --help            show this help message and exit

		Multi(plex) mode arguments:
		  -j , --jobs           Divide into # of jobs (default: 100)
		  -w , --walltime       Walltime for each job (default: 3:00:00)
		  -k , --mem            Memory for each job (default: 5000MB)

		Single mode arguments:
		  -f , --suffix         Suffix for multiplexing [set automatically] (default:
								)

		Detailed description of inputs/outputs follows:

		-s/--snps 
			A tab-delimited BED file with positions of masked SNPs of interest as follows:

			[CHR]	[0 POSITION]	[1 POSITION]

			Additional columns are ignored.

		-r/--reads
			A SAM or BAM file containing all of the reads masked to the masked genome. The file
			shound have all duplicates removed and MUST be sorted by read name 
			(i.e. samtools sort -n ). 

		-m/--mode
			The script can be run in two modes. In 'single' mode, the entire SNP counting is 
			performed locally. In 'multi' mode, the read file will be split up by the number of
			specified jobs on the cluster. This is much faster for large SAM/BAM files.
	
		OUTPUT:

		The output of the script is a tab-delimited text file, [PREFIX]_SNP_COUNTS.txt, which 
		contains the following columns:

		CHR		Chromosome where SNP is found
		POSITION	1-based position of SNP
		POS_A|C|G|T	Count of reads containing A|C|G|T bases at the SNP position on the POSITIVE strand
		NEG_A|C|G|T	Count of reads containing A|C|G|T bases at the SNP position on the NEGATIVE strand
		SUM_POS_READS	Sum of all reads assigned to the SNP on POSITIVE strand	
		SUM_NEG_READS	Sum of all reads assigned to the SNP on NEGATIVE strand	
		SUM_READS	Sum of all reads assigned to the SNP
	
	
	7. Once we've determined the counts at individual SNPs, we can then obtain the gene/
	   transcript-level counts with GetGeneASE.py:
	   
		usage: GetGeneASE.py -c  -p  -g  -o  [-w] [-i] [-t] [-m MIN] [-s] [-h]

		This script takes the output of CountSNPASE.py and generates gene level ASE counts.

		Required arguments::
		  -c , --snpcounts      SNP-level ASE counts from CountSNPASE.py (default:
								None)
		  -p , --phasedsnps     BED file of phased SNPs (default: None)
		  -g , --gff            GFF/GTF formatted annotation file (default: None)
		  -o , --outfile        Gene-level ASE counts output (default: None)

		Optional arguments::
		  -w, --writephasedsnps
								Write a phased SNP-level ASE output file
								[OUTFILE].snps.txt (default: False)
		  -i , --identifier     ID attribute in information column (default: gene_id)
		  -t , --type           Annotation feature type (default: exon)
		  -m MIN, --min MIN     Min reads to calculate proportion ref/alt biased
								(default: 10)
		  -s, --stranded        Data are stranded? [Default: False] (default: False)
		  -h, --help            Show this help message and exit

		NOTE:	SNPs that overlap multiple features on the same strand (or counting from 
				unstranded libraries) will be counted in EVERY feature that they overlap. It is
				important to filter the annotation to count features of interest!  

		Detailed description of inputs/outputs follows:

		-p/--phasedsnps 
			A tab-delimited BED file with positions of masked SNPs of interest as follows:

			[CHR]	[0 POSITION]	[1 POSITION]	[REF|ALT]

			The fourth column MUST contain the phased SNPs alleles. 

		-g/--gff
			The script accepts both GTF and GFF annotation files. This should be combined with
			the -i/--identifier option specifying the identifier in the info column (column 9) 
			that will be used for grouping counts. For example, in a GTF 'gene_id' will group
			counts by gene with 'transcript_id' with group counts by transcript. In addition,
			the -t/--type option sets the feature type (column 3) from which to pull features
			typically you'd want to count from 'exon', but many annotations may use non-
			standard terms.

		-m/--min
			This sets the minimum # of reads required to include a SNP in the calculation of 
			the fraction of SNPs agreeing in allelic direction.

		-w/--writephasedsnps
			If this is specified, then the program will output an additional output file named
			[OUTFILE].snp.txt with phased SNP-level ASE calls. This can be useful for checking
			SNP consistency across samples. See below for a description of the output.

		-s/--stranded
			If the data come from a stranded library prep, then this option will only count 
			reads mapped to the corresponding strand.
	
		OUTPUT:

		The output of the script is a tab-delimited text file set by -o/--outfile, which 
		contains the following columns:

		FEATURE 		Name of the counted feature	
		CHROMOSOME 		Chromosome where feature is found
		ORIENTATION 		Orientation of feature (+/-)
		START-STOP 		Ultimate 5' and 3' 1-based start and stop positions
		REFERENCE_COUNTS 	Total reference allele counts across SNPS (or first allele in the REF|ALT phasing)
		ALT_COUNTS 		Total alternate allele counts across SNPs (or second allele in the REF|ALT phasing)
		TOTAL_SNPS 		The total number of SNPs overlapped by the feature 
		REF_BIASED 		Number of REF biased SNPs passing the -m/--min threshold
		ALT_BIASED 		Number of ALT biased SNPs passing the -m/--min threshold
		REF-ALT_RATIO 		The proportion of SNPs agreeing in direction (0.5 - 1)
		SNPS 			A list of all SNPs overlapped by the feature separated by ';' and of the format:

			[1-based position],[REF_ALLELE]|[ALT_ALLELE],[REF_COUNTS]|[ALT_COUNTS];

		If the -w/--writephasedsnps option has been set, it will produce a tab-delimited table 
		with the following columns:

		CHROMOSOME 		Chromosome where SNP is found
		POSITION 		1-based position
		FEATURE 		Feature in which SNP is found
		ORIENTATION 		Orientation of feature (if stranded only reads on this strand are counted)
		REFERENCE_ALLELE 	Reference base
		ALTERNATE_ALLELE 	Alternate base
		REF_COUNTS 		Reference base counts
		ALT_COUNTS 		Alternate base counts
	
