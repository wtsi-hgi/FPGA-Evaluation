#!/usr/bin/env bash

set -euf -o pipefail

# Timed FASTQ to sorted, duplicate-marked BAM output.

# Check input and assign to vars
if [ "${#@}" -lt 4 ]; then
  echo "Usage: timed_pipelines_fastq_to_vcf_with_bam_output.sh <fastq_list.csv> <output_dir> <output_file_prefix> <log_directory>
All '<>' parameters must be supplied with full path names."
  exit 1
fi

fastq_list="${1}"
output_dir="${2%/}"
output_prefix="${3}"
log_directory="${4%/}"

command_log="${log_directory}/command_timings.log"
total_timings_log="${log_directory}/total_timings.log"
joint_caller_log="${log_directory}/joint_caller_timings.log"

# Dragen variables
REFDIR="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6"
VCREF="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6/Homo_sapiens.GRCh38_full_analysis_set_plus_decoy_hla.fa"

# Calc totally time to run all the samples
start_time=$(date -u +"%s")


if [ ! -d "${log_directory}" ]; then
  mkdir "${log_directory}"
fi
if [ -f "${command_log}" ]; then
  echo "ERROR: Command log ${command_log} already exists."
  exit 1
fi
if [ -f "${total_timings_log}" ]; then
  echo "ERROR: Timing log ${total_timings_log} already exists."
  exit 1
fi
if [ -f "${joint_caller_log}" ]; then
  echo "ERROR: Joint caller timing log ${joint_caller_log} already exists."
  exit 1
fi


printf "%s\n" "$(date)" >> "${command_log}"
printf "%s\n" "$(date)" >> "${total_timings_log}"

SAMPLES=$(tail -n +2 "${fastq_list}" | awk 'BEGIN {FS=","} {print $2;}' | sort | uniq)

file_date=$(date -u +"%Y%m%d")
# Below is a handy little cheat if the dragen crashes partway through processing and you still want the joint caller to work on all files with the same date.
# DO REMEMEBER to comment it out before committing to version control or for subsequent processing.
#file_date="20180208"  

# Create a directory for the bams
bam_directory="${output_dir}/bam"
if [ ! -d "${bam_directory}" ]; then
  mkdir "${bam_directory}"
fi

echo "Sample sample_total_elapsed_seconds sample_bam_elapsed_seconds sample_gvcf_elapsed_seconds sample_gatk_elapsed_seconds" >> "${total_timings_log}"


# From each FASTQ sample, generate a bam.  Then run timings for non-GATK-acceleration and GATK-acceleration for VCF generation
for sample in ${SAMPLES}; do 

  sample_start_time=$(date -u +"%s")
  
  echo "Calling sample ${sample}" >> "${command_log}"

  # FASTQ to BAM
  /usr/bin/time --append --output="${command_log}" -f "\n--------------------\nTimings for FASTQ to BAM run\n--------------------\nCommand: %C\nRun elapsed time = %E\nRun elapsed real time = %e\nRun exit status = %x\n" dragen -f -r "${REFDIR}" --fastq-list "${fastq_list}" --fastq-list-sample-id "${sample}" --intermediate-results-dir "/staging/tmp" --output-directory "${bam_directory}" --output-file-prefix "${output_prefix}.${sample}.fastq_to_bam.${file_date}" --enable-duplicate-marking true --enable-bam-indexing true

  bam_end_time=$(date -u +"%s")

  bam_file="${bam_directory}/${output_prefix}.${sample}.fastq_to_bam.${file_date}.bam"

  # BAM to gVCF
  /usr/bin/time --append --output="${command_log}" -f "\n--------------------\nTimings for BAM to gVCF run\n--------------------\nCommand: %C\nRun elapsed time = %E\nRun elapsed real time = %e\nRun exit status = %x\n" dragen -f -r "${REFDIR}" -b "${bam_file}" --enable-variant-caller true --vc-reference "${VCREF}" --vc-sample-name "${sample}" --vc-emit-ref-confidence "GVCF" --intermediate-results-dir "/staging/tmp" --output-directory "${output_dir}" --output-file-prefix "${output_prefix}.${sample}.bam_to_gvcf.${file_date}" --enable-duplicate-marking true

  gvcf_end_time=$(date -u +"%s")

  # GATK-accelerated BAM to gVCF
  /usr/bin/time --append --output="${command_log}" -f "\n--------------------\nTimings for GATK BAM to gVCF run\n--------------------\nCommand: %C\nRun elapsed time = %E\nRun elapsed real time = %e\nRun exit status = %x\n" dragen -f -r "${REFDIR}" -b "${bam_file}" --enable-variant-caller true --vc-reference "${VCREF}" --vc-sample-name "${sample}" --vc-emit-ref-confidence "GVCF" --vc-enable-gatk-acceleration true --intermediate-results-dir "/staging/tmp" --output-directory "${output_dir}" --output-file-prefix "${output_prefix}.${sample}.bam_to_gvcf_gatk.${file_date}" --enable-duplicate-marking true

  gatk_end_time=$(date -u +"%s")

  sample_total_elapsed_seconds=$(( ${gatk_end_time} - ${sample_start_time} ))
  sample_bam_elapsed_seconds=$(( ${bam_end_time} - ${sample_start_time} ))
  sample_gvcf_elapsed_seconds=$(( ${gvcf_end_time} - ${bam_end_time} ))
  sample_gatk_elapsed_seconds=$(( ${gatk_end_time} - ${gvcf_end_time} ))

  echo "${sample} ${sample_total_elapsed_seconds} ${sample_bam_elapsed_seconds} ${sample_gvcf_elapsed_seconds} ${sample_gatk_elapsed_seconds}" >> "${total_timings_log}" 

