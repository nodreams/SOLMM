function outputs = plot_static_complex_results(resultDir)
%PLOT_STATIC_COMPLEX_RESULTS Plot static success, length, and best paths.
%
% Success-rate and path-length uncertainty is computed across independent
% seeds.  Path length is conditioned on successful evaluation episodes.
% Trajectory figures intentionally use a clean paper style: point
% obstacles, observed trajectory, start, goal and coordinate axes only.

arguments
    resultDir (1, 1) string = ""
end

if strlength(resultDir) == 0
    here = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(here, 'static_random_results');
    candidates = dir(resultRoot);
    candidates = candidates([candidates.isdir]);
    candidates = candidates(~ismember({candidates.name}, {'.', '..'}));
    assert(~isempty(candidates), ...
        'No result folders were found in %s.', resultRoot);
    [~, newestIndex] = max([candidates.datenum]);
    resultDir = string(fullfile(resultRoot, candidates(newestIndex).name));
    fprintf('Using latest static result folder: %s\n', resultDir);
end

episodePath = fullfile(resultDir, 'episode_results.csv');
statePath = fullfile(resultDir, 'experiment_output.mat');
assert(isfile(episodePath), 'Missing episode_results.csv in %s.', resultDir);
assert(isfile(statePath), 'Missing experiment_output.mat in %s.', resultDir);

data = readtable(episodePath, TextType='string');
state = load(statePath, 'cfg');
cfg = state.cfg;
scale = cfg.plotCoordinateScale;
evaluation = data(data.phase == "eval" & data.scenario == "static", :);
assert(~isempty(evaluation), 'No static evaluation rows were found.');

[summary, seedSummary] = summarize_static_metrics(evaluation, scale);
metricsCsv = fullfile(resultDir, 'static_metrics.csv');
seedCsv = fullfile(resultDir, 'static_seed_metrics.csv');
writetable(summary, metricsCsv);
writetable(seedSummary, seedCsv);

metricsFigure = fullfile(resultDir, 'static_success_and_path_length.png');
plot_metric_figure(summary, metricsFigure);

environmentFigure = plot_environment_best_path( ...
    evaluation, cfg, resultDir, scale);

[bestPathsFigure, bestPathsCsv, individualPathPdfs] = plot_best_paths( ...
    evaluation, cfg, resultDir, scale);

outputs = struct('metricsCsv', metricsCsv, 'seedMetricsCsv', seedCsv, ...
    'metricsFigure', metricsFigure, ...
    'environmentFigure', environmentFigure, ...
    'bestPathsFigure', bestPathsFigure, 'bestPathsCsv', bestPathsCsv, ...
    'individualPathPdfs', individualPathPdfs);
end

function figurePath = plot_environment_best_path(data, cfg, resultDir, scale)
full = data(data.variant == "SOLMM-Full", :);
successful = full(logical(full.success), :);
if isempty(successful)
    [~, selectedIndex] = min(full.final_distance);
    selected = full(selectedIndex, :);
else
    [~, selectedIndex] = min(successful.path_length);
    selected = successful(selectedIndex, :);
end
token = lower(regexprep(char(selected.variant), '[^A-Za-z0-9]+', '_'));
traceName = sprintf('seed_%d_%s_eval_static_%02d.mat', ...
    selected.seed, token, selected.episode);
loaded = load(fullfile(resultDir, 'traces', traceName), 'trace');
trace = loaded.trace;

figurePath = fullfile(resultDir, 'static_environment_best_path.png');
obsoleteFigure = fullfile(resultDir, 'static_environment_reference_path.png');
obsoleteCsv = fullfile(resultDir, 'reference_shortest_path.csv');
if isfile(obsoleteFigure)
    delete(obsoleteFigure);
end
if isfile(obsoleteCsv)
    delete(obsoleteCsv);
end

figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 760, 680]);
ax = axes(figureHandle);
hold(ax, 'on');
draw_point_obstacles(ax, trace.staticObstacles, scale);
plot(ax, trace.path(:, 1) ./ scale, trace.path(:, 2) ./ scale, ...
    'r.', 'MarkerSize', 10);
scatter(ax, trace.startPosition(1) ./ scale, ...
    trace.startPosition(2) ./ scale, 105, [1.00, 0.00, 0.00], 'filled');
plot(ax, trace.goalPosition(1) ./ scale, ...
    trace.goalPosition(2) ./ scale, 'g*', 'MarkerSize', 15, ...
    'LineWidth', 1.8);
axis(ax, [cfg.worldBounds(1:2), cfg.worldBounds(3:4)] ./ scale);
axis(ax, 'equal');
grid(ax, 'off');
box(ax, 'on');
xlabel(ax, 'X');
ylabel(ax, 'Y');
set(ax, 'FontName', 'Arial', 'FontSize', 11);
print(figureHandle, figurePath, '-dpng', '-r300');
close(figureHandle);
end

function [summary, seedSummary] = summarize_static_metrics(data, scale)
variants = unique(data.variant, 'stable');
seeds = unique(data.seed, 'stable');
seedRows = struct([]);
for variantIndex = 1:numel(variants)
    for seedIndex = 1:numel(seeds)
        subset = data(data.variant == variants(variantIndex) & ...
            data.seed == seeds(seedIndex), :);
        if isempty(subset)
            continue;
        end
        success = logical(subset.success);
        pathValues = subset.path_length(success) ./ scale;
        row = struct('seed', seeds(seedIndex), ...
            'variant', variants(variantIndex), ...
            'evaluation_trials', height(subset), ...
            'successes', sum(success), ...
            'success_rate', mean(success), ...
            'mean_path_length_success_m', safe_mean(pathValues));
        seedRows = append_row(seedRows, row);
    end
end
seedSummary = struct2table(seedRows);

rows = struct([]);
for variantIndex = 1:numel(variants)
    subset = data(data.variant == variants(variantIndex), :);
    bySeed = seedSummary(seedSummary.variant == variants(variantIndex), :);
    successValues = bySeed.success_rate;
    pathValues = bySeed.mean_path_length_success_m;
    pathValues = pathValues(~isnan(pathValues));
    [successMean, successSd, successLow, successHigh] = ...
        mean_ci(successValues);
    [pathMean, pathSd, pathLow, pathHigh] = mean_ci(pathValues);
    successLow = max(0, successLow);
    successHigh = min(1, successHigh);
    row = struct('variant', variants(variantIndex), ...
        'independent_seeds', height(bySeed), ...
        'evaluation_trials', height(subset), ...
        'successful_trials', sum(logical(subset.success)), ...
        'success_rate', successMean, ...
        'success_sd_across_seeds', successSd, ...
        'success_ci95_low', successLow, ...
        'success_ci95_high', successHigh, ...
        'path_length_seeds_with_success', numel(pathValues), ...
        'mean_path_length_success_m', pathMean, ...
        'path_length_sd_across_seeds_m', pathSd, ...
        'path_length_ci95_low_m', pathLow, ...
        'path_length_ci95_high_m', pathHigh);
    rows = append_row(rows, row);
end
summary = struct2table(rows);
end

