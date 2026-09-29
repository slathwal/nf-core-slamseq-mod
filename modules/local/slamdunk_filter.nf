// Filter mapped reads with `slamdunk filter` (optional multimapper recovery via BED).
process SLAMDUNK_FILTER {
    tag "${name}"
    label 'slamdunk_process'

    publishDir path: "${params.outdir}/slamdunk/bam", mode: 'copy',
               overwrite: true, pattern: 'filter/*bam*',
               saveAs: { filename ->
                             if (filename.endsWith('.bam')) file(filename).getName()
                             else if (filename.endsWith('.bai')) file(filename).getName()
                             else null
                       }

    input:
    tuple val(name), path(map)
    path bed

    output:
    tuple val(name), path('filter/*bam*'), emit: bam

    script:
    def multimappers = params.multimappers ? "-b ${bed}" : ''
    """
    slamdunk filter \\
        -o filter \\
        ${multimappers} \\
        -t ${task.cpus} \\
        ${map}
    """
}
