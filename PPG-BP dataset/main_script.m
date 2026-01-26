% Main Script
clear all; close all; clc;
dataset_root_path = 'add_your_dataset_PPG-BP_path'; % dataset path: download dataset from the link: https://figshare.com/articles/dataset/PPG-BP_Database_zip/5459299
% PPG signal processing & extraction features
[all_features, dataset_info] = process_ppg_bp(dataset_root_path);
% Get the features and the target for building the ML and DL models
[X, y, feature_names, subject_info] = prepare_bp_classification_4class(all_features);
% export the features and the target to .csv file
data_table = array2table([X, y], 'VariableNames', [feature_names_complete, {'target'}]);
writetable(data_table, 'complete_dataset.csv', 'WriteMode', 'overwrite', 'Delimiter', ',');