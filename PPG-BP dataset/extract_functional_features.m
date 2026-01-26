function result = extract_functional_features(all_features)
    % Extract function-based features from all_features array
    num_samples = length(all_features);
    features = [];
    names = {};
    for i = 1:num_samples
        try
            feat = all_features(i).function_based;
            % Extract all function-based fields
            field_names = fieldnames(feat);
            sample_features = [];
            
            for j = 1:length(field_names)
                field_name = field_names{j};
                field_value = feat.(field_name);
                
                if isnumeric(field_value) && isscalar(field_value)
                    sample_features(end+1) = field_value;
                    if i == 1
                        names{end+1} = ['Func_', field_name];
                    end
                end
            end
            
            features(i, :) = sample_features;
            
        catch ME
            if i == 1
                field_names = fieldnames(all_features(1).function_based);
                num_features = 0;
                for j = 1:length(field_names)
                    if isnumeric(all_features(1).function_based.(field_names{j})) && ...
                       isscalar(all_features(1).function_based.(field_names{j}))
                        num_features = num_features + 1;
                        names{end+1} = ['Func_', field_names{j}];
                    end
                end
                features = zeros(num_samples, num_features);
            end
            features(i, :) = 0;
        end
    end
    
    result.features = features;
    result.names = names;
end