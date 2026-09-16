#!/usr/bin/env bash
# Builds dist/lambda.zip: app/ plus its prod-only deps (fastapi, mangum), installed
# via the package's own pyproject.toml config rather than listed again here.
#
# Assumes the manylinux wheels pip resolves for compiled deps (pydantic-core) on the
# build host are ABI-compatible with Lambda's python3.12 runtime (Amazon Linux 2023,
# glibc/x86_64) — true in practice for a standard ubuntu-latest runner, not verified
# by this script.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf dist
mkdir -p dist/package
pip install --target dist/package .
(cd dist/package && zip -rq ../lambda.zip . -x '*.pyc' -x '__pycache__/*')

echo "Built dist/lambda.zip"
