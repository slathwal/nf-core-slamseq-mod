// Compute T>C conversions per UTR position with `alleyoop tcperutrpos`.
process ALLEYOOP_TCPERUTRPOS {
    tag "${name}"
    label 'slamdunk_process'

    input:
    tuple val(name), path(filter), path(snp)
    path fasta
    path bed

    output:
    path 'tcperutrpos/*csv', emit: csv

    script:
    def snpMode = params.vcf ? "-v ${params.vcf}" : '-s . '
    """
    alleyoop tcperutrpos \\
        -o tcperutrpos \\
        -r ${fasta} \\
        -b ${bed} \\
        ${snpMode} \\
        -mq ${params.base_quality} \\
        -l ${params.read_length} \\
        -t ${task.cpus} \\
        ${filter[0]}
    """
}
