function displayOutcome(defense_locations,outcomes,outcomeIndex)
% Plot the defense and attack results on a geographic display.

define_constants;

just_percent_line_loading = true; % Option to set whether the display only shows the percentage of the line loading or also shows the MVA flow.

mpc = ukraine;
nbranch = size(mpc.branch,1);

%% Input validation
defense_locations = defense_locations(:);
if length(defense_locations) ~= nbranch
    error('The input "defense_locations" must have length equal to the number of branches.');
end

if outcomeIndex <= 0 || outcomeIndex > length(outcomes.failures) || round(outcomeIndex) ~= outcomeIndex
    error('Invalid input "outcomeIndex": must be an integer from 1 to %i.',length(outcomes.failures))
end

wrn = warning;
warning off

%% Load data
define_constants;

% Geographic data
mpc.bus_geo = readmatrix('ukraine_coordinates.csv');

% Solver options
mpopts = mpoption;

targeted_lines = outcomes.failures{end};
attacked_lines = outcomes.failures{outcomeIndex};

%% Solve the OPF problem for the specified failure scenario
mpc0 = mpc;
mpc.branch(attacked_lines,BR_STATUS) = 0;
tic;
mpc = runopf_with_islands(mpc,mpopts);
mpc.et = toc;
warning(wrn);

if mpc.success
    printpf(mpc);
else
    warning('Matpower OPF solver failed to converge for this outcome.');
    mpc = mpc0;
end

%% Show background image of Ukraine
h = figure;
mapaxes_handle = bordersm('ukraine','k','facecolor','green','FaceAlpha',0.1);
framem off; gridm off; mlabel off; plabel off;
hold on;

%% Plot bus locations
plotm(mpc.bus_geo(:,2),mpc.bus_geo(:,1),'k.','MarkerSize',25);

%% Plot all non-targeted lines
latlon = nan(3*size(mpc.branch,1),2);
count = 1;
for i=1:size(mpc.branch,1)
    if mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) || mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1)
        if ~any(targeted_lines == i)
            latlon(count:count+2,1:2) = [mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1); ...
                                         mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1); ...
                                         nan(1,2)];
        end
    end
    count = count + 3;
end
plotm(latlon,'k-');

%% Plot all targeted but not successfully attacked lines
latlon = nan(3*size(mpc.branch,1),2);
count = 1;
for i=1:size(mpc.branch,1)
    if mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) || mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1)
        if any(targeted_lines == i) && ~any(attacked_lines == i)
            latlon(count:count+2,1:2) = [mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1); ...
                                         mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1); ...
                                         nan(1,2)];
        end
    end
    count = count + 3;
end
plotm(latlon,'r-','linewidth',3);


%% Plot all targeted and successfully attacked lines
latlon = nan(3*size(mpc.branch,1),2);
count = 1;
for i=1:size(mpc.branch,1)
    if mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) || mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1)
        if any(targeted_lines == i) && any(attacked_lines == i)
            latlon(count:count+2,1:2) = [mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1); ...
                                         mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1); ...
                                         nan(1,2)];
        end
    end
    count = count + 3;
end
plotm(latlon,'r:','linewidth',3);

%% Plot all defended lines

% Control the spacing of the defense markers along each line and their
% offset from the line (in degrees)
defense_spacing = 0.18;
defense_offset = 0.08;

for i=1:size(mpc.branch,1)
    if defense_locations(i) > 0 % If there are any defenses located at this line
        if mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) || mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1)
            latlon = [mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1); ...
                      mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1)];
                                     
            lat_F = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2);
            lon_F = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1);

            lat_T = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2);
            lon_T = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1);
            
            mid_lat = (lat_F + lat_T) / 2;
            mid_lon = (lon_F + lon_T) / 2;
            
            % Space the defense markers along the line itself, slightly
            % offset to one side, so they are not confused with other lines
            u = [lat_T - lat_F, lon_T - lon_F] / norm([lat_T - lat_F, lon_T - lon_F]); % Unit vector along the line
            p = [-u(2), u(1)]; % Unit vector perpendicular to the line
            for k=1:defense_locations(i)
                pos = [mid_lat mid_lon] + defense_spacing*(k-(defense_locations(i)+1)/2)*u + defense_offset*p;
                plotm(pos,'b^','MarkerFaceColor','b','MarkerSize',10);
            end            
        end
    end
