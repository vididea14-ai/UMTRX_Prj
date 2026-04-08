%% ============================================================
%  WLAN AUDIO STREAMING GUI - ENHANCED VERSION
%  - Full GUI interface with all configuration options
%  - Reed-Solomon (RS) encoding option alongside BCC
%  - IMPROVED RELIABILITY for last packets:
%    * Extra tail packets with redundant data
%    * Longer transmission window for final packets
%    * CRC validation per packet
%    * Configurable end-of-stream markers
%  - Automatic USB port detection
%  - Real-time statistics and visualization
%  - NEW: Camera snapshot capture and transmission
%  - NEW: Live PER and BER display before/after FEC
% ============================================================

function wlan_audio_streaming_gui()
    % Create main figure
    fig = uifigure('Name', 'HCLoS File Streaming - Enhanced', ...
        'Position', [100 100 1000 800], ...
        'Resize', 'off');
    
    % Initialize file type constants
    defineFileTypeConstants();
    
    % Create tab group
    tabGroup = uitabgroup(fig, 'Position', [10 60 980 730]);
    
    % Create tabs
    configTab = uitab(tabGroup, 'Title', 'Configuration');
    txTab = uitab(tabGroup, 'Title', 'Transmitter');
    rxTab = uitab(tabGroup, 'Title', 'Receiver');
    statsTab = uitab(tabGroup, 'Title', 'Statistics');
    cameraTab = uitab(tabGroup, 'Title', 'Camera');
    
    % Store app data
    appData = struct();
    appData.isRunning = false;
    appData.totalPackets = 0;
    appData.receivedPackets = 0;
    appData.missingPackets = [];
    appData.berBeforeFEC = 0;
    appData.berAfterFEC = 0;
    appData.perBeforeFEC = 0;
    appData.perAfterFEC = 0;
    appData.cameraObj = [];
    
    %% =============== CONFIGURATION TAB CREATION ===============
    createConfigTab(configTab, fig, appData);
    
    %% =============== TX TAB CREATION ===============
    createTxTab(txTab, fig, appData);
    
    %% =============== RX TAB CREATION ===============
    createRxTab(rxTab, fig, appData);
    
    %% =============== STATS TAB CREATION ===============
    createStatsTab(statsTab, fig, appData);
    
    %% =============== CAMERA TAB CREATION ===============
    createCameraTab(cameraTab, fig, appData);
    
    %% =============== BOTTOM STATUS BAR ===============
    uilabel(fig, 'Position', [10 10 200 30], ...
        'Text', 'Status: Ready', 'Tag', 'statusLabel');
    
    uibutton(fig, 'Position', [700 10 90 35], ...
        'Text', 'Detect SDRs', ...
        'ButtonPushedFcn', @(~,~) detectSDRs(fig));
    
    uibutton(fig, 'Position', [800 10 90 35], ...
        'Text', 'Help', ...
        'ButtonPushedFcn', @(~,~) showHelp());
    
    % Store figure data
    guidata(fig, appData);
end

%% =============== FILE TYPE CONSTANTS ===============
function defineFileTypeConstants()
    % File type codes for packet identification
    global FILE_TYPE_AUDIO FILE_TYPE_PDF FILE_TYPE_DOCX FILE_TYPE_TXT ...
           FILE_TYPE_VIDEO FILE_TYPE_IMAGE FILE_TYPE_XLSX FILE_TYPE_PPTX FILE_TYPE_BINARY;
    
    FILE_TYPE_AUDIO = uint8(1);
    FILE_TYPE_PDF = uint8(2);
    FILE_TYPE_DOCX = uint8(3);
    FILE_TYPE_TXT = uint8(4);
    FILE_TYPE_VIDEO = uint8(5);
    FILE_TYPE_IMAGE = uint8(6);
    FILE_TYPE_XLSX = uint8(7);
    FILE_TYPE_PPTX = uint8(8);
    FILE_TYPE_BINARY = uint8(255);
end

%% =============== CONFIGURATION TAB CREATION ===============
function createConfigTab(tab, fig, appData)
    % RF Configuration Panel
    rfPanel = uipanel(tab, 'Title', 'RF Configuration', ...
        'Position', [10 480 460 180]);
    
    uilabel(rfPanel, 'Position', [10 130 120 22], 'Text', 'Center Freq (MHz):');
    uieditfield(rfPanel, 'numeric', 'Position', [140 130 100 22], ...
        'Value', 3000, 'Tag', 'centerFreq', 'Limits', [70 6000]);
    
    uilabel(rfPanel, 'Position', [10 100 120 22], 'Text', 'Sample Rate (MHz):');
    uieditfield(rfPanel, 'numeric', 'Position', [140 100 100 22], ...
        'Value', 20, 'Tag', 'sampleRate', 'Limits', [1 61.44]);
    
    uilabel(rfPanel, 'Position', [10 70 120 22], 'Text', 'Channel Bandwidth:');
    uidropdown(rfPanel, 'Position', [140 70 100 22], ...
        'Items', {'CBW20', 'CBW40'}, 'Value', 'CBW20', 'Tag', 'channelBW');
    
    uilabel(rfPanel, 'Position', [250 130 50 22], 'Text', 'MCS:');
    uidropdown(rfPanel, 'Position', [300 130 150 22], ...
        'Items', {'0: BPSK 1/2 (6.5 Mbps)', '1: BPSK 3/4 (9.75 Mbps)', ...
                  '2: QPSK 1/2 (13 Mbps)', '3: QPSK 3/4 (19.5 Mbps)', ...
                  '4: 16QAM 1/2 (26 Mbps)', '5: 16QAM 3/4 (39 Mbps)', ...
                  '6: 64QAM 2/3 (52 Mbps)', '7: 64QAM 3/4 (58.5 Mbps)'}, ...
        'Value', '3: QPSK 3/4 (19.5 Mbps)', 'Tag', 'mcsSelect');
    
    % SDR Selection Panel
    sdrPanel = uipanel(tab, 'Title', 'SDR Selection', ...
        'Position', [480 480 460 180]);
    
    uilabel(sdrPanel, 'Position', [10 130 100 22], 'Text', 'TX Radio ID:');
    uidropdown(sdrPanel, 'Position', [120 130 150 22], ...
        'Items', {'usb:0', 'usb:1', 'usb:2', 'usb:3'}, ...
        'Value', 'usb:0', 'Tag', 'txRadioID');
    
    uilabel(sdrPanel, 'Position', [10 100 100 22], 'Text', 'RX Radio ID:');
    uidropdown(sdrPanel, 'Position', [120 100 150 22], ...
        'Items', {'usb:0', 'usb:1', 'usb:2', 'usb:3'}, ...
        'Value', 'usb:0', 'Tag', 'rxRadioID');
    
    uibutton(sdrPanel, 'Position', [290 115 110 30], ...
        'Text', 'Auto Detect', ...
        'ButtonPushedFcn', @(~,~) detectSDRs(fig));
    
    uilabel(sdrPanel, 'Position', [10 60 350 30], ...
        'Text', 'Detected SDRs: None', 'Tag', 'detectedSDRs');
    
    % File Configuration Panel
    filePanel = uipanel(tab, 'Title', 'File Configuration', ...
        'Position', [10 280 460 190]);
    
    uilabel(filePanel, 'Position', [10 140 100 22], 'Text', 'Input File:');
    uieditfield(filePanel, 'text', 'Position', [110 140 200 22], ...
        'Value', '', 'Tag', 'inputFile');
    uibutton(filePanel, 'Position', [320 138 60 26], 'Text', 'Browse', ...
        'ButtonPushedFcn', @(~,~) browseInputFile(fig));
    
    uibutton(filePanel, 'Position', [390 138 60 26], 'Text', 'Snapshot', ...
        'BackgroundColor', [0.4 0.6 0.9], ...
        'ButtonPushedFcn', @(~,~) captureSnapshot(fig));
    
    uilabel(filePanel, 'Position', [10 110 100 22], 'Text', 'File Type:');
    uidropdown(filePanel, 'Position', [110 110 150 22], ...
        'Items', {'Auto Detect', 'Audio', 'Video', 'Document', 'Image', 'Binary'}, ...
        'Value', 'Auto Detect', 'Tag', 'fileTypeSelect');
    
    uilabel(filePanel, 'Position', [10 80 100 22], 'Text', 'Detected Type:');
    uilabel(filePanel, 'Position', [110 80 200 22], ...
        'Text', 'None', 'Tag', 'detectedFileType', 'FontWeight', 'bold');
    
    uilabel(filePanel, 'Position', [10 50 100 22], 'Text', 'File Size:');
    uilabel(filePanel, 'Position', [110 50 200 22], ...
        'Text', '0 bytes', 'Tag', 'fileSize');
    
    % Audio-specific options (shown only for audio files) - IMPROVED DEFAULTS
    audioOptionsPanel = uipanel(filePanel, 'Title', 'Audio Options', ...
        'Position', [270 10 180 120], 'Tag', 'audioOptionsPanel');
    
    uilabel(audioOptionsPanel, 'Position', [5 70 80 22], 'Text', 'Target Fs:');
    uieditfield(audioOptionsPanel, 'numeric', 'Position', [85 70 45 22], ...
        'Value', 44100, 'Tag', 'targetFs', 'Limits', [8000 48000]);
    
    uicheckbox(audioOptionsPanel, 'Position', [5 45 120 22], ...
        'Value', false, 'Text', 'Compress Audio', 'Tag', 'useCompression');
    
    uilabel(audioOptionsPanel, 'Position', [5 20 50 22], 'Text', 'Quality:');
    uislider(audioOptionsPanel, 'Position', [55 28 70 3], ...
        'Limits', [1 10], 'Value', 10, 'Tag', 'compQuality');
    
    % FEC Configuration Panel
    fecPanel = uipanel(tab, 'Title', 'Forward Error Correction (FEC)', ...
        'Position', [480 280 460 190]);
    
    uilabel(fecPanel, 'Position', [10 140 100 22], 'Text', 'FEC Mode:');
    uidropdown(fecPanel, 'Position', [110 140 150 22], ...
        'Items', {'BCC Only', 'RS + BCC', 'RS Only (Experimental)'}, ...
        'Value', 'BCC Only', 'Tag', 'fecMode', ...
        'ValueChangedFcn', @(src,~) updateFECOptions(fig, src.Value));
    
    uilabel(fecPanel, 'Position', [10 110 100 22], 'Text', 'RS Code Rate:');
    uidropdown(fecPanel, 'Position', [110 110 150 22], ...
        'Items', {'RS(255,239) - 6.7%', 'RS(255,223) - 12.5%', ...
                  'RS(255,191) - 25%', 'RS(255,127) - 50%'}, ...
        'Value', 'RS(255,223) - 12.5%', 'Tag', 'rsCodeRate', 'Enable', 'off');
    
    uilabel(fecPanel, 'Position', [10 80 100 22], 'Text', 'Interleaving:');
    uicheckbox(fecPanel, 'Position', [110 80 80 22], ...
        'Value', true, 'Text', 'Enable', 'Tag', 'useInterleaving', 'Enable', 'off');
    
    uilabel(fecPanel, 'Position', [10 50 400 22], ...
        'Text', 'RS encoding adds redundancy for burst error correction');
    
    % Reliability Panel
    reliabilityPanel = uipanel(tab, 'Title', 'Reliability Enhancements', ...
        'Position', [10 80 460 190]);
    
    uilabel(reliabilityPanel, 'Position', [10 140 150 22], 'Text', 'Tail Packet Repeats:');
    uieditfield(reliabilityPanel, 'numeric', 'Position', [160 140 60 22], ...
        'Value', 0, 'Tag', 'tailRepeats', 'Limits', [0 20], ...
        'Tooltip', 'Extra repeats for last N packets');
    
    uilabel(reliabilityPanel, 'Position', [230 140 100 22], 'Text', 'Tail Count:');
    uieditfield(reliabilityPanel, 'numeric', 'Position', [330 140 60 22], ...
        'Value', 0, 'Tag', 'tailCount', 'Limits', [0 50], ...
        'Tooltip', 'Number of packets at end to repeat');
    
    uilabel(reliabilityPanel, 'Position', [10 110 150 22], 'Text', 'End-of-Stream Markers:');
    uieditfield(reliabilityPanel, 'numeric', 'Position', [160 110 60 22], ...
        'Value', 1, 'Tag', 'eosMarkers', 'Limits', [0 20], ...
        'Tooltip', 'Special EOS packets to signal end');
    
    uilabel(reliabilityPanel, 'Position', [10 80 150 22], 'Text', 'Final Packet Delay (s):');
    uieditfield(reliabilityPanel, 'numeric', 'Position', [160 80 60 22], ...
        'Value', 0.02, 'Tag', 'finalDelay', 'Limits', [0.0 2.0], ...
        'Tooltip', 'Extra delay for final packets');
    
    uicheckbox(reliabilityPanel, 'Position', [10 50 180 22], ...
        'Value', false, 'Text', 'Verify Last Packets (TX)', 'Tag', 'verifyLastPkts');
    
    uicheckbox(reliabilityPanel, 'Position', [200 50 180 22], ...
        'Value', false, 'Text', 'Extended RX Wait', 'Tag', 'extendedWait');
    
    % Timing Panel
    timingPanel = uipanel(tab, 'Title', 'Transmission Timing', ...
        'Position', [480 80 460 190]);
    
    uilabel(timingPanel, 'Position', [10 140 140 22], 'Text', 'TX Time/Packet (s):');
    uieditfield(timingPanel, 'numeric', 'Position', [160 140 80 22], ...
        'Value', 0.02, 'Tag', 'txTime', 'Limits', [0.0 2.0]);
    
    uilabel(timingPanel, 'Position', [10 110 140 22], 'Text', 'Inter-Packet Gap (s):');
    uieditfield(timingPanel, 'numeric', 'Position', [160 110 80 22], ...
        'Value', 0.02, 'Tag', 'txGap', 'Limits', [0 1.0]);
    
    uilabel(timingPanel, 'Position', [10 80 140 22], 'Text', 'Full Repeats:');
    uieditfield(timingPanel, 'numeric', 'Position', [160 80 80 22], ...
        'Value', 3, 'Tag', 'txRepeats', 'Limits', [1 10]);
    
    uilabel(timingPanel, 'Position', [10 50 140 22], 'Text', 'Sync Packets:');
    uieditfield(timingPanel, 'numeric', 'Position', [160 50 80 22], ...
        'Value', 5, 'Tag', 'syncPackets', 'Limits', [0 20]);
    
    uilabel(timingPanel, 'Position', [250 140 100 22], 'Text', 'Sync Interval (s):');
    uieditfield(timingPanel, 'numeric', 'Position', [350 140 60 22], ...
        'Value', 0.05, 'Tag', 'syncInterval', 'Limits', [0 1.0]);
end

