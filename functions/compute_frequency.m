function frequency = compute_frequency(NN,NN_times,params)

nfft = 1024;
% nfft = fs*4; % take 4 s
fvec = 1/nfft:1/nfft:.401;

% nWind = length(t_idx)-1; % # of windows

% HRV frequency bands
bands = [ [0 .003]; [0.003 .04]; [.04 .15]; [0.15 0.40] ];  % ULF; VLF; LF; HF

% Check required data length for each band. 5-10 cycles are recommended
% by the Task Force of the European Society of Cardiology and the North
% American Society of Pacing and Electrophysiology, 1996.
% fRes = fs/NN_times(end);  % frequency resolution
% minULF = 1 / (2 * (1 / fRes)) * 0.003;
minULF = 5/0.003; % 5 cycles/0.003 hz (in s)
if NN_times(end) < minULF
    warning('File length is too short for estimating ULF. At least %g minutes are required. This choice was disabled.', NN_times(end)/60)
end
minVLF = [minULF 5/0.04];  % 5 cycles/0.04 hz  (in s)
minLF = [minVLF(2) 5/0.15];  % 5 cycles/0.15 hz  (in s)
minHF = [minLF(2) 5/0.4];  % 5 cycles/0.15 hz  (in s)

% for iWin = 1:nWind
% idx = find(NN_times >= t_idx(1) & NN_times < t_idx(2));

% Lomb-Scargle Periodogram
if params.hrv_norm
    [pwr,freqs] = plomb(NN,NN_times,fvec,'normalized');
    fprintf('Computing Lomb-Scargle periodogram (normalized) on NN series. \n')
else
    [pwr,freqs] = plomb(NN,NN_times,fvec); % 'psd' be default
    fprintf('Computing Lomb-Scargle periodogram (PSD) on NN series. \n')
end

% frequency indexes
ulf_idx = bands(1,1) <= freqs & freqs <= bands(1,2);
vlf_idx = bands(2,1) <= freqs & freqs <= bands(2,2);
lf_idx = bands(3,1) <= freqs & freqs <= bands(3,2);
hf_idx = bands(4,1) <= freqs & freqs <= bands(4,2);

% Power for each band in mv^2
space = freqs(2)-freqs(1);
ulf = sum(pwr(ulf_idx)*space) * 1e6;    % ULF in ms^2
vlf = sum(pwr(vlf_idx)*space) * 1e6;    % VLF in ms^2
lf = sum(pwr(lf_idx)*space) * 1e6;      % LF in ms^2
hf = sum(pwr(hf_idx)*space) * 1e6;      % HF in ms^2
lfhf = round(lf/hf*100)/100;            % lf/hf ratio in ms^2
ttlpwr = sum([ulf vlf lf hf]);          % total power in ms^2

% Normalized
if params.hrv_norm
    ulf = ulf/ttlpwr;
    vlf = vlf/ttlpwr;
    lf = lf/ttlpwr;
    hf = hf/ttlpwr;
    lfhf = round(lf/hf *100)/100;
end

% Outputs for plotting
frequency.ulf_idx = ulf_idx;
frequency.vlf_idx = vlf_idx;
frequency.lf_idx = lf_idx;
frequency.hf_idx = hf_idx;
frequency.pwr = pwr;
frequency.pwr_freqs = freqs;
frequency.bands = bands;

% Export only features of interest FIXEME: only if data length allows
frequency.ulf = ulf;
frequency.vlf = vlf;
frequency.lf = lf;
frequency.hf = hf;
frequency.lfhf = lfhf;
frequency.total = ttlpwr;

% if vis
%     subplot(2,2,2+iWin); hold on;
%     x = find(ulf_idx); y = pwr(ulf_idx);
%     area(x,y,'FaceColor',[0.6350 0.0780 0.1840],'FaceAlpha',.7);
%     x = find(vlf_idx); y = pwr(vlf_idx);
%     area(x,y,'FaceColor',[0.8500 0.3250 0.0980],'FaceAlpha',.7)
%     x = find(lf_idx); y = pwr(lf_idx);
%     area(x,y,'FaceColor',[0.9290 0.6940 0.1250],'FaceAlpha',.7)
%     x = find(hf_idx); y = pwr(hf_idx);
%     area(x,y,'FaceColor',[0 0.4470 0.7410],'FaceAlpha',.7)
%     % xticks(1:8); xticklabels(reshape(fBounds,1,[]));
%     xticks(1:30:length(f)); xticklabels(f(1:30:end));
%     xlabel('Frequency (Hz)'); ylabel('Power (normalized)');
%     legend('ULF', 'VLF', 'LF', 'HF')
%     title(sprintf('Lomb-Scargle periodogram - Window %d', iWin))
% end

% end
