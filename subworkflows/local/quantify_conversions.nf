//
// Nucleotide-conversion aware quantification: SNP calling (unless a genomic
// VCF is supplied), per-UTR counting and gene-level collapsing.
//
include { SLAMDUNK_SNP      } from '../../modules/local/slamdunk_snp'
include { SLAMDUNK_COUNT    } from '../../modules/local/slamdunk_count'
include { ALLEYOOP_COLLAPSE } from '../../modules/local/alleyoop_collapse'

workflow QUANTIFY_CONVERSIONS {
    take:
    ch_filter_bam   // channel: [ name, [bam, bai] ]
    ch_fasta        // channel: reference FASTA (value)
    ch_count_bed    // channel: 3' UTR counting-window BED (value)
    ch_vcf_combine  // channel: [ name, vcf ] when an external VCF is provided

    main:
    // Call T>C-masking SNPs unless the user supplied a genomic-SNP VCF.
    if (params.vcf) {
        ch_snp = channel.empty()
    }
    else {
        SLAMDUNK_SNP(ch_filter_bam, ch_fasta)
        ch_snp = SLAMDUNK_SNP.out.vcf
    }

    // Attach the SNP/VCF for each sample onto its filtered BAM.
    ch_vcf_comb = ch_snp.mix(ch_vcf_combine)
    ch_results  = ch_filter_bam.join(ch_vcf_comb)   // [ name, [bam, bai], vcf ]

    SLAMDUNK_COUNT(ch_results, ch_count_bed, ch_fasta)
    ALLEYOOP_COLLAPSE(SLAMDUNK_COUNT.out.tsv)

    emit:
    results   = ch_results                  // channel: [ name, [bam, bai], vcf ]
    count_tsv = SLAMDUNK_COUNT.out.tsv       // channel: [ name, tsv ]
    collapse  = ALLEYOOP_COLLAPSE.out.csv    // channel: [ name, csv ]
}
