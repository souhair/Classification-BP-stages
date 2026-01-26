function key = get_key_from_value(map, value)
    % Helper function to get key from value in containers.Map
    keys = map.keys;
    for i = 1:length(keys)
        if map(keys{i}) == value
            key = keys{i};
            return;
        end
    end
    key = 'Unknown';
end