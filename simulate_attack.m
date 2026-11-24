function [expected_load_shed, targeted_lines, outcomes] = simulate_attack(defense_locations,num_attack,verbose)
% Determine the attacker's action given the defended lines and the number
% of lines that the attacker can attempt to destroy.
% 
% Inputs: 
%   defense_locations: A vector with length equal to the number of lines. 
%       The entries of defense_locations indicate how many defensive 
%       resources are allocated to defending the line at the corresponding
%       row of the branch data in the Ukrainian test case.
%
%   num_attack: A scalar indicating the number of lines that the attacker
%       can attempt to destroy.
%
%   verbose (optional): If true (the default), print progress and timing
%       information to the command window. Set to false to suppress these
%       messages, e.g., when running many simulations.
%
% Outputs:
%   expected_load_shed: A scalar indicating the expected load shed from the
%       attack, given the input defense_locations and number of attacked
%       lines (num_attack). This value is given as a fraction of the total
%       load in the system.
%
%   targeted_lines: A vector indicating the lines that the attacker
%       targets for attack.
%
%   outcomes: A structure describing the probability and load shedding
%       corresponding to each outcome that might occur from the targeted
%       attack. This structure has three fields:
%         outcomes.failures: A cell array of the possible line failures
%           (successful attacks) that could occur from the attack on the
%           targeted lines. The values in the cell array correspond to line
%           indices (rows in the branch data of the Ukrainian test case).
%
%         outcomes.probability: The likelihood that the corresponding
%           failures in outcomes.failures will occur, given the
%           defense_locations input.
%
%         outcomes.loadshed: The load shed resulting from each possible
%           combination of line failures in outcomes.failures.
%
%       The outcomes are ordered as binary counting over the targeted
%       lines: outcome 1 has no failures, outcome 2 is the failure of only
%       the last targeted line, ..., and the last outcome is the failure of
%       every targeted line.

%% Load data

tic;

if nargin < 3
    verbose = true;
end

define_constants;
mpc = ukraine;

% Precomputed load shedding from each combination of N-k failures.
% Currently, k=6 is the maximum precomputed value. This data file is large,
% so load it only once and keep it in memory for subsequent calls.
persistent contingencyData
if isempty(contingencyData)
    contingencyData = load('contingency_data6.mat','samples','loadshed','success');
end
samples = contingencyData.samples;
loadshed = contingencyData.loadshed;
success = contingencyData.success;

% Load options
opts = setParameters;

% Number of branches
nbranch = size(mpc.branch,1);

%% Input validation
defense_locations = defense_locations(:);
if length(defense_locations) ~= nbranch
    error('The input "defense_locations" must have length equal to the number of branches.');
end

if any(defense_locations < 0) || any(defense_locations ~= round(defense_locations))
    error('The entries of "defense_locations" must be non-negative integers.');
end

if num_attack ~= round(num_attack) || num_attack <= 0 || num_attack > 6
    error('Invalid num_attack value.');
end

%% Compute the probability that each line fails if targeted for attack
% Assumes independence among the probability of the attack missing and the 
% probabilities of each defender interdicting an attack.
attack_success_probability = prod([(1-opts.miss)*ones(nbranch,1) (1-opts.defend).^defense_locations],2);

%% Compute expected load shedding from each attack
% We have precomputed and loaded the following variables:
% samples: a matrix describing a list of N-k contingency scenarios
% loadshed: a vector with the amount of load shedding for each contingency scenario
% success: a vector indicating whether the solver converged for each contingency scenario

% Handle contingency scenarios for which the solver failed to converge.
% We don't actually know what would happen in these cases (perhaps we just
% had a bad initialization), so we set the corresponding load shedding to
% zero, decreasing the incentives for the attacker to target these lines.
loadshed(~success) = 0;

% Screen out contingencies with more attacked lines than the attacker is
% allowed to target.
loadshed(sum(samples,1) > num_attack) = [];
samples(:,sum(samples,1) > num_attack) = [];

