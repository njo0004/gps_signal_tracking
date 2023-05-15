classdef TrackingChannel
    
    %{

        Inputs
            Initial Doppler
            Loop Filter Bandwidths 
                PLL
                FLL
                DLL
            C/A Code for SV to track [1023 chips]
            IF Frequency
            Sample Rate
                Used to calcualte nominal chipping rate
            Tracking Power  
                IP
                QP
                IE
                QE
                IL
                QL
            data for this integration period
            
    %}

properties

    % --- General --- %
    filter_bandwidths = struct('fll',0,'pll',0,'dll',0);
    full_cycle_power = struct('IP',0,'QP',0,'IE',0,'QE',0,'IL',0,'QL',0); % <- for PLL/DLL discriminators (in tracking loops)
    half_cycle_power = struct('IP1',0,'IP2',0,'QP1',0,'QP2',0); % <- for FLL discriminator
    acquisition_doppler
    ca_code;
    if_frequency
    sample_rate
    current_data
    chipping_rate
    Tint
    Tsignal

    % --- Objects for Individual Tracking Loops --- %
    phase_lock_loop
    delay_lock_loop

    % --- Local Replica Stuff --- %
    code_rem_phase
    carrier_rem_phase
    upsampled_code
    sin_signal
    cos_signal
    doppler_frequency
    correlator_spacing = 0.5; % [fractional chips]

end % end of properties

methods

    function obj = TrackingChannel(initialization)

        % --- Filter Bandwidths --- %
        obj.filter_bandwidths.fll = initialization.fll_bw;
        obj.filter_bandwidths.pll = initialization.pll_bw;
        obj.filter_bandwidths.dll = initialization.dll_bw;

        % --- doppler from acquisition --- %
        obj.acquisition_doppler = initialization.acq_doppler;
        obj.doppler_frequency   = initialization.acq_doppler;

        obj.chipping_rate = initialization.chipping_rate;
        obj.if_frequency = initialization.if_freq;

        % --- Making Initialization Structs for tracking loops --- %
        pll_initialization.pll_Bw = obj.filter_bandwidths.pll;
        pll_initialization.fll_Bw = obj.filter_bandwidths.fll;
        pll_initialization.acquisition_frequency = obj.acquisition_doppler;

        dll_initialization.bw = obj.filter_bandwidths.dll;
        dll_initialization.nom_chipping_rate = obj.chipping_rate;

        obj.phase_lock_loop = PhaseLockLoop(pll_initialization);
        obj.delay_lock_loop = DelayLockLoop(dll_initialization);

    end

    function [obj,tracking_results] = ingestData(obj,input_data)

        obj.current_data = input_data;
        generateCorrelators;


    end


    function obj = generateCorrelators(obj)
        
        obj.Tint = (1/obj.sample_rate)*length(obj.current_data);
        upsamplePRN(obj);
        obj.Tsignal = 0:1/obj.sample_rate:obj.Tint;
        
        % --- NCO --- %
        obj.sin_signal = 2.*sin(2*pi*(obj.if_frequency + obj.doppler_frequency).*obj.Tsignal + obj.carrier_rem_phase);
        obj.cos_signal = 2.*cos(2*pi*(obj.if_frequency + obj.doppler_frequency).*obj.Tsignal + obj.carrier_rem_phase);
        obj.carrier_rem_phase = remp(2*pi*(obj.if_frequency + obj.doppler_frequency)*obj.Tint + obj.carrier_rem_phase,2*pi);

        % --- Shifted Code Replicas --- %
        early_code = circshift(obj.upsampled_code,obj.correlator_spacing);
        late_code  = circshift(obj.upsampled_code,-obj.correlator_spacing);

        % --- Full Cycle Correlators --- %
        obj.full_cycle_power.IP = sum(obj.current_data.*obj.sin_signal.*obj.upsampled_code);
        obj.full_cycle_power.QP = sum(obj.current_data.*obj.cos_signal.*obj.upsampled_code);

        obj.full_cycle_power.IE = sum(obj.current_data.*obj.sin_signal.*early_code);
        obj.full_cycle_power.QE = sum(obj.current_data.*obj.cos_signal.*early_code);

        obj.full_cycle_power.IL = sum(obj.current_data.*obj.sin_signal.*late_code);
        obj.full_cycle_power.QL = sum(obj.current_data.*obj.cos_signal.*late_code);

        % --- Half Cycle Correlators --- %
        data_first_half  = obj.current_data(1:length(obj.current_data)/2);
        data_second_half = obj.current_data(length(obj.current_data)/2 + 1:end);

        sin_first_half  = obj.sin_signal(1:length(obj.current_data)/2);
        sin_second_half = obj.sin_signal(length(obj.current_data)/2 + 1:end);

        cos_first_half  = obj.cos_signal(1:length(obj.current_data)/2);
        cos_second_half = obj.cos_signal(length(obj.current_data)/2 + 1:end);

        code_first_half  = obj.upsampled_code(1:length(obj.current_data)/2);
        code_second_half = obj.upsampled_code(length(obj.current_data)/2 + 1:end);

        obj.half_cycle_power.IP1 = sum(data_first_half.*sin_first_half.*code_first_half);
        obj.half_cycle_power.IP2 = sum(data_second_half.*sin_second_half.*code_second_half);

        obj.half_cycle_power.QP1 = sum(data_first_half.*cos_first_half.*code_first_half);
        obj.half_cycle_power.QP2 = sum(data_second_half.*cos_second_half.*code_second_half);

    end

    function obj = upsamplePRN(obj)

        %UPSAMPLE_CODE Upsamples any code (eg. ranging, data, etc.) based on the sampling rate
        % and current chipping rate of the code.
        %
        %   Inputs:
        %       - code: code to upsample [whole chips]
        %       - rem_code_phase: remainder code phase [fractional chips]
        %       - fsamp: sampling frequency [Hz]
        %       - fchip: sampling frequency [Hz]
        %
        %   Outputs: 
        %       - upsamp_code: upsampled code
        %       - new_rem_code_phase: new remainder code phase [fractional chips]
        %
        %   Author: Tanner Koza
        
        % intialization
        code_length = length(obj.ca_code);
        samp_per_chip = obj.sample_rate/obj.chipping_rate;
        chip_per_samp = 1/samp_per_chip;
        
        samp_per_code_period = ceil((code_length-obj.code_rem_phase)/chip_per_samp);
        appended_code = [obj.ca_code(end) obj.ca_code obj.ca_code(1)];
        
        % upsampling
        code_subchip_idx = obj.code_rem_phase:chip_per_samp:(samp_per_code_period-1)*chip_per_samp + obj.code_rem_phase; % [fractional chips]
        code_chip_idx = ceil(code_subchip_idx) + 1; % add 1 for one-indexing [whole chips]
        obj.upsampled_code = appended_code(code_chip_idx);
        
        obj.code_rem_phase = code_subchip_idx(samp_per_code_period) + chip_per_samp - code_length; % [samples]

    end

end % end of methods


end % end of class definition