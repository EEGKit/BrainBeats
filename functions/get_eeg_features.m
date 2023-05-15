%% Extract EEG features in time, fequency, and nonlinear domains.

function eeg_features = get_eeg_features(signals,chanlocs,params)

disp('Extracting EEG features...')

fs = params.fs;
ps = parallel.Settings; ps.Pool.AutoCreate = params.parpool; % use parallel computing

% Use Multiple GPUs in Parallel Pool
if params.parpool && params.gpu
    availableGPUs = gpuDeviceCount("available");
    if availableGPUs > 1
        parpool('Processes',availableGPUs);
        fprintf('%g GPUs detected. Using them in parallel pool. \n',availableGPUs)
    else
        fprintf('Only one GPU detected. Using normal GPU and parallel pool computing. \n')
    end
end


%% Time domain
disp('Calculating time-domain EEG features...')
eeg_features.time.mean = mean(signals,2);
eeg_features.time.trimmed_mean = trimmean(signals,20,2);
eeg_features.time.median = median(signals,2);
eeg_features.time.mode = mode(signals,2);
eeg_features.time.var = var(signals,0,2);
eeg_features.time.skewness = skewness(signals,0,2);
eeg_features.time.kurtosis = kurtosis(signals,0,2);
eeg_features.time.iqr = iqr(signals,2);

%% Frequency domain

nChan = size(signals,1);
fRange = [1 45];    % FIXME: lowpass/highpass should be in params to make sure these are within filtered signal
winSize = 2;        % window size (in s). Default = 2 (at least 2 s recommended by Smith et al, 2017 for asymmetry)
winType = 'hamming';
overlap = 50;       % 50% default (Smith et al. 2017)

% Initiate progressbar (only when not in parpool)
if ~params.parpool
    progressbar('Extracting EEG features on EEG channels')
end

disp('Calculating band-power on each EEG channel')
for iChan = 1:nChan

    fprintf('EEG channel %g \n', iChan)

    % Compute PSD using pwelch
    [pwr, pwr_dB, freqs] = compute_psd(signals(iChan,:),fs*winSize,winType,overlap,[],fs,fRange,'psd', false);
    eeg_features.frequency.pwr(iChan,:) = pwr;
    eeg_features.frequency.pwr_dB(iChan,:) = pwr_dB;
    eeg_features.frequency.freqs(iChan,:) = freqs;

    % Delta
    eeg_features.frequency.delta(iChan,:) = pwr_dB(freqs >= fRange(1) & freqs <= 3);

    % Theta
    eeg_features.frequency.theta(iChan,:) = pwr_dB(freqs >= 3 & freqs <= 7);

    % Alpha
    eeg_features.frequency.alpha(iChan,:) = pwr_dB(freqs >= 7.5 & freqs <= 13);

    % Beta
    eeg_features.frequency.beta(iChan,:) = pwr_dB(freqs >= 13.5 & freqs <= 30);

    % Low gamma
    eeg_features.frequency.low_gamma(iChan,:) = pwr_dB(freqs >= 31 & freqs <= fRange(2));

    % Individual alpha frequency (IAF) (my code, not working)
    % iaf = detect_iaf(pwr(iChan,:), freqs, winSize, params)

    if ~params.parpool
        progressbar(iChan/nChan)
    end

end

% IAF (only export CoG)
disp('Detecting individual alpha frequency (IAF) for each EEG channel...')
[pSum, pChans, f] = restingIAF(signals, size(signals,1), 3, [1 30], fs, [7 13], 11, 5);
eeg_features.frequency.IAF_mean = pSum.cog;
eeg_features.frequency.IAF = [pChans.gravs];


% Asymmetry (use log(pwr) no pwr_dB) - on all pairs
disp('Calculating (z-normalized) EEG asymmetry for each electrode pair...')
nPairs = size(chanlocs,2)/2+1;
pairs = nan(nPairs,2);
pairLabels = cell(nPairs,1);
for iPair = 1:nPairs

    % find pairs using X distance
    for iChan2 = 1:size(chanlocs,2)
        if iChan2 == iPair
            distX(iChan2,:) = NaN;
        else
            distX(iChan2,:) = diff([chanlocs(iPair).X chanlocs(iChan2).X ]);
        end
    end
    [~, match] = min(abs(distX));
    pairs(iPair,:) = [iPair match];
    pairLabels(iPair,:) = { sprintf('%s %s', chanlocs(iPair).labels, chanlocs(match).labels) };
    
    % flip if order is not left - left
    if rem(str2double(pairLabels{iPair}(end)),2) ~= 0 % second elec should be even number
        pairs(iPair,:) = [match iPair];
        pairLabels(iPair,:) = { sprintf('%s %s', chanlocs(match).labels, chanlocs(iPair).labels) };
    end

    % Z-normalize by correcting for overall alpha power (see Allen et al. 2004 and Smith et al. 2017)
    alpha_left = mean(eeg_features.frequency.alpha(pairs(iPair,1),:));
    alpha_right = mean(eeg_features.frequency.alpha(pairs(iPair,2),:));
    alpha_left = alpha_left / sum(mean(eeg_features.frequency.alpha,2));
    alpha_right = alpha_right / sum(mean(eeg_features.frequency.alpha,2));

    % compute asymmetry and export
    % asy(iPair,:) = log(alpha_left) - log(alpha_right);
    eeg_features.frequency.asymmetry(iPair,:) = log(alpha_left) - log(alpha_right);
    eeg_features.frequency.asymmetry_pairs(iPair,:) = pairLabels;

