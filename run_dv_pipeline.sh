#!/bin/bash
set -euo pipefail
# Set common settings.

if [ "${#@}" -lt 5 ]; then
    echo "Usage:"
    exit 1
fi

PROJECT_ID=sanger-humgen-gcpeval
INPUT_REF_FILE="${1}"
INPUT_BAM_FILE="${2}"

OUTPUT_DIR="${3%/}"
STAGING_FOLDER_NAME=stage
OUTPUT_FILE_NAME="${4}"
JOB_PREFIX="${5}"

# Model for calling whole genome sequencing data.
MODEL=gs://deepvariant/models/DeepVariant/0.6.0/DeepVariant-inception_v3-0.6.0+cl-191676894.data-wgs_standard

IMAGE_VERSION=0.6.1
DOCKER_IMAGE=gcr.io/deepvariant-docker/deepvariant:"${IMAGE_VERSION}"
DOCKER_IMAGE_GPU=gcr.io/deepvariant-docker/deepvariant_gpu:"${IMAGE_VERSION}"

# Run the pipeline.
gcloud alpha genomics pipelines run \
       --project "${PROJECT_ID}" \
       --pipeline-file /home/sm36/dv/scripts/multisample/deepvariant_pipeline.yaml \
       --logging "${OUTPUT_DIR}/runner_logs" \
       --zones europe-west1-b \
       --labels run="${JOB_PREFIX}" \
       --inputs `echo \
      PROJECT_ID="${PROJECT_ID}", \
      INPUT_REF_FILE="${INPUT_REF_FILE}", \
      INPUT_BAM_FILE="${INPUT_BAM_FILE}", \
      OUTPUT_DIR="${OUTPUT_DIR}", \
      JOB_NAME="${JOB_PREFIX}_", \
      MODEL="${MODEL}", \
      DOCKER_IMAGE="${DOCKER_IMAGE}", \
      DOCKER_IMAGE_GPU="${DOCKER_IMAGE_GPU}", \
      STAGING_FOLDER_NAME="${STAGING_FOLDER_NAME}", \
      OUTPUT_FILE_NAME="${OUTPUT_FILE_NAME}" \
      | tr -d '[:space:]'`

