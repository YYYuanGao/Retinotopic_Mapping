function Polar(Subj, Direc, Bkgd)
%Polar(Subj, Direc, Bkgd)
%
% Polar mapping

if nargin==0
    Subj='Demo';
    Direc='+';
    Bkgd='Checkerboard'; 
    Emul=1;
elseif nargin==1
    Direc='+';
    Bkgd='Checkerboard'; 
    Emul=0;
elseif nargin==2
    Bkgd='Checkerboard'; 
    Emul=0;
end

%% Engine parameters
Parameters.Screen=0;    % Main screen
Parameters.Resolution=[0 0 1920 1080];   % Resolution [0 0 1024 768]
Parameters.Foreground=[0 0 0];  % Foreground colour
Parameters.Background=[127 127 127];    % Background colour
Parameters.FontSize = 15;   % Size of font
Parameters.FontName = 'Helvetica';  % Font to use

%% Scanner parameters
Parameters.TR=2;    % Seconds per volume % 2
Parameters.Number_of_Slices=36; % Number of slices
Parameters.Dummies=4;   % Dummy volumes
Parameters.Overrun=6;   % Dummy volumes at end

%% Experiment parameters
Parameters.Cycles_per_Expmt=9;  % Stimulus cycles per run 
Parameters.Vols_per_Cycle=20;   % Volumes per cycle 
Parameters.Prob_of_Event=0;  % Probability of a jerk event
Parameters.Event_Duration=0.2;  % Duration of a jerk event
Parameters.Event_Size=2.5;  % Size of jerk event in degrees
Parameters.Apperture='Wedge';   % Stimulus type
Parameters.Apperture_Width=40;  % Width of wedge in degrees
Parameters.Direction=Direc; % Direction of cycling
Parameters.Rotate_Stimulus=true;    % Does image rotate?
if strcmpi(Bkgd, 'Checkerboard')
    % Conventional checkerboard
    load('Checkerboard');
    Parameters.Stimulus(:,:,1)=Checkerboard;
    Parameters.Stimulus(:,:,2)=InvertContrast(Checkerboard);
    Parameters.Refreshs_per_Stim=8;
elseif strcmpi(Bkgd, 'PolarChecker')
    % Polar checker stimulus
    Parameters.Stimulus(:,:,1)=Polar_Checker(10,0,900);
    Parameters.Stimulus(:,:,2)=Polar_Checker(10,90,900);
    Parameters.Refreshs_per_Stim=8;
elseif strcmpi(Bkgd, 'Ripples')
    Parameters.Rotate_Stimulus=false;
    % Ripple stimulus movie
    load('Ripples');
    Parameters.Stimulus=Stimulus; 
    Parameters.Refreshs_per_Stim=4;
end

%% Various parameters
%Parameters.Instruction='Welcome!\n\nPress button when there is a jerk!';
Parameters.Instruction='Welcome!\n\nPress right button when the fixation is green!';
[Parameters.Session Parameters.Session_name]=CurrentSession([Subj '_Polar' Direc Bkgd]); % Determine current session

%% Run the experiment
Retinotopic_Mapping(Parameters, Emul);
