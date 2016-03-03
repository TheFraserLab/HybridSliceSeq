# Configuration files for the experiment
RUNCONFIG  = Parameters/RunConfig.cfg
STARCONFIG = Parameters/STAR_params.in

# Other random variables
ANALYSIS_DIR = /godot/peter/hybrids

# Reference FASTA and GFF files from FlyBase
MEL5RELEASE= r5.57_FB2014_03
MELRELEASE = r6.09_FB2016_01
SIMRELEASE = r2.01_FB2016_01
SECRELEASE = r1.3_FB2016_01

MELMAJORVERSION = $(word 1, $(subst ., , $(MELRELEASE)))
MELVERSION = $(word 1, $(subst _FB, ,$(MELRELEASE)))
MELDATE = $(word 2, $(subst _FB, ,$(MELRELEASE)))

SIMMAJORVERSION = $(word 1, $(subst ., , $(SIMRELEASE)))
SIMVERSION = $(word 1, $(subst _FB, ,$(SIMRELEASE)))
SIMDATE = $(word 2, $(subst _FB, ,$(SIMRELEASE)))


SECMAJORVERSION = $(word 1, $(subst ., , $(SECRELEASE)))
SECVERSION = $(word 1, $(subst _FB, ,$(SECRELEASE)))
SECDATE = $(word 2, $(subst _FB, ,$(SECRELEASE)))

PREREQDIR = prereqs
MELFASTA = $(PREREQDIR)/dmel-all-chromosome-$(MELVERSION).fasta
SIMFASTA = $(PREREQDIR)/dsim-all-chromosome-$(SIMVERSION).fasta
SECFASTA = $(PREREQDIR)/dsec-all-chromosome-$(SECVERSION).fasta

REFDIR = Reference

MELFASTA2= $(REFDIR)/dmel_prepend.fasta
SIMFASTA2= $(REFDIR)/dsim_prepend.fasta
SECFASTA2= $(REFDIR)/dsec_prepend.fasta

ORTHOLOGS = $(PREREQDIR)/gene_orthologs_fb_$(MELDATE).tsv

MELGFF   = $(PREREQDIR)/dmel-all-$(MELVERSION).gff
MELGTF   = $(REFDIR)/mel_good.gtf
MELALLGTF   = $(REFDIR)/mel_all.gtf
MELBADGTF   = $(REFDIR)/mel_bad.gtf

SIMGFF   = $(PREREQDIR)/dsim-all-$(SIMVERSION).gff
SIMGTF   = $(REFDIR)/sim_good.gtf
SIMALLGTF= $(REFDIR)/sim_all.gtf
SIMBADGTF= $(REFDIR)/sim_bad.gtf

SECGFF   = $(PREREQDIR)/dsec-all-$(SECVERSION).gff
SECGTF   = $(REFDIR)/sec_good.gtf
SECALLGTF= $(REFDIR)/sec_all.gtf
SECBADGTF= $(REFDIR)/sec_bad.gtf

GENEMAPTABLE = $(PREREQDIR)/gene_map_table_fb_$(MELDATE).tsv


.SECONDARY:


all :  $(REFDIR)/mel_$(MELMAJORVERSION) $(REFDIR)/mel_$(MELVERSION) $(FPKMS)

genomes: Reference/Dmel/Genome $(SIMFASTA2) $(MELFASTA2) $(SECFASTA2)
	echo "Genomes Made"


# Read the per-project make-file
include config.make
include analyze.make

$(ANALYSIS_DIR)/retabulate:
	touch $@

$(ANALYSIS_DIR)/summary.tsv : $(ANALYSIS_DIR)/retabulate MakeSummaryTable.py $(FPKMS) $(RUNCONFIG) | $(ANALYSIS_DIR)
	@echo '============================='
	@echo 'Making summary table'
	@echo '============================='
	./qsubber $(QSUBBER_ARGS)_$(*F) -t 6 \
	python MakeSummaryTable.py \
       --params $(RUNCONFIG) \
	   --strip-low-reads 500000 \
	   --strip-on-unique \
	   --strip-as-nan \
	   --mapped-bamfile assigned_dmelR.bam \
	   --strip-low-map-rate 70 \
	   --map-stats analysis/map_stats.tsv \
	   --filename $(QUANT_FNAME) \
	   --key $(QUANT_KEY) \
	   --column $(QUANT_COL) \
		$(ANALYSIS_DIR) \
		| tee analysis/mst.log

