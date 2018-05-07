function [sol_eq, sol_i_eq, sol_i_eq_SR, ssol_i_eq, ssol_i_eq_SR, sol_i_1S_SR, ssol_i_1S_SR] = equilibrate_minimal(params)
%EQUILIBRATE_MINIMAL Uses analytical initial conditions and runs to equilibrium and steady state
% Takes the parameters from pinParams.m file and tries
% to obtain an equilibrium solution (as if the device has been left for
% a long period of time). This solution can then be used as accurate
% initial conditions for other simulations, e.g. a JV scan.
% Note that tmax is consistently adjusted to appropriate values for to
% ensure there are numerous mesh points where large gradients in the time
% dimension are present.
%
% Syntax:  [sol_eq, sol_i_eq, sol_i_eq_SR, ssol_i_eq, ssol_i_eq_SR, sol_i_1S_SR, ssol_i_1S_SR] = EQUILIBRATE_MINIMAL(PARAMS)
%
% Inputs:
%   PARAMS - optional, struct containing the needed parameters as obtained
%     from pinParams.m
%
% Outputs:
%   sol_eq - short circuit, dark, no mobile ionic defects, no SRH
%   sol_i_eq - short circuit, dark, mobile ionic defects, no SRH
%   sol_i_eq_SR - short circuit, dark, mobile ionic defects, with SRH
%   ssol_i_eq - open circuit, dark, mobile ionic defects, no SRH
%   ssol_i_eq_SR - open circuit, dark, mobile ionic defects, with SRH
%   sol_i_1S_SR - short circuit, 1 sun, mobile ionic defects, with SRH
%   ssol_i_1S_SR - open circuit, 1 sun, mobile ionic defects, with SRH
%
% Example:
%   [sol_eq, sol_i_eq, sol_i_eq_SR, ssol_i_eq, ssol_i_eq_SR, sol_i_1S_SR, ssol_i_1S_SR] = equilibrate_minimal()
%     generate stabilized solutions
%
% Other m-files required: pindrift, pinParams, mobsetfun
% Subfunctions: none
% MAT-files required: none
%
% See also pindrift, paramsStruct, equilibrate.

% Author: Phil Calado, Ph.D.
% Imperial College London
% Research Group Prof. Jenny Nelson
% email address: p.calado13@imperial.ac.uk
% Contributors: Ilario Gelmetti, Ph.D. student
% Institute of Chemical Research of Catalonia (ICIQ)
% Research Group Prof. Emilio Palomares
% email address: iochesonome@gmail.com
% Supervised by: Dr. Piers Barnes, Prof. Jenny Nelson
% Imperial College London
% 2015; Last revision: May 2018

%------------- BEGIN CODE --------------

tic;    % Start stopwatch

%% Initial arguments
% Setting sol.sol = 0 enables a parameters structure to be read into
% pindrift but indicates that the initial conditions should be the
% analytical solutions
sol0.sol = 0;    

% if a params struct has been provided in input, use it instead of the
% pinParams file
if nargin
    p = params;
else
    p = pinParams;
end

% Store initial parameters
original_p = p;

%% Start with low recombination coefficients
p.klin = 0;
p.klincon = 0;
p.taun_etl = 1e6;       % [s] SRH time constant for electrons
p.taup_etl = 1e6;      % [s] SRH time constant for holes
p.taun_htl = 1e6;       %%%% USE a high value of (e.g.) 1 to switch off
p.taup_htl = 1e6;

%% General initial parameters
p.tpoints = 20;

p.Ana = 0;
p.JV = 0;
p.Vapp = 0;
p.Int = 0;
p.pulseon = 0; 
p.OC = 0;
p.BC = 1;
p.tmesh_type = 2;
p.tmax = 1e-9;
p.t0 = p.tmax/1e4;

%% Mobsetfun is used to easily set mobilities
p = mobsetfun(0, 0, p);

