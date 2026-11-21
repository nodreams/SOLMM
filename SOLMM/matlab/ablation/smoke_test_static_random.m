function output = smoke_test_static_random()
%SMOKE_TEST_STATIC_RANDOM Fast integration check; not a paper result.

output = run_static_random_ablation("smoke");
episodes = readtable(output.episodeResults, TextType='string');
expected = ["SOLMM-Full", "SOLMM-NoReorg", ...
    "SOLMM-AlwaysAC", "SOLMM-NoSwitch"];
assert(isequal(unique(episodes.variant, 'stable')', expected));
assert(all(episodes.scenario == "static"));
assert(isfile(output.staticMetrics));
assert(isfile(output.metricsFigure));
assert(isfile(output.environmentFigure));
assert(isfile(output.bestPathsFigure));
assert(numel(output.individualPathPdfs) == 4 && ...
    all(isfile(output.individualPathPdfs)));
fprintf('Static-random smoke test passed: %s\n', output.outputDir);
end
