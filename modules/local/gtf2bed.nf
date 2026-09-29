// Convert a GTF annotation into a sorted 3' UTR BED file used for counting windows.
process GTF2BED {
    tag "${gtf}"

    input:
    path gtf

    output:
    path '*.bed', emit: bed

    script:
    """
    gtf2bed.py ${gtf} | sort -k1,1 -k2,2n > ${gtf.baseName}.3utr.bed
    """
}