done

# Run the joint callers.
echo "dataset total_joint_caller_elapsed_seconds gvcf_joint_caller_elapsed_seconds gatk_joint_caller_elapsed_seconds" >> "${joint_caller_log}"

# Need a list of all the gVCF's
gvcf_list="${output_dir}/gVCF_list.txt"
gatk_list="${output_dir}/gatk_list.txt"

if [ -f ${gvcf_list} ]; then
  rm -f ${gvcf_list}
fi
if [ -f ${gatk_list} ]; then
  rm -f ${gatk_list}
fi

for gvcf_file in $(ls ${output_dir} | egrep '*.gvcf.gz$' | egrep "${file_date}" |  egrep -v '*hard-filtered*'); do
   if [[ "${gvcf_file}" =~ 'gatk' ]]; then
     echo "${output_dir}/${gvcf_file}" >> "${gatk_list}"
   elif ! [[ "${gvcf_file}" =~ 'gatk'  ]]; then
     echo "${output_dir}/${gvcf_file}" >> "${gvcf_list}"
   fi  
done

joint_caller_start_time=$(date -u +"%s")

# Run joint caller on non-gatk gVCFs
/usr/bin/time --append --output="${command_log}" -f "\n--------------------\nTimings for the joint caller\n--------------------\nCommand: %C\nJoint calling elapsed time = %E\nJoint calling elapsed real time = %e\nJoint calling exit status = %x\n" dragen -f -r "${REFDIR}" --enable-joint-genotyping true --variant-list ${gvcf_list} --intermediate-results-dir "/staging/tmp" --output-directory ${output_dir} --output-file-prefix "${output_prefix}.gvcf_to_vcf.${file_date}"

end_gvcf_time=$(date -u +"%s")

# Run joint caller on gatk gVCFs
/usr/bin/time --append --output="${command_log}" -f "\n--------------------\nTimings for the GATK joint caller\n--------------------\nCommand: %C\nJoint calling elapsed time = %E\nJoint calling elapsed real time = %e\nJoint calling exit status = %x\n" dragen -f -r "${REFDIR}" --enable-joint-genotyping true --vc-enable-gatk-acceleration true --variant-list ${gatk_list} --intermediate-results-dir "/staging/tmp" --output-directory ${output_dir} --output-file-prefix "${output_prefix}.gatk_gvcf_to_vcf.${file_date}"

end_gatk_time=$(date -u +"%s")

total_joint_caller_elapsed_seconds=$(( ${end_gatk_time} - ${joint_caller_start_time} ))
gvcf_elapsed_seconds=$(( ${end_gvcf_time} - ${joint_caller_start_time} ))
gatk_elapsed_seconds=$(( ${end_gatk_time} - ${end_gvcf_time} ))

echo "${output_prefix} ${total_joint_caller_elapsed_seconds} ${gvcf_elapsed_seconds} ${gatk_elapsed_seconds}" >> "${joint_caller_log}"

end_time=$(date -u +"%s")
printf "\nTotal runtime: %s\n\n" $(date -u -d "0 ${end_time} seconds - ${start_time} seconds"  +"%H:%M:%S") >> "${command_log}"