% Create a lookup vector to quickly find the contingency scenario
% corresponding to a given set of failures. Each set of failures maps to a
% unique integer key (a binary number with bit j set if line j fails), which
% is exactly representable as a double for up to 53 lines.
lookupVec = 2.^(0:nbranch-1).';
sLookup = full(double(samples).'*lookupVec);

for i=1:num_attack
    tempSamplesIdx = sum(samples,1) == i;
    sLookup_by_num_attack{i} = sLookup(tempSamplesIdx);
    I_by_num_attack{i} = find(tempSamplesIdx);
end

% Loop through the contingency scenarios to compute the expected load shed
% for each given the probability of successful attack.
% To speed up this calculation, we skip contingency scenarios whose load
% shed (if every targeted line fails) is no larger than the worst expected
% load shed found so far. This is exact if the load shed never decreases
% when additional lines fail. Since the AC OPF solutions are computed with a
% local solver (and non-converged scenarios are set to zero load shed
% above), this property may not always hold, so the attacker is
% near-optimal rather than guaranteed to find the worst-case attack.
expected_load_shed = zeros(size(samples,2),1);
worst_expected_load_shed = 0;

% Default outputs if no attack causes any expected load shedding
worst_targeted_lines = zeros(0,1);
outcomes.failures = {zeros(0,1)};
outcomes.probability = 1;
outcomes.loadshed = 0;
for i=1:size(samples,2)
    if loadshed(i) > worst_expected_load_shed
        targeted_lines = find(samples(:,i));

        % Assess all possible outcomes from the targeted lines.
        possible_outcomes = dec2bin(0:2^length(targeted_lines)-1)-'0';
        possible_outcomes_probability = zeros(size(possible_outcomes,1),1);
        possible_outcomes_loadshed = zeros(size(possible_outcomes,1),1);
        clear outcomes_temp
        for k=1:size(possible_outcomes,1)
            % Compute the probability of this outcome occurring, given the
            % selected attack and defense
            possible_outcomes_probability(k) ...
                = prod(attack_success_probability(targeted_lines(logical(possible_outcomes(k,:).')))) ...
                 *prod((1-attack_success_probability(targeted_lines(~logical(possible_outcomes(k,:).')))));
            
            outcomes_temp{k} = targeted_lines(logical(possible_outcomes(k,:).'));

            lookupVal = sum(lookupVec(targeted_lines(logical(possible_outcomes(k,:)))));
            if lookupVal ~= 0 % At least one line was successfully attacked, otherwise no load shedding in the base case
                % Find the load shed corresponding to this outcome via the
                % lookup keys for scenarios with the same number of failures
                num_attack_k = sum(possible_outcomes(k,:));
                lookupIdx = I_by_num_attack{num_attack_k}(find(sLookup_by_num_attack{num_attack_k} == lookupVal,1));

                if ~isempty(lookupIdx)
                    possible_outcomes_loadshed(k) = loadshed(lookupIdx);
                else 
                    possible_outcomes_loadshed(k) = nan;
                    warning('Could not find some scenario in the list.')
                end
            end
        end
        expected_load_shed(i) = possible_outcomes_probability.' * possible_outcomes_loadshed;
        if expected_load_shed(i) > worst_expected_load_shed
            worst_expected_load_shed = expected_load_shed(i);
            worst_targeted_lines = targeted_lines;
            outcomes.failures = outcomes_temp;
            outcomes.probability = possible_outcomes_probability;
            outcomes.loadshed = possible_outcomes_loadshed;
        end
    end
    % Display updates
    if verbose && mod(i,1e4) == 0
        fprintf('Searching for worst-case attack: %i of %i.\n',i,size(samples,2));
    end
end

%% Prepare outputs
expected_load_shed = worst_expected_load_shed;
targeted_lines = worst_targeted_lines;

et = toc;
if verbose
    fprintf('Time searching for worst-case attack: %.1f sec.\n',et);
end