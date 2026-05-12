#!/bin/bash
# Copyright 2026 Google LLC
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

ERROR_COLOR="\e[1;31m"
INFO_COLOR="\e[1;37m"
WARN_COLOR="\e[1;33m"
DEBUG_COLOR="\e[1;35m"
DEFAULT_COLOR="\e[1;32m"
ENDCOLOR="\e[0m"
BOLD="\e[1m"

function pretty_print() {
    MSG=$1
    LEVEL=${2:-DEFAULT}

    if [[ -z "${MSG}" ]]; then
        return
    fi

    case "$LEVEL" in
        "DEFAULT")
            printf "${DEFAULT_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
        "ERROR")
            printf "${ERROR_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
        "WARN")
            printf "${WARN_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
        "INFO")
            printf "${INFO_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
        "DEBUG")
            printf "${DEBUG_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
        "SUCCESS")
            printf "${DEFAULT_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
        *)
            printf "${DEFAULT_COLOR}${MSG}${ENDCOLOR}\n" >&2
            ;;
    esac
}

function display_help() {
	VAR_EXTRAS_STRING=""
	if [[ -f "./build-artifacts/instance-run-vars.yaml" ]]; then
		VAR_EXTRAS_STRING="--extra-vars=\"@build-artifacts/instance-run-vars.yaml\""
	fi

    pretty_print "\n=============================="
    pretty_print "Starting the docker container. You can run the following commands (cut-copy-paste):"
    pretty_print "=============================="
	pretty_print "===        INSTALL         ==="
	pretty_print "=============================="
    pretty_print "1: Check Health: \n\n${WARN_COLOR}./scripts/health-check.sh${ENDCOLOR}\n"
    pretty_print "2: Run Install: \n\n${WARN_COLOR}ansible-playbook all-full-install.yml -i inventory ${VAR_EXTRAS_STRING}${ENDCOLOR}\n"
    pretty_print "3: Exit after install"
    pretty_print "=============================="
	pretty_print "===       UNINSTALL        ==="
	pretty_print "=============================="
    pretty_print "1. Uninstall cluster: \n\n${WARN_COLOR}ansible-playbook all-remove-abm-software.yml -i inventory ${VAR_EXTRAS_STRING} --tags never${ENDCOLOR}\n"
    pretty_print "=============================="
	pretty_print "===          SSH           ==="
	pretty_print "=============================="
	pretty_print "\n${WARN_COLOR}ssh -F build-artifacts/ssh-config [host-name]${ENDCOLOR}\n"
	pretty_print "=============================="
    pretty_print "\nType ${BOLD}${ERROR_COLOR}\"help-me\"${DEFAULT_COLOR} at any time to display this message\n"
}

function trim_key_file() {
    local target_file="$1"
    if [[ -f "$target_file" ]]; then
        local content=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Trim trailing whitespace using Bash parameter expansion
            content+="${line%${line##*[![:space:]]}}"$'\n'
        done < "$target_file"
        # Strip trailing newline to match $(cat) behavior if needed, and write back
        printf "%s\n" "${content%$'\n'}" > "$target_file"
    fi
}
