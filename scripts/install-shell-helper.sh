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

ERROR_COLOR="\e[1;31m"
INFO_COLOR="\e[1;37m"
WARN_COLOR="\e[1;33m"
DEBUG_COLOR="\e[1;35m"
DEFAULT_COLOR="\e[1;32m"
ENDCOLOR="\e[0m"

function pretty_print() {
    MSG=$1
    LEVEL=${2:-DEFAULT}

    if [[ -z "${MSG}" ]]; then
        return
    fi

    case "$LEVEL" in
        "DEFAULT")
            printf "${DEFAULT_COLOR}${MSG}${ENDCOLOR}\n"
            ;;
        "ERROR")
            printf "${ERROR_COLOR}${MSG}${ENDCOLOR}\n"
            ;;
        "WARN")
            printf "${WARN_COLOR}${MSG}${ENDCOLOR}\n"
            ;;
        "INFO")
            printf "${INFO_COLOR}${MSG}${ENDCOLOR}\n"
            ;;
        "DEBUG")
            printf "${DEBUG_COLOR}${MSG}${ENDCOLOR}\n"
            ;;
        *)
            echo "NO MATCH"
            ;;
    esac
}

function display_help() {
    pretty_print "\n=============================="
    pretty_print "Starting the docker container. You will need to run the following 2 commands (cut-copy-paste)"
    pretty_print "=============================="
    pretty_print "1: ./scripts/health-check.sh"
    pretty_print "2: ansible-playbook all-full-install.yml -i inventory ${VAR_EXTRAS_STRING}"
    pretty_print "3: Type 'exit' to exit the Docker shell after installation"
    pretty_print "=============================="
    pretty_print "Thank you for using the quick helper script!"
    pretty_print "(you are now inside the Docker shell)"
    pretty_print "\nType "help-me" at any time to display this message\n"
}

alias "help-me"="display_help"