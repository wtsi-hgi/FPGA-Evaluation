#!/bin/bash
set -euo pipefail

if [ "${#@}" -lt 4 ]; then
    echo "Usage:"
    exit 1
fi

# Set common settings.

PROJECT_ID=sanger-humgen-gcpeval
INPUT_REF_FILE="${1}"
INPUT_BAM_LIST="${2}"

OUTPUT_BUCKET="${3%/}"
STAGING_FOLDER_NAME=stage
OUTPUT_FILE_PREFIX="${4}"
JOB_PREFIX="${5:-none}"

for INPUT_BAM_FILE in $(cat "${INPUT_BAM_LIST}"); do
    echo "${INPUT_BAM_FILE}"

    IFS='/' read -a fields <<< "${INPUT_BAM_FILE}"
    SAMPLE="${fields[-2]}"
    DEPTH="${fields[-4]}"
    OUTPUT_DIR="${OUTPUT_BUCKET}/${DEPTH}/${SAMPLE}"
    
    if [[ "${JOB_PREFIX}" =~ 'none' ]]; then
	JOB_LABEL="${DEPTH//-/_}-${OUTPUT_FILE_PREFIX}-repl${SAMPLE: -1}"
    else
	JOB_LABEL="${JOB_PREFIX}-${DEPTH//-/_}-${OUTPUT_FILE_PREFIX}-repl${SAMPLE: -1}"
    fi

    FILE_DATE=$(date -u +"%Y%m%d")

    if [[ "${INPUT_BAM_FILE}" == *.bam ]]; then
	INPUT_BAI_FILE="${INPUT_BAM_FILE%%.bam}.bai"
	OUTPUT_FILE_NAME="${DEPTH}.${OUTPUT_FILE_PREFIX}.${SAMPLE}.bam_to_vcf.${FILE_DATE}.vcf"
    fi

    if [[ "${INPUT_BAM_FILE}" == *.cram ]]; then
	INPUT_BAI_FILE="${INPUT_BAM_FILE}.crai"
	OUTPUT_FILE_NAME="${DEPTH}.${OUTPUT_FILE_PREFIX}.${SAMPLE}.cram_to_vcf.${FILE_DATE}.vcf"	
    fi

    bash run_dv_pipeline.sh "${INPUT_REF_FILE}" "${INPUT_BAM_FILE}" "${INPUT_BAI_FILE}" "${OUTPUT_DIR}" "${OUTPUT_FILE_NAME}" "${JOB_LABEL}"

done
