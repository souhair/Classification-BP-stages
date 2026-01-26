function processed_data = process_pulse_wave(ppg_signals, pulse_rates, ages, fs)
    
    processed_data = [];
    
    for i = 1:length(ppg_signals)
        fprintf('Processing signal %d/%d (Age: %d)...\n', i, length(ppg_signals), ages(i));
        
        % Get age coefficient (p starts from 2)
        p = calculate_age_coefficient(ages(i));
        fprintf('  Age coefficient: p = %d\n', p);
        
        % Convert to CCD step representation
        [step_amps, step_times, step_durations] = convert_to_step_representation(...
            ppg_signals{i}, pulse_rates(i), fs);
        
        % Detect peaks and valleys
        [peaks, valleys] = detect_step_extrema(step_amps);
        
        % Initialize results structure
        result.signal_id = i;
        result.age = ages(i);
%         result.NumOfPeaks= length(result.peaks);
        result.p_coefficient = p;
        result.step_data.amplitudes = step_amps;
        result.step_data.times = step_times;
        result.step_data.durations = step_durations;
        result.extrema.peaks = peaks;
        result.extrema.valleys = valleys;
        result.extrema.systolic_peak_amplitude = max(peaks.amplitudes);
        result.extrema.diastolic_peak_amplitude= min(valleys.amplitudes);
        result.area_systolic = trapz(ppg_signals{i}(ppg_signals{i} > mean(ppg_signals{i})));
        result.area_diastolic = trapz(ppg_signals{i}(ppg_signals{i} <= mean(ppg_signals{i})));
        derivative = diff(ppg_signals{i});
        result.max_rising_slope = max(derivative(derivative > 0));
        result.max_falling_slope = min(derivative(derivative < 0));
        result.slope_ratio = abs(result.max_rising_slope / result.max_falling_slope);
        
        result.mean_ppg = mean(ppg_signals{i});
        result.variance_ppg = var(ppg_signals{i});
        result.skewness_ppg = skewness(ppg_signals{i});  % Asymmetry
        result.kurtosis_ppg = kurtosis(ppg_signals{i});  % Peakiness
        result.median_ppg = median(ppg_signals{i});
        result.mad_ppg = mad(ppg_signals{i});  % Median absolute deviation

        % Percentile-based features
        result.p25_ppg = prctile(ppg_signals{i}, 25);
        result.p75_ppg = prctile(ppg_signals{i}, 75);
        result.iqr_ppg = result.p75_ppg - result.p25_ppg;

        % Process each cardiac cycle USING OUR FUNCTIONs
        cycle_results = process_cardiac_cycles(step_amps, step_times, step_durations, peaks, valleys, p);
        result.cycle_analysis = cycle_results;
        processed_data = [processed_data, result];
        
        fprintf('  Completed: %d cardiac cycles analyzed\n', length(cycle_results));
    end
end

function cycle_results = process_cardiac_cycles(step_amps, step_times, step_durations, peaks, valleys, p)
    cycle_results = [];
    num_cycles = min(length(peaks.locations), length(valleys.locations));
    
    for cycle_idx = 1:num_cycles
        cycle.cycle_id = cycle_idx;
        
        % F function - Peak steepness analysis
        peak_loc = peaks.locations(cycle_idx);
        cycle.F_value = calculate_peak_steepness(step_amps, step_durations, peak_loc);
        
        % Φ function - Rising front analysis
        if cycle_idx == 1
            valley_loc = 1;
        else
            valley_loc = valleys.locations(cycle_idx-1);
        end
        peak_loc = peaks.locations(cycle_idx);
        
        if valley_loc < peak_loc
            cycle.Phi_value = calculate_rise_function(step_amps, step_times, step_durations, valley_loc, peak_loc, p);
        else
            cycle.Phi_value = 0;
            
        end
        
        % Ψ function - Falling front analysis 
        peak_loc = peaks.locations(cycle_idx);
        valley_loc = valleys.locations(cycle_idx);
        if peak_loc < valley_loc
            cycle.Psi_value = calculate_decay_function(step_amps, step_times, step_durations, peak_loc, valley_loc, p);
            %cycle.Max_Psi_value = max(cycle.Psi_value);
        else
            cycle.Psi_value = 0;
            %cycle.Max_Psi_value = 0;
        end
        
        cycle_results = [cycle_results, cycle];
    end
end

