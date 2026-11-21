function action = cached_mdn2_action(controller, obstacles, goal, agent)
%CACHED_MDN2_ACTION Vectorized equivalent of the legacy dn2_test inference.

goalVector = goal - agent;
goalDistance = norm(goalVector);
if goalDistance < eps
    action = 1;
    return;
end
goalAngle = atan2(goalVector(2), goalVector(1));
if goalAngle < 0
    goalAngle = goalAngle + 2 * pi;
end

relative = obstacles - agent;
distances = sqrt(sum(relative .^ 2, 2));
[obstacleDistance, nearestIndex] = min(distances);
obstacleVector = relative(nearestIndex, :);
obstacleAngle = atan2(obstacleVector(2), obstacleVector(1));
if obstacleAngle < 0
    obstacleAngle = obstacleAngle + 2 * pi;
end

if controller.useWrappedAngles
    obstacleDifference = wrapped_angle_difference(goalAngle, obstacleAngle);
else
    obstacleDifference = abs(goalAngle - obstacleAngle);
end

if obstacleDistance >= controller.circle || obstacleDifference > pi / 2
    action = nearest_direction(goalAngle, controller.useWrappedAngles);
    return;
end

goalRatio = goalDistance / (goalDistance + obstacleDistance);
obstacleRatio = obstacleDistance / (goalDistance + obstacleDistance);
if controller.inputEncoding == "raw_cartesian"
    input = [goalVector .* goalRatio ./ goalDistance, ...
        obstacleVector .* obstacleRatio ./ max(obstacleDistance, eps), ...
        goalRatio, obstacleRatio];
else
    input = [cos(goalAngle), sin(goalAngle), ...
        cos(obstacleAngle), sin(obstacleAngle), ...
        goalRatio, obstacleRatio];
end
input = input / max(norm(input), eps);

uState = winner_state(input, controller.xToU, ...
    controller.uToState, controller.topK);
if obstacleDistance <= controller.obstacleThreshold
    pState = winner_state(input, controller.xToP, ...
        controller.pToState, controller.topK);
else
    pState = zeros(size(controller.stateToActionP, 1), 1);
end
if goalDistance >= controller.goalThreshold
    sState = winner_state(input, controller.xToS, ...
        controller.sToState, controller.topK);
else
    sState = zeros(size(controller.stateToActionS, 1), 1);
end

uResponse = uState' * controller.stateToActionU;
pResponse = pState' * controller.stateToActionP;
sResponse = sState' * controller.stateToActionS;
score = uResponse .* (1 + 3 .* sResponse - 10 .* pResponse);
score(score < 0) = 0;
[~, action] = max(score(1:36));
end

function state = winner_state(input, xToIntermediate, intermediateToState, topK)
intermediateResponse = input * xToIntermediate;
[~, order] = sort(intermediateResponse, 'descend');
intermediate = zeros(size(xToIntermediate, 2), 1);
intermediate(order(1:min(topK, numel(order)))) = 1;
intermediate = intermediate / max(norm(intermediate), eps);
stateResponse = intermediate' * intermediateToState;
[~, winner] = max(stateResponse);
state = zeros(size(intermediateToState, 2), 1);
state(winner) = 1;
end

function difference = wrapped_angle_difference(a, b)
difference = abs(atan2(sin(a - b), cos(a - b)));
end

function action = nearest_direction(angle, useWrappedAngles)
directions = (0:35) .* (pi / 18);
if useWrappedAngles
    differences = abs(atan2(sin(angle - directions), cos(angle - directions)));
else
    differences = abs(angle - directions);
end
[~, action] = min(differences);
end
