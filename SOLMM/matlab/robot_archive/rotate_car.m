function rotate_car(headingDeg, odom, publisher, command, transforms)
%ROTATE_CAR Turn toward an absolute map heading via the shortest angular arc.
rotationSpeed = 0.5;
toleranceDeg = 3;
timeoutSeconds = 12;
start = tic;
stop = onCleanup(@() stop_turn(publisher, command)); %#ok<NASGU>
command.Linear.X = 0;

while toc(start) < timeoutSeconds
    remaining = timeoutSeconds - toc(start);
    if remaining <= 0
        break;
    end
    [~, currentDeg] = getRobotMapPose(receive(odom, remaining), transforms);
    errorDeg = mod(headingDeg - currentDeg + 180, 360) - 180;
    if abs(errorDeg) < toleranceDeg
        return;
    end
    command.Angular.Z = sign(errorDeg) * rotationSpeed;
    send(publisher, command);
end
error('SOLMM:TurnTimeout', 'The robot did not attain the target heading.');
end

function stop_turn(publisher, command)
command.Angular.Z = 0;
send(publisher, command);
end
