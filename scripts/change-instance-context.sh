#! /bin/bash
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

# Take in 1 parameter (the name of the new build-artifacts Post-Fix Folder to use)

PREFIX_DIR=$(dirname -- "$0")
source ${PREFIX_DIR}/install-shell-helper.sh

MARKER="*"

want_new_folder=false
desired_folder="build-artifacts-example" # Default desired_folder
list_folders=false

while getopts lf: flag; do
    case "${flag}" in
    f) desired_folder=${OPTARG}; want_new_folder=true;;
    l) list_folders=true ;;
    esac
done

function get_list_of_folders() {
    local folders=$(ls -d ./build-artifacts-*)
    declare -a output=()

    for folder in $folders; do
        # Remove the "build-artifacts-" prefix
        fld="${folder#"./build-artifacts-"}"
        output+=( "$fld" )
    done

    echo "${output[@]}" # "${users[@]}"
}

function display_folders() {
    local active=""

    pretty_print "Available Instance Run Contexts\n=============================="

    if [[ ! -z "$1" ]]; then
        active=$1
    fi

    folders=$(get_list_of_folders)

    for folder in $folders; do
        # Add a marker to the active folder
        if [[ $folder == $active ]]; then
            line="${folder}${MARKER}"
            pretty_print "${line}" "INFO"
        else
            pretty_print $folder
        fi

    done

}

function get_active_folder() {

    current_folder=$(readlink build-artifacts)

    if [[ ! -z "${current_folder}" ]]; then
        current_folder=${current_folder#"build-artifacts-"}
    fi

    echo $current_folder
}

#### Main Execution

if [[ $list_folders == true ]]; then

    active_folder=$(get_active_folder)

    display_folders ${active_folder}
fi

# Change the active folder if -l used
if [[ ${want_new_folder} == true ]]; then
    # check if the desired folder is the same as the current
    active=$(get_active_folder)
    if [[ $desired_folder == $active ]]; then
        pretty_print "Current context is already ${active}, no action will be taken" "DEBUG"
    else
        # check to see if the desired folder is in the list of folders, if not, offer to create a new context

        available_folders=$(get_list_of_folders)

        found=false
        for f in $available_folders; do
            if [[ $f == $desired_folder ]]; then
                found=true
                break
            fi
        done

        # Case: if the desired folder is not found, ask to create it
        if [[ $found == false ]]; then
            pretty_print "The desired context '${desired_folder}' does not exist, would you like to create it? (y/n)"
            read answer
            if [[ $answer == "y" ]]; then
                pretty_print "Creating new context ${desired_folder}"
                # create new folder from example
                cp -r build-artifacts-example build-artifacts-${desired_folder}
                # remove old build-artifacts link
                rm -rf build-artifacts
                # Create new build-artifacts link
                ln -s build-artifacts-${desired_folder} build-artifacts
                echo "Please modify the files for the context before using it in a provisioning run" "INFO"
            else
                pretty_print "No action taken" "ERROR"
                exit 0
            fi
        else # Case: if the desired folder is found, change the context
            pretty_print "Setting Context to '${desired_folder}'" "INFO"
            rm -rf build-artifacts
            ln -s build-artifacts-${desired_folder} build-artifacts
            if [[ -x "$(command -v direnv)" ]]; then
                direnv allow .
            else
                pretty_print "direnv not installed, perhaps you should 'source .envrc'"
            fi

            pretty_print "Don't forget to check your gcloud current config"
        fi
    fi

fi

