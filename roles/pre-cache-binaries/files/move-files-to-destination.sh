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


BASE_FOLDER=$1

### Error checking to fail-fast if provided varaible is not folder
if [[ -z "${BASE_FOLDER}" ]]; then
    echo "Need to provide a base folder containing the configuration and bin/ folder"
    exit 1
fi

## Fail fast if config file does not exist
if [[ ! -f "${BASE_FOLDER}/config.csv" ]]; then
    echo "config.csv file does not exist in ${BASE_FOLDER}"
    exit 1
fi

## For each line in the file, split by "," and assign to rec_column*
while IFS="," read -r rec_column1 rec_column2
do
   echo "cp ${BASE_FOLDER}/bin/$rec_column1 $rec_column2"
   cp "${BASE_FOLDER}/bin/$rec_column1" "$rec_column2" && true
done < <(tail ${BASE_FOLDER}/config.csv)
