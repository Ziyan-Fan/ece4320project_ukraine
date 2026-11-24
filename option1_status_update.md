# ECE 4320 Project Status Update

November 23, 2026 · Option 1, Best Defense Locations

## Project goal

I’m testing where to place defenses on the course’s 41-line synthetic grid to minimize expected load shedding, measured as a percentage of total demand. In the simulator, `num_attack` is the maximum number of distinct lines the attacker can target in one round. Each line can be targeted once. The defense budget is `4 × num_attack`, and multiple defense units can protect the same line.

## Progress and results

The course data contain precomputed AC optimal power flow (AC OPF) results from MATPOWER. For each set of failed lines, AC OPF redispatches generation and estimates how much demand must be shed to stay within operating limits. The simulator calculates expected load shedding by weighting each outcome by its probability. A defense plan’s score is the highest expected load shedding the simulator finds across the target sets it evaluates.

The table reports expected load shedding as a percentage of total demand.

| `num_attack` | Defense units available | No defenses | Best plan tested |
| ---: | ---: | ---: | ---: |
| 1 | 4 | 5.06% | 3.26% |
| 2 | 8 | 15.30% | 6.87% |
| 3 | 12 | 25.77% | 9.37% |
| 4 | 16 | 28.82% | 10.60% |
| 5 | 20 | 32.71% | 12.01% |
| 6 | 24 | 35.74% | Baseline only |

Plans based on multi-line outages matched or beat the other methods tested in every placement comparison. With four allowed targets, moving one defense unit improved the best initial plan from 11.49% to 10.60%.

## Challenges and next steps

Larger attack budgets take longer to simulate because there are more possible outage combinations. For six targets, I ran the no-defense case to establish a baseline. To keep the placement search manageable, I used a shortlist of severe outages with valid AC OPF solutions to propose plans, then scored those plans with the course simulator. The simulator assigns zero load shedding to outages where the solver failed to converge, which can make expected load shedding too low. Before December 8, I’ll verify the reported placements and explain how the limited search and solver failures affect the conclusions.