function plot_metric_figure(summary, outputPath)
variants = string(summary.variant);
colors = lines(numel(variants));
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1300, 520]);
layout = tiledlayout(figureHandle, 1, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

ax = nexttile(layout);
values = 100 .* summary.success_rate;
lower = 100 .* (summary.success_rate - summary.success_ci95_low);
upper = 100 .* (summary.success_ci95_high - summary.success_rate);
barHandle = bar(ax, 1:numel(variants), values, 'FaceColor', 'flat');
barHandle.CData = colors;
hold(ax, 'on');
errorbar(ax, 1:numel(variants), values, lower, upper, ...
    'k.', 'LineWidth', 1.4, 'CapSize', 10);
ylabel(ax, 'Evaluation success rate (%)');
title(ax, '(a) Static navigation success');
ylim(ax, [0, 105]);
format_variant_axis(ax, variants);

ax = nexttile(layout);
values = summary.mean_path_length_success_m;
lower = values - summary.path_length_ci95_low_m;
upper = summary.path_length_ci95_high_m - values;
barHandle = bar(ax, 1:numel(variants), values, 'FaceColor', 'flat');
barHandle.CData = colors;
hold(ax, 'on');
errorbar(ax, 1:numel(variants), values, lower, upper, ...
    'k.', 'LineWidth', 1.4, 'CapSize', 10);
ylabel(ax, 'Path length of successful trials (m)');
title(ax, '(b) Static navigation path length');
format_variant_axis(ax, variants);

title(layout, 'Static component ablation (mean and 95% CI across seeds)');
print(figureHandle, outputPath, '-dpng', '-r300');
close(figureHandle);
end

function format_variant_axis(ax, variants)
set(ax, 'XTick', 1:numel(variants), 'XTickLabel', cellstr(variants), ...
    'FontName', 'Arial', 'FontSize', 10);
xtickangle(ax, 18);
grid(ax, 'on');
box(ax, 'on');
end

function [figurePath, csvPath, individualPdfPaths] = ...
        plot_best_paths(data, cfg, resultDir, scale)
variants = unique(data.variant, 'stable');
traceRoot = fullfile(resultDir, 'traces');
assert(isfolder(traceRoot), ...
    'Trajectory files are required to draw the static path figure.');

figurePath = fullfile(resultDir, 'static_best_observed_paths.png');
csvPath = fullfile(resultDir, 'static_best_observed_paths.csv');
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 80, 1250, 1000]);
layout = tiledlayout(figureHandle, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
colors = lines(numel(variants));
rows = struct([]);
individualPdfPaths = strings(numel(variants), 1);

for variantIndex = 1:numel(variants)
    variant = variants(variantIndex);
    subset = data(data.variant == variant, :);
    successful = subset(logical(subset.success), :);
    if isempty(successful)
        [~, selectedIndex] = min(subset.final_distance);
        selected = subset(selectedIndex, :);
        selectionLabel = "closest failed trial";
    else
        [~, selectedIndex] = min(successful.path_length);
        selected = successful(selectedIndex, :);
        selectionLabel = "best observed successful trial";
    end

    token = lower(regexprep(char(variant), '[^A-Za-z0-9]+', '_'));
    traceName = sprintf('seed_%d_%s_eval_static_%02d.mat', ...
        selected.seed, token, selected.episode);
    tracePath = fullfile(traceRoot, traceName);
    assert(isfile(tracePath), 'Missing trace file: %s', tracePath);
    loaded = load(tracePath, 'trace');
    trace = loaded.trace;

    individualPdfPaths(variantIndex) = plot_individual_path_pdf( ...
        trace, variant, cfg, resultDir, scale);

    ax = nexttile(layout);
    hold(ax, 'on');
    draw_point_obstacles(ax, trace.staticObstacles, scale);
    plot(ax, trace.path(:, 1) ./ scale, trace.path(:, 2) ./ scale, ...
        '.', 'Color', colors(variantIndex, :), 'MarkerSize', 8);
    scatter(ax, trace.startPosition(1) ./ scale, ...
        trace.startPosition(2) ./ scale, 70, [1.00, 0.00, 0.00], 'filled');
    plot(ax, trace.goalPosition(1) ./ scale, ...
        trace.goalPosition(2) ./ scale, 'g*', 'MarkerSize', 12, ...
        'LineWidth', 1.5);
    axis(ax, [cfg.worldBounds(1:2), cfg.worldBounds(3:4)] ./ scale);
    axis(ax, 'equal');
    grid(ax, 'off');
    box(ax, 'on');
    xlabel(ax, 'x (m)');
    ylabel(ax, 'y (m)');
    observedLength = selected.path_length ./ scale;
    title(ax, char(variant), 'Interpreter', 'none');

    row = struct('variant', variant, 'selection', selectionLabel, ...
        'seed', selected.seed, 'episode', selected.episode, ...
        'success', logical(selected.success), 'status', selected.status, ...
        'observed_path_length_m', observedLength, ...
        'trace_file', string(tracePath));
    rows = append_row(rows, row);
end

print(figureHandle, figurePath, '-dpng', '-r300');
close(figureHandle);
writetable(struct2table(rows), csvPath);
end

function pdfPath = plot_individual_path_pdf( ...
        trace, variant, cfg, resultDir, scale)
token = lower(regexprep(char(variant), '[^A-Za-z0-9]+', '_'));
pdfPath = string(fullfile(resultDir, ...
    sprintf('%s_best_path.pdf', token)));

figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 760, 680]);
ax = axes(figureHandle);
hold(ax, 'on');
draw_point_obstacles(ax, trace.staticObstacles, scale);
plot(ax, trace.path(:, 1) ./ scale, trace.path(:, 2) ./ scale, ...
    'r.', 'MarkerSize', 10);