%% =============== TX TAB CREATION ===============
function createTxTab(tab, fig, appData)
    % TX Control Panel
    controlPanel = uipanel(tab, 'Title', 'Transmitter Control', ...
        'Position', [10 500 960 150]);
    
    uibutton(controlPanel, 'Position', [20 80 120 50], ...
        'Text', 'START TX', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3 0.8 0.3], ...
        'Tag', 'startTxBtn', ...
        'ButtonPushedFcn', @(~,~) startTransmission(fig));
    
    uibutton(controlPanel, 'Position', [160 80 120 50], ...
        'Text', 'STOP TX', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.3 0.3], ...
        'Tag', 'stopTxBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) stopTransmission(fig));
    
    uibutton(controlPanel, 'Position', [20 20 100 40], ...
        'Text', 'Clear Log', 'FontSize', 12, ...
        'ButtonPushedFcn', @(~,~) clearTxLog(fig));
    
    % Status display
    uilabel(controlPanel, 'Position', [320 90 100 22], 'Text', 'TX Status:');
    uilabel(controlPanel, 'Position', [420 90 400 22], ...
        'Text', 'Idle', 'Tag', 'txStatus', 'FontWeight', 'bold');
    
    uilabel(controlPanel, 'Position', [320 60 100 22], 'Text', 'Progress:');
    % Progress bar background (gray)
    uipanel(controlPanel, 'Position', [420 60 400 20], ...
        'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'line', 'Tag', 'txProgressBg');
    % Progress bar fill (green) - width will be updated dynamically
    uipanel(controlPanel, 'Position', [420 60 1 20], ...
        'BackgroundColor', [0.3 0.7 0.3], 'BorderType', 'none', 'Tag', 'txProgress');
    % Progress percentage label
    uilabel(controlPanel, 'Position', [830 60 50 20], ...
        'Text', '0%', 'Tag', 'txProgressLabel');
    
    uilabel(controlPanel, 'Position', [320 25 100 22], 'Text', 'Packets:');
    uilabel(controlPanel, 'Position', [420 25 200 22], ...
        'Text', '0/0', 'Tag', 'txPacketCount');

    uilabel(controlPanel, 'Position', [560 25 100 22], 'Text', 'PAPR (dB):');
    uilabel(controlPanel, 'Position', [660 25 100 22], ...
    'Text', '0.00', 'Tag', 'txPAPR', 'FontWeight', 'bold', 'FontColor', [0.8 0.4 0]);

    uilabel(controlPanel, 'Position', [760 25 80 22], 'Text', 'Avg PAPR:');
    uilabel(controlPanel, 'Position', [840 25 80 22], ...
    'Text', '0.00 dB', 'Tag', 'txAvgPAPR', 'FontWeight', 'bold');
    
    % TX Log Panel
    logPanel = uipanel(tab, 'Title', 'Transmission Log', ...
        'Position', [10 10 960 480]);
    
    uitextarea(logPanel, 'Position', [10 10 940 440], ...
        'Editable', 'off', 'Tag', 'txLog', ...
        'Value', {'[TX] Ready for transmission...'});
end

%% =============== RX TAB CREATION ===============
function createRxTab(rxTab, fig, appData)
    % RX Control Panel
    controlPanel = uipanel(rxTab, 'Title', 'Receiver Control', ...
        'Position', [10 500 960 150]);
    
    uibutton(controlPanel, 'Position', [20 80 120 50], ...
        'Text', 'START RX', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3 0.8 0.3], ...
        'Tag', 'startRxBtn', ...
        'ButtonPushedFcn', @(~,~) startReception(fig));
    
    uibutton(controlPanel, 'Position', [160 80 120 50], ...
        'Text', 'STOP RX', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.3 0.3], ...
        'Tag', 'stopRxBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) stopReception(fig));
    
    uibutton(controlPanel, 'Position', [20 20 120 40], ...
        'Text', 'Play Audio', 'Tag', 'playAudioBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) playReceivedAudio(fig));
    
    uibutton(controlPanel, 'Position', [150 20 120 40], ...
        'Text', 'Save Audio', 'Tag', 'saveAudioBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) saveReceivedAudio(fig));
    
    uibutton(controlPanel, 'Position', [280 20 120 40], ...
        'Text', 'Open File', 'Tag', 'openFileBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) openReceivedFile(fig));
    
    uibutton(controlPanel, 'Position', [410 20 100 40], ...
        'Text', 'Clear Log', 'FontSize', 12, ...
        'ButtonPushedFcn', @(~,~) clearRxLog(fig));
    
    % Status display
    uilabel(controlPanel, 'Position', [540 90 100 22], 'Text', 'RX Status:');
    uilabel(controlPanel, 'Position', [640 90 200 22], ...
        'Text', 'Idle', 'Tag', 'rxStatus', 'FontWeight', 'bold');
    
    % Progress bar background (gray)
    uilabel(controlPanel, 'Position', [540 60 100 22], 'Text', 'Progress:');
    uipanel(controlPanel, 'Position', [640 60 200 20], ...
        'BackgroundColor', [0.9 0.9 0.9], 'BorderType', 'line', 'Tag', 'rxProgressBg');
    % Progress bar fill (blue)
    uipanel(controlPanel, 'Position', [640 60 1 20], ...
        'BackgroundColor', [0.3 0.5 0.8], 'BorderType', 'none', 'Tag', 'rxProgress');
    % Progress percentage label
    uilabel(controlPanel, 'Position', [845 60 50 20], ...
        'Text', '0%', 'Tag', 'rxProgressLabel');
    
    uilabel(controlPanel, 'Position', [540 25 100 22], 'Text', 'Packets:');
    uilabel(controlPanel, 'Position', [640 25 200 22], ...
        'Text', '0/0', 'Tag', 'rxPacketCount');
    
    % RX Settings Panel
    settingsPanel = uipanel(rxTab, 'Title', 'RX Settings', ...
        'Position', [10 360 460 130]);
    
    uilabel(settingsPanel, 'Position', [10 80 120 22], 'Text', 'Samples/Frame:');
    uieditfield(settingsPanel, 'numeric', 'Position', [140 80 100 22], ...
        'Value', 70000, 'Tag', 'rxSamplesPerFrame', 'Limits', [10000 200000]);
    
    uilabel(settingsPanel, 'Position', [10 50 120 22], 'Text', 'Max Timeout (s):');
    uieditfield(settingsPanel, 'numeric', 'Position', [140 50 100 22], ...
        'Value', 180, 'Tag', 'rxTimeout', 'Limits', [10 600]);
    
    uilabel(settingsPanel, 'Position', [260 80 100 22], 'Text', 'RX Gain:');
    uieditfield(settingsPanel, 'numeric', 'Position', [360 80 50 22], ...
        'Value', 70, 'Tag', 'rxGain', 'Limits', [0 73]);
    
    % Early Exit Panel
    earlyExitPanel = uipanel(rxTab, 'Title', 'Early Exit Settings', ...
        'Position', [490 360 460 130]);
    
    uicheckbox(earlyExitPanel, 'Position', [10 80 150 22], ...
        'Value', true, 'Text', 'Enable Early Exit', 'Tag', 'earlyExitEnable');
    
    uilabel(earlyExitPanel, 'Position', [10 50 100 22], 'Text', 'Threshold (%):');
    uieditfield(earlyExitPanel, 'numeric', 'Position', [110 50 60 22], ...
        'Value', 60, 'Tag', 'earlyExitThreshold', 'Limits', [50 99]);
    
    uicheckbox(earlyExitPanel, 'Position', [200 80 150 22], ...
        'Value', true, 'Text', 'Intelligent Exit', 'Tag', 'intelligentExit');
    
    uilabel(earlyExitPanel, 'Position', [200 50 100 22], 'Text', 'Stale Time (s):');
    uieditfield(earlyExitPanel, 'numeric', 'Position', [300 50 60 22], ...
        'Value', 8, 'Tag', 'gapStaleTime', 'Limits', [3 30]);
    
    % RX Log Panel
    logPanel = uipanel(rxTab, 'Title', 'Reception Log', ...
        'Position', [10 10 960 340]);
    
    uitextarea(logPanel, 'Position', [10 10 940 300], ...
        'Editable', 'off', 'Tag', 'rxLog', ...
        'Value', {'[RX] Ready for reception...'});
end

%% =============== STATS TAB CREATION ===============
function createStatsTab(tab, fig, appData)
    % Statistics Panel
    statsPanel = uipanel(tab, 'Title', 'Session Statistics', ...
        'Position', [10 400 960 250]);
    
    % Create axes for packet reception chart
    ax = uiaxes(statsPanel, 'Position', [10 10 500 210]);
    ax.Title.String = 'Packet Reception Status';
    ax.XLabel.String = 'Packet Index';
    ax.YLabel.String = 'Status';
    ax.Tag = 'packetChart';
    
    % Stats display
    uilabel(statsPanel, 'Position', [530 190 150 22], 'Text', 'Total Packets:');
    uilabel(statsPanel, 'Position', [680 190 150 22], 'Text', '0', 'Tag', 'statTotalPkts');
    
    uilabel(statsPanel, 'Position', [530 160 150 22], 'Text', 'Received:');
    uilabel(statsPanel, 'Position', [680 160 150 22], 'Text', '0', 'Tag', 'statReceived');
    
    uilabel(statsPanel, 'Position', [530 130 150 22], 'Text', 'Missing:');
    uilabel(statsPanel, 'Position', [680 130 150 22], 'Text', '0', 'Tag', 'statMissing');
    
    uilabel(statsPanel, 'Position', [530 100 150 22], 'Text', 'Success Rate:');
    uilabel(statsPanel, 'Position', [680 100 150 22], 'Text', '0%', 'Tag', 'statSuccessRate');
    
    uilabel(statsPanel, 'Position', [530 70 150 22], 'Text', 'Total Decodes:');
    uilabel(statsPanel, 'Position', [680 70 150 22], 'Text', '0', 'Tag', 'statDecodes');
    
    uilabel(statsPanel, 'Position', [530 40 150 22], 'Text', 'Elapsed Time:');
    uilabel(statsPanel, 'Position', [680 40 150 22], 'Text', '0.0s', 'Tag', 'statElapsed');
    
    % Error Rate Panel
    errorPanel = uipanel(tab, 'Title', 'Error Rate Statistics', ...
        'Position', [10 250 960 140]);
    
    uilabel(errorPanel, 'Position', [10 100 180 22], 'Text', 'PER (Before FEC):');
    uilabel(errorPanel, 'Position', [200 100 120 22], ...
        'Text', '0%', 'Tag', 'perBeforeFEC', 'FontWeight', 'bold', 'FontColor', [0.8 0 0]);
    
    uilabel(errorPanel, 'Position', [10 70 180 22], 'Text', 'PER (After FEC):');
    uilabel(errorPanel, 'Position', [200 70 120 22], ...
        'Text', '0%', 'Tag', 'perAfterFEC', 'FontWeight', 'bold', 'FontColor', [0 0.6 0]);
    
    uilabel(errorPanel, 'Position', [10 40 180 22], 'Text', 'BER (Before FEC):');
    uilabel(errorPanel, 'Position', [200 40 120 22], ...
        'Text', '0', 'Tag', 'berBeforeFEC', 'FontWeight', 'bold', 'FontColor', [0.8 0 0]);
    
    uilabel(errorPanel, 'Position', [10 10 180 22], 'Text', 'BER (After FEC):');
    uilabel(errorPanel, 'Position', [200 10 120 22], ...
        'Text', '0', 'Tag', 'berAfterFEC', 'FontWeight', 'bold', 'FontColor', [0 0.6 0]);
    
    uilabel(errorPanel, 'Position', [350 100 200 22], 'Text', 'Packets Corrected by FEC:');
    uilabel(errorPanel, 'Position', [560 100 100 22], ...
        'Text', '0', 'Tag', 'packetsCorrected');
    
    uilabel(errorPanel, 'Position', [350 70 200 22], 'Text', 'Total Bits Transmitted:');
    uilabel(errorPanel, 'Position', [560 70 100 22], ...
        'Text', '0', 'Tag', 'totalBits');
    
    uilabel(errorPanel, 'Position', [350 40 200 22], 'Text', 'Bit Errors (Before FEC):');
    uilabel(errorPanel, 'Position', [560 40 100 22], ...
        'Text', '0', 'Tag', 'bitErrorsBefore');
    
    uilabel(errorPanel, 'Position', [350 10 200 22], 'Text', 'Bit Errors (After FEC):');
    uilabel(errorPanel, 'Position', [560 10 100 22], ...
        'Text', '0', 'Tag', 'bitErrorsAfter');
    
    % Missing Packets Panel
    missingPanel = uipanel(tab, 'Title', 'Missing Packet Analysis', ...
        'Position', [10 100 960 140]);
    
    uilabel(missingPanel, 'Position', [10 100 150 22], 'Text', 'Missing Sequences:');
    uitextarea(missingPanel, 'Position', [10 10 500 90], ...
        'Editable', 'off', 'Tag', 'missingPacketsList', ...
        'Value', {'None'});
    
    uilabel(missingPanel, 'Position', [530 100 150 22], 'Text', 'Pattern Analysis:');
    uitextarea(missingPanel, 'Position', [530 10 410 90], ...
        'Editable', 'off', 'Tag', 'patternAnalysis', ...
        'Value', {'No data yet'});
    
    % Audio Info Panel
    audioInfoPanel = uipanel(tab, 'Title', 'File Information', ...
        'Position', [10 10 960 80]);
    
    uilabel(audioInfoPanel, 'Position', [10 40 100 22], 'Text', 'Sample Rate:');
    uilabel(audioInfoPanel, 'Position', [120 40 100 22], 'Text', '0 Hz', 'Tag', 'audioFs');
    
    uilabel(audioInfoPanel, 'Position', [240 40 100 22], 'Text', 'Duration:');
    uilabel(audioInfoPanel, 'Position', [350 40 100 22], 'Text', '0.0 s', 'Tag', 'audioDuration');
    
    uilabel(audioInfoPanel, 'Position', [470 40 100 22], 'Text', 'Samples:');
    uilabel(audioInfoPanel, 'Position', [580 40 100 22], 'Text', '0', 'Tag', 'audioSamples');
    
    uilabel(audioInfoPanel, 'Position', [700 40 100 22], 'Text', 'Compression:');
    uilabel(audioInfoPanel, 'Position', [810 40 100 22], 'Text', 'None', 'Tag', 'audioCompression');
    
    % Add waveform axes here if needed
    ax2 = uiaxes(tab, 'Position', [10 200 500 180], 'Visible', 'off');
    ax2.Tag = 'audioWaveform';
end

%% =============== CAMERA TAB CREATION ===============
function createCameraTab(tab, fig, appData)
    % Camera Control Panel
    controlPanel = uipanel(tab, 'Title', 'Camera Control', ...
        'Position', [10 500 960 150]);
    
    uibutton(controlPanel, 'Position', [20 80 120 50], ...
        'Text', 'START CAMERA', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3 0.6 0.9], ...
        'Tag', 'startCameraBtn', ...
        'ButtonPushedFcn', @(~,~) startCamera(fig));
    
    uibutton(controlPanel, 'Position', [160 80 120 50], ...
        'Text', 'STOP CAMERA', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.3 0.3], ...
        'Tag', 'stopCameraBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) stopCamera(fig));
    
    uibutton(controlPanel, 'Position', [300 80 120 50], ...
        'Text', 'CAPTURE & SEND', 'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.7 0.3], ...
        'Tag', 'captureSendBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) captureAndSend(fig));
    
    uibutton(controlPanel, 'Position', [440 80 120 50], ...
        'Text', 'SAVE IMAGE', 'FontSize', 12, ...
        'Tag', 'saveImageBtn', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) saveCameraImage(fig));
    
    uibutton(controlPanel, 'Position', [20 20 100 40], ...
        'Text', 'Clear Log', 'FontSize', 12, ...
        'ButtonPushedFcn', @(~,~) clearCameraLog(fig));
    
    % Camera Status
    uilabel(controlPanel, 'Position', [600 90 100 22], 'Text', 'Camera Status:');
    uilabel(controlPanel, 'Position', [710 90 200 22], ...
        'Text', 'Off', 'Tag', 'cameraStatus', 'FontWeight', 'bold');
    
    uilabel(controlPanel, 'Position', [600 60 100 22], 'Text', 'Resolution:');
    uilabel(controlPanel, 'Position', [710 60 200 22], ...
        'Text', 'None', 'Tag', 'cameraResolution');
    
    % Image Preview Panel
    previewPanel = uipanel(tab, 'Title', 'Live Preview', ...
        'Position', [10 280 470 210]);
    
    % Create axes for camera preview
    ax = uiaxes(previewPanel, 'Position', [10 10 450 180]);
    ax.Tag = 'cameraAxes';
    ax.XTick = [];
    ax.YTick = [];
    ax.Box = 'on';
    
    % Captured Image Panel
    capturePanel = uipanel(tab, 'Title', 'Captured Image', ...
        'Position', [490 280 470 210]);
    
    % Create axes for captured image
    ax2 = uiaxes(capturePanel, 'Position', [10 10 450 180]);
    ax2.Tag = 'capturedAxes';
    ax2.XTick = [];
    ax2.YTick = [];
    ax2.Box = 'on';
    
    % Camera Settings Panel
    settingsPanel = uipanel(tab, 'Title', 'Camera Settings', ...
        'Position', [10 150 470 120]);
    
    uilabel(settingsPanel, 'Position', [10 70 100 22], 'Text', 'Resolution:');
    uidropdown(settingsPanel, 'Position', [120 70 150 22], ...
        'Items', {'320x240', '640x480', '800x600', '1024x768', '1280x720'}, ...
        'Value', '640x480', 'Tag', 'cameraResSelect');
    
    uilabel(settingsPanel, 'Position', [10 40 100 22], 'Text', 'Quality:');
    uieditfield(settingsPanel, 'numeric', 'Position', [120 40 50 22], ...
        'Value', 85, 'Tag', 'imageQuality', 'Limits', [10 100]);
    
    uicheckbox(settingsPanel, 'Position', [200 50 120 22], ...
        'Value', true, 'Text', 'Auto Focus', 'Tag', 'autoFocus');
    
    uicheckbox(settingsPanel, 'Position', [200 40 120 22], ...
        'Value', true, 'Text', 'Auto Exposure', 'Tag', 'autoExposure');
    
    % Image Processing Panel
    processingPanel = uipanel(tab, 'Title', 'Image Processing', ...
        'Position', [490 150 470 120]);
    
    uicheckbox(processingPanel, 'Position', [10 70 120 22], ...
        'Value', false, 'Text', 'Enable Compression', 'Tag', 'imageCompression');
    
    uilabel(processingPanel, 'Position', [10 40 120 22], 'Text', 'Compression Ratio:');
    uislider(processingPanel, 'Position', [130 48 100 3], ...
        'Limits', [1 10], 'Value', 5, 'Tag', 'compressionRatio');
    
    uicheckbox(processingPanel, 'Position', [250 70 120 22], ...
        'Value', false, 'Text', 'Grayscale', 'Tag', 'grayscale');
    
    uicheckbox(processingPanel, 'Position', [250 40 120 22], ...
        'Value', false, 'Text', 'Add Timestamp', 'Tag', 'addTimestamp');
    
    % Camera Log Panel
    logPanel = uipanel(tab, 'Title', 'Camera Log', ...
        'Position', [10 10 960 130]);
    
    uitextarea(logPanel, 'Position', [10 10 940 100], ...
        'Editable', 'off', 'Tag', 'cameraLog', ...
        'Value', {'[CAMERA] Ready...'});
end

%% =============== CALLBACK FUNCTIONS ===============

function detectSDRs(fig)
    statusLabel = findobj(fig, 'Tag', 'detectedSDRs');
    statusLabel.Text = 'Detecting SDRs...';
    drawnow;
    
    availableRadios = {};
    possibleIDs = {'usb:0', 'usb:1', 'usb:2', 'usb:3'};
    
    for i = 1:length(possibleIDs)
        try
            radioID = possibleIDs{i};
            testRx = sdrrx('Pluto', 'RadioID', radioID, ...
                'CenterFrequency', 800e6, 'BasebandSampleRate', 1e6, ...
                'SamplesPerFrame', 1000, 'OutputDataType', 'double');
            release(testRx);
            availableRadios{end+1} = radioID;
        catch
            % Radio not available
        end
    end
    
    if isempty(availableRadios)
        statusLabel.Text = 'Detected SDRs: None found!';
    else
        statusLabel.Text = sprintf('Detected SDRs: %s', strjoin(availableRadios, ', '));
        
        % Update dropdowns
        txDropdown = findobj(fig, 'Tag', 'txRadioID');
        rxDropdown = findobj(fig, 'Tag', 'rxRadioID');
        txDropdown.Items = availableRadios;
        rxDropdown.Items = availableRadios;
        
        if length(availableRadios) >= 1
            txDropdown.Value = availableRadios{1};
            rxDropdown.Value = availableRadios{1};
        end
    end
end

function browseInputFile(fig)
    % File filters for all supported types
    fileFilters = { ...
        '*.mp3;*.wav;*.m4a;*.flac;*.ogg;*.aac;*.wma', 'Audio Files'; ...
        '*.mp4;*.avi;*.mkv;*.mov;*.wmv;*.flv;*.webm;*.mpeg;*.mpg;*.3gp', 'Video Files'; ...
        '*.pdf', 'PDF Files'; ...
        '*.docx;*.doc', 'Word Documents'; ...
        '*.txt;*.rtf', 'Text Files'; ...
        '*.xlsx;*.xls;*.csv', 'Excel Files'; ...
        '*.pptx;*.ppt', 'PowerPoint Files'; ...
        '*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.tiff', 'Image Files'; ...
        '*.*', 'All Files'};
    
    [file, path] = uigetfile(fileFilters, 'Select a file to transmit');
    if file ~= 0
        fullPath = fullfile(path, file);
        
        % Update input file field
        inputFileField = findobj(fig, 'Tag', 'inputFile');
        inputFileField.Value = fullPath;
        
        % Detect and display file type
        [fileType, fileTypeCode] = detectFileType(fullPath);
        detectedLabel = findobj(fig, 'Tag', 'detectedFileType');
        detectedLabel.Text = fileType;
        
        % Update file size
        fileInfo = dir(fullPath);
        fileSizeLabel = findobj(fig, 'Tag', 'fileSize');
        if fileInfo.bytes < 1024
            fileSizeLabel.Text = sprintf('%d bytes', fileInfo.bytes);
        elseif fileInfo.bytes < 1024*1024
            fileSizeLabel.Text = sprintf('%.2f KB', fileInfo.bytes/1024);
        else
            fileSizeLabel.Text = sprintf('%.2f MB', fileInfo.bytes/(1024*1024));
        end
        
        % Show/hide audio options based on file type
        audioPanel = findobj(fig, 'Tag', 'audioOptionsPanel');
        if strcmp(fileType, 'AUDIO')
            audioPanel.Visible = 'on';
        else
            audioPanel.Visible = 'off';
        end
    end
end

function updateFECOptions(fig, mode)
    rsCodeRate = findobj(fig, 'Tag', 'rsCodeRate');
    useInterleaving = findobj(fig, 'Tag', 'useInterleaving');
    
    if contains(mode, 'RS')
        rsCodeRate.Enable = 'on';
        useInterleaving.Enable = 'on';
    else
        rsCodeRate.Enable = 'off';
        useInterleaving.Enable = 'off';
    end
end

function startTransmission(fig)
    % Get all configuration values
    config = getConfiguration(fig);
    
    % Update UI
    startBtn = findobj(fig, 'Tag', 'startTxBtn');
    stopBtn = findobj(fig, 'Tag', 'stopTxBtn');
    txStatus = findobj(fig, 'Tag', 'txStatus');
    txLog = findobj(fig, 'Tag', 'txLog');
    
    startBtn.Enable = 'off';
    stopBtn.Enable = 'on';
    txStatus.Text = 'Starting...';
    
    % Reset progress bar
    updateProgressBar(fig, 'txProgress', 0, 400);
    
    % Store stop flag
    setappdata(fig, 'stopTx', false);
    
    % Run transmission in background
    try
        runTransmission(fig, config);
    catch ME
        txLog.Value = [txLog.Value; {sprintf('[TX] ERROR: %s', ME.message)}];
        txStatus.Text = 'Error';
    end
    
    startBtn.Enable = 'on';
    stopBtn.Enable = 'off';
end

function stopTransmission(fig)
    setappdata(fig, 'stopTx', true);
    txStatus = findobj(fig, 'Tag', 'txStatus');
    txStatus.Text = 'Stopping...';
end

function startReception(fig)
    % Get configuration
    config = getConfiguration(fig);
    
    % Update UI
    startBtn = findobj(fig, 'Tag', 'startRxBtn');
    stopBtn = findobj(fig, 'Tag', 'stopRxBtn');
    rxStatus = findobj(fig, 'Tag', 'rxStatus');
    rxLog = findobj(fig, 'Tag', 'rxLog');
    
    startBtn.Enable = 'off';
    stopBtn.Enable = 'on';
    rxStatus.Text = 'Starting...';
    
    % Reset progress bar
    updateProgressBar(fig, 'rxProgress', 0, 200);
    
    % Store stop flag
    setappdata(fig, 'stopRx', false);
    
    % Run reception
    try
        runReception(fig, config);
    catch ME
        rxLog.Value = [rxLog.Value; {sprintf('[RX] ERROR: %s', ME.message)}];
        rxStatus.Text = 'Error';
    end
    
    startBtn.Enable = 'on';
    stopBtn.Enable = 'off';
end

function stopReception(fig)
    setappdata(fig, 'stopRx', true);
    rxStatus = findobj(fig, 'Tag', 'rxStatus');
    rxStatus.Text = 'Stopping...';
end

function config = getConfiguration(fig)
    config = struct();
    
    % RF Config
    config.centerFreq = findobj(fig, 'Tag', 'centerFreq').Value * 1e6;
    config.sampleRate = findobj(fig, 'Tag', 'sampleRate').Value * 1e6;
    config.channelBW = findobj(fig, 'Tag', 'channelBW').Value;
    
    mcsStr = findobj(fig, 'Tag', 'mcsSelect').Value;
    config.mcs = str2double(mcsStr(1));
    
    % SDR Config
    config.txRadioID = findobj(fig, 'Tag', 'txRadioID').Value;
    config.rxRadioID = findobj(fig, 'Tag', 'rxRadioID').Value;
    
    % Audio Config
    config.targetFs = findobj(fig, 'Tag', 'targetFs').Value;
    config.useCompression = findobj(fig, 'Tag', 'useCompression').Value;
    config.compQuality = findobj(fig, 'Tag', 'compQuality').Value;

    % File Config
    inputFileField = findobj(fig, 'Tag', 'inputFile');
    if ~isempty(inputFileField)
        config.inputFile = inputFileField.Value;
    else
        config.inputFile = '';
    end
    
    % FEC Config
    config.fecMode = findobj(fig, 'Tag', 'fecMode').Value;
    config.rsCodeRate = findobj(fig, 'Tag', 'rsCodeRate').Value;
    config.useInterleaving = findobj(fig, 'Tag', 'useInterleaving').Value;
    
    % Reliability Config
    config.tailRepeats = findobj(fig, 'Tag', 'tailRepeats').Value;
    config.tailCount = findobj(fig, 'Tag', 'tailCount').Value;
    config.eosMarkers = findobj(fig, 'Tag', 'eosMarkers').Value;
    config.finalDelay = findobj(fig, 'Tag', 'finalDelay').Value;
    config.verifyLastPkts = findobj(fig, 'Tag', 'verifyLastPkts').Value;
    config.extendedWait = findobj(fig, 'Tag', 'extendedWait').Value;
    
    % Timing Config
    config.txTime = findobj(fig, 'Tag', 'txTime').Value;
    config.txGap = findobj(fig, 'Tag', 'txGap').Value;
    config.txRepeats = findobj(fig, 'Tag', 'txRepeats').Value;
    config.syncPackets = findobj(fig, 'Tag', 'syncPackets').Value;
    config.syncInterval = findobj(fig, 'Tag', 'syncInterval').Value;
    
    % RX Config
    config.rxSamplesPerFrame = findobj(fig, 'Tag', 'rxSamplesPerFrame').Value;
    config.rxTimeout = findobj(fig, 'Tag', 'rxTimeout').Value;
    config.rxGain = findobj(fig, 'Tag', 'rxGain').Value;
    config.earlyExitEnable = findobj(fig, 'Tag', 'earlyExitEnable').Value;
    config.earlyExitThreshold = findobj(fig, 'Tag', 'earlyExitThreshold').Value / 100;
    config.intelligentExit = findobj(fig, 'Tag', 'intelligentExit').Value;
    config.gapStaleTime = findobj(fig, 'Tag', 'gapStaleTime').Value;
    
    % Camera Config
    config.cameraResolution = findobj(fig, 'Tag', 'cameraResSelect').Value;
    config.imageQuality = findobj(fig, 'Tag', 'imageQuality').Value;
    config.autoFocus = findobj(fig, 'Tag', 'autoFocus').Value;
    config.autoExposure = findobj(fig, 'Tag', 'autoExposure').Value;
    config.imageCompression = findobj(fig, 'Tag', 'imageCompression').Value;
    config.compressionRatio = findobj(fig, 'Tag', 'compressionRatio').Value;
    config.grayscale = findobj(fig, 'Tag', 'grayscale').Value;
    config.addTimestamp = findobj(fig, 'Tag', 'addTimestamp').Value;
end

function showHelp()
    msg = sprintf(['HCLoS PoC File Streaming GUI - Help\n\n' ...
        '=== NEW FEATURES ===\n' ...
        '• Camera Tab: Capture snapshots from laptop HD camera\n' ...
        '• Live Error Rates: Real-time PER and BER display\n' ...
        '• FEC Statistics: Track corrections before/after FEC\n\n' ...
        '=== RELIABILITY FEATURES (for last packet issues) ===\n' ...
        '• Tail Packet Repeats: Extra transmissions for final packets\n' ...
        '• Tail Count: How many packets at end to treat specially\n' ...
        '• End-of-Stream Markers: Special packets signaling end\n' ...
        '• Final Packet Delay: Extra delay between last packets\n\n' ...
        '=== FEC OPTIONS ===\n' ...
        '• BCC Only: Standard convolutional coding (default)\n' ...
        '• RS + BCC: Reed-Solomon + BCC (burst error protection)\n' ...
        '• RS Only: Experimental RS-only mode\n\n' ...
        '=== AUDIO QUALITY ===\n' ...
        '• For best quality: Use 44100 Hz, disable compression\n' ...
        '• For smaller file: Use 8000 Hz with compression\n\n' ...
        '=== TROUBLESHOOTING ===\n' ...
        '• Missing last packets: Increase Tail Repeats and Tail Count\n' ...
        '• Poor signal: Reduce MCS, increase TX time\n' ...
        '• Interference: Try different center frequency\n']);
    
    uialert(gcf, msg, 'Help', 'Icon', 'info');
end

function playReceivedAudio(fig)
    appData = guidata(fig);
    if isfield(appData, 'receivedAudio') && ~isempty(appData.receivedAudio)
        sound(appData.receivedAudio, appData.receivedFs);
    end
end

function saveReceivedAudio(fig)
    appData = guidata(fig);
    if isfield(appData, 'receivedAudio') && ~isempty(appData.receivedAudio)
        [file, path] = uiputfile('*.wav', 'Save Audio');
        if file ~= 0
            audiowrite(fullfile(path, file), appData.receivedAudio, appData.receivedFs);
        end
    end
end

%% =============== CAMERA FUNCTIONS ===============

function startCamera(fig)
    appData = guidata(fig);
    cameraLog = findobj(fig, 'Tag', 'cameraLog');
    cameraStatus = findobj(fig, 'Tag', 'cameraStatus');
    startBtn = findobj(fig, 'Tag', 'startCameraBtn');
    stopBtn = findobj(fig, 'Tag', 'stopCameraBtn');
    captureBtn = findobj(fig, 'Tag', 'captureSendBtn');
    saveBtn = findobj(fig, 'Tag', 'saveImageBtn');
    
    try
        % Get camera resolution
        resStr = findobj(fig, 'Tag', 'cameraResSelect').Value;
        resParts = strsplit(resStr, 'x');
        width = str2double(resParts{1});
        height = str2double(resParts{2});
        
        % Initialize camera
        if isempty(appData.cameraObj) || ~isvalid(appData.cameraObj)
            appData.cameraObj = webcam;
        end
        
        % Update UI
        cameraStatus.Text = 'Running';
        startBtn.Enable = 'off';
        stopBtn.Enable = 'on';
        captureBtn.Enable = 'on';
        saveBtn.Enable = 'on';
        
        % Update resolution display
        resLabel = findobj(fig, 'Tag', 'cameraResolution');
        resLabel.Text = sprintf('%dx%d', width, height);
        
        logAndScroll(cameraLog, '[CAMERA] Camera started');
        
        % Start preview in separate timer
        startCameraPreview(fig);
        
    catch ME
        logAndScroll(cameraLog, sprintf('[CAMERA] ERROR: %s', ME.message));
        cameraStatus.Text = 'Error';
    end
    
    guidata(fig, appData);
end

function stopCamera(fig)
    appData = guidata(fig);
    cameraLog = findobj(fig, 'Tag', 'cameraLog');
    cameraStatus = findobj(fig, 'Tag', 'cameraStatus');
    startBtn = findobj(fig, 'Tag', 'startCameraBtn');
    stopBtn = findobj(fig, 'Tag', 'stopCameraBtn');
    captureBtn = findobj(fig, 'Tag', 'captureSendBtn');
    saveBtn = findobj(fig, 'Tag', 'saveImageBtn');
    
    try
        % Stop preview timer
        stopCameraPreview(fig);
        
        % Clear camera object
        if ~isempty(appData.cameraObj) && isvalid(appData.cameraObj)
            clear appData.cameraObj;
            appData.cameraObj = [];
        end
        
        % Update UI
        cameraStatus.Text = 'Off';
        startBtn.Enable = 'on';
        stopBtn.Enable = 'off';
        captureBtn.Enable = 'off';
        saveBtn.Enable = 'off';
        
        logAndScroll(cameraLog, '[CAMERA] Camera stopped');
        
    catch ME
        logAndScroll(cameraLog, sprintf('[CAMERA] ERROR: %s', ME.message));
    end
    
    guidata(fig, appData);
end

function startCameraPreview(fig)
    % Start timer for camera preview
    appData = guidata(fig);
    
    % Create or restart timer
    if isfield(appData, 'previewTimer') && isvalid(appData.previewTimer)
        stop(appData.previewTimer);
        delete(appData.previewTimer);
    end
    
    appData.previewTimer = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period', 0.1, ...  % 10 FPS
        'TimerFcn', @(~,~) updateCameraPreview(fig), ...
        'BusyMode', 'drop');
    
    start(appData.previewTimer);
    guidata(fig, appData);
end

function stopCameraPreview(fig)
    % Stop preview timer
    appData = guidata(fig);
    
    if isfield(appData, 'previewTimer') && isvalid(appData.previewTimer)
        stop(appData.previewTimer);
        delete(appData.previewTimer);
        appData = rmfield(appData, 'previewTimer');
    end
    
    % Clear axes
    cameraAxes = findobj(fig, 'Tag', 'cameraAxes');
    if ~isempty(cameraAxes)
        cla(cameraAxes);
        title(cameraAxes, 'Camera Off');
    end
    
    guidata(fig, appData);
end

function updateCameraPreview(fig)
    appData = guidata(fig);
    cameraAxes = findobj(fig, 'Tag', 'cameraAxes');
    
    try
        if ~isempty(appData.cameraObj) && isvalid(appData.cameraObj)
            % Capture frame
            img = snapshot(appData.cameraObj);
            
            % Update axes
            if isvalid(cameraAxes)
                imshow(img, 'Parent', cameraAxes);
                title(cameraAxes, 'Live Camera');
                drawnow;
            end
        end
    catch
        % Camera might be disconnected
    end
end

function captureAndSend(fig)
    appData = guidata(fig);
    cameraLog = findobj(fig, 'Tag', 'cameraLog');
    
    try
        if isempty(appData.cameraObj) || ~isvalid(appData.cameraObj)
            error('Camera not available');
        end
        
        logAndScroll(cameraLog, '[CAMERA] Capturing image...');
        
        % Capture image
        img = snapshot(appData.cameraObj);
        
        % Apply processing
        config = getConfiguration(fig);
        
        % Convert to grayscale if selected
        if config.grayscale
            img = rgb2gray(img);
            logAndScroll(cameraLog, '[CAMERA] Converted to grayscale');
        end
        
        % Add timestamp if selected
        if config.addTimestamp
    try
        % Try using insertText (requires Computer Vision Toolbox)
        img = insertText(img, [10 10], datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
            'FontSize', 14, 'BoxColor', 'black', 'TextColor', 'white');
    catch
        % Fallback: Draw timestamp using graphics
        figTemp = figure('Visible', 'off');
        imshow(img);
        hold on;
        text(10, 20, datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
            'Color', 'white', 'FontSize', 12, 'FontWeight', 'bold', ...
            'BackgroundColor', 'black');
        hold off;
        frame = getframe(gca);
        img = frame.cdata;
        close(figTemp);
    end
    logAndScroll(cameraLog, '[CAMERA] Added timestamp');
end
        
        % Display captured image
        capturedAxes = findobj(fig, 'Tag', 'capturedAxes');
        if isvalid(capturedAxes)
            imshow(img, 'Parent', capturedAxes);
            title(capturedAxes, 'Captured Image');
        end
        
        % Save to temporary file
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        tempFile = fullfile(pwd, sprintf('snapshot_%s.jpg', timestamp));
        
        % Apply compression if selected
        if config.imageCompression
            % Use compression ratio to adjust quality (ratio 1-10 maps to quality 100-10)
            effectiveQuality = round(config.imageQuality * (11 - config.compressionRatio) / 10);
            effectiveQuality = max(10, min(100, effectiveQuality));
            imwrite(img, tempFile, 'jpg', 'Quality', effectiveQuality);
            logAndScroll(cameraLog, sprintf('[CAMERA] Saved compressed image (Q=%d, Ratio=%.1f)', effectiveQuality, config.compressionRatio));
        else
            % Save as PNG for uncompressed (lossless)
            tempFile = strrep(tempFile, '.jpg', '.png');
            imwrite(img, tempFile, 'png');
            logAndScroll(cameraLog, '[CAMERA] Saved uncompressed PNG image');
        end
        
        % Update input file field
        inputFileField = findobj(fig, 'Tag', 'inputFile');
        inputFileField.Value = tempFile;
        
        % Update file info
        fileInfo = dir(tempFile);
        fileSizeLabel = findobj(fig, 'Tag', 'fileSize');
        fileSizeLabel.Text = sprintf('%.2f KB', fileInfo.bytes/1024);
        
        % Update file type
        detectedLabel = findobj(fig, 'Tag', 'detectedFileType');
        detectedLabel.Text = 'IMAGE';
        
        % Hide audio options
        audioPanel = findobj(fig, 'Tag', 'audioOptionsPanel');
        audioPanel.Visible = 'off';
        
        logAndScroll(cameraLog, sprintf('[CAMERA] Ready to transmit: %s (%.2f KB)', ...
            tempFile, fileInfo.bytes/1024));
        
        % Switch to TX tab
        tabGroup = findobj(fig, 'Type', 'uitabgroup');
        if ~isempty(tabGroup)
            tabGroup.SelectedTab = findobj(tabGroup.Children, 'Title', 'Transmitter');
        end
        
    catch ME
        logAndScroll(cameraLog, sprintf('[CAMERA] ERROR: %s', ME.message));
    end
end

function captureSnapshot(fig)
    % Capture snapshot and set as input file
    cameraLog = findobj(fig, 'Tag', 'cameraLog');
    
    try
        % Check if camera is available
        camList = webcamlist;
        if isempty(camList)
            error('No camera detected');
        end
        
        % Use first available camera
        cam = webcam(1);
        img = snapshot(cam);
        clear cam;
        
        % Save to temporary file
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        tempFile = fullfile(pwd, sprintf('snapshot_%s.jpg', timestamp));
        imwrite(img, tempFile);
        
        % Update input file field
        inputFileField = findobj(fig, 'Tag', 'inputFile');
        inputFileField.Value = tempFile;
        
        % Update file info
        fileInfo = dir(tempFile);
        fileSizeLabel = findobj(fig, 'Tag', 'fileSize');
        fileSizeLabel.Text = sprintf('%.2f KB', fileInfo.bytes/1024);
        
        % Update file type
        detectedLabel = findobj(fig, 'Tag', 'detectedFileType');
        detectedLabel.Text = 'IMAGE';
        
        % Hide audio options
        audioPanel = findobj(fig, 'Tag', 'audioOptionsPanel');
        audioPanel.Visible = 'off';
        
        % Show preview in captured axes
        capturedAxes = findobj(fig, 'Tag', 'capturedAxes');
        if isvalid(capturedAxes)
            imshow(img, 'Parent', capturedAxes);
            title(capturedAxes, 'Snapshot');
        end
        
        logAndScroll(cameraLog, sprintf('[CAMERA] Snapshot saved: %s', tempFile));
        
    catch ME
        uialert(fig, sprintf('Camera error: %s', ME.message), 'Camera Error');
    end
end

function saveCameraImage(fig)
    appData = guidata(fig);
    cameraLog = findobj(fig, 'Tag', 'cameraLog');
    
    try
        if isempty(appData.cameraObj) || ~isvalid(appData.cameraObj)
            error('Camera not available');
        end
        
        % Capture image
        img = snapshot(appData.cameraObj);
        
        % Ask for save location
        [file, path] = uiputfile({'*.jpg;*.png;*.bmp', 'Image files (*.jpg, *.png, *.bmp)'}, ...
            'Save Image As');
        
        if file ~= 0
            % Get file extension
            [~, ~, ext] = fileparts(file);
            
            % Save image
            if strcmpi(ext, '.jpg') || strcmpi(ext, '.jpeg')
                imwrite(img, fullfile(path, file), 'jpg', 'Quality', 95);
            else
                imwrite(img, fullfile(path, file));
            end
            
            logAndScroll(cameraLog, sprintf('[CAMERA] Image saved: %s', fullfile(path, file)));
        end
        
    catch ME
        logAndScroll(cameraLog, sprintf('[CAMERA] ERROR: %s', ME.message));
    end
end

function clearCameraLog(fig)
    cameraLog = findobj(fig, 'Tag', 'cameraLog');
    cameraLog.Value = {'[CAMERA] Log cleared...'};
end

%% =============== MAIN TX/RX FUNCTIONS ===============

function runTransmission(fig, config)
    txLog = findobj(fig, 'Tag', 'txLog');
    txStatus = findobj(fig, 'Tag', 'txStatus');
    txPacketCount = findobj(fig, 'Tag', 'txPacketCount');
    
    logMsg = @(msg) logAndScroll(txLog, msg);
    
    % Fixed parameters
    scramInit = 93;
    dataPacketHeaderBytes = 1;
    
    % Reduce payload size when RS encoding is enabled
    if contains(config.fecMode, 'RS')
        [rsN, rsK] = parseRSParams(config.rsCodeRate);
        rsOverhead = rsN / rsK;
        maxPayloadBytes = floor((2200 - 10) / rsOverhead);
        logMsg(sprintf('[TX] RS enabled: reduced payload to %d bytes (overhead: %.1f%%)', ...
            maxPayloadBytes, (rsOverhead-1)*100));
    else
        maxPayloadBytes = 2200;
    end
    
    maxDataPerPacket = maxPayloadBytes - dataPacketHeaderBytes;
    
    % Build PHY/MAC configs
    [cfgPHY, cfgMAC] = buildConfigs(config.channelBW, config.mcs);
    
    % Read and process input file
    inputFile = findobj(fig, 'Tag', 'inputFile').Value;
    
    if isempty(inputFile) || ~isfile(inputFile)
        error('Please select a valid input file');
    end
    
    logMsg(sprintf('[TX] Reading file: %s', inputFile));
    txStatus.Text = 'Loading file...';
    drawnow;
    
    try
        % Read file based on type
        [fileBytes, fileMetadata] = readFileForTransmission(inputFile, config);
        fileMetadata.maxDataPerPacket = maxDataPerPacket;
        
        logMsg(sprintf('[TX] File type: %s', fileMetadata.fileType));
        logMsg(sprintf('[TX] File size: %d bytes (%.2f KB)', ...
            fileMetadata.totalBytes, fileMetadata.totalBytes/1024));
        
        if strcmp(fileMetadata.fileType, 'AUDIO')
            logMsg(sprintf('[TX] Audio: %d samples @ %d Hz', ...
                fileMetadata.audioSamples, fileMetadata.audioFs));
            if fileMetadata.compressionUsed
                logMsg(sprintf('[TX] Compression: Q=%d, ratio=%.1fx', ...
                    fileMetadata.compressionQuality, fileMetadata.compressionRatio));
            end
        elseif strcmp(fileMetadata.fileType, 'IMAGE')
            if isfield(fileMetadata, 'imageHeight')
                logMsg(sprintf('[TX] Image: %dx%d pixels, %d channels', ...
                    fileMetadata.imageHeight, fileMetadata.imageWidth, fileMetadata.imageChannels));
            end
        end
        
        % Packetize file
        dataPackets = packetizeFile(fileBytes, fileMetadata, maxDataPerPacket);
        numDataPackets = numel(dataPackets);
        
        logMsg(sprintf('[TX] Data packets: %d', numDataPackets));
        
        % Create sync packets
        syncPackets = createMultiFileSyncPackets(numDataPackets, fileMetadata, ...
            config.syncPackets, config);
        
        % Combine packets
        allPackets = [syncPackets; dataPackets];
        totalPkts = numel(allPackets);
        
        logMsg(sprintf('[TX] Total: %d packets (%d sync + %d data)', ...
            totalPkts, config.syncPackets, numDataPackets));
        
        % Pad all packets to same size for consistent waveform generation
        maxPktSize = 0;
        for k = 1:totalPkts
            if length(allPackets{k}) > maxPktSize
                maxPktSize = length(allPackets{k});
            end
        end
        
        for k = 1:totalPkts
            pktLen = length(allPackets{k});
            if pktLen < maxPktSize
                padding = zeros(maxPktSize - pktLen, 1, 'uint8');
                allPackets{k} = [allPackets{k}; padding];
            end
        end
        
        % Generate waveforms
        txStatus.Text = 'Generating waveforms...';
        logMsg('[TX] Generating HCLoS waveforms...');
        drawnow;
        
        txWaveforms = cell(totalPkts, 1);
        for k = 1:totalPkts
            cfgMAC.SequenceNumber = k - 1;
            
            pktData = allPackets{k};
            
            % Apply RS encoding if enabled
            if contains(config.fecMode, 'RS')
                [rsN, rsK] = parseRSParams(config.rsCodeRate);
                pktData = applyRSEncoding(pktData, rsN, rsK, config.useInterleaving);
            end
            
            [psduBits, psduLenBytes] = wlanMACFrame(uint8(pktData), cfgMAC, 'OutputFormat', 'bits');
            cfgPHY.PSDULength = psduLenBytes;
            txWave = wlanWaveformGenerator(psduBits, cfgPHY, 'ScramblerInitialization', scramInit);
            txWave = 0.8 * txWave / max(abs(txWave) + eps);
            txWaveforms{k} = txWave;
            
            if mod(k, 20) == 0 || k == 1 || k == totalPkts
                updateProgressBar(fig, 'txProgress', (k / totalPkts) * 50, 400);
                drawnow;
            end
        end
        
        % Create EOS waveforms
        eosWaveforms = cell(config.eosMarkers, 1);
        for i = 1:config.eosMarkers
            eosPacket = createEOSPacketMultiFile(numDataPackets, fileMetadata, i);
            eosPacket = [eosPacket; zeros(maxPktSize - length(eosPacket), 1, 'uint8')];
            
            cfgMAC.SequenceNumber = totalPkts + i;
            [psduBits, psduLenBytes] = wlanMACFrame(uint8(eosPacket), cfgMAC, 'OutputFormat', 'bits');
            cfgPHY.PSDULength = psduLenBytes;
            eosWave = wlanWaveformGenerator(psduBits, cfgPHY, 'ScramblerInitialization', scramInit);
            eosWave = 0.8 * eosWave / max(abs(eosWave) + eps);
            eosWaveforms{i} = eosWave;
        end
        
        % Initialize transmitter
        txStatus.Text = 'Initializing SDR...';
        logMsg('[TX] Initializing transmitter...');
        drawnow;
        
        tx = sdrtx('Pluto', 'RadioID', config.txRadioID, ...
            'CenterFrequency', config.centerFreq, ...
            'BasebandSampleRate', config.sampleRate, ...
            'Gain', 0);
        % pause(0.5);
        
        txStatus.Text = 'Transmitting...';

                % Initialize PAPR tracking
        allPAPRvalues = zeros(totalPkts, 1);
        for k = 1:totalPkts
            allPAPRvalues(k) = calculatePAPR(txWaveforms{k});
        end
        avgPAPR = mean(allPAPRvalues);
        
        % Display average PAPR
        txAvgPAPRLabel = findobj(fig, 'Tag', 'txAvgPAPR');
        txAvgPAPRLabel.Text = sprintf('%.2f dB', avgPAPR);
        logMsg(sprintf('[TX] Average PAPR: %.2f dB (Min: %.2f, Max: %.2f)', ...
            avgPAPR, min(allPAPRvalues), max(allPAPRvalues)));
        
        % Transmit sync packets
        if config.syncPackets > 0
            logMsg('[TX] === SYNC PHASE ===');
            for k = 1:config.syncPackets
                if getappdata(fig, 'stopTx'); break; end
                
                transmitRepeat(tx, txWaveforms{k});
                logMsg(sprintf('[TX] SYNC %d/%d', k, config.syncPackets));
                pause(config.syncInterval);
            end
        end
        
        % Transmit data packets
        for repeatIdx = 1:config.txRepeats
            if getappdata(fig, 'stopTx'); break; end
            
            logMsg(sprintf('[TX] === DATA REPEAT %d/%d ===', repeatIdx, config.txRepeats));
            
            for k = (config.syncPackets + 1):totalPkts
                if getappdata(fig, 'stopTx'); break; end
                
                dataIdx = k - config.syncPackets;
                isTailPacket = dataIdx > (numDataPackets - config.tailCount);
                
                % Calculate PAPR for current waveform
                currentPAPR = calculatePAPR(txWaveforms{k});
                
                if isTailPacket
                    for tailRep = 1:config.tailRepeats
                        transmitRepeat(tx, txWaveforms{k});
                        pause(config.finalDelay);
                    end
                    logMsg(sprintf('[TX] TAIL R%d: pkt %d/%d (x%d) PAPR=%.2fdB', ...
                        repeatIdx, dataIdx, numDataPackets, config.tailRepeats, currentPAPR));
                else
                    transmitRepeat(tx, txWaveforms{k});
                    pause(config.txTime);
                end

% Update PAPR display
txPAPRLabel = findobj(fig, 'Tag', 'txPAPR');
txPAPRLabel.Text = sprintf('%.2f dB', currentPAPR);
                
                if config.txGap > 0
                    pause(config.txGap);
                end
                
                progress = 50 + (dataIdx / numDataPackets) * (50 / config.txRepeats) * repeatIdx;
                updateProgressBar(fig, 'txProgress', min(progress, 100), 400);
                txPacketCount.Text = sprintf('%d/%d', dataIdx, numDataPackets);
                
                if mod(dataIdx, 20) == 0 || dataIdx == 1
                    logMsg(sprintf('[TX] R%d: pkt %d/%d', repeatIdx, dataIdx, numDataPackets));
                end
                drawnow;
            end
            
            if repeatIdx < config.txRepeats
                pause(1.0);
            end
        end
        
        % Transmit EOS markers
        if config.eosMarkers > 0 && ~getappdata(fig, 'stopTx')
            logMsg('[TX] === END-OF-STREAM ===');
            for i = 1:config.eosMarkers
                for rep = 1:3
                    transmitRepeat(tx, eosWaveforms{i});
                    pause(config.finalDelay);
                end
                logMsg(sprintf('[TX] EOS %d/%d', i, config.eosMarkers));
            end
        end
        
        release(tx);
        
        updateProgressBar(fig, 'txProgress', 100, 400);
        txStatus.Text = 'Complete';
        logMsg(sprintf('[TX] === COMPLETE: %s transmitted ===', fileMetadata.fileType));
        
    catch ME
        logAndScroll(txLog, sprintf('[TX] ERROR: %s', ME.message));
        txStatus.Text = 'Error';
        rethrow(ME);
    end
end

function runReception(fig, config)
    rxLog = findobj(fig, 'Tag', 'rxLog');
    rxStatus = findobj(fig, 'Tag', 'rxStatus');
    rxPacketCount = findobj(fig, 'Tag', 'rxPacketCount');
    
    logMsg = @(msg) logAndScroll(rxLog, msg);
    
    % Build PHY config
    [cfgPHY, ~] = buildConfigs(config.channelBW, config.mcs);
    
    % Initialize receiver
    rxStatus.Text = 'Initializing SDR...';
    logMsg('[RX] Initializing receiver...');
    drawnow;
    
    rx = sdrrx('Pluto', 'RadioID', config.rxRadioID, ...
        'CenterFrequency', config.centerFreq, ...
        'BasebandSampleRate', config.sampleRate, ...
        'GainSource', 'AGC Fast Attack', ...
        'Gain', config.rxGain, ...
        'SamplesPerFrame', config.rxSamplesPerFrame, ...
        'OutputDataType', 'double');
    % pause(0.5);
    
    rxStatus.Text = 'Listening...';
    logMsg(sprintf('[RX] Listening (max %ds)...', config.rxTimeout));
    
    % Storage
    totalPkts = [];
    compressionUsed = false;
    compressionQ = 0;
    compRatio = 1.0;
    rxSyncInfo = struct();
    
    rawPayloads = containers.Map('KeyType', 'uint32', 'ValueType', 'any');
    
    streamConfirmed = false;
    confirmCount = 0;
    totalFrames = 0;
    totalDecodes = 0;
    eosReceived = false;
    
    % Error tracking
    packetsCorrected = 0;
    totalBits = 0;
    bitErrorsBeforeFEC = 0;
    bitErrorsAfterFEC = 0;
    
    % Early exit tracking
    thresholdMetTime = [];
    
    tStart = tic;
    lastStatus = tic;
    
    while toc(tStart) < config.rxTimeout && ~getappdata(fig, 'stopRx')
        totalFrames = totalFrames + 1;
        rxSig = rx();
        
        [decoded, payload, errorsBefore, errorsAfter] = tryDecodeWithErrors(rxSig, cfgPHY, config.sampleRate, config);
        
        if decoded
            totalDecodes = totalDecodes + 1;
            
            % Track errors
            if errorsBefore > 0
                bitErrorsBeforeFEC = bitErrorsBeforeFEC + errorsBefore;
            end
            if errorsAfter > 0
                bitErrorsAfterFEC = bitErrorsAfterFEC + errorsAfter;
                if errorsAfter < errorsBefore  % If FEC corrected some errors
                    packetsCorrected = packetsCorrected + 1;
                end
            end
            
            totalBits = totalBits + length(payload) * 8;
            
            % Apply RS decoding if enabled
            if contains(config.fecMode, 'RS')
                [rsN, rsK] = parseRSParams(config.rsCodeRate);
                payload = applyRSDecoding(payload, rsN, rsK, config.useInterleaving);
            end
            
            % Check if it's a SYNC packet
            if length(payload) >= 4 && strcmp(char(payload(1:4)'), 'SYNC')
                [validSync, syncInfo] = parseMultiFileSyncPacket(payload);
                if validSync && ~streamConfirmed
                    confirmCount = confirmCount + 1;
                    if confirmCount == 1
                        totalPkts = syncInfo.numDataPackets;
                        rxSyncInfo = syncInfo;
                        
                        if isfield(syncInfo, 'compressionUsed')
                            compressionUsed = syncInfo.compressionUsed;
                            compressionQ = syncInfo.compressionQuality;
                            compRatio = syncInfo.compressionRatio;
                        end
                        
                        logMsg(sprintf('[RX] SYNC: %s | %d packets | %d bytes', ...
                            syncInfo.fileType, syncInfo.numDataPackets, syncInfo.totalFileSize));
                    end
                    if confirmCount >= 2
                        streamConfirmed = true;
                        % Display clean filename (only printable chars)
                        displayName = rxSyncInfo.filename;
                        displayName = displayName(displayName >= 32 & displayName <= 126);
                        if isempty(displayName)
                            displayName = ['file.' rxSyncInfo.extension];
                        end
                        logMsg(sprintf('[RX] LOCKED: %s | %d packets | File: %s', ...
                            rxSyncInfo.fileType, totalPkts, displayName));
                    end
                end
                continue;
            end
            
            % Check for EOS packet
            if length(payload) >= 4 && strcmp(char(payload(1:4)'), 'EOS!')
                eosReceived = true;
                logMsg('[RX] End-of-Stream marker received');
                
                % Extended wait after EOS
                if config.extendedWait && ~isempty(totalPkts) && rawPayloads.Count < totalPkts
                    logMsg('[RX] Extended wait for remaining packets...');
                    extendedStart = tic;
                    while toc(extendedStart) < 5 && rawPayloads.Count < totalPkts
                        rxSig = rx();
                        [decoded2, payload2, eb, ea] = tryDecodeWithErrors(rxSig, cfgPHY, config.sampleRate, config);
                        if decoded2 && length(payload2) >= 4
                            if strcmp(char(payload2(1:4)'), 'SYNC') || strcmp(char(payload2(1:4)'), 'EOS!')
                                continue;
                            end
                            % Extract sequence number correctly
                            if length(payload2) >= 2
                                seqNum2 = double(typecast(uint8(payload2(1:2)), 'uint16'));
                                if seqNum2 > 0 && seqNum2 <= totalPkts && ~isKey(rawPayloads, uint32(seqNum2))
                                    rawPayloads(uint32(seqNum2)) = payload2;
                                    
                                    % Track errors
                                    bitErrorsBeforeFEC = bitErrorsBeforeFEC + eb;
                                    bitErrorsAfterFEC = bitErrorsAfterFEC + ea;
                                    if ea < eb
                                        packetsCorrected = packetsCorrected + 1;
                                    end
                                    totalBits = totalBits + length(payload2) * 8;
                                    
                                    logMsg(sprintf('[RX] LATE pkt %d recovered', seqNum2));
                                end
                            end
                        end
                    end
                end
                continue;
            end
            
            % Handle DATA packet
            if streamConfirmed && length(payload) >= 4
                % Extract sequence number (first 2 bytes)
                seqNum = double(typecast(uint8(payload(1:2)), 'uint16'));
                
                if seqNum > 0 && seqNum <= totalPkts && seqNum < 20000 && ~isKey(rawPayloads, uint32(seqNum))
                    rawPayloads(uint32(seqNum)) = payload;
                    
                    % Update UI
                    rxPacketCount.Text = sprintf('%d/%d', rawPayloads.Count, totalPkts);
                    UPDATE_PROGRESS=(rawPayloads.Count / totalPkts) * 100;
                    updateProgressBar(fig, 'rxProgress', UPDATE_PROGRESS, 200);
                    
                    if mod(rawPayloads.Count, 10) == 0 || rawPayloads.Count == 1
                        logMsg(sprintf('[RX] pkt %d/%d (%.1f%%)', ...
                            seqNum, totalPkts, 100*rawPayloads.Count/totalPkts));
                    end
                    drawnow;
                    
                    % Update error statistics
                    updateErrorStatistics(fig, totalPkts, rawPayloads.Count, ...
                        bitErrorsBeforeFEC, bitErrorsAfterFEC, totalBits, packetsCorrected);
                    
                    % Check early exit conditions
                    if config.earlyExitEnable
                        if config.intelligentExit
                            [shouldExit, exitReason, ~] = checkIntelligentExit(...
                                rawPayloads, totalPkts, config.earlyExitThreshold, ...
                                3, config.gapStaleTime, 3, ...
                                [], [], 0, tStart);
                            
                            if shouldExit
                                logMsg(sprintf('[RX] INTELLIGENT EXIT: %s', exitReason));
                                break;
                            end
                        else
                            if isempty(thresholdMetTime) && ...
                               rawPayloads.Count >= floor(totalPkts * config.earlyExitThreshold)
                                thresholdMetTime = tic;
                                logMsg(sprintf('[RX] %.0f%% threshold met', ...
                                    100 * rawPayloads.Count / totalPkts));
                            end
                            
                            if ~isempty(thresholdMetTime) && toc(thresholdMetTime) > 15
                                logMsg('[RX] EARLY EXIT: timeout after threshold');
                                break;
                            end
                        end
                    end
                end
            end
        end
        
        % Complete check
        if streamConfirmed && ~isempty(totalPkts) && rawPayloads.Count >= totalPkts
            logMsg(sprintf('[RX] COMPLETE: %d/%d packets', rawPayloads.Count, totalPkts));
            break;
        end
        
        % Status update
        if toc(lastStatus) > 2.0
            if streamConfirmed
                logMsg(sprintf('[RX] Status: %d/%d (%.0f%%) | %.1fs', ...
                    rawPayloads.Count, totalPkts, 100*rawPayloads.Count/totalPkts, toc(tStart)));
                
                % Update error stats
                updateErrorStatistics(fig, totalPkts, rawPayloads.Count, ...
                    bitErrorsBeforeFEC, bitErrorsAfterFEC, totalBits, packetsCorrected);
            else
                logMsg(sprintf('[RX] Searching... %.1fs', toc(tStart)));
            end
            lastStatus = tic;
            drawnow;
        end
    end
    
    release(rx);
    
    % Process results
    rxStatus.Text = 'Processing...';
    logMsg('[RX] Processing received packets...');
    
    if ~streamConfirmed
        rxStatus.Text = 'No stream found';
        logMsg('[RX] ERROR: No stream locked');
        return;
    end
    
    logMsg(sprintf('[RX] Received: %d/%d (%.1f%%)', ...
        rawPayloads.Count, totalPkts, 100*rawPayloads.Count/totalPkts));
    
    % Collect packets into cell array
    rxPackets = cell(totalPkts, 1);
    missing = [];
    
    for k = 1:totalPkts
        if isKey(rawPayloads, uint32(k))
            rxPackets{k} = rawPayloads(uint32(k));
        else
            missing(end+1) = k;
        end
    end
    
    if ~isempty(missing)
        logMsg(sprintf('[RX] Missing: [%s]', num2str(missing)));
        updateMissingPacketsAnalysis(fig, missing, totalPkts);
    end
    
    % Calculate final error statistics
    updateErrorStatistics(fig, totalPkts, rawPayloads.Count, ...
        bitErrorsBeforeFEC, bitErrorsAfterFEC, totalBits, packetsCorrected);
    
    % Reconstruct file based on type
    outputDir = pwd;
    [outputFile, success] = reconstructFile(rxPackets, rxSyncInfo, outputDir);
    
    if success
        logMsg(sprintf('[RX] File saved: %s', outputFile));
        
        % Store received data in app
        appData = guidata(fig);
        appData.receivedFile = outputFile;
        appData.receivedFileType = rxSyncInfo.fileType;
        appData.totalPackets = totalPkts;
        appData.receivedPackets = rawPayloads.Count;
        appData.missingPackets = missing;
        appData.berBeforeFEC = bitErrorsBeforeFEC / max(totalBits, 1);
        appData.berAfterFEC = bitErrorsAfterFEC / max(totalBits, 1);
        appData.perBeforeFEC = (totalPkts - rawPayloads.Count) / max(totalPkts, 1);
        appData.perAfterFEC = (totalPkts - rawPayloads.Count) / max(totalPkts, 1);
        
        % Handle audio-specific features
        if strcmp(rxSyncInfo.fileType, 'AUDIO')
            try
                [audioData, audioFs] = audioread(outputFile);
                appData.receivedAudio = audioData;
                appData.receivedFs = audioFs;
                
                updateAudioDisplay(fig, audioData, audioFs, compressionUsed);
                
                playBtn = findobj(fig, 'Tag', 'playAudioBtn');
                saveBtn = findobj(fig, 'Tag', 'saveAudioBtn');
                playBtn.Enable = 'on';
                saveBtn.Enable = 'on';
                
                logMsg(sprintf('[RX] Audio: %d samples @ %d Hz', length(audioData), audioFs));
            catch ME
                logMsg(sprintf('[RX] Audio playback error: %s', ME.message));
            end
        else
            logMsg(sprintf('[RX] %s file received: %s', rxSyncInfo.fileType, rxSyncInfo.filename));
        end
        
        openFileBtn = findobj(fig, 'Tag', 'openFileBtn');
        if ~isempty(openFileBtn)
            openFileBtn.Enable = 'on';
        end
        guidata(fig, appData);
    else
        logMsg('[RX] ERROR: File reconstruction failed');
    end
    
    % Update statistics
    updateStatistics(fig, totalPkts, rawPayloads.Count, missing, totalDecodes, toc(tStart));
    
    rxStatus.Text = 'Complete';
    updateProgressBar(fig, 'rxProgress', 100, 200);
    
    logMsg(sprintf('[RX] === RECEPTION COMPLETE: %s ===', rxSyncInfo.fileType));
end

%% =============== HELPER FUNCTIONS ===============

function [cfgPHY, cfgMAC] = buildConfigs(CBW, MCS)
    cfgPHY = wlanNonHTConfig;
    cfgPHY.ChannelBandwidth = CBW;
    cfgPHY.MCS = MCS;
    cfgPHY.NumTransmitAntennas = 1;
    
    cfgMAC = wlanMACFrameConfig('FrameType', 'Data', ...
        'Address1', '001122334455', 'Address2', 'AABBCCDDEEFF', 'Address3', 'FFEEDDCCBBAA');
end

function [compressed, ratio] = compressAudio(audio, fs, quality)
    % Improved compression with anti-aliasing
    if quality <= 3
        downsample_factor = 4;
    elseif quality <= 6
        downsample_factor = 2;
    else
        downsample_factor = 1;
    end
    
    if downsample_factor > 1
        % Apply anti-aliasing filter before downsampling
        cutoff = 0.8 / downsample_factor;
        [b, a] = butter(6, cutoff);
        audioFiltered = filtfilt(b, a, audio);
        compressed = audioFiltered(1:downsample_factor:end);
    else
        compressed = audio;
    end
    
    ratio = length(audio) / length(compressed);
end

function decompressed = decompressAudio(compressed, fs, quality, ratio)
    % Decompress audio with proper interpolation
    
    if quality <= 3
        upsample_factor = 4;
    elseif quality <= 6
        upsample_factor = 2;
    else
        upsample_factor = 1;
    end
    
    if upsample_factor > 1
        % Use interp function for smoother upsampling
        n = length(compressed);
        xOrig = 1:n;
        xNew = 1:(1/upsample_factor):n;
        decompressed = interp1(xOrig, compressed, xNew, 'spline')';
    else
        decompressed = compressed;
    end
    
    % Gentle normalization
    maxVal = max(abs(decompressed));
    if maxVal > 0.95
        decompressed = decompressed * 0.9 / maxVal;
    end
end

function [ok, payload, errorsBefore, errorsAfter] = tryDecodeWithErrors(rxSig, cfgPHY, fsRF, config)
    ok = false;
    payload = [];
    errorsBefore = 0;
    errorsAfter = 0;
    
    try
        pktOffset = wlanPacketDetect(rxSig, cfgPHY.ChannelBandwidth);
        if isempty(pktOffset); return; end
        
        ind = wlanFieldIndices(cfgPHY);
        
        lstf = rxSig(pktOffset+ind.LSTF(1):pktOffset+ind.LSTF(2));
        coarseCFO = wlanCoarseCFOEstimate(lstf, cfgPHY.ChannelBandwidth);
        pfOffset = comm.PhaseFrequencyOffset('SampleRate', fsRF, 'FrequencyOffsetSource', 'Input port');
        rxCFO = pfOffset(rxSig, -coarseCFO);
        
        nonHT = rxCFO(pktOffset+ind.LSTF(1):pktOffset+ind.LSIG(2));
        timingOffset = wlanSymbolTimingEstimate(nonHT, cfgPHY.ChannelBandwidth, 0.7);
        pktOffset = pktOffset + timingOffset;
        
        lltf = rxCFO(pktOffset+ind.LLTF(1):pktOffset+ind.LLTF(2));
        fineCFO = wlanFineCFOEstimate(lltf, cfgPHY.ChannelBandwidth);
        rxSync = pfOffset(rxCFO, -fineCFO);
        
        lltfCorr = rxSync(pktOffset+ind.LLTF(1):pktOffset+ind.LLTF(2));
        demLLTF = wlanLLTFDemodulate(lltfCorr, cfgPHY.ChannelBandwidth);
        H = wlanLLTFChannelEstimate(demLLTF, cfgPHY.ChannelBandwidth);
        noiseVar = wlanLLTFNoiseEstimate(demLLTF);
        
        lsig = rxSync(pktOffset+ind.LSIG(1):pktOffset+ind.LSIG(2));
        [~, failCheck] = wlanLSIGRecover(lsig, H, noiseVar, cfgPHY.ChannelBandwidth);
        if failCheck; return; end
        
        cfgPHY2 = cfgPHY;
        cfgPHY2.PSDULength = 2304 + 24 + 4;
        
        indData = wlanFieldIndices(cfgPHY2, 'NonHT-Data');
        if pktOffset + indData(2) > length(rxSync); return; end
        dataField = rxSync(pktOffset+indData(1):pktOffset+indData(2));
        
        [rxBits, ~] = wlanNonHTDataRecover(dataField, H, noiseVar, cfgPHY2);
        
        % Estimate errors (simplified - count flipped bits in known patterns)
        errorsBefore = estimateBitErrors(rxBits);
        
        rxBits = rxBits(:);
        numBytes = floor(length(rxBits) / 8);
        rxBits = double(rxBits(1:numBytes*8));
        rxBitsMatrix = reshape(rxBits, 8, numBytes).';
        rxBytes = uint8(bi2de(rxBitsMatrix, 'right-msb'));
        
        if length(rxBytes) <= 28; return; end
        
        payload = rxBytes(25:end-4);
        
        if length(payload) < 8; return; end
        
        % Estimate errors after decoding
        errorsAfter = estimateBitErrorsAfterFEC(payload, config);
        
        ok = true;
    catch
    end
end

function errors = estimateBitErrors(bits)
    % Simplified bit error estimation based on LLR values
    % This is a placeholder - in real implementation, you would compare with known bits
    errors = 0;
    
    % Use LLR magnitude to estimate errors
    % Bits with LLR near 0 are more likely to be errors
    if ~isempty(bits)
        llr = abs(bits);
        % Count bits with low confidence (LLR < 0.5)
        errors = sum(llr < 0.5);
    end
end

function errors = estimateBitErrorsAfterFEC(payload, config)
    % Estimate errors after FEC based on packet validity
    errors = 0;
    
    % Simple heuristic: count invalid bytes or patterns
    if length(payload) > 4
        % Check for common invalid patterns
        invalidCount = 0;
        for i = 1:length(payload)-3
            % Count consecutive zeros or 255s (common in errors)
            if payload(i) == 0 && payload(i+1) == 0 && payload(i+2) == 0 && payload(i+3) == 0
                invalidCount = invalidCount + 4;
            elseif payload(i) == 255 && payload(i+1) == 255 && payload(i+2) == 255 && payload(i+3) == 255
                invalidCount = invalidCount + 4;
            end
        end
        errors = invalidCount;
    end
end

function [rsN, rsK] = parseRSParams(rsCodeRateStr)
    if contains(rsCodeRateStr, '239')
        rsN = 255; rsK = 239;
    elseif contains(rsCodeRateStr, '223')
        rsN = 255; rsK = 223;
    elseif contains(rsCodeRateStr, '191')
        rsN = 255; rsK = 191;
    elseif contains(rsCodeRateStr, '127')
        rsN = 255; rsK = 127;
    else
        rsN = 255; rsK = 223;
    end
end

function encodedData = applyRSEncoding(data, rsN, rsK, useInterleaving)
    try
        rsEncoder = comm.RSEncoder(rsN, rsK, 'BitInput', false);
        
        dataLen = length(data);
        padLen = ceil(dataLen / rsK) * rsK - dataLen;
        paddedData = [data; zeros(padLen, 1, 'uint8')];
        
        numBlocks = length(paddedData) / rsK;
        dataBlocks = reshape(paddedData, rsK, numBlocks);
        
        encodedBlocks = zeros(rsN, numBlocks, 'uint8');
        for i = 1:numBlocks
            encodedBlocks(:, i) = step(rsEncoder, dataBlocks(:, i));
        end
        
        if useInterleaving
            encodedBlocks = interleaverFcn(encodedBlocks);
        end
        
        encodedFlat = encodedBlocks(:);
        lengthBytes = typecast(uint32(dataLen), 'uint8');
        encodedData = [lengthBytes(:); encodedFlat];
        
        release(rsEncoder);
    catch
        encodedData = data;
    end
end

function decodedData = applyRSDecoding(data, rsN, rsK, useInterleaving)
    try
        if length(data) < 5
            decodedData = data;
            return;
        end
        
        lengthBytes = data(1:4);
        originalLen = double(typecast(uint8(lengthBytes), 'uint32'));
        encodedData = data(5:end);
        
        rsDecoder = comm.RSDecoder(rsN, rsK, 'BitInput', false);
        
        expectedBlocks = ceil(originalLen / rsK);
        expectedLen = expectedBlocks * rsN;
        
        if length(encodedData) < expectedLen
            encodedData = [encodedData; zeros(expectedLen - length(encodedData), 1, 'uint8')];
        end
        encodedData = encodedData(1:expectedLen);
        
        encodedBlocks = reshape(encodedData, rsN, expectedBlocks);
        
        if useInterleaving
            encodedBlocks = deinterleaverFcn(encodedBlocks);
        end
        
        decodedBlocks = zeros(rsK, expectedBlocks, 'uint8');
        for i = 1:expectedBlocks
            [decodedBlocks(:, i), ~] = step(rsDecoder, encodedBlocks(:, i));
        end
        
        decodedFlat = decodedBlocks(:);
        decodedData = decodedFlat(1:originalLen);
        
        release(rsDecoder);
    catch
        decodedData = data;
    end
end

function interleavedData = interleaverFcn(data)
    [rows, cols] = size(data);
    interleavedData = reshape(data', cols, rows)';
end

function deinterleavedData = deinterleaverFcn(data)
    [rows, cols] = size(data);
    deinterleavedData = reshape(data', cols, rows)';
end

function [shouldExit, reason, gaps] = checkIntelligentExit(payloads, total, threshold, ...
    maxGaps, staleTime, minChecks, lastSig, firstSeen, count, startTime)
    
    shouldExit = false;
    reason = '';
    gaps = [];
    
    if payloads.Count < floor(total * threshold)
        return;
    end
    
    received = cell2mat(keys(payloads));
    allSeqs = 1:total;
    gaps = setdiff(allSeqs, received);
    
    if isempty(gaps)
        shouldExit = true;
        reason = 'All packets received';
        return;
    end
    
    if length(gaps) <= maxGaps
        currentSig = sprintf('%s', num2str(sort(gaps)));
        
        persistent lastSignature firstSeenTime sameCount;
        if isempty(lastSignature)
            lastSignature = '';
            firstSeenTime = [];
            sameCount = 0;
        end
        
        if strcmp(currentSig, lastSignature)
            sameCount = sameCount + 1;
            if sameCount >= minChecks && ~isempty(firstSeenTime) && toc(firstSeenTime) >= staleTime
                shouldExit = true;
                reason = sprintf('%d gaps stable for %.1fs', length(gaps), toc(firstSeenTime));
            end
        else
            lastSignature = currentSig;
            firstSeenTime = tic;
            sameCount = 1;
        end
    end
end

function updateStatistics(fig, total, received, missing, decodes, elapsed)
    statTotal = findobj(fig, 'Tag', 'statTotalPkts');
    statReceived = findobj(fig, 'Tag', 'statReceived');
    statMissing = findobj(fig, 'Tag', 'statMissing');
    statRate = findobj(fig, 'Tag', 'statSuccessRate');
    statDecodes = findobj(fig, 'Tag', 'statDecodes');
    statElapsed = findobj(fig, 'Tag', 'statElapsed');
    
    statTotal.Text = num2str(total);
    statReceived.Text = num2str(received);
    statMissing.Text = num2str(length(missing));
    statRate.Text = sprintf('%.1f%%', 100 * received / total);
    statDecodes.Text = num2str(decodes);
    statElapsed.Text = sprintf('%.1fs', elapsed);
    
    ax = findobj(fig, 'Tag', 'packetChart');
    cla(ax);
    
    receivedIdx = setdiff(1:total, missing);
    bar(ax, receivedIdx, ones(size(receivedIdx)), 'g', 'EdgeColor', 'none');
    hold(ax, 'on');
    if ~isempty(missing)
        bar(ax, missing, ones(size(missing)), 'r', 'EdgeColor', 'none');
    end
    hold(ax, 'off');
    
    xlim(ax, [0 total+1]);
    ylim(ax, [0 1.5]);
    legend(ax, {'Received', 'Missing'}, 'Location', 'northeast');
end

function updateErrorStatistics(fig, totalPkts, receivedPkts, bitErrorsBefore, bitErrorsAfter, totalBits, packetsCorrected)
    % Calculate error rates
    perBefore = (totalPkts - receivedPkts) / max(totalPkts, 1);
    perAfter = perBefore;  % Assuming missing packets are still missing after FEC
    
    berBefore = bitErrorsBefore / max(totalBits, 1);
    berAfter = bitErrorsAfter / max(totalBits, 1);
    
    % Update UI
    perBeforeLabel = findobj(fig, 'Tag', 'perBeforeFEC');
    perAfterLabel = findobj(fig, 'Tag', 'perAfterFEC');
    berBeforeLabel = findobj(fig, 'Tag', 'berBeforeFEC');
    berAfterLabel = findobj(fig, 'Tag', 'berAfterFEC');
    packetsCorrectedLabel = findobj(fig, 'Tag', 'packetsCorrected');
    totalBitsLabel = findobj(fig, 'Tag', 'totalBits');
    bitErrorsBeforeLabel = findobj(fig, 'Tag', 'bitErrorsBefore');
    bitErrorsAfterLabel = findobj(fig, 'Tag', 'bitErrorsAfter');
    
    perBeforeLabel.Text = sprintf('%.3f%%', perBefore * 100);
    perAfterLabel.Text = sprintf('%.3f%%', perAfter * 100);
    berBeforeLabel.Text = sprintf('%.2e', berBefore);
    berAfterLabel.Text = sprintf('%.2e', berAfter);
    packetsCorrectedLabel.Text = num2str(packetsCorrected);
    totalBitsLabel.Text = sprintf('%.0f', totalBits);
    bitErrorsBeforeLabel.Text = sprintf('%.0f', bitErrorsBefore);
    bitErrorsAfterLabel.Text = sprintf('%.0f', bitErrorsAfter);
    
    % Store in app data
    appData = guidata(fig);
    appData.berBeforeFEC = berBefore;
    appData.berAfterFEC = berAfter;
    appData.perBeforeFEC = perBefore;
    appData.perAfterFEC = perAfter;
    guidata(fig, appData);
end

function updateMissingPacketsAnalysis(fig, missing, total)
    missingList = findobj(fig, 'Tag', 'missingPacketsList');
    patternAnalysis = findobj(fig, 'Tag', 'patternAnalysis');
    
    if isempty(missing)
        missingList.Value = {'None - All packets received!'};
        patternAnalysis.Value = {'Perfect reception'};
        return;
    end
    
    missingList.Value = {sprintf('Missing sequences: [%s]', num2str(missing))};
    
    analysis = {};
    
    if all(missing > total - 10)
        analysis{end+1} = '⚠️ TAIL PACKET ISSUE DETECTED';
        analysis{end+1} = 'Most missing packets are at the end';
        analysis{end+1} = 'Recommendations:';
        analysis{end+1} = '  - Increase Tail Repeats';
        analysis{end+1} = '  - Increase Tail Count';
        analysis{end+1} = '  - Increase Final Delay';
        analysis{end+1} = '  - Enable Extended RX Wait';
    end
    
    diffs = diff(missing);
    if all(diffs == 1)
        analysis{end+1} = '⚠️ Consecutive packet loss detected';
        analysis{end+1} = 'May indicate burst errors';
        analysis{end+1} = 'Try enabling RS encoding';
    end
    
    analysis{end+1} = '';
    analysis{end+1} = sprintf('Total missing: %d (%.1f%%)', length(missing), 100*length(missing)/total);
    analysis{end+1} = sprintf('First missing: %d', missing(1));
    analysis{end+1} = sprintf('Last missing: %d', missing(end));
    
    patternAnalysis.Value = analysis;
end

function updateAudioDisplay(fig, audio, fs, compressed)
    ax = findobj(fig, 'Tag', 'audioWaveform');
    
    if ~isempty(audio)
        t = (0:length(audio)-1) / fs;
        plot(ax, t, audio);
        xlabel(ax, 'Time (s)');
        ylabel(ax, 'Amplitude');
        title(ax, 'Received Audio Waveform');
        ax.Visible = 'on';
    else
        ax.Visible = 'off';
    end
    
    fsLabel = findobj(fig, 'Tag', 'audioFs');
    durLabel = findobj(fig, 'Tag', 'audioDuration');
    sampLabel = findobj(fig, 'Tag', 'audioSamples');
    compLabel = findobj(fig, 'Tag', 'audioCompression');
    
    fsLabel.Text = sprintf('%d Hz', fs);
    durLabel.Text = sprintf('%.3f s', length(audio)/fs);
    sampLabel.Text = num2str(length(audio));
    compLabel.Text = string(compressed);
end

function [fileType, fileTypeCode] = detectFileType(filePath)
    [~, ~, fileExt] = fileparts(filePath);
    fileExt = lower(fileExt);
    
    % Remove any leading dots
    if ~isempty(fileExt) && fileExt(1) == '.'
        fileExt = fileExt(2:end);
    end
    
    audioExtensions = {'wav', 'mp3', 'm4a', 'flac', 'ogg', 'aac', 'wma'};
    videoExtensions = {'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'mpeg', 'mpg', '3gp', 'm4v'};
    imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'tif'};
    
    if any(strcmp(fileExt, audioExtensions))
        fileType = 'AUDIO';
        fileTypeCode = uint8(1);
    elseif any(strcmp(fileExt, videoExtensions))
        fileType = 'VIDEO';
        fileTypeCode = uint8(5);
    elseif any(strcmp(fileExt, imageExtensions))
        fileType = 'IMAGE';
        fileTypeCode = uint8(6);
    elseif strcmp(fileExt, 'pdf')
        fileType = 'PDF';
        fileTypeCode = uint8(2);
    elseif strcmp(fileExt, 'docx') || strcmp(fileExt, 'doc')
        fileType = 'DOCX';
        fileTypeCode = uint8(3);
    elseif strcmp(fileExt, 'txt') || strcmp(fileExt, 'rtf')
        fileType = 'TXT';
        fileTypeCode = uint8(4);
    elseif strcmp(fileExt, 'xlsx') || strcmp(fileExt, 'xls') || strcmp(fileExt, 'csv')
        fileType = 'XLSX';
        fileTypeCode = uint8(7);
    elseif strcmp(fileExt, 'pptx') || strcmp(fileExt, 'ppt')
        fileType = 'PPTX';
        fileTypeCode = uint8(8);
    else
        fileType = 'BINARY';
        fileTypeCode = uint8(255);
    end
end

function fileTypeName = getFileTypeName(fileTypeCode)
    switch fileTypeCode
        case 1, fileTypeName = 'AUDIO';
        case 2, fileTypeName = 'PDF';
        case 3, fileTypeName = 'DOCX';
        case 4, fileTypeName = 'TXT';
        case 5, fileTypeName = 'VIDEO';
        case 6, fileTypeName = 'IMAGE';
        case 7, fileTypeName = 'XLSX';
        case 8, fileTypeName = 'PPTX';
        otherwise, fileTypeName = 'BINARY';
    end
end

function [fileBytes, fileMetadata] = readFileForTransmission(filePath, config)
    [~, fileName, fileExt] = fileparts(filePath);
    fileExt = lower(fileExt);
    [fileType, fileTypeCode] = detectFileType(filePath);
    
    fileMetadata = struct();
    fileMetadata.fileName = [fileName, fileExt];
    fileMetadata.fileExt = fileExt;
    fileMetadata.fileType = fileType;
    fileMetadata.fileTypeCode = fileTypeCode;
    
    % Override file type based on user selection if not "Auto Detect"
    fileTypeSelect = findobj('Tag', 'fileTypeSelect');
    if ~isempty(fileTypeSelect)
        selectedType = fileTypeSelect.Value;
        if ~strcmp(selectedType, 'Auto Detect')
            switch selectedType
                case 'Audio'
                    fileType = 'AUDIO';
                    fileTypeCode = uint8(1);
                case 'Video'
                    fileType = 'VIDEO';
                    fileTypeCode = uint8(5);
                case 'Image'
                    fileType = 'IMAGE';
                    fileTypeCode = uint8(6);
                case 'Document'
                    % Check specific document type
                    if strcmp(fileExt, '.pdf')
                        fileType = 'PDF';
                        fileTypeCode = uint8(2);
                    elseif strcmp(fileExt, '.docx') || strcmp(fileExt, '.doc')
                        fileType = 'DOCX';
                        fileTypeCode = uint8(3);
                    elseif strcmp(fileExt, '.txt') || strcmp(fileExt, '.rtf')
                        fileType = 'TXT';
                        fileTypeCode = uint8(4);
                    else
                        fileType = 'BINARY';
                        fileTypeCode = uint8(255);
                    end
                otherwise
                    fileType = 'BINARY';
                    fileTypeCode = uint8(255);
            end
            fileMetadata.fileType = fileType;
            fileMetadata.fileTypeCode = fileTypeCode;
        end
    end
    
    switch fileType
        case 'AUDIO'
            [x, fsIn] = audioread(filePath);
            
            if size(x, 2) > 1
                x = mean(x, 2);
            end
            
            targetFs = config.targetFs;
            if fsIn ~= targetFs
                x = resample(x, targetFs, fsIn);
            end
            fsAudio = targetFs;
            
            x = x / (max(abs(x)) + eps);
            
            if config.useCompression
                [x, compRatio] = compressAudio(x, fsAudio, config.compQuality);
                fileMetadata.compressionRatio = compRatio;
                fileMetadata.compressionUsed = true;
                fileMetadata.compressionQuality = config.compQuality;
            else
                fileMetadata.compressionRatio = 1.0;
                fileMetadata.compressionUsed = false;
                fileMetadata.compressionQuality = 0;
            end
            
            pcm = int16(x * 32767);
            fileBytes = typecast(pcm, 'uint8');
            
            fileMetadata.audioFs = uint16(min(fsAudio, 65535));
            fileMetadata.audioSamples = uint32(length(pcm));
            fileMetadata.originalFs = fsIn;
            
        case 'IMAGE'
            % Read image file
            try
                img = imread(filePath);
                
                % Store image metadata
                fileMetadata.imageHeight = size(img, 1);
                fileMetadata.imageWidth = size(img, 2);
                fileMetadata.imageChannels = size(img, 3);
                
                % Convert to JPEG bytes with specified quality
                tempFile = tempname;
                quality = config.imageQuality;
                if isfield(config, 'imageQuality') && config.imageQuality > 0
                    imwrite(img, tempFile, 'jpg', 'Quality', quality);
                else
                    imwrite(img, tempFile, 'jpg');
                end
                
                fid = fopen(tempFile, 'rb');
                fileBytes = fread(fid, '*uint8');
                fclose(fid);
                delete(tempFile);
                
                fileMetadata.compressionUsed = true;
                fileMetadata.compressionRatio = 1.0;
                
            catch ME
                % Fallback: read as binary file
                fid = fopen(filePath, 'rb');
                if fid == -1
                    error('Cannot open file: %s', filePath);
                end
                fileBytes = fread(fid, '*uint8');
                fclose(fid);
                
                fileMetadata.compressionUsed = false;
                fileMetadata.compressionRatio = 1.0;
            end
            
        otherwise
            % For all other file types (PDF, DOCX, TXT, BINARY, etc.)
            fid = fopen(filePath, 'rb');
            if fid == -1
                error('Cannot open file: %s', filePath);
            end
            fileBytes = fread(fid, '*uint8');
            fclose(fid);
            
            fileMetadata.compressionUsed = false;
            fileMetadata.compressionRatio = 1.0;
    end
    
    fileMetadata.totalBytes = length(fileBytes);
    
    fileInfo = dir(filePath);
    fileMetadata.originalSize = fileInfo.bytes;
end

function [outputFile, success] = reconstructFile(rxDataPackets, syncInfo, outputDir)
    % Reconstruct file from received packets - FIXED VERSION
    
    success = false;
    outputFile = '';
    
    try
        fprintf('[RX] Starting reconstruction: %s, %d packets, %d bytes expected\n', ...
            syncInfo.fileType, syncInfo.numDataPackets, syncInfo.totalFileSize);
        
        % Reassemble all data
        allFileData = [];
        
        for pktIdx = 1:syncInfo.numDataPackets
            if isempty(rxDataPackets{pktIdx}) || length(rxDataPackets{pktIdx}) < 4
                % Missing or invalid packet
                missingSize = syncInfo.lastPacketSize; % Use last packet size as default
                if pktIdx < syncInfo.numDataPackets
                    % Estimate size for non-last packets
                    avgSize = ceil(syncInfo.totalFileSize / syncInfo.numDataPackets);
                    missingSize = avgSize;
                end
                placeholder = zeros(missingSize, 1, 'uint8');
                allFileData = [allFileData; placeholder];
                fprintf('[RX] Warning: Packet %d missing, inserting %d zero bytes\n', pktIdx, missingSize);
                continue;
            end
            
            pktData = uint8(rxDataPackets{pktIdx});
            
            % Verify this is a data packet (not SYNC or EOS)
            if length(pktData) >= 4
                firstFour = char(pktData(1:4)');
                if strcmp(firstFour, 'SYNC') || strcmp(firstFour, 'EOS!')
                    fprintf('[RX] Skipping non-data packet type: %s\n', firstFour);
                    continue;
                end
            end
            
            % Extract payload length from header (bytes 3-4)
            payloadLen = double(typecast(uint8(pktData(3:4)), 'uint16'));
            
            % Validate payloadLen
            if payloadLen > 0 && payloadLen <= 2200 && length(pktData) >= 4 + payloadLen
                fileData = pktData(5:4+payloadLen);
                fprintf('[RX] Packet %d: %d bytes payload\n', pktIdx, payloadLen);
            elseif length(pktData) > 4
                % Fallback: use all remaining data
                fileData = pktData(5:end);
                fprintf('[RX] Packet %d: using all %d bytes (header missing/invalid)\n', pktIdx, length(fileData));
            else
                fileData = [];
                fprintf('[RX] Packet %d: no data\n', pktIdx);
            end
            
            allFileData = [allFileData; fileData(:)];
        end
        
        fprintf('[RX] Assembled %d bytes from packets\n', length(allFileData));
        
        % Trim to actual file size
        if isfield(syncInfo, 'totalFileSize') && syncInfo.totalFileSize > 0
            if length(allFileData) > syncInfo.totalFileSize
                allFileData = allFileData(1:syncInfo.totalFileSize);
                fprintf('[RX] Trimmed to %d bytes\n', length(allFileData));
            elseif length(allFileData) < syncInfo.totalFileSize
                % Pad with zeros if we have less data
                paddingNeeded = syncInfo.totalFileSize - length(allFileData);
                allFileData = [allFileData; zeros(paddingNeeded, 1, 'uint8')];
                fprintf('[RX] Padded %d zero bytes to reach %d bytes\n', paddingNeeded, syncInfo.totalFileSize);
            end
        end
        
        % Generate safe output filename
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        
        % Determine file extension
        switch syncInfo.fileType
            case 'AUDIO'
                ext = 'wav';
            case 'PDF'
                ext = 'pdf';
            case 'DOCX'
                ext = 'docx';
            case 'TXT'
                ext = 'txt';
            case 'VIDEO'
                ext = 'mp4';
            case 'IMAGE'
                ext = 'jpg';
            case 'XLSX'
                ext = 'xlsx';
            case 'PPTX'
                ext = 'pptx';
            otherwise
                ext = 'bin';
        end
        
        outputFile = fullfile(outputDir, sprintf('received_%s_%s.%s', ...
            lower(syncInfo.fileType), timestamp, ext));
        
        fprintf('[RX] Output file: %s\n', outputFile);
        
        switch syncInfo.fileType
            case 'AUDIO'
                fprintf('[RX] Processing as AUDIO file\n');
                
                % Ensure even number of bytes for int16 conversion
                if mod(length(allFileData), 2) ~= 0
                    allFileData = allFileData(1:end-1);
                    fprintf('[RX] Trimmed 1 byte to make even length\n');
                end
                
                if isempty(allFileData)
                    error('No audio data to process');
                end
                
                pcmRx = typecast(allFileData, 'int16');
                audioRx = double(pcmRx) / 32768.0;
                
                fprintf('[RX] Converted to %d audio samples\n', length(audioRx));
                
                % Get sample rate with validation
                fs = 44100;  % Default
                if isfield(syncInfo, 'audioFs') && syncInfo.audioFs >= 4000 && syncInfo.audioFs <= 48000
                    fs = double(syncInfo.audioFs);
                end
                fprintf('[RX] Sample rate: %d Hz\n', fs);
                
                % Decompress if needed
                if isfield(syncInfo, 'compressionUsed') && syncInfo.compressionUsed
                    compQ = 10;
                    if isfield(syncInfo, 'compressionQuality')
                        compQ = syncInfo.compressionQuality;
                    end
                    fprintf('[RX] Decompressing audio (Q=%d)\n', compQ);
                    audioRx = decompressAudio(audioRx, fs, compQ, 1.0);
                    fprintf('[RX] Decompressed to %d samples\n', length(audioRx));
                end
                
                % Ensure valid audio range
                audioRx = max(-1, min(1, audioRx));
                
                % Save audio file
                fprintf('[RX] Saving audio: %d samples @ %d Hz\n', length(audioRx), fs);
                audiowrite(outputFile, audioRx, fs);
                fprintf('[RX] Audio saved successfully\n');
                
            case 'IMAGE'
                fprintf('[RX] Processing as IMAGE file\n');
                
                % Write image data to file
                fid = fopen(outputFile, 'wb');
                if fid == -1
                    error('Cannot create output file: %s', outputFile);
                end
                fwrite(fid, allFileData, 'uint8');
                fclose(fid);
                
                fprintf('[RX] Image saved: %s (%d bytes)\n', outputFile, length(allFileData));
                
            otherwise
                fprintf('[RX] Processing as %s file\n', syncInfo.fileType);
                
                fid = fopen(outputFile, 'wb');
                if fid == -1
                    error('Cannot create output file: %s', outputFile);
                end
                fwrite(fid, allFileData, 'uint8');
                fclose(fid);
                
                fprintf('[RX] File saved: %s (%d bytes)\n', outputFile, length(allFileData));
        end
        
        success = true;
        fprintf('[RX] Reconstruction SUCCESS\n');
        
    catch ME
        fprintf('[RX] Reconstruction error: %s\n', ME.message);
        fprintf('[RX] Error identifier: %s\n', ME.identifier);
        if ~isempty(ME.stack)
            for i = 1:min(3, length(ME.stack))
                fprintf('[RX] Stack %d: %s line %d\n', i, ME.stack(i).name, ME.stack(i).line);
            end
        end
        success = false;
    end
end

function [valid, syncInfo] = parseMultiFileSyncPacket(payload)
    valid = false;
    syncInfo = struct();
    
    try
        if length(payload) < 18
            return;
        end
        
        % Ensure payload is uint8
        payload = uint8(payload);
        
        idx = 1;
        
        % Check magic bytes "SYNC"
        if ~strcmp(char(payload(1:4)'), 'SYNC')
            return;
        end
        idx = idx + 4;
        
        % Protocol version (1 byte)
        syncInfo.version = double(payload(idx));
        idx = idx + 1;
        
        % Skip mu-law parameter (2 bytes)
        idx = idx + 2;
        
        % File type code (1 byte)
        syncInfo.fileTypeCode = double(payload(idx));
        syncInfo.fileType = getFileTypeName(syncInfo.fileTypeCode);
        idx = idx + 1;
        
        % Number of data packets (2 bytes)
        syncInfo.numDataPackets = double(typecast(payload(idx:idx+1), 'uint16'));
        idx = idx + 2;
        
        % Total file size (4 bytes)
        syncInfo.totalFileSize = double(typecast(payload(idx:idx+3), 'uint32'));
        idx = idx + 4;
        
        % Last packet size (2 bytes)
        syncInfo.lastPacketSize = double(typecast(payload(idx:idx+1), 'uint16'));
        idx = idx + 2;
        
        % File extension (variable length)
        if idx <= length(payload)
            extLen = double(payload(idx));
            idx = idx + 1;
            
            if extLen > 0 && extLen <= 10 && idx + extLen - 1 <= length(payload)
                extBytes = payload(idx:idx+extLen-1);
                syncInfo.extension = char(extBytes');
                idx = idx + extLen;
            else
                syncInfo.extension = 'bin';
            end
        else
            syncInfo.extension = 'bin';
        end
        
        % Filename (variable length)
        if idx <= length(payload)
            nameLen = double(payload(idx));
            idx = idx + 1;
            
            if nameLen > 0 && nameLen <= 50 && idx + nameLen - 1 <= length(payload)
                nameBytes = payload(idx:idx+nameLen-1);
                syncInfo.filename = char(nameBytes');
                idx = idx + nameLen;
            else
                syncInfo.filename = ['received_file.' syncInfo.extension];
            end
        else
            syncInfo.filename = ['received_file.' syncInfo.extension];
        end
        
        % Audio metadata (if audio file)
        if syncInfo.fileTypeCode == 1 && idx + 6 <= length(payload)
            audioFs = double(typecast(payload(idx:idx+1), 'uint16'));
            idx = idx + 2;
            
            if audioFs >= 4000 && audioFs <= 48000
                syncInfo.audioFs = audioFs;
            else
                syncInfo.audioFs = 44100;
            end
            
            syncInfo.audioSamples = double(typecast(payload(idx:idx+3), 'uint32'));
            idx = idx + 4;
            
            % Compression info
            if idx + 6 <= length(payload)
                syncInfo.compressionUsed = payload(idx) == 1;
                idx = idx + 1;
                
                syncInfo.compressionQuality = double(payload(idx));
                idx = idx + 1;
                
                if idx + 3 <= length(payload)
                    syncInfo.compressionRatio = double(typecast(payload(idx:idx+3), 'single'));
                    idx = idx + 4;
                end
            end
        end
        
        valid = true;
        
    catch ME
        fprintf('[RX] Sync parse error: %s\n', ME.message);
        % Still mark as valid if we got the essential fields
        if isfield(syncInfo, 'numDataPackets') && syncInfo.numDataPackets > 0
            valid = true;
        end
    end
end

function txPackets = packetizeFile(fileBytes, fileMetadata, maxDataPerPacket)
    % Fixed header size (always 4 bytes)
    dataPacketHeaderBytes = 4;
    
    if nargin < 3 || isempty(maxDataPerPacket)
        maxPayloadBytes = 2200;
        maxDataPerPacket = maxPayloadBytes - dataPacketHeaderBytes;
    end
    
    totalBytes = length(fileBytes);
    numPkts = ceil(totalBytes / maxDataPerPacket);
    txPackets = cell(numPkts, 1);
    
    for pktIdx = 1:numPkts
        startByte = (pktIdx-1) * maxDataPerPacket + 1;
        
        if pktIdx == numPkts
            endByte = totalBytes;
        else
            endByte = startByte + maxDataPerPacket - 1;
        end
        
        pktFileData = fileBytes(startByte:endByte);
        pktDataLen = length(pktFileData);
        
        header = uint8(zeros(dataPacketHeaderBytes, 1));
        header(1:2) = typecast(uint16(pktIdx), 'uint8');
        header(3:4) = typecast(uint16(pktDataLen), 'uint8');
        
        txPackets{pktIdx} = [header; pktFileData(:)];
    end
end

function syncPackets = createMultiFileSyncPackets(numDataPkts, fileMetadata, numSync, config)
    syncPackets = cell(numSync, 1);
    
    for i = 1:numSync
        syncPacket = uint8([]);
        
        syncPacket = [syncPacket; uint8('S'); uint8('Y'); uint8('N'); uint8('C')];
        syncPacket = [syncPacket; uint8(1)];
        syncPacket = [syncPacket; typecast(uint16(255), 'uint8')'];
        syncPacket = [syncPacket; fileMetadata.fileTypeCode];
        syncPacket = [syncPacket; typecast(uint16(numDataPkts), 'uint8')'];
        syncPacket = [syncPacket; typecast(uint32(fileMetadata.totalBytes), 'uint8')'];
        
        maxDataPerPacket = 2200 - 4;
        if isfield(fileMetadata, 'maxDataPerPacket')
            maxDataPerPacket = fileMetadata.maxDataPerPacket;
        end
        lastPacketSize = mod(fileMetadata.totalBytes, maxDataPerPacket);
        if lastPacketSize == 0 && fileMetadata.totalBytes > 0
            lastPacketSize = maxDataPerPacket;
        end
        syncPacket = [syncPacket; typecast(uint16(lastPacketSize), 'uint8')'];
        
        extStr = fileMetadata.fileExt;
        if startsWith(extStr, '.')
            extStr = extStr(2:end);
        end
        extBytes = uint8(extStr);
        extLen = uint8(min(length(extBytes), 10));
        syncPacket = [syncPacket; extLen; extBytes(1:extLen)'];
        
        nameBytes = uint8(fileMetadata.fileName);
        nameLen = uint8(min(length(nameBytes), 50));
        syncPacket = [syncPacket; nameLen; nameBytes(1:nameLen)'];
        
        if strcmp(fileMetadata.fileType, 'AUDIO')
            syncPacket = [syncPacket; typecast(fileMetadata.audioFs, 'uint8')'];
            syncPacket = [syncPacket; typecast(fileMetadata.audioSamples, 'uint8')'];
            syncPacket = [syncPacket; uint8(fileMetadata.compressionUsed)];
            syncPacket = [syncPacket; uint8(fileMetadata.compressionQuality)];
            syncPacket = [syncPacket; typecast(single(fileMetadata.compressionRatio), 'uint8')'];
        elseif strcmp(fileMetadata.fileType, 'IMAGE')
            if isfield(fileMetadata, 'imageHeight')
                syncPacket = [syncPacket; typecast(uint16(fileMetadata.imageHeight), 'uint8')'];
                syncPacket = [syncPacket; typecast(uint16(fileMetadata.imageWidth), 'uint8')'];
                syncPacket = [syncPacket; uint8(fileMetadata.imageChannels)];
            end
        end
        
        syncPacket = [syncPacket; uint8(config.tailCount)];
        syncPacket = [syncPacket; uint8(config.eosMarkers)];
        
        crc = crc16(syncPacket);
        syncPacket = [syncPacket; typecast(uint16(crc), 'uint8')'];
        
        syncPackets{i} = syncPacket;
    end
end

function eosPacket = createEOSPacketMultiFile(numDataPkts, fileMetadata, eosIdx)
    % EOS packet with file metadata
    eosPacket = uint8([]);
    eosPacket = [eosPacket; uint8('E'); uint8('O'); uint8('S'); uint8('!')];
    eosPacket = [eosPacket; uint8(eosIdx)];
    eosPacket = [eosPacket; fileMetadata.fileTypeCode];
    eosPacket = [eosPacket; typecast(uint16(numDataPkts), 'uint8')'];
end

function crc = crc16(data)
    crc = uint16(0xFFFF);
    for i = 1:length(data)
        crc = bitxor(crc, uint16(data(i)));
        for j = 1:8
            if bitand(crc, 1)
                crc = bitxor(bitshift(crc, -1), uint16(0xA001));
            else
                crc = bitshift(crc, -1);
            end
        end
    end
end

function clearTxLog(fig)
    txLog = findobj(fig, 'Tag', 'txLog');
    txLog.Value = {'[TX] Log cleared. Ready for transmission...'};
end

function clearRxLog(fig)
    rxLog = findobj(fig, 'Tag', 'rxLog');
    rxLog.Value = {'[RX] Log cleared. Ready for reception...'};
end

function openReceivedFile(fig)
    appData = guidata(fig);
    if isfield(appData, 'receivedFile') && ~isempty(appData.receivedFile)
        outputFile = appData.receivedFile;
        if ~isfile(outputFile)
            uialert(fig, sprintf('File not found: %s', outputFile), 'Error');
            return;
        end
        try
            if ispc
                winopen(outputFile);
            elseif ismac
                system(['open "' outputFile '"']);
            else
                system(['xdg-open "' outputFile '" &']);
            end
        catch ME
            uialert(fig, sprintf('Could not open: %s\nError: %s', outputFile, ME.message), 'Error');
        end
    else
        uialert(fig, 'No file has been received yet.', 'Info');
    end
end



function logAndScroll(logHandle, msg)
    logHandle.Value = [logHandle.Value; {msg}];
    drawnow;
    % scroll(logHandle, 'bottom');
end

function updateProgressBar(fig, tag, percentage, maxWidth)
    % Update progress bar width and label
    
    if nargin < 4
        maxWidth = 400;
    end
    
    percentage = max(0, min(percentage, 100));
    
    progressBar = findobj(fig, 'Tag', tag);
    if ~isempty(progressBar)
        newWidth = max(1, round((maxWidth / 100) * percentage));
        pos = progressBar.Position;
        progressBar.Position = [pos(1) pos(2) newWidth pos(4)];
    end
    
    labelTag = [tag 'Label'];
    progressLabel = findobj(fig, 'Tag', labelTag);
    if ~isempty(progressLabel)
        progressLabel.Text = sprintf('%.0f%%', percentage);
    end
end

function paprDB = calculatePAPR(waveform)
    % Calculate Peak-to-Average Power Ratio in dB
    peakPower = max(abs(waveform).^2);
    avgPower = mean(abs(waveform).^2);
    if avgPower > 0
        paprDB = 10 * log10(peakPower / avgPower);
    else
        paprDB = 0;
    end
end