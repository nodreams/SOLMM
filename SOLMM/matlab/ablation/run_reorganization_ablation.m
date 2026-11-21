function output = run_reorganization_ablation(cfg)
%RUN_REORGANIZATION_ABLATION Run paired SOLMM component-ablation trials.
%
% Each seed starts from the same baseline model. Training retains memory
% within a repetition, while repetitions are independent. Evaluation freezes
% model updates. Evaluation contexts are reused by all variants. When
% pairStaticDynamicContexts is enabled, static and dynamic trials with the
% same seed and episode share the exact static map and static-obstacle noise;
% the dynamic trial adds only the moving obstacle and its independent noise.

if nargin < 1
    cfg = default_ablation_config("full");
end
cfg.variants = string(cfg.variants);
cfg.evalScenarios = string(cfg.evalScenarios);

validate_config(cfg);
% Keep this experiment directory on the search path after entering each
% isolated run-state folder; helper functions are separate MATLAB files.
experimentDir = fileparts(mfilename('fullpath'));
addpath(experimentDir);
addpath(cfg.legacyDir);
pathCleanup = onCleanup(@() rmpath(cfg.legacyDir)); %#ok<NASGU>

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outputDir = fullfile(cfg.outputRoot, timestamp);
mkdir(outputDir);
write_config(cfg, fullfile(outputDir, 'config.json'));

rows = struct([]);
traceRoot = fullfile(outputDir, 'traces');
if cfg.saveTraces
    mkdir(traceRoot);
end

for seedIndex = 1:numel(cfg.seeds)
    seed = cfg.seeds(seedIndex);
    for variantIndex = 1:numel(cfg.variants)
        variant = cfg.variants(variantIndex);
        if cfg.verbose
            fprintf('Seed %d/%d (%d), variant %s\n', ...
                seedIndex, numel(cfg.seeds), seed, variant);
        end

        runDir = fullfile(outputDir, 'run_state', ...
            sprintf('seed_%d', seed), safe_name(variant));
        mkdir(runDir);
        copyfile(cfg.baselineModel, fullfile(runDir, 'gongguMDN2.mat'));
        copyfile(cfg.fallbackModel, fullfile(runDir, 'goodmodel.mat'));

        previousDir = pwd;
        cd(runDir);
        cdCleanup = onCleanup(@() cd(previousDir));
        rng(seed, 'twister');

        fallback = create_fallback_context(cfg);
        baselineMetrics = read_model_metrics('gongguMDN2.mat');
        memoryController = load_memory_controller( ...
            'gongguMDN2.mat', cfg, variant);

        for episode = 1:cfg.trainEpisodes
            movementPlan = make_movement_plan(cfg, seed, "train", ...
                "static", episode);
            [result, memoryData, trace, fallback] = run_episode( ...
                cfg, variant, "train", "static", episode, seed, ...
                cfg.trainStart, cfg.trainGoal, movementPlan, fallback, ...
                memoryController);

            [candidateCount, appliedCount] = offline_update( ...
                variant, memoryData, result, episode, cfg);
            if appliedCount > 0
                memoryController = load_memory_controller( ...
                    'gongguMDN2.mat', cfg, variant);
            end
            modelMetrics = read_model_metrics('gongguMDN2.mat');
            result.reorganization_candidates = candidateCount;
            result.reorganization_applied = appliedCount;
            result.model_y011_update_delta = ...
                modelMetrics.y011UpdateMass - baselineMetrics.y011UpdateMass;
            result.model_z_update_delta = ...
                modelMetrics.zUpdateMass - baselineMetrics.zUpdateMass;
            rows = append_row(rows, result);

            if cfg.saveTraces && ...
                    (~isfield(cfg, 'saveTrainingTraces') || ...
                    cfg.saveTrainingTraces)
                save(fullfile(traceRoot, sprintf( ...
                    'seed_%d_%s_train_%02d.mat', seed, ...
                    safe_name(variant), episode)), 'trace');
            end
        end


        % Optional dynamic-adaptation phase. It remains part of training:
        % offline updates are allowed and evaluation data are not inspected.
        for episode = 1:cfg.dynamicTrainEpisodes
            movementPlan = make_movement_plan(cfg, seed, ...
                "dynamic_train", "dynamic", episode);
            [result, memoryData, trace, fallback] = run_episode( ...
                cfg, variant, "dynamic_train", "dynamic", episode, seed, ...
                cfg.trainStart, cfg.trainGoal, movementPlan, fallback, ...
                memoryController);

            [candidateCount, appliedCount] = offline_update( ...
                variant, memoryData, result, episode, cfg);
            if appliedCount > 0
                memoryController = load_memory_controller( ...
                    'gongguMDN2.mat', cfg, variant);
            end
            modelMetrics = read_model_metrics('gongguMDN2.mat');
            result.reorganization_candidates = candidateCount;
            result.reorganization_applied = appliedCount;
            result.model_y011_update_delta = ...
                modelMetrics.y011UpdateMass - baselineMetrics.y011UpdateMass;
            result.model_z_update_delta = ...
                modelMetrics.zUpdateMass - baselineMetrics.zUpdateMass;
            rows = append_row(rows, result);

            if cfg.saveTraces && ...
                    (~isfield(cfg, 'saveTrainingTraces') || ...
                    cfg.saveTrainingTraces)
                save(fullfile(traceRoot, sprintf( ...
                    'seed_%d_%s_dynamic_train_%02d.mat', seed, ...
                    safe_name(variant), episode)), 'trace');
            end
        end

        % Evaluation is frozen: no call to offline_update is made here.
        for scenarioIndex = 1:numel(cfg.evalScenarios)
            scenario = cfg.evalScenarios(scenarioIndex);
            for episode = 1:cfg.evalEpisodes
                [startPosition, goalPosition] = evaluation_pair( ...
                    cfg, episode, seed);
                movementPlan = make_movement_plan(cfg, seed, "eval", ...
                    scenario, episode);
                [result, ~, trace, fallback] = run_episode( ...
                    cfg, variant, "eval", scenario, episode, seed, ...
                    startPosition, goalPosition, movementPlan, fallback, ...
                    memoryController);
                modelMetrics = read_model_metrics('gongguMDN2.mat');
                result.reorganization_candidates = 0;
                result.reorganization_applied = 0;
                result.model_y011_update_delta = ...
                    modelMetrics.y011UpdateMass - baselineMetrics.y011UpdateMass;
                result.model_z_update_delta = ...
                    modelMetrics.zUpdateMass - baselineMetrics.zUpdateMass;
                rows = append_row(rows, result);

                if cfg.saveTraces
                    save(fullfile(traceRoot, sprintf( ...
                        'seed_%d_%s_eval_%s_%02d.mat', seed, ...
                        safe_name(variant), scenario, episode)), 'trace');
                end
            end
        end

        clear cdCleanup;
        cd(previousDir);
    end
