//
// Prepare the reference genome files required by slamdunk/alleyoop.
//
// Resolves three reference channels from the parameters, mirroring the
// reference-handling logic of the original DSL1 pipeline:
//   * fasta       - the genome FASTA (gunzipped on the fly when bgzipped)
//   * bed         - the 3' UTR counting window BED (built from a GTF if absent)
//   * utr_filter  - the multimapper-recovery reference (a --mapping file when
//                   supplied, otherwise the 3' UTR BED)
//

include { GUNZIP_FASTA } from '../../modules/local/gunzip_fasta'
include { GTF2BED }      from '../../modules/local/gtf2bed'

workflow PREPARE_GENOME {
    main:
    // ----------------------------
    // Genome FASTA (resolved from --fasta or the selected iGenomes --genome)
    // ----------------------------
    def genome_fasta = params.genome ? params.genomes[params.genome].fasta ?: false : params.fasta

    if (genome_fasta.toString().endsWith('.gz')) {
        GUNZIP_FASTA(channel.fromPath(genome_fasta, checkIfExists: true))
        ch_fasta = GUNZIP_FASTA.out.fasta.first()
    }
    else {
        ch_fasta = channel.fromPath(genome_fasta, checkIfExists: true).first()
    }

    // ----------------------------
    // 3' UTR counting-window BED
    // ----------------------------
    if (params.bed) {
        ch_bed = channel.fromPath(params.bed, checkIfExists: true).first()
    }
    else {
        def gtf = params.genome ? params.genomes[params.genome].gtf ?: false : false
        GTF2BED(channel.fromPath(gtf, checkIfExists: true))
        ch_bed = GTF2BED.out.bed.first()
    }

    // ----------------------------
    // Multimapper-recovery reference for `slamdunk filter`
    // ----------------------------
    ch_utr_filter = params.mapping
        ? channel.fromPath(params.mapping, checkIfExists: true).first()
        : ch_bed

    emit:
    fasta      = ch_fasta
    bed        = ch_bed
    utr_filter = ch_utr_filter
}
