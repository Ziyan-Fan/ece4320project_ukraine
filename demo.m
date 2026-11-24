% Demo
clear
clc
close all

% If needed, add files within this folder and subfolders to the Matlab path
if isempty(which('define_constants')) || isempty(which('ukraine'))
    addpath(genpath(pwd));
end

mpc = ukraine; % Load test case data
nbranch = size(mpc.branch,1); % Number of lines

% Specify defense locations
defense_locations = zeros(nbranch,1);
defense_locations([]) = 1;
defense_locations([]) = 2;
defense_locations([]) = 3;

% Simulate attack
num_attack = 4;
[expected_load_shed, targeted_lines, outcomes] = simulate_attack(defense_locations,num_attack);

% Indicate the outcome to show on the plot. The last outcome is the one
% where all attacks are successful. (This equals 2^num_attack if the
% attacker targets the maximum number of lines.)
outcomeIndex = length(outcomes.failures); 

% Plot this outcome
displayOutcome(defense_locations,outcomes,outcomeIndex)