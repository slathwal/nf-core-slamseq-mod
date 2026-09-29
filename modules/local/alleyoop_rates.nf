process ALLEYOOP_RATES {
    tag "$name"
    label 'slamdunk_process'
    container 'nfcore/slamseq:1.0.0'

    input:
    tuple val(name), path(filter), path(snp)
    path fasta

    output:
    path "rates/*csv", emit: csv

    script:
    """
    alleyoop rates \\
        -o rates \\
        -r $fasta \\
        -mq $params.base_quality \\
        -t $task.cpus \\
        ${filter[0]}
    """
}
