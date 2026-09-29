/*
========================================================================================
    nf-core/slamseq main analysis workflow
========================================================================================
*/

include { PREPARE_GENOME        } from '../subworkflows/local/prepare_genome'
include { INPUT_CHECK           } from '../subworkflows/local/input_check'
include { ALIGN_READS           } from '../subworkflows/local/align_reads'
include { QUANTIFY_CONVERSIONS  } from '../subworkflows/local/quantify_conversions'
include { ALLEYOOP_QC           } from '../subworkflows/local/alleyoop_qc'

include { ALLEYOOP_SUMMARY      } from '../modules/local/alleyoop_summary'
include { DESEQ2                } from '../modules/local/deseq2'
include { MULTIQC               } from '../modules/local/multiqc'
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions'
include { OUTPUT_DOCUMENTATION  } from '../modules/local/output_documentation'

workflow SLAMSEQ {

    // ----------------------------------------------------------------------
    // Input setup
    // ----------------------------------------------------------------------
    ch_input = channel.fromPath(params.input, checkIfExists: true)
    ch_vcf   = params.vcf
        ? channel.fromPath(params.vcf, checkIfExists: true)
        : channel.empty()

    // Resolve reference FASTA + 3' UTR BED (and multimapper BED for filtering).
    PREPARE_GENOME()

    // Validate the design file and derive per-sample channels.
    INPUT_CHECK(ch_input, ch_vcf)

    // ----------------------------------------------------------------------
    // Trim, map and filter reads
    // ----------------------------------------------------------------------
    ALIGN_READS(
        INPUT_CHECK.out.reads,
        PREPARE_GENOME.out.fasta,
        PREPARE_GENOME.out.filter_bed,
    )
    ch_filter_bam = ALIGN_READS.out.filter_bam

    // ----------------------------------------------------------------------
    // Conversion-aware quantification + QC (skipped entirely in quantseq mode)
    // ----------------------------------------------------------------------
    if (!params.quantseq) {
        QUANTIFY_CONVERSIONS(
            ch_filter_bam,
            PREPARE_GENOME.out.fasta,
            PREPARE_GENOME.out.bed,
            INPUT_CHECK.out.vcf_combine,
        )

        ALLEYOOP_QC(
            QUANTIFY_CONVERSIONS.out.results,
            PREPARE_GENOME.out.fasta,
            PREPARE_GENOME.out.bed,
        )

        ch_count_tsv = QUANTIFY_CONVERSIONS.out.count_tsv
        ch_collapse  = QUANTIFY_CONVERSIONS.out.collapse
        ch_rates        = ALLEYOOP_QC.out.rates
        ch_utrrates     = ALLEYOOP_QC.out.utrrates
        ch_tcperreadpos = ALLEYOOP_QC.out.tcperreadpos
        ch_tcperutrpos  = ALLEYOOP_QC.out.tcperutrpos
    }
    else {
        ch_count_tsv    = channel.empty()
        ch_collapse     = channel.empty()
        ch_rates        = channel.empty()
        ch_utrrates     = channel.empty()
        ch_tcperreadpos = channel.empty()
        ch_tcperutrpos  = channel.empty()
    }

    // ----------------------------------------------------------------------
    // Per-run summary statistics (alleyoop summary)
    // ----------------------------------------------------------------------
    ch_summary_bams = ch_filter_bam
        .map { _name, files -> files }
        .flatten()
        .filter { f -> f.name.endsWith('.bam') }
        .collect()

    ch_summary_counts = ch_count_tsv
        .map { _name, tsv -> tsv }
        .flatten()
        .filter { f -> f.name.endsWith('.tsv') }
        .collect()
        .ifEmpty([])

    ALLEYOOP_SUMMARY(ch_summary_bams, ch_summary_counts)

    // ----------------------------------------------------------------------
    // DESeq2 differential expression (grouped by condition)
    // ----------------------------------------------------------------------
    if (!params.quantseq && !params.skip_deseq2) {
        ch_deseq2_input = INPUT_CHECK.out.conditions
            .join(ch_collapse)
            .map { _name, group, csv -> tuple(group, csv) }
            .groupTuple()

        DESEQ2(INPUT_CHECK.out.design.collect(), ch_deseq2_input)
    }

    // ----------------------------------------------------------------------
    // Reporting: software versions, workflow summary, MultiQC, output docs
    // ----------------------------------------------------------------------
    GET_SOFTWARE_VERSIONS()

    def run_name = params.name ?: false
    if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
        run_name = workflow.runName
    }
    ch_workflow_summary = workflow_summary_mqc(run_name)

    ch_multiqc_config = file("${projectDir}/assets/multiqc_config.yaml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config
        ? channel.fromPath(params.multiqc_config, checkIfExists: true)
        : channel.empty()

    MULTIQC(
        ch_multiqc_config,
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_rates.collect().ifEmpty([]),
        ch_utrrates.collect().ifEmpty([]),
        ch_tcperreadpos.collect().ifEmpty([]),
        ch_tcperutrpos.collect().ifEmpty([]),
        ALLEYOOP_SUMMARY.out.txt,
        ALIGN_READS.out.trim_qc.collect().ifEmpty([]),
        ALIGN_READS.out.trim_fastqc.collect().ifEmpty([]),
        GET_SOFTWARE_VERSIONS.out.yaml.collect(),
        ch_workflow_summary,
        run_name,
    )

    ch_output_docs        = file("${projectDir}/docs/output.md", checkIfExists: true)
    ch_output_docs_images = file("${projectDir}/docs/images/", checkIfExists: true)
    OUTPUT_DOCUMENTATION(ch_output_docs, ch_output_docs_images)
}

//
// Build the MultiQC workflow-summary YAML fragment from the run parameters.
//
def workflow_summary_mqc(run_name) {
    def summary = [:]
    summary['Run Name']         = run_name ?: workflow.runName
    summary['Input']            = params.input
    summary['Fasta Ref']        = params.fasta
    summary['Vcf']              = params.vcf
    summary['Trim 5']           = params.trim5
    summary['Poly-A']           = params.polyA
    summary['Multimappers']     = params.multimappers
    summary['Quantseq']         = params.quantseq
    summary['Endtoend']         = params.endtoend
    summary['Minimum coverage'] = params.min_coverage
    summary['Variant fraction'] = params.var_fraction
    summary['Conversions']      = params.conversions
    summary['base_quality']     = params.base_quality
    summary['read_length']      = params.read_length
    summary['P-value']          = params.pvalue
    summary['Skip Trimming']    = params.skip_trimming
    summary['Skip DESeq2']      = params.skip_deseq2
    summary['Output dir']       = params.outdir

    def rows = summary.collect { k, v ->
        "            <dt>${k}</dt><dd><samp>${v != null && v != false ? v : 'N/A'}</samp></dd>"
    }.join('\n')

    return channel.of(
        """
        id: 'nf-core-slamseq-summary'
        description: " - this information is collected when the pipeline is started."
        section_name: 'nf-core/slamseq Workflow Summary'
        section_href: 'https://github.com/nf-core/slamseq'
        plot_type: 'html'
        data: |
            <dl class="dl-horizontal">
${rows}
            </dl>
        """.stripIndent()
    ).collectFile(name: 'workflow_summary_mqc.yaml')
}
