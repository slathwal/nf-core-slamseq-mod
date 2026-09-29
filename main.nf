#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/slamseq
========================================================================================
 nf-core/slamseq Analysis Pipeline (DSL2).
 #### Homepage / Documentation
 https://github.com/nf-core/slamseq
----------------------------------------------------------------------------------------
*/

include { SLAMSEQ } from './workflows/slamseq'

workflow {

    // Show help message and exit early.
    if (params.help) {
        log.info helpMessage()
        return
    }

    log.info nfcoreHeader()

    // ----------------------------------------------------------------------
    // Parameter validation
    // ----------------------------------------------------------------------
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        error "The provided genome '${params.genome}' is not available in the iGenomes file. Currently the available genomes are ${params.genomes.keySet().join(', ')}"
    }
    if (!params.input) {
        error 'Input design file not specified!'
    }
    if (!params.bed && !params.genome) {
        error 'Bed file not specified!'
    }
    if (!params.read_length) {
        error 'Read length must be supplied.'
    }

    // Check the hostnames against configured profiles.
    checkHostname()

    // ----------------------------------------------------------------------
    // Run the pipeline
    // ----------------------------------------------------------------------
    SLAMSEQ()

    // ----------------------------------------------------------------------
    // Completion notification
    // ----------------------------------------------------------------------
    workflow.onComplete {
        completionEmail()
        completionSummary()
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

def helpMessage() {
    return """
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/slamseq --input design.tsv --fasta genome.fa --bed 3utr.bed -profile docker

    Mandatory arguments:
      --input [file]                  Tab-separated file containing information about the samples (see docs/usage.md)
      -profile [str]                  Configuration profile to use (conda, docker, singularity, test, ...)

    References:
      --genome [str]                  Name of iGenomes reference
      --fasta [file]                  Path to fasta reference
      --bed [file]                    Path to 3' UTR counting window reference
      --mapping [file]                Path to 3' UTR multimapper recovery reference (optional)
      --vcf [file]                    Path to VCF file for genomic SNPs to mask T>C conversion (optional)

    Processing parameters:
      --trim5 [int]                   Number of basepairs to trim from 5' end of the read
      --polyA [int]                   Maximum number of As at the 3' end of a read
      --multimappers [bool]           Activate multimapper retainment strategy
      --quantseq [bool]               Deactivate nucleotide-conversion aware scoring
      --endtoend [bool]               Use an end-to-end alignment algorithm for mapping
      --min_coverage [int]            Minimum coverage to call a SNP
      --var_fraction [float]          Minimum variant fraction to call a SNP
      --conversions [int]             Minimum number of conversions to count a read as converted
      --base_quality [int]            Minimum base quality to filter conversions
      --read_length [int]             Read length of processed reads
      --pvalue [float]                P-value cutoff for MA plot
      --skip_trimming [bool]          Skip trimming step
      --skip_deseq2 [bool]            Skip DESeq2 step

    Other options:
      --outdir [file]                 The output directory where the results will be saved
      --email [email]                 Set this parameter to your e-mail address to get a summary e-mail
      --email_on_fail [email]         Same as --email, but only sent on failure
      -name [str]                     Name for the pipeline run
    """.stripIndent()
}

def completionEmail() {
    def custom_runName = params.name
    if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
        custom_runName = workflow.runName
    }

    def subject = workflow.success
        ? "[nf-core/slamseq] Successful: ${workflow.runName}"
        : "[nf-core/slamseq] FAILED: ${workflow.runName}"

    def email_fields = [:]
    email_fields['version']      = workflow.manifest.version
    email_fields['runName']      = custom_runName ?: workflow.runName
    email_fields['success']      = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration']     = workflow.duration
    email_fields['exitStatus']   = workflow.exitStatus
    email_fields['errorMessage'] = workflow.errorMessage ?: 'None'
    email_fields['errorReport']  = workflow.errorReport ?: 'None'
    email_fields['commandLine']  = workflow.commandLine
    email_fields['projectDir']   = workflow.projectDir
    email_fields['summary']      = [:]
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Date Started']     = workflow.start
    email_fields['summary']['Date Completed']   = workflow.complete

    def email_address = params.email
    if (!params.email && params.email_on_fail && !workflow.success) {
        email_address = params.email_on_fail
    }

    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("${workflow.projectDir}/assets/email_template.txt")
    def email_txt = engine.createTemplate(tf).make(email_fields).toString()
    def hf = new File("${workflow.projectDir}/assets/email_template.html")
    def email_html = engine.createTemplate(hf).make(email_fields).toString()

    if (email_address) {
        def smail_fields = [
            email: email_address,
            subject: subject,
            email_txt: email_txt,
            email_html: email_html,
            baseDir: "${workflow.projectDir}",
            mqcFile: null,
            mqcMaxSize: params.max_multiqc_email_size.toBytes(),
        ]
        def sf = new File("${workflow.projectDir}/assets/sendmail_template.txt")
        def sendmail_html = engine.createTemplate(sf).make(smail_fields).toString()
        try {
            if (params.plaintext_email) {
                throw new org.codehaus.groovy.GroovyException('Send plaintext e-mail, not HTML')
            }
            [ 'sendmail', '-t' ].execute() << sendmail_html
            log.info "[nf-core/slamseq] Sent summary e-mail to ${email_address} (sendmail)"
        }
        catch (_all) {
            [ 'mail', '-s', subject, email_address ].execute() << email_txt
            log.info "[nf-core/slamseq] Sent summary e-mail to ${email_address} (mail)"
        }
    }

    // Write summary e-mail HTML and TXT to a file.
    def output_d = new File("${params.outdir}/pipeline_info/")
    if (!output_d.exists()) {
        output_d.mkdirs()
    }
    new File(output_d, 'pipeline_report.html').withWriter { w -> w << email_html }
    new File(output_d, 'pipeline_report.txt').withWriter { w -> w << email_txt }
}

