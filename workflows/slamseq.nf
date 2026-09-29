//
// nf-core/slamseq main analysis workflow (DSL2)
//
// Orchestrates trimming, slamdunk mapping/filtering/SNP-calling/counting and
// the alleyoop QC + DESeq2 downstream steps. All channel wiring and the
// conditional `quantseq` / `vcf` / `skip_*` logic that used to live in process
// `when:` blocks now lives here at the workflow level.
//

include { CHECK_DESIGN }          from '../modules/local/check_design'
include { TRIM_GALORE }           from '../modules/local/trim_galore'
include { SLAMDUNK_MAP }          from '../modules/local/slamdunk_map'
include { SLAMDUNK_FILTER }       from '../modules/local/slamdunk_filter'
include { SLAMDUNK_SNP }          from '../modules/local/slamdunk_snp'
include { SLAMDUNK_COUNT }        from '../modules/local/slamdunk_count'
include { ALLEYOOP_COLLAPSE }     from '../modules/local/alleyoop_collapse'
include { ALLEYOOP_RATES }        from '../modules/local/alleyoop_rates'
include { ALLEYOOP_UTRRATES }     from '../modules/local/alleyoop_utrrates'
include { ALLEYOOP_TCPERREADPOS } from '../modules/local/alleyoop_tcperreadpos'
include { ALLEYOOP_TCPERUTRPOS }  from '../modules/local/alleyoop_tcperutrpos'
include { ALLEYOOP_SUMMARY }      from '../modules/local/alleyoop_summary'
include { DESEQ2 }                from '../modules/local/deseq2'
include { MULTIQC }               from '../modules/local/multiqc'
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions'
include { OUTPUT_DOCUMENTATION }  from '../modules/local/output_documentation'

