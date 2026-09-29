process DESEQ2 {
    label 'slamdunk_process'
    container 'nfcore/slamseq:1.0.0'

    publishDir path: "${params.outdir}/deseq2", mode: 'copy', overwrite: 'true'

    input:
    path conditions
    tuple val(group), path("counts/*")

    output:
    path "${group}", optional: true, emit: results

    script:
    """
    deseq2_slamdunk.r -t $group -d $conditions -c counts -p $params.pvalue -O $group
    """
}
