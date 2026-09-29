process GUNZIP_FASTA {
    tag "$fasta"
    container 'nfcore/slamseq:1.0.0'

    input:
    path fasta

    output:
    path "ref.fa", emit: fasta

    script:
    """
    gunzip -c $fasta > ref.fa
    """
}
