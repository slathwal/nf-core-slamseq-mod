process GET_SOFTWARE_VERSIONS {
    container 'nfcore/slamseq:1.0.0'

    publishDir "${params.outdir}/pipeline_info", mode: 'copy',
        saveAs: { filename ->
                      if (filename.indexOf(".csv") > 0) filename
                      else null
                }

    output:
    path 'software_versions_mqc.yaml', emit: yaml
    path "software_versions.csv"

    script:
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    fastqc --version > v_fastqc.txt
    trim_galore --version > v_trimgalore.txt
    slamdunk --version > v_slamdunk.txt
    echo \$(R --version 2>&1) > v_R.txt
    R -e 'packageVersion("DESeq2")' | grep "\\[1\\]" > v_DESeq2.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py &> software_versions_mqc.yaml
    """
}
