function results = study_defense_placements(attackBudgets)
% Compare defensive allocations on the supplied synthetic course case.
% By default, evaluate one through five allowed line outages. Pass a vector
% of budgets from 1 through 6 to select other cases. Budget six can be slow.
if nargin == 0
    attackBudgets = 1:5;
end
validateattributes(attackBudgets, {'numeric'}, ...
    {'vector', 'nonempty', 'integer', '>=', 1, '<=', 6});

projectDir = fileparts(mfilename('fullpath'));
originalDir = pwd;
originalPath = path;
restoreDir = onCleanup(@() cd(originalDir));
restorePath = onCleanup(@() path(originalPath));
cd(projectDir);
addpath(genpath(fullfile(projectDir, 'matpower7.1')));

data = load('contingency_data6.mat', 'samples', 'loadshed', 'success');
outageCount = sum(data.samples, 1).';
lineCount = size(data.samples, 1);
opts = setParameters;
residual = 1 - opts.defend;
scenariosPerSize = 500;
maxBudget = max(attackBudgets);
scenarioIndices = cell(maxBudget, 1);
for k = 1:maxBudget
    valid = find(outageCount == k & data.success & data.loadshed > 0);
    [~, rank] = maxk(data.loadshed(valid), min(scenariosPerSize, numel(valid)));
    scenarioIndices{k} = valid(rank);
end

methodNames = {'Single-outage severity', 'Random spread', ...
    'Contingency tail p=2', 'Contingency tail p=8', 'Contingency tail p=24'};
stream = RandStream('mt19937ar', 'Seed', 4320);
results = struct([]);
for budgetIndex = 1:numel(attackBudgets)
    k = attackBudgets(budgetIndex);
    defenseBudget = 4 * k;
    eligible = vertcat(scenarioIndices{1:k});
    incidence = double(data.samples(:, eligible).');
    risk = data.loadshed(eligible) .* (1 - opts.miss).^outageCount(eligible);
    singles = outageCount(eligible) == 1;

    plans = zeros(lineCount, numel(methodNames));
    plans(:, 1) = greedyPlacement(incidence(singles, :), risk(singles), ...
        residual, defenseBudget, 1);
    plans(randperm(stream, lineCount, defenseBudget), 2) = 1;
    tailPowers = [2, 8, 24];
    for i = 1:numel(tailPowers)
        plans(:, i + 2) = greedyPlacement(incidence, risk, residual, ...
            defenseBudget, tailPowers(i));
    end
    assert(all(sum(plans, 1) == defenseBudget));

    fprintf('\nAllowed outages %d, defense budget %d\n', k, defenseBudget);
    noDefense = simulate_attack(zeros(lineCount, 1), k, false);
    fprintf('  %-25s %9.5f%%\n', 'No defense', 100 * noDefense);
    scores = zeros(1, size(plans, 2));
    for i = 1:numel(scores)
        scores(i) = simulate_attack(plans(:, i), k, false);
        fprintf('  %-25s %9.5f%%\n', methodNames{i}, 100 * scores(i));
    end

    [initialScore, initialWinner] = min(scores);
    initialPlan = plans(:, initialWinner);
    neighbors = sampledMoves(initialPlan, stream);
    neighborScores = zeros(1, size(neighbors, 2));
    for i = 1:numel(neighborScores)
        neighborScores(i) = simulate_attack(neighbors(:, i), k, false);
        fprintf('  One-unit move %d of %d      %9.5f%%\n', ...
            i, numel(neighborScores), 100 * neighborScores(i));
    end
    [bestScore, winner] = min([initialScore, neighborScores]);
    finalists = [initialPlan, neighbors];
    bestPlan = finalists(:, winner);
    assert(sum(bestPlan) == defenseBudget && all(bestPlan >= 0));
    [verifiedScore, ~, outcomes] = simulate_attack(bestPlan, k, false);
    assert(abs(verifiedScore - bestScore) < 1e-12);
    assert(abs(sum(outcomes.probability) - 1) < 1e-12);
    assert(abs(outcomes.probability.' * outcomes.loadshed - bestScore) < 1e-12);

    alternatives = [scores, neighborScores];
    testedPlans = [plans, neighbors];
    distinctAlternatives = any(testedPlans ~= bestPlan, 1);
    nearestScore = min(alternatives(distinctAlternatives));
    fprintf('  %-25s %9.5f%%\n', 'Selected placement', 100 * bestScore);
    fprintf('  %-25s %9.5f pp\n', 'Gap to next placement', ...
        100 * (nearestScore - bestScore));
    defended = find(bestPlan);
    fprintf('  Synthetic branch row x units:');
    fprintf(' %dx%d', [defended.'; bestPlan(defended).']);
    fprintf('\n');

    results(budgetIndex).allowedOutages = k;
    results(budgetIndex).defenseBudget = defenseBudget;
    results(budgetIndex).noDefenseLoadShed = noDefense;
    results(budgetIndex).methods = methodNames;
    results(budgetIndex).candidatePlans = plans;
    results(budgetIndex).candidateLoadShed = scores;
    results(budgetIndex).initialMethod = methodNames{initialWinner};
    results(budgetIndex).neighborPlans = neighbors;
    results(budgetIndex).neighborLoadShed = neighborScores;
    results(budgetIndex).selectedPlan = bestPlan;
    results(budgetIndex).selectedLoadShed = bestScore;
    results(budgetIndex).nextBestLoadShed = nearestScore;
end
end

function placement = greedyPlacement(incidence, risk, residual, budget, power)
% Adding a defense reduces the joint failure probability in each scenario
% containing that branch. Choose the largest reduction in pooled tail risk.
weights = (risk / max(risk)).^power;
placement = zeros(size(incidence, 2), 1);
for i = 1:budget
    [~, line] = max(incidence.' * weights);
    placement(line) = placement(line) + 1;
    weights(logical(incidence(:, line))) = ...
        weights(logical(incidence(:, line))) * residual^power;
end
end

function neighbors = sampledMoves(placement, stream)
% Draw six distinct one-unit transfers from the best initial placement.
lineCount = numel(placement);
[sources, destinations] = ndgrid(find(placement), 1:lineCount);
valid = sources ~= destinations;
sources = sources(valid);
destinations = destinations(valid);
choices = randperm(stream, numel(sources), min(6, numel(sources)));
neighbors = repmat(placement, 1, numel(choices));
for i = 1:numel(choices)
    from = sources(choices(i));
    to = destinations(choices(i));
    neighbors(from, i) = neighbors(from, i) - 1;
    neighbors(to, i) = neighbors(to, i) + 1;
end
end
