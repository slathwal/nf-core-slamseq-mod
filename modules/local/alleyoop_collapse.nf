// Collapse per-UTR counts to per-gene counts with `alleyoop collapse`.
process ALLEYOOP_COLLAPSE {
    tag "${name}"
    label 'slamdunk_process'

    publishDir path: "${params.outdir}/slamdunk/count/genes", mode: 'copy',
               overwrite: true, pattern: 'collapse/*.csv',
               saveAs: { filename -> filename.endsWith('.csv') ? file(filename).getName() : null }

    input:
    tuple val(name), path(count)

    output:
    tuple val(name), path('collapse/*csv'), emit: csv

    script:
    """
    alleyoop collapse \\
        -o collapse \\
        -t ${task.cpus} \\
        ${count}
    sed -i "1i# name:${name}" collapse/*csv
    """
}
