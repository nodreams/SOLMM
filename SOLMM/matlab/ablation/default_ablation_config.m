function cfg = default_ablation_config(mode)
%DEFAULT_ABLATION_CONFIG Configuration for the memory-reorganization ablation.
%
% cfg = default_ablation_config("full")  creates the publication-oriented run.
% cfg = default_ablation_config("smoke") creates a short integration test.

if nargin < 1
    mode = "full";
end

here = fileparts(mfilename('fullpath'));
workspaceRoot = fileparts(fileparts(here));

cfg.experimentName = "memory_reorganization_ablation";
cfg.outputRoot = fullfile(here, 'results');
cfg.legacyDir = fullfile(workspaceRoot, 'matlab', 'legacy_mdn22');
modelDir = fullfile(workspaceRoot, 'models');
cfg.baselineModel = fullfile(modelDir, 'nice_mdn2_model.mat');
cfg.fallbackModel = fullfile(modelDir, 'goodmodel.mat');

% The base mode keeps the historical two-group experiment.  The reviewer
% mode below expands it to four controlled component ablations.
cfg.variants = ["SOLMM-Full", "SOLMM-NoReorg"];
cfg.spatialEncoding = "polar_geometry";
cfg.repetitions = 30;
cfg.seeds = 20260918 + (0:cfg.repetitions-1);
cfg.trainEpisodes = 10;
cfg.dynamicTrainEpisodes = 0;
cfg.evalEpisodes = 10;
cfg.evalScenarios = ["static", "dynamic"];
cfg.maxSteps = 200;

cfg.worldMin = 20;
cfg.worldMax = 480;
cfg.stepSize = 12;
cfg.goalThreshold = 15;
cfg.collisionThreshold = 14;
cfg.hybridSafetyMargin = cfg.collisionThreshold;
cfg.dynamicSafetyRadius = 40;
cfg.dynamicCollisionThreshold = cfg.collisionThreshold;
cfg.dynamicStepScale = 2;
cfg.dynamicMotionMode = "random_walk";
cfg.dynamicTrajectory = zeros(0, 2);
cfg.dynamicTrajectoryRotationDeg = 0;
cfg.dynamicTrajectoryJitter = 0;
cfg.dynamicSpeedFactorRange = [1, 1];
cfg.applyDynamicCollisionResponse = true;
cfg.observationNoiseStd = 0;
cfg.staticLayoutJitter = 0;
cfg.endpointJitter = 0;
cfg.pairStaticDynamicContexts = false;
cfg.plotCoordinateScale = 1;
cfg.referenceGridResolution = 5;

cfg.trainStart = [450, 50];
cfg.trainGoal = [50, 450];
cfg.staticObstacles = [ ...
     78, 330; 118, 210; 290, 382; 345, 325; 366,  78; ...
    382, 130; 360, 260; 225, 211; 195, 267; 330, 200; ...
    290, 300; 165, 170; 430, 340; 365, 395; 259, 162; ...
    135,  85; 210, 140];
cfg.dynamicInitial = [300, 255; 206, 334; 420, 265; 110, 140];
cfg.dynamicStartPositions = cfg.dynamicInitial;
cfg.dynamicDirectionOptions = zeros(size(cfg.dynamicInitial));
cfg.dynamicRouteByEpisode = [];
cfg.dynamicRouteDelayByRoute = [];
cfg.dynamicRouteMoveStepsByRoute = [];
cfg.worldBounds = [cfg.worldMin, cfg.worldMax, cfg.worldMin, cfg.worldMax];
cfg.alternateEvaluationDirection = true;

% AC.m receives fresh state on every call, so its returned action always takes
% the initial dh_test fallback branch. "legacy_equivalent" calls that branch
% directly and is behaviorally equivalent while avoiding unused local updates.
% "legacy_exact" remains available as a slow compatibility audit.
cfg.fallbackMode = "legacy_equivalent";

% Keep the original paper's unwrapped angular comparison for the main
% ablation so that memory reorganization is the only changed factor. Set to
% true only in a separate robustness/correction experiment.
cfg.useWrappedAngles = false;

