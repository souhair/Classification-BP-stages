function [all_features, dataset_info] = process_large_dataset(dataset_root_path)
% PROCESS LARGE DATASET COMPLETE - Full pipeline for large dataset
% Processes all MAT files with Subj_Wins struct

    fprintf('=== LARGE DATASET PROCESSING ===\n\n');
    
    % Check if dataset path exists
    if ~exist(dataset_root_path, 'dir')
        error('Dataset root path not found: %s', dataset_root_path);
    end
    
    % Find all MAT files in the dataset directory
    mat_files = dir(fullfile(dataset_root_path, '*.mat'));
    
    if isempty(mat_files)
        error('No MAT files found in: %s', dataset_root_path);
    end
    
    fprintf('Found %d MAT files\n', length(mat_files));
    
    all_features = [];
    dataset_info = struct();
    dataset_info.total_files = length(mat_files);
    dataset_info.total_records = 0;
    dataset_info.processed_records = 0;
    dataset_info.failed_records = 0;
    
    % Process each MAT file
    for file_idx = 1:length(mat_files)
        mat_filename = mat_files(file_idx).name;
        mat_filepath = fullfile(dataset_root_path, mat_filename);
        
        fprintf('\nProcessing file %d/%d: %s\n', file_idx, length(mat_files), mat_filename);
        
        % Process all records in this MAT file
        file_features = process_large_dataset_file(mat_filepath);
        
        if ~isempty(file_features)
            all_features = [all_features, file_features];
            dataset_info.processed_records = dataset_info.processed_records + length(file_features);
        end
        dataset_info.total_records = dataset_info.total_records + length(file_features);
    end
    
    % Calculate success rate
    dataset_info.success_rate = (dataset_info.processed_records / dataset_info.total_records) * 100;
    
    fprintf('\n=== LARGE DATASET PROCESSING ===\n');
    fprintf('Total files: %d\n', dataset_info.total_files);
    fprintf('Total records: %d\n', dataset_info.total_records);
    fprintf('Successfully processed: %d\n', dataset_info.processed_records);
    fprintf('Failed: %d\n', dataset_info.failed_records);
    fprintf('Success rate: %.1f%%\n', dataset_info.success_rate);
end

function file_features = process_large_dataset_file(mat_filepath)
% PROCESS LARGE DATASET FILE - Process individual MAT file with Subj_Wins struct

    file_features = [];
    
    try
        % Load the MAT file
        mat_data = load(mat_filepath);
        
        % Check if Subj_Wins struct exists
        if ~isfield(mat_data, 'Subj_Wins')
            fprintf('    WARNING: Subj_Wins struct not found in %s\n', mat_filepath);
            return;
        end
        
        Subj_Wins = mat_data.Subj_Wins;
        
        % Get the number of records (assuming Subj_Wins is a struct array)
        num_records = length(Subj_Wins);
        
        fprintf('    Found %d records in file\n', num_records);
        
        % Process each record
        for record_idx = 1:num_records
            record_features = process_large_dataset_record(Subj_Wins(record_idx), mat_filepath, record_idx);
            
            if ~isempty(record_features)
                file_features = [file_features, record_features];
            end
        end
        
    catch ME
        fprintf('    ERROR processing file %s: %s\n', mat_filepath, ME.message);
        fprintf('    Error in function: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end
function features = process_large_dataset_record(record, mat_filepath, record_idx)
% PROCESS LARGE DATASET RECORD - Enhanced with unique subject ID

    features = [];
    
    try
        % Extract required fields from the record
        subject_id = get_field_safe(record, 'SubjectID', 'Unknown');
        segment_id = get_field_safe(record, 'SegmentID', 1);
        case_id = get_field_safe(record, 'CaseID', 'Unknown');
        age = get_field_safe(record, 'Age', 30);
        gender = get_field_safe(record, 'Gender', 'U');
        ppg_signal = get_field_safe(record, 'PPG_F', []);
        sbp = get_field_safe(record, 'SegSBP', 120);
        dbp = get_field_safe(record, 'SegDBP', 80);
        bmi = get_field_safe(record, 'BMI', 25);
        height = get_field_safe(record, 'Height', 170);
        weight = get_field_safe(record, 'Weight', 70);
        
        % Create unique subject identifier
        [~, filename, ~] = fileparts(mat_filepath);
        unique_subject_id = sprintf('%s_%s', filename, subject_id);
        
        % Validate PPG signal
        if isempty(ppg_signal) || length(ppg_signal) < 100
            fprintf('    WARNING: Invalid PPG signal for subject %s\n', unique_subject_id);
            return;
        end
        
        % Sampling rate for large dataset
        fs = 125; % Hz
        
        % Estimate pulse rate from PPG signal
        pulse_rate = estimate_pulse_rate_large_dataset(ppg_signal, fs);
        
        % Prepare inputs for feature extraction
        ppg_signals = {ppg_signal};
        pulse_rates = pulse_rate;
        ages = age;
        
        % Extract features using your existing function
        feature_struct = extract_pulse_wave_features(ppg_signals, pulse_rates, ages, fs);
        
        if ~isempty(feature_struct)
            % Get the first (and only) feature set
            features = feature_struct(1);
            
            % Add basic demographic data
            features.basic = struct();
            features.basic.age = age;
            features.basic.gender = gender;
            features.basic.height = height;
            features.basic.weight = weight;
            features.basic.bmi = bmi;
            features.basic.heart_rate = pulse_rate;
            
            % Add engineered features
            try
                features.engineered = extract_engineered_features_single(features, age, bmi, pulse_rate, weight, height);
            catch ME
                fprintf('    Warning: Engineered feature extraction failed: %s\n', ME.message);
                features.engineered = create_default_engineered_structure();
            end
            
            % Add comprehensive dataset information WITH UNIQUE SUBJECT ID
            features.dataset_info.unique_subject_id = unique_subject_id;  % THIS IS THE KEY FIELD
            features.dataset_info.subject_id = subject_id;
            features.dataset_info.segment_id = segment_id;
            features.dataset_info.case_id = case_id;
            features.dataset_info.age = age;
            features.dataset_info.gender = gender;
            features.dataset_info.height = height;
            features.dataset_info.weight = weight;
            features.dataset_info.bmi = bmi;
            features.dataset_info.sbp = sbp;
            features.dataset_info.dbp = dbp;
            features.dataset_info.heart_rate = pulse_rate;
            features.dataset_info.pulse_rate_method = 'PPG_Estimated';
            features.dataset_info.estimated_pulse_rate = pulse_rate;
            
            % Determine blood pressure category based on SBP/DBP
            features.dataset_info.bp_category = classify_blood_pressure(sbp, dbp);
            features.dataset_info.bp_category_3class = classify_blood_pressure_3class(sbp, dbp);
            
            % Add processing metadata
            features.dataset_info.processing_date = datestr(now);
            features.dataset_info.sampling_rate = fs;
            features.dataset_info.signal_length_seconds = length(ppg_signal) / fs;
            features.dataset_info.dataset_source = 'Large_Dataset';
            features.dataset_info.source_file = mat_filepath;
            features.dataset_info.record_index = record_idx;
            
        end
        
    catch ME
        fprintf('    ERROR processing record %d: %s\n', record_idx, ME.message);
        fprintf('    Error in function: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end

function pulse_rate = estimate_pulse_rate_large_dataset(ppg_signal, fs)
% ESTIMATE PULSE RATE FROM PPG SIGNAL - Optimized for large dataset (125 Hz)

    pulse_rate = 72; % Default fallback
    
    try
        % Preprocess PPG signal
        ppg_signal = ppg_signal - mean(ppg_signal);
        
        % Bandpass filter for heart rate range (0.5-4 Hz = 30-240 BPM)
        [b, a] = butter(3, [0.5, 4]/(fs/2), 'bandpass');
        ppg_filtered = filtfilt(b, a, ppg_signal);
        
        % Find peaks in filtered PPG signal
        min_peak_distance = round(0.4 * fs); % Minimum 0.4s between pulses
        min_peak_prominence = 0.1 * (max(ppg_filtered) - min(ppg_filtered));
        
        [~, locs] = findpeaks(ppg_filtered, 'MinPeakHeight', mean(ppg_filtered), ...
                             'MinPeakDistance', min_peak_distance, ...
                             'MinPeakProminence', min_peak_prominence);
        
        if length(locs) >= 2
            rr_intervals = diff(locs) / fs;
            % Remove outliers (RR intervals outside physiological range)
            valid_rr = rr_intervals(rr_intervals > 0.4 & rr_intervals < 2.0);
            if length(valid_rr) >= 2
                pulse_rate = 60 / mean(valid_rr);
            end
        end
        
        % Constrain to physiological range
        pulse_rate = max(40, min(180, pulse_rate));
        
    catch
        % Keep default value
    end
end

function bp_category = classify_blood_pressure_3class(sbp, dbp)
% CLASSIFY BLOOD PRESSURE 3CLASS - Generate 3-class classification
%
% Input:
%   sbp - systolic blood pressure
%   dbp - diastolic blood pressure
%
% Output:
%   bp_category - string with 3-class blood pressure category

    % Convert to double to ensure numeric comparison
    sbp_num = double(sbp);
    dbp_num = double(dbp);
    
    % 3-class classification:
    % 1. Normal: SBP < 120 AND DBP < 80
    % 2. Prehypertension/Stage 1: SBP 120-139 OR DBP 80-89
    % 3. Stage 2 Hypertension: SBP ≥ 140 OR DBP ≥ 90
    
    if (sbp_num < 120) && (dbp_num < 80)
        bp_category = "Normal";
    elseif (sbp_num >= 140) || (dbp_num >= 90)
        bp_category = "Stage 2 Hypertension";
    else
        bp_category = "Prehypertension_Stage1";
    end
end

% You'll also need to add this helper function if it doesn't exist:
function value = get_field_safe(structure, field_name, default_value)
    % Safely get field value from structure
    try
        if isfield(structure, field_name)
            value = structure.(field_name);
            if isempty(value)
                value = default_value;
            end
            % Handle numeric conversion if needed
            if isnumeric(default_value) && ischar(value)
                value = str2double(value);
                if isnan(value)
                    value = default_value;
                end
            end
        else
            value = default_value;
        end
    catch
        value = default_value;
    end
end