def completionSummary() {
    def c_green  = params.monochrome_logs ? '' : "\033[0;32m"
    def c_purple = params.monochrome_logs ? '' : "\033[0;35m"
    def c_red    = params.monochrome_logs ? '' : "\033[0;31m"
    def c_reset  = params.monochrome_logs ? '' : "\033[0m"

    if (workflow.stats.ignoredCount > 0 && workflow.success) {
        log.info "-${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}-"
        log.info "-${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCount} ${c_reset}-"
        log.info "-${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCount} ${c_reset}-"
    }

    if (workflow.success) {
        log.info "-${c_purple}[nf-core/slamseq]${c_green} Pipeline completed successfully${c_reset}-"
    }
    else {
        checkHostname()
        log.info "-${c_purple}[nf-core/slamseq]${c_red} Pipeline completed with errors${c_reset}-"
    }
}

def nfcoreHeader() {
    def c_black  = params.monochrome_logs ? '' : "\033[0;30m"
    def c_blue   = params.monochrome_logs ? '' : "\033[0;34m"
    def c_dim    = params.monochrome_logs ? '' : "\033[2m"
    def c_green  = params.monochrome_logs ? '' : "\033[0;32m"
    def c_purple = params.monochrome_logs ? '' : "\033[0;35m"
    def c_reset  = params.monochrome_logs ? '' : "\033[0m"
    def c_yellow = params.monochrome_logs ? '' : "\033[0;33m"

    return """    -${c_dim}--------------------------------------------------${c_reset}-
                                            ${c_green},--.${c_black}/${c_green},-.${c_reset}
    ${c_blue}        ___     __   __   __   ___     ${c_green}/,-._.--~\'${c_reset}
    ${c_blue}  |\\ | |__  __ /  ` /  \\ |__) |__         ${c_yellow}}  {${c_reset}
    ${c_blue}  | \\| |       \\__, \\__/ |  \\ |___     ${c_green}\\`-._,-`-,${c_reset}
                                            ${c_green}`._,._,\'${c_reset}
    ${c_purple}  nf-core/slamseq v${workflow.manifest.version}${c_reset}
    -${c_dim}--------------------------------------------------${c_reset}-
    """.stripIndent()
}

def checkHostname() {
    def c_reset       = params.monochrome_logs ? '' : "\033[0m"
    def c_white       = params.monochrome_logs ? '' : "\033[0;37m"
    def c_red         = params.monochrome_logs ? '' : "\033[1;91m"
    def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
    if (params.hostnames) {
        def hostname = 'hostname'.execute().text.trim()
        params.hostnames.each { prof, hnames ->
            hnames.each { hname ->
                if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
                    log.error "====================================================\n" +
                            "  ${c_red}WARNING!${c_reset} You are running with `-profile ${workflow.profile}`\n" +
                            "  but your machine hostname is ${c_white}'${hostname}'${c_reset}\n" +
                            "  ${c_yellow_bold}It's highly recommended that you use `-profile ${prof}${c_reset}`\n" +
                            "============================================================"
                }
            }
        }
    }
}
