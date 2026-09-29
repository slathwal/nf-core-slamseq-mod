process SLAMDUNK_COUNT {
    tag "$name"
    label 'slamdunk_process'
    container 'nfcore/slamseq:1.0.0'

    publishDir path: "${params.outdir}/slamdunk/count/utrs", mode: 'copy',
               overwrite: 'true', pattern: "count/*.tsv",
               saveAs: { fn -> fn.endsWith(".tsv") ? file(fn).getName() : fn }

    input:
    tuple val(name), path(filter), path(snp)
    path bed
    path fasta

    output:
    tuple val(name), path("count/*tsv"), emit: tsv

    script:
    def snpMode = params.vcf ? "-v $params.vcf" : "-s . "
    """
    slamdunk count -o count \\
        -r $fasta \\
        $snpMode \\
        -b $bed \\
        -l $params.read_length \\
        -c $params.conversions \\
        -q $params.base_quality \\
        -t $task.cpus \\
        ${filter[0]}
    """
}
