// Compute per-UTR conversion rates with `alleyoop utrrates`.
process ALLEYOOP_UTRRATES {
    tag "${name}"
    label 'slamdunk_process'

    input:
    tuple val(name), path(filter), path(snp)
    path fasta
    path bed

    output:
    path 'utrrates/*csv', emit: csv

    script:
    """
    alleyoop utrrates \\
        -o utrrates \\
        -r ${fasta} \\
        -mq ${params.base_quality} \\
        -b ${bed} \\
        -l ${params.read_length} \\
        -t ${task.cpus} \\
        ${filter[0]}
    """
}
