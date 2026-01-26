function [X, y, feature_names, subject_info] = prepare_bp_classification_4class(all_features)
% Prepare BP Classification 4Class - Includes all features for 4-class classification
    
    fprintf('  Extracting features and labels (3-class mode)...\n');
    
    num_records = length(all_features);
    
    % Extract labels for 4-class classification
    label_map = containers.Map();
    label_map('Normal') = 1;
    label_map('Prehypertension') = 2; 
    label_map('Stage 1 hypertension') = 3;  
    label_map('Stage 2 hypertension') = 4;
    
    y = zeros(num_records, 1);
    valid_indices = [];
    
    for i = 1:num_records
        try
            % Use the 4-class classification
            sbp = all_features(i).dataset_info.sbp;
            dbp = all_features(i).dataset_info.dbp;
            bp_cat = all_features(i).dataset_info.hypertension;            
            if isKey(label_map, bp_cat)
                y(i) = label_map(bp_cat);
                valid_indices = [valid_indices, i];
                all_features(i).dataset_info.bp_category_4class = bp_cat;
            end
        catch
            continue;
        end
    end
    
    fprintf('  Valid samples found: %d/%d\n', length(valid_indices), num_records);
    
    if isempty(valid_indices)
        error('No valid samples found');
    end
    
    % Extract ALL feature categories 
    feature_categories = {
        'basic', 'morphology', 'function_based', 'temporal', 'variability', ...
        'derivative', 'spectral', 'nonlinear', 'beat_shape', 'stiffness', ...
        'composite', 'engineered'
    };
    
    all_features_list = {};
    all_names_list = {};
    
    for cat_idx = 1:length(feature_categories)
        category = feature_categories{cat_idx};
        fprintf('  Extracting %s features...\n', category);
        
        try
            switch category
                case 'basic'
                    result = extract_basic_features(all_features(valid_indices));
                case 'morphology'
                    result = extract_morphology_features(all_features(valid_indices));
                case 'function_based'
                    result = extract_functional_features(all_features(valid_indices));
                case 'temporal'
                    result = extract_temporal_features(all_features(valid_indices));
                case 'variability'
                    result = extract_variability_features(all_features(valid_indices));
                case 'derivative'
                    result = extract_derivative_features(all_features(valid_indices));
                case 'spectral'
                    result = extract_spectral_features(all_features(valid_indices));
                case 'nonlinear'
                    result = extract_nonlinear_features(all_features(valid_indices));
                case 'beat_shape'
                    result = extract_beat_shape_features(all_features(valid_indices));
                case 'stiffness'
                    result = extract_stiffness_features(all_features(valid_indices));
                case 'composite'
                    result = extract_composite_features(all_features(valid_indices));
                case 'engineered'
                    result = extract_engineered_features(all_features(valid_indices));
            end
            
            if ~isempty(result.features) && size(result.features, 2) > 0
                all_features_list{end+1} = result.features;
                all_names_list = [all_names_list, result.names];
                fprintf('    -> %d features extracted\n', size(result.features, 2));
            else
                fprintf('    -> No features extracted\n');
            end
            
        catch ME
            fprintf('    -> ERROR: %s\n', ME.message);
        end
    end
    
    % Combine all features
    X = [];
    for i = 1:length(all_features_list)
        X = [X, all_features_list{i}];
    end
    
    y = y(valid_indices);
    
    subject_info.valid_indices = valid_indices;
    subject_info.label_map = label_map;
    subject_info.num_features = size(X, 2);
    subject_info.num_samples = size(X, 1);
    subject_info.feature_categories = feature_categories;
    
    feature_names = all_names_list;
    
    fprintf('  Final dataset: %d samples, %d features\n', size(X, 1), size(X, 2));
    
    % Display class distribution for 4 classes
    unique_labels = unique(y);
    fprintf('  4-Class Distribution:\n');
    for i = 1:length(unique_labels)
        label = unique_labels(i);
        count = sum(y == label);
        category_name = get_key_from_value(label_map, label);
        percentage = count / length(y) * 100;
        fprintf('    %s: %d samples (%.1f%%)\n', category_name, count, percentage);
    end
end