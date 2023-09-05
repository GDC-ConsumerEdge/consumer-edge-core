#!/bin/bash

verbose_mode=false
output_file=""

# Create a new folder
function create_new_folder() {
    local folder_name=$1
    echo "Creating a new folder"
    cp -r build-artifacts-example ${folder_name}

}
# Switch to an existing folder
function switch_folder() {
    local folder_name=$1
    # Remove existing link
    rm -rf build-artifacts
    # Create a new link
    ln -s ${folder_name} build-artifacts
}

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo " -h, --help      Display this help message"
    echo " -v, --verbose   Enable verbose mode"
    echo " -e, --env       Name of the environment to use. Create new if not eixsts"
}

function has_argument() {
    [[ ("$1" == *=* && -n ${1#*=}) || (! -z "$2" && "$2" != -*) ]]
}

function extract_argument() {
    echo "${2:-${1#*=}}"
}

# Function to handle options and arguments
function handle_options() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while getopts ":vhe:" opt; do
        case $opt in
        h)
            usage
            exit 0
            ;;
        v)
            verbose_mode=true
            ;;
        e)
            output_file=${OPTARG}
            ;;
        *)
            echo "Invalid option: $1" >&2
            usage
            exit 1
            ;;
        esac
    done
}

# Main script execution
handle_options "$@"

if [ "$verbose_mode" = true ]; then
    echo "Verbose mode enabled."
fi

if [ -z "$output_file" ]; then
    echo "Output file specified: $output_file"
fi

# if [[ -d $folder_name ]]; then
#     echo "Folder $folder_name already exists"
#     exit 1
# fi