end

%% Plot direction of power flow by adding arrows along each line.
% Also label the total amount of power flowing in this direction.

qlen = 0.7; % Relative length of the arrows showing the direction of power flow
qmax = 0.7; % Maximum absolute length of the arrows showing the direction of power flow

% Offsets for the line labels
% dstr_lat = -0.1;
% dstr_lon = 0.1;
dstr_lat = 0;
dstr_lon = 0;

% Draw arrows in the middle of each line
lat = nan(size(mpc.branch,1),1);
lon = nan(size(mpc.branch,1),1);
dlat = nan(size(mpc.branch,1),1);
dlon = nan(size(mpc.branch,1),1);

str_lat = nan(size(mpc.branch,1),1);
str_lon = nan(size(mpc.branch,1),1);
str_txt = strings(size(mpc.branch,1),1);

for i=1:size(mpc.branch,1)
    if mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2) || mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1) ~= mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1)
%         if mpc.branch(i,BR_STATUS) == 1
            lat_F = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),2);
            lon_F = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,F_BUS),1),1);

            lat_T = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),2);
            lon_T = mpc.bus_geo(find(mpc.bus(:,BUS_I) == mpc.branch(i,T_BUS),1),1);

            [theta_F,~] = cart2pol(lat_F - lat_T, lon_F - lon_T);
            theta_T = theta_F;
            theta_F = theta_F + pi;

            len = min(sqrt((lat_F - lat_T)^2 + (lon_F - lon_T)^2), qmax);

            if mpc.branch(i,PF) > 0
                lat(i) = (lat_F + lat_T - cos(theta_F)*len*qlen) / 2;
                lon(i) = (lon_F + lon_T - sin(theta_F)*len*qlen) / 2;
                dlat(i) = cos(theta_F)*len*qlen;
                dlon(i) = sin(theta_F)*len*qlen;

                str_lat(i) = (lat_F + lat_T - cos(theta_F)*len*qlen/2) / 2;
                str_lon(i) = (lon_F + lon_T - sin(theta_F)*len*qlen/2) / 2;
                if mpc.branch(i,RATE_A) ~= 0
                    if just_percent_line_loading
                        str_txt(i) = strcat('L', int2str(i), {' ('}, num2str(100*abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF))/mpc.branch(i,RATE_A),'%-.1f'),'%)');
                    else
                        str_txt(i) = strcat('L', int2str(i), '\newline', string(round(abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF)))),'MVA (', num2str(100*abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF))/mpc.branch(i,RATE_A),'%-.1f'),'%)');
                    end
                else
                    if just_percent_line_loading
                        str_txt(i) = strcat('L', int2str(i));
                    else
                        str_txt(i) = strcat('L', int2str(i), '\newline', string(round(abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF)))),'MVA');
                    end
                end

            elseif mpc.branch(i,PF) < 0
                theta_T = theta_F - pi;
                theta_F = theta_F + pi;

                lat(i) = (lat_F + lat_T - cos(theta_F)*len*qlen) / 2;
                lon(i) = (lon_F + lon_T - sin(theta_F)*len*qlen) / 2;
                dlat(i) = cos(theta_F)*len*qlen;
                dlon(i) = sin(theta_F)*len*qlen;

                str_lat(i) = (lat_F + lat_T - cos(theta_F)*len*qlen) / 2;
                str_lon(i) = (lon_F + lon_T - sin(theta_F)*len*qlen) / 2;
                if mpc.branch(i,RATE_A) ~= 0
                    if just_percent_line_loading
                        str_txt(i) = strcat('L', int2str(i), {' ('}, num2str(100*abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF))/mpc.branch(i,RATE_A),'%-.1f'),'%)');
                    else
                        str_txt(i) = strcat('L', int2str(i), '\newline', string(round(abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF)))),'MVA (', num2str(100*abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF))/mpc.branch(i,RATE_A),'%-.1f'),'%)');
                    end
                else
                    if just_percent_line_loading
                        str_txt(i) = strcat('L', int2str(i));
                    else
                        str_txt(i) = strcat('L', int2str(i), '\newline', string(round(abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF)))),'MVA');
                    end
                end
            else % mpc.branch(i,PF) == 0
                str_lat(i) = (lat_F + lat_T - cos(theta_F)*len*qlen) / 2;
                str_lon(i) = (lon_F + lon_T - sin(theta_F)*len*qlen) / 2;
                if mpc.branch(i,RATE_A) ~= 0
                    if just_percent_line_loading
                        str_txt(i) = strcat('L', int2str(i), {' ('}, num2str(100*abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF))/mpc.branch(i,RATE_A),'%-.1f'),'%)');
                    else
                        str_txt(i) = strcat('L', int2str(i), '\newline', string(abs(round(mpc.branch(i,PF)))),'MVA (', num2str(100*abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF))/mpc.branch(i,RATE_A),'%-.1f'),'%)');
                    end
                else
                    if just_percent_line_loading
                        str_txt(i) = strcat('L', int2str(i));
                    else
                        str_txt(i) = strcat('L', int2str(i), '\newline', string(round(abs(mpc.branch(i,PF)+1i*mpc.branch(i,QF)))),'MVA');
                    end
                end
            end
