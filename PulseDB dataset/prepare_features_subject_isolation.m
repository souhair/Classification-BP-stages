function [X, y, feature_names, subject_info] = prepare_features_subject_isolation(all_features)
% PREPARE FEATURES WITH SUBJECT TRACKING - WITH ORIGINAL FEATURE NAMES
    fprintf('  Extracting features with subject isolation...\n');  
    num_records = length(all_features);  
    % Extract labels for 3-class classification
    label_map = containers.Map();
    label_map('Normal') = 1;
    label_map('Prehypertension_Stage1') = 2;
    label_map('Stage 2 Hypertension') = 3;
    
    y = zeros(num_records, 1);
    subject_ids = cell(num_records, 1);
    dataset_sources = cell(num_records, 1);
    valid_indices = [];
    
    fprintf('  Checking %d records for valid BP data...\n', num_records);
    
    % First pass: identify valid samples
    for i = 1:num_records
        try
            % Check if required fields exist
            if ~isfield(all_features(i).dataset_info, 'sbp') || ~isfield(all_features(i).dataset_info, 'dbp')
                continue;
            end
            
            sbp = all_features(i).dataset_info.sbp;
            dbp = all_features(i).dataset_info.dbp;
            bp_cat = classify_blood_pressure_3class(sbp, dbp);
            
            if isKey(label_map, bp_cat)
                y(i) = label_map(bp_cat);
                
                % Use unique_subject_id if it exists
                if isfield(all_features(i).dataset_info, 'unique_subject_id')
                    subject_ids{i} = all_features(i).dataset_info.unique_subject_id;
                else
                    % Create fallback unique subject ID
                    if isfield(all_features(i).dataset_info, 'subject_id')
                        subject_id = all_features(i).dataset_info.subject_id;
                    else
                        subject_id = sprintf('SUBJ_%d', i);
                    end
                    if isfield(all_features(i).dataset_info, 'source_file')
                        [~, filename, ~] = fileparts(all_features(i).dataset_info.source_file);
                        subject_ids{i} = sprintf('%s_%s', filename, subject_id);
                    else
                        subject_ids{i} = sprintf('FILE_%d_%s', i, subject_id);
                    end
                end
                
                % Dataset source
                if isfield(all_features(i).dataset_info, 'dataset_name')
                    dataset_sources{i} = all_features(i).dataset_info.dataset_name;
                else
                    dataset_sources{i} = 'Unknown_Dataset';
                end
                
                valid_indices = [valid_indices, i];
            end
            
        catch
            continue;
        end
    end
    
    fprintf('  Valid samples found: %d/%d\n', length(valid_indices), num_records);
    
    if isempty(valid_indices)
        fprintf('  ❌ NO VALID SAMPLES FOUND!\n');
        X = []; y = []; feature_names = {}; subject_info = struct();
        return;
    end
    
    % Extract ALL feature names from the first valid record
    fprintf('  Extracting original feature names...\n');
    
    % Get feature names from the feature structure
    feature_names = extract_all_feature_names(all_features(valid_indices(1)));
    
    % Create feature matrix
    X = zeros(length(valid_indices), length(feature_names));
    
    % Populate feature matrix
    fprintf('  Populating feature matrix for %d samples and %d features...\n', ...
        length(valid_indices), length(feature_names));
    
    for i = 1:length(valid_indices)
        idx = valid_indices(i);
        try
            % Extract features using the same structure path
            feat_vector = extract_all_features_from_structure(all_features(idx), feature_names);
            X(i, :) = feat_vector;
        catch ME
            fprintf('  Warning: Error extracting features for sample %d: %s\n', idx, ME.message);
            X(i, :) = NaN(1, length(feature_names));
        end
        
        % Progress reporting
        if mod(i, 50000) == 0
            fprintf('    Processed %d/%d samples\n', i, length(valid_indices));
        end
    end
    
    fprintf('    Completed processing all %d samples\n', length(valid_indices));
    
    % Handle missing values and remove zero-variance features
%     [X, feature_names] = handle_missing_values_with_names(X, feature_names);
    
    % Update subject info for valid indices only
    subject_info.unique_subject_ids = subject_ids(valid_indices);
    subject_info.dataset_sources = dataset_sources(valid_indices);
    subject_info.valid_indices = valid_indices;
    subject_info.label_map = label_map;
    
    y = y(valid_indices);
    
    % Final dimension check
    assert(size(X, 2) == length(feature_names), ...
        'Final dimension mismatch: X has %d columns, feature_names has %d elements', ...
        size(X, 2), length(feature_names));
    assert(iscell(feature_names), 'feature_names must be a cell array');
    
    % Display some feature names for verification
    fprintf('  First 20 feature names:\n');
    for i = 1:min(20, length(feature_names))
        fprintf('    %d. %s\n', i, feature_names{i});
    end
    fprintf('  ... (total %d features)\n', length(feature_names));
    
    % Analyze subject distribution
    analyze_subject_distribution(subject_info, y);
