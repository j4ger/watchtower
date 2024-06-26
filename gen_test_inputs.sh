#!/usr/bin/env bash

# this script generates csv files based on a file list
# it expects a file named "RECORDS" in $pwd
# should work without tweaks when placed inside the original MIT-BIH dataset directory

# requirements:
# wfdb toolchain compiled & placed in $PATH

wfdb_base="../../wfdb-10.7.0/build/bin"
rdsamp="$wfdb_base/rdsamp"
rdann="$wfdb_base/rdann"

dataset_base="../dataset/mitdb_1.0.0"

cd $dataset_base

# Path to the text file containing the list of filenames
file_list="RECORDS"

# Check if the file containing the list of filenames exists
if [[ ! -f "$file_list" ]]; then
    echo "The file $file_list does not exist."
    exit 1
fi

# Loop through each line in the file
while IFS= read -r file_name; do
    full_path="$dataset_base/$file_name"

    echo "Processing $full_path..."

    # Extract record
    csv_out="$file_name.csv"
    if [[ -f $csv_out ]]; then
      rm -f $csv_out
    fi
    $rdsamp -c -H -f 0 -v -pS -r $file_name > $csv_out

    # Extract annotations
    txt_out="$file_name.txt"
    if [[ -f $txt_out ]]; then
      rm -rf $txt_out
    fi
    $rdann -c 0 -f 0 -v -a atr -r $file_name > $txt_out

done < "$file_list"

echo "All files have been processed."
