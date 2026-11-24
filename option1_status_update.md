# ECE 4320 Project Status Update

November 23, 2026 · Option 1, Best Defense Locations

## Project goal

I’m testing where to place defenses on the course’s 41-line synthetic grid to reduce the share of electricity demand that goes unserved. In each case, the simulated attacker can make one attempt per line. The defender gets four units for each line the attacker is allowed to target and can put several units on the same line.

## Progress and results

MATPOWER estimates how much demand the grid can serve after different lines go out. The MATLAB study uses those precomputed estimates and the likelihood of each outage to score each defense plan.

I compared defense plans for cases with one to five allowed targets. Plans that accounted for several lines failing together scored as well as or better than the other methods tested. With five allowed targets, expected unserved demand dropped from **32.71% without defenses** to **12.01% with the best 20-unit plan tested**. With four allowed targets, moving one defense unit from one line to another improved the best initial plan from **11.49% to 10.60%**.

## Challenges and next steps

Larger cases take longer to run, so for six targets I measured expected unserved demand with no defenses. MATPOWER also failed to find a solution for some outage combinations. To keep the search manageable, I used a subset of severe outages with valid solutions to propose plans, then scored those plans with the course simulator. Before December 8, I’ll review the comparisons and explain how these limits affect the conclusions.
