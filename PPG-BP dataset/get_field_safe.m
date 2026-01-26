function value = get_field_safe(structure, field_name, default_value)
    % Safely get field value from structure
    try
        if isfield(structure, field_name)
            value = structure.(field_name);
            if isempty(value) || isnan(value)
                value = default_value;
            end
        else
            value = default_value;
        end
    catch
        value = default_value;
    end
end