function [opts] = setParameters

%% Options related to attack and defense probabilities
opts.miss = 0.2; % Probability that an attack targeted at a particular line misses
opts.defend = 0.33; % Probability that each defender allocated to a line successfully prevents an attack