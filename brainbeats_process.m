%% Brainbeats_process
% Process single EEGLAB files containg EEG and cardiovascular (ECG or PPG)
% signals. 
% 
% Mode 1: Hearbteat evoked potentials (HEP) and oscillations (HEO).
% Mode 2: Extract EEG and HRV features.
% Mode 3: Remove heart components from EEG signals.
% 
% Potential tooblox names: BrainBeats, CardioNeuroSync (CNS), NeuroPulse, CardioCortex
%
% Copyright (C) Cedric Cannard, 2023

function [EEG, Features, com] = brainbeats_process(EEG, varargin)

pop_editoptions('option_single', 0); % ensure double precision
Features = [];
com = '';

% % Add path to subfolders
mainpath = fileparts(which('eegplugin_BrainBeats.m'));
addpath(fullfile(mainpath, 'functions'));
addpath(fullfile(mainpath, 'functions', 'restingIAF'));
% addpath(fullfile(mainpath, 'functions', 'fieldtrip'));
% outPath = fullfile(mainpath, 'sample_data'); %FIXME: ASK USER FOR OUTPUT DIR

% Basic checks
if ~exist('EEG','var')
    error('This plugin requires that your data (containing both EEG and ECG/PPG signals) are already loaded into EEGLAB.')
end
if nargin < 1
    help pop_BrainBeats; return;
end
if isempty(EEG) || isempty(EEG.data)
    error('Empty EEG dataset.');
end
if isempty(EEG.chanlocs(1).labels)
    error('No channel labels.');
end
if isempty(EEG.ref)
    warning('EEG data not referenced! Referencing is highly recommended');
end

%%%%%%%%%%%%%%%%%%%% Main parameters %%%%%%%%%%%%%%%%%%%%%
if nargin == 1
    params = getparams_gui(EEG);                % GUI
elseif nargin > 1
    params = getparams_command(varargin{:});    % Command line
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% if GUI was aborted (FIXME: should not send this error)
if ~isfield(params, 'heart_channels')
    disp('Aborted'); return
end

% Check if data format is compatible with chosen analysis and select analysis
if isfield(params,'analysis')
    switch params.analysis
        case 'continuous'
            if length(size(EEG.data)) ~= 2
                error("You selected feature-based analysis but your data are not continuous.")
            end
        case 'epoched'
            if length(size(EEG.data)) ~= 3
                error("You selected HEP analysis but your data are not epoched.")
            end
    end
else
    % Select analysis based on data format if not defined
    if length(size(EEG.data)) == 2
        params.analysis = 'continuous';
        disp("Analysis not defined. Continuous data detected: selecting 'feature-based mode' by default")
    elseif length(size(EEG.data)) == 3
        params.analysis = 'epoched';
        disp("Analysis not defined. Epoched data detected: selecting 'heart-beat evoked potential (HEP) mode' by default")
    else
        error("You did not define the analysis to run, and your data format was not recognized. " + ...
            "Should be 'continuous' or 'epoched', and something may be wrong with your data format ")
    end
end

% Check if heart channels are in file (for command line mode)
if contains({EEG.chanlocs.labels}, params.heart_channels) == 0
    error('The heart channel names you inputted cannot be found in the current dataset.')
else
    % Check it is cell if only one ECG channel (FIXME: move this to getparams_gui)
    if ~iscell(params.heart_channels)
        params.heart_channels = {params.heart_channels};
    end
end

% Check for channel locations for visualization
if params.vis
    if ~isfield(EEG.chanlocs, 'X') || isempty(EEG.chanlocs(1).X)
        error("Electrode location coordinates must be loaded for visualizing outputs.");
    end
end

% Parallel computing
if ~isfield(params,'parpool') % not available from GUI yet
    params.parpool = false;
end

% GPU computing
if ~isfield(params,'gpu') % not available from GUI yet
    params.gpu = false;
end

% Save outputs?
if ~isfield(params,'save') % not available from GUI yet
    params.save = true;
end

%%%%%%%%%%%%% PREP EEG DATA %%%%%%%%%%%%%

EEG.data = double(EEG.data);  % ensure double precision
params.fs = EEG.srate;
% EEG = pop_select(EEG,'nochannel',params.heart_channels); % FIXME: remove all non-EEG channels instead
% 
% % Filter, re-reference, remove bad channels
% if params.clean_eeg    
%     params.clean_eeg_step = 0;
%     [EEG, params] = clean_eeg(EEG, params);
% end


%%%%% MODE 1: remove heart components from EEG signals with IClabel %%%%%
if strcmp(params.analysis,'rm_heart')    
    EEG = remove_heartcomp(EEG, params);
