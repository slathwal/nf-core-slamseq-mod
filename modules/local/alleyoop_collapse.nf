process ALLEYOOP_COLLAPSE {
    tag "$name"
    label 'slamdunk_process'
    container 'nfcore/slamseq:1.0.0'

    publishDir path: "${params.outdir}/slamdunk/count/genes", mode: 'copy',
               overwrite: 'true', pattern: "collapse/*.csv",
               saveAs: { fn -> fn.endsWith(".csv") ? file(fn).getName() : fn }

    input:
    tuple val(name), path(count)

    output:
    tuple val(name), path("collapse/*csv"), emit: csv

    script:
    """
    alleyoop collapse \\
        -o collapse \\
        -t $task.cpus \\
        $count
    sed -i "1i# name:${name}" collapse/*csv
    """
}
