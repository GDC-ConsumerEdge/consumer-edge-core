#!/bin/bash


ansible cloud_type_abm -i inventory/ --limit cnuc-1 -m shell -a "for((i=2;i<=4;i++)); do ping -c3 \"10.0.200.\$i\"; done"
