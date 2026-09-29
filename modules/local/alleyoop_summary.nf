process ALLEYOOP_SUMMARY {
    container 'nfcore/slamseq:1.0.0'

    input:
    path "filter/*"
    path "count/*"

    output:
    path "summary*.txt", emit: summary

    script:
    def countFolderFlag = !params.quantseq ? "-t ./count" : ""
    """
    alleyoop summary \\
        -o summary.txt \\
        $countFolderFlag \\
        ./filter/*bam
    """
}
