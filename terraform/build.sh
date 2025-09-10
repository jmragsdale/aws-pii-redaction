#!/usr/bin/env bash
set -e
pushd ../lambda >/dev/null
zip -q -r ../lambda.zip .
popd >/dev/null
echo "Built lambda.zip"
