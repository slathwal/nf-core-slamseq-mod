// Call T>C conversion-masking SNPs from filtered reads with `slamdunk snp`.
process SLAMDUNK_SNP {
    tag "${name}"

    publishDir path: "${params.outdir}/slamdunk/vcf", mode: 'copy',
               overwrite: true, pattern: 'snp/*vcf',
               saveAs: { filename -> filename.endsWith('.vcf') ? file(filename).getName() : null }

    input:
    tuple val(name), path(filter)
    path fasta

    output:
    tuple val(name), path('snp/*vcf'), emit: vcf

    script:
    """
    slamdunk snp \\
        -o snp \\
        -r ${fasta} \\
        -c ${params.min_coverage} \\
        -f ${params.var_fraction} \\
        -t ${task.cpus} \\
        ${filter[0]}
    """
}
