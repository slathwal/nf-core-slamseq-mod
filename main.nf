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

include { PREPARE_GENOME } from './subworkflows/local/prepare_genome'
include { SLAMSEQ }        from './workflows/slamseq'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    // Show help message and exit
    if (params.help) {
        log.info nfcoreHeader()
        log.info helpMessage()
        return
    }

    //
    // Validate inputs
    //
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        error "The provided genome '${params.genome}' is not available in the iGenomes file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
    }
    if (!params.input) {
        error "Input design file not specified!"
    }

    def fasta_ref = params.genome ? params.genomes[params.genome].fasta ?: false : params.fasta
    if (!fasta_ref) {
        error "Fasta file not specified!"
    }
    if (!params.bed && !params.genome) {
        error "Bed file not specified!"
    }
    if (!params.read_length) {
        error "Read length must be supplied."
    }

    if (workflow.profile.contains('awsbatch')) {
        if (!params.awsqueue || !params.awsregion) {
            error "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
        }
        if (!params.outdir.startsWith('s3:')) {
            error "Outdir not on S3 - specify S3 Bucket to run on AWSBatch!"
        }
        if (params.tracedir.startsWith('s3:')) {
            error "Specify a local tracedir or run without trace! S3 cannot be used for tracefiles."
        }
    }

    //
    // Header log info
    //
    def summary = createSummary(fasta_ref)

    log.info nfcoreHeader()
    log.info summary.collect { k, v -> "${k.padRight(18)}: $v" }.join("\n")
    log.info "-\033[2m--------------------------------------------------\033[0m-"
    checkHostname()

    //
    // Stage config / documentation files
    //
    def ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
    def ch_multiqc_custom_config = params.multiqc_config ? channel.fromPath(params.multiqc_config, checkIfExists: true) : channel.empty()
    def ch_output_docs           = file("$projectDir/docs/output.md", checkIfExists: true)
    def ch_output_docs_images    = file("$projectDir/docs/images/", checkIfExists: true)

    //
    // Build the MultiQC workflow-summary fragment
    //
    def ch_workflow_summary = channel.from(summary.collect { entry -> [entry.key, entry.value] })
        .map { k, v -> "<dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }
        .reduce { a, b -> [a, b].join("\n            ") }
        .map { x ->
            """
            id: 'nf-core-slamseq-summary'
            description: " - this information is collected when the pipeline is started."
            section_name: 'nf-core/slamseq Workflow Summary'
            section_href: 'https://github.com/nf-core/slamseq'
            plot_type: 'html'
            data: |
                <dl class=\"dl-horizontal\">
                    $x
                </dl>
            """.stripIndent()
        }

    //
    // Resolve genome reference channels (FASTA, 3'UTR BED, multimapper filter)
    //
    PREPARE_GENOME()

    //
    // Run the full slamseq analysis
    //
    SLAMSEQ(
        channel.fromPath(params.input, checkIfExists: true),
        PREPARE_GENOME.out.fasta,
        PREPARE_GENOME.out.bed,
        PREPARE_GENOME.out.utr_filter,
        ch_multiqc_config,
        ch_multiqc_custom_config,
        ch_output_docs,
        ch_output_docs_images,
        ch_workflow_summary,
    )
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

def completionNotification() {
    def custom_runName = getRunName()
    def summary = createSummary(params.genome ? params.genomes[params.genome].fasta ?: false : params.fasta)

    // Set up the e-mail variables
    def subject = workflow.success ? "[nf-core/slamseq] Successful: $workflow.runName" : "[nf-core/slamseq] FAILED: $workflow.runName"

    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if (workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if (workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if (workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // Check if we are only sending emails on failure
    def email_address = params.email
    if (!params.email && params.email_on_fail && !workflow.success) {
        email_address = params.email_on_fail
    }

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$projectDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$projectDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: email_address, subject: subject, email_txt: email_txt, email_html: email_html, projectDir: "$projectDir", mqcFile: null, mqcMaxSize: params.max_multiqc_email_size.toBytes() ]
    def sf = new File("$projectDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (email_address) {
        try {
            if (params.plaintext_email) { throw new RuntimeException('Send plaintext e-mail, not HTML') }
            [ 'sendmail', '-t' ].execute() << sendmail_html
            log.info "[nf-core/slamseq] Sent summary e-mail to $email_address (sendmail)"
        }
        catch (Exception _all) {
            [ 'mail', '-s', subject, email_address ].execute() << email_txt
            log.info "[nf-core/slamseq] Sent summary e-mail to $email_address (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File("${params.outdir}/pipeline_info/")
    if (!output_d.exists()) {
        output_d.mkdirs()
    }
    def output_hf = new File(output_d, "pipeline_report.html")
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File(output_d, "pipeline_report.txt")
    output_tf.withWriter { w -> w << email_txt }

    def c_green = params.monochrome_logs ? '' : "\033[0;32m"
    def c_purple = params.monochrome_logs ? '' : "\033[0;35m"
    def c_red = params.monochrome_logs ? '' : "\033[0;31m"
    def c_reset = params.monochrome_logs ? '' : "\033[0m"

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

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

// Resolve the run name, catching both -name and --name
def getRunName() {
    def custom_runName = params.name
    if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
        custom_runName = workflow.runName
    }
    return custom_runName
}

// Build the run-summary map shown in the log and the MultiQC report
def createSummary(fasta_ref) {
    def custom_runName = getRunName()
    def summary = [:]
    if (workflow.revision) summary['Pipeline Release'] = workflow.revision
    summary['Run Name']         = custom_runName ?: workflow.runName
    summary['Input']            = params.input
    summary['Fasta Ref']        = fasta_ref
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
    summary['Max Resources']    = "$params.max_memory memory, $params.max_cpus cpus, $params.max_time time per job"
    if (workflow.containerEngine) summary['Container'] = "$workflow.containerEngine - $workflow.container"
    summary['Output dir']       = params.outdir
    summary['Launch dir']       = workflow.launchDir
    summary['Working dir']      = workflow.workDir
    summary['Script dir']       = workflow.projectDir
    summary['User']             = workflow.userName
    if (workflow.profile.contains('awsbatch')) {
        summary['AWS Region']   = params.awsregion
        summary['AWS Queue']    = params.awsqueue
        summary['AWS CLI']      = params.awscli
    }
    summary['Config Profile'] = workflow.profile
    if (params.config_profile_description) summary['Config Description'] = params.config_profile_description
    if (params.config_profile_contact)     summary['Config Contact']     = params.config_profile_contact
    if (params.config_profile_url)         summary['Config URL']         = params.config_profile_url
    if (params.email || params.email_on_fail) {
        summary['E-mail Address']    = params.email
        summary['E-mail on failure'] = params.email_on_fail
        summary['MultiQC maxsize']   = params.max_multiqc_email_size
    }
    return summary
}

def helpMessage() {
    return """
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/slamseq --input design.tsv --fasta genome.fa --bed 3utr.bed -profile docker

    Mandatory arguments:
      --input [file]                  Tab-separated file containing information about the samples in the experiment (see docs/usage.md)
      -profile [str]                  Configuration profile to use. Can use multiple (comma separated)
                                      Available: conda, docker, singularity, test, awsbatch, <institute> and more

    Options:
      --genome [str]                  Name of iGenomes reference

    References                        If not specified in the configuration file or you wish to overwrite any of the references
      --fasta [file]                  Path to fasta reference
      --bed [file]                    Path to 3' UTR counting window reference
      --mapping [file]                Path to 3' UTR multimapper recovery reference (optional)
      --vcf [file]                    Path to VCF file for genomic SNPs to mask T>C conversion (optional)

    Processing parameters
      --trim5 [int]                   Number of basepairs to trim from 5' end of the read
      --polyA [int]                   Maximum number of As at the 3' end of a read.
      --multimappers [bool]           Activate multimapper retainment strategy
      --quantseq [bool]               Deactivate nucleotide-conversion aware scoring
      --endtoend [bool]               Use a end to end alignment algorithm for mapping.
      --min_coverage [int]            Minimimum coverage to call a SNP.
      --var_fraction [float]          Minimimum variant fraction to call a SNP.
      --conversions [int]             Minimum number of conversions to count a read as converted read
      --base_quality [int]            Minimum base quality to filter conversions
      --read_length [int]             Read length of processed reads
      --pvalue [float]                P-value cutoff for MA plot
      --skip_trimming [bool]          Skip trimming step
      --skip_deseq2 [bool]            Skip DESeq2 step

    Other options:
      --outdir [file]                 The output directory where the results will be saved
      --email [email]                 Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      --email_on_fail [email]         Same as --email, except only send mail if the workflow is not successful
      --max_multiqc_email_size [str]  Theshold size for MultiQC report to be attached in notification email (Default: 25MB)
      -name [str]                     Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic

    AWSBatch options:
      --awsqueue [str]                The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion [str]               The AWS Region for your AWS Batch job to run on
      --awscli [str]                  Path to the AWS CLI tool
    """.stripIndent()
}

def nfcoreHeader() {
    def c_black = params.monochrome_logs ? '' : "\033[0;30m"
    def c_blue = params.monochrome_logs ? '' : "\033[0;34m"
    def c_dim = params.monochrome_logs ? '' : "\033[2m"
    def c_green = params.monochrome_logs ? '' : "\033[0;32m"
    def c_purple = params.monochrome_logs ? '' : "\033[0;35m"
    def c_reset = params.monochrome_logs ? '' : "\033[0m"
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
    def c_reset = params.monochrome_logs ? '' : "\033[0m"
    def c_white = params.monochrome_logs ? '' : "\033[0;37m"
    def c_red = params.monochrome_logs ? '' : "\033[1;91m"
    def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
    if (params.hostnames) {
        def hostname = "hostname".execute().text.trim()
        params.hostnames.each { prof, hnames ->
            hnames.each { hname ->
                if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
                    log.error "====================================================\n" +
                            "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
                            "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
                            "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
                            "============================================================"
                }
            }
        }
    }
}
