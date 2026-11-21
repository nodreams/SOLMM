function output = analyze_reorganization_ablation(inputCsv, cfg)
%ANALYZE_REORGANIZATION_ABLATION Summaries, paired tests, and figures.

data = readtable(inputCsv, TextType='string');
outputDir = fileparts(inputCsv);
evalData = data(data.phase == "eval", :);

variantDefinitions = unique(data(:, ["variant", "spatial_encoding", ...
    "switching_enabled", "reorganization_enabled"]), 'rows', 'stable');
variantDefinitionsPath = fullfile(outputDir, 'variant_definitions.csv');
writetable(variantDefinitions, variantDefinitionsPath);

trainingSummary = build_training_summary(data(data.phase == "train", :));
trainingSummaryPath = fullfile(outputDir, 'training_summary.csv');
writetable(trainingSummary, trainingSummaryPath);

replicateSummary = build_replicate_summary(evalData);
replicateSummaryPath = fullfile(outputDir, 'replicate_summary.csv');
writetable(replicateSummary, replicateSummaryPath);

overallSummary = build_overall_summary(replicateSummary);
overallSummaryPath = fullfile(outputDir, 'overall_summary.csv');
writetable(overallSummary, overallSummaryPath);

statistics = build_paired_statistics(evalData, replicateSummary, cfg);
statisticsPath = fullfile(outputDir, 'paired_statistics.csv');
writetable(statistics, statisticsPath);

figurePath = fullfile(outputDir, 'ablation_summary.png');
plot_summary(data, overallSummary, figurePath);

output = struct( ...
    'variantDefinitionsPath', variantDefinitionsPath, ...
    'trainingSummaryPath', trainingSummaryPath, ...
    'replicateSummaryPath', replicateSummaryPath, ...
    'overallSummaryPath', overallSummaryPath, ...
    'statisticsPath', statisticsPath, ...
    'figurePath', figurePath);
end

function summary = build_training_summary(data)
variants = unique(data.variant, 'stable');
episodes = unique(data.episode);
rows = struct([]);
for i = 1:numel(variants)
    for j = 1:numel(episodes)
        x = data(data.variant == variants(i) & ...
            data.episode == episodes(j), :);
        if isempty(x)
            continue;
        end
        successMask = logical(x.success);
        successValues = double(successMask);
        n = numel(successValues);
        successRate = mean(successValues);
        if n > 1
            successHalfWidth = 1.96 * std(successValues) / sqrt(n);
        else
            successHalfWidth = NaN;
        end
        row = struct( ...
            'variant', variants(i), ...
            'episode', episodes(j), ...
            'n', n, ...
            'success_rate', successRate, ...
            'success_ci95_low', max(0, successRate - successHalfWidth), ...
            'success_ci95_high', min(1, successRate + successHalfWidth), ...
            'mean_steps_success', safe_mean(x.steps(successMask)), ...
            'mean_path_length_success', ...
                safe_mean(x.path_length(successMask)), ...
            'mean_path_efficiency', mean(x.path_efficiency), ...
            'mean_min_clearance', safe_mean(x.min_clearance), ...
            'mean_reorganization_applied', ...
                mean(x.reorganization_applied));
        rows = append_struct(rows, row);
    end
end
summary = struct2table(rows);
end

function summary = build_replicate_summary(data)
seeds = unique(data.seed);
variants = unique(data.variant, 'stable');
scenarios = unique(data.scenario, 'stable');
rows = struct([]);
for i = 1:numel(seeds)
    for j = 1:numel(variants)
        for k = 1:numel(scenarios)
            mask = data.seed == seeds(i) & data.variant == variants(j) & ...
                data.scenario == scenarios(k);
            x = data(mask, :);
            if isempty(x)
                continue;
            end
            successMask = logical(x.success);
            row = struct( ...
                'seed', seeds(i), ...
                'variant', variants(j), ...
                'scenario', scenarios(k), ...
                'success_rate', mean(successMask), ...
                'mean_steps_success', safe_mean(x.steps(successMask)), ...
                'mean_path_length_success', safe_mean(x.path_length(successMask)), ...
                'mean_path_efficiency', mean(x.path_efficiency), ...
                'mean_min_clearance', safe_mean(x.min_clearance), ...
                'mean_min_static_clearance', ...
                    safe_mean(x.min_static_clearance), ...
                'mean_min_dynamic_clearance', ...
                    safe_mean(x.min_dynamic_clearance), ...
                'mean_switch_count', mean(x.switch_count), ...
                'model_y011_update_delta', max(x.model_y011_update_delta), ...
                'model_z_update_delta', max(x.model_z_update_delta));
            rows = append_struct(rows, row);
        end
    end
end
summary = struct2table(rows);
end

function overall = build_overall_summary(data)
variants = unique(data.variant, 'stable');
scenarios = unique(data.scenario, 'stable');
metrics = ["success_rate", "mean_steps_success", ...
    "mean_path_length_success", "mean_path_efficiency", ...
    "mean_min_clearance", "mean_min_static_clearance", ...
    "mean_min_dynamic_clearance", "mean_switch_count", ...
    "model_y011_update_delta"];
rows = struct([]);
for i = 1:numel(variants)
    for j = 1:numel(scenarios)
        mask = data.variant == variants(i) & data.scenario == scenarios(j);
        x = data(mask, :);
        for k = 1:numel(metrics)
            values = x.(metrics(k));
            values = values(~isnan(values));
            n = numel(values);
            mu = safe_mean(values);
            sd = safe_std(values);
            if n > 1
                halfWidth = 1.96 * sd / sqrt(n);
            else
                halfWidth = NaN;
            end
            row = struct('variant', variants(i), 'scenario', scenarios(j), ...
                'metric', metrics(k), 'n', n, 'mean', mu, 'sd', sd, ...
                'ci95_low', mu - halfWidth, 'ci95_high', mu + halfWidth);
            rows = append_struct(rows, row);
        end
    end
end
overall = struct2table(rows);
end

function stats = build_paired_statistics(evalData, replicateSummary, cfg)
scenarios = unique(replicateSummary.scenario, 'stable');
variants = unique(replicateSummary.variant, 'stable');
ablations = variants(variants ~= "SOLMM-Full");
metrics = ["success_rate", "mean_steps_success", ...
    "mean_path_length_success", "mean_path_efficiency", ...
    "mean_min_clearance", "mean_switch_count", ...
    "model_y011_update_delta"];
