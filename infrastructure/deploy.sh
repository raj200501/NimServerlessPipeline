#!/usr/bin/env bash
set -euo pipefail

if ! command -v sam >/dev/null 2>&1; then
  echo "AWS SAM CLI not found. Install it before deploying."
  exit 1
fi

if [[ -z "${AWS_S3_BUCKET:-}" ]]; then
  echo "AWS_S3_BUCKET must be set to package the SAM template."
  exit 1
fi

# Validate the SAM template
sam validate --template-file template.yaml

# Package the SAM template
sam package --template-file template.yaml --output-template-file packaged.yaml --s3-bucket "$AWS_S3_BUCKET"

# Deploy the SAM template
sam deploy --template-file packaged.yaml --stack-name NimServerlessPipeline --capabilities CAPABILITY_IAM