function Psi = calculate_decay_function(step_amps, step_times, step_durations, peak_loc, valley_loc, p)
    % Ψ FUNCTION 
    
    if peak_loc >= valley_loc || peak_loc < 1 || valley_loc > length(step_amps)
        Psi = 0;
        return;
    end
    
    A_m = step_amps(peak_loc);
    n = valley_loc;
    m = peak_loc;
    
    Psi_total = 0;
    valid_steps = 0;
    
    % Calculate for each step in decay segment
    for k = peak_loc+1:valley_loc
        t_current = step_times(k);
        delta_tau_k = step_durations(k);
        A_k_minus_1 = step_amps(k-1);
        A_k = step_amps(k);
        
        % Time from peak to current step
        t_from_peak = t_current - step_times(peak_loc);
        
        % Exact formula - NO SCALING
        exponent = (-t_from_peak * p) / ((n - m) * delta_tau_k);
        amplitude_diff = A_k_minus_1 - A_k;
        linear_term = (n - m) / p;
        
        Psi_step = A_m * exp(exponent) * amplitude_diff * linear_term;
        
        % Only add valid, non-NaN, non-infinite values
        if ~isnan(Psi_step) && ~isinf(Psi_step) && isreal(Psi_step) && Psi_step >= 0
            Psi_total = Psi_total + Psi_step;
            valid_steps = valid_steps + 1;
        end
    end
    
    % Return average Ψ value across all valid steps
    if valid_steps > 0
        Psi = Psi_total / valid_steps;
    else
        Psi = 0;
    end
    
    if isnan(Psi) || isinf(Psi)
        Psi = 0;
    end
end

% All other supporting functions remain the same
function p = calculate_age_coefficient(age)
    if age < 30
        p = 2;
    elseif age < 45
        p = 3;
    elseif age < 60
        p = 4;
    else
        p = 5;
    end
end

function [step_amps, step_times, step_durations] = convert_to_step_representation(ppg, pulse_rate, fs)
    Y = ppg / max(ppg);
    total_time = length(Y) / fs;
    X = (1:length(Y)) * total_time / length(Y);
    
    first = 1;
    while first < length(Y) && Y(first+1) == Y(first)
        first = first + 1;
    end
    
    step_amps = []; step_times = []; step_durations = [];
    
    counter = 1;
    step_amps(counter) = Y(first);
    step_times(counter) = X(first);
    step_durations(counter) = first / fs;
    counter = counter + 1;
    
    for i = first+1:length(Y)-1
        if Y(i+1) ~= Y(i)
            step_amps(counter) = Y(i);
            step_times(counter) = X(i);
            step_durations(counter) = 1 / fs;
            counter = counter + 1;
        else
            step_durations(end) = step_durations(end) + 1/fs;
        end
    end
    
    step_amps(counter) = Y(end);
    step_times(counter) = X(end);
end

function [peaks, valleys] = detect_step_extrema(step_amps)
    peaks.locations = []; peaks.amplitudes = [];
    valleys.locations = []; valleys.amplitudes = [];
    
    n = length(step_amps);
    for i = 2:n-1
        if step_amps(i) > step_amps(i-1) && step_amps(i) > step_amps(i+1)
            peaks.locations(end+1) = i;
            peaks.amplitudes(end+1) = step_amps(i);
        end
        if step_amps(i) < step_amps(i-1) && step_amps(i) < step_amps(i+1)
            valleys.locations(end+1) = i;
            valleys.amplitudes(end+1) = step_amps(i);
        end
    end
end

function F_value = calculate_peak_steepness(step_amps, step_durations, peak_loc)
    if peak_loc > 1 && peak_loc <= length(step_amps)
        delta_A = step_amps(peak_loc) - step_amps(peak_loc-1);
        delta_tau = step_durations(peak_loc);
        if delta_tau > 0
            F_value = abs(delta_A / delta_tau);
        else
            F_value = 0;
        end
    else
        F_value = 0;
    end
end

function Phi = calculate_rise_function(step_amps, step_times, step_durations, valley_loc, peak_loc, p)
    if valley_loc >= peak_loc || valley_loc < 1 || peak_loc > length(step_amps)
        Phi = 0;
        return;
    end
    
    m_i = peak_loc;
    k_i = valley_loc;
    total_rise_time = sum(step_durations(k_i:m_i));
    
    Phi = 0;
    for n = k_i:m_i
        A_n = step_amps(n);
        inner_sum = 0;
        for j = 1:(m_i - k_i + 1)
            j_idx = j + k_i - 1;
            if j_idx <= m_i
                delta_tau_j = step_durations(j_idx);
                term = ((delta_tau_j * p) / (total_rise_time * (m_i - 1)))^j;
                inner_sum = inner_sum + term;
            end
        end
        Phi = Phi + A_n * inner_sum;
    end
end