rows = struct([]);
for i = 1:numel(scenarios)
    scenario = scenarios(i);
    for aIndex = 1:numel(ablations)
        ablation = ablations(aIndex);
        comparison = "SOLMM-Full vs " + ablation;
        full = replicateSummary( ...
            replicateSummary.variant == "SOLMM-Full" & ...
            replicateSummary.scenario == scenario, :);
        ablated = replicateSummary( ...
            replicateSummary.variant == ablation & ...
            replicateSummary.scenario == scenario, :);
        full = full(:, ["seed", metrics]);
        ablated = ablated(:, ["seed", metrics]);
        full = renamevars(full, metrics, metrics + "_full");
        ablated = renamevars(ablated, metrics, metrics + "_ablated");
        paired = innerjoin(full, ablated, Keys='seed');

        for j = 1:numel(metrics)
            a = paired.(metrics(j) + "_full");
            b = paired.(metrics(j) + "_ablated");
            valid = ~isnan(a) & ~isnan(b);
            differences = a(valid) - b(valid);
            testSeed = 9000 + i * 1000 + aIndex * 100 + j;
            [ciLow, ciHigh] = paired_bootstrap_ci( ...
                differences, cfg.bootstrapSamples, testSeed);
            p = sign_flip_pvalue(differences, cfg.permutationSamples, ...
                testSeed + 10000);
            effect = safe_mean(differences) / safe_std(differences);
            row = struct('scenario', scenario, ...
                'comparison', comparison, 'metric', metrics(j), ...
                'n_pairs', numel(differences), ...
                'mean_difference_full_minus_ablation', ...
                    safe_mean(differences), ...
                'ci95_low', ciLow, 'ci95_high', ciHigh, ...
                'paired_effect_dz', effect, 'p_value', p, ...
                'test', "paired sign-flip permutation");
            rows = append_struct(rows, row);
        end

        fullEpisodes = evalData(evalData.variant == "SOLMM-Full" & ...
            evalData.scenario == scenario, :);
        ablatedEpisodes = evalData(evalData.variant == ablation & ...
            evalData.scenario == scenario, :);
        pairKeys = ["seed", "scenario", "episode", "start_x", "start_y", ...
            "goal_x", "goal_y"];
        fullEpisodes = fullEpisodes(:, [pairKeys, "success"]);
        ablatedEpisodes = ablatedEpisodes(:, [pairKeys, "success"]);
        fullEpisodes = renamevars(fullEpisodes, "success", "success_full");
        ablatedEpisodes = renamevars(ablatedEpisodes, "success", ...
            "success_ablated");
        episodePairs = innerjoin(fullEpisodes, ablatedEpisodes, Keys=pairKeys);
        b = sum(episodePairs.success_full == 1 & ...
            episodePairs.success_ablated == 0);
        c = sum(episodePairs.success_full == 0 & ...
            episodePairs.success_ablated == 1);
        p = exact_mcnemar_pvalue(b, c);
        row = struct('scenario', scenario, 'comparison', comparison, ...
            'metric', "episode_success", 'n_pairs', height(episodePairs), ...
            'mean_difference_full_minus_ablation', ...
                mean(double(episodePairs.success_full)) - ...
                mean(double(episodePairs.success_ablated)), ...
            'ci95_low', NaN, 'ci95_high', NaN, ...
            'paired_effect_dz', NaN, 'p_value', p, ...
            'test', "exact McNemar");
        rows = append_struct(rows, row);
    end
end
stats = struct2table(rows);
stats.p_value_holm = holm_adjust(stats.p_value);
end

function adjusted = holm_adjust(pValues)
% Family-wise error correction across the planned Full-vs-ablation tests.
adjusted = NaN(size(pValues));
valid = find(~isnan(pValues));
if isempty(valid)
    return;
end
[sorted, order] = sort(pValues(valid));
m = numel(sorted);
corrected = zeros(m, 1);
running = 0;
for i = 1:m
    running = max(running, (m - i + 1) * sorted(i));
    corrected(i) = min(1, running);
end
adjusted(valid(order)) = corrected;
end

function [low, high] = paired_bootstrap_ci(differences, samples, seed)
differences = differences(:);
if isempty(differences)
    low = NaN;
    high = NaN;
    return;
elseif numel(differences) == 1
    low = differences(1);
    high = differences(1);
    return;
end
stream = RandStream('mt19937ar', 'Seed', seed);
n = numel(differences);
means = zeros(samples, 1);
for i = 1:samples
    idx = randi(stream, n, n, 1);
    means(i) = mean(differences(idx));
end
means = sort(means);
low = means(max(1, round(0.025 * samples)));
high = means(min(samples, round(0.975 * samples)));
end

function p = sign_flip_pvalue(differences, samples, seed)
differences = differences(:);
differences = differences(~isnan(differences));
if isempty(differences)
    p = NaN;
    return;
end
observed = abs(mean(differences));
stream = RandStream('mt19937ar', 'Seed', seed);
extreme = 0;
for i = 1:samples
    signs = 2 * (rand(stream, numel(differences), 1) >= 0.5) - 1;
    extreme = extreme + (abs(mean(signs .* differences)) >= observed);
end
p = (extreme + 1) / (samples + 1);
end

function p = exact_mcnemar_pvalue(b, c)
n = b + c;
if n == 0
    p = 1;
    return;
