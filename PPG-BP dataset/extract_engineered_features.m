function result = extract_engineered_features(all_features)
    % Extract engineered features for all samples
    num_samples = length(all_features);
    
    % Get field names from first sample to determine feature count
    if num_samples > 0 && isfield(all_features(1), 'engineered')
        field_names = fieldnames(all_features(1).engineered);
        num_features = length(field_names);
        features = zeros(num_samples, num_features);
        names = cell(1, num_features);
        
        for j = 1:num_features
            names{j} = ['Eng_', field_names{j}];
        end
    else
        % Default structure if no engineered features found
        default_engineered = {
            'Age_x_THD', 'Age_x_Stiffness', 'Age_x_HeartRate', ...
            'BMI_x_HarmonicRatio', 'BMI_x_Stiffness', 'BMI_x_PulseArea', ...
            'CV_Stress_Index', 'Dipping_Age_Risk_Proxy', 'Dipping_Stiffness_Risk', ...
            'Dipping_Stiffness_Age_Index', 'Dipping_BMI_Risk', 'Dipping_Autonomic_Function', ...
            'HTN_Waveform_Signature', 'HTN_Resistance_Proxy', 'HTN_Progression_Risk', ...
            'HTN_Reflection_Intensity', 'HTN_Prehyper_Discriminator', ...
            'Clinical_ISH_Proxy', 'Clinical_Young_HT_Pattern', ...
            'Pulse_Pressure_Proxy', 'Arterial_Health_Index', ...
            'Vascular_Age_Gap', 'BP_Risk_Score'
        };
        num_features = length(default_engineered);
        features = zeros(num_samples, num_features);
        names = cell(1, num_features);
        for j = 1:num_features
            names{j} = ['Eng_', default_engineered{j}];
        end
    end
    
    % Extract features for each sample
    for i = 1:num_samples
        try
            if isfield(all_features(i), 'engineered')
                feat = all_features(i).engineered;
                for j = 1:num_features
                    if j <= length(field_names)
                        field_name = field_names{j};
                        if isfield(feat, field_name)
                            field_value = feat.(field_name);
                            if isnumeric(field_value) && isscalar(field_value)
                                features(i, j) = field_value;
                            else
                                features(i, j) = 0;
                            end
                        else
                            features(i, j) = 0;
                        end
                    else
                        features(i, j) = 0;
                    end
                end
            else
                features(i, :) = 0;
            end
        catch
            features(i, :) = 0;
        end
    end
    
    result.features = features;
    result.names = names;
    
    fprintf('    -> %d engineered features extracted\n', num_features);
end