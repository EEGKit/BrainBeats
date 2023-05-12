%% Extract EEG features in time, fequency, and nonlinear domains. 

function eeg_features = get_eeg_features(signals,times,params)

disp('Extracting EEG features...')

fs = params.fs; 

% Time domain
eeg_features.time.mean = mean(signals,2); 
eeg_features.time.trimmed_mean = trimmean(signals,20,2); 
eeg_features.time.median = median(signals,2); 
eeg_features.time.mode = mode(signals,2); 
eeg_features.time.var = var(signals,0,2); 
eeg_features.time.skewness = skewness(signals,0,2); 
eeg_features.time.kurtosis = kurtosis(signals,0,2); 
eeg_features.time.iqr = iqr(signals,2); 


% Frequency domain
nChan = size(signals,1);
fRange = [1 45];    % WARNING: make sure these are within filtered signal
winSize = 3;        % window size (in s). default = 2 (recommended by Smith et al (2017)
winType = 'hamming';
overlap = 50;       % 50% default (Smith et al. 2017)
useGPU = true;

% pwr = nan(nChan,fRange(2)*winSize);
for iChan = 1:nChan
    
    fprintf('EEG CHANNEL %g \n', iChan)
    
    % % Compute PSD using pwelch
    [pwr(iChan,:), pwr_dB(iChan,:), freqs] = compute_psd(signals(iChan,:), ...
            fs*winSize,winType,overlap,[],fs,fRange,'psd', useGPU);
    eeg_features.frequency.pwr(iChan,:) = pwr(iChan,:);
    eeg_features.frequency.pwr_dB(iChan,:) = pwr_dB(iChan,:);
    eeg_features.frequency.freqs(iChan,:) = freqs;
    
    % % Delta
    % EEG.frequency.delta(iChan,:) = pwr_dB(iChan,freqs >= fRange(1) & freqs <= 3);
    % 
    % % Theta
    % EEG.frequency.theta(iChan,:) = pwr_dB(iChan,freqs >= 3 & freqs <= 7);
    % 
    % % Alpha
    % EEG.frequency.alpha(iChan,:) = pwr_dB(iChan,freqs >= 8 & freqs <= 13);
    % 
    % % Beta
    % EEG.frequency.beta(iChan,:) = pwr_dB(iChan,freqs >= 13 & freqs <= 30);
    % 
    % % Low gamma
    % EEG.frequency.gamma(iChan,:) = pwr_dB(iChan,freqs >= 31 & freqs <= fRange(2));
    
    % Fuzzy entropy
    m = 2;
    r = .15;
    n = 2;
    tau = 1;
    coarseType = 'Standard deviation';
    nScales = 20;
    filtData = false;
    useGPU = true;

    % Entropy
    if length(times) > 5000 % Downsample to accelerate on data with more than 5,000 samples
        new_fs = 90;
        fac = fs / new_fs; % downsample factor

        % downsample if integer, otherwise decimate to round factor
        if fac ~= floor(fac)
            fac = round(fac);
            signals_res(iChan,:) = decimate(signals(iChan,:), fac);
            fprintf('Decimating EEG data to %g Hz sample rate to compute entropy on these large datasets. \n',new_fs)
        else
            signals_res(iChan,:) = resample(signals(iChan,:), 1, fac);
            fprintf('Downsampling EEG data to %g Hz sample rate to compute entropy on these large datasets. \n',new_fs)
        end
        % Plot to check
        % times_res = (0:1/new_fs:(length(signals_res(iChan,:))-1)/new_fs)*1000;
        % figure; plot(times(1:fs*5), signals(iChan,1:fs*5)); % plot 5 s of data
        % hold on; plot(times_res(1:new_fs*5), signals_res(iChan,1:new_fs*5));   
        
        % Lowest_freq = 1 / (length(signals(iChan,:))/1000)
        % highest_freq = new_fs / (2*nScales)
        % warning('Lowest frequency captured by MFE after downsampling = %g', )
        
        % Fuzzy entropy
        % EEG.nonlinear.FE(iChan,:) = compute_fe(signals_res(iChan,:), m, r, n, tau,useGPU);
        
        % Multiscale fuzzy entropy
        [eeg_features.nonlinear.MFE(iChan,:), eeg_features.nonlinear.MFE_scales(iChan,:)] = compute_mfe(signals_res(iChan,:), ...
            m, r, tau, coarseType, nScales, filtData, fs, n, useGPU);
        % figure; plot(EEG.nonlinear.MFE_scales(iChan,:),EEG.nonlinear.MFE(iChan,:));

    else
        % Fuzzy entropy
        % EEG.nonlinear.FE(iChan,:) = compute_fe(signals(iChan,:), m, r, n, tau,useGPU);
        
        % Multiscale fuzzy entropy
        [eeg_features.nonlinear.MFE(iChan,:), eeg_features.nonlinear(iChan,:).MFE_scales] = compute_mfe(signals(iChan,:), ...
            m, r, tau, coarseType, nScales, filtData, fs, n, useGPU);
        
    end
    
    % Individual alpha frequency (IAF) (Caution: do not use normalized power)
    % iaf = detect_iaf(pwr(iChan,:), freqs, winSize, params)
    
end

% IAF
[pSum, pChans, f] = restingIAF(signals, size(signals,1), 3, [1 30], fs, [7 13], 11, 5);
eeg_features.frequency.IAF_mean = pSum.cog;
eeg_features.frequency.IAF = [pChans.gravs];

% Asymmetry (use log(pwr) no pwr_dB)



% EEG coherence





