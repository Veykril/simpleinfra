#!/bin/bash

#
# {{ ansible_managed }}
#

set -euv -o pipefail

checkout_path="{{ vars_playground_checkout_path }}"
artifacts_path="{{ vars_playground_artifacts_path }}"

binary_path="${artifacts_path}/ui"

# Get new docker images
"${checkout_path}/compiler/fetch.sh"

# Clean old docker images
docker system prune -f || true

# Get the binary's hash so we know if it has changed
previous_binary_hash=""
if [[ -f "${binary_path}" ]]; then
    previous_binary_hash=$(md5sum "${binary_path}")
fi

# Get new artifacts
aws s3 sync --region=us-east-2 s3://playground-artifacts-i32 "${artifacts_path}"
# These artifacts don't change names and might stay the same size
# https://github.com/aws/aws-cli/issues/1074
aws s3 sync \
    --region=us-east-2 \
    --exclude='*' \
    --include=ui \
    --include=build/index.html \
    --include=build/index.html.gz \
    --include=build/robots.txt \
    --exact-timestamps \
    s3://playground-artifacts-i32 "${artifacts_path}"
chmod +x "${binary_path}"

# Restart to get new server binary
if [[ -z "${previous_binary_hash}" ]] || ! md5sum -c <(echo "${previous_binary_hash}") --status; then
    sudo service playground stop || true
    sudo service playground start
fi