$(ANALYSIS_DIR)/summary_fb.tsv : $(ANALYSIS_DIR)/retabulate MakeSummaryTable.py $(FPKMS) $(RUNCONFIG) | $(ANALYSIS_DIR)
	@echo '============================='
	@echo 'Making summary table'
	@echo '============================='
	./qsubber $(QSUBBER_ARGS)_$(*F) -t 6 \
	python MakeSummaryTable.py \
       --params $(RUNCONFIG) \
	   --strip-low-reads 500000 \
	   --strip-on-unique \
	   --strip-as-nan \
	   --mapped-bamfile assigned_dmelR.bam \
	   --strip-low-map-rate 70 \
	   --map-stats analysis/map_stats.tsv \
	   --filename $(QUANT_FNAME) \
	   --key $(QUANT_KEY) \
	   --column tracking_id \
		$(ANALYSIS_DIR) \
		| tee analysis/mst_fb.log

$(ANALYSIS_DIR)/ase_summary.tsv: $(ANALYSIS_DIR)/retabulate $$(subst genes.fpkm_tracking,melsim_gene_ase.tsv,$$(FPKMS))
	./qsubber $(QSUBBER_ARGS)_$(*F) -t 6 \
	python MakeSummaryTable.py \
			--params Parameters/RunConfig.cfg \
			--filename melsim_gene_ase.tsv \
			--column "REF-ALT_RATIO" \
			--key "FEATURE" \
			--out-basename ase_summary \
			$(ANALYSIS_DIR)

%/genes.fpkm_tracking : %/assigned_dmelR.bam $(MELGTF) $(MELFASTA2) $(MELBADGTF)
	@echo '============================='
	@echo 'Calculating Abundances'
	@echo '============================='
	touch $@
	./qsubber $(QSUBBER_ARGS)_$(*F) -t 4 \
	cufflinks \
		--num-threads 8 \
		--output-dir $(@D) \
		--multi-read-correct \
		--frag-bias-correct $(MELFASTA2) \
		--GTF $(MELGTF) \
		--mask-file $(MELBADGTF) \
		$<

%/assigned_dmelR.bam : %/accepted_hits.bam AssignReads2.py
	samtools view -H $< \
		| grep -Pv 'SN:(?!dmel)' \
		> $(@D)/mel_only.header.sam
	samtools view -H $< \
		| grep -oP 'SN:....' \
		| cut -c 4- \
		| sort -u \
		> $(@D)/species_present
	ns=`wc -l $(@D)/species_present | cut -f 1`
	if [ `wc -l $(@D)/species_present | cut -d ' ' -f 1` -eq "1" ]; then \
		samtools sort $< $(basename $@); \
	else \
		python AssignReads2.py $(@D)/accepted_hits.bam; \
		samtools sort $(@D)/assigned_dmel.bam \
			$(@D)/assigned_dmel_sorted; \
		samtools view $(@D)/assigned_dmel_sorted.bam \
			| cat $(@D)/mel_only.header.sam - \
			| samtools view -bS -o $@ -; \
		rm $(@D)/assigned_dmel_sorted.bam; \
	fi
	samtools index $@

$(MELALLGTF): $(MELGFF) | $(REFDIR)
	gffread $< -C -E -T -o- | \
		awk '{print "dmel_"$$0}' > \
		$@

$(MELGTF): $(MELALLGTF) | $(REFDIR)
	cat $< \
		| grep -vP '(snoRNA|CR[0-9]{4}|Rp[ILS]|mir-|tRNA|unsRNA|snRNA|snmRNA|scaRNA|rRNA|RNA:|mt:|His.*:)' \
		| grep 'gene_id' \
		> $@

