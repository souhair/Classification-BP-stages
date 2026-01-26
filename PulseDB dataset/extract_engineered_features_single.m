function engineered = extract_engineered_features_single(feat, age, bmi, heart_rate, weight, height)
    % Extract engineered features based on clinical knowledge and interactions
    
    % Define default fields first (BEFORE any operations)
    default_engineered = {
        % Basic interactions
        'Age_x_THD', 'Age_x_Stiffness', 'Age_x_HeartRate', ...
        'BMI_x_HarmonicRatio', 'BMI_x_Stiffness', 'BMI_x_PulseArea', ...
        'CV_Stress_Index', ...% Nocturnal dipping proxies
        'Dipping_Age_Risk_Proxy', 'Dipping_Stiffness_Risk', ...
        'Dipping_Stiffness_Age_Index', 'Dipping_BMI_Risk', ...
        'Dipping_Autonomic_Function', ...        % Hypertension-specific
        'HTN_Waveform_Signature', 'HTN_Resistance_Proxy', ...
        'HTN_Progression_Risk', 'HTN_Reflection_Intensity', ...
        'HTN_Prehyper_Discriminator', ...        % Clinical knowledge
        'Clinical_ISH_Proxy', 'Clinical_Young_HT_Pattern', ...        % Additional engineered features
        'Pulse_Pressure_Proxy', 'Arterial_Health_Index', ...
        'Vascular_Age_Gap', 'BP_Risk_Score'
    };
    
    engineered = struct();
    
    % Initialize all fields to 0 first
    for i = 1:length(default_engineered)
        engineered.(default_engineered{i}) = 0;
    end
    
    try
        % Get required base feature values with safe access
        spec_thd = get_field_safe(feat.spectral, 'total_harmonic_distortion', 0);
        spec_hr = get_field_safe(feat.spectral, 'harmonic_ratio', 0);
        stiff_pwv = get_field_safe(feat.stiffness, 'pwv_proxy_2', 0);
        func_phi = get_field_safe(feat.function_based, 'Phi_mean', 0);
        morph_area = get_field_safe(feat.morphology, 'mean_area_systolic', 0);
        morph_amplitude = get_field_safe(feat.morphology, 'mean_amplitude', 0);
        
        % Ensure all values are scalar
        spec_thd = ensure_scalar(spec_thd);
        spec_hr = ensure_scalar(spec_hr);
        stiff_pwv = ensure_scalar(stiff_pwv);
        func_phi = ensure_scalar(func_phi);
        morph_area = ensure_scalar(morph_area);
        morph_amplitude = ensure_scalar(morph_amplitude);
        age = ensure_scalar(age);
        bmi = ensure_scalar(bmi);
        heart_rate = ensure_scalar(heart_rate);
        weight = ensure_scalar(weight);
        height = ensure_scalar(height);
        
        % 1. BASIC INTERACTION FEATURES
        if age > 0 && ~isnan(age)
            engineered.Age_x_THD = age * spec_thd;
            engineered.Age_x_Stiffness = age * stiff_pwv;
            engineered.Age_x_HeartRate = age * heart_rate;
        end
        
        if bmi > 0 && ~isnan(bmi)
            engineered.BMI_x_HarmonicRatio = bmi * spec_hr;
            engineered.BMI_x_Stiffness = bmi * stiff_pwv;
            engineered.BMI_x_PulseArea = bmi * morph_area;
        end
        
        % Cardiovascular Stress Index
        if age > 0 && bmi > 0 && heart_rate > 0 && ...
           ~isnan(age) && ~isnan(bmi) && ~isnan(heart_rate)
            engineered.CV_Stress_Index = (age / 50) * (bmi / 25) * (heart_rate / 70);
        end
        
        % 2. NOCTURNAL DIPPING PROXY FEATURES
        if age > 0 && ~isnan(age)
            engineered.Dipping_Age_Risk_Proxy = 1 ./ (1 + exp(-0.08*(age - 45)));
        end
        
        if age > 0 && stiff_pwv > 0 && ~isnan(age) && ~isnan(stiff_pwv)
            engineered.Dipping_Stiffness_Risk = (stiff_pwv * (age / 50)) / 10;
            engineered.Dipping_Stiffness_Age_Index = stiff_pwv * log(age + 1);
        end
        
        if bmi > 0 && ~isnan(bmi)
            engineered.Dipping_BMI_Risk = bmi / 30;
        end
        
        if heart_rate > 0 && spec_thd > 0 && ~isnan(heart_rate) && ~isnan(spec_thd)
            engineered.Dipping_Autonomic_Function = (60 ./ heart_rate) * spec_thd;
        end
        
        % 3. HYPERTENSION-SPECIFIC FEATURES
        if spec_thd > 0 && func_phi > 0 && ~isnan(spec_thd) && ~isnan(func_phi)
            engineered.HTN_Waveform_Signature = spec_thd * (1 - func_phi);
        end
        
        if morph_area > 0 && heart_rate > 0 && ~isnan(morph_area) && ~isnan(heart_rate)
            engineered.HTN_Resistance_Proxy = morph_area / (heart_rate + eps);
        end
        
        if age > 0 && bmi > 0 && stiff_pwv > 0 && ...
           ~isnan(age) && ~isnan(bmi) && ~isnan(stiff_pwv)
            engineered.HTN_Progression_Risk = (age / 50) * (bmi / 25) * stiff_pwv;
        end
        
        if spec_hr > 0 && spec_thd > 0 && ~isnan(spec_hr) && ~isnan(spec_thd)
            engineered.HTN_Reflection_Intensity = spec_hr * spec_thd;
        end
        
        if age > 0 && bmi > 0 && ~isnan(age) && ~isnan(bmi)
            engineered.HTN_Prehyper_Discriminator = double((age > 45) && (bmi > 27));
        end
        
        % 4. CLINICAL KNOWLEDGE FEATURES
        if age > 0 && stiff_pwv > 0 && ~isnan(age) && ~isnan(stiff_pwv)
            engineered.Clinical_ISH_Proxy = double(age > 60) * stiff_pwv;
        end
        
        if age > 0 && bmi > 0 && ~isnan(age) && ~isnan(bmi)
            engineered.Clinical_Young_HT_Pattern = double(age < 40) * bmi;
        end
        
        % 5. ADDITIONAL ENGINEERED FEATURES
        % Pulse Pressure Proxy
        if morph_amplitude > 0 && stiff_pwv > 0 && ~isnan(morph_amplitude) && ~isnan(stiff_pwv)
            engineered.Pulse_Pressure_Proxy = morph_amplitude * stiff_pwv;
        end
        
        % Arterial Health Index
        if spec_thd > 0 && stiff_pwv > 0 && ~isnan(spec_thd) && ~isnan(stiff_pwv)
            engineered.Arterial_Health_Index = spec_thd / (stiff_pwv + eps);
        end
        
        % Vascular Age Gap
        if age > 0 && stiff_pwv > 0 && ~isnan(age) && ~isnan(stiff_pwv)
            vascular_age = stiff_pwv * 20; % Simplified conversion
            engineered.Vascular_Age_Gap = vascular_age - age;
        end
        
        % Comprehensive BP Risk Score
        if age > 0 && bmi > 0 && stiff_pwv > 0 && spec_thd > 0 && ...
           ~isnan(age) && ~isnan(bmi) && ~isnan(stiff_pwv) && ~isnan(spec_thd)
            engineered.BP_Risk_Score = (age/80) * 0.3 + (bmi/40) * 0.2 + ...
                                      (stiff_pwv/10) * 0.3 + ((1-spec_thd)/1) * 0.2;
        end
        
    catch ME
        fprintf('  Warning: Engineered feature extraction failed: %s\n', ME.message);
        % Re-initialize all fields to 0 on error using the predefined list
        for i = 1:length(default_engineered)
            engineered.(default_engineered{i}) = 0;
        end
    end
end

function scalar_value = ensure_scalar(value)
    % Ensure the value is a scalar
    if isempty(value)
        scalar_value = 0;
    elseif ~isscalar(value)
        % If it's an array, take the mean
        scalar_value = mean(value(:));
    else
        scalar_value = value;
    end
end