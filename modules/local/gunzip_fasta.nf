// Decompress a gzipped reference FASTA into a plain-text FASTA.
process GUNZIP_FASTA {
    tag "${fasta}"

    input:
    path fasta

    output:
    path 'ref.fa', emit: fasta

    script:
    """
    gunzip -c ${fasta} > ref.fa
    """
}
