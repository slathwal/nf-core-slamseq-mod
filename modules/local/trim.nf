// Adapter/quality trimming with Trim Galore! (plus FastQC) for a single-end sample.
process TRIM {
    tag "${meta.name}"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("TrimGalore/${meta.name}_trimmed.fq.gz"), emit: reads
    path 'TrimGalore/*.txt'          , emit: qc
    path 'TrimGalore/*.{zip,html}'   , emit: fastqc

    script:
    """
    mkdir -p TrimGalore
    trim_galore \\
        ${reads} \\
        --stringency 3 \\
        --fastqc \\
        --cores ${task.cpus} \\
        --output_dir TrimGalore \\
        --basename ${meta.name}
    """
}
