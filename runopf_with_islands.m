function [sol]=runopf_with_islands(mpc,mpopts)
% This function solves an AC OPF problem for the system described in
% the Matpower case input mpc. In contrast to Matpower's runopf function,
% here we allow the Matpower case to have multiple islands. We also allow
% load shedding by modeling all loads as dispatchable.
%
% The output sol.bus(:,PD) and sol.bus(:,QD) contain the load demands that
% are actually supplied, and sol.loadshed contains the total active power
% load shedding (in MW).

% Assume at most one generator per bus.
% Assume that the bus numbers are consecutive integers starting from 1.

tic;
wrn = warning;
warning off

define_constants;

Ptol = 0.1; % MW

if nargin < 2
    mpopts = mpoption;
end

mpopts.out.all = 0;
mpopts.verbose = 0;

% Try MIPS (included with Matpower) first. If MIPS fails and the
% Optimization Toolbox is installed, then also try fmincon.
acopf_solvers = {'MIPS'};
if have_feature('fmincon')
    acopf_solvers{end+1} = 'FMINCON';
end

Pd_total = sum(mpc.bus(:,PD)); % Total load demand before any load shedding

%% Handle systems with multiple connected components (islands)

% Identify islands with multiple buses
mpc_islands = extract_islands(mpc);

% Include islands with a single (isolated) bus
[~,isolatedBuses] = find_islands(mpc); % Find isolated buses
for i=1:length(isolatedBuses)
    mpc_isolated = mpc;
    genLookup = find(mpc.gen(:,GEN_BUS) == isolatedBuses(i));
    
    mpc_isolated.bus = mpc.bus(isolatedBuses(i),:);
    mpc_isolated.gen = mpc.gen(genLookup,:);
    mpc_isolated.branch = zeros(0,size(mpc.branch,2));
    mpc_isolated.gencost = mpc.gencost(genLookup,:);
    
    mpc_islands{length(mpc_islands)+1} = mpc_isolated;
end


%% Solve AC OPF for each island

success = true;
et = 0;
for i=1:length(mpc_islands)
    
    mpc_i = mpc_islands{i};
    
    % Solve the AC OPF problem for this island
    load_in_island = sum(mpc_i.bus(:,PD));
    generation_in_island = sum(mpc_i.gen(mpc_i.gen(:,PMAX) > 0,PMAX));
    
    % Convert dispatchable loads to generator model
    ngen = size(mpc_i.gen,1);
    mpc_i = load2disp(mpc_i);
    
    % Set the reference angle in this island
    if ~any(mpc_i.bus(:,BUS_TYPE) == REF)
        mpc_i.bus(1,BUS_TYPE) = REF;
        mpc_i.bus(:,VA) = 0;
    end

    if generation_in_island <= Ptol || load_in_island <= Ptol
        % Either no generation or no load in this island, so just shed all load
        mpc_i.bus(:,VM) = 1;
        mpc_i.bus(:,VA) = 0;
        mpc_i.bus(:,PD) = 0;
        mpc_i.gen(:,PG) = 0;
        mpc_i.bus(:,QD) = 0;
        mpc_i.gen(:,QG) = 0;
        mpc_i.gen(:,VG) = 1;
        mpc_i.branch(:,PF) = 0;
        mpc_i.branch(:,PT) = 0;
        mpc_i.branch(:,QF) = 0;
        mpc_i.branch(:,QT) = 0;
        mpc_i.success = true;
        mpc_i.bus(:,LAM_P) = 0;
        mpc_i.bus(:,LAM_Q) = 0;
        mpc_i.bus(:,MU_VMAX) = 0;
        mpc_i.bus(:,MU_VMIN) = 0;
        mpc_i.gen(:,MU_PMAX) = 0;
        mpc_i.gen(:,MU_PMIN) = 0;
        mpc_i.gen(:,MU_QMAX) = 0;
        mpc_i.gen(:,MU_QMIN) = 0;
        mpc_i.branch(:,MU_SF) = 0;
        mpc_i.branch(:,MU_ST) = 0;
        mpc_i.et = 0;
    else
        for solverIndex = 1:length(acopf_solvers)
            mpopts.opf.ac.solver = acopf_solvers{solverIndex};
            mpc_i = runopf(mpc_i,mpopts);
            if mpc_i.success == 1
                break;
            end
        end
    end
    
    % Match generator outputs, bus voltages, load demands, line flows,
    % success flag, computation time.
    if ~mpc_i.success
        success = false;
        mpc_i.bus(:,VM) = 1;
        mpc_i.bus(:,VA) = 0;
        mpc_i.bus(:,PD) = 0;
        mpc_i.gen(:,PG) = 0;
        mpc_i.bus(:,QD) = 0;
        mpc_i.gen(:,QG) = 0;
        mpc_i.gen(:,VG) = 1;
        mpc_i.branch(:,PF) = 0;
        mpc_i.branch(:,PT) = 0;
        mpc_i.branch(:,QF) = 0;
        mpc_i.branch(:,QT) = 0;
        mpc_i.bus(:,LAM_P) = 0;
        mpc_i.bus(:,LAM_Q) = 0;
        mpc_i.bus(:,MU_VMAX) = 0;
        mpc_i.bus(:,MU_VMIN) = 0;
        mpc_i.gen(:,MU_PMAX) = 0;
        mpc_i.gen(:,MU_PMIN) = 0;
        mpc_i.gen(:,MU_QMAX) = 0;
        mpc_i.gen(:,MU_QMIN) = 0;
        mpc_i.branch(:,MU_SF) = 0;
        mpc_i.branch(:,MU_ST) = 0;
    end
    et = et + mpc_i.et;
    
    % Convert dispatchable loads models as generators back to loads
