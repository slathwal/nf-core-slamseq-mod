process MULTIQC {
    container 'nfcore/slamseq:1.0.0'

    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path multiqc_config
    path mqc_custom_config
    path "rates/*"
    path "utrrates/*"
    path "tcperreadpos/*"
    path "tcperutrpos/*"
    path summary
    path "TrimGalore/*"
    path "TrimGalore/*"
    path "software_versions/*"
    path workflow_summary

    output:
    path "*multiqc_report.html", emit: report
    path "*_data"
    path "multiqc_plots"

    script:
    def custom_runName = params.name ? "${params.name}" : ''
    def rtitle = custom_runName ? "--title \"$custom_runName\"" : ''
    def rfilename = custom_runName ? "--filename " + custom_runName.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report" : ''
    def custom_config_file = params.multiqc_config ? "--config $mqc_custom_config" : ''
    """
    multiqc -m fastqc -m cutadapt -m slamdunk -f $rtitle $rfilename $custom_config_file .
    """
}
