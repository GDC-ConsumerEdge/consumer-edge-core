#!/bin/bash
# Copyright 2023 Google LLC
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

### This script is used to count the number of disks that are ONLINE as reported by Robin
### This is most commonly used during Robin installation, but could be run any time

EXPECTED="$1"

if [[ -z "${EXPECTED}" ]]; then
  echo "ERROR: Expected number of disks to be passed as first argument"
  exit 1
fi

declare -a COUNT=( )
COUNT+=( $(robin disk list --role all --headers wwn,status --json | jq -r '.items[] | select( .status | test("ONLINE")) | .wwn') )

LEN=${#COUNT[@]}

if [[ ${LEN} -ne $EXPECTED ]]; then
  echo "ERROR: Expected ${EXPECTED} disks to be ONLINE, but have ${LEN}"
  exit 1
else
  echo "SUCCESS: Expected ${EXPECTED} disks to be ONLINE, and have ${LEN}"
  exit 0
fi