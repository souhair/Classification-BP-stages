function result = extract_stiffness_features(all_features)
    % Extract stiffness features
    num_samples = length(all_features);
    features = [];
    names = {};
    
    for i = 1:num_samples
        try
            feat = all_features(i).stiffness;
            field_names = fieldnames(feat);
            sample_features = [];
            
            for j = 1:length(field_names)
                field_name = field_names{j};
                field_value = feat.(field_name);
                
                if isnumeric(field_value) && isscalar(field_value)
                    sample_features(end+1) = field_value;
                    if i == 1
                        names{end+1} = ['Stiff_', field_name];
                    end
                end
            end
            
            features(i, :) = sample_features;
            
        catch
            if i == 1
                field_names = fieldnames(all_features(1).stiffness);
                num_features = 0;
                for j = 1:length(field_names)
                    if isnumeric(all_features(1).stiffness.(field_names{j})) && ...
                       isscalar(all_features(1).stiffness.(field_names{j}))
                        num_features = num_features + 1;
                        names{end+1} = ['Stiff_', field_names{j}];
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