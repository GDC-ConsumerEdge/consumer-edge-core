#!/bin/bash

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
