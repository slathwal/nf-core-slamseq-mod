// Aggregate QC across FastQC, Cutadapt and Slamdunk into a MultiQC report.
process MULTIQC {
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path multiqc_config
    path mqc_custom_config
    path 'rates/*'
    path 'utrrates/*'
    path 'tcperreadpos/*'
    path 'tcperutrpos/*'
    path summary
    path 'TrimGalore/*'
    path 'TrimGalore/*'
    path 'software_versions/*'
    path workflow_summary
    val run_name

    output:
    path '*multiqc_report.html', emit: report
    path '*_data'
    path 'multiqc_plots'

    script:
    def rtitle = run_name ? "--title \"${run_name}\"" : ''
    def rfilename = run_name ? '--filename ' + run_name.replaceAll('\\W', '_').replaceAll('_+', '_') + '_multiqc_report' : ''
    def custom_config_file = params.multiqc_config ? "--config ${mqc_custom_config}" : ''
    """
    multiqc -m fastqc -m cutadapt -m slamdunk -f ${rtitle} ${rfilename} ${custom_config_file} .
    """
}