end

episodeResults = struct2table(rows);
episodeResults.variant = string(episodeResults.variant);
episodeResults.phase = string(episodeResults.phase);
episodeResults.scenario = string(episodeResults.scenario);
episodeResults.status = string(episodeResults.status);
episodeResults.scenario_pair_id = string(episodeResults.scenario_pair_id);
pairingAuditPath = "";
if cfg.pairStaticDynamicContexts && ...
        all(ismember(["static", "dynamic"], cfg.evalScenarios))
    verify_paired_scenario_contexts(episodeResults);
    pairingAudit = build_scenario_pairing_audit(episodeResults);
    pairingAuditPath = fullfile(outputDir, 'scenario_pairing_audit.csv');
    writetable(pairingAudit, pairingAuditPath);
end
episodeCsv = fullfile(outputDir, 'episode_results.csv');
writetable(episodeResults, episodeCsv);

analysis = analyze_reorganization_ablation(episodeCsv, cfg);
output = struct( ...
    'outputDir', outputDir, ...
    'episodeResults', episodeCsv, ...
    'variantDefinitions', analysis.variantDefinitionsPath, ...
    'trainingSummary', analysis.trainingSummaryPath, ...
    'replicateSummary', analysis.replicateSummaryPath, ...
    'overallSummary', analysis.overallSummaryPath, ...
    'statistics', analysis.statisticsPath, ...
    'scenarioPairingAudit', pairingAuditPath, ...
    'figure', analysis.figurePath);

save(fullfile(outputDir, 'experiment_output.mat'), 'output', 'cfg');
fprintf('Ablation experiment outputs: %s\n', outputDir);
end

function validate_config(cfg)
requiredFiles = [string(cfg.baselineModel), string(cfg.fallbackModel), ...
    string(fullfile(cfg.legacyDir, 'MDN2.m')), ...
    string(fullfile(cfg.legacyDir, 'fxxz.m')), ...
    string(fullfile(cfg.legacyDir, 'memorycons.m'))];
for i = 1:numel(requiredFiles)
    assert(isfile(requiredFiles(i)), 'Missing required file: %s', requiredFiles(i));
end
assert(numel(cfg.seeds) == cfg.repetitions, ...
    'cfg.seeds must contain one seed per repetition.');
assert(all(ismember(cfg.variants, ["SOLMM-Full", "SOLMM-NoReorg", ...
    "SOLMM-AlwaysAC", "SOLMM-NoSwitch", "SOLMM-NoGridPlace"])), ...
    'Unsupported variant in cfg.variants.');
assert(all(ismember(cfg.evalScenarios, ["static", "dynamic"])), ...
    'cfg.evalScenarios may contain only "static" and "dynamic".');
assert(size(cfg.staticObstacles, 2) == 2 && ~isempty(cfg.staticObstacles), ...
    'cfg.staticObstacles must be a non-empty N-by-2 matrix.');
assert(numel(cfg.worldBounds) == 4, ...
    'cfg.worldBounds must be [xmin xmax ymin ymax].');
assert(cfg.reorganizationEpochs >= 1 && ...
    fix(cfg.reorganizationEpochs) == cfg.reorganizationEpochs, ...
    'cfg.reorganizationEpochs must be a positive integer.');
assert((isinf(cfg.reorganizationMaxCandidates) || ...
    (cfg.reorganizationMaxCandidates >= 1 && ...
    fix(cfg.reorganizationMaxCandidates) == ...
    cfg.reorganizationMaxCandidates)), ...
    'cfg.reorganizationMaxCandidates must be Inf or a positive integer.');
assert(cfg.reorganizationInterval >= 1 && ...
    fix(cfg.reorganizationInterval) == cfg.reorganizationInterval, ...
    'cfg.reorganizationInterval must be a positive integer.');
assert(cfg.hybridSafetyMargin >= cfg.collisionThreshold, ...
    'cfg.hybridSafetyMargin must be at least cfg.collisionThreshold.');
assert(cfg.dynamicCollisionThreshold >= cfg.collisionThreshold, ...
    ['cfg.dynamicCollisionThreshold must be at least the static ' ...
     'collision threshold.']);
assert(isscalar(cfg.pairStaticDynamicContexts) && ...
    (islogical(cfg.pairStaticDynamicContexts) || ...
    ismember(cfg.pairStaticDynamicContexts, [0, 1])), ...
    'cfg.pairStaticDynamicContexts must be a logical scalar.');
