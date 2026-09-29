//
// Alleyoop conversion-rate QC modules run on the filtered BAM / SNP results.
//
include { ALLEYOOP_RATES        } from '../../modules/local/alleyoop_rates'
include { ALLEYOOP_UTRRATES     } from '../../modules/local/alleyoop_utrrates'
include { ALLEYOOP_TCPERREADPOS } from '../../modules/local/alleyoop_tcperreadpos'
include { ALLEYOOP_TCPERUTRPOS  } from '../../modules/local/alleyoop_tcperutrpos'

workflow ALLEYOOP_QC {
    take:
    ch_results   // channel: [ name, [bam, bai], vcf ]
    ch_fasta     // channel: reference FASTA (value)
    ch_bed       // channel: 3' UTR counting-window BED (value)

    main:
    ALLEYOOP_RATES(ch_results, ch_fasta)
    ALLEYOOP_UTRRATES(ch_results, ch_fasta, ch_bed)
    ALLEYOOP_TCPERREADPOS(ch_results, ch_fasta)
    ALLEYOOP_TCPERUTRPOS(ch_results, ch_fasta, ch_bed)

    emit:
    rates         = ALLEYOOP_RATES.out.csv
    utrrates      = ALLEYOOP_UTRRATES.out.csv
    tcperreadpos  = ALLEYOOP_TCPERREADPOS.out.csv
    tcperutrpos   = ALLEYOOP_TCPERUTRPOS.out.csv
}