cfg.hybridGoalWeight = 0.7;
cfg.hybridClearanceWeight = 0.3;
cfg.enableCollisionGuard = false;
cfg.actionSafetyBuffer = 0;
cfg.guardGoalWeight = 0.65;
cfg.guardClearanceWeight = 0.35;
cfg.reorganizationEpochs = 10;
cfg.reorganizationMaxCandidates = Inf;
cfg.reorganizationInterval = 1;
cfg.reorganizationStartEpisode = 1;
cfg.reorganizationSuccessOnly = false;
cfg.bootstrapSamples = 10000;
cfg.permutationSamples = 10000;
cfg.saveTraces = false;
cfg.saveTrainingTraces = true;
cfg.verbose = true;

if strcmpi(mode, "paper") || strcmpi(mode, "paper_smoke")
    % Protocol aligned to Section 4 of the paper and the archived physical
    % ROS experiment. Coordinates are converted from metres to centimetres
    % so the legacy memory network keeps the numerical scale it was trained
    % with. Static occupied points come from map_new.mat; the single dynamic
    % obstacle follows the archived measured trajectory.
    rosDir = fullfile(workspaceRoot, 'matlab', 'robot_archive', 'data');
    mapFile = fullfile(rosDir, 'map_new.mat');
    dynamicFile = fullfile(rosDir, '结果数据', '动态', ...
        '待处理数据', '动态障碍物轨迹.xlsx');

    cfg.experimentName = "paper_aligned_memory_reorganization_ablation";
    cfg.outputRoot = fullfile(here, 'paper_aligned_results');
    cfg.baselineModel = fullfile(modelDir, 'yuanshiMDN2.mat');
    cfg.paperMapFile = mapFile;
    cfg.paperDynamicTrajectoryFile = dynamicFile;
    cfg.coordinateScale = 100; % 100 internal units = 1 metre

    cfg.repetitions = 30;
    cfg.seeds = 20260918 + (0:cfg.repetitions-1);
    cfg.trainEpisodes = 10;
    cfg.evalEpisodes = 1;
    cfg.evalScenarios = "dynamic";
    cfg.maxSteps = 80;

    cfg.trainStart = [0, 0];
    cfg.trainGoal = [360, -240];
    cfg.stepSize = 15;
    cfg.goalThreshold = 15;
    cfg.collisionThreshold = 15;
    cfg.dynamicCollisionThreshold = cfg.collisionThreshold;
    cfg.hybridSafetyMargin = cfg.collisionThreshold;
    cfg.worldBounds = [-55, 430, -285, 80];
    cfg.worldMin = min(cfg.worldBounds([1, 3]));
    cfg.worldMax = max(cfg.worldBounds([2, 4]));
    cfg.alternateEvaluationDirection = false;

    cfg.staticObstacles = load_paper_map_obstacles( ...
        mapFile, cfg.coordinateScale);
    trajectory = readmatrix(dynamicFile);
    trajectory = trajectory(all(isfinite(trajectory(:, 1:2)), 2), 1:2);
    trajectory = unique(trajectory, 'rows', 'stable');
    cfg.dynamicTrajectory = trajectory .* cfg.coordinateScale;
    % Section 4.2 reports two controlled starting positions.  The archived
    % measured trajectory supplies the motion shape only; it is translated
    % to the selected paper start instead of reusing its unrelated origin.
    cfg.dynamicStartPositions = [310, 0; 340, -260];
    cfg.dynamicInitial = cfg.dynamicStartPositions(1, :);
    cfg.dynamicMotionMode = "recorded_trajectory";
    cfg.dynamicTrajectoryRotationDeg = 4;
    cfg.dynamicTrajectoryJitter = 2; % 2 cm smooth trajectory variation
    cfg.dynamicSpeedFactorRange = [0.95, 1.05];
    cfg.applyDynamicCollisionResponse = false;
    cfg.dynamicSafetyRadius = 15;
    cfg.observationNoiseStd = 1; % 1 cm paired LiDAR-like noise
end

