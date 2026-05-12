#!/bin/bash
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 1. Path setup
if [ -d "/var/google-cloud-sdk/bin" ]; then
  export PATH=/var/google-cloud-sdk/bin:${PATH}
elif [ -d "/var/gcloud-sdk/google-cloud-sdk/bin" ]; then
  export PATH=/var/gcloud-sdk/google-cloud-sdk/bin:${PATH}
fi

# 2. Authenticate gcloud (only once)
if [ -n "${PROJECT_ID}" ] && [ ! -f /tmp/gcloud_auth_done ]; then
  if [ -f "./build-artifacts/provisioning-gsa.json" ]; then
    gcloud auth activate-service-account --key-file=./build-artifacts/provisioning-gsa.json --project "${PROJECT_ID}"
    gcloud auth configure-docker --quiet --verbosity=critical
    touch /tmp/gcloud_auth_done
  fi
fi

# 3. /etc/hosts setup (previously docker-cron-startup-script.sh)
if [ -f "/var/consumer-edge-install/docker-build/docker-cron-startup-script.sh" ]; then
  /var/consumer-edge-install/docker-build/docker-cron-startup-script.sh >> /var/log/cron.log 2>&1
fi

# 4. direnv
if command -v direnv >/dev/null 2>&1; then
  direnv allow .
fi

# 5. cron (for development)
if command -v cron >/dev/null 2>&1; then
  cron
fi

# 6. Setup ~/.bashrc for interactive shells
if ! grep -q "AUTO-GENERATED-BASHRC-SETUP" ~/.bashrc 2>/dev/null; then
  cat << 'EOF' >> ~/.bashrc

# AUTO-GENERATED-BASHRC-SETUP
if [ -d "/var/google-cloud-sdk/bin" ]; then
  export PATH=/var/google-cloud-sdk/bin:${PATH}
elif [ -d "/var/gcloud-sdk/google-cloud-sdk/bin" ]; then
  export PATH=/var/gcloud-sdk/google-cloud-sdk/bin:${PATH}
fi

if [ -n "${PROJECT_ID}" ] && [ ! -f /tmp/gcloud_auth_done ] && [ -f "./build-artifacts/provisioning-gsa.json" ]; then
  gcloud auth activate-service-account --key-file=./build-artifacts/provisioning-gsa.json --project "${PROJECT_ID}"
  gcloud auth configure-docker --quiet --verbosity=critical
  touch /tmp/gcloud_auth_done
fi

if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion bash)
fi

alias l="ls -al"
alias ll="ls -al"
alias ".."="cd .."

if [ -f "/var/consumer-edge-install/scripts/shell-install-helper.sh" ]; then
  source /var/consumer-edge-install/scripts/shell-install-helper.sh
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi
EOF
fi

# Add SSH Config to avoid fingerprint checking (if not exists)
mkdir -p ~/.ssh
if [ ! -f ~/.ssh/config ] || ! grep -q "StrictHostKeyChecking no" ~/.ssh/config; then
  echo -e "Host *\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
  chmod 600 ~/.ssh/config
fi

# 7. Print Help if entering interactive shell
if [ -f "/var/consumer-edge-install/scripts/shell-install-helper.sh" ] && [ "$#" -eq 0 ]; then
  source /var/consumer-edge-install/scripts/shell-install-helper.sh
  display_help
fi

# Execute passed command or drop into bash
if [ "$#" -eq 0 ]; then
  exec /bin/bash
else
  exec "$@"
fi