workflow SLAMSEQ {
    take:
    ch_input                    // channel: path to the raw design/samplesheet TSV
    ch_fasta                    // value:   genome FASTA
    ch_bed                      // value:   3' UTR counting-window BED
    ch_utr_filter               // value:   multimapper-recovery reference
    ch_multiqc_config           // value:   MultiQC config
    ch_multiqc_custom_config    // channel: optional custom MultiQC config
    ch_output_docs              // value:   output docs markdown
    ch_output_docs_images       // value:   output docs images dir
    ch_workflow_summary         // channel: run-summary YAML fragment for MultiQC

    main:
    // VCF of known SNPs (optional). When provided it bypasses `slamdunk snp`.
    ch_vcf = params.vcf ? channel.fromPath(params.vcf, checkIfExists: true) : channel.empty()

    //
    // Validate and normalise the design file
    //
    CHECK_DESIGN(ch_input)
    ch_design = CHECK_DESIGN.out.design

    // Per-sample raw reads: meta = full design row, plus the reads file
    ch_raw_files = ch_design
        .splitCsv(header: true, sep: '\t')
        .map { row -> tuple(row, file(row.reads, checkIfExists: true)) }

    // Sample -> condition/group mapping used to assemble DESeq2 comparisons
    ch_condition = ch_design
        .splitCsv(header: true, sep: '\t')

    // Pair each sample name with the shared VCF (only relevant when --vcf is set)
    ch_vcf_combine = ch_design
        .splitCsv(header: true, sep: '\t')
        .map { row -> row.name }
        .combine(ch_vcf)

    //
    // STEP 1 - Adapter/quality trimming with Trim Galore!
    //
    if (params.skip_trimming) {
        ch_trimmed     = ch_raw_files
        ch_trim_qc     = channel.empty()
        ch_trim_fastqc = channel.empty()
    }
    else {
        TRIM_GALORE(ch_raw_files)
        ch_trimmed     = TRIM_GALORE.out.reads
        ch_trim_qc     = TRIM_GALORE.out.report
        ch_trim_fastqc = TRIM_GALORE.out.fastqc
    }

    //
    // STEP 2 - Map reads with slamdunk, then re-key channels by sample name
    //
    SLAMDUNK_MAP(ch_trimmed, ch_fasta)
    ch_map = SLAMDUNK_MAP.out.bam.map { meta, bam -> tuple(meta.name, bam) }

    //
    // STEP 3 - Filter alignments
    //
    SLAMDUNK_FILTER(ch_map, ch_utr_filter)
    ch_filter = SLAMDUNK_FILTER.out.bam

    //
    // STEP 4 - Call T>C SNPs (skipped when a VCF is supplied or in quantseq mode)
    //
    if (!params.vcf && !params.quantseq) {
        SLAMDUNK_SNP(ch_filter, ch_fasta)
        ch_snp = SLAMDUNK_SNP.out.vcf
    }
    else {
        ch_snp = channel.empty()
    }

    // The SNP source for downstream counting is either the called SNPs or the
    // per-sample known VCF.
    ch_vcf_comb = ch_snp.mix(ch_vcf_combine)

    // Join filtered BAMs with their SNP/VCF file on the sample name key
    ch_count_input = ch_filter.join(ch_vcf_comb)

    //
    // STEPS 5-10 - Counting + alleyoop rate/position QC (all conversion-aware,
    // so skipped entirely in quantseq mode)
    //
    ch_rates          = channel.empty()
    ch_utrrates       = channel.empty()
    ch_tcperreadpos   = channel.empty()
    ch_tcperutrpos    = channel.empty()
    ch_count_alleyoop = channel.empty()
    ch_collapse       = channel.empty()

    if (!params.quantseq) {
        SLAMDUNK_COUNT(ch_count_input, ch_bed, ch_fasta)
        ch_count_alleyoop = SLAMDUNK_COUNT.out.tsv

        ALLEYOOP_COLLAPSE(SLAMDUNK_COUNT.out.tsv)
        ch_collapse = ALLEYOOP_COLLAPSE.out.csv

        ALLEYOOP_RATES(ch_count_input, ch_fasta)
        ch_rates = ALLEYOOP_RATES.out.csv

        ALLEYOOP_UTRRATES(ch_count_input, ch_fasta, ch_bed)
        ch_utrrates = ALLEYOOP_UTRRATES.out.csv

        ALLEYOOP_TCPERREADPOS(ch_count_input, ch_fasta)
        ch_tcperreadpos = ALLEYOOP_TCPERREADPOS.out.csv

        ALLEYOOP_TCPERUTRPOS(ch_count_input, ch_fasta, ch_bed)
        ch_tcperutrpos = ALLEYOOP_TCPERUTRPOS.out.csv
    }

    //
    // STEP 11 - Aggregate filter + count summaries
    //
    ch_filter_summary = ch_filter
        .flatten()
        .filter(~/.*bam$/)
        .collect()

    ch_count_summary = ch_count_alleyoop
        .collect()
        .flatten()
        .filter(~/.*tsv$/)
        .collect()

    ALLEYOOP_SUMMARY(ch_filter_summary, ch_count_summary.ifEmpty([]))
    ch_summary = ALLEYOOP_SUMMARY.out.summary

    //
    // STEP 12 - DESeq2 differential T>C conversion analysis
    //
    ch_deseq2_input = ch_condition
        .map { row -> tuple(row.name, row.group) }
        .join(ch_collapse)
        .map { it -> tuple(it[1], it[2]) }
        .groupTuple()

    if (!params.quantseq && !params.skip_deseq2) {
        DESEQ2(ch_design.collect(), ch_deseq2_input)
    }

    //
    // Software versions
    //
    GET_SOFTWARE_VERSIONS()

    //
    // STEP 13 - MultiQC
    //
    MULTIQC(
        ch_multiqc_config,
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_rates.collect().ifEmpty([]),
        ch_utrrates.collect().ifEmpty([]),
        ch_tcperreadpos.collect().ifEmpty([]),
        ch_tcperutrpos.collect().ifEmpty([]),
        ch_summary,
        ch_trim_qc.collect().ifEmpty([]),
        ch_trim_fastqc.collect().ifEmpty([]),
        GET_SOFTWARE_VERSIONS.out.yaml.collect(),
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'),
    )

    //
    // STEP 14 - Output description HTML
    //
    OUTPUT_DOCUMENTATION(ch_output_docs, ch_output_docs_images)

    emit:
    MULTIQC.out.report
}
