process OUTPUT_DOCUMENTATION {
    container 'nfcore/slamseq:1.0.0'

    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    path output_docs
    path images

    output:
    path "results_description.html"

    script:
    """
    markdown_to_html.py $output_docs -o results_description.html
    """
}
