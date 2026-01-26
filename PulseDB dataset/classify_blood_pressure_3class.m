function bp_category = classify_blood_pressure_3class(sbp, dbp)
  % Convert to double to ensure numeric comparison
    sbp_num = double(sbp);
    dbp_num = double(dbp);    
    % 3-class classification:
    % 1. Normal: SBP < 120 AND DBP < 80
    % 2. Prehypertension/Stage 1: SBP 120-139 OR DBP 80-89
    % 3. Stage 2 Hypertension: SBP ≥ 140 OR DBP ≥ 90   
    if (sbp_num < 120) && (dbp_num < 80)
        bp_category = "Normal";
    elseif (sbp_num >= 140) || (dbp_num >= 90)
        bp_category = "Stage 2 Hypertension";
    else
        bp_category = "Prehypertension_Stage1";
    end
end