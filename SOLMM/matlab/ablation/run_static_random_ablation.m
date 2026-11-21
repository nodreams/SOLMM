function output = run_static_random_ablation(mode)
%RUN_STATIC_RANDOM_ABLATION Run the 5 m x 5 m random-point static study.
%
% output = run_static_random_ablation()        % formal 30-seed run
% output = run_static_random_ablation("smoke") % short software check

if nargin < 1
    mode = "full";
end
output = run_static_complex_ablation(mode);
end
