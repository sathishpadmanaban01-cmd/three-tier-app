#!/usr/bin/env bash
set -euo pipefail
cd infra/environments/dev
terraform destroy -auto-approve
