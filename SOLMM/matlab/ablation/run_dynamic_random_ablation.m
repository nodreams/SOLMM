function output = run_dynamic_random_ablation(mode)
%RUN_DYNAMIC_RANDOM_ABLATION Run the controlled dynamic component study.
%
% output = run_dynamic_random_ablation()        % formal 30-seed run
% output = run_dynamic_random_ablation("smoke") % software check only

if nargin < 1
    mode = "full";
end
if strcmpi(mode, "smoke")
    cfg = default_ablation_config("dynamic_random_smoke");
else
    cfg = default_ablation_config("dynamic_random");
end

output = run_reorganization_ablation(cfg);
figures = plot_dynamic_random_results(output.outputDir);
output.dynamicMetrics = figures.metricsCsv;
output.metricsFigure = figures.metricsFigure;
output.environmentFigure = figures.environmentFigure;
output.bestPathsFigure = figures.bestPathsFigure;
output.bestPathsCsv = figures.bestPathsCsv;
output.individualPathPdfs = figures.individualPathPdfs;
save(fullfile(output.outputDir, 'experiment_output.mat'), ...
    'output', 'cfg');
fprintf('Dynamic experiment figures: %s\n', output.bestPathsFigure);
end