%     mpc_i.bus(mpc_i.gen(ngen+1:end,GEN_BUS),PD) = -mpc_i.gen(ngen+1:end,PG);
    
    busInIsland = ismember(mpc.bus(:,BUS_I),mpc_i.bus(:,BUS_I));
    mpc.bus(busInIsland,VM) = mpc_i.bus(:,VM);
    mpc.bus(busInIsland,VA) = mpc_i.bus(:,VA);
%     mpc.bus(busInIsland,PD) = mpc_i.bus(:,PD);
%     mpc.bus(busInIsland,QD) = mpc_i.bus(:,QD);
    
    mpc.bus(busInIsland,LAM_P) = mpc_i.bus(:,LAM_P);
    mpc.bus(busInIsland,LAM_Q) = mpc_i.bus(:,LAM_Q);
    mpc.bus(busInIsland,MU_VMAX) = mpc_i.bus(:,MU_VMAX);
    mpc.bus(busInIsland,MU_VMIN) = mpc_i.bus(:,MU_VMIN);

    mpc.bus(mpc_i.gen(ngen+1:end,GEN_BUS),PD) = -mpc_i.gen(ngen+1:end,PG);
    mpc.bus(mpc_i.gen(ngen+1:end,GEN_BUS),QD) = -mpc_i.gen(ngen+1:end,QG);
    
    genInIsland = ismember(mpc.gen(:,GEN_BUS),mpc_i.gen(:,GEN_BUS));
    mpc.gen(genInIsland,PG) = mpc_i.gen(1:ngen,PG);
    mpc.gen(genInIsland,QG) = mpc_i.gen(1:ngen,QG);
    mpc.gen(genInIsland,VG) = mpc_i.gen(1:ngen,VG);

    mpc.gen(genInIsland,MU_PMAX) = mpc_i.gen(1:ngen,MU_PMAX);
    mpc.gen(genInIsland,MU_PMIN) = mpc_i.gen(1:ngen,MU_PMIN);
    mpc.gen(genInIsland,MU_QMAX) = mpc_i.gen(1:ngen,MU_QMAX);
    mpc.gen(genInIsland,MU_QMIN) = mpc_i.gen(1:ngen,MU_QMIN);
    
    branchInIsland = ismember(mpc.branch(:,[F_BUS T_BUS]),mpc_i.branch(:,[F_BUS T_BUS]),'rows');
    mpc.branch(branchInIsland,PF) = mpc_i.branch(:,PF);
    mpc.branch(branchInIsland,PT) = mpc_i.branch(:,PT);
    mpc.branch(branchInIsland,QF) = mpc_i.branch(:,QF);
    mpc.branch(branchInIsland,QT) = mpc_i.branch(:,QT);

    mpc.branch(branchInIsland,MU_SF) = mpc_i.branch(:,MU_SF);
    mpc.branch(branchInIsland,MU_ST) = mpc_i.branch(:,MU_ST);
end

% Compute cost
c2 = mpc.gencost(:,COST);
c1 = mpc.gencost(:,COST+1);
c0 = mpc.gencost(:,COST+2);
status = mpc.gen(:,PG) > Ptol;
cost = sum(c2.*mpc.gen(:,PG).^2 + c1.*mpc.gen(:,PG)) + sum(c0.*status);

mpc.success = success;
mpc.f = cost;
mpc.et = toc;
mpc.loadshed = Pd_total - sum(mpc.bus(:,PD)); % Total load shedding (MW)

sol = mpc;

warning(wrn);

end