$(SIMGTF): $(SIMALLGTF) | $(REFDIR)
	cat $< \
		| grep -vP '(snoRNA|CR[0-9]{4}|Rp[ILS]|mir-|tRNA|unsRNA|snRNA|snmRNA|scaRNA|rRNA|RNA:|mt:|His.*:)' \
		| grep -vP 'dsim_Scf_NODE_(108665)' \
		| grep 'gene_id' \
		> $@

$(SECGTF): $(SECALLGTF) | $(REFDIR)
	cat $< \
		| grep -vP '(snoRNA|CR[0-9]{4}|Rp[ILS]|mir-|tRNA|unsRNA|snRNA|snmRNA|scaRNA|rRNA|RNA:|mt:|His.*:)' \
		| grep 'gene_id' \
		> $@

$(MELBADGTF): $(MELALLGTF) | $(REFDIR)
	cat $< \
		| grep -P '(snoRNA|CR[0-9]{4}|Rp[ILS]|mir-|tRNA|unsRNA|snRNA|snmRNA|scaRNA|rRNA|RNA:|mt:|His.*:)' \
		> $@
$(SIMALLGTF): $(SIMGFF) | $(REFDIR)
	gffread $< -C -E -T -o- | \
		awk '{print "dsim_"$$0}' > \
		$@

$(SIMBADGTF): $(SIMALLGTF) | $(REFDIR)
	cat $< \
		| grep -v 'gene_id' \
		> $@

$(SECALLGTF): $(SECGFF) | $(REFDIR)
	gffread $< -C -E -T -o- | \
		awk '{print "dsec_"$$0}' > \
		$@

