# Defense Allocation in a Synthetic Model of Ukraine’s Transmission Grid

ECE 4320 · Fall 2026 · Option 1 · Draft

## Executive Summary

This study compares ways to allocate a limited number of defense units in a 41-branch synthetic transmission grid. Candidate placements that account for severe multi-line outages consistently outperformed placements based only on single-line outage severity when the simulated attacker could target multiple lines. With five allowed targets and 20 defenses, the best tested placement reduced expected load shedding from 32.71% to 12.01%, a reduction of 20.70 percentage points. Several distinct allocations gave nearly the same result, so the simulations support a set of plausible allocations for this test case.

## Ukraine’s Energy Crisis

Electricity outages during wartime disrupt services that households depend on, including heat, water, and transportation. In November 2026, repeated Russian attacks damaged the electricity network serving Odesa. Local authorities moved schools to remote instruction, and the city temporarily suspended electric public transit. The International Energy Agency’s 2026 pre-winter assessment describes how distributed generation, battery storage, and power imports can help sustain service. The assessment also highlights that network bottlenecks can keep available electricity from reaching areas where it is needed. These experiences motivate studying how network outages affect the ability to deliver power. [1, 2]

## Simulation Model

The course case contains 32 buses, 10 generators, and 41 branches. It reflects some broad characteristics of Ukraine’s power system using a synthetic network designed for research and education. The simulation represents demand at a single point in time. After each modeled set of line failures, the operator redispatches generation using AC optimal power flow. The solver can shed demand when needed to respect system constraints. [3, 4]

For an attack budget of $k$ lines, the defense budget is $4k$ units. Each unit is assigned to one branch, and a branch can receive multiple units. The supplied miss probability is 0.20 and each defense unit independently intercepts an attempt with probability 0.33. An attempt on a branch with $d$ units therefore produces an outage with probability $0.80(0.67)^d$. The simulator evaluates the scenario after observing the placement and returns the expected fraction of total demand shed for its highest-scoring simulated attack. The study keeps all supplied simulation parameters fixed. [4]

## Placement Method

The comparison includes a no-defense baseline, a random spread with distinct branches, and a single-outage severity heuristic. The single-outage heuristic places each additional defense on the branch with the greatest remaining expected shed after its existing defenses. The multibranch heuristic begins with up to 500 of the highest-shed converged contingencies at each outage size through $k$. It weights each contingency’s unmitigated shed by the probability that all branches in that contingency fail. The score of a placement is the sum of these weighted terms raised to a power $p$.

Each additional defense multiplies the affected contingency’s term by 0.67 before exponentiation. The greedy method places the next unit on the branch that produces the largest current reduction in the score. Higher powers give the most severe remaining joint failures more influence. The test uses $p=2,8,24$ to compare the effects of this emphasis. This score guides placement and accounts for complete failures of the selected contingencies. The course simulator provides the reported expected values by including partial failure outcomes for each simulated attack it evaluates.

For each budget, the supplied simulator scores the five initial defense plans. The study samples six distinct transfers of one unit in the best initial plan and scores those plans with the same simulator. The selected plan is the lowest-scoring plan tested. A fixed random seed makes the random spread and transfers reproducible for the same budget sequence. The code checks that the selected plan uses the full allowable budget, that the simulated outcome probabilities sum to one, and that their probability-weighted load shed equals the reported score. The placement comparisons cover one through five allowed targets. The six-target case received a no-defense timing run, which took about 35 seconds for one evaluation.

## Results and Placement Sensitivity

Expected load shedding is expressed as a percentage of total demand. The improvement column measures the difference from the no-defense baseline in percentage points.

| Allowed targets | Defense units | No defense | Single-outage heuristic | Random spread | Best initial multibranch plan | Selected placement | Improvement |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 4 | 5.06% | 3.26% | 5.06% | 3.26% | 3.26% | 1.80 |
| 2 | 8 | 15.30% | 15.30% | 15.30% | 6.94% | 6.87% | 8.43 |
| 3 | 12 | 25.77% | 21.35% | 19.29% | 9.37% | 9.37% | 16.40 |
| 4 | 16 | 28.82% | 24.19% | 19.16% | 11.49% | 10.60% | 18.21 |
| 5 | 20 | 32.71% | 26.54% | 25.88% | 12.01% | 12.01% | 20.70 |

