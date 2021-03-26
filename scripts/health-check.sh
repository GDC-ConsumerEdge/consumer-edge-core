#!/bin/bash

ansible workers -i ../inventory.yml -m ansible.builtin.ping --one-line
