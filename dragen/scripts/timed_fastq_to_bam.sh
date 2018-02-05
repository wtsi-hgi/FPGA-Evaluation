#!/usr/bin/env bash

set -euf -o pipefail

# Timed FASTQ to sorted BAM output.

# Check input and assign to vars
if [ "${#@}" -lt 4 ]; then
  echo "Usage: timed_fastq_to_bam.sh <fastq_list.csv> <output_dir> <output_file_prefix> <log_file> [run_gatk_acc]
All '<>' parameters must be supplied with full path names.
NOTE: run_gatk_acc is set to "false" by default.  
      To run the pipeline with GATK acceleration put "true" after specifying the log file."
  exit 1
fi

fastq_list="${1}"
output_dir="${2%/}"
output_prefix="${3}"
log_file="${4}"
run_gatk="${5:-"false"}"

if [[ "${run_gatk}" =~ 'true' ]]; then
  gatk=" GATK "
  file_name="dragen-fastq_to_bam_gatk"
  gatk_command="--vc-enable-gatk-acceleration true"
else
  gatk=" "
  file_name="dragen-fastq_to_bam"
  gatk_command=" "
fi

# Dragen variables
REFDIR="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6"

# Calc totally time to run all the samples
start_time=$(date -u +"%s")

printf "%s\n" "$(date)" >> "${log_file}"

SAMPLES=$(tail -n +2 "${fastq_list}" | awk 'BEGIN {FS=","} {print $2;}' | sort | uniq)

file_date=$(date -u +"%Y%m%d")

for sample in ${SAMPLES}; do 
  echo "Calling sample ${sample}" >> "${log_file}"
  /usr/bin/time --append --output="${log_file}" -f "\n--------------------\nTimings for${gatk}FASTQ to BAM run\n--------------------\nCommand: %C\nRun elapsed time = %E\nRun elapsed real time = %e\nRun exit status = %x\n" dragen -f -r "${REFDIR}" --fastq-list "${fastq_list}" --fastq-list-sample-id "${sample}" ${gatk_command} --intermediate-results-dir "/staging/tmp" --output-directory "${output_dir}" --output-file-prefix "${output_prefix}.${sample}.${file_name}.${file_date}" --enable-duplicate-marking true 
done

run_end_time=$(date -u +"%s")
printf "\nTotal runtime for generating BAMs: %s\n\n" $(date -u -d "0 ${run_end_time} seconds - ${start_time} seconds"  +"%H:%M:%S") >> "${log_file}"

