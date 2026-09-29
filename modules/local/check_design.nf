// Validate and reformat the input sample design/samplesheet file.
process CHECK_DESIGN {
    tag "${design}"

    input:
    path design

    output:
    path '*.txt', emit: design

    script:
    """
    check_design.py ${design} nfcore_slamseq_design.txt
    """
}
