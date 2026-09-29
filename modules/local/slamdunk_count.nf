// Quantify T>C conversions per counting window with `slamdunk count`.
process SLAMDUNK_COUNT {
    tag "${name}"
    label 'slamdunk_process'

    publishDir path: "${params.outdir}/slamdunk/count/utrs", mode: 'copy',
               overwrite: true, pattern: 'count/*.tsv',
               saveAs: { filename -> filename.endsWith('.tsv') ? file(filename).getName() : null }

    input:
    tuple val(name), path(filter), path(snp)
    path bed
    path fasta

    output:
    tuple val(name), path('count/*tsv'), emit: tsv

    script:
    def snpMode = params.vcf ? "-v ${params.vcf}" : '-s . '
    """
    slamdunk count -o count \\
        -r ${fasta} \\
        ${snpMode} \\
        -b ${bed} \\
        -l ${params.read_length} \\
        -c ${params.conversions} \\
        -q ${params.base_quality} \\
        -t ${task.cpus} \\
        ${filter[0]}
    """
}
