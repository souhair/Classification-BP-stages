function analyze_dataset_composition(all_features)
% dataset composition analysis that handles multiple data structures

    fprintf('   Analyzing data structure...\n');
    
    % Determine the data structure type
    if iscell(all_features)
        fprintf('   Data type: Cell array with %d elements\n', length(all_features));
    % analyze_cell_structure(all_features);
    elseif isstruct(all_features)
        fprintf('   Data type: Structure array\n');
        analyze_struct_structure(all_features);
    else
        fprintf('   Data type: Unknown (%s)\n', class(all_features));
        fprintf('   Please check the data structure\n');
    end
end
function analyze_struct_structure(all_features_struct)
% Analyze structure array

    total_records = 0;
    dataset_counts = containers.Map();
    
    if length(all_features_struct) == 1
        % Single structure
        current_item = all_features_struct;
        dataset_name = extract_dataset_name(current_item);
        record_count = count_records(current_item);
        
        dataset_counts(dataset_name) = record_count;
        total_records = record_count;
        
        fprintf('     Single structure: %s, %d records\n', dataset_name, record_count);
        fprintf('     Fields: %s\n', strjoin(fieldnames(current_item), ', '));
    else
        % Structure array
        for i = 1:length(all_features_struct)
            current_item = all_features_struct(i);
            dataset_name = extract_dataset_name(current_item);
            record_count = count_records(current_item);
            
            if isKey(dataset_counts, dataset_name)
                dataset_counts(dataset_name) = dataset_counts(dataset_name) + record_count;
            else
                dataset_counts(dataset_name) = record_count;
            end
            total_records = total_records + record_count;
        end
    end
    
    display_composition_results(dataset_counts, total_records);
end

function dataset_name = extract_dataset_name(item)
% Extract dataset name from various possible field locations
    dataset_name = 'Unknown';   
    if isfield(item, 'dataset_info') && isstruct(item.dataset_info) && isfield(item.dataset_info, 'dataset_name')
        dataset_name = item.dataset_info.dataset_name;
    elseif isfield(item, 'dataset_name')
        dataset_name = item.dataset_name;
    elseif isfield(item, 'source_dataset')
        dataset_name = item.source_dataset;
    elseif isfield(item, 'dataset')
        dataset_name = item.dataset;
    end
end

function record_count = count_records(item)
% Count records from various possible field locations
    record_count = 1; % Default
    
    if isfield(item, 'features') && ~isempty(item.features)
        record_count = size(item.features, 1);
    elseif isfield(item, 'feature_vector') && ~isempty(item.feature_vector)
        record_count = size(item.feature_vector, 1);
    elseif isfield(item, 'data') && ~isempty(item.data)
        record_count = size(item.data, 1);
    elseif isfield(item, 'X') && ~isempty(item.X)
        record_count = size(item.X, 1);
    end
end

function display_composition_results(dataset_counts, total_records)
% Display the composition results
    fprintf('   Dataset composition:\n');
    dataset_keys = keys(dataset_counts);
    for i = 1:length(dataset_keys)
        count = dataset_counts(dataset_keys{i});
        percentage = (count / total_records) * 100;
        fprintf('     %s: %d records (%.1f%%)\n', dataset_keys{i}, count, percentage);
    end
    fprintf('   Total: %d records\n', total_records);
end