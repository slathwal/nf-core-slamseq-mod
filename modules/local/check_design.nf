process CHECK_DESIGN {
    tag "$design"
    container 'nfcore/slamseq:1.0.0'

    input:
    path design

    output:
    path "*.txt", emit: design

    script:
    """
    check_design.py $design nfcore_slamseq_design.txt
    """
}
