function controller = prepare_memory_controller(network, options)
%PREPARE_MEMORY_CONTROLLER Convert the legacy struct network to matrices.
% The conversion is performed once after initialization or offline update,
% rather than loading and unpacking the MAT file at every control step.

if nargin < 2
    options = struct('useWrappedAngles', false, ...
        'spatialEncoding', "polar_geometry");
elseif islogical(options) || isnumeric(options)
    options = struct('useWrappedAngles', logical(options), ...
        'spatialEncoding', "polar_geometry");
end

controller.topK = 6;
controller.circle = 300;
controller.obstacleThreshold = 65;
controller.goalThreshold = 45;
controller.useWrappedAngles = logical(options.useWrappedAngles);
controller.inputEncoding = string(options.spatialEncoding);

controller.xToU = normalized_columns( ...
    stack_field(network.Y.y_100_u_neuron, 'X_Y_100_u_weight'));
controller.uToState = normalized_columns( ...
    stack_field(network.Y.y_011_u_neuron, 'Y_100_u_Y_011_u_weight'));

controller.xToP = normalized_columns( ...
    stack_field(network.Y.y_100_p_neuron, 'X_Y_100_p_weight'));
controller.pToState = normalized_columns( ...
    stack_field(network.Y.y_011_p_neuron, 'Y_100_p_Y_011_p_weight'));

controller.xToS = normalized_columns( ...
    stack_field(network.Y.y_100_s_neuron, 'X_Y_100_s_weight'));
controller.sToState = normalized_columns( ...
    stack_field(network.Y.y_011_s_neuron, 'Y_100_s_Y_011_s_weight'));

controller.stateToActionU = stack_field( ...
    network.Z.z_u_neuron, 'Y_011_u_Z_weight');
controller.stateToActionP = stack_field( ...
    network.Z.z_p_neuron, 'Y_011_p_Z_weight');
controller.stateToActionS = stack_field( ...
    network.Z.z_s_neuron, 'Y_011_s_Z_weight');

if controller.inputEncoding == "raw_cartesian"
    controller.xToU = polar_prototypes_to_raw(controller.xToU);
    controller.xToP = polar_prototypes_to_raw(controller.xToP);
    controller.xToS = polar_prototypes_to_raw(controller.xToS);
end
end

function matrix = polar_prototypes_to_raw(matrix)
% Convert [cos(g),sin(g),cos(o),sin(o),r_g,r_o] prototypes to
% distance-normalized Cartesian offsets while preserving six dimensions.
goalRatio = max(0, matrix(5, :));
obstacleRatio = max(0, matrix(6, :));
matrix = [ ...
    matrix(1, :) .* goalRatio; ...
    matrix(2, :) .* goalRatio; ...
    matrix(3, :) .* obstacleRatio; ...
    matrix(4, :) .* obstacleRatio; ...
    goalRatio; obstacleRatio];
matrix = normalized_columns(matrix);
end

function matrix = stack_field(structArray, fieldName)
count = numel(structArray);
value = structArray(1).(fieldName);
first = double(value(:));
matrix = zeros(numel(first), count);
matrix(:, 1) = first;
for i = 2:count
    value = structArray(i).(fieldName);
    matrix(:, i) = double(value(:));
end
end

function matrix = normalized_columns(matrix)
denominator = sqrt(sum(matrix .^ 2, 1));
denominator(denominator < eps) = 1;
matrix = matrix ./ denominator;
end
