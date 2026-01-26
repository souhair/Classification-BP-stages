function result = extract_basic_features(all_features)
    % Extract basic demographic features
    num_samples = length(all_features);
    % Define basic feature names
    basic_names = {'Age', 'BMI', 'HeartRate'};%, 'Weight', 'Height'};
    features = zeros(num_samples, length(basic_names));
    for i = 1:num_samples
        try
            if isfield(all_features(i), 'basic') && ~isempty(all_features(i).basic)
                feat = all_features(i).basic;
                features(i, 1) = get_field_safe(feat, 'age', 0);
                features(i, 2) = get_field_safe(feat, 'bmi', 0);
                features(i, 3) = get_field_safe(feat, 'heart_rate', 0);
%                 features(i, 4) = get_field_safe(feat, 'weight', 0);
%                 features(i, 5) = get_field_safe(feat, 'height', 0);
            else
                % Try to get from dataset_info as fallback
                features(i, 1) = get_field_safe(all_features(i).dataset_info, 'age', 0);
                features(i, 2) = get_field_safe(all_features(i).dataset_info, 'bmi', 0);
                features(i, 3) = get_field_safe(all_features(i).dataset_info, 'heart_rate', 0);
%                 features(i, 4) = get_field_safe(all_features(i).dataset_info, 'weight', 0);
%                 features(i, 5) = get_field_safe(all_features(i).dataset_info, 'height', 0);
            end
        catch
            features(i, :) = 0;
        end
    end
    
    result.features = features;
    result.names = basic_names;
end