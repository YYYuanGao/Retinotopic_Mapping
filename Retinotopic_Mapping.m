function Retinotopic_Mapping(Parameters, Emulate)
%Retinotopic_Mapping_PTB(Parameters, Emulate)
% 
% Cyclic presentation with a rotating and/or expanding aperture.
% Behind the aperture a background is displayed as a movie.
%
% Parameters:
%   Parameters :    Struct containing various parameters
%   Emulate :       0 (default) for scanning
%                   1 for simulation with SimulScan
%                   2 for manual trigger
%

% Create the mandatory folders if not already present 
if ~exist([cd '\Results'], 'dir')
    mkdir('Results');
end

%% Behavioural data
Behaviour = struct;
Behaviour.EventTime = [];
Behaviour.Response = [];
Behaviour.ResponseTime = [];

%% Initialize randomness & keycodes
SetupRand;
SetupKeyCodes;

%% Stimulus conditions 
Volumes = [];  
% Cycle through repeats of each set
for i = 1 : Parameters.Cycles_per_Expmt 
    Volumes = [Volumes; ones(Parameters.Vols_per_Cycle, 1)];
end
Vols_per_Expmt = length(Volumes);
if Emulate
    % In manual start there are no dummies
    Parameters.Dummies = 0;
    Parameters.Overrun = 0;
end
disp(['Volumes = ' num2str(Vols_per_Expmt + Parameters.Dummies + Parameters.Overrun)]); disp(' ');
WaitSecs(0.5);
% Add column for volume time stamps
Volumes = [Volumes, zeros(Vols_per_Expmt,1)];
Cycle_Vols = find(Volumes(:,1) == 1);

%% Event timings
Events = [];
for e = Parameters.TR : Parameters.Event_Duration : (Parameters.Cycles_per_Expmt * Parameters.Vols_per_Cycle * Parameters.TR)
    if rand < Parameters.Prob_of_Event
        Events = [Events; e];
    end
end
% Add a dummy event at the end of the Universe
Events = [Events; Inf];

%% Configure scanner 
if Emulate 
    % Emulate scanner
    TrigStr = 'Press key to start...';    % Trigger string
else
    % Real scanner
    TrigStr = 'Stand by for scan...';    % Trigger string
end

