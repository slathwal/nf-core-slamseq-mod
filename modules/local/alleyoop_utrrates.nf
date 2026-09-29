process ALLEYOOP_UTRRATES {
    tag "$name"
    label 'slamdunk_process'
    container 'nfcore/slamseq:1.0.0'

    input:
    tuple val(name), path(filter), path(snp)
    path fasta
    path bed

    output:
    path "utrrates/*csv", emit: csv

    script:
    """
    alleyoop utrrates \\
        -o utrrates \\
        -r $fasta \\
        -mq $params.base_quality \\
        -b $bed \\
        -l $params.read_length \\
        -t $task.cpus \\
        ${filter[0]}
    """
}