%% Initial solution with zero mobility
disp('Initial solution, zero mobility')
sol1 = pindrift(sol0, p);
disp('Complete')

p.figson = 0; % reduce annoyance of figures popping up
p.tmax = 1e-9;
p.t0 = p.tmax/1e3;

%% Mobility with mobility switched on

% switch on electron and hole mobility
p.mue_i = original_p.mue_i; % electron mobility in intrinsic
p.muh_i = original_p.muh_i; % hole mobility in intrinsic
p.mue_p = original_p.mue_p; % electron mobility in p-type
p.muh_p = original_p.muh_p; % hole mobility in n-type
p.mue_n = original_p.mue_n; % electron mobility in p-type
p.muh_n = original_p.muh_n; % hole mobility in n-type

disp('Solution with mobility switched on')
sol2 = pindrift(sol1, p);

p.Ana = 1;
p.calcJ = 0;
p.tmax = 1e-2;
p.t0 = p.tmax/1e10;

sol_eq = pindrift(sol2, p);

verifyStabilization(sol_eq.sol, sol_eq.t, 0.2); % verify solution stability
sol_eq.p.figson = 1; % re-enable figures creation for this solution
disp('Complete')

%% Equilibrium solution with mirrored cell and OC boundary conditions, mobility zero
disp('Initial equilibrium open circuit solution')
p.BC = 1;
p.OC = 1;
p.calcJ = 0;
p = mobsetfun(0, 0, p);

% switch on electron and hole mobility
p.mue_i = original_p.mue_i; % electron mobility in intrinsic
p.muh_i = original_p.muh_i; % hole mobility in intrinsic
p.mue_p = original_p.mue_p; % electron mobility in p-type
p.muh_p = original_p.muh_p; % hole mobility in n-type
p.mue_n = original_p.mue_n; % electron mobility in p-type
p.muh_n = original_p.muh_n; % hole mobility in n-type

% Longer time step to ensure equilibrium has been reached
p.tmax = 1e-2;
p.t0 = p.tmax/1e3;

%% Equilibrium solutions with ion mobility switched on
%% Closed circuit conditions
disp('Closed circuit equilibrium with ions')

p.OC = 0;
p.tmax = 1e-6;
p.t0 = p.tmax/1e3;
p.mui = 1e-6;           % Ions are accelerated to reach equilibrium

sol4 = pindrift(sol_eq, p);

% Much longer second step to ensure that ions have migrated
p.calcJ = 0;
p.tmax = 1e2;
p.t0 = p.tmax/1e3;
p.mui = original_p.mui; % Ions are set to the correct speed indicated in pinParams

sol_i_eq = pindrift(sol4, p);

verifyStabilization(sol_i_eq.sol, sol_i_eq.t, 0.2); % verify solution stability
sol_i_eq.p.figson = 1; % re-enable figures creation for this solution
disp('Complete')

%% Ion equilibrium with surface recombination
disp('Switching on surface recombination')
p.taun_etl = original_p.taun_etl;
p.taup_etl = original_p.taup_etl;
p.taun_htl = original_p.taun_htl;
p.taup_htl = original_p.taup_htl;

p.calcJ = 0;
p.tmax = 1e-6;
p.t0 = p.tmax/1e3;

sol_i_eq_SR = pindrift(sol_i_eq, p);

sol_i_eq_SR_p = p; % temporarily save params
verifyStabilization(sol_i_eq_SR.sol, sol_i_eq_SR.t, 0.2); % verify solution stability
sol_i_eq_SR.p.figson = 1; % re-enable figures creation for this solution
disp('Complete')

% Switch off SR
p.taun_etl = 1e6;
p.taup_etl = 1e6;
p.taun_htl = 1e6;
p.taup_htl = 1e6; 

%% Symmetricise closed circuit condition
disp('Symmetricise equilibriumion solution')
symsol = symmetricize(sol_i_eq);
disp('Complete')

p.OC = 1;
p.tmax = 1e-9;
p.t0 = p.tmax/1e3;
p = mobsetfun(0, 0, p);

