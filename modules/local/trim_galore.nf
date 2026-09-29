process TRIM_GALORE {
    tag "$meta.name"
    container 'nfcore/slamseq:1.0.0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("TrimGalore/${meta.name}_trimmed.fq.gz"), emit: reads
    path "TrimGalore/*.txt",         emit: report
    path "TrimGalore/*.{zip,html}",  emit: fastqc

    script:
    """
    mkdir -p TrimGalore
    trim_galore \\
        $reads \\
        --stringency 3 \\
        --fastqc \\
        --cores $task.cpus \\
        --output_dir TrimGalore \\
        --basename ${meta.name}
    """
}
