<!-- <p align="center"> -->
# BrainBeats (Beta)
<!-- </p> -->

<p align="center" width="100%">
    <img width="50%" src="https://github.com/amisepa/BrainBeats/blob/v1.4/brainbeats_logo.png">
</p>

The BrainBeats toolbox, implemented as an EEGLAB plugin, allows joint processing and analysis of EEG and cardiovascular signals (ECG/PPG). Both the general user interface (GUI) and command line are supported (see tutorial). 

## 3 METHODS AVAILABLE

1) Process EEG data for heartbeat-evoked potentials (HEP) analysis using ECG or PPG signals. Steps include signal processing of EEG and cardiovascular signals, inserting R-peak markers into the EEG data, segmentation around the R-peaks with optimal window length, time-frequency decomposition.

Example of HEP at the subject level, obtained from simultaneous EEG-ECG signals:
<p width="100%">
    <img width="50%" src="https://github.com/amisepa/BrainBeats/blob/v1.4/figures/fig1.11.png"> 
</p>

Example of HEP at the subject level, obtained from simultaneous EEG-PPG signals:
<p width="100%">
    <img width="50%" src="https://github.com/amisepa/BrainBeats/blob/v1.4/figures/fig1.17.png">
</p>

2) Extract EEG and HRV features from continuous data in the time, frequency, and nonlinear domains. 
    - HRV time domain: SDNN, RMSSD, pNN50.
    - HRV frequency domain: VLF-power, ULF-power, LF-power, HF-power, LF:HF ratio, Total power. 
    - HRV nonlinear domain: Poincare, fuzzy entropy, fractal dimension, PRSA. 
    
    - EEG frequency domain: average band power (delta, theta, alpha, beta, gamma), individual alpha frequency (IAF), alpha asymmetry.
    - EEG nonlinear domain: fuzzy entropy, fractal dimension

Example of power spectral density (PSD) estimated from HRV and EEG data:
<p width="100%">
    <img width="50%" src="https://github.com/amisepa/BrainBeats/blob/v1.4/figures/fig2.4.png"> 
</p>

Example of EEG features extracted from sample dataset.
<p width="100%">
    <img width="50%" src="https://github.com/amisepa/BrainBeats/blob/v1.4/figures/fig2.5.png"> 
</p>

3) Remove heart components from EEG signals using ICA and ICLabel.
   
Example of extraction of cardiovascular components from EEG signals
<p width="100%">
    <img width="50%" src="https://github.com/amisepa/BrainBeats/blob/v1.4/figures/fig3.3.png"> 
</p>

## Tutorial

A sample dataset is provided and located in the "sample_data" folder. 

See the JoVE preprint for a step-by-step tutorial using the sample dataset: https://www.biorxiv.org/content/10.1101/2023.06.01.543272v1.full.pdf


