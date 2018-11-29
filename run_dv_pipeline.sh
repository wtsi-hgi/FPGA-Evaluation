#!/bin/bash
set -euo pipefail
# Set common settings.

if [ "${#@}" -lt 6 ]; then
    echo "Usage:"
    exit 1
fi

PROJECT_ID=sanger-humgen-gcpeval
INPUT_REF_FILE="${1}"
INPUT_BAM_FILE="${2}"
INPUT_BAI_FILE="${3}"

OUTPUT_DIR="${4%/}"
STAGING_FOLDER_NAME=stage
OUTPUT_FILE_NAME="${5}"
JOB_PREFIX="${6}"

# Model for calling whole genome sequencing data.
MODEL=gs://deepvariant/models/DeepVariant/0.7.0/DeepVariant-inception_v3-0.7.0+data-wgs_standard

IMAGE_VERSION=0.7.0
DOCKER_IMAGE=gcr.io/deepvariant-docker/deepvariant:"${IMAGE_VERSION}"

# Run the pipeline.
gcloud alpha genomics pipelines run \
       --project "${PROJECT_ID}" \
       --service-account-scopes="https://www.googleapis.com/auth/cloud-platform" \
       --pipeline-file deepvariant_pipeline.yaml \
       --logging "${OUTPUT_DIR}/runner_logs" \
       --regions europe-west1 \
       --labels run="${JOB_PREFIX}" \
       --inputs `echo \
      PROJECT_ID="${PROJECT_ID}", \
      INPUT_REF_FILE="${INPUT_REF_FILE}", \
      INPUT_BAM_FILE="${INPUT_BAM_FILE}", \
      INPUT_BAI_FILE="${INPUT_BAI_FILE}", \
      OUTPUT_DIR="${OUTPUT_DIR}", \
      JOB_NAME="${JOB_PREFIX}_", \
      MODEL="${MODEL}", \
      DOCKER_IMAGE="${DOCKER_IMAGE}", \
      STAGING_FOLDER_NAME="${STAGING_FOLDER_NAME}", \
      OUTPUT_FILE_NAME="${OUTPUT_FILE_NAME}" \
      | tr -d '[:space:]'`

