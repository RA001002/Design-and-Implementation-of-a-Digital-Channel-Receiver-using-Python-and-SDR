clc;
clear;
close all;

%% ===============================
% Pluto SDR Configuration
%% ===============================
centerFreq = 0.7e9;       % Center Frequency
sampleRate = 10e6;         % Sampling Rate
frameLength = 2^14;
gain = 40;

rx = sdrrx('Pluto', ...
    'CenterFrequency', centerFreq, ...
    'BasebandSampleRate', sampleRate, ...
    'SamplesPerFrame', frameLength, ...
    'GainSource', 'Manual', ...
    'Gain', gain, ...
    'OutputDataType', 'double');   

%% ===============================
% Parameters for Channel Detection
%% ===============================
N = frameLength;
freqAxis = linspace(-sampleRate/2, sampleRate/2, N);

channelBW = 1e6;     % 1 MHz channel
threshold = -80;     % dB threshold

%% ===============================
% Visualization Setup
%% ===============================
figure;
disp('Smart Spectrum Receiver Running...');

while true
    
    %% Step 1: Receive Signal
    rxSignal = rx();   % already double
    
    %% Step 2: FFT Spectrum
    fftSignal = fftshift(fft(rxSignal));
    powerSpec = 20*log10(abs(fftSignal) + 1e-6);
    
    %% Step 3: Peak Detection
    [pks, locs] = findpeaks(powerSpec, 'MinPeakHeight', threshold);
    
    if ~isempty(pks)
        
        % Strongest peak
        [~, idx] = max(pks);
        peakLoc = locs(idx);
        peakFreq = freqAxis(peakLoc);
        
        fprintf('Strongest Channel at: %.2f MHz\n', peakFreq/1e6);
        
        %% Step 4: Frequency Shift to Baseband
        t = (0:N-1)'/sampleRate;
        shiftedSignal = rxSignal .* exp(-1j*2*pi*peakFreq*t);
        
        %% Step 5: Lowpass Filter (Channel Extraction)
        lpFilt = designfilt('lowpassfir', ...
            'FilterOrder', 100, ...
            'CutoffFrequency', channelBW/2, ...
            'SampleRate', sampleRate);
        
        extractedSignal = filter(lpFilt, shiftedSignal);
        
    else
        peakFreq = 0;
        extractedSignal = rxSignal;
    end
    
    %% Step 6: Plot Full Spectrum
    subplot(2,1,1);
    plot(freqAxis/1e6, powerSpec);
    title('Full Spectrum');
    xlabel('Frequency (MHz)');
    ylabel('Power (dB)');
    grid on;
    
    hold on;
    if peakFreq ~= 0
        plot(peakFreq/1e6, max(powerSpec), 'ro', 'LineWidth', 2);
    end
    hold off;
    
    %% Step 7: Extracted Channel Spectrum
    fftExtracted = fftshift(fft(extractedSignal));
    powerExtracted = 20*log10(abs(fftExtracted) + 1e-6);
    
    subplot(2,1,2);
    plot(freqAxis/1e6, powerExtracted);
    title('Extracted Strongest Channel (Basebanded)');
    xlabel('Frequency (MHz)');
    ylabel('Power (dB)');
    grid on;
    
    drawnow;
    
end