%% Initialize PTB
Screen('Preference', 'SkipSyncTests', 1);
[Win Rect] = Screen('OpenWindow', Parameters.Screen, Parameters.Background, Parameters.Resolution); 
Screen('TextFont', Win, Parameters.FontName);
Screen('TextSize', Win, Parameters.FontSize);
Screen('BlendFunction', Win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
HideCursor;
RefreshDur = Screen('GetFlipInterval',Win);
Slack = RefreshDur / 2;

%% Load background movie
StimRect = [0 0 size(Parameters.Stimulus,2) size(Parameters.Stimulus,1)];
BgdTextures = [];
for f = 1:size(Parameters.Stimulus, 3)
    BgdTextures(f) = Screen('MakeTexture', Win, Parameters.Stimulus(:,:,f));
end

%% Create apperture texture
[X Y] = meshgrid(-Rect(3)*2/3:Rect(3)*2/3, -Rect(3)*2/3:Rect(3)*2/3);
[T R] = cart2pol(X,Y);
T = NormDeg(T / pi * 180);
Apperture = 127 * ones(size(T));
if strcmpi(Parameters.Apperture, 'Ring')
    Apperture(:,:,2) = (R < Rect(4)/2 - Parameters.Apperture_Width | R > Rect(4)/2) * 255;
elseif strcmpi(Parameters.Apperture, 'Wedge')
    Apperture(:,:,2) = (T < 90-Parameters.Apperture_Width/2 | T > 90+Parameters.Apperture_Width/2 | R > Rect(4)/2) * 255;
end
AppRect = [0 0 size(Apperture,2) size(Apperture,1)];
AppTexture = Screen('MakeTexture', Win, Apperture);

%% Create fixation cross
Fix_Cross = cross_matrix(16) * 255;
[fh fw] = size(Fix_Cross);
Fix_Cross(:,:,2) = Fix_Cross;   % alpha layer
Fix_Cross(:,:,1) = InvertContrast(Fix_Cross(:,:,1));
FixCrossTexture = Screen('MakeTexture', Win, Fix_Cross);

%% Standby screen
Screen('FillRect', Win, Parameters.Background, Rect);
DrawFormattedText(Win, [Parameters.Instruction '\n \n' TrigStr], 'center', 'center', Parameters.Foreground); 
Screen('Flip', Win);

%% Wait for start of experiment

Trigger = 83;  % 's'
is_true = 0;
if Emulate == 1
%     while (is_true == 0)
%         [keyIsDown,junk4,keyCode] = KbCheck;
%         if keyCode(Trigger)
%             is_true = 1;
%         end
%     end
    KbWait;
    WaitSecs(Parameters.TR*Parameters.Dummies);
    Start_Session = GetSecs;
    CurrSlice = 0;
else
   while (is_true == 0)
        [keyIsDown,junk4,keyCode] = KbCheck;
        if keyCode(Trigger)
            is_true = 1;
        end
    end
end

%% Begin main experiment 
Start_of_Expmt = NaN;   % Time when cycling starts
FrameTimes = [];  % Time stamp of each frame
CurrEvent = 1;  % Current dimming event
CurrFrame = 1;  % Current stimulus frame
CurrRefresh = 0;   % Current video refresh
CurrAngle = 0;  % Current angle of wedge
CurrScale = 0;  % Current inner radius of ring
PrevKeypr = 0;  % If previously key was pressed

%% Draw the fixation cross
Screen('FillRect', Win, Parameters.Background, Rect);
Screen('DrawTexture', Win, FixCrossTexture, [0 0 fh fw], CenterRect([0 0 fh fw], Rect));
Screen('Flip', Win);
WaitSecs(Parameters.TR*Parameters.Dummies);

%% Start cycling the stimulus
Behaviour.EventTime = [];    %Events;
CycleDuration = Parameters.TR * Parameters.Vols_per_Cycle;
CyclingEnd = CycleDuration * Parameters.Cycles_per_Expmt;
CyclingStart = GetSecs;
CurrTime = GetSecs-CyclingStart;
everrand = 0; %为了增加中心注视点 by jiake 20121226 

% Loop until the end of last cycle
while CurrTime < CyclingEnd    
    % Update frame number
    CurrRefresh = CurrRefresh + 1;
    if CurrRefresh == Parameters.Refreshs_per_Stim
        CurrRefresh = 0;
        CurrFrame = CurrFrame + 1;
        if CurrFrame > size(Parameters.Stimulus,3) 
            CurrFrame = 1;
        end
    end
    % Current time stamp
    CurrTime = GetSecs-CyclingStart;       
    % Current frame time & condition
    FrameTimes = [FrameTimes; CurrTime CurrFrame CurrAngle CurrScale];

    %% Prepare aperture
    % Is this an event? (Jump apperture by a step)
    CurrEvents = Events - CurrTime;
    if sum(CurrEvents > 0 & CurrEvents < Parameters.Event_Duration)
        AppJump = Parameters.Event_Size;
    else 
        AppJump = 0;
    end
    % Determine size & angle
    if strcmpi(Parameters.Apperture, 'Wedge')
        CurrScale = 1;
        if strcmpi(Parameters.Direction, '+')
            CurrAngle = 90 + (CurrTime/CycleDuration) * 360 + AppJump;
        elseif strcmpi(Parameters.Direction, '-')
            CurrAngle = 90 - (CurrTime/CycleDuration) * 360 + AppJump;
        end
    elseif strcmpi(Parameters.Apperture, 'Ring')
        CurrAngle = 90;
        if strcmpi(Parameters.Direction, '+')
            CurrScale = 0.05 + mod(CurrTime, CycleDuration)/CycleDuration * 0.95 + AppJump;
        elseif strcmpi(Parameters.Direction, '-')
            CurrScale = 1 - mod(CurrTime, CycleDuration)/CycleDuration * 0.95 + AppJump;
        end
    end
      
    %% Stimulus presentation
    %下面对这一部分进行了修改，添加了中心任务，194--240保留了原程序
%    
%     % Display background
%     if Parameters.Rotate_Stimulus
%         BgdAngle = CurrAngle;
%     else        
%         BgdAngle = 0;
%     end
% 
%     Screen('DrawTexture', Win, BgdTextures(CurrFrame), StimRect, CenterRect(CurrScale * StimRect, Rect), BgdAngle);
%     % Draw aperture
%     Screen('DrawTexture', Win, AppTexture, [0 0 size(Apperture,2) size(Apperture,1)], CenterRect(CurrScale * AppRect, Rect), CurrAngle);
%     % Draw the fixation cross & aperture
%     Screen('DrawTexture', Win, FixCrossTexture);    
%     % Draw current video frame   
%     rft = Screen('Flip', Win);
%     if isnan(Start_of_Expmt)
%         Start_of_Expmt = rft;
%     end
%     
%     %% Behavioural response
%     [Keypr KeyTime Key] = KbCheck;
%     if Key(KeyCodes.Escape) 
%         % Abort screen
%         Screen('FillRect', Win, Parameters.Background, Rect);
%         DrawFormattedText(Win, 'Experiment was aborted!', 'center', 'center', Parameters.Foreground); 
%         WaitSecs(0.5);
%         ShowCursor;
%         Screen('CloseAll');
%         disp(' '); 
%         disp('Experiment aborted by user!'); 
%         disp(' ');
%         return
%     end
%     if Keypr 
%         if ~PrevKeypr
%             PrevKeypr = 1;
%             Behaviour.Response = [Behaviour.Response; find(Key)];
%             Behaviour.ResponseTime = [Behaviour.ResponseTime; KeyTime - CyclingStart];
%         end
%     else
%         if PrevKeypr
%             PrevKeypr = 0;
%         end
%     end
    
   %% Stimulus presentation
   
   %本部分添加了中心任务，要求：
   %    1、将jerk任务的概率降为0；
   %    2、中心任务为红色或绿色的圆点，每秒一个点，被试看到绿点按4键
   %    3、红点出现的概率为90%，绿点为10%，被试每10s做出一次反应，这个地方可以调整
   %    4、红点的亮度为127，绿点为70，根据409电脑设计，这样红绿亮度相当
   %    5、by jiake 20121226
     
    % Display background
    if Parameters.Rotate_Stimulus
        BgdAngle = CurrAngle;
    else        
        BgdAngle = 0;
    end

    Screen('DrawTexture', Win, BgdTextures(CurrFrame), StimRect, CenterRect(CurrScale * StimRect, Rect), BgdAngle);
    % Draw aperture
    Screen('DrawTexture', Win, AppTexture, [0 0 size(Apperture,2) size(Apperture,1)], CenterRect(CurrScale * AppRect, Rect), CurrAngle);
    % Draw the fixation cross & aperture
    %Screen('DrawTexture', Win, FixCrossTexture);    
    % Draw fixation dot

    if (abs(CurrTime - fix(CurrTime))< 0.15) & fix(CurrTime)>0
        if ~everrand
            Prob_of_red = 0.9;
            if rand < Prob_of_red
                dot_color = [255,0,0];
            else
                dot_color = [0,175,0];
            end
            Screen('DrawDots',Win,[Rect(3)/2,Rect(4)/2],6,dot_color,[],1);
            everrand = 1;
            if dot_color(2) == 175
                Behaviour.EventTime = [Behaviour.EventTime; round(CurrTime)-0.15];
            end    
        else
            Screen('DrawDots',Win,[Rect(3)/2,Rect(4)/2],6,dot_color,[],1);
        end
    else
        everrand = 0;
    end
    
    % Draw current video frame
    rft = Screen('Flip', Win);
    if isnan(Start_of_Expmt)
        Start_of_Expmt = rft;
    end
    
    %% Behavioural response
    [Keypr KeyTime Key] = KbCheck;
    if Key(KeyCodes.Escape) 
        % Abort screen
        Screen('FillRect', Win, Parameters.Background, Rect);
        DrawFormattedText(Win, 'Experiment was aborted!', 'center', 'center', Parameters.Foreground); 
        WaitSecs(0.5);
        ShowCursor;
        Screen('CloseAll');
        disp(' '); 
        disp('Experiment aborted by user!'); 
        disp(' ');
        return
    end
    if Keypr 
        if ~PrevKeypr
            PrevKeypr = 1;
            Behaviour.Response = [Behaviour.Response; find(Key)];
            Behaviour.ResponseTime = [Behaviour.ResponseTime; KeyTime - CyclingStart];
        end
    else
        if PrevKeypr
            PrevKeypr = 0;
        end
    end
    
end

%% Draw the fixation cross
Screen('DrawTexture', Win, FixCrossTexture);
End_of_Expmt = Screen('Flip', Win);

%% Farewell screen
Screen('FillRect', Win, Parameters.Background, Rect);
DrawFormattedText(Win, 'Thank you!', 'center', 'center', Parameters.Foreground); 
Screen('Flip', Win);
WaitSecs(Parameters.TR * Parameters.Overrun);
ShowCursor;
Screen('CloseAll');

%% accuracy
num_Event = length(Behaviour.EventTime);
numacc = 0;
for i = 1:num_Event
    interval = Behaviour.ResponseTime - Behaviour.EventTime(i);
    acc_interval = (interval>0 & interval<1);
    
    if any(acc_interval) 
        if any(Behaviour.Response((acc_interval==1)) == 52)
            numacc = numacc +1;
        end
    end
end

acc = numacc/num_Event;

%% Save workspace
clear('Apperture', 'R', 'T', 'X', 'Y');
Parameters.Stimulus = [];
save(['Results\' Parameters.Session_name]);

%% Experiment duration
new_line;
ExpmtDur = End_of_Expmt - Start_of_Expmt + Parameters.TR * Parameters.Overrun + Parameters.TR* Parameters.Dummies;
ExpmtDurMin = floor(ExpmtDur/60);
ExpmtDurSec = mod(ExpmtDur, 60);
disp(['Cycling lasted ' n2s(ExpmtDurMin) ' minutes, ' n2s(ExpmtDurSec) ' seconds']);
new_line;
disp(num2str(acc));
new_line;
WaitSecs(1);
