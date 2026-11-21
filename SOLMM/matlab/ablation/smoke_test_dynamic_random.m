function output = smoke_test_dynamic_random()
%SMOKE_TEST_DYNAMIC_RANDOM Fast integration check; not a paper result.

output = run_dynamic_random_ablation("smoke");
episodes = readtable(output.episodeResults, TextType='string');
expected = ["SOLMM-Full", "SOLMM-NoReorg", ...
    "SOLMM-AlwaysAC", "SOLMM-NoSwitch"];
assert(isequal(unique(episodes.variant, 'stable')', expected));
assert(any(episodes.phase == "dynamic_train"));
evaluation = episodes(episodes.phase == "eval", :);
assert(all(evaluation.scenario == "dynamic"));
assert(isfile(output.dynamicMetrics));
assert(isfile(output.metricsFigure));
assert(isfile(output.environmentFigure));
assert(isfile(output.bestPathsFigure));
assert(numel(output.individualPathPdfs) == 4 && ...
    all(isfile(output.individualPathPdfs)));
fprintf('Dynamic-random smoke test passed: %s\n', output.outputDir);
end
