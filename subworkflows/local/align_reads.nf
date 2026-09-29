//
// Read preprocessing and alignment: optional Trim Galore! trimming, then
// `slamdunk map` and `slamdunk filter`.
//
include { TRIM            } from '../../modules/local/trim'
include { SLAMDUNK_MAP    } from '../../modules/local/slamdunk_map'
include { SLAMDUNK_FILTER } from '../../modules/local/slamdunk_filter'

workflow ALIGN_READS {
    take:
    ch_reads       // channel: [ meta, reads ]
    ch_fasta       // channel: reference FASTA (value)
    ch_filter_bed  // channel: BED used for multimapper recovery (value)

    main:
    if (params.skip_trimming) {
        ch_trimmed      = ch_reads
        ch_trim_qc      = channel.empty()
        ch_trim_fastqc  = channel.empty()
    }
    else {
        TRIM(ch_reads)
        ch_trimmed     = TRIM.out.reads
        ch_trim_qc     = TRIM.out.qc
        ch_trim_fastqc = TRIM.out.fastqc
    }

    SLAMDUNK_MAP(ch_trimmed, ch_fasta)
    SLAMDUNK_FILTER(SLAMDUNK_MAP.out.bam, ch_filter_bed)

    emit:
    filter_bam  = SLAMDUNK_FILTER.out.bam   // channel: [ name, [bam, bai] ]
    trim_qc     = ch_trim_qc
    trim_fastqc = ch_trim_fastqc
}