end

%%%%% MODE 2 & 3: RR, SQI, and NN %%%%%
if contains(params.analysis, {'features' 'hep'})

    % Get RR, SQI ans NN for each ECG electrode
    % note: using structures as outputs because they often have different
    % lengths, causing issues
    if strcmp(params.heart_signal, 'ecg')

        ECG = pop_select(EEG,'channel',params.heart_channels); % export ECG data in separate structure
        ecg = ECG.data;
        nElec = size(ecg,1);
        for iElec = 1:nElec
            elec = sprintf('elec%g',iElec);
            fprintf('Detecting R peaks from ECG time series: electrode %g...\n', iElec)
            [RR.(elec), RR_t.(elec), Rpeaks.(elec), sig_filt(iElec,:), sig_t(iElec,:), HR] = get_RR(ecg(iElec,:)', params);

            % SQI
            SQIthresh = .9; % minimum SQI recommended by Vest et al. (2019)
            [sqi(iElec,:), sqi_times(iElec,:)] = get_sqi(Rpeaks.(elec), ecg(iElec,:), params.fs);
            SQI(iElec,:) = sum(sqi(iElec,:) < SQIthresh) / length(sqi(iElec,:));  

            % Correct RR artifacts (e.g., arrhytmia, ectopy, noise) to obtain the NN series
            % FIXME: does not take SQI into account
            rr_t = RR_t.(elec); 
            rr_t(1) = [];   % remove 1st heartbeat
            vis = false;    % to visualize artifacts that are inteprolated
            [NN.(elec), NN_t.(elec), flagged.(elec)] = clean_rr(rr_t, RR.(elec), params, vis);
            flaggedRatio.(elec) = sum(flagged.(elec)) / length(flagged.(elec));

            % if sum(flagged) > 0
            %     if contains(params.rr_correct,'remove')
            %         fprintf('%g heart beats were flagged as artifacts and removed. \n', sum(flagged));
            %     else
            %         fprintf('%g heart beats were flagged as artifacts and interpolated. \n', sum(flagged));
            %     end
            % end
        end

        % Keep only ECG data of electrode with the best SQI (FIXME: Use flagged
        % hearbeats from clean_RR instead?)
        % [~, best_elec] = min(SQI);
        % sqi = [sqi_times(best_elec,:); sqi(best_elec,:)];
        % SQI = SQI(best_elec);
        [~,best_elec] = min(struct2array(flaggedRatio));
        elec = sprintf('elec%g',best_elec);
        maxThresh = .2;         % max portion of artifacts (.2 default from Vest et al. 2019)
        % if SQI > maxThresh    % more than 20% of RR series is bad
        %      warning on
        %     warning("%g%% of the RR series on your best ECG electrode has a signal quality index (SQI) below minimum recommendations (max 20%% below SQI = .9; see Vest et al., 2019)!",round(SQI,2));
        %     error("Signal quality is too low: aborting! You could inspect the data in EEGLAB > Plot > Channel data (Scroll) and try to remove large artifacts first.");
        % else
        %     fprintf( "Keeping only the heart electrode with the best signal quality index (SQI): %g%% of the RR series is outside of the recommended threshold. \n", SQI )
        % end
        flaggedRatio = flaggedRatio.(elec);
        flagged = flagged.(elec);
        if  flaggedRatio > maxThresh % more than 20% of RR series is bad
            warning on
            warning("%g%% of the RR series on your best ECG electrode are artifacts, this is below minimum recommendations (max 20%% is tolerated)", round(flaggedRatio,2));
            error("Signal quality is too low: aborting! You could inspect the data in EEGLAB > Plot > Channel data (Scroll) and try to remove large artifacts first.");
        else
            fprintf( "Keeping only the heart electrode with the best signal quality index (SQI): %g%% of the RR series is outside of the recommended threshold. \n", round(flaggedRatio,2) )
        end

        sig_t = sig_t(best_elec,:);
        sig_filt = sig_filt(best_elec,:);
        RR = RR.(elec);
        RR_t = RR_t.(elec);
        RR_t(1) = [];       % always ignore 1st hearbeat
        Rpeaks = Rpeaks.(elec);
        Rpeaks(1) = [];     % always ignore 1st hearbeat
        NN_t = NN_t.(elec);
        NN = NN.(elec);
        
    elseif strcmp(params.heart_signal,'ppg')
        error("Work in progress, sorry!");
        % [rr,t_rr,sqi] = Analyze_ABP_PPG_Waveforms(InputSig,{'PPG'},HRVparams,[],subID);

    else
        error("Unknown heart signal. Should be 'ecg' or 'ppg'.");
    end

    % % Correct RR artifacts (e.g., arrhytmia, ectopy, noise) to obtain the NN series
    % % FIXME: does not take SQI into account
    % vis = false;    % to visualize artifacts that are inteprolated
    % [NN, NN_times, flagged] = clean_rr(RR_t, RR, sqi, params, vis);
    % if sum(flagged) > 0
    %     if contains(params.rr_correct,'remove')
    %         fprintf('%g heart beats were flagged as artifacts and removed. \n', sum(flagged));
    %     else
    %         fprintf('%g heart beats were flagged as artifacts and interpolated. \n', sum(flagged));
    %     end
    % end

    % Plot filtered ECG and RR series of best electrode and interpolated
    % RR artifacts (if any)
    if params.vis
    
        plot_NN(sig_t,sig_filt,RR_t,RR,Rpeaks,NN_t,NN,flagged)

    end
    
    % Preprocessing outputs
    Features.HRV.ECG_filtered = sig_filt;
    Features.HRV.ECG_times = sig_t;
    Features.HRV.SQI = SQI;
    Features.HRV.RR = RR;
    Features.HRV.RR_times = RR_t;
    Features.HRV.HR = HR;
    Features.HRV.NN = NN;
    Features.HRV.NN_times = NN_t;
    Features.HRV.flagged_heartbeats = flagged;

    % Remove ECG data from EEG data
    EEG = pop_select(EEG,'nochannel',params.heart_channels); % FIXME: remove all non-EEG channels instead

    % Filter, re-reference, remove bad channels
    if params.clean_eeg    
        params.clean_eeg_step = 0;
        [EEG, params] = clean_eeg(EEG, params);
    end

    %%%%% MODE 2: Heartbeat-evoked potentials (HEP) %%%%%
    if strcmp(params.analysis,'hep')
        EEG = run_HEP(EEG, params, Rpeaks);
    end 
    
    %%%%% MODE 3: HRV features %%%%%
    if strcmp(params.analysis,'features') && params.hrv

        % if SQI <= .2 % tolerate up to 20% of RR artifacts
            if params.parpool
                % delete(gcp('nocreate')) %shut down opened parpool
                p = gcp('nocreate');
                if isempty(p) % if not already on, launch it
                    disp('Initiating parrallel computing (all available processors)...')
                    c = parcluster; % cluster profile
                    % N = feature('numcores');        % physical number of cores
                    N = getenv('NUMBER_OF_PROCESSORS'); % all processors (including threads)
                    if ischar(N)
                        N = str2double(N);
                    end
                    c.NumWorkers = N-1;  % update cluster profile to include all workers
                    c.parpool();
                end
            end

            % defaults
            % params.hrv_norm = true;  % default
            params.hrv_spec = 'Lomb-Scargle periodogram';  % 'Lomb-Scargle periodogram' (default), 'pwelch', 'fft', 'burg'
            params.hrv_overlap =  0.25; % 25%

            % File length (we take the whole series for now to allow ULF and VLF as much as possible)
            file_length = floor(EEG.xmax)-1;
            if file_length < 300
                warning('File length is shorter than 5 minutes! The minimum recommended is 300 s for estimating reliable HRV metrics.')
            end
            params.file_length = file_length;

            % Extract HRV measures
            HRV = get_hrv_features(NN, NN_t, params);

            % Final output with everything
            Features.HRV = HRV;

        % else
        %     error('Signal quality of the RR series is too low. HRV features will not be reliable')
        % end
    end

    %%%%% MODE 3: EEG features %%%%%
    if strcmp(params.analysis,'features') && params.eeg

        % Clean EEG artifacts with ASR
        if params.clean_eeg
            [EEG, params] = clean_eeg(EEG, params);
        end

        % Extract EEG features
        if params.eeg
            params.chanlocs = EEG.chanlocs;
            eeg_features = get_eeg_features(EEG.data, params);
        end

        % Final output with everything
        Features.EEG = eeg_features;

    end
end

%%%%%% PLOT & SAVE FEATURES %%%%%%%
if strcmp(params.analysis,'features')

    % Save in same repo as loaded file (FIXME: ASK USER FOR OUTPUT DIR)
    if params.save
        outputPath = fullfile(EEG.filepath, sprintf('%s_features.mat', EEG.filename(1:end-4)));
        fprintf("Saving Features in %s \n", outputPath);
        save(outputPath,'Features');
    end

    % Plot features
    if params.vis
        plot_features(Features,params)
    end
end

% Shut down parallel pool
% if params.parpool
%     delete(gcp('nocreate'));
% end

disp('Done!'); %gong


