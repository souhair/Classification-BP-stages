function result = extract_nonlinear_features(all_features)
    % Nonlinear and complexity features
    num_samples = length(all_features);
    features = [];
    names = {};
    
    for i = 1:num_samples
        try
            feat = all_features(i).nonlinear;
            
            % Extract all nonlinear fields
            field_names = fieldnames(feat);
            sample_features = [];
            
            for j = 1:length(field_names)
                field_name = field_names{j};
                field_value = feat.(field_name);
                
                if isnumeric(field_value) && isscalar(field_value)
                    sample_features(end+1) = field_value;
                    if i == 1
                        names{end+1} = ['Nonlin_', field_name];
                    end
                end
            end
            
            features(i, :) = sample_features;   
        catch ME
            if i == 1
                % Determine feature size from first sample
                field_names = fieldnames(all_features(1).nonlinear);
                num_features = 0;
                for j = 1:length(field_names)
                    if isnumeric(all_features(1).nonlinear.(field_names{j})) && ...
                       isscalar(all_features(1).nonlinear.(field_names{j}))
                        num_features = num_features + 1;
                        names{end+1} = ['Nonlin_', field_names{j}];
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