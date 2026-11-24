% Specify the defense locations
defense_locations = zeros(41,1);
defense_locations([11 30]) = 2;
defense_locations([28]) = 1;

num_attack = 4; % Number of lines the attacker can target
outcomeIndex = 16; % The outcome to display (successful attack on all lines)

[expected_load_shed, targeted_lines, outcomes] = simulate_attack(defense_locations,num_attack);
displayOutcome(defense_locations,outcomes,outcomeIndex)