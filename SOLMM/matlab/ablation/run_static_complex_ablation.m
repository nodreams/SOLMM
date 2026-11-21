function output = run_static_complex_ablation(mode)
%RUN_STATIC_COMPLEX_ABLATION Backward-compatible random static-map entry.
%
% output = run_static_complex_ablation()        % formal 30-seed run
% output = run_static_complex_ablation("smoke") % short software check
%
% The formal protocol evaluates four paired variants on a staggered-barrier
% map.  It writes the general audit files plus a two-metric summary and
% publication-oriented path figures.

if nargin < 1
    mode = "full";
end
if strcmpi(mode, "smoke")
    cfg = default_ablation_config("static_random_smoke");
else
    cfg = default_ablation_config("static_random");
end

output = run_reorganization_ablation(cfg);
figures = plot_static_complex_results(output.outputDir);
output.staticMetrics = figures.metricsCsv;
output.metricsFigure = figures.metricsFigure;
output.environmentFigure = figures.environmentFigure;
output.bestPathsFigure = figures.bestPathsFigure;
output.bestPathsCsv = figures.bestPathsCsv;
output.individualPathPdfs = figures.individualPathPdfs;

save(fullfile(output.outputDir, 'experiment_output.mat'), ...
    'output', 'cfg');
fprintf('Static-only figures: %s\n', output.bestPathsFigure);
end