end

function [X_clean, feature_names_clean] = handle_missing_values_with_names(X, feature_names)
% Handle missing values in feature matrix AND update feature names accordingly
    
    fprintf('  Handling missing values...\n');
    
    % Count missing values
    nan_count = sum(sum(isnan(X)));
    total_elements = numel(X);
    
    if nan_count > 0
        fprintf('    Found %d NaN values (%.1f%% of total)\n', nan_count, (nan_count/total_elements)*100);
    end
    
    % Replace NaN with column mean
    for col = 1:size(X, 2)
        col_data = X(:, col);
        nan_mask = isnan(col_data);
        
        if any(nan_mask)
            col_mean = mean(col_data(~nan_mask), 'omitnan');
            if isnan(col_mean)
                col_mean = 0;
            end
            X(nan_mask, col) = col_mean;
        end
    end
    
    % Remove features with zero variance
    feature_std = std(X, 0, 1);
    non_zero_var_mask = feature_std > 1e-10;
    
    zero_var_features = sum(~non_zero_var_mask);
    if zero_var_features > 0
        fprintf('    Removing %d features with zero variance\n', zero_var_features);
        
        % Get the names of features being removed
        removed_indices = find(~non_zero_var_mask);
        fprintf('    Removed feature indices: ');
        fprintf('%d ', removed_indices);
        fprintf('\n');
        
        % Keep only features with non-zero variance
        X_clean = X(:, non_zero_var_mask);
        feature_names_clean = feature_names(non_zero_var_mask);
        
        % Display which features were removed
        fprintf('    Removed feature names:\n');
        for i = 1:length(removed_indices)
            idx = removed_indices(i);
            fprintf('      %d. %s\n', idx, feature_names{idx});
        end
    else
        X_clean = X;
        feature_names_clean = feature_names;
    end
    
    fprintf('    Final feature matrix: %d samples × %d features\n', size(X_clean, 1), size(X_clean, 2));
end

function feature_names = extract_all_feature_names(feature_struct)
% Extract ALL feature names from the feature structure
    
    feature_names = {};
    
    try
        % Top-level scalar features
        top_level_scalars = {'subject_id', 'age', 'p_coefficient'};
        for i = 1:length(top_level_scalars)
            if isfield(feature_struct, top_level_scalars{i})
                feature_names{end+1} = top_level_scalars{i};
            end
        end
        
        % Define all feature categories from your structure
        feature_categories = {
            'morphology',  ...    % 26 fields
            'function_based',...  % 15 fields
            'temporal',  ...      % 4 fields
            'variability',  ...   % 7 fields
            'derivative',  ...    % 11 fields
            'spectral',    ...    % 8 fields
            'nonlinear',   ...    % 8 fields
            'beat_shape',   ...   % 7 fields
            'stiffness',    ...   % 7 fields
            'composite',   ...    % 5 fields
            'basic',        ...   % 6 fields
            'engineered'          % 23 fields
        };
        
        % Extract features from each category
        for cat_idx = 1:length(feature_categories)
            category = feature_categories{cat_idx};
            
            if isfield(feature_struct, category) && isstruct(feature_struct.(category))
                fields = fieldnames(feature_struct.(category));
                
                for field_idx = 1:length(fields)
                    field_name = fields{field_idx};
                    
                    % Check if this field contains a scalar numeric value
                    val = feature_struct.(category).(field_name);
                    
                    if isscalar(val) && isnumeric(val)
                        % Add with category prefix
                        feature_names{end+1} = [category '_' field_name];
                    elseif isstruct(val)
                        % Handle nested structures (if any)
                        nested_fields = fieldnames(val);
                        for nested_idx = 1:length(nested_fields)
                            nested_val = val.(nested_fields{nested_idx});
                            if isscalar(nested_val) && isnumeric(nested_val)
                                feature_names{end+1} = [category '_' field_name '_' nested_fields{nested_idx}];
                            end
                        end
                    end
                end
            end
        end
        
        fprintf('    Extracted %d feature names from structure\n', length(feature_names));
        
        % Verify we have features from all categories
        fprintf('    Feature distribution by category:\n');
        for cat_idx = 1:length(feature_categories)
            category = feature_categories{cat_idx};
            count = sum(startsWith(feature_names, [category '_']));
            if count > 0
                fprintf('      %s: %d features\n', category, count);
            end
        end
        
        % Also report top-level features
        top_level_count = 0;
        for i = 1:length(top_level_scalars)
            if isfield(feature_struct, top_level_scalars{i})
                top_level_count = top_level_count + 1;
            end
        end
        fprintf('      Top-level: %d features\n', top_level_count);
        
    catch ME
        fprintf('    Error extracting feature names: %s\n', ME.message);
        % Try a simpler approach as fallback
        feature_names = extract_simple_feature_names(feature_struct);
    end