scatter(ax, trace.startPosition(1) ./ scale, ...
    trace.startPosition(2) ./ scale, 105, [1.00, 0.00, 0.00], 'filled');
plot(ax, trace.goalPosition(1) ./ scale, ...
    trace.goalPosition(2) ./ scale, 'g*', 'MarkerSize', 15, ...
    'LineWidth', 1.8);
axis(ax, [cfg.worldBounds(1:2), cfg.worldBounds(3:4)] ./ scale);
axis(ax, 'equal');
grid(ax, 'off');
box(ax, 'on');
xlabel(ax, 'X');
ylabel(ax, 'Y');
set(ax, 'FontName', 'Arial', 'FontSize', 11);
exportgraphics(figureHandle, pdfPath, ...
    'ContentType', 'vector', 'BackgroundColor', 'white');
close(figureHandle);
end

function draw_point_obstacles(ax, obstacles, scale)
scatter(ax, obstacles(:, 1) ./ scale, obstacles(:, 2) ./ scale, ...
    18, 'k', 'filled');
end

function [path, lengthValue] = astar_reference_path( ...
        startPosition, goalPosition, obstacles, cfg)
resolution = cfg.referenceGridResolution;
xValues = cfg.worldBounds(1):resolution:cfg.worldBounds(2);
yValues = cfg.worldBounds(3):resolution:cfg.worldBounds(4);
[xGrid, yGrid] = meshgrid(xValues, yValues);
blocked = false(size(xGrid));
for obstacleIndex = 1:size(obstacles, 1)
    blocked = blocked | hypot(xGrid - obstacles(obstacleIndex, 1), ...
        yGrid - obstacles(obstacleIndex, 2)) <= cfg.collisionThreshold;
end

[~, startX] = min(abs(xValues - startPosition(1)));
[~, startY] = min(abs(yValues - startPosition(2)));
[~, goalX] = min(abs(xValues - goalPosition(1)));
[~, goalY] = min(abs(yValues - goalPosition(2)));
blocked(startY, startX) = false;
blocked(goalY, goalX) = false;

gridSize = size(blocked);
startNode = sub2ind(gridSize, startY, startX);
goalNode = sub2ind(gridSize, goalY, goalX);
nodeCount = numel(blocked);
open = false(nodeCount, 1);
closed = false(nodeCount, 1);
gScore = inf(nodeCount, 1);
fScore = inf(nodeCount, 1);
parent = zeros(nodeCount, 1, 'uint32');
open(startNode) = true;
gScore(startNode) = 0;
fScore(startNode) = norm([xValues(startX), yValues(startY)] - ...
    [xValues(goalX), yValues(goalY)]);
offsets = [-1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];