if strcmpi(cfg.dynamicMotionMode, "recorded_trajectory")
    assert(size(cfg.dynamicInitial, 1) == 1, ...
        'The paper-aligned recorded trajectory uses one dynamic obstacle.');
    assert(size(cfg.dynamicTrajectory, 2) == 2 && ...
        size(cfg.dynamicTrajectory, 1) >= 2, ...
        'cfg.dynamicTrajectory must contain at least two 2-D points.');
end
if ~isempty(cfg.dynamicRouteByEpisode)
    assert(all(cfg.dynamicRouteByEpisode >= 1) && ...
        all(cfg.dynamicRouteByEpisode <= size(cfg.dynamicStartPositions, 1)) && ...
        all(fix(cfg.dynamicRouteByEpisode) == cfg.dynamicRouteByEpisode), ...
        'cfg.dynamicRouteByEpisode contains an invalid route index.');
    assert(size(cfg.dynamicDirectionOptions, 1) == ...
        size(cfg.dynamicStartPositions, 1), ...
        ['cfg.dynamicDirectionOptions must contain one direction for each ' ...
         'dynamic start position.']);
    validate_controlled_crossing_geometry(cfg);
end
end

function validate_controlled_crossing_geometry(cfg)
steps = (0:cfg.maxSteps)';
requiredStaticClearance = max(cfg.collisionThreshold, ...
    cfg.dynamicCollisionThreshold) + ...
    sqrt(2) * cfg.staticLayoutJitter;
for episode = 1:cfg.evalEpisodes
    [startPosition, goalPosition] = evaluation_pair(cfg, episode);
    robotDirection = goalPosition - startPosition;
    robotDirection = robotDirection ./ norm(robotDirection);
    robotPath = startPosition + steps .* robotDirection .* cfg.stepSize;

    routeSlot = 1 + mod(episode - 1, numel(cfg.dynamicRouteByEpisode));
    routeIndex = cfg.dynamicRouteByEpisode(routeSlot);
    dynamicPath = controlled_route_positions(cfg, routeIndex);
    inside = dynamicPath(:, 1) >= cfg.worldBounds(1) & ...
        dynamicPath(:, 1) <= cfg.worldBounds(2) & ...
        dynamicPath(:, 2) >= cfg.worldBounds(3) & ...
        dynamicPath(:, 2) <= cfg.worldBounds(4);

    temporalDistance = sqrt(sum((robotPath(inside, :) - ...
        dynamicPath(inside, :)) .^ 2, 2));
    assert(min(temporalDistance) < cfg.dynamicCollisionThreshold, ...
        ['Controlled dynamic route %d does not cross the nominal robot ' ...
         'trajectory closely enough.'], routeIndex);

    routePoints = dynamicPath(inside, :);
    routeClearance = inf;
    for pointIndex = 1:size(routePoints, 1)
        distances = sqrt(sum((cfg.staticObstacles - ...
            routePoints(pointIndex, :)) .^ 2, 2));
        routeClearance = min(routeClearance, min(distances));
    end
    assert(routeClearance > requiredStaticClearance, ...
        ['Controlled dynamic route %d can overlap a jittered static ' ...
         'obstacle.'], routeIndex);
end
end

function write_config(cfg, path)
serializable = cfg;
serializable.variants = cellstr(cfg.variants);
serializable.evalScenarios = cellstr(cfg.evalScenarios);
text = jsonencode(serializable, PrettyPrint=true);
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Unable to create config file: %s', path);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text, 'char');
end

function fallback = create_fallback_context(cfg)
fallback = struct('mode', string(cfg.fallbackMode));
if strcmpi(cfg.fallbackMode, "legacy_exact")
    stateCount = 500 * 500;
    actionCount = 9;
    fallback.RBFNN.x_num = 6;
    fallback.RBFNN.y_num = 1;
    fallback.RBFNN.z_num = actionCount;
    fallback.RBFNN.y(1).x_y_weight = ones(6, 1);
    for i = 1:actionCount
        fallback.RBFNN.z(i).y_z_weight = 1;
    end
    fallback.RBFNN.y_response = 0;
    fallback.RBFNN.z_response = zeros(actionCount, 1);
    fallback.C = zeros(1, 6);
    fallback.Q = sparse(stateCount, actionCount);
    fallback.N = zeros(stateCount, 1);
    fallback.alpha = 0.5;
    fallback.gamma = 0.95;
    fallback.delte_ERR = [];
    fallback.delte_COR = [];
    fallback.beta_star = sparse(2, stateCount);
    fallback.beta_star(1, 1) = 0.5;
    fallback.beta = sparse(2, stateCount);
    fallback.beta(1, 1) = 8.808;
    fallback.t = 1;
else
    global network
    data = load('goodmodel.mat', 'network');
    network = data.network;
end
end

function [result, memoryData, trace, fallback] = run_episode( ...
        cfg, variant, phase, scenario, episode, seed, ...
        startPosition, goalPosition, movementPlan, fallback, memoryController)

