process GTF2BED {
    tag "$gtf"
    container 'nfcore/slamseq:1.0.0'

    input:
    path gtf

    output:
    path "*.bed", emit: bed

    script:
    """
    gtf2bed.py $gtf | sort -k1,1 -k2,2n > ${gtf.baseName}.3utr.bed
    """
}