if strcmpi(mode, "reviewer") || strcmpi(mode, "reviewer_smoke")
    % Formal simulation ablation.  This stays inside the native 500-by-500
    % MDN22 coordinate system and uses the obstacle layout in the original
    % source code, avoiding an invalid mixture of the ROS map with the
    % simulation-trained network.  Evaluation layouts and trajectories are
    % generated once per seed and shared by both variants.
    cfg.experimentName = "reviewer_aligned_memory_reorganization_ablation";
    cfg.outputRoot = fullfile(here, 'reviewer_aligned_results');
    cfg.baselineModel = fullfile(modelDir, 'nice_mdn2_model.mat');
    cfg.variants = ["SOLMM-Full", "SOLMM-NoReorg", ...
        "SOLMM-NoSwitch", "SOLMM-NoGridPlace"];
    cfg.repetitions = 30;
    cfg.seeds = 20260918 + (0:cfg.repetitions-1);
    cfg.trainEpisodes = 10;
    % Four paired evaluation episodes give two repetitions of each
    % start/goal direction and each controlled dynamic crossing route.
    cfg.evalEpisodes = 4;
    cfg.evalScenarios = ["static", "dynamic"];
    cfg.maxSteps = 80;

    % Frozen after two predeclared validation searches.  Formal-test seeds
    % must not be used to change these values again.
    cfg.reorganizationEpochs = 10;
    cfg.reorganizationMaxCandidates = Inf;
    cfg.reorganizationInterval = 1;
    cfg.reorganizationStartEpisode = 1;
    cfg.reorganizationSuccessOnly = false;
    cfg.evaluationProtocolVersion = "paired_synchronized_crossing_v3";
    cfg.parameterLockStatus = "requires_paired_revalidation";
    cfg.parameterSelectionProtocol = ...
        "Reorganization setting retained from the original validation. " + ...
        "Hybrid-safety settings must be revalidated under paired-v3 on " + ...
        "seeds 20261601-20261608 before the final test is enabled.";
    cfg.parameterValidationSeeds = 20261001 + (0:7); % backward compatibility
    cfg.reorganizationValidationSeeds = 20261001 + (0:7);
    cfg.legacyHybridSafetyValidationSeeds = 20261201 + (0:7);
    cfg.legacyPairedSafetyValidationSeeds = 20261401 + (0:7);
    cfg.hybridSafetyValidationSeeds = 20261601 + (0:7);
    cfg.hybridSafetyAcceptanceThreshold = 0.80;

    % The original MDN22 map (agent_friend_weizhisuiji.m and main.m).
    cfg.staticObstacles = [ ...
         78, 330; 118, 210; 290, 382; 345, 325; 366,  78; ...
        382, 130; 360, 260; 225, 211; 195, 267; 330, 200; ...
        290, 300; 165, 170; 430, 340; 365, 395; 259, 162; ...
        135,  85; 210, 140];
    cfg.trainStart = [450, 50];
    cfg.trainGoal = [50, 450];
    cfg.worldBounds = [20, 480, 20, 480];
    cfg.staticLayoutJitter = 8;
    cfg.observationNoiseStd = 1;
    cfg.pairStaticDynamicContexts = true;
    % Provisional candidate inherited from the earlier validation protocol.
    % Re-run tune_hybrid_safety_parameters under paired-v2 before changing
    % parameterLockStatus to "locked_after_paired_revalidation".
    cfg.hybridGoalWeight = 0.60;
    cfg.hybridClearanceWeight = 0.40;
    cfg.hybridSafetyMargin = 22;

    % One dynamic obstacle moves at the robot's nominal speed. Four routes
    % are synchronized with the two start/goal directions and intersect the
    % nominal straight-line corridor at approximately step 13. Route design
    % uses only map geometry and kinematics, not algorithm outcomes.
    cfg.dynamicMotionMode = "controlled_crossing";
    cfg.dynamicStartPositions = [ ...
        229,  50; ... % forward direction, northeast crossing
        450, 271; ... % forward direction, southwest crossing
         50, 229; ... % reverse direction, northeast crossing
        271, 450];    % reverse direction, southwest crossing
    cfg.dynamicDirectionOptions = [1, 1; -1, -1; 1, 1; -1, -1];
    cfg.dynamicRouteByEpisode = [1, 3, 2, 4];
    cfg.dynamicInitial = cfg.dynamicStartPositions(1, :);
    cfg.dynamicStepScale = cfg.stepSize;
    cfg.applyDynamicCollisionResponse = false;
    cfg.dynamicSafetyRadius = cfg.collisionThreshold;
    cfg.alternateEvaluationDirection = true;
