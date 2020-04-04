#!/bin/bash
#
# Process data. This script should be run within the subject's folder.
#
# Usage:
#   ./process_data.sh <SUBJECT> <FILEPARAM>
#
# Example:
#   ./process_data.sh sub-03 parameters.sh
#
# Authors: Julien Cohen-Adad

# The following global variables are retrieved from parameters.sh but could be
# overwritten here:
# PATH_QC="~/qc"

# Uncomment for full verbose
set -v

# Immediately exit if error
set -e

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT

# Retrieve input params
SUBJECT=$1
FILEPARAM=$2


# FUNCTIONS
# ==============================================================================

# Check if manual segmentation already exists. If it does, copy it locally. If
# it does not, perform seg.
segment_if_does_not_exist(){
  local file="$1"
  local contrast="$2"
  # Update global variable with segmentation file name
  FILESEG="${file}_seg"
  if [ -e "${PATH_SEGMANUAL}/${FILESEG}-manual.nii.gz" ]; then
    echo "Found manual segmentation: ${PATH_SEGMANUAL}/${FILESEG}-manual.nii.gz"
    rsync -avzh "${PATH_SEGMANUAL}/${FILESEG}-manual.nii.gz" ${FILESEG}.nii.gz
    sct_qc -i ${file}.nii.gz -s ${FILESEG}.nii.gz -p sct_deepseg_sc -qc ${PATH_QC} -qc-subject ${SUBJECT}
  else
    # Segment spinal cord
    sct_deepseg_sc -i ${file}.nii.gz -c $contrast -qc ${PATH_QC} -qc-subject ${SUBJECT}
  fi
}


# SCRIPT STARTS HERE
# ==============================================================================
# Load environment variables
source $FILEPARAM
# Go to results folder, where most of the outputs will be located
cd $PATH_RESULTS
# Copy source images
mkdir -p data
cd data
cp -r $PATH_DATA/$SUBJECT .
cd ${SUBJECT}

# DWI
# ------------------------------------------------------------------------------
cd dwi
file_dwi="${SUBJECT}_dwi"
file_bval=${file_dwi}.bval
file_bvec=${file_dwi}.bvec
# Separate b=0 and DW images
sct_dmri_separate_b0_and_dwi -i ${file_dwi}.nii.gz -bvec ${file_bvec}
# Segment cord (1st pass -- just to get a rough centerline)
sct_propseg -i ${file_dwi}_dwi_mean.nii.gz -c dwi
# Create mask to help motion correction and for faster processing
sct_create_mask -i ${file_dwi}_dwi_mean.nii.gz -p centerline,${file_dwi}_dwi_mean_seg.nii.gz -size 30mm
# Crop data for faster processing
sct_crop_image -i ${file_dwi}.nii.gz -m mask_${file_dwi}_dwi_mean.nii.gz -o ${file_dwi}_crop.nii.gz
# Motion correction
sct_dmri_moco -i ${file_dwi}_crop.nii.gz -bvec ${file_dwi}.bvec -x spline
file_dwi=${file_dwi}_crop_moco
file_dwi_mean=${file_dwi}_dwi_mean
# Segment spinal cord (only if it does not exist)
segment_if_does_not_exist ${file_dwi_mean} "dwi"
file_dwi_seg=$FILESEG
# Create vertebral label C6 in the middle of the FOV
sct_label_utils -i ${file_dwi_seg}.nii.gz -create-seg -1,6 -o labelvert_c6.nii.gz
# Register template->dwi
sct_register_to_template -i ${file_dwi_mean}.nii.gz -s ${file_dwi_seg}.nii.gz -l labelvert_c6.nii.gz -ref subject -qc $PATH_QC
# Rename warping field for clarity
mv warp_template2anat.nii.gz warp_template2dwi.nii.gz
mv warp_anat2template.nii.gz warp_dwi2template.nii.gz
# Warp template
sct_warp_template -d ${file_dwi_mean}.nii.gz -w warp_template2dwi.nii.gz -qc ${PATH_QC} -qc-subject ${SUBJECT}
# Create mask around the spinal cord (for faster computing)
sct_maths -i ${file_dwi_seg}.nii.gz -dilate 3 -o ${file_dwi_seg}_dil.nii.gz
# Compute DTI using RESTORE
sct_dmri_compute_dti -i ${file_dwi}.nii.gz -bvec ${file_bvec} -bval ${file_bval} -method restore -m ${file_dwi_seg}_dil.nii.gz
# Compute FA, MD and RD in WM between C4 and T1 vertebral levels
metrics=(dti_FA dti_MD dti_RD)
for metric in ${metrics[@]}; do
  sct_extract_metric -i ${metric}.nii.gz -f label/atlas -l 51 -vert 4:8 -perlevel 1 -o ${PATH_RESULTS}/${metric}.csv -append 1
done
# Go back to parent folder
cd ..

# Verify presence of output files and write log file if error
# ------------------------------------------------------------------------------
FILES_TO_CHECK=(
  "dwi/label/atlas/PAM50_atlas_00.nii.gz"
  "dwi/dti_FA.nii.gz"
  "dwi/dti_MD.nii.gz"
  "dwi/dti_RD.nii.gz"
)
for file in ${FILES_TO_CHECK[@]}; do
  if [ ! -e $file ]; then
    echo "${SUBJECT}/${file} does not exist" >> $PATH_LOG/_error_check_output_files.log
  fi
done