The placements below use row numbers from `mpc.branch` in the synthetic MATLAB case. An entry such as `13 × 2` assigns two units to row 13. Each unlisted row receives zero units.

| Allowed targets | Selected branch rows and units | Gap to next distinct tested plan, percentage points |
| ---: | --- | ---: |
| 1 | 4 × 1, 13 × 2, 29 × 1 | 0.129 |
| 2 | 11 × 2, 12 × 1, 13 × 1, 26 × 1, 28 × 2, 29 × 1 | 0.071 |
| 3 | 2 × 2, 4 × 1, 11 × 2, 12 × 2, 13 × 1, 21 × 1, 26 × 1, 28 × 2 | 0.000 |
| 4 | 2 × 3, 3 × 1, 4 × 1, 11 × 2, 12 × 2, 13 × 1, 21 × 1, 25 × 1, 28 × 2, 29 × 1, 33 × 1 | 0.095 |
| 5 | 2 × 2, 3 × 1, 4 × 1, 11 × 3, 12 × 3, 13 × 1, 21 × 2, 25 × 1, 26 × 1, 28 × 3, 29 × 1, 33 × 1 | 0.000 |

At one allowed target, the single-outage rule already achieves the best tested score. With one target, the model’s score is the maximum across individual branches. Assigning the next unit to a branch below that maximum leaves the score unchanged. When several branches share the maximum, each needs an additional unit before the score can fall. This structure explains why the single-outage rule works in this case.

With two allowed targets, the single-outage heuristic achieved the same expected load shedding as the no-defense case. The multibranch approach with $p=8$ cut the score to 6.94% before the one-unit transfers, compared with 10.25% for $p=2$. At four targets, a transfer improved the initial 11.49% result to 10.60%, while another transfer raised it to 12.55%. At five targets, one transfer matched the initial 12.01% and others raised it to as much as 14.56%. An allocation procedure for another synthetic case should screen for severe multi-line outages and retest small changes with the supplied simulator.

## Limitations

The comparison uses a single snapshot of demand and assumes independent outcomes with a constant intercept probability. It covers transmission-line failures and omits repair times, sequential attacks, and constraints on how quickly generators can redispatch. Expected load shedding measures aggregate unmet demand and gives equal weight to each megawatt, so it cannot distinguish which communities or essential services lose power. The defense placements are branch indices in the course network. [3, 4]

The course simulator uses a local AC solver. It assigns zero load shed to the 229,489 contingency records where the solver failed to converge, about 4.3% of the supplied dataset through six outages. It may also prune possible attacks using the shed from the all-fail outcome. Both choices can understate the simulated worst-case expected loss. The defense search screens a subset of contingencies for placement, uses a single random-spread baseline per budget, and checks six nearby moves. Its results establish the best plan among the plans evaluated. [4]

## Conclusion

The synthetic case shows the value of considering combined line outages when allocating a limited number of defenses. The largest improvement observed relative to no defense came from identifying branches that contribute to severe multi-line contingencies and then checking nearby allocations against the complete simulation score. Reporting near-ties alongside the selected placements gives a more accurate picture of how much the model depends on the exact allocation.

## Reproduction

Open MATLAB in the project folder and run `results = study_defense_placements;`. The function prints the defense counts and load-shedding scores and returns the selected and comparison plans. For a shorter run, use `study_defense_placements(1:4)`. The reported runs used MATLAB R2025a and the bundled MATPOWER 7.1 files.

## References

1. A. Terajima, [Russian attacks cause ‘serious damage’ to Odesa power grid as outages disrupt city](https://kyivindependent.com/russian-attacks-cause-serious-damage-to-odesa-power-grid-as-outages-disrupt-city/), *The Kyiv Independent*, Nov. 22, 2026.
2. International Energy Agency, [Ukraine’s Energy Security 2026](https://www.iea.org/reports/ukraine-s-energy-security-2026/key-findings), 2026.
3. R. Harris, A. Banerjee, and D. K. Molzahn, [Synthetic Test Case for Ukraine’s Power Grid](https://molzahn.github.io/pubs/harris_banerjee_molzahn-ukraine.pdf), *55th North American Power Symposium*, 2023.
4. D. Molzahn, [ECE 4320 Fall 2026 Course Project — Defend Ukraine](ECE%204320%20Ukraine%20Project.pdf), Georgia Tech, 2026.
