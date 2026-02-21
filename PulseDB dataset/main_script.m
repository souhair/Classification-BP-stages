clear; close all; clc;
fprintf('=== DATASET PROCESSING ===\n');
[all_datasets_features, dataset_info] = process_large_dataset(dataset_path);
fprintf('\n=== RUNNING COMPREHENSIVE ANALYSIS ===\n\n');

% Debug: Check what we're passing to the analysis
fprintf('Data type: %s\n', class(all_datasets_features));
if iscell(all_datasets_features)
    fprintf('Cell array with %d elements\n', length(all_datasets_features));
    if ~isempty(all_datasets_features)
        fprintf('First element type: %s\n', class(all_datasets_features{1}));
        if isstruct(all_datasets_features{1})
            fprintf('First element fields: %s\n', strjoin(fieldnames(all_datasets_features{1}), ', '));
        end
    end
elseif isstruct(all_datasets_features)
    fprintf('Structure with %d elements\n', length(all_datasets_features));
    if ~isempty(all_datasets_features)
        fprintf('First element fields: %s\n', strjoin(fieldnames(all_datasets_features(1)), ', '));
    end
end

fprintf('\n=== RUNNING COMPREHENSIVE ANALYSIS ===\n\n');

% 1. Dataset composition analysis
fprintf('1. Analyzing dataset composition...\n');

% Handle different data structures more robustly
analyze_dataset_composition(all_datasets_features);

% 2. Prepare features with subject isolation
fprintf('\n2. Preparing features with subject isolation...\n');
[X, y, feature_names, subject_info] = prepare_features_subject_isolation(all_datasets_features);

if isempty(X)
    fprintf('❌ No valid samples for analysis\n');
    return;
end

fprintf('   Final dataset: %d samples, %d features\n', size(X, 1), size(X, 2));
fprintf('   Class distribution:\n');
unique_classes = unique(y);
for i = 1:length(unique_classes)
    class_count = sum(y == unique_classes(i));
    if isfield(subject_info, 'label_map') && ~isempty(subject_info.label_map)
        class_name = get_key_from_value(subject_info.label_map, unique_classes(i));
    else
        class_name = sprintf('Class%d', unique_classes(i));
    end
    fprintf('     %s: %d samples (%.1f%%)\n', ...
        class_name, class_count, class_count/length(y)*100);
end
data_table = array2table([X, y], 'VariableNames', [feature_names, {'target'}]);
writetable(data_table, 'complete_dataset.csv', 'WriteMode', 'overwrite', 'Delimiter', ',');

