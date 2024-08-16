function Eccen(Subj, Direc, Bkgd)
%Eccen(Subj, Direc, Bkgd)
%
% Eccentricity mapping

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
Parameters.Resolution=[0 0 1024 768];   % Resolution  %原程序为[0 0 1400 1050]
Parameters.Foreground=[0 0 0];  % Foreground colour
Parameters.Background=[127 127 127];    % Background colour
Parameters.FontSize = 15;   % Size of font
Parameters.FontName = 'Helvetica';  % Font to use

%% Scanner parameters
Parameters.TR=3.06;    % Seconds per volume
Parameters.Number_of_Slices=36; % Number of slices
Parameters.Dummies=0;   % Dummy volumes  %dummy volumes是为了消除fMRI最初8s的不稳定？原来为4，现改为0
Parameters.Overrun=0;   % Dummy volumes at end

%% Experiment parameters
Parameters.Cycles_per_Expmt=15;  % Stimulus cycles per run
Parameters.Vols_per_Cycle=10;   % Volumes per cycle 
Parameters.Prob_of_Event=0;  % Probability of a jerk event   %去掉了jerk，将概率从0.05改为了0
Parameters.Event_Duration=0.2;  % Duration of a jerk event
Parameters.Event_Size=2.5;  % Size of jerk event in degrees
Parameters.Apperture='Ring';    % Stimulus type
Parameters.Apperture_Width=170;  % Width of ring in pixels
Parameters.Direction=Direc; % Direction of cycling
Parameters.Rotate_Stimulus=false;   % Does image rotate?
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
    % Ripple stimulus movie
    load('Ripples');
    Parameters.Stimulus=Stimulus; 
    Parameters.Refreshs_per_Stim=4;
end

%% Various parameters
%Parameters.Instruction='Welcome!\n\nPress button when there is a jerk!';
Parameters.Instruction='Welcome!\n\nPress left button when the fixation turns gray!';
[Parameters.Session Parameters.Session_name]=CurrentSession([Subj '_Eccen' Direc Bkgd]); % Determine current session

%% Run the experiment
Retinotopic_Mapping(Parameters, Emul);
