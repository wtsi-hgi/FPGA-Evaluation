#!/usr/bin/env bash

set -euf -o pipefail

# Time pipeline runs on Dragen

# Check input and assign to vars
if [ "${#@}" -lt 4 ]; then
  echo "Usage: timed_end_to_end_fastq_to_vcf.sh <fastq_list.csv> <output_dir> <output_file_prefix> <log_file> [run_gatk_acc]
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
  first_stage="dragen-fastq_to_gvcf_gatk"
  second_stage="dragen-gvcf_to_vcf_gatk"
  gatk_command="--vc-enable-gatk-acceleration true"
else
  gatk=" "
  first_stage="dragen-fastq_to_gvcf"
  second_stage="dragen-gvcf_to_vcf"
  gatk_command=" "
fi

# Dragen variables
REFDIR="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6"
VCREF="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6/Homo_sapiens.GRCh38_full_analysis_set_plus_decoy_hla.fa"

# Calc totally time to run all the samples
start_time=$(date -u +"%s")

printf "%s\n" "$(date)" >> "${log_file}"

SAMPLES=$(tail -n +2 "${fastq_list}" | awk 'BEGIN {FS=","} {print $2;}' | sort | uniq)

file_date=$(date -u +"%Y%m%d")

for sample in ${SAMPLES}; do 
  echo "Calling sample ${sample}" >> "${log_file}"
  /usr/bin/time --append --output="${log_file}" -f "\n--------------------\nTimings for${gatk}FASTQ to gVCF run\n--------------------\nCommand: %C\nRun elapsed time = %E\nRun elapsed real time = %e\nRun exit status = %x\n" dragen -f -r "${REFDIR}" --fastq-list "${fastq_list}" --fastq-list-sample-id "${sample}" --enable-variant-caller true --vc-reference "${VCREF}" --vc-sample-name "${sample}" --vc-emit-ref-confidence "GVCF" ${gatk_command} --intermediate-results-dir "/staging/tmp" --output-directory "${output_dir}" --output-file-prefix "${output_prefix}.${sample}.${first_stage}.${file_date}" --enable-duplicate-marking true
done

run_end_time=$(date -u +"%s")
printf "\nTotal runtime for generating gVCFs: %s\n\n" $(date -u -d "0 ${run_end_time} seconds - ${start_time} seconds"  +"%H:%M:%S") >> "${log_file}"

# Run the joint caller on the gVCF files output from the pipeline run.

# Need a list of all the gVCF's
gvcf_list="${output_dir}/gVCF_list.txt"

if [ -f ${gvcf_list} ]; then
  rm -f ${gvcf_list}
fi

for gvcf_file in $(ls ${output_dir} | egrep '*.gvcf.gz$' | egrep "${file_date}" |  egrep -v '*hard-filtered*'); do
   if [[ "${run_gatk}" =~ 'true' ]] && [[ "${gvcf_file}" =~ 'gatk' ]]; then
     echo "${output_dir}/${gvcf_file}" >> "${gvcf_list}"
   elif [[ "${run_gatk}" =~ 'false' ]] && ! [[ "${gvcf_file}" =~ 'gatk'  ]]; then
     echo "${output_dir}/${gvcf_file}" >> "${gvcf_list}"
   fi  
done

/usr/bin/time --append --output="${log_file}" -f "\n--------------------\nTimings for${gatk}the joint caller\n--------------------\nCommand: %C\nJoint calling elapsed time = %E\nJoint calling elapsed real time = %e\nJoint calling exit status = %x\n" dragen -f -r "${REFDIR}" --enable-joint-genotyping true --variant-list ${gvcf_list} --output-directory ${output_dir} --output-file-prefix "${output_prefix}.${second_stage}.${file_date}" 

end_time=$(date -u +"%s")
printf "\nTotal runtime: %s\n\n" $(date -u -d "0 ${end_time} seconds - ${start_time} seconds"  +"%H:%M:%S") >> "${log_file}"

