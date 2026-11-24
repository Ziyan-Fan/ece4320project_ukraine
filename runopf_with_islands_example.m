% Run an AC optimal power flow with two line failures

define_constants;
mpc = ukraine;
mpopts = mpoption;

mpc.branch([3 4],BR_STATUS) = 0;

[sol]=runopf_with_islands(mpc,mpopts);
