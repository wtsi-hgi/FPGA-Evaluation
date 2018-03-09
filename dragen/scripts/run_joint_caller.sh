#!/usr/bin/env bash

set -euf -o pipefail

# Run the joint caller for stanard dragen pipeline or gatk pipeline or both.

# Check if all arguments have been supplied.
if [ "${#@}" -lt 5 ]; then
  echo "Usage: run_joint_caller.sh [gvcf_directory] [file_date] [output_dir] [output_prefix] [log_directory] <run_mode=none>
All arguments must be supplied except for run_mode which is none by default.
Run modes:
  none - run the standard Dragen joint caller
  gatk - run the gatk-accelerated joint caller
  both - run both standard and gatk-accelerated joint caller, one after the other."
fi

gvcf_dir="${1%/}"
file_date="${2}"
output_dir="${3%/}"
output_prefix="${4}"
log_directory="${5%/}"
run_mode="${6:-none}"

if [[ "${run_mode}" =~ 'none' ]]; then
  run_standard="true"
  run_gatk="false"
fi
if [[ "${run_mode}" =~ 'gatk' ]]; then
  run_standard="false"
  run_gatk="true"
fi
if [[ "${run_mode}" =~ 'both' ]]; then
  run_standard="true"
  run_gatk="true"
fi

joint_caller_log="${log_directory}/standalone_joint_caller_timings.log" 

if [ ! -d "${log_directory}" ]; then
  mkdir "${log_directory}"
fi
if [ -f "${joint_caller_log}" ]; then
  echo "ERROR: Command log ${joint_caller_log} already exists."
  exit 1
fi

# Dragen variables
REFDIR="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6"
VCREF="/lustre/scratch118/humgen/hgi/users/mercury/2017-2018-variant-caller-eval/dragen/ref-v6/Homo_sapiens.GRCh38_full_analysis_set_plus_decoy_hla.fa"

printf "%s\n" "$(date)" >> "${joint_caller_log}"

start_time=$(date -u +"%s")

# Run joint caller on non-gatk gVCFs
if [[ ${run_standard} =~ "true" ]]; then
  gvcf_list="${output_dir}/standalone_gVCF_list.txt"

  if [ -f ${gvcf_list} ]; then
    rm -f ${gvcf_list}
  fi
  
  for gvcf_file in $(ls "${gvcf_dir}" | egrep '*.gvcf.gz$' | egrep "${file_date}" |  egrep -v '*hard-filtered*'); do
    if ! [[ "${gvcf_file}" =~ 'gatk'  ]]; then
      echo "${gvcf_dir}/${gvcf_file}" >> "${gvcf_list}"
    fi
  done

  /usr/bin/time --append --output="${joint_caller_log}" -f "\n--------------------\nTimings for the joint caller\n--------------------\nCommand: %C\nJoint calling elapsed time = %E\nJoint calling elapsed real time = %e\nJoint calling exit status = %x\n" dragen -f -r "${REFDIR}" --enable-joint-genotyping true --variant-list ${gvcf_list} --output-directory ${output_dir} --intermediate-results-dir "/staging/tmp" --output-file-prefix "${output_prefix}.gvcf_to_vcf.${file_date}"
fi

# Run joint caller on gatk gVCFs
if [[ ${run_gatk} =~ "true" ]]; then
  gatk_list="${output_dir}/standalone_gatk_list.txt"

  if [ -f ${gatk_list} ]; then
    rm -f ${gatk_list}
  fi

  for gvcf_file in $(ls "${gvcf_dir}" | egrep '*.gvcf.gz$' | egrep "${file_date}" |  egrep -v '*hard-filtered*'); do
    if [[ "${gvcf_file}" =~ 'gatk' ]]; then
     echo "${gvcf_dir}/${gvcf_file}" >> "${gatk_list}"
    fi
  done

  /usr/bin/time --append --output="${joint_caller_log}" -f "\n--------------------\nTimings for the GATK joint caller\n--------------------\nCommand: %C\nJoint calling elapsed time = %E\nJoint calling elapsed real time = %e\nJoint calling exit status = %x\n" dragen -f -r "${REFDIR}" --enable-joint-genotyping true --vc-enable-gatk-acceleration true --variant-list ${gatk_list} --intermediate-results-dir "/staging/tmp" --output-directory ${output_dir} --output-file-prefix "${output_prefix}.gatk_gvcf_to_vcf.${file_date}"
fi

end_time=$(date -u +"%s")
printf "\nTotal runtime: %s\n\n" $(date -u -d "0 ${end_time} seconds - ${start_time} seconds"  +"%H:%M:%S") >> "${joint_caller_log}"