end

if strcmpi(mode, "static_complex") || ...
        strcmpi(mode, "static_complex_smoke") || ...
        strcmpi(mode, "static_random") || ...
        strcmpi(mode, "static_random_smoke") || ...
        strcmpi(mode, "dynamic_random") || ...
        strcmpi(mode, "dynamic_random_smoke")
    % Controlled static-only ablation in a 5 m by 5 m environment.  The
    % legacy controller works in centimetre-like internal coordinates, so
    % 500 internal units are plotted and reported as 5 metres.
    cfg.experimentName = "static_random_point_component_ablation";
    cfg.outputRoot = fullfile(here, 'static_random_results');
    cfg.variants = ["SOLMM-Full", "SOLMM-NoReorg", ...
        "SOLMM-AlwaysAC", "SOLMM-NoSwitch"];
    cfg.repetitions = 30;
    cfg.seeds = 20260927 + (0:cfg.repetitions-1);
    cfg.trainEpisodes = 30;
    cfg.evalEpisodes = 10;
    cfg.evalScenarios = "static";
    cfg.maxSteps = 150;

    cfg.worldBounds = [0, 500, 0, 500];
    cfg.worldMin = 0;
    cfg.worldMax = 500;
    cfg.trainStart = [50, 50];
    cfg.trainGoal = [450, 450];
    cfg.stepSize = 10;       % 0.10 m
    cfg.goalThreshold = 15;  % 0.15 m
    cfg.collisionThreshold = 14; % 0.08 m robot + 0.06 m point obstacle
    cfg.hybridSafetyMargin = 22;
    cfg.plotCoordinateScale = 100;
    cfg.referenceGridResolution = 5; % 0.05 m reference A* grid

    % A fixed, pre-generated random-point layout. Several points lie near
    % the start-goal diagonal, so the robot must make visible detours, while
    % the map remains compatible with the original local obstacle sensing
    % controller.  Do not regenerate this layout separately per variant.
    cfg.staticObstacles = [ ...
         55, 190;  85, 282; 111, 365; 123,  57; 136, 342; ...
        146, 150; 154, 394; 203, 270; 214,  95; 226, 218; ...
        244, 350; 249, 107; 254, 270; 283, 228; 285, 293; ...
        304, 232; 318, 289; 338, 408; 343, 110; 381, 231; ...
        418, 389; 422, 330; 432, 251];

    % Evaluation contexts are static but not exact duplicates.  Small,
    % paired perturbations are shared by every algorithm variant.
    cfg.staticLayoutJitter = 4; % +/- 0.04 m paired test perturbation
    cfg.endpointJitter = 8;     % +/- 0.08 m corner-region sampling
    cfg.observationNoiseStd = 0.5; % 0.005 m sensor-like noise
    cfg.alternateEvaluationDirection = false;
    cfg.pairStaticDynamicContexts = false;

    cfg.reorganizationEpochs = 10;
    cfg.reorganizationMaxCandidates = Inf;
    cfg.reorganizationInterval = 1;
    cfg.reorganizationStartEpisode = 1;
    cfg.reorganizationSuccessOnly = false;
    cfg.hybridGoalWeight = 0.60;
    cfg.hybridClearanceWeight = 0.40;
    % The scattered layout does not require the auxiliary collision guard
    % that was considered for the discarded continuous-barrier design.
    cfg.enableCollisionGuard = false;
    cfg.actionSafetyBuffer = 0;
    cfg.saveTraces = true;
    cfg.saveTrainingTraces = false;
    cfg.evaluationProtocolVersion = "static_random_points_v1";
end

