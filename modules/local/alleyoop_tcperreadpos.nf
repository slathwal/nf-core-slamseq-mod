// Compute T>C conversions per read position with `alleyoop tcperreadpos`.
process ALLEYOOP_TCPERREADPOS {
    tag "${name}"
    label 'slamdunk_process'

    input:
    tuple val(name), path(filter), path(snp)
    path fasta

    output:
    path 'tcperreadpos/*csv', emit: csv

    script:
    def snpMode = params.vcf ? "-v ${params.vcf}" : '-s . '
    """
    alleyoop tcperreadpos \\
        -o tcperreadpos \\
        -r ${fasta} \\
        ${snpMode} \\
        -mq ${params.base_quality} \\
        -l ${params.read_length} \\
        -t ${task.cpus} \\
        ${filter[0]}
    """
}
