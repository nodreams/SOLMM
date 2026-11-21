function [trajectory, distance] = rosdn2(goal, maxSteps)
%ROSDN2 ROS 1 adapter for the archived geometric controller.
% Set ROS_MASTER_URI and ROS_IP for the intended session before calling.
arguments
    goal (1, 2) double {mustBeFinite} = [3.08, 2.3]
    maxSteps (1, 1) double {mustBeInteger, mustBePositive} = 150
end

rosinit;
publisher = [];
command = [];
cleanup = onCleanup(@finish); %#ok<NASGU>
scan = rossubscriber('/scan', 'sensor_msgs/LaserScan');
odom = rossubscriber('/odom', 'nav_msgs/Odometry');
transforms = rostf;
waitForTransform(transforms, 'map', 'odom');
waitForTransform(transforms, 'map', 'laser');
publisher = rospublisher('/cmd_vel', 'geometry_msgs/Twist');
command = rosmessage(publisher);

trajectory = zeros(maxSteps, 2);
distance = zeros(maxSteps, 2);
for step = 1:maxSteps
    agent = getRobotMapPose(receive(odom, 10), transforms);
    points = readCartesian(receive(scan, 10));
    points = points(all(isfinite(points), 2), :);
    if isempty(points)
        error('SOLMM:MissingScan', 'No finite LiDAR returns in the current scan.');
    end
    obstacles = zeros(size(points));
    for index = 1:size(points, 1)
        obstacles(index, :) = laser2map_position(points(index, 1), points(index, 2), transforms);
    end

    trajectory(step, :) = agent;
    distance(step, :) = [min(vecnorm(points, 2, 2)) - 0.15, norm(goal - agent)];
    if distance(step, 2) < 0.2
        break;
    end
    heading = response_dn2(agent, obstacles, goal);
    rotate_car(heading, odom, publisher, command, transforms);
    command.Linear.X = 0.3;
    send(publisher, command);
    pause(1);
    stop_robot(publisher, command);
end
trajectory = trajectory(1:step, :);
distance = distance(1:step, :);

    function finish()
        shutdown = onCleanup(@() rosshutdown); %#ok<NASGU>
        if ~isempty(command)
            stop_robot(publisher, command);
        end
    end
end

function stop_robot(publisher, command)
command.Linear.X = 0;
command.Angular.Z = 0;
send(publisher, command);
end