if strcmpi(mode, "dynamic_random") || ...
        strcmpi(mode, "dynamic_random_smoke")
    % Dynamic extension of the locked random-point static environment.
    % Each repetition first learns the static map, then receives a short
    % dynamic adaptation phase. Evaluation freezes all offline updates.
    cfg.experimentName = "dynamic_random_point_component_ablation";
    cfg.outputRoot = fullfile(here, 'dynamic_random_results');
    cfg.repetitions = 30;
    cfg.seeds = 20261027 + (0:cfg.repetitions-1);
    cfg.trainEpisodes = 30;
    cfg.dynamicTrainEpisodes = 10;
    cfg.evalEpisodes = 10;
    cfg.evalScenarios = "dynamic";
    cfg.maxSteps = 150;

    % One controlled moving obstacle. D1 crosses the early route upward;
    % D2 crosses the late route from right to left after a fixed delay.
    % All four variants receive the exact same route and timing for each
    % seed/episode. Routes were chosen geometrically, not from outcomes.
    cfg.dynamicMotionMode = "controlled_crossing";
    cfg.dynamicStartPositions = [178, 8; 490, 360];
    cfg.dynamicDirectionOptions = [0, 1; -1, 0];
    cfg.dynamicRouteByEpisode = [1, 2];
    cfg.dynamicRouteDelayByRoute = [0, 31];
    cfg.dynamicRouteMoveStepsByRoute = [49, 17];
    cfg.dynamicInitial = cfg.dynamicStartPositions(1, :);
    cfg.dynamicStepScale = cfg.stepSize;
    cfg.dynamicCollisionThreshold = 18; % 0.08 m robot + 0.10 m obstacle
    cfg.dynamicSafetyRadius = cfg.dynamicCollisionThreshold;
    cfg.applyDynamicCollisionResponse = false;
    cfg.evaluationProtocolVersion = "dynamic_controlled_crossings_v1";
end

if strcmpi(mode, "smoke")
    cfg.repetitions = 1;
    cfg.seeds = 20260918;
    cfg.trainEpisodes = 1;
    cfg.evalEpisodes = 1;
    cfg.evalScenarios = "static";
    cfg.maxSteps = 3;
    cfg.fallbackMode = "legacy_equivalent";
    cfg.bootstrapSamples = 100;
    cfg.permutationSamples = 100;
    cfg.saveTraces = true;
end

if strcmpi(mode, "paper_smoke")
    cfg.repetitions = 1;
    cfg.seeds = 20260918;
    cfg.trainEpisodes = 1;
    cfg.evalEpisodes = 1;
    cfg.maxSteps = 3;
    cfg.bootstrapSamples = 100;
    cfg.permutationSamples = 100;
    cfg.saveTraces = true;
end


if strcmpi(mode, "reviewer_smoke")
    cfg.repetitions = 1;
    cfg.seeds = 20260918;
    cfg.trainEpisodes = 1;
    cfg.evalEpisodes = 1;
    cfg.maxSteps = 3;
    cfg.bootstrapSamples = 100;
    cfg.permutationSamples = 100;
    cfg.saveTraces = true;
end

if strcmpi(mode, "static_complex_smoke") || ...
        strcmpi(mode, "static_random_smoke")
    cfg.repetitions = 1;
    cfg.seeds = 20260927;
    cfg.trainEpisodes = 1;
    cfg.evalEpisodes = 2;
    cfg.maxSteps = 8;
    cfg.bootstrapSamples = 100;
    cfg.permutationSamples = 100;
    cfg.saveTraces = true;
    cfg.saveTrainingTraces = false;
end

if strcmpi(mode, "dynamic_random_smoke")
    cfg.repetitions = 1;
    cfg.seeds = 20261027;
    cfg.trainEpisodes = 1;
    cfg.dynamicTrainEpisodes = 1;
    cfg.evalEpisodes = 2;
    cfg.maxSteps = 60;
    cfg.bootstrapSamples = 100;
    cfg.permutationSamples = 100;
    cfg.saveTraces = true;
    cfg.saveTrainingTraces = false;
end
end
