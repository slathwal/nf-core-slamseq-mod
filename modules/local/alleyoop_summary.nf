// Aggregate filter/count statistics across all samples with `alleyoop summary`.
process ALLEYOOP_SUMMARY {

    input:
    path 'filter/*'
    path 'count/*'

    output:
    path 'summary*.txt', emit: txt

    script:
    def countFolderFlag = !params.quantseq ? '-t ./count' : ''
    """
    alleyoop summary \\
        -o summary.txt \\
        ${countFolderFlag} \\
        ./filter/*bam
    """
}
