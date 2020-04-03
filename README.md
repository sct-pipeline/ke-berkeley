# ke-berkeley
Pipeline to process DWI data

## Requirements

This pipeline was tested with [SCT v4.2.2](https://github.com/neuropoly/spinalcordtoolbox/releases/tag/4.2.2).

The dataset should be organized according to BIDS structure:

~~~
DATA/
└──	data/
		└── sub-01
		    |── anat
		    |   └── sub-01_T2w.nii.gz
				|		└── sub-01_T2w.json
		    |   └── sub-01_survey.nii.gz
				|		└── sub-01_survey.json
		    └── dwi
		        └── sub-01_dwi.nii.gz
		        └── sub-01_dwi.json
		        └── sub-01_dwi.bval
		        └── sub-01_dwi.bvec
~~~

## Installation

Clone this repository
```
git clone https://github.com/sct-pipeline/ke-berkeley.git
cd ke-berkeley
PATH_REPOS=`pwd`
```

Copy the file `parameters.sh` in the folder `DATA/`

## How to run

Go to `DATA/` folder and run:
```
sct_run_batch parameters.sh $PATH_REPOS/process_data.sh
```

The pipeline outputs:
- `DATA/log/`: Log files for each subject
- `DATA/qc/`: QC report
- `DATA/results/`: Result folder with all processed data and quantitative results.
