//
// Validate the sample design file and derive the per-sample channels used
// throughout the pipeline.
//
include { CHECK_DESIGN } from '../../modules/local/check_design'

workflow INPUT_CHECK {
    take:
    ch_input   // channel: path to the raw design/samplesheet file
    ch_vcf     // channel: optional genomic-SNP VCF (may be empty)

    main:
    CHECK_DESIGN(ch_input)
    ch_design = CHECK_DESIGN.out.design

    // Per-sample reads: full design row is carried as the meta map.
    ch_reads = ch_design
        .splitCsv(header: true, sep: '\t')
        .map { row -> tuple(row, file(row.reads, checkIfExists: true)) }

    // Sample -> condition group mapping for DESeq2 grouping.
    ch_conditions = ch_design
        .splitCsv(header: true, sep: '\t')
        .map { row -> tuple(row.name, row.group) }

    // Pair every sample name with the (optional) genomic-SNP VCF.
    ch_vcf_combine = ch_design
        .splitCsv(header: true, sep: '\t')
        .map { row -> row.name }
        .combine(ch_vcf)

    emit:
    reads       = ch_reads
    design      = ch_design
    conditions  = ch_conditions
    vcf_combine = ch_vcf_combine
}
