// Map trimmed reads to the reference with `slamdunk map`.
process SLAMDUNK_MAP {
    tag "${meta.name}"

    input:
    tuple val(meta), path(fastq)
    path fasta

    output:
    tuple val(meta.name), path('map/*bam'), emit: bam

    script:
    def quantseq = params.quantseq ? '-q' : ''
    def endtoend = params.endtoend ? '-e' : ''
    """
    slamdunk map \\
        -r ${fasta} \\
        -o map \\
        -5 ${params.trim5} \\
        -n 100 \\
        -a ${params.polyA} \\
        -t ${task.cpus} \\
        --sampleName ${meta.name} \\
        --sampleType ${meta.type} \\
        --sampleTime ${meta.time} \\
        --skip-sam \\
        ${quantseq} \\
        ${endtoend} \\
        ${fastq}
    """
}