end

function feat_vector = extract_all_features_from_structure(feature_struct, feature_names)
% Extract feature values for given feature names
    
    feat_vector = zeros(1, length(feature_names));
    
    for i = 1:length(feature_names)
        feat_name = feature_names{i};
        
        try
            % Check if it's a top-level scalar feature
            if isfield(feature_struct, feat_name) && isscalar(feature_struct.(feat_name))
                feat_vector(i) = feature_struct.(feat_name);
                continue;
            end
            
            % Handle features with underscore (category_field format)
            if contains(feat_name, '_')
                parts = strsplit(feat_name, '_');
                
                % Try to find the category
                category_found = false;
                for j = 1:length(parts)
                    potential_category = strjoin(parts(1:j), '_');
                    if isfield(feature_struct, potential_category)
                        % This might be the category
                        sub_field = strjoin(parts(j+1:end), '_');
                        
                        if ~isempty(sub_field) && isfield(feature_struct.(potential_category), sub_field)
                            val = feature_struct.(potential_category).(sub_field);
                            if isscalar(val) && isnumeric(val)
                                feat_vector(i) = val;
                                category_found = true;
                                break;
                            end
                        end
                    end
                end
                
                if ~category_found
                    % Try direct extraction with underscores
                    for j = length(parts):-1:1
                        category_candidate = strjoin(parts(1:j), '_');
                        field_candidate = strjoin(parts(j+1:end), '_');
                        
                        if isfield(feature_struct, category_candidate) && ...
                           isfield(feature_struct.(category_candidate), field_candidate)
                            val = feature_struct.(category_candidate).(field_candidate);
                            if isscalar(val) && isnumeric(val)
                                feat_vector(i) = val;
                                break;
                            end
                        end
                    end
                end
            end
            
        catch
            feat_vector(i) = NaN;
        end
    end
end

function feature_names = extract_simple_feature_names(feature_struct)
% Simple fallback method to extract feature names
    
    feature_names = {};
    
    % Get all field names
    all_fields = fieldnames(feature_struct);
    
    for i = 1:length(all_fields)
        field_name = all_fields{i};
        val = feature_struct.(field_name);
        
        if isstruct(val)
            % Get sub-fields
            sub_fields = fieldnames(val);
            for j = 1:length(sub_fields)
                sub_val = val.(sub_fields{j});
                if isscalar(sub_val) && isnumeric(sub_val)
                    feature_names{end+1} = [field_name '_' sub_fields{j}];
                end
            end
        elseif isscalar(val) && isnumeric(val)
            feature_names{end+1} = field_name;
        end
    end
    
    fprintf('    Fallback: Extracted %d feature names\n', length(feature_names));
end

function analyze_subject_distribution(subject_info, y)
% Analyze subject distribution across classes
    
    unique_subjects = unique(subject_info.unique_subject_ids);
    
    fprintf('\n  Subject Distribution Analysis:\n');
    fprintf('    Total unique subjects: %d\n', length(unique_subjects));
    fprintf('    Total samples: %d\n', length(y));
    
    if length(unique_subjects) > 0
        fprintf('    Samples per subject (avg): %.1f\n', length(y)/length(unique_subjects));
        
        % Count subjects per class
        subject_classes = containers.Map();
        for i = 1:length(subject_info.unique_subject_ids)
            subject = subject_info.unique_subject_ids{i};
            class_id = y(i);
            
            if ~isKey(subject_classes, subject)
                subject_classes(subject) = class_id;
            elseif subject_classes(subject) ~= class_id
                % Subject appears in multiple classes
                subject_classes(subject) = -1; % Mark as ambiguous
            end
        end
        
        % Count classes
        class_counts = zeros(1, 3);
        ambiguous_count = 0;
        subjects = keys(subject_classes);
        
        for i = 1:length(subjects)
            class_id = subject_classes(subjects{i});
            if class_id > 0 && class_id <= 3
                class_counts(class_id) = class_counts(class_id) + 1;
            elseif class_id == -1
                ambiguous_count = ambiguous_count + 1;
            end
        end
        
        class_names = {'Normal', 'Prehypertension/Stage1', 'Stage 2 Hypertension'};
        for class_id = 1:3
            fprintf('    Class %d (%s): %d unique subjects\n', class_id, class_names{class_id}, class_counts(class_id));
        end
        if ambiguous_count > 0
            fprintf('    Ambiguous (multiple classes): %d subjects\n', ambiguous_count);
        end
    end
    
    % Count samples per class
    for class_id = 1:3
        class_count = sum(y == class_id);
        fprintf('    Class %d samples: %d (%.1f%%)\n', class_id, class_count, (class_count/length(y))*100);
    end
end