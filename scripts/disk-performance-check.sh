#!/bin/bash

TEST_DIR=`mktemp -d -p "$DIR"`
DISK_PATH=$1
RUNTIME="15s"

TEST_NAMES=( "write" "read" )
BLOCK_SIZES=( "4K" "128K" "1M")

function run_throughput_test {
    local TEST_NAME=$1
    local BLOCK_SIZE=$2
    sudo fio --name=${TEST_NAME}_throughput --filename=${DISK_PATH} --directory=$TEST_DIR --numjobs=16 \
        --size=10G --time_based --runtime=${RUNTIME} --ramp_time=2s --ioengine=libaio \
        --direct=1 --verify=0 --bs=${BLOCK_SIZE} --iodepth=64 --rw=${TEST_NAME} \
        --group_reporting=1 --iodepth_batch_submit=64 \
        --iodepth_batch_complete_max=64
}

function run_iops_test {
    local TEST_NAME=$1
    local BLOCK_SIZE=$2
    sudo fio --name=${TEST_NAME}_iops --filename=${DISK_PATH} --directory=$TEST_DIR \
        --size=10G --time_based --runtime=${RUNTIME} --ramp_time=2s --ioengine=libaio \
        --direct=1 --verify=0 --bs=${BLOCK_SIZE} --iodepth=256 --rw=rand${TEST_NAME} \
        --group_reporting=1 --iodepth_batch_submit=256 \
        --iodepth_batch_complete_max=256
}

echo "Using temp dir: ${TEST_DIR}"

for test in "${TEST_NAMES[@]}"
do
    for block_size in "${BLOCK_SIZES[@]}"
    do
        echo "======================================================"
        echo "= Test: ${test}_throughput, Block size: ${block_size}"
        echo "======================================================"
        run_throughput_test $test $block_size
        echo " "
        echo "======================================================"
        echo "= Test: ${test}_iops, Block size: ${block_size}"
        echo "======================================================"
        run_iops_test $test $block_size
        echo ""
        echo ""
    done
    echo ""
    echo ""
done

rm -rf $TEST_DIR
