function outputs = plot_dynamic_random_results(resultDir)
%PLOT_DYNAMIC_RANDOM_RESULTS Plot dynamic success, length and trajectories.

arguments
    resultDir (1, 1) string = ""
end

if strlength(resultDir) == 0
    here = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(here, 'dynamic_random_results');
    candidates = dir(resultRoot);
    candidates = candidates([candidates.isdir]);
    candidates = candidates(~ismember({candidates.name}, {'.', '..'}));
    assert(~isempty(candidates), ...
        'No dynamic result folders were found in %s.', resultRoot);
    [~, newestIndex] = max([candidates.datenum]);
    resultDir = string(fullfile(resultRoot, candidates(newestIndex).name));
    fprintf('Using latest dynamic result folder: %s\n', resultDir);
end

episodePath = fullfile(resultDir, 'episode_results.csv');
statePath = fullfile(resultDir, 'experiment_output.mat');
assert(isfile(episodePath), 'Missing episode_results.csv in %s.', resultDir);
assert(isfile(statePath), 'Missing experiment_output.mat in %s.', resultDir);
data = readtable(episodePath, TextType='string');
state = load(statePath, 'cfg');
cfg = state.cfg;
scale = cfg.plotCoordinateScale;
evaluation = data(data.phase == "eval" & data.scenario == "dynamic", :);
assert(~isempty(evaluation), 'No dynamic evaluation rows were found.');

[summary, seedSummary] = summarize_metrics(evaluation, scale);
metricsCsv = fullfile(resultDir, 'dynamic_metrics.csv');
seedCsv = fullfile(resultDir, 'dynamic_seed_metrics.csv');
writetable(summary, metricsCsv);
writetable(seedSummary, seedCsv);

metricsFigure = fullfile(resultDir, 'dynamic_success_and_path_length.png');
plot_metric_figure(summary, metricsFigure);

[environmentFigure, bestPathsFigure, bestPathsCsv, individualPathPdfs] = ...
    plot_dynamic_paths(evaluation, cfg, resultDir, scale);

outputs = struct('metricsCsv', metricsCsv, 'seedMetricsCsv', seedCsv, ...
    'metricsFigure', metricsFigure, ...
    'environmentFigure', environmentFigure, ...
    'bestPathsFigure', bestPathsFigure, 'bestPathsCsv', bestPathsCsv, ...
    'individualPathPdfs', individualPathPdfs);
end

function [summary, seedSummary] = summarize_metrics(data, scale)
variants = unique(data.variant, 'stable');
seeds = unique(data.seed, 'stable');
seedRows = struct([]);
for variantIndex = 1:numel(variants)
    for seedIndex = 1:numel(seeds)
        x = data(data.variant == variants(variantIndex) & ...
            data.seed == seeds(seedIndex), :);
        if isempty(x)
            continue;
        end
        success = logical(x.success);
        row = struct('seed', seeds(seedIndex), ...
            'variant', variants(variantIndex), ...
            'evaluation_trials', height(x), ...
            'successes', sum(success), ...
            'success_rate', mean(success), ...
            'mean_path_length_success_m', ...
                safe_mean(x.path_length(success) ./ scale));
        seedRows = append_row(seedRows, row);
    end
end
seedSummary = struct2table(seedRows);

