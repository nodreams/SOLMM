function [headingDeg, action] = response_dn2(agent, laserMap, friend)
%RESPONSE_DN2 Evaluate the archived geometric controller without ROS.
% Inputs are in metres in the map frame. MATLAB indexes actions from 1 to 36.
validateattributes(agent, {'numeric'}, {'size', [1, 2], 'finite'});
validateattributes(friend, {'numeric'}, {'size', [1, 2], 'finite'});
validateattributes(laserMap, {'numeric'}, {'2d', 'ncols', 2, 'finite'});

obstacles = laserMap(any(laserMap ~= agent, 2), :);
goal = friend - agent;
if ~any(goal) || isempty(obstacles)
    heading = atan2d(goal(2), goal(1));
    action = mod(round(heading / 10), 36) + 1;
else
    fallback = AC_shiwu(agent, obstacles, friend);
    memory = MDN2_shiwu(100 * agent, 100 * obstacles, 100 * friend);
    action = action_select_shiwu(100 * obstacles, 100 * agent, ...
        100 * friend, fallback, memory);
end
headingDeg = 10 * (action - 1);
end
