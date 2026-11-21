function obstacles = load_paper_map_obstacles(mapFile, coordinateScale)
%LOAD_PAPER_MAP_OBSTACLES Extract occupied points from the archived ROS map.
%
% The saved map is the occupancy map used for the physical robot experiment.
% Output coordinates preserve the ROS map frame and are scaled from metres
% to the legacy controller's centimetre-like internal coordinate system.

assert(isfile(mapFile), 'Paper-aligned occupancy map not found: %s', mapFile);
data = load(mapFile, 'myOccMap');
assert(isfield(data, 'myOccMap'), ...
    'Expected variable myOccMap in %s.', mapFile);

map = data.myOccMap;
occupancy = getOccupancy(map);
[row, column] = find(occupancy >= map.OccupiedThreshold);
worldPoints = grid2world(map, [row, column]);
obstacles = unique(round(worldPoints .* coordinateScale, 4), ...
    'rows', 'stable');

assert(~isempty(obstacles), ...
    'No occupied points were extracted from %s.', mapFile);
end
