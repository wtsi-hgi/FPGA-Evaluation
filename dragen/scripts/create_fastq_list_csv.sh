#!/usr/bin/env bash

set -euf -o pipefail

# Create a CSV file of all the fastq files that should be processed by dragen.

# Check both arguments have been supplied
if [ "${#@}" -ne 2 ]; then
  echo "Usage: create_fastq_list.sh [csv_file_name] [fastq_directory]
All parameters must be supplied with full path names.

It is assumed that the fastqs are organised into Library and then
Read Group ID directories:
fastq directory
  |
  --> Library directory
          |
          --> Read group ID directory
                      |
                      --> fast_1
                      --> fast_2
                      --> ...etc..."
  exit 1
fi

csv_file_name="${1}"
fastq_directory="${2%/}"

# Headers defined on the first row of the CSV
echo "RGID,RGSM,RGLB,Lane,Read1File,Read2File" >  $csv_file_name

# For each entry in the command line specified directory:
for val in $(ls "${fastq_directory}"); do

  if [ -d "${fastq_directory}/${val}" ]; then
    library_path="${fastq_directory}/${val}"
    library="${val}"

    for val in $(ls "${library_path}"); do
      read_group_path="${library_path}/${val}"

      if [ -d "${read_group_path}" ] && [ $(ls "${read_group_path}"  | grep -E '.fastq' | wc -l) -gt 0 ]; then
        RGID=$(basename "${read_group_path}")

        for entry in $(ls "${read_group_path}"); do

          if [[ "${entry}" =~ '.fastq' ]]; then
            fastq1="${read_group_path}/${entry}"

            # For Casava naming conventions used with the evaluation data.  The fields should be as follows:
            #     [0]      [1]    [2]    [3]             [4]
            # <SampleID>_<Index>_<Lane>_<Read>_<segment# and FileExt>
            IFS='_' read -a fields <<< "${entry}"

            # Check for R2 file.  This will be appended to the row in the csv.
            r2_file_to_check="${fields[0]}_${fields[1]}_${fields[2]}_R2_${fields[4]}"
            if [ $(ls "${read_group_path}" | grep "${r2_file_to_check}") ]; then

              # Remember to include the dir for full path name.
              fastq2="${read_group_path}/${r2_file_to_check}"
            fi

            # Extract the sample name and lane number
            RGSM=${fields[0]}
            if [[ ${fields[2]} =~ L0*([1-9]*) ]]; then
              Lane="${BASH_REMATCH[1]}"
            fi

            # Only create a csv row if the current file is R1, this is to stop R2 generating another row. (TODO: check this is correct.  What if there are just R2 fastq's)
            if [[ ${fields[3]} =~ 'R1' ]]; then
  
              # As per the header, the fields are as follows:
              # RGID, RGSM, RGLB, Lane, FASTQ1, [FASTQ2]     # With the fastq2 being optional but it must still be 'there'.
              echo "${RGID},${RGSM},${library},${Lane},${fastq1},${fastq2}" >> "${csv_file_name}"
            fi
          fi
        done 
      fi
    done
  fi
done