directions = [(0:35)' .* (pi / 18)];
directions = [cos(directions), sin(directions)];
agent = startPosition;
staticObstacles = movementPlan.staticObstacles;
dynamicObstacles = movementPlan.dynamicInitial;
if scenario == "static"
    dynamicObstacles = zeros(0, 2);
end
dynamicPath = zeros(0, size(dynamicObstacles, 1), 2);
if ~isempty(dynamicObstacles)
    dynamicPath(1, :, :) = reshape(dynamicObstacles, ...
        1, size(dynamicObstacles, 1), 2);
end

path = agent;
controllerHistory = strings(0, 1);
goalVectors = zeros(0, 2);
obstacleVectors = zeros(0, 2);
memoryActionsForUpdate = zeros(0, 1);
guardCount = 0;
pathLength = 0;
minClearance = inf;
minStaticClearance = inf;
minDynamicClearance = inf;
status = "timeout";
success = false;
startTimer = tic;

for step = 1:cfg.maxSteps
    if ~isempty(dynamicObstacles)
        increments = squeeze(movementPlan.dynamicIncrements(step, :, :));
        if size(increments, 2) ~= 2
            increments = reshape(increments, [], 2);
        end
        dynamicObstacles = update_dynamic_obstacles( ...
            dynamicObstacles, increments, staticObstacles, cfg);
        dynamicPath(end+1, :, :) = reshape(dynamicObstacles, ...
            1, size(dynamicObstacles, 1), 2); %#ok<AGROW>
    end

    obstacles = [staticObstacles; dynamicObstacles];
    noise = squeeze(movementPlan.observationNoise(step, :, :));
    if size(noise, 2) ~= 2
        noise = reshape(noise, [], 2);
    end
    observedObstacles = obstacles + noise;
    relative = observedObstacles - agent;
    distances = sqrt(sum(relative .^ 2, 2));
    [~, nearestIndex] = min(distances);
    goalVectors(end+1, :) = goalPosition - agent; %#ok<AGROW>
    obstacleVectors(end+1, :) = relative(nearestIndex, :); %#ok<AGROW>

    memoryAction = cached_mdn2_action( ...
        memoryController, observedObstacles, goalPosition, agent);
    if strcmpi(fallback.mode, "legacy_exact")
        evalc(['fallbackAction = AC(observedObstacles, goalPosition, agent, ', ...
            'fallback.RBFNN, fallback.C, fallback.Q, fallback.N, ', ...
            'fallback.alpha, fallback.gamma, fallback.delte_ERR, ', ...
            'fallback.delte_COR, fallback.beta_star, fallback.beta, ', ...
            'fallback.t);']);
    else
        a_ri = goalPosition - agent;
        b_ri = [relative, distances];
        evalc('fallbackAction = dh_test(a_ri, b_ri);');
    end

    [action, controller] = select_hybrid_action( ...
        agent, goalPosition, observedObstacles, memoryAction, fallbackAction, ...
        directions, cfg, variant);
    [action, guardApplied] = apply_collision_guard( ...
        action, agent, goalPosition, observedObstacles, directions, cfg);
    guardCount = guardCount + guardApplied;
    controllerHistory(end+1, 1) = controller; %#ok<AGROW>
    memoryActionsForUpdate(end+1, 1) = memoryAction(1); %#ok<AGROW>

    nextAgent = round(agent + directions(action, :) .* cfg.stepSize);
    pathLength = pathLength + norm(nextAgent - agent);
    agent = nextAgent;
    path(end+1, :) = agent; %#ok<AGROW>

    staticDistancesAfterMove = sqrt(sum((staticObstacles - agent) .^ 2, 2));
    staticClearance = min(staticDistancesAfterMove);
    minStaticClearance = min(minStaticClearance, staticClearance);
    if isempty(dynamicObstacles)
        dynamicClearance = inf;
    else
        dynamicDistancesAfterMove = sqrt(sum((dynamicObstacles - agent) .^ 2, 2));
        dynamicClearance = min(dynamicDistancesAfterMove);
        minDynamicClearance = min(minDynamicClearance, dynamicClearance);
    end
    clearance = min(staticClearance, dynamicClearance);
    minClearance = min(minClearance, clearance);
    goalDistance = norm(goalPosition - agent);

    if goalDistance < cfg.goalThreshold
        success = true;
        status = "success";
        break;
    elseif staticClearance < cfg.collisionThreshold
        if scenario == "dynamic"
            status = "static_collision";
        else
            status = "collision";
        end
        break;
    elseif dynamicClearance < cfg.dynamicCollisionThreshold
        status = "dynamic_collision";
        break;
    elseif is_out_of_bounds(agent, cfg)
        status = "out_of_bounds";
        break;
    end
end

steps = size(path, 1) - 1;
if success && pathLength > 0
    pathEfficiency = norm(goalPosition - startPosition) / pathLength;
else
    pathEfficiency = 0;
end
if isinf(minClearance)
    minClearance = NaN;
end
if isinf(minStaticClearance)
    minStaticClearance = NaN;
end
if isinf(minDynamicClearance)
    minDynamicClearance = NaN;
end
switchCount = sum(controllerHistory(2:end) ~= controllerHistory(1:end-1));

result = struct( ...
    'seed', seed, ...
    'variant', char(variant), ...
    'phase', char(phase), ...
    'scenario', char(scenario), ...
    'episode', episode, ...
    'scenario_pair_id', char(movementPlan.scenarioPairId), ...
    'static_context_seed', movementPlan.staticContextSeed, ...
    'dynamic_context_seed', movementPlan.dynamicContextSeed, ...
    'static_layout_signature', movementPlan.staticLayoutSignature, ...
    'static_noise_signature', movementPlan.staticNoiseSignature, ...
    'dynamic_route_index', movementPlan.dynamicRouteIndex, ...
    'dynamic_route_delay_steps', movementPlan.dynamicRouteDelaySteps, ...
    'dynamic_route_move_steps', movementPlan.dynamicRouteMoveSteps, ...
    'start_x', startPosition(1), ...
    'start_y', startPosition(2), ...
    'goal_x', goalPosition(1), ...
    'goal_y', goalPosition(2), ...
    'success', success, ...
    'status', char(status), ...
    'steps', steps, ...
    'path_length', pathLength, ...
    'path_efficiency', pathEfficiency, ...
    'min_clearance', minClearance, ...
    'min_static_clearance', minStaticClearance, ...
    'min_dynamic_clearance', minDynamicClearance, ...
    'final_distance', norm(goalPosition - agent), ...
    'memory_actions', sum(startsWith(controllerHistory, "memory")), ...
    'fallback_actions', sum(startsWith(controllerHistory, "fallback")), ...
    'switch_count', switchCount, ...
    'collision_guard_actions', guardCount, ...
    'spatial_encoding', char(memoryController.inputEncoding), ...
    'switching_enabled', variant ~= "SOLMM-NoSwitch" && ...
        variant ~= "SOLMM-AlwaysAC", ...
    'reorganization_enabled', variant ~= "SOLMM-NoReorg" && ...
        variant ~= "SOLMM-AlwaysAC", ...
    'raw_memory_items', size(goalVectors, 1), ...
    'reorganization_candidates', 0, ...
    'reorganization_applied', 0, ...
    'model_y011_update_delta', 0, ...
    'model_z_update_delta', 0, ...
    'elapsed_seconds', toc(startTimer));

memoryData = struct( ...
    'goalVectors', goalVectors, ...
    'obstacleVectors', obstacleVectors, ...
    'memoryActions', memoryActionsForUpdate);
trace = struct('path', path, 'controllers', controllerHistory, ...
    'staticObstacles', staticObstacles, ...
    'startPosition', startPosition, 'goalPosition', goalPosition, ...
    'dynamicPath', dynamicPath, 'status', status, 'success', success);
end

function [action, controller] = select_hybrid_action( ...
        agent, goal, obstacles, memoryAction, fallbackAction, directions, cfg, variant)
memoryAction = clamp_action(memoryAction(1));
fallbackAction = clamp_action(fallbackAction(1));
if variant == "SOLMM-AlwaysAC"
    action = fallbackAction;
    controller = "fallback_always_ac";
    return;
end
if variant == "SOLMM-NoSwitch"
    action = memoryAction;
    controller = "memory_no_switch";
    return;
end
memoryPosition = agent + directions(memoryAction, :) .* cfg.stepSize;
fallbackPosition = agent + directions(fallbackAction, :) .* cfg.stepSize;

currentGoalDistance = norm(goal - agent);
currentClearance = nearest_clearance(agent, obstacles);
memoryClearance = nearest_clearance(memoryPosition, obstacles);
fallbackClearance = nearest_clearance(fallbackPosition, obstacles);

if fallbackClearance <= cfg.hybridSafetyMargin && ...
        memoryClearance > cfg.hybridSafetyMargin
    action = memoryAction;
    controller = "memory";
    return;
elseif memoryClearance <= cfg.hybridSafetyMargin && ...
        fallbackClearance > cfg.hybridSafetyMargin
    action = fallbackAction;
    controller = "fallback";
    return;
elseif memoryClearance <= cfg.hybridSafetyMargin && ...
        fallbackClearance <= cfg.hybridSafetyMargin
    if memoryClearance > fallbackClearance
        action = memoryAction;
        controller = "memory_safety";
    else
        action = fallbackAction;
        controller = "fallback_safety";
    end
    return;
end

memoryProgress = (currentGoalDistance - norm(goal - memoryPosition)) / cfg.stepSize;
fallbackProgress = (currentGoalDistance - norm(goal - fallbackPosition)) / cfg.stepSize;
memorySafety = (memoryClearance - currentClearance) / cfg.stepSize;
fallbackSafety = (fallbackClearance - currentClearance) / cfg.stepSize;

memoryScore = cfg.hybridGoalWeight * memoryProgress + ...
    cfg.hybridClearanceWeight * memorySafety;
fallbackScore = cfg.hybridGoalWeight * fallbackProgress + ...
    cfg.hybridClearanceWeight * fallbackSafety;
if memoryScore > fallbackScore
    action = memoryAction;
    controller = "memory";
else
    action = fallbackAction;
    controller = "fallback";
end
end

function value = nearest_clearance(position, obstacles)
value = min(sqrt(sum((obstacles - position) .^ 2, 2)));
end

function action = clamp_action(action)
action = round(action);
action = max(1, min(36, action));
end

function [action, applied] = apply_collision_guard( ...
        action, agent, goal, obstacles, directions, cfg)
applied = false;
if ~isfield(cfg, 'enableCollisionGuard') || ~cfg.enableCollisionGuard
    return;
end

positions = round(agent + directions .* cfg.stepSize);
clearances = inf(size(positions, 1), 1);
inside = true(size(positions, 1), 1);
for directionIndex = 1:size(positions, 1)
    clearances(directionIndex) = nearest_clearance( ...
        positions(directionIndex, :), obstacles);
    inside(directionIndex) = ~is_out_of_bounds(positions(directionIndex, :), cfg);
end
safetyThreshold = cfg.collisionThreshold + cfg.actionSafetyBuffer;
safe = inside & clearances > safetyThreshold;
if safe(action)
    return;
end

applied = true;
candidateIndices = find(safe);
if isempty(candidateIndices)
    candidateIndices = find(inside);
end
if isempty(candidateIndices)
    return;
end

currentGoalDistance = norm(goal - agent);
progress = (currentGoalDistance - ...
    sqrt(sum((goal - positions(candidateIndices, :)) .^ 2, 2))) ./ ...
    max(cfg.stepSize, eps);
clearanceCap = max(3 * safetyThreshold, eps);
clearanceScore = min(clearances(candidateIndices), clearanceCap) ./ ...
    clearanceCap;
scores = cfg.guardGoalWeight .* progress + ...
    cfg.guardClearanceWeight .* clearanceScore;
[~, bestIndex] = max(scores);
action = candidateIndices(bestIndex);
end

function dynamic = update_dynamic_obstacles(dynamic, increments, staticObstacles, cfg)
if ~cfg.applyDynamicCollisionResponse
    dynamic = dynamic + increments;
    return;
end
for i = 1:size(dynamic, 1)
    delta = increments(i, :);
    candidate = dynamic(i, :) + delta;
    hitsBoundary = is_out_of_bounds(candidate, cfg);
    staticDistances = sqrt(sum((staticObstacles - candidate) .^ 2, 2));
    hitsStatic = min(staticDistances) < cfg.dynamicSafetyRadius;
    if hitsBoundary || hitsStatic
        candidate = dynamic(i, :) - delta;
    end
    candidate(1) = max(cfg.worldBounds(1), min(cfg.worldBounds(2), candidate(1)));
    candidate(2) = max(cfg.worldBounds(3), min(cfg.worldBounds(4), candidate(2)));
    dynamic(i, :) = candidate;
end
end

function plan = make_movement_plan(cfg, seed, phase, scenario, episode)
usesSingleControlledObstacle = strcmpi(cfg.dynamicMotionMode, ...
    "recorded_trajectory") || strcmpi(cfg.dynamicMotionMode, ...
    "controlled_crossing");
if scenario == "static"
    nDynamic = 0;
elseif usesSingleControlledObstacle
    nDynamic = 1;
else
    nDynamic = size(cfg.dynamicInitial, 1);
end
phaseOffset = 0;
if phase == "eval"
    phaseOffset = 100000;
elseif phase == "dynamic_train"
    phaseOffset = 200000;
end
scenarioOffset = sum(double(char(scenario))) * 100;
if phase == "eval" && cfg.pairStaticDynamicContexts
    % The base seed deliberately excludes the scenario name. Static and
    % dynamic trials therefore receive the same static layout and the same
    % observation noise for every static obstacle.
    staticContextSeed = seed + phaseOffset + episode;
else
    staticContextSeed = seed + phaseOffset + scenarioOffset + episode;
end
dynamicContextSeed = seed + phaseOffset + 500000 + episode;
staticStream = RandStream('mt19937ar', 'Seed', staticContextSeed);
dynamicStream = RandStream('mt19937ar', 'Seed', dynamicContextSeed);

staticObstacles = cfg.staticObstacles;
if phase == "eval" && cfg.staticLayoutJitter > 0
    jitter = (2 * rand(staticStream, size(staticObstacles)) - 1) .* ...
        cfg.staticLayoutJitter;
    staticObstacles = staticObstacles + jitter;
    staticObstacles(:, 1) = max(cfg.worldBounds(1), ...
        min(cfg.worldBounds(2), staticObstacles(:, 1)));
    staticObstacles(:, 2) = max(cfg.worldBounds(3), ...
        min(cfg.worldBounds(4), staticObstacles(:, 2)));
end

dynamicInitial = zeros(0, 2);
dynamicRouteIndex = NaN;
dynamicRouteDelaySteps = 0;
dynamicRouteMoveSteps = 0;
if nDynamic > 0
    if usesSingleControlledObstacle
        if ~isempty(cfg.dynamicRouteByEpisode)
            episodeIndex = 1 + mod(episode - 1, ...
                numel(cfg.dynamicRouteByEpisode));
            startIndex = cfg.dynamicRouteByEpisode(episodeIndex);
        else
            startIndex = 1 + mod(seed + episode, ...
                size(cfg.dynamicStartPositions, 1));
        end
        dynamicRouteIndex = startIndex;
        dynamicInitial = cfg.dynamicStartPositions(startIndex, :);
    else
        dynamicInitial = cfg.dynamicInitial;
    end
end

if nDynamic == 0
    dynamicIncrements = zeros(cfg.maxSteps, 0, 2);
elseif strcmpi(cfg.dynamicMotionMode, "recorded_trajectory")
    dynamicIncrements = recorded_trajectory_increments( ...
        cfg, dynamicStream, dynamicInitial);
elseif strcmpi(cfg.dynamicMotionMode, "controlled_crossing")
    direction = cfg.dynamicDirectionOptions(startIndex, :);
    direction = direction ./ max(norm(direction), eps);
    dynamicIncrements = zeros(cfg.maxSteps, 1, 2);
    delay = route_value(cfg.dynamicRouteDelayByRoute, startIndex, 0);
    moveSteps = route_value(cfg.dynamicRouteMoveStepsByRoute, ...
        startIndex, cfg.maxSteps);
    dynamicRouteDelaySteps = delay;
    dynamicRouteMoveSteps = moveSteps;
    activeStart = delay + 1;
    activeEnd = min(cfg.maxSteps, delay + moveSteps);
    if activeStart <= activeEnd
        dynamicIncrements(activeStart:activeEnd, 1, :) = repmat( ...
            reshape(direction .* cfg.stepSize, 1, 1, 2), ...
            activeEnd - activeStart + 1, 1, 1);
    end
else
    raw = randi(dynamicStream, [-5, 5], cfg.maxSteps, nDynamic, 2);
    dynamicIncrements = raw .* cfg.dynamicStepScale;
end

nStatic = size(staticObstacles, 1);
staticNoise = randn(staticStream, cfg.maxSteps, nStatic, 2) .* ...
    cfg.observationNoiseStd;
dynamicNoise = randn(dynamicStream, cfg.maxSteps, nDynamic, 2) .* ...
    cfg.observationNoiseStd;
observationNoise = cat(2, staticNoise, dynamicNoise);
scenarioPairId = sprintf('seed_%d_%s_episode_%02d', ...
    seed, char(phase), episode);
plan = struct('staticObstacles', staticObstacles, ...
    'dynamicInitial', dynamicInitial, ...
    'dynamicIncrements', dynamicIncrements, ...
    'observationNoise', observationNoise, ...
    'scenarioPairId', string(scenarioPairId), ...
    'staticContextSeed', staticContextSeed, ...
    'dynamicContextSeed', dynamicContextSeed, ...
    'staticLayoutSignature', numeric_signature(staticObstacles), ...
    'staticNoiseSignature', numeric_signature(staticNoise), ...
    'dynamicRouteIndex', dynamicRouteIndex, ...
    'dynamicRouteDelaySteps', dynamicRouteDelaySteps, ...
    'dynamicRouteMoveSteps', dynamicRouteMoveSteps);
end

function positions = controlled_route_positions(cfg, routeIndex)
direction = cfg.dynamicDirectionOptions(routeIndex, :);
direction = direction ./ max(norm(direction), eps);
delay = route_value(cfg.dynamicRouteDelayByRoute, routeIndex, 0);
moveSteps = route_value(cfg.dynamicRouteMoveStepsByRoute, ...
    routeIndex, cfg.maxSteps);
increments = zeros(cfg.maxSteps, 2);
activeStart = delay + 1;
activeEnd = min(cfg.maxSteps, delay + moveSteps);
if activeStart <= activeEnd
    increments(activeStart:activeEnd, :) = repmat( ...
        direction .* cfg.stepSize, activeEnd - activeStart + 1, 1);
end
positions = cfg.dynamicStartPositions(routeIndex, :) + ...
    [zeros(1, 2); cumsum(increments, 1)];
end

function value = route_value(values, index, defaultValue)
if isempty(values)
    value = defaultValue;
else
    value = values(index);
end
end

function value = numeric_signature(values)
values = double(values(:));
weights = mod((1:numel(values))', 104729) + 1;
value = sum(values .* weights);
end

function verify_paired_scenario_contexts(results)
evaluation = results(results.phase == "eval", :);
variants = unique(evaluation.variant, 'stable');
seeds = unique(evaluation.seed, 'stable');
episodes = unique(evaluation.episode, 'stable');
for variantIndex = 1:numel(variants)
    for seedIndex = 1:numel(seeds)
        for episodeIndex = 1:numel(episodes)
            pair = evaluation(evaluation.variant == variants(variantIndex) & ...
                evaluation.seed == seeds(seedIndex) & ...
                evaluation.episode == episodes(episodeIndex), :);
            assert(height(pair) == 2 && ...
                all(ismember(["static", "dynamic"], pair.scenario)), ...
                'Missing static/dynamic member for paired evaluation context.');
            assert(isscalar(unique(pair.scenario_pair_id)) && ...
                isscalar(unique(pair.static_context_seed)) && ...
                isscalar(unique(pair.static_layout_signature)) && ...
                isscalar(unique(pair.static_noise_signature)), ...
                ['Static and dynamic trials do not share the same static ' ...
                 'evaluation context.']);
        end
    end
end
for seedIndex = 1:numel(seeds)
    for episodeIndex = 1:numel(episodes)
        context = evaluation(evaluation.seed == seeds(seedIndex) & ...
            evaluation.episode == episodes(episodeIndex), :);
        assert(isscalar(unique(context.scenario_pair_id)) && ...
            isscalar(unique(context.static_context_seed)) && ...
            isscalar(unique(context.static_layout_signature)) && ...
            isscalar(unique(context.static_noise_signature)), ...
            ['Algorithm variants do not share the same paired evaluation ' ...
             'context.']);
    end
end
end

function audit = build_scenario_pairing_audit(results)
evaluation = results(results.phase == "eval", :);
referenceVariant = evaluation.variant(1);
evaluation = evaluation(evaluation.variant == referenceVariant, :);
seeds = unique(evaluation.seed, 'stable');
episodes = unique(evaluation.episode, 'stable');
rows = struct([]);
for seedIndex = 1:numel(seeds)
    for episodeIndex = 1:numel(episodes)
        pair = evaluation(evaluation.seed == seeds(seedIndex) & ...
            evaluation.episode == episodes(episodeIndex), :);
        staticRow = pair(pair.scenario == "static", :);
        dynamicRow = pair(pair.scenario == "dynamic", :);
        isMatch = height(staticRow) == 1 && height(dynamicRow) == 1 && ...
            staticRow.scenario_pair_id == dynamicRow.scenario_pair_id && ...
            staticRow.static_context_seed == dynamicRow.static_context_seed && ...
            staticRow.static_layout_signature == ...
                dynamicRow.static_layout_signature && ...
            staticRow.static_noise_signature == ...
                dynamicRow.static_noise_signature;
        row = struct( ...
            'seed', seeds(seedIndex), ...
            'episode', episodes(episodeIndex), ...
            'scenario_pair_id', staticRow.scenario_pair_id, ...
            'static_context_seed', staticRow.static_context_seed, ...
            'static_layout_signature', staticRow.static_layout_signature, ...
            'static_noise_signature', staticRow.static_noise_signature, ...
            'dynamic_context_seed', dynamicRow.dynamic_context_seed, ...
            'base_context_match', isMatch);
        rows = append_row(rows, row);
    end
end
audit = struct2table(rows);
end

function increments = recorded_trajectory_increments(cfg, stream, dynamicInitial)
points = double(cfg.dynamicTrajectory);
relative = points - points(1, :);

rotationLimit = deg2rad(cfg.dynamicTrajectoryRotationDeg);
angle = (2 * rand(stream) - 1) * rotationLimit;
rotation = [cos(angle), -sin(angle); sin(angle), cos(angle)];
relative = relative * rotation';

if cfg.dynamicTrajectoryJitter > 0
    jitter = randn(stream, size(relative)) .* cfg.dynamicTrajectoryJitter;
    jitter = movmean(jitter, min(5, size(jitter, 1)), 1);
    jitter = jitter - jitter(1, :);
    relative = relative + jitter;
end
points = dynamicInitial + relative;

segmentLength = sqrt(sum(diff(points, 1, 1) .^ 2, 2));
distance = [0; cumsum(segmentLength)];
keep = [true; diff(distance) > eps];
distance = distance(keep);
points = points(keep, :);
assert(numel(distance) >= 2 && distance(end) > 0, ...
    'The recorded dynamic trajectory has no usable movement.');

range = cfg.dynamicSpeedFactorRange;
speedFactor = range(1) + rand(stream) * (range(2) - range(1));
queryDistance = (0:cfg.maxSteps)' .* cfg.stepSize .* speedFactor;
queryDistance = min(queryDistance, distance(end));
positions = [ ...
    interp1(distance, points(:, 1), queryDistance, 'linear'), ...
    interp1(distance, points(:, 2), queryDistance, 'linear')];
delta = diff(positions, 1, 1);
increments = reshape(delta, cfg.maxSteps, 1, 2);
end

function value = is_out_of_bounds(position, cfg)
value = position(1) < cfg.worldBounds(1) || ...
    position(1) > cfg.worldBounds(2) || ...
    position(2) < cfg.worldBounds(3) || ...
    position(2) > cfg.worldBounds(4);
end

function [candidateCount, appliedCount] = offline_update( ...
        variant, memoryData, result, episode, cfg)
candidateCount = 0;
appliedCount = 0;
if variant == "SOLMM-AlwaysAC"
    return;
end
if isempty(memoryData.goalVectors)
    return;
end
% The legacy fxxz.m uses length() on an N-by-2 matrix, which is unsafe for
% a one-step episode because length([x y]) is 2. A single observation cannot
% define a reorganization transition, so no offline update is applied.
if size(memoryData.goalVectors, 1) < 2
    return;
end
[goalShort, obstacleShort, actionShort, badActionShort] = fxxz( ...
    memoryData.goalVectors, memoryData.obstacleVectors, memoryData.memoryActions);
candidateCount = numel(actionShort);
isScheduled = episode >= cfg.reorganizationStartEpisode && ...
    mod(episode - cfg.reorganizationStartEpisode, ...
        cfg.reorganizationInterval) == 0;
isEligibleOutcome = ~cfg.reorganizationSuccessOnly || result.success;
if variant ~= "SOLMM-NoReorg" && candidateCount > 0 && ...
        isScheduled && isEligibleOutcome
    keepCount = min(candidateCount, cfg.reorganizationMaxCandidates);
    if isfinite(keepCount) && keepCount < candidateCount
        keep = unique(round(linspace(1, candidateCount, keepCount)));
        goalShort = goalShort(keep, :);
        obstacleShort = obstacleShort(keep, :);
        actionShort = actionShort(keep, :);
        badActionShort = badActionShort(keep, :);
    end
    evalc(['memorycons(goalShort, obstacleShort, actionShort, ', ...
        'badActionShort, cfg.reorganizationEpochs);']);
    appliedCount = numel(actionShort);
end
end

function metrics = read_model_metrics(modelPath)
data = load(modelPath, 'network');
network = data.network;
metrics.y011UpdateMass = sum(double(network.Y.y_011_u.age(:)) - 1);
metrics.zUpdateMass = sum(double(network.Z.z_u.age(:)) - 1);
end

function controller = load_memory_controller(modelPath, cfg, variant)
data = load(modelPath, 'network');
localCfg = cfg;
if variant == "SOLMM-NoGridPlace"
    localCfg.spatialEncoding = "raw_cartesian";
end
controller = prepare_memory_controller(data.network, localCfg);
end

function [startPosition, goalPosition] = evaluation_pair(cfg, episode, seed)
if nargin < 3
    seed = 0;
end
if ~cfg.alternateEvaluationDirection || mod(episode, 2) == 1
    startPosition = cfg.trainStart;
    goalPosition = cfg.trainGoal;
else
    startPosition = cfg.trainGoal;
    goalPosition = cfg.trainStart;
end
if isfield(cfg, 'endpointJitter') && cfg.endpointJitter > 0
    stream = RandStream('mt19937ar', ...
        'Seed', seed + 800000 + episode);
    startPosition = startPosition + ...
        (2 * rand(stream, 1, 2) - 1) .* cfg.endpointJitter;
    goalPosition = goalPosition + ...
        (2 * rand(stream, 1, 2) - 1) .* cfg.endpointJitter;
    startPosition(1) = max(cfg.worldBounds(1), ...
        min(cfg.worldBounds(2), startPosition(1)));
    startPosition(2) = max(cfg.worldBounds(3), ...
        min(cfg.worldBounds(4), startPosition(2)));
    goalPosition(1) = max(cfg.worldBounds(1), ...
        min(cfg.worldBounds(2), goalPosition(1)));
    goalPosition(2) = max(cfg.worldBounds(3), ...
        min(cfg.worldBounds(4), goalPosition(2)));
end
end

function rows = append_row(rows, row)
if isempty(rows)
    rows = row;
else
    rows(end+1) = row; %#ok<AGROW>
end
end

function name = safe_name(value)
name = lower(regexprep(char(value), '[^A-Za-z0-9]+', '_'));
end
