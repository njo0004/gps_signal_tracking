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
T = 0.020; % 10 ms of data
dataSize = floor(T*SF);
fileID = fopen(sprintf('%s',path_if_data));
fseek(fileID,0,'bof');
[signalData,~] = fread(fileID,dataSize,dataType);

f_IF = 5000445.88565834;
chipping_rate = 1.023e6; % <= rate of chips (chips/second)

initialization.if_data = signalData;
initialization.acquisition_period = 0.010; % [s]
initialization.step_size = 0.010; % [s]
initialization.aq_threshold = 3;
initialization.prn = ca_code;
initialization.f_s = SF;
initialization.f_if = f_IF;

acquisition_class = SignalAcquisition(initialization);
acquisition_data = acquisition_class.acquireSV;