end
k = min(b, c);
terms = zeros(k + 1, 1);
for i = 0:k
    terms(i + 1) = exp(gammaln(n + 1) - gammaln(i + 1) - ...
        gammaln(n - i + 1) - n * log(2));
end
p = min(1, 2 * sum(terms));
end

function plot_summary(data, overall, outputPath)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 850]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

train = data(data.phase == "train", :);
nexttile(layout);
hold on;
variants = unique(train.variant, 'stable');
colors = lines(max(2, numel(variants)));
for i = 1:numel(variants)
    means = NaN(max(train.episode), 1);
    errors = NaN(max(train.episode), 1);
    for episode = 1:max(train.episode)
        values = double(train.success(train.variant == variants(i) & ...
            train.episode == episode));
        means(episode) = mean(values);
        if numel(values) > 1
            errors(episode) = 1.96 * std(values) / sqrt(numel(values));
        else
            errors(episode) = 0;
        end
    end
    errorbar(1:numel(means), means, errors, '-o', 'LineWidth', 1.5, ...
        'Color', colors(i, :), 'DisplayName', variants(i));
end
xlabel('Training episode'); ylabel('Success rate'); ylim([0, 1.05]);
title('Training success'); legend('Location', 'best'); grid on;

plot_overall_metric(nexttile(layout), overall, "success_rate", ...
    'Evaluation success rate', 'Success rate');
plot_overall_metric(nexttile(layout), overall, "mean_path_efficiency", ...
    'Evaluation path efficiency', 'Straight-line / actual path');
plot_overall_metric(nexttile(layout), overall, "model_y011_update_delta", ...
    'Offline memory update mass', 'Y_{011} age increment');

title(layout, 'SOLMM component ablation');
exportgraphics(fig, outputPath, 'Resolution', 200);
close(fig);
end

function plot_overall_metric(ax, overall, metric, chartTitle, yLabel)
subset = overall(overall.metric == metric, :);
scenarios = unique(subset.scenario, 'stable');
variants = unique(subset.variant, 'stable');
values = NaN(numel(scenarios), numel(variants));
errors = NaN(size(values));
for i = 1:numel(scenarios)
    for j = 1:numel(variants)
        row = subset(subset.scenario == scenarios(i) & ...
            subset.variant == variants(j), :);
        if ~isempty(row)
            values(i, j) = row.mean(1);
            errors(i, j) = row.ci95_high(1) - row.mean(1);
        end
    end
end
b = bar(ax, values, 'grouped');
hold(ax, 'on');
for j = 1:numel(b)
    x = b(j).XEndPoints;
    errorbar(ax, x, values(:, j), errors(:, j), 'k.', 'LineWidth', 1);
end
if numel(scenarios) == 1
    cla(ax);
    bar(ax, 1:numel(variants), values(1, :));
    hold(ax, 'on');
    errorbar(ax, 1:numel(variants), values(1, :), errors(1, :), ...
        'k.', 'LineWidth', 1);
    set(ax, 'XTick', 1:numel(variants), 'XTickLabel', cellstr(variants));
    xlabel(ax, char(scenarios(1)));
else
    set(ax, 'XTick', 1:numel(scenarios), ...
        'XTickLabel', cellstr(scenarios));
    legend(ax, cellstr(variants), 'Location', 'best');
end
if metric == "success_rate" || metric == "mean_path_efficiency"
    ylim(ax, [0, 1.05]);
end
ylabel(ax, yLabel); title(ax, chartTitle); grid(ax, 'on');
end

function value = safe_mean(values)
values = values(~isnan(values));
if isempty(values), value = NaN; else, value = mean(values); end
end

function value = safe_std(values)
values = values(~isnan(values));
if numel(values) < 2, value = NaN; else, value = std(values); end
end

function rows = append_struct(rows, row)
if isempty(rows), rows = row; else, rows(end+1) = row; end %#ok<AGROW>
end
