#!/bin/bash

ansible workers -i ../inventory.yaml -m ansible.builtin.ping --one-line
