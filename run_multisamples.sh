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

#INPUT_BAM_FILES=( $(cat "${INPUT_BAM_LIST}") )

for INPUT_BAM_FILE in $(cat "${INPUT_BAM_LIST}"); do
    echo "${INPUT_BAM_FILE}"

    IFS='/' read -a fields <<< "${INPUT_BAM_FILE}"
    SAMPLE="${fields[-2]}"
    OUTPUT_DIR="${OUTPUT_BUCKET}/${SAMPLE}"
    
    if [[ "${JOB_PREFIX}" =~ 'none' ]]; then
	JOB_PREFIX="${OUTPUT_FILE_PREFIX}_${SAMPLE}"
    fi

    FILE_DATE=$(date -u +"%Y%m%d")
    OUTPUT_FILE_NAME="${OUTPUT_FILE_PREFIX}.${SAMPLE}.bam_to_vcf.${FILE_DATE}.vcf"

    bash run_dv_pipeline.sh "${INPUT_REF_FILE}" "${INPUT_BAM_FILE}" "${OUTPUT_DIR}" "${OUTPUT_FILE_NAME}" "${JOB_PREFIX}"

done