$(MELFASTA): $(REFDIR)/mel_$(MELMAJORVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_melanogaster/dmel_$(MELRELEASE)/fasta/dmel-all-chromosome-$(MELVERSION).fasta.gz
	gunzip --force $@.gz

$(SIMFASTA): $(REFDIR)/sim_$(SIMMAJORVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_simulans/dsim_$(SIMRELEASE)/fasta/dsim-all-chromosome-$(SIMVERSION).fasta.gz
	gunzip --force $@.gz

$(SECFASTA): $(REFDIR)/sec_$(SECMAJORVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_sechellia/dsec_$(SECRELEASE)/fasta/dsec-all-chromosome-$(SECVERSION).fasta.gz
	gunzip --force $@.gz
	
$(MELTRANSCRIPTS) : $(REFDIR)/mel_$(MELVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_melanogaster/dmel_$(MELRELEASE)/fasta/dmel-all-transcript-$(MELVERSION).fasta.gz
	gunzip --force $@.gz


$(MELGFF): $(REFDIR)/mel_$(MELVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_melanogaster/dmel_$(MELRELEASE)/gff/dmel-all-$(MELVERSION).gff.gz
	gunzip --force $@.gz

$(SIMGFF): $(REFDIR)/sim_$(SIMVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_simulans/dsim_$(SIMRELEASE)/gff/dsim-all-$(SIMVERSION).gff.gz
	gunzip --force $@.gz

$(SECGFF): $(REFDIR)/sec_$(SECVERSION) | $(REFDIR) $(PREREQDIR)
	wget -O $@.gz ftp://ftp.flybase.net/genomes/Drosophila_sechellia/dsec_$(SECRELEASE)/gff/dsec-all-$(SECVERSION).gff.gz
	gunzip --force $@.gz

$(MELFASTA2): $(MELFASTA) $(REFDIR)/mel_$(MELMAJORVERSION) | $(REFDIR)
	perl -pe 's/>/>dmel_/' $(MELFASTA) > $@

$(SIMFASTA2): $(SIMFASTA) $(REFDIR)/sim_$(SIMMAJORVERSION) | $(REFDIR)
	perl -pe 's/>/>dsim_/' $(SIMFASTA) > $@

$(SECFASTA2): $(SECFASTA) $(REFDIR)/sec_$(SECMAJORVERSION) | $(REFDIR)
	perl -pe 's/>/>dsec_/' $(SECFASTA) > $@
	
$(REFDIR)/Dmel/transcriptome : $(MELGTF) |  $(REFDIR)/Dmel
	tophat --GTF $(MELGTF) \
		--transcriptome-index $@ \
		$(REFDIR)/Dmel
	touch $@


$(ORTHOLOGS) : | $(PREREQDIR)
	wget -O $@.gz -i ftp.flybase.org/releases/FB$(MELDATE)/precomputed_files/genes/gene_orthologs_fb_$(MELDATE).tsv.gz
	gunzip --force $@.gz

$(REFDIR) :
	mkdir $@

$(PREREQDIR):
	mkdir $@

$(ANALYSIS_DIR):
	mkdir $@

##### MEL GENOMES ####
$(REFDIR)/Dmel/Genome : $(REFDIR)/mel_$(MELMAJORVERSION) | $(MELGTF)  $(REFDIR)/Dmel $(MELFASTA2) $(REFDIR)
	rm -rf $(@D)/_tmp
	STAR --runMode genomeGenerate --genomeDir $(REFDIR)/Dmel \
		--outTmpDir $(@D)/_tmp \
		--genomeFastaFiles $(MELFASTA2) \
		--sjdbGTFfile $(MELGTF)

$(REFDIR)/Dmel_unspliced/Genome : $(REFDIR)/mel_$(MELMAJORVERSION) | $(REFDIR)/Dmel_unspliced $(MELFASTA2) $(REFDIR)
	rm -rf $(@D)/_tmp
	STAR --runMode genomeGenerate --genomeDir $(REFDIR)/Dmel_unspliced \
		--outTmpDir $(@D)/_tmp \
		--genomeFastaFiles $(MELFASTA2) \

$(REFDIR)/Dmel : | $(REFDIR)
	mkdir $@

$(REFDIR)/Dmel_unspliced : | $(REFDIR)
	mkdir $@

##### SIM GENOMES ####
$(REFDIR)/Dsim/Genome : $(REFDIR)/sim_$(SIMMAJORVERSION) | $(SIMGTF)  $(REFDIR)/Dsim $(SIMFASTA2) $(REFDIR)
	rm -rf $(@D)/_tmp
	STAR --runMode genomeGenerate --genomeDir $(REFDIR)/Dsim \
		--outTmpDir $(@D)/_tmp \
		--genomeFastaFiles $(SIMFASTA2) \
		--sjdbGTFfile $(SIMGTF)

$(REFDIR)/Dsim_unspliced/Genome : $(REFDIR)/sim_$(SIMMAJORVERSION) | $(REFDIR)/Dsim_unspliced $(SIMFASTA2) $(REFDIR)
	rm -rf $(@D)/_tmp
	STAR --runMode genomeGenerate --genomeDir $(REFDIR)/Dsim_unspliced \
		--outTmpDir $(@D)/_tmp \
		--genomeFastaFiles $(SIMFASTA2) 

$(REFDIR)/Dsim : | $(REFDIR)
	mkdir $@

$(REFDIR)/Dsim_unspliced : | $(REFDIR)
	mkdir $@

##### SEC GENOMES ####
$(REFDIR)/Dsec/Genome : $(REFDIR)/sec_$(SECMAJORVERSION) | $(SECGTF)  $(REFDIR)/Dsec $(SECFASTA2) $(REFDIR)
	rm -rf $(@D)/_tmp
	STAR --runMode genomeGenerate --genomeDir $(REFDIR)/Dsec \
		--outTmpDir $(@D)/_tmp \
		--genomeFastaFiles $(SECFASTA2) \
		--sjdbGTFfile $(SECGTF)

$(REFDIR)/Dsec_unspliced/Genome : $(REFDIR)/sec_$(SECMAJORVERSION) | $(REFDIR)/Dsec_unspliced $(SECFASTA2) $(REFDIR)
	rm -rf $(@D)/_tmp
	STAR --runMode genomeGenerate --genomeDir $(REFDIR)/Dsec_unspliced \
		--outTmpDir $(@D)/_tmp \
		--genomeFastaFiles $(SECFASTA2) 


$(REFDIR)/Dsec : | $(REFDIR)
	mkdir $@

$(REFDIR)/Dsec_unspliced : | $(REFDIR)
	mkdir $@

%/: 
	mkdir $@

$(GENEMAPTABLE):
	wget ftp://ftp.flybase.net/releases/FB$(MELDATE)/precomputed_files/genes/$(notdir $(GENEMAPTABLE)).gz \
		-O $(GENEMAPTABLE).gz
	gunzip --force $(GENEMAPTABLE).gz

%_sorted.bam: %.bam
	samtools sort $< $*_sorted 
	samtools index $@

%.bam.bai: %.bam
	samtools index $@

$(REFDIR)/mel_$(MELVERSION): | $(REFDIR)
	touch $@

$(REFDIR)/mel_$(MELMAJORVERSION): | $(REFDIR)
	touch $@

$(REFDIR)/sim_$(SIMVERSION): | $(REFDIR)
	touch $@

$(REFDIR)/sim_$(SIMMAJORVERSION): | $(REFDIR)
	touch $@

$(REFDIR)/sec_$(SECVERSION): | $(REFDIR)
	touch $@

$(REFDIR)/sec_$(SECMAJORVERSION): | $(REFDIR)
	touch $@


$(REFDIR)/lav: | $(REFDIR)
	mkdir $@

$(REFDIR)/psl: | $(REFDIR)/lav
	mkdir $@

$(REFDIR)/d%_masked/done: $(REFDIR)/d%_masked.fasta
	python faSplitter.py $< $(@D)
	touch $@

%.bwt : %
	bwa index $*
	samtools faidx $*

%.fai : %
	samtools faidx $<

%.1.ebwt: $(basename $(basename %)).fasta
	bowtie-build --offrate 3 $< $(basename $(basename $@))

%.1.bt2: $(basename $(basename %)).fasta
	bowtie2-build --offrate 3 $< $(basename $(basename $@))

%.dict : %.fasta
	picard CreateSequenceDictionary R=$< O=$@

%.dict : %.fa
	picard CreateSequenceDictionary R=$< O=$@

%_transcriptome: %.1.ebwt
	tophat2 --transcriptome-index $@ \
			--GTF $($(call uc,$*)GTF)
			$*


$(REFDIR)/d%_masked.fasta: $(REFDIR)/d%_prepend.fasta
	trfBig $< $@

$(REFDIR)/lav/melsim: $(REFDIR)/dmel_masked/done $(REFDIR)/dsim_masked/done $(REFDIR)/mel_good.gtf $(REFDIR)/sim_good.gtf | $(REFDIR)/lav
	python SubmitAlignments.py mel sim
	touch $@

$(REFDIR)/lav/melsec: $(REFDIR)/dmel_masked/done $(REFDIR)/dsec_masked/done $(REFDIR)/mel_good.gtf $(REFDIR)/sec_good.gtf | $(REFDIR)/lav
	python SubmitAlignments.py mel sec
	touch $@

%.bw : %.bam
	python ChromSizes.py $<
	bamToBed -i $< -bed12 | bed12ToBed6 -i stdin | genomeCoverageBed -bga -i stdin -g $<.chromsizes > $(basename $@).bed
	bedGraphToBigWig $(basename $@).bed $<.chromsizes $@

%.cxb : %.bam
	./qsubber --job-name $(@F)_cuffquant --queue batch --keep-temporary tmp -t 8 \
	cuffquant \
		--output-dir $(*D)/$(*F) \
		--num-thread 8 \
		--multi-read-correct \
		--frag-bias-correct $($(call uc,$(call substr,$(notdir $(*D)),4,6))FASTA2) \
		$($(call uc,$(call substr,$(notdir $(*D)),4,6))GTF) \
		$<
	cp $(*D)/$(*F)/abundances.cxb $@

