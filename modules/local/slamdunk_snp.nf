process SLAMDUNK_SNP {
    tag "$name"
    container 'nfcore/slamseq:1.0.0'

    publishDir path: "${params.outdir}/slamdunk/vcf", mode: 'copy',
               overwrite: 'true', pattern: "snp/*vcf",
               saveAs: { fn -> fn.endsWith(".vcf") ? file(fn).getName() : fn }

    input:
    tuple val(name), path(filter)
    path fasta

    output:
    tuple val(name), path("snp/*vcf"), emit: vcf

    script:
    """
    slamdunk snp \\
        -o snp \\
        -r $fasta \\
        -c $params.min_coverage \\
        -f $params.var_fraction \\
        -t $task.cpus \\
        ${filter[0]}
    """
}
