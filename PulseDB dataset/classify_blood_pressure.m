function bp_category = classify_blood_pressure(sbp, dbp)
% Input:
%   sbp - systolic blood pressure
%   dbp - diastolic blood pressure
%
% Output:
    % Convert to double to ensure numeric comparison
    sbp_num = double(sbp);
    dbp_num = double(dbp);
    
    % Check conditions in the correct order (most restrictive first):
    % 1. Stage 2 hypertension: SBP ≥ 160 OR (SBP 140-159 AND DBP ≥ 90)
    % 2. Stage 1 hypertension: SBP 140-159 AND DBP 80-89
    % 3. Prehypertension: SBP 120-139 OR DBP 80-89
    % 4. Normal: SBP < 120 AND DBP < 80
    
    if (sbp_num >= 160) || (dbp_num >= 100)
        bp_category = "Stage 2 hypertension";
    elseif (sbp_num >= 140) || (dbp_num >= 90)
        bp_category = "Stage 1 hypertension";
    elseif (sbp_num >= 120) || (dbp_num >= 80)
        bp_category = "Prehypertension";
    elseif (sbp_num < 120) && (dbp_num < 80)
        bp_category = "Normal";
    else
        bp_category = "Unknown";
    end
end