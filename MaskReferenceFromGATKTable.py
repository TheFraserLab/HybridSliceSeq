#!/usr/bin/python
from __future__ import print_function
import pandas as pd
from argparse import ArgumentParser, FileType
from Bio import SeqIO
from Bio.Seq import MutableSeq
from time import time
from progressbar import ProgressBar

def mask_sites(chrom_sequence, sub_table):
    corrected_sites = 0
    masked_sites = 0
    bed = []
    for i, var in sub_table.iterrows():
        if var['HOM-VAR'] == var['NCALLED'] and len(var['ALT']) == 1:
            chrom_sequence[var.POS-1] = var['ALT']
            corrected_sites += 1
        elif var['HOM-REF'] != var['NCALLED']:
            if ((var['HOM-REF'] == 1) 
                    and (var['HOM-VAR'] == 1)
                    and (len(var['ALT']) == 1)
                    and (len(var['REF'])== 1)):
                bed.append('{}\t{}\t{}\t{}\n'.format(
                    var.CHROM, 
                    var.POS - 1,
                    var.POS,
                    var[reference_column][0]  +"|"+var[alternate_column][0],
                    )
                    )
            for p in range(var.POS-1, var.POS + len(var.REF) - 1):
                chrom_sequence[p] = 'N'
                masked_sites += 1
            
    return chrom_sequence, bed, masked_sites, corrected_sites


tic = time()

parser = ArgumentParser()
parser.add_argument('--emit-bed', '-b', default=None, type=FileType('w'))
parser.add_argument('--threads', '-t', default=1, type=int)
parser.add_argument('--outfasta', type=str)
parser.add_argument('--target-species', '-S', default='sim')
parser.add_argument('fasta_file', type=open)
parser.add_argument('table', type=open)
args = parser.parse_args()

seq_recs = [rec for rec in SeqIO.parse(args.fasta_file, 'fasta')]
sequence = {rec.id: MutableSeq(str(rec.seq)) for rec in seq_recs}
print("Finished Parsing: {}s".format(time() - tic))
tic = time()
joint_vars = pd.read_table(args.table)

reference_column = ''
alternate_column = ''
for column in joint_vars.columns:
    if column.startswith(args.target_species) and column.endswith('.GT'):
        reference_column = column
    elif column.endswith('.GT'):
        alternate_column = column
    if reference_column and alternate_column:
        break
print("Using genotypes:  Reference: {} \tAlternate: {}".format(reference_column, alternate_column))


print("Finished reading in table: {}s".format(time() - tic))

masked_sites = 0
corrected_sites = 0
if args.threads == 1:
    pb = ProgressBar(maxval=len(joint_vars))
    pb.start()
    for i, var in joint_vars.iterrows():
        pb.update(i)
        if var['HOM-VAR'] == var['NCALLED'] and len(var['ALT']) == 1:
            sequence[var.CHROM][var.POS-1] = var['ALT']
            corrected_sites += 1
        elif var['HOM-REF'] != var['NCALLED']:
            if (args.emit_bed 
                    and (var['HOM-REF'] == 1) 
                    and (var['HOM-VAR'] == 1)
                    and (len(var['ALT']) == 1)
                    and (len(var['REF'])== 1)):
                args.emit_bed.write('{}\t{}\t{}\t{}\n'.format(
                    var.CHROM, 
                    var.POS - 1,
                    var.POS,
                    var[reference_column][0]  +"|"+var[alternate_column][0],
                    )
                    )
            for p in range(var.POS-1, var.POS + len(var.REF) - 1):
                sequence[var.CHROM][p] = 'N'
                masked_sites += 1
            
    pb.finish()
    for rec in seq_recs:
        rec.seq = sequence[rec.id]
else:
    from  multiprocessing import Pool
    p = Pool(8)
    groups = joint_vars.groupby('CHROM').groups
    res = p.starmap(mask_sites, 
            [(sequence[rec.id], joint_vars.ix[groups[rec.id]]) 
                for rec in seq_recs 
                if rec.id in groups])
    for rec, (seq, bed, mask, corr) in zip(seq_recs, res):
        rec.seq = seq
        masked_sites += mask
        corrected_sites += corr
        if args.emit_bed:
            args.emit_bed.writelines(bed)



if args.outfasta:
    SeqIO.write(seq_recs, args.outfasta, 'fasta')
print("Corrected sites: {:,}".format(corrected_sites))
print("Masked sites: {:,}".format(masked_sites))