found = false;
while any(open)
    candidates = find(open);
    [~, localIndex] = min(fScore(candidates));
    current = candidates(localIndex);
    if current == goalNode
        found = true;
        break;
    end
    open(current) = false;
    closed(current) = true;
    [currentY, currentX] = ind2sub(gridSize, current);
    currentPoint = [xValues(currentX), yValues(currentY)];

    for offsetIndex = 1:size(offsets, 1)
        nextY = currentY + offsets(offsetIndex, 1);
        nextX = currentX + offsets(offsetIndex, 2);
        if nextY < 1 || nextY > gridSize(1) || ...
                nextX < 1 || nextX > gridSize(2) || ...
                blocked(nextY, nextX)
            continue;
        end
        nextNode = sub2ind(gridSize, nextY, nextX);
        if closed(nextNode)
            continue;
        end
        nextPoint = [xValues(nextX), yValues(nextY)];
        if ~segment_is_free(currentPoint, nextPoint, obstacles, ...
                cfg.collisionThreshold, resolution)
            continue;
        end
        tentative = gScore(current) + norm(nextPoint - currentPoint);
        if tentative < gScore(nextNode)
            parent(nextNode) = current;
            gScore(nextNode) = tentative;
            fScore(nextNode) = tentative + norm(nextPoint - ...
                [xValues(goalX), yValues(goalY)]);
            open(nextNode) = true;
        end
    end
end

if ~found
    path = zeros(0, 2);
    lengthValue = NaN;
    return;
end

nodes = goalNode;
while nodes(1) ~= startNode
    previous = double(parent(nodes(1)));
    assert(previous > 0, 'A* path reconstruction failed.');
    nodes = [previous; nodes]; %#ok<AGROW>
end
[pathY, pathX] = ind2sub(gridSize, nodes);
path = [xValues(pathX)', yValues(pathY)'];
path(1, :) = startPosition;
path(end, :) = goalPosition;
path = simplify_reference_path(path, obstacles, ...
    cfg.collisionThreshold, resolution);
lengthValue = sum(sqrt(sum(diff(path, 1, 1) .^ 2, 2)));
end

function simplified = simplify_reference_path(path, obstacles, radius, resolution)
simplified = path(1, :);
anchor = 1;
while anchor < size(path, 1)
    nextIndex = size(path, 1);
    while nextIndex > anchor + 1 && ...
            ~segment_is_free(path(anchor, :), path(nextIndex, :), ...
            obstacles, radius, resolution)
        nextIndex = nextIndex - 1;
    end
    simplified(end+1, :) = path(nextIndex, :); %#ok<AGROW>
    anchor = nextIndex;
end
end

function isFree = segment_is_free(a, b, obstacles, radius, resolution)
sampleCount = max(2, ceil(norm(b - a) / max(resolution / 2, eps)) + 1);
t = linspace(0, 1, sampleCount)';
points = a + t .* (b - a);
isFree = true;
for pointIndex = 1:size(points, 1)
    distances = sqrt(sum((obstacles - points(pointIndex, :)) .^ 2, 2));
    if min(distances) <= radius
        isFree = false;
        return;
    end
end
end

function [mu, sd, low, high] = mean_ci(values)
values = values(~isnan(values));
if isempty(values)
    mu = NaN;
    sd = NaN;
    low = NaN;
    high = NaN;
    return;
end
mu = mean(values);
if numel(values) == 1
    sd = 0;
    low = mu;
    high = mu;
else
    sd = std(values);
    halfWidth = 1.96 * sd / sqrt(numel(values));
    low = mu - halfWidth;
    high = mu + halfWidth;
end
end

function value = safe_mean(values)
values = values(~isnan(values));
if isempty(values)
    value = NaN;
else
    value = mean(values);
end
end

function rows = append_row(rows, row)
if isempty(rows)
    rows = row;
else
    rows(end+1) = row; %#ok<AGROW>
end
end
