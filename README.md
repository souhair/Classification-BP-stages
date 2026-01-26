# Classification-BP-stages
This repository created for classification the blood pressure stages using features extracted from the raw PPG signals (link of published article). We used two datasets to evaluate the proposed methodology under varied and realistic conditions. 
They are:

1- PPG-BP dataset: it contains 657 segments, 4 classes (Normal, Prehypertension, Hypertension stage 1, Hypertension stage 2).

2- PulseDB dataset: it contains 283773 segments, 3 classes (Normal, Prehypertension, Hypertension)

A feature extraction pipeline was implemented across 12 physiological domains.

The code implemented in MATLAB R2021a. 

To extract features of each dataset, just run the main_script.m in the dataset directory and you will get the csv file of all features and labels.
After getting the csv files, you can use the notebook in python directory to build the models of each dataset. 

you can download the datasets from: 

1- PPG-BP dataset: Liang, Y.; Chen, Z.; Liu, G.; Elgendi, M. A new, short-recorded photoplethysmogram dataset for blood pressure monitoring in China. Sci. Data 2018, 5, 180020. doi:10.1038/sdata.2018.20.

2- PulseDB dataset: Wang, W.; Mohseni, P.; Kilgore, K.L.; Najafizadeh, L. PulseDB: A large, cleaned dataset based on MIMIC-III and VitalDB for benchmarking cuff-less blood pressure estimation methods. Front. Digit. Health 2023, 4, 1090854. doi: 10.3389/fdgth.2022.1090854. 

You can download the csv file to run the model in python notebook using these links:

1- PPG-BP dataset: https://drive.google.com/file/d/1nBmCudkbawpY2aOibp0eEHin2ChPFzwz/view?usp=sharing

2- PulseDB dataset: https://drive.google.com/file/d/1Zi4FAFEzjGDTikwvYYQ2xc9rcRMZhRXA/view?usp=sharing
