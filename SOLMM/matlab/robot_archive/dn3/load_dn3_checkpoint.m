function model = load_dn3_checkpoint()
%LOAD_DN3_CHECKPOINT Restore the model used by the archived creat_dn3 script.
weights = fullfile(fileparts(mfilename('fullpath')), 'new_mat');
first = load(fullfile(weights, 'env28_Y100.mat'), 'Y_100');
second = load(fullfile(weights, 'env28_Y011.mat'), 'Y_011');
output = load(fullfile(weights, 'env28_Z.mat'), 'Z');
model.Y.Y_100 = first.Y_100;
model.Y.Y_011 = second.Y_011;
model.Z = output.Z;
end
