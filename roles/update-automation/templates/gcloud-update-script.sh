#!/bin/bash

if [[ -x "$(command -v gcloud)"]]; then
    gcloud components update --quiet
fi