%         end
    end
end

if any(~isnan(dlat))
    quiverm(lat,lon, dlat, dlon, 'k-', 0, 'filled');
end
try
    textm(str_lat+dstr_lat,str_lon+dstr_lon,str_txt,'FontSize',9);
catch
    warning('Could not display the line labels.');
end

%% Show generators and loads at each bus
% Note: For the Ukraine test case, generator buses don't have load, so we
% can simplify the display somewhat.
genByBus = zeros(size(mpc.bus,1),3);
genBus = false(size(mpc.bus,1),1);
for i=1:size(mpc.gen,1)
    genByBus(mpc.bus(:,BUS_I) == mpc.gen(i,GEN_BUS),1:3) = genByBus(mpc.bus(:,BUS_I) == mpc.gen(i,GEN_BUS),1:3) ...
                                                           + [mpc.gen(i,PG) mpc.gen(i,PMIN) mpc.gen(i,PMAX)];
    genBus(mpc.bus(:,BUS_I) == mpc.gen(i,GEN_BUS)) = true;                                                      
end

dlat_gen = 0.1;
dlon_gen = 0.1;
textm(mpc.bus_geo(genBus,2)+dlat_gen,mpc.bus_geo(genBus,1)+dlon_gen,strcat('B', num2str(mpc.bus(genBus,BUS_I),'%-d'), '\newline', 'P_g=', num2str(round(genByBus(genBus,1)),'%-.0f'), {' of '}, num2str(round(genByBus(genBus,3)),'%-.0f')  ,' MW'),'FontSize',10);
textm(mpc.bus_geo(~genBus,2)+dlat_gen,mpc.bus_geo(~genBus,1)+dlon_gen,strcat('B', num2str(mpc.bus(~genBus,BUS_I),'%-d'), '\newline', 'P_d=', num2str(round(mpc.bus(~genBus,PD)),'%-.0f'), {' of '}, num2str(mpc0.bus(~genBus,PD),'%-.0f'),' MW'),'FontSize',10);

%% Title with summary information
title(['Outcome ' int2str(outcomeIndex) ' of ' int2str(length(outcomes.failures)) ', Load shed for this outcome = ' num2str(outcomes.loadshed(outcomeIndex)*100,4) '%, Expected load shed across all outcomes = ' num2str(outcomes.probability' * outcomes.loadshed*100,4) '%'],'FontSize',20);

%% Format axis

axis tight
ax = gca;
ax.Clipping = 'off';
set(h, 'Clipping', false);
set(mapaxes_handle, 'Clipping', false);
zoom on

