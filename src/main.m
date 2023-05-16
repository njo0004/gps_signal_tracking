clear all; clc; close all;

addpath(genpath('helper_functions'));
load('ca_codes.mat');
path_if_data = ingest_data();

%% Notes

%{

    This will be the main script in which the SDR (being written) will be
    ran. 

    To-Do:

    1) Verify updated acquisition works (I am confident it will but this
    needs to be checked with class static dataset)

    2) DLL Class (needs to be tested)

    3) Tracking Channel Class (needs to be done)

    4) PLL Class (needs to be tested)

    5) Cn0 Estimator

    6) Software Defined Receiver Class

%}

%% Acquisition

dataType = "int8";
SF = 20e6; % 20000000 Hz (20 MHz)
T = 0.010; % 10 ms of data
dataSize = floor(T*SF);
fileID = fopen(sprintf('%s',path_if_data));
fseek(fileID,0,'bof');
[signalData,~] = fread(fileID,dataSize,dataType);

f_IF = 5000445.88565834;
chipping_rate = 1.023e6; % <= rate of chips (chips/second)

initialization.if_data = signalData;
initialization.acquisition_period = 0.005; % [s]
initialization.step_size = 0.002; % [s]
initialization.aq_threshold = 3;
initialization.prn = ca_code;
initialization.f_s = SF;
initialization.f_if = f_IF;

acquisition_class = SignalAcquisition(initialization);
acquisition_data = acquisition_class.acquireSV;

%% Tracking

pll_bw = 15;
fll_bw = 0;
dll_bw = 5;

initialization.fll_bw = fll_bw;
initialization.pll_bw = pll_bw;
initialization.dll_bw = dll_bw;

initialization.acq_doppler = acquisition_data.doppler_shift(acquisition_data.sv_list == 7);
initialization.chipping_rate = chipping_rate;
initialization.ca_code = ca_code(7,:);

tracking_class = TrackingChannel(initialization);

seconds_to_read = 5*60; % grab this many samples of data
max_counter = seconds_to_read*20000*1000; % [max number of samples to read]

i = 1;
j = 1;

Tsignal = 0:1/SF:0.001;
Tsignal(end) = [];

while i<=max_counter

data_length = length(Tsignal);

fseek(fileID,i-1+acquisition_data.code_shift(acquisition_data.sv_list == 7),'bof');
[currentData,~] = fread(fileID,data_length,dataType);

[~,current_results] = tracking_class.ingestData(currentData);

IP(j) = current_results.IP;
QP(j) = current_results.QP;
doppler_estimate(j) = current_results.doppler_estimate;
early_power(j) = current_results.early_power;
late_power(j) = current_results.late_power;
prompt_power(j) = current_results.prompt_power;
carrier_phase(j) = current_results.carrier_rem_phase;
code_phase(j) = current_results.code_rem_phase;

j = j + 1;

i = i + data_length;

end

