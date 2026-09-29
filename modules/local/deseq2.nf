// Differential expression on gene-collapsed counts with DESeq2.
process DESEQ2 {
    label 'slamdunk_process'

    publishDir path: "${params.outdir}/deseq2", mode: 'copy', overwrite: true

    input:
    path conditions
    tuple val(group), path('counts/*')

    output:
    path "${group}", emit: results, optional: true

    script:
    """
    deseq2_slamdunk.r -t ${group} -d ${conditions} -c counts -p ${params.pvalue} -O ${group}
    """
}
