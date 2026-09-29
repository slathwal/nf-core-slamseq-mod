//
// Resolve and prepare reference files: uncompress the FASTA if needed and
// build the 3' UTR BED from a GTF when no BED is provided directly.
//
include { GUNZIP_FASTA } from '../../modules/local/gunzip_fasta'
include { GTF2BED      } from '../../modules/local/gtf2bed'

workflow PREPARE_GENOME {
    main:
    // ----------------------------------------------------------------------
    // Reference FASTA (uncompress when gzipped) -> reusable value channel
    // ----------------------------------------------------------------------
    def fasta_ref = params.fasta ?: (params.genome && params.genomes ? params.genomes[params.genome].fasta : false)
    if (!fasta_ref) {
        error 'Fasta file not specified!'
    }

    ch_fasta = channel.empty()
    if (fasta_ref.toString().endsWith('.gz')) {
        GUNZIP_FASTA(channel.fromPath(fasta_ref, checkIfExists: true))
        ch_fasta = GUNZIP_FASTA.out.fasta.first()
    }
    else {
        ch_fasta = channel.fromPath(fasta_ref, checkIfExists: true).first()
    }

    // ----------------------------------------------------------------------
    // 3' UTR counting-window BED (derive from GTF when not supplied)
    // ----------------------------------------------------------------------
    ch_bed = channel.empty()
    if (params.bed) {
        ch_bed = channel.fromPath(params.bed, checkIfExists: true).first()
    }
    else {
        def gtf = params.genome && params.genomes ? params.genomes[params.genome].gtf : false
        if (!gtf) {
            error 'Bed file not specified!'
        }
        GTF2BED(channel.fromPath(gtf, checkIfExists: true))
        ch_bed = GTF2BED.out.bed.first()
    }

    // ----------------------------------------------------------------------
    // BED used by the filter step: multimapper-recovery mapping file if given,
    // otherwise the counting-window BED.
    // ----------------------------------------------------------------------
    ch_filter_bed = params.mapping
        ? channel.fromPath(params.mapping, checkIfExists: true).first()
        : ch_bed

    emit:
    fasta      = ch_fasta
    bed        = ch_bed
    filter_bed = ch_filter_bed
}