rows = struct([]);
for variantIndex = 1:numel(variants)
    x = data(data.variant == variants(variantIndex), :);
    bySeed = seedSummary(seedSummary.variant == variants(variantIndex), :);
    successValues = bySeed.success_rate;
    pathValues = bySeed.mean_path_length_success_m;
    pathValues = pathValues(~isnan(pathValues));
    [successMean, successSd, successLow, successHigh] = mean_ci(successValues);
    [pathMean, pathSd, pathLow, pathHigh] = mean_ci(pathValues);
    row = struct('variant', variants(variantIndex), ...
        'independent_seeds', height(bySeed), ...
        'evaluation_trials', height(x), ...
        'successful_trials', sum(logical(x.success)), ...
        'success_rate', successMean, ...
        'success_sd_across_seeds', successSd, ...
        'success_ci95_low', max(0, successLow), ...
        'success_ci95_high', min(1, successHigh), ...
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
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1300, 520]);
layout = tiledlayout(fig, 1, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

ax = nexttile(layout);
values = 100 .* summary.success_rate;
lower = 100 .* (summary.success_rate - summary.success_ci95_low);
upper = 100 .* (summary.success_ci95_high - summary.success_rate);
b = bar(ax, 1:numel(variants), values, 'FaceColor', 'flat');
b.CData = colors;
hold(ax, 'on');
errorbar(ax, 1:numel(variants), values, lower, upper, ...
    'k.', 'LineWidth', 1.4, 'CapSize', 10);
ylabel(ax, 'Evaluation success rate (%)');
title(ax, '(a) Dynamic navigation success');
ylim(ax, [0, 105]);
format_axis(ax, variants);

ax = nexttile(layout);
values = summary.mean_path_length_success_m;
lower = values - summary.path_length_ci95_low_m;
upper = summary.path_length_ci95_high_m - values;
b = bar(ax, 1:numel(variants), values, 'FaceColor', 'flat');
b.CData = colors;
hold(ax, 'on');
errorbar(ax, 1:numel(variants), values, lower, upper, ...
    'k.', 'LineWidth', 1.4, 'CapSize', 10);
ylabel(ax, 'Path length of successful trials (m)');
title(ax, '(b) Dynamic navigation path length');
format_axis(ax, variants);

title(layout, 'Dynamic component ablation (mean and 95% CI across seeds)');
print(fig, outputPath, '-dpng', '-r300');
close(fig);
end

function format_axis(ax, variants)
set(ax, 'XTick', 1:numel(variants), 'XTickLabel', cellstr(variants), ...
    'FontName', 'Arial', 'FontSize', 10);
xtickangle(ax, 18);
grid(ax, 'on');
box(ax, 'on');
end

function [environmentPath, comparisonPath, csvPath, pdfPaths] = ...
        plot_dynamic_paths(data, cfg, resultDir, scale)
variants = unique(data.variant, 'stable');
traceRoot = fullfile(resultDir, 'traces');
assert(isfolder(traceRoot), 'Dynamic trajectory files were not saved.');
comparisonPath = fullfile(resultDir, 'dynamic_best_observed_paths.png');
csvPath = fullfile(resultDir, 'dynamic_best_observed_paths.csv');
environmentPath = fullfile(resultDir, 'dynamic_environment_best_path.png');
pdfPaths = strings(numel(variants), 1);
rows = struct([]);

fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 80, 1250, 1000]);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

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
    traceName = sprintf('seed_%d_%s_eval_dynamic_%02d.mat', ...
        selected.seed, token, selected.episode);
    tracePath = fullfile(traceRoot, traceName);
    assert(isfile(tracePath), 'Missing trace file: %s', tracePath);
    loaded = load(tracePath, 'trace');
    trace = loaded.trace;

    ax = nexttile(layout);
    draw_dynamic_scene(ax, trace, cfg, scale);
    title(ax, char(variant), 'Interpreter', 'none');

    pdfPaths(variantIndex) = fullfile(resultDir, ...
        sprintf('%s_dynamic_best_path.pdf', token));
    export_individual_pdf(trace, cfg, scale, pdfPaths(variantIndex));
    if variant == "SOLMM-Full"
        export_individual_png(trace, cfg, scale, environmentPath);
    end

    row = struct('variant', variant, 'selection', selectionLabel, ...
        'seed', selected.seed, 'episode', selected.episode, ...
        'success', logical(selected.success), 'status', selected.status, ...
        'observed_path_length_m', selected.path_length ./ scale, ...
        'trace_file', string(tracePath));
    rows = append_row(rows, row);
end

print(fig, comparisonPath, '-dpng', '-r300');
close(fig);
writetable(struct2table(rows), csvPath);
end

function draw_dynamic_scene(ax, trace, cfg, scale)
hold(ax, 'on');
scatter(ax, trace.staticObstacles(:, 1) ./ scale, ...
    trace.staticObstacles(:, 2) ./ scale, 18, 'k', 'filled');
plot(ax, trace.path(:, 1) ./ scale, trace.path(:, 2) ./ scale, ...
    'r.', 'MarkerSize', 9);
dynamicPath = squeeze(trace.dynamicPath(:, 1, :));
if size(dynamicPath, 2) ~= 2
    dynamicPath = reshape(dynamicPath, [], 2);
end
plot(ax, dynamicPath(:, 1) ./ scale, dynamicPath(:, 2) ./ scale, ...
    'b.', 'MarkerSize', 8);
scatter(ax, trace.startPosition(1) ./ scale, ...
    trace.startPosition(2) ./ scale, 80, [1, 0, 0], 'filled');
plot(ax, trace.goalPosition(1) ./ scale, ...
    trace.goalPosition(2) ./ scale, 'g*', 'MarkerSize', 13, ...
    'LineWidth', 1.6);
axis(ax, [cfg.worldBounds(1:2), cfg.worldBounds(3:4)] ./ scale);
axis(ax, 'equal');
grid(ax, 'off');
box(ax, 'on');
xlabel(ax, 'X');
ylabel(ax, 'Y');
set(ax, 'FontName', 'Arial', 'FontSize', 10);
end

function export_individual_pdf(trace, cfg, scale, outputPath)
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 760, 680]);
ax = axes(fig);
draw_dynamic_scene(ax, trace, cfg, scale);
exportgraphics(fig, outputPath, 'ContentType', 'vector', ...
    'BackgroundColor', 'white');
close(fig);
end

function export_individual_png(trace, cfg, scale, outputPath)
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 760, 680]);
ax = axes(fig);
draw_dynamic_scene(ax, trace, cfg, scale);
print(fig, outputPath, '-dpng', '-r300');
close(fig);
end

function [mu, sd, low, high] = mean_ci(values)
values = values(~isnan(values));
if isempty(values)
    mu = NaN; sd = NaN; low = NaN; high = NaN;
elseif isscalar(values)
    mu = values(1); sd = 0; low = mu; high = mu;
else
    mu = mean(values);
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
