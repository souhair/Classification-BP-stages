function features = extract_pulse_wave_features(ppg_signals, pulse_rates, ages, fs)
% Robust pulse wave feature extraction
    fprintf('=== ROBUST PULSE WAVE FEATURE EXTRACTION ===\n\n');
    % Process signals using existing function
    results = process_pulse_wave(ppg_signals, pulse_rates, ages, fs);    
    features = [];    
    for i = 1:length(results)
        fprintf('Extracting features for subject %d (Age: %d)...\n', i, results(i).age);
        
        try
            % Create the main feature structure
            feat = struct();
            feat.subject_id = i;
            feat.age = results(i).age;
            feat.p_coefficient = results(i).p_coefficient;
            cycles = results(i).cycle_analysis;
            ppg_signal = ppg_signals{i};

            % 1. BASIC MORPHOLOGY FEATURES 
            feat.morphology = extract_morphology_features_single(results(i));
            % 2. FUNCTION-BASED FEATURES 
            feat.function_based = extract_function_features_single(cycles, results(i).p_coefficient);
            % 3. TEMPORAL FEATURES 
            feat.temporal = extract_temporal_features_single(cycles, results(i).step_data);
            % 4. VARIABILITY FEATURES
            feat.variability = extract_variability_features_single(cycles);
            % 5. WAVEFORM DERIVATIVE FEATURES
            feat.derivative = extract_robust_derivative_features_single(ppg_signal, fs);
            % 6. SPECTRAL FEATURES
            feat.spectral = extract_robust_spectral_features_single(ppg_signal, fs, pulse_rates(i));
            % 7. NONLINEAR DYNAMICS FEATURES
            feat.nonlinear = extract_nonlinear_features_single(ppg_signal);
            % 8. BEAT-TO-BEAT SHAPE FEATURES
            feat.beat_shape = extract_beat_shape_features_single(cycles, results(i));
            % 9. ARTERIAL STIFFNESS INDICATORS
            feat.stiffness = extract_stiffness_features_single(feat, results(i).age);
            % 10. COMPOSITE CLINICAL INDICES
            feat.composite = extract_composite_indices_single(feat);

            features = [features, feat];
            
            fprintf('  Successfully extracted features\n');
            
        catch ME
            fprintf('  ERROR processing subject %d: %s\n', i, ME.message);
            fprintf('  Error in function: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
            % Create minimal feature structure with all required fields
            feat = create_complete_feature_structure(i, results(i).age, results(i).p_coefficient);
            features = [features, feat];
        end
    end
    
    fprintf('\n=== ROBUST ENHANCED FEATURE EXTRACTION COMPLETE ===\n');
    fprintf('Processed %d subjects successfully\n', length(features));
end

function morphology = extract_morphology_features_single(result)
    % Extract morphology features for a single subject 
    morphology = struct();
    try
        cycles = result.cycle_analysis;
        step_data = result.step_data; 
        % Basic counts
        morphology.peak_count = length(result.extrema.peaks.locations);
        morphology.valley_count = length(result.extrema.valleys.locations);
        % Amplitude statistics
        all_amplitudes = step_data.amplitudes;
        morphology.mean_amplitude = mean(all_amplitudes);
        morphology.amplitude_std = std(all_amplitudes);
        morphology.amplitude_range = max(all_amplitudes) - min(all_amplitudes);
        morphology.mean_systolic_peak_amplitude = mean(result.extrema.systolic_peak_amplitude);
        morphology.mean_diastolic_peak_amplitude = mean(result.extrema.diastolic_peak_amplitude);
        % Pulse Area Features
        morphology.mean_area_systolic = mean(result.area_systolic);
        morphology.mean_area_diastolic = mean(result.area_diastolic);
        % Slope Features
        morphology.max_rising_slope = mean(result.max_rising_slope);
        morphology.max_falling_slope = mean(result.max_falling_slope);
        morphology.slope_ratio = mean(result.slope_ratio);
        morphology.avg_mean_ppgs = mean(result.mean_ppg);
        morphology.variance_ppgs = mean(result.variance_ppg);
        morphology.skewness_ppgs = mean(result.skewness_ppg);
        morphology.kurtosis_ppgs = mean(result.kurtosis_ppg);
        morphology.median_ppgs = mean(result.median_ppg);
        morphology.mad_ppgs = mean(result.mad_ppg);
        % Percentile-based features
        morphology.p25_ppg = mean(result.p25_ppg);
        morphology.p75_ppg = mean(result.p75_ppg);
        morphology.iqr_ppg = mean(result.iqr_ppg);       
        % Step characteristics
        morphology.mean_step_duration = mean(step_data.durations);
        morphology.step_duration_std = std(step_data.durations);      
        % Pulse wave characteristics
        if ~isempty(cycles)
            rise_times = [];
            decay_times = [];
            for j = 1:length(cycles)
                if j <= length(result.extrema.peaks.locations) && j <= length(result.extrema.valleys.locations)
                    peak_idx = result.extrema.peaks.locations(j);
                    valley_idx = result.extrema.valleys.locations(j);
                    if j == 1
                        rise_start = 1;
                    else
                        rise_start = result.extrema.valleys.locations(j-1);
                    end
                    
                    if peak_idx > rise_start && valley_idx > peak_idx
                        rise_times(j) = step_data.times(peak_idx) - step_data.times(rise_start);
                        decay_times(j) = step_data.times(valley_idx) - step_data.times(peak_idx);
                    end
                end
            end
            
            if ~isempty(rise_times)
                morphology.mean_rise_time = mean(rise_times);
                morphology.mean_decay_time = mean(decay_times);
                morphology.rise_decay_ratio = mean(rise_times) / mean(decay_times);
            else
                morphology.mean_rise_time = 0;
                morphology.mean_decay_time = 0;
                morphology.rise_decay_ratio = 0;
            end
        else
            morphology.mean_rise_time = 0;
            morphology.mean_decay_time = 0;
            morphology.rise_decay_ratio = 0;
        end
        
    catch
        % Set default values if extraction fails
        morphology = create_default_morphology_structure();
    end
end

function func_feat = extract_function_features_single(cycles, p)
    % Extract function-based features for a single subject
    func_feat = struct();  
    try
        if isempty(cycles)
            func_feat = create_default_function_structure();
            return;
        end        
        F_values = [cycles.F_value];
        Phi_values = [cycles.Phi_value];
        Psi_values = [cycles.Psi_value];  
        % Central tendencies
        func_feat.F_mean = mean(F_values);
        func_feat.F_std = std(F_values);
        func_feat.F_cv = func_feat.F_std / func_feat.F_mean;
        
        func_feat.Phi_mean = mean(Phi_values);
        func_feat.Phi_std = std(Phi_values);
        func_feat.Phi_cv = func_feat.Phi_std / func_feat.Phi_mean;
        
        func_feat.Psi_mean = mean(Psi_values);
        func_feat.Psi_std = std(Psi_values);
        func_feat.Psi_cv = func_feat.Psi_std / func_feat.Psi_mean;
        
        % Ratios and relationships
        func_feat.F_Psi_ratio = func_feat.F_mean / func_feat.Psi_mean;
        func_feat.Phi_Psi_ratio = func_feat.Phi_mean / func_feat.Psi_mean;
        func_feat.F_Phi_ratio = func_feat.F_mean / func_feat.Phi_mean;
        
        % Age-adjusted function values
        func_feat.Psi_age_adjusted = func_feat.Psi_mean * p;
        func_feat.vascular_compliance_index = func_feat.Psi_mean / p;
        
        % Function variability patterns
        func_feat.function_balance = (func_feat.F_mean + func_feat.Phi_mean) / func_feat.Psi_mean;
        
    catch
        func_feat = create_default_function_structure();
    end
end

function temporal = extract_temporal_features_single(cycles, step_data)
    % Extract temporal features for a single subject
    temporal = struct();
    
    try
        temporal.total_duration = step_data.times(end);
        temporal.mean_cycle_duration = temporal.total_duration / length(cycles);
        
        if length(cycles) > 1
            cycle_durations = diff([cycles.cycle_id]) .* temporal.mean_cycle_duration;
            temporal.cycle_duration_std = std(cycle_durations);
            temporal.heart_rate_variability = temporal.cycle_duration_std / temporal.mean_cycle_duration;
        else
            temporal.cycle_duration_std = 0;
            temporal.heart_rate_variability = 0;
        end
        
    catch
        temporal.total_duration = 0;
        temporal.mean_cycle_duration = 0;
        temporal.cycle_duration_std = 0;
        temporal.heart_rate_variability = 0;
    end
end

function variability = extract_variability_features_single(cycles)
    % Extract variability features for a single subject
    variability = struct();
    
    try
        if length(cycles) < 2
            variability = create_default_variability_structure();
            return;
        end
        
        F_values = [cycles.F_value];
        Phi_values = [cycles.Phi_value];
        Psi_values = [cycles.Psi_value];
        
        % Short-term variability (adjacent beats)
        F_variability = std(diff(F_values)) / mean(F_values);
        Phi_variability = std(diff(Phi_values)) / mean(Phi_values);
        Psi_variability = std(diff(Psi_values)) / mean(Psi_values);
        
        variability.F_short_term_var = F_variability;
        variability.Phi_short_term_var = Phi_variability;
        variability.Psi_short_term_var = Psi_variability;
        
        % Overall variability
        variability.F_total_var = std(F_values) / mean(F_values);
        variability.Phi_total_var = std(Phi_values) / mean(Phi_values);
        variability.Psi_total_var = std(Psi_values) / mean(Psi_values);
        
        % Pattern consistency
        variability.function_stability = 1 - (variability.F_total_var + variability.Phi_total_var + variability.Psi_total_var) / 3;
        
    catch
        variability = create_default_variability_structure();
    end
end

function derivative = extract_robust_derivative_features_single(ppg_signal, fs)
    % Extract derivative features for a single subject 
    derivative = struct();
    
    try
        if length(ppg_signal) < 10
            derivative = create_default_derivative_structure();
            return;
        end
        
        % First derivative (velocity)
        vel = diff(ppg_signal);
        if ~isempty(vel)
            derivative.max_velocity = max(vel);
            derivative.min_velocity = min(vel);
            derivative.mean_velocity = mean(vel);
            derivative.velocity_skewness = skewness(vel);
        else
            derivative.max_velocity = 0;
            derivative.min_velocity = 0;
            derivative.mean_velocity = 0;
            derivative.velocity_skewness = 0;
        end  
        % Second derivative (acceleration)
        if length(ppg_signal) > 20
            acc = diff(ppg_signal, 2);
            if ~isempty(acc)
                derivative.max_acceleration = max(acc);
                derivative.min_acceleration = min(acc);
                derivative.acceleration_kurtosis = kurtosis(acc);
            else
                derivative.max_acceleration = 0;
                derivative.min_acceleration = 0;
                derivative.acceleration_kurtosis = 0;
            end
        else
            derivative.max_acceleration = 0;
            derivative.min_acceleration = 0;
            derivative.acceleration_kurtosis = 0;
        end 
        % Third derivative (jerk)
        if length(ppg_signal) > 30
            jerk = diff(ppg_signal, 3);
            if ~isempty(jerk)
                derivative.max_jerk = max(jerk);
            else
                derivative.max_jerk = 0;
            end
        else
            derivative.max_jerk = 0;
        end   
        % Timing features
        if ~isempty(vel)
            [~, max_vel_idx] = max(vel);
            if max_vel_idx <= length(vel)
                derivative.time_to_max_velocity = max_vel_idx / fs;
            else
                derivative.time_to_max_velocity = 0;
            end
        else
            derivative.time_to_max_velocity = 0;
        end
        
        if exist('acc', 'var') && ~isempty(acc)
            [~, max_acc_idx] = max(acc);
            if max_acc_idx <= length(acc)
                derivative.time_to_max_acceleration = max_acc_idx / fs;
            else
                derivative.time_to_max_acceleration = 0;
            end
        else
            derivative.time_to_max_acceleration = 0;
        end
        
        % Ratios
        if derivative.max_acceleration ~= 0
            derivative.velocity_acceleration_ratio = derivative.max_velocity / derivative.max_acceleration;
        else
            derivative.velocity_acceleration_ratio = 0;
        end
        
    catch
        derivative = create_default_derivative_structure();
    end
end

% Similar single-subject versions for other feature categories...
function spectral = extract_robust_spectral_features_single(ppg_signal, fs, pulse_rate)
    spectral = struct();
    try
        spectral = create_default_spectral_structure();
        % Remove DC component
        ppg_detrended = ppg_signal - mean(ppg_signal);
        % Compute power spectral density
        [psd, freq] = pwelch(ppg_detrended, [], [], [], fs);
        % Find fundamental frequency (heart rate)
        [~, max_idx] = max(psd);
        spectral.fundamental_freq = freq(max_idx);
        % Spectral moments
        spectral.spectral_centroid = sum(freq .* psd) / sum(psd);
        spectral.spectral_bandwidth = sqrt(sum(psd .* (freq - spectral.spectral_centroid).^2) / sum(psd));
        spectral.spectral_rolloff = find(cumsum(psd) >= 0.85 * sum(psd), 1) * (freq(2) - freq(1));
        % Harmonic features
        fundamental_hz = pulse_rate / 60; % Convert to Hz
        harmonic_peaks = [];

        for h = 2:5 % Up to 5th harmonic
            harmonic_freq = h * fundamental_hz;
            [~, idx] = min(abs(freq - harmonic_freq));
            if idx <= length(psd)
                harmonic_peaks(h-1) = psd(idx);
            end
        end

        if ~isempty(harmonic_peaks)
            spectral.harmonic_ratio = max(harmonic_peaks) / psd(max_idx);
            spectral.total_harmonic_distortion = sqrt(sum(harmonic_peaks.^2)) / psd(max_idx);
        else
            spectral.harmonic_ratio = 0;
            spectral.total_harmonic_distortion = 0;
        end

        % Spectral entropy
        spectral.spectral_entropy = -sum((psd/sum(psd)) .* log2(psd/sum(psd)));
        % Low frequency to high frequency ratio (simplified)
        lf_band = [0.04, 0.15]; % Hz
        hf_band = [0.15, 0.4];  % Hz

        lf_power = sum(psd(freq >= lf_band(1) & freq <= lf_band(2)));
        hf_power = sum(psd(freq >= hf_band(1) & freq <= hf_band(2)));

        spectral.lf_hf_ratio = lf_power / hf_power;
    catch
        spectral = create_default_spectral_structure();
    end
    
end

function nonlinear = extract_nonlinear_features_single(ppg_signal)
    % Robust nonlinear feature extraction
    nonlinear = struct();
    
    % Initialize all fields with default values
    default_fields = {
        'approx_entropy', 'dfa_alpha', 'sd1', 'sd2', 'sd_ratio', ...
        'recurrence_rate', 'lyapunov_exp', 'multiscale_entropy'
    };
    
    for i = 1:length(default_fields)
        nonlinear.(default_fields{i}) = 0;
    end

    % Validate input signal
    if isempty(ppg_signal) || length(ppg_signal) < 50
        return;
    end
    
    try
        % Ensure signal is a row vector
        ppg_signal = ppg_signal(:)';
        
        % 1. Approximate Entropy
        if length(ppg_signal) >= 50
            try
                nonlinear.approx_entropy = compute_robust_approximate_entropy(ppg_signal);
            catch
                nonlinear.approx_entropy = 0;
            end
        end
        
        % 2. Detrended Fluctuation Analysis
        if length(ppg_signal) >= 100
            try
                nonlinear.dfa_alpha = compute_robust_dfa(ppg_signal);
            catch
                nonlinear.dfa_alpha = 0;
            end
        end
        
        % 3. Poincaré Plot Features (FIXED)
        if length(ppg_signal) >= 10
            try
                [nonlinear.sd1, nonlinear.sd2, nonlinear.sd_ratio] = compute_robust_poincare(ppg_signal);
            catch
                nonlinear.sd1 = 0;
                nonlinear.sd2 = 0;
                nonlinear.sd_ratio = 0;
            end
        end
        
        % 4. Recurrence Rate
        if length(ppg_signal) >= 30
            try
                nonlinear.recurrence_rate = compute_robust_recurrence_rate(ppg_signal);
            catch
                nonlinear.recurrence_rate = 0;
            end
        end
        
        % 5. Lyapunov Exponent
        if length(ppg_signal) >= 50
            try
                nonlinear.lyapunov_exp = compute_robust_lyapunov(ppg_signal);
            catch
                nonlinear.lyapunov_exp = 0;
            end
        end
        
        % 6. Multiscale Entropy
        if length(ppg_signal) >= 100
            try
                nonlinear.multiscale_entropy = compute_robust_multiscale_entropy(ppg_signal);
            catch
                nonlinear.multiscale_entropy = 0;
            end
        end
        
    catch ME
        fprintf('  Nonlinear extraction error: %s\n', ME.message);
        % All fields already initialized to 0
    end
end

function [sd1, sd2, sd_ratio] = compute_robust_poincare(signal)
    % Robust Poincaré plot analysis
    sd1 = 0;
    sd2 = 0;
    sd_ratio = 0;
    
    if length(signal) < 3
        return;
    end
    
    try
        % Calculate differences for SD1
        diff_signal = diff(signal);
        if ~isempty(diff_signal)
            sd1 = std(diff_signal) / sqrt(2);
        end
        
        % Calculate consecutive averages for SD2
        if length(signal) >= 2
            avg_signal = (signal(1:end-1) + signal(2:end)) / 2;
            if ~isempty(avg_signal)
                sd2 = std(avg_signal) * sqrt(2);
            end
        end
        
        % Calculate ratio
        if sd2 ~= 0 && ~isnan(sd2) && ~isinf(sd2)
            sd_ratio = sd1 / sd2;
        end
        
    catch
        % Return default values
    end
end

function entropy = compute_robust_approximate_entropy(signal)
    % Robust approximate entropy calculation
    entropy = 0;
    
    if length(signal) < 50
        return;
    end
    
    try
        % Use a simplified but robust implementation
        m = 2;
        r = 0.2 * std(signal);
        
        % Limit signal length for efficiency
        max_length = min(200, length(signal));
        signal = signal(1:max_length);
        N = length(signal);
        
        % Pre-allocate patterns
        patterns_m = zeros(N-m+1, m);
        patterns_mp1 = zeros(N-m, m+1);
        
        % Create patterns for embedding dimension m
        for i = 1:N-m+1
            patterns_m(i, :) = signal(i:i+m-1);
        end
        
        % Create patterns for embedding dimension m+1
        for i = 1:N-m
            patterns_mp1(i, :) = signal(i:i+m);
        end
        
        % Calculate correlation sums
        C_m = zeros(1, N-m+1);
        C_mp1 = zeros(1, N-m);
        
        for i = 1:N-m+1
            distances = max(abs(patterns_m - patterns_m(i, :)), [], 2);
            C_m(i) = sum(distances <= r) / (N-m+1);
        end
        
        for i = 1:N-m
            distances = max(abs(patterns_mp1 - patterns_mp1(i, :)), [], 2);
            C_mp1(i) = sum(distances <= r) / (N-m);
        end
        
        % Remove zeros before taking log
        valid_C_m = C_m(C_m > 0);
        valid_C_mp1 = C_mp1(C_mp1 > 0);
        
        if ~isempty(valid_C_m) && ~isempty(valid_C_mp1)
            phi_m = mean(log(valid_C_m));
            phi_mp1 = mean(log(valid_C_mp1));
            entropy = phi_m - phi_mp1;
        end
        
        % Ensure valid range
        if isnan(entropy) || isinf(entropy) || entropy < 0
            entropy = 0;
        end
        
    catch
        entropy = 0;
    end
end

function dfa_alpha = compute_robust_dfa(signal)
    % Robust DFA implementation
    dfa_alpha = 0;
    
    if length(signal) < 50
        return;
    end
    
    try
        % Integrated signal
        y = cumsum(signal - mean(signal));
        N = length(y);
        
        % Fixed scales that work for most signals
        scales = [16, 32, 64, 128];
        scales = scales(scales <= floor(N/4));
        
        if length(scales) < 2
            return;
        end
        
        F_n = zeros(1, length(scales));
        
        for i = 1:length(scales)
            n = scales(i);
            segments = floor(N / n);
            
            if segments < 2
                continue;
            end
            
            rms_segment = zeros(1, segments);
            
            for v = 1:segments
                start_idx = (v-1)*n + 1;
                end_idx = v*n;
                
                if end_idx > N
                    continue;
                end
                
                y_segment = y(start_idx:end_idx);
                x = (1:length(y_segment))';
                
                % Linear detrending
                p = polyfit(x, y_segment, 1);
                trend = polyval(p, x);
                detrended = y_segment - trend;
                
                rms_segment(v) = sqrt(mean(detrended.^2));
            end
            
            valid_rms = rms_segment(rms_segment > 0);
            if ~isempty(valid_rms)
                F_n(i) = mean(valid_rms);
            end
        end
        
        % Remove invalid values
        valid_idx = F_n > 0 & ~isnan(F_n) & ~isinf(F_n);
        if sum(valid_idx) >= 2
            valid_scales = scales(valid_idx);
            valid_F = F_n(valid_idx);
            
            % Linear fit in log space
            p = polyfit(log(valid_scales), log(valid_F), 1);
            dfa_alpha = p(1);
        end
        
    catch
        dfa_alpha = 0;
    end
end

function recurrence_rate = compute_robust_recurrence_rate(signal)
    % Robust recurrence rate calculation
    recurrence_rate = 0;
    
    if length(signal) < 20
        return;
    end
    
    try
        % Normalize signal
        signal_norm = (signal - mean(signal)) / std(signal);    
        % Use a subset for efficiency
        max_points = min(50, length(signal_norm));
        signal_subset = signal_norm(1:max_points);
        
        threshold = 0.2;
        recurrence_matrix = zeros(max_points);
        
        % Build recurrence matrix
        for i = 1:max_points
            for j = 1:max_points
                if abs(signal_subset(i) - signal_subset(j)) < threshold
                    recurrence_matrix(i, j) = 1;
                end
            end
        end 
        % Calculate recurrence rate (excluding diagonal)
        recurrence_rate = (sum(recurrence_matrix(:)) - max_points) / (max_points^2 - max_points);
        
        if isnan(recurrence_rate) || recurrence_rate < 0
            recurrence_rate = 0;
        end
        
    catch
        recurrence_rate = 0;
    end
end

function lyapunov_exp = compute_robust_lyapunov(signal)
    % Lyapunov exponent approximation
    lyapunov_exp = 0;
    
    if length(signal) < 30
        return;
    end
    
    try
        % divergence-based approximation
        half_len = floor(length(signal)/2);
        part1 = signal(1:half_len);
        part2 = signal(half_len+1:2*half_len);
        
        if length(part1) == length(part2)
            initial_distance = abs(part1(1) - part2(1));
            final_distance = abs(part1(end) - part2(end));
            
            if initial_distance > 0 && final_distance > 0
                lyapunov_exp = log(final_distance / initial_distance) / length(part1);
            end
        end
        
        % Constrain to reasonable range
        lyapunov_exp = max(-1, min(1, lyapunov_exp));
        
    catch
        lyapunov_exp = 0;
    end
end

function mse = compute_robust_multiscale_entropy(signal)
    % Robust multiscale entropy
    mse = 0;
    
    if length(signal) < 100
        return;
    end
    
    try
        max_scale = 3; % Reduced for stability
        entropy_values = [];
        
        for scale = 1:max_scale
            coarse_length = floor(length(signal) / scale);
            
            if coarse_length < 20
                break;
            end
            
            % Coarse-graining
            coarse_signal = zeros(1, coarse_length);
            for i = 1:coarse_length
                start_idx = (i-1)*scale + 1;
                end_idx = min(i*scale, length(signal));
                coarse_signal(i) = mean(signal(start_idx:end_idx));
            end
            
            % Compute entropy for coarse-grained signal
            if length(coarse_signal)get_field_safe >= 50
                entropy_val = compute_robust_approximate_entropy(coarse_signal);
                if entropy_val > 0
                    entropy_values(end+1) = entropy_val;
                end
            end
        end
        
        if ~isempty(entropy_values)
            mse = mean(entropy_values);
        end
        
    catch
        mse = 0;
    end
end


function beat_shape = extract_beat_shape_features_single(cycles, result)
    beat_shape = struct();
    try
        beat_shape = create_default_beat_shape_structure();
        if length(cycles) < 3
            beat_shape.shape_consistency = 0;
            beat_shape.amplitude_modulation = 0;
            beat_shape.duration_variability = 0;
            return;
        end

        % Amplitude modulation
        peak_amplitudes = [result.extrema.peaks.amplitudes];
        beat_shape.amplitude_modulation = std(peak_amplitudes) / mean(peak_amplitudes);

        % Duration variability
        if isfield(result.step_data, 'durations')
            durations = result.step_data.durations;
            beat_shape.duration_variability = std(durations) / mean(durations);
        else
            beat_shape.duration_variability = 0;
        end

        % Shape consistency using F, Φ, Ψ functions
        F_vals = [cycles.F_value];
        Phi_vals = [cycles.Phi_value];
        Psi_vals = [cycles.Psi_value];

        beat_shape.F_consistency = 1 - (std(F_vals) / mean(F_vals));
        beat_shape.Phi_consistency = 1 - (std(Phi_vals) / mean(Phi_vals));
        beat_shape.Psi_consistency = 1 - (std(Psi_vals) / mean(Psi_vals));

        % Overall shape consistency
        beat_shape.shape_consistency = (beat_shape.F_consistency + ...
                                       beat_shape.Phi_consistency + ...
                                       beat_shape.Psi_consistency) / 3;

        % Augmentation index proxy
        if length(peak_amplitudes) > 1
            beat_shape.augmentation_index_proxy = (max(peak_amplitudes) - min(peak_amplitudes)) / mean(peak_amplitudes);
        else
            beat_shape.augmentation_index_proxy = 0;
        end
    catch
        beat_shape = create_default_beat_shape_structure();
    end
    
end

function stiffness = extract_stiffness_features_single(feat, age)
    stiffness = struct();
    
    % Arterial stiffness-related features
    try
        stiffness = create_default_stiffness_structure();
        % Pulse Wave Velocity proxies
        stiffness.pwv_proxy_1 = feat.function_based.F_mean / feat.function_based.Psi_mean;
        stiffness.pwv_proxy_2 = feat.derivative.max_velocity / feat.temporal.mean_cycle_duration;

        % Reflection index proxies
        if isfield(feat.morphology, 'rise_decay_ratio')
            stiffness.reflection_index = feat.morphology.rise_decay_ratio;
        else
            stiffness.reflection_index = 0;
        end

        % Age-adjusted stiffness
        expected_stiffness = 0.1 + 0.002 * age; % Empirical approximation
        stiffness.age_adjusted_stiffness = stiffness.pwv_proxy_1 / expected_stiffness;

        % Compliance metrics
        stiffness.vascular_compliance = 1 / stiffness.pwv_proxy_1;
        stiffness.total_compliance_index = feat.function_based.Psi_mean * 100;

        % Stiffness gradient (beat-to-beat changes)
        if isfield(feat.variability, 'Psi_total_var')
            stiffness.stiffness_gradient = feat.variability.Psi_total_var;
        else
            stiffness.stiffness_gradient = 0;
        end
    catch
        stiffness = create_default_stiffness_structure();
    end
    
end

function composite = extract_composite_indices_single(feat)
    composite = struct();
    try
        composite = create_default_composite_structure();
        % Vascular Health Index
        composite.vascular_health_index = (feat.function_based.Psi_mean * 100) / ...
                                         (1 + feat.stiffness.pwv_proxy_1);

        % BP Prediction Index (empirical combination)
        composite.bp_prediction_index = ...
            feat.function_based.F_Phi_ratio * 0.3 + ...
            feat.stiffness.pwv_proxy_1 * 0.2 + ...
            feat.spectral.lf_hf_ratio * 0.2 + ...
            feat.nonlinear.sd_ratio * 0.15 + ...
            feat.derivative.velocity_acceleration_ratio * 0.15;

        % Arterial Age Index
        composite.arterial_age_index = feat.age * ...
                                      (1 + feat.stiffness.age_adjusted_stiffness);

        % Waveform Complexity Score
        composite.waveform_complexity = ...
            feat.spectral.spectral_entropy * 0.4 + ...
            feat.nonlinear.approx_entropy * 0.3 + ...
            feat.morphology.kurtosis_ppgs * 0.3;

        % Hemodynamic Stress Index
        composite.hemodynamic_stress = ...
            feat.function_based.F_mean * feat.derivative.max_velocity * ...
            feat.temporal.heart_rate_variability;
    catch
        composite = create_default_composite_structure();
    end
    
end

function feat = create_complete_feature_structure(subject_id, age, p_coefficient)
    % Create a complete feature structure with all required fields
    feat = struct();
    feat.subject_id = subject_id;
    feat.age = age;
    feat.p_coefficient = p_coefficient;
    
    feat.basic = create_default_basic_structure();
    feat.morphology = create_default_morphology_structure();
    feat.function_based = create_default_function_structure();
    feat.temporal = create_default_temporal_structure();
    feat.variability = create_default_variability_structure();
    feat.derivative = create_default_derivative_structure();
    feat.spectral = create_default_spectral_structure();
    feat.nonlinear = create_default_nonlinear_structure();
    feat.beat_shape = create_default_beat_shape_structure();
    feat.stiffness = create_default_stiffness_structure();
    feat.composite = create_default_composite_structure();
    feat.engineered = create_default_engineered_structure();

end
function basic = create_default_basic_structure()
    % Create default basic demographic structure (6)
    basic = struct();
    basic.age = 0;
    basic.gender = '';
    basic.height = 0;
    basic.weight = 0;
    basic.bmi = 0;
    basic.heart_rate = 0;
end
function morphology = create_default_morphology_structure() %(26)
    morphology = struct();
    morphology.peak_count = 0;
    morphology.valley_count = 0;
    morphology.mean_amplitude = 0;
    morphology.amplitude_std = 0;
    morphology.amplitude_range = 0;
    morphology.mean_systolic_peak_amplitude = 0;
    morphology.mean_diastolic_peak_amplitude = 0;
    morphology.mean_area_systolic = 0;
    morphology.mean_area_diastolic = 0;
    morphology.max_rising_slope = 0;
    morphology.max_falling_slope = 0;
    morphology.slope_ratio = 0;
    morphology.avg_mean_ppgs = 0;
    morphology.variance_ppgs = 0;
    morphology.skewness_ppgs = 0;
    morphology.kurtosis_ppgs = 0;
    morphology.median_ppgs = 0;
    morphology.mad_ppgs = 0;
    morphology.p25_ppg = 0;
    morphology.p75_ppg = 0;
    morphology.iqr_ppg = 0;
    morphology.mean_step_duration = 0;
    morphology.step_duration_std = 0;
    morphology.mean_rise_time = 0;
    morphology.mean_decay_time = 0;
    morphology.rise_decay_ratio = 0;
end
 
function func_feat = create_default_function_structure() % (15)
    func_feat = struct();
    func_feat.F_mean = 0;
    func_feat.F_std = 0;
    func_feat.F_cv = 0;
    func_feat.Phi_mean = 0;
    func_feat.Phi_std = 0;
    func_feat.Phi_cv = 0;
    func_feat.Psi_mean = 0;
    func_feat.Psi_std = 0;
    func_feat.Psi_cv = 0;
    func_feat.F_Psi_ratio = 0;
    func_feat.Phi_Psi_ratio = 0;
    func_feat.F_Phi_ratio = 0;
    func_feat.Psi_age_adjusted = 0;
    func_feat.vascular_compliance_index = 0;
    func_feat.function_balance = 0;
end

% Create similar default structures for other feature categories...
function temporal = create_default_temporal_structure() %(4)
    temporal = struct();
    temporal.total_duration = 0;
    temporal.mean_cycle_duration = 0;
    temporal.cycle_duration_std = 0;
    temporal.heart_rate_variability = 0;
end

function variability = create_default_variability_structure()%()
    variability = struct();
    variability.F_short_term_var = 0;
    variability.Phi_short_term_var = 0;
    variability.Psi_short_term_var = 0;
    variability.F_total_var = 0;
    variability.Phi_total_var = 0;
    variability.Psi_total_var = 0;
    variability.function_stability = 0;
end

function derivative = create_default_derivative_structure()
    derivative = struct();
    derivative.max_velocity = 0;
    derivative.min_velocity = 0;
    derivative.mean_velocity = 0;
    derivative.max_acceleration = 0;
    derivative.min_acceleration = 0;
    derivative.max_jerk = 0;
    derivative.time_to_max_velocity = 0;
    derivative.time_to_max_acceleration = 0;
    derivative.velocity_acceleration_ratio = 0;
    derivative.velocity_skewness = 0;
    derivative.acceleration_kurtosis = 0;
end

function spectral = create_default_spectral_structure()
    spectral = struct();
    spectral.fundamental_freq = 0;
    spectral.spectral_centroid = 0;
    spectral.spectral_bandwidth = 0;
    spectral.spectral_rolloff = 0;
    spectral.harmonic_ratio = 0;
    spectral.total_harmonic_distortion = 0;
    spectral.spectral_entropy = 0;
    spectral.lf_hf_ratio = 0;
end

function nonlinear = create_default_nonlinear_structure()
    nonlinear = struct();
    nonlinear.approx_entropy = 0;
    nonlinear.dfa_alpha = 0;
    nonlinear.sd1 = 0;
    nonlinear.sd2 = 0;
    nonlinear.sd_ratio = 0;
    nonlinear.recurrence_rate = 0;
    nonlinear.lyapunov_exp = 0;
    nonlinear.multiscale_entropy = 0;
end

function beat_shape = create_default_beat_shape_structure()
    beat_shape = struct();
    beat_shape.shape_consistency = 0;
    beat_shape.amplitude_modulation = 0;
    beat_shape.duration_variability = 0;
    beat_shape.F_consistency = 0;
    beat_shape.Phi_consistency = 0;
    beat_shape.Psi_consistency = 0;
    beat_shape.augmentation_index_proxy = 0;
end

function stiffness = create_default_stiffness_structure()
    stiffness = struct();
    stiffness.pwv_proxy_1 = 0;
    stiffness.pwv_proxy_2 = 0;
    stiffness.reflection_index = 0;
    stiffness.age_adjusted_stiffness = 0;
    stiffness.vascular_compliance = 0;
    stiffness.total_compliance_index = 0;
    stiffness.stiffness_gradient = 0;
end

function composite = create_default_composite_structure()
    composite = struct();
    composite.vascular_health_index = 0;
    composite.bp_prediction_index = 0;
    composite.arterial_age_index = 0;
    composite.waveform_complexity = 0;
    composite.hemodynamic_stress = 0;
end




function engineered = create_default_engineered_structure()
    % Create default engineered features structure
    engineered = struct();
    default_engineered = {
        'Age_x_THD', 'Age_x_Stiffness', 'Age_x_HeartRate', ...
        'BMI_x_HarmonicRatio', 'BMI_x_Stiffness', 'BMI_x_PulseArea', ...
        'CV_Stress_Index', 'Dipping_Age_Risk_Proxy', 'Dipping_Stiffness_Risk', ...
        'Dipping_Stiffness_Age_Index', 'Dipping_BMI_Risk', 'Dipping_Autonomic_Function', ...
        'HTN_Waveform_Signature', 'HTN_Resistance_Proxy', 'HTN_Progression_Risk', ...
        'HTN_Reflection_Intensity', 'HTN_Prehyper_Discriminator', ...
        'Clinical_ISH_Proxy', 'Clinical_Young_HT_Pattern'
    };
    
    for i = 1:length(default_engineered)
        engineered.(default_engineered{i}) = 0;
    end
end