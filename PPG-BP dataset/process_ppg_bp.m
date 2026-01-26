function [all_features, dataset_info] = process_ppg_bp(dataset_root_path)
    % This function for processing all 219 subjects with 3 segments each (657 total records)
    % Inputs: dataset_root_path: the dataset path: you can download the dataset from -> https://figshare.com/articles/dataset/PPG-BP_Database_zip/5459299
    % Outputs: all_features: Structure of the extracted features from PPG signals 
    %          dataset_info: Structure of the dataset information 
    fprintf('=== PPG-BP DATASET PROCESSING ===\n\n');
    % Check if dataset path exists
    if ~exist(dataset_root_path, 'dir'),error('Dataset root path not found: %s', dataset_root_path);end
    % Define paths
    data_file_path = fullfile(dataset_root_path, 'PPG-BP Database', 'Data File');
    metadata_file = fullfile(data_file_path, 'PPG-BP dataset.xlsx');
    sqi_file = fullfile(dataset_root_path, 'Table 1.xlsx');
    subjects_folder = fullfile(data_file_path, '0_subject');
    % Check if all required files/folders exist
    if ~exist(metadata_file, 'file'),error('Metadata file not found: %s', metadata_file);end
    if ~exist(sqi_file, 'file'),error('SQI file not found: %s', sqi_file);end
    if ~exist(subjects_folder, 'dir'),error('Subjects folder not found: %s', subjects_folder);end
    fprintf('Loading metadata from: %s\n', metadata_file);
    metadata = readtable(metadata_file, 'VariableNamingRule', 'preserve'); % Use 'VariableNamingRule', 'preserve' to keep original column names
    fprintf('Loading SQI data from: %s\n', sqi_file);
    sqi_data = readtable(sqi_file, 'VariableNamingRule', 'preserve');
    fprintf('Found %d subjects in metadata\n', height(metadata));
    fprintf('Found %d SQI records\n', height(sqi_data));
    % Display column names for debugging
    fprintf('Metadata columns:\n'); disp(metadata.Properties.VariableNames');
    fprintf('SQI data columns:\n'); disp(sqi_data.Properties.VariableNames');
    all_features = []; dataset_info = struct();
    dataset_info.total_subjects = height(metadata);dataset_info.total_segments = 0;dataset_info.processed_segments = 0;dataset_info.failed_segments = 0;
    % Process each subject
    for subject_idx = 1:height(metadata)
        subject_id = metadata.("subject_ID")(subject_idx);
        fprintf('\nProcessing subject %d/%d: %d\n', subject_idx, height(metadata), subject_id);
        % Process all 3 segments for this subject
        for segment_idx = 1:3
            segment_features = process_ppg_bp_segment(subjects_folder, metadata, sqi_data, subject_idx, segment_idx);
            if ~isempty(segment_features)
                all_features = [all_features, segment_features];
                dataset_info.processed_segments = dataset_info.processed_segments + 1;
            else
                dataset_info.failed_segments = dataset_info.failed_segments + 1;
            end
            dataset_info.total_segments = dataset_info.total_segments + 1;
        end
    end
    % Calculate success rate
    dataset_info.success_rate = (dataset_info.processed_segments / dataset_info.total_segments) * 100;
    fprintf('\n=== DATASET PROCESSING COMPLETE ===\n');
    fprintf('Total subjects: %d\n', dataset_info.total_subjects);
    fprintf('Total segments: %d\n', dataset_info.total_segments);
    fprintf('Successfully processed: %d\n', dataset_info.processed_segments);
    fprintf('Failed: %d\n', dataset_info.failed_segments);
    fprintf('Success rate: %.1f%%\n', dataset_info.success_rate);
end


function features = process_ppg_bp_segment(subjects_folder, metadata, sqi_data, subject_idx, segment_idx)
    % Process PPG-BP segment - Process individual PPG segment with all metadata
    % Output: features: struct for all extracted features
    % Input: subjects_folder: the subject folder
    %        metadata: metadata for this subject 
    %        sqi_data: the sqi data
    %        subject_idx: subject ID
    %        segment_idx: segment ID
    features = [];
    try      
        subject_id = metadata.("subject_ID")(subject_idx); % Get subject ID from metadata 
        % Construct PPG filename (e.g., 2_1.txt, 2_2.txt, 2_3.txt)
        ppg_filename = sprintf('%d_%d.txt', subject_id, segment_idx);
        ppg_filepath = fullfile(subjects_folder, ppg_filename);
        % Check if PPG file exists
        if ~exist(ppg_filepath, 'file')
            fprintf('    WARNING: PPG file not found: %s\n', ppg_filename);
            return;
        end       
        ppg_signal = load(ppg_filepath); % Load PPG signal from text file
        % Basic signal validation
        if length(ppg_signal) < 100
            fprintf('    WARNING: PPG signal too short in %s\n', ppg_filename);
            return;
        end
        % Extract metadata for this subject using the preserved column names
        age = metadata.("Age(year)")(subject_idx);
        gender = metadata.("Sex(M/F)")(subject_idx);
        height = metadata.("Height(cm)")(subject_idx);
        weight = metadata.("Weight(kg)")(subject_idx);
        sbp = metadata.("Systolic Blood Pressure(mmHg)")(subject_idx);
        dbp = metadata.("Diastolic Blood Pressure(mmHg)")(subject_idx);
        heart_rate = metadata.("Heart Rate(b/m)")(subject_idx);
        bmi = metadata.("BMI(kg/m^2)")(subject_idx);
        % Extract disease information - handle potential missing columns
        hypertension = get_table_value_safe(metadata, "Hypertension", subject_idx, '');
        diabetes = get_table_value_safe(metadata, "Diabetes", subject_idx, '');
        cerebral_infarction = get_table_value_safe(metadata, "cerebral infarction", subject_idx, '');
        cerebrovascular_disease = get_table_value_safe(metadata, "cerebrovascular disease", subject_idx, '');
        % Validate age
        if age < 18 || age > 120
            fprintf('    WARNING: Invalid age %d for subject %d - using default 30\n', age, subject_id);
            age = 30;
        end
        % Find SQI for this segment
        sqi_value = get_sqi_value(sqi_data, subject_id, segment_idx);
        % Estimate pulse rate (use provided heart rate or estimate from PPG)
        fs = 1000; % Sampling rate for PPG-BP dataset is 1000 Hz
        if ~isnan(heart_rate) && heart_rate > 30 && heart_rate < 200
            pulse_rate = heart_rate;
            pulse_rate_method = 'Provided_HR';
        else
            pulse_rate = estimate_pulse_rate_ppg_bp(ppg_signal, fs);
            pulse_rate_method = 'PPG_Estimated';
        end
        % Prepare inputs for feature extraction - Single subject processing
        ppg_signals = {ppg_signal};
        pulse_rates = pulse_rate;
        ages = age;
        % Extract features. For single subject processing
        feature_struct = extract_pulse_wave_features(ppg_signals, pulse_rates, ages, fs);
        if ~isempty(feature_struct)
            % Get the first (and only) feature set
            features = feature_struct(1);
            % Add demographic data to the feature structure
            features.basic = struct();
            features.basic.age = age;
            features.basic.gender = gender;
            features.basic.height = height;
            features.basic.weight = weight;
            features.basic.bmi = bmi;
            features.basic.heart_rate = heart_rate;
            try
                % Add engineered features
                features.engineered = extract_engineered_features_single(features, age, bmi, heart_rate, weight, height);
            catch ME
                fprintf('    Warning: Engineered feature extraction failed: %s\n', ME.message);
                % Create default engineered structure
                features.engineered = create_default_engineered_structure();
            end
            % Add comprehensive dataset information
            features.dataset_info.subject_id = subject_id;
            features.dataset_info.segment_id = segment_idx;
            features.dataset_info.age = age;
            features.dataset_info.gender = gender;
            features.dataset_info.height = height;
            features.dataset_info.weight = weight;
            features.dataset_info.bmi = bmi;
            features.dataset_info.sbp = sbp;
            features.dataset_info.dbp = dbp;
            features.dataset_info.heart_rate = heart_rate;
            features.dataset_info.pulse_rate_method = pulse_rate_method;
            features.dataset_info.estimated_pulse_rate = pulse_rate;
            features.dataset_info.skewness_sqi = sqi_value;
            % Add disease information
            features.dataset_info.hypertension = hypertension;
            features.dataset_info.diabetes = diabetes;
            features.dataset_info.cerebral_infarction = cerebral_infarction;
            features.dataset_info.cerebrovascular_disease = cerebrovascular_disease;
            % Determine blood pressure category based on SBP/DBP
%             features.dataset_info.bp_category = classify_blood_pressure(sbp, dbp);
            features.dataset_info.bp_category = hypertension;
            % Add processing metadata
            features.dataset_info.processing_date = datestr(now);
            features.dataset_info.sampling_rate = fs;
            features.dataset_info.signal_length_seconds = length(ppg_signal) / fs;
            features.dataset_info.dataset_source = 'PPG-BP Database';
            features.dataset_info.reference = 'Liang et al. Sci Data 5:180020 (2018)';
            
        end 
    catch ME
        fprintf('    ERROR processing segment %d for subject %d: %s\n', segment_idx, subject_id, ME.message);
        fprintf('    Error in function: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end
function value = get_table_value_safe(table, column_name, row_idx, default_value)
% GET TABLE VALUE SAFE - Safely extract value from table with error handling
    try
        if ismember(column_name, table.Properties.VariableNames)
            value = table.(column_name)(row_idx);
            if iscell(value),value = value{1};end
        else
            value = default_value;
        end
    catch
        value = default_value;
    end
end
function sqi_value = get_sqi_value(sqi_data, subject_id, segment_idx)
% GET SQI VALUE - Extract skewness SQI from Table 1 data 
    sqi_value = NaN;
    try
        % Find the row for this subject in SQI data
        subject_rows = find(sqi_data.("subject ID") == subject_id);
        if isempty(subject_rows)
            fprintf('    WARNING: No SQI data found for subject %d\n', subject_id);
            return;
        end
        % Extract SQI for the requested segment
        switch segment_idx
            case 1
                sqi_value = sqi_data.("segment 1")(subject_rows(1));
            case 2
                sqi_value = sqi_data.("segment 2")(subject_rows(1));
            case 3
                sqi_value = sqi_data.("Segment 3")(subject_rows(1));
        end
    catch ME
        fprintf('    WARNING: Could not extract SQI for subject %d segment %d\n', subject_id, segment_idx);
    end
end

function pulse_rate = estimate_pulse_rate_ppg_bp(ppg_signal, fs)
    % estimate_pulse_rate_ppg_bp: Function for estimation the pulse rate from PPG signal 
    % Inputs: ppg_signal: The PPG signal, fs: the sampling frequency in Hz
    % Output: pulse_rate: The pulse rate value
    pulse_rate = 72; % Default value
    try
        ppg_signal = ppg_signal - mean(ppg_signal); % Preprocess PPG signal 
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
        pulse_rate = max(40, min(180, pulse_rate)); % Constrain to physiological range
        
    catch
        % Keep default value
    end
end
