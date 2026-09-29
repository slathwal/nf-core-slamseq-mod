process SLAMDUNK_MAP {
    tag "$meta.name"
    container 'nfcore/slamseq:1.0.0'

    input:
    tuple val(meta), path(fastq)
    path fasta

    output:
    tuple val(meta), path("map/*bam"), emit: bam

    script:
    def quantseq = params.quantseq ? "-q" : ""
    def endtoend = params.endtoend ? "-e" : ""
    """
    slamdunk map \\
        -r $fasta \\
        -o map \\
        -5 $params.trim5 \\
        -n 100 \\
        -a $params.polyA \\
        -t $task.cpus \\
        --sampleName ${meta.name} \\
        --sampleType ${meta.type} \\
        --sampleTime ${meta.time} \\
        --skip-sam \\
        $quantseq \\
        $endtoend \\
        $fastq
    """
}