%% OC condition with ions at equilbirium
disp('Open circuit equilibrium with ions')
ssol = pindrift(symsol, p);

p.tmax = 1e-9;
p.t0 = p.tmax/1e3;
p.mui = 0;

% switch on electron and hole mobility
p.mue_i = original_p.mue_i; % electron mobility in intrinsic
p.muh_i = original_p.muh_i; % hole mobility in intrinsic
p.mue_p = original_p.mue_p; % electron mobility in p-type
p.muh_p = original_p.muh_p; % hole mobility in n-type
p.mue_n = original_p.mue_n; % electron mobility in p-type
p.muh_n = original_p.muh_n; % hole mobility in n-type

ssol = pindrift(ssol, p);

% Switch on ion mobility to ensure equilibrium has been reached
p.tmax = 1e-6;
p.t0 = p.tmax/1e3;
p.mui = original_p.mui; % this requires mui to be set in the original params

ssol = pindrift(ssol, p);

p.tmax = 1e2;
p.t0 = p.tmax/1e3;

ssol_i_eq = pindrift(ssol, p);

ssol_i_eq_p = p; % temporarily save params
verifyStabilization(ssol_i_eq.sol, ssol_i_eq.t, 0.2); % verify solution stability
ssol_i_eq.p.figson = 1; % re-enable figures creation for this solution
disp('Complete')

%% Dark, mobile ions, open circuit, surface recombination
disp("Dark, mobile ions, open circuit, surface recombination")
p = ssol_i_eq_p;
p.taun_etl = original_p.taun_etl;
p.taup_etl = original_p.taup_etl;
p.taun_htl = original_p.taun_htl;
p.taup_htl = original_p.taup_htl;

ssol_i_eq_SR = pindrift(ssol_i_eq, p);
ssol_i_eq_SR = pindrift(ssol_i_eq_SR, p);
p.tmax = p.tmax * 10;
ssol_i_eq_SR = pindrift(ssol_i_eq_SR, p);
ssol_i_eq_SR = pindrift(ssol_i_eq_SR, p);
ssol_i_eq_SR = pindrift(ssol_i_eq_SR, p);
p.tmax = p.tmax * 10;
ssol_i_eq_SR = pindrift(ssol_i_eq_SR, p);
ssol_i_eq_SR = pindrift(ssol_i_eq_SR, p);

ssol_i_eq_SR_p = p; % temporarily save params
verifyStabilization(ssol_i_eq_SR.sol, ssol_i_eq_SR.t, 0.2); % verify solution stability
ssol_i_eq_SR.p.figson = 1; % re-enable figures creation for this solution
disp('Complete')

%% Illuminated, mobile ions, short circuit, surface recombination
disp("Illuminated, mobile ions, short circuit, surface recombination")
p = sol_i_eq_SR_p;
p.Int = original_p.Int;

sol_i_1S_SR = pindrift(sol_i_eq_SR, p);

verifyStabilization(sol_i_1S_SR.sol, sol_i_1S_SR.t, 0.2); % verify solution stability
sol_i_1S_SR.p.figson = 1; % re-enable figures creation for this solution
disp('Complete')

%% Illuminated, mobile ions, open circuit, surface recombination
disp("Illuminated, mobile ions, open circuit, surface recombination")
p = ssol_i_eq_SR_p;
p.Int = original_p.Int;

p.tmax = p.tmax / 1e1;
ssol_i_1S_SR = pindrift(ssol_i_eq_SR, p);

p.tmax = p.tmax * 1e2;
p.figson = 1; % for the last simulation, figures popping up are ok
ssol_i_1S_SR = pindrift(ssol_i_1S_SR, p);

verifyStabilization(ssol_i_1S_SR.sol, ssol_i_1S_SR.t, 0.2); % verify solution stability
disp('Complete')

disp('EQUILIBRATION COMPLETE')
toc

end