end

%% EEG coherence (only pairs with medium-long distance; see Nunez 2016)
% elec neighbors
vis = false;
neighbors = get_channelneighbors(chanlocs,vis);

% all possible pairs
pairs = nchoosek({chanlocs.labels}, 2);

% remove pairs that are neighbors
for iPair = 1:size(pairs,1)
    
    chan1 = pairs{iPair,1};
    chan2 = pairs{iPair,2};
    
    % If chan2 is neighbor, skip to next pair, otherwise compute coherence
    chan1_neighbors = neighbors(strcmp({neighbors.label},chan1)).neighblabel;
    if sum(contains(chan1_neighbors, chan2)) == 0
        idx1 = strcmp({chanlocs.labels},chan1);
        idx2 = strcmp({chanlocs.labels},chan2);
        [cohr,f] = mscohere(signals(idx1,:),signals(idx2,:),hamming(fs*2),fs,[],fs);
        plot(f(f>=0 & f<30), squeeze(cohr(f>=0 & f<30))); grid on; hold on;
        eeg_features.frequency.eeg_coherence(iPair,:) = cohr;
        eeg_features.frequency.eeg_coherence(iPair,:) = cohr;
    else
        continue
    end

end

%% Entropy

% default parameters
m = 2;
r = .15;
n = 2;
tau = 1;
coarseType = 'Standard deviation';
nScales = 20;
filtData = true;

% Initiate progressbar (only when not in parpool)
if ~params.parpool
    progressbar('Extracting EEG features on EEG channels')
end

disp('Calculating nonlinear-domain EEG features...')
for iChan = 1:nChan

    % Entropy
    if size(signals,2) > 5000 % Downsample to accelerate on data with more than 5,000 samples
        new_fs = 90;  % for Nyquist freq = lowpass cutoff (i.e. 45 Hz)
        fac = fs / new_fs; % downsample factor

        % downsample if integer, otherwise decimate to round factor
        if fac ~= floor(fac)
            fac = round(fac);
            signals_res = decimate(signals(iChan,:), fac);
            fprintf('Decimating EEG data to %g Hz sample rate to compute entropy on these large datasets. \n',new_fs)
        else
            signals_res = resample(signals(iChan,:), 1, fac);
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
        % fe = compute_fe(signals_res, m, r, n, tau, params.gpu);

        % Multiscale fuzzy entropy
        % [mfe, scales, scale_bounds] = compute_mfe(signals_res, m, r, tau, coarseType, nScales, filtData, new_fs, n, params.gpu);
        % plot(scales(end:-1:1),mfe(end:-1:1));  hold on; 
        % title('downsampled'); axis tight; box on; grid on
        % xticks(scales); xticklabels(scale_bounds(end:-1:1)); xtickangle(45)

    else

        % Fuzzy entropy
        disp('Computing fuzzy entropy...')
        % fe = compute_fe(signals(iChan,:), m, r, n, tau, params.gpu);
    
        % Multiscale fuzzy entropy
        disp('Computing multiscale fuzzy entropy...')
        % [mfe, scales, scale_bounds] = compute_mfe(signals(iChan,:), m, r, tau, coarseType, nScales, filtData, fs, n, params.gpu);
        % plot(scales(end:-1:1),mfe(end:-1:1)); hold on; axis tight; box on; grid on
        % xticks(scales); xticklabels(scale_bounds(end:-1:1)); xtickangle(45)

    end
    
    % Outputs
    % eeg_features.nonlinear.MFE_scales(iChan,:) = scales;
    % eeg_features.nonlinear.MFE_scale_bounds(iChan,:) = scale_bounds;
    % eeg_features.nonlinear.MFE(iChan,:) = mfe;
    % eeg_features.nonlinear.MFE_mean(iChan,:) = mean(mfe);
    % eeg_features.nonlinear.MFE_sd(iChan,:) = std(mfe);
    % eeg_features.nonlinear.MFE_var(iChan,:) = var(mfe);
    % eeg_features.nonlinear.MFE_area(iChan,:) = trapz(mfe);
    % [~,eeg_features.nonlinear.MFE_peak(iChan,:)] = max(mfe);


end


% Shut down parallel pool
% if params.parpool
%     delete(gcp('nocreate'));
% end
