classdef TrackingChannel
    
    %{

        To-Do:
            Data Bit Processing
                1) Generate the bit stream from the inphase prompt power
                2) Find Preamble/Detect bit stream is inverted or no
                3) save a subframe
                4) Seperate subframes by words
                5) get TOW from handover word
                6) seperate out rest of ephemeris

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

    % --- Bit Processing --- %
    is_locked = false; % <- boolean param to decide if the PLL is locked
    have_found_first_bit = false; % <- boolean to decide if we have seem the first bit flip
    preamble_found = false; 
    is_fliped = false;

    idx_first_bit
    preamble = [1,-1,-1,-1,1,-1,1,1]; % [bits] 
    chips_per_bit = 20;
    bits_per_subframe = 300;
    chips_per_subframe % we want two subframes to do processing because we can ensure we found the preamble and not just the correct string w/ two correlation spikes at 6000 samples apart
    bit_buffer % <= where the IP is stored
    bit_counter = 1;

    % --- CN0 Estimator Params --- %
    averaging_coeff
    channel_power
    noise_power

    % --- Objects for Individual Tracking Loops --- %
    phase_lock_loop
    delay_lock_loop
    cn0_estimator

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
        obj.if_frequency = initialization.f_if;
        obj.sample_rate = initialization.f_s;
        obj.ca_code = initialization.ca_code;
        obj.code_rem_phase = 0;
        obj.carrier_rem_phase = 0;

        % --- Making Initialization Structs for tracking loops --- %
        pll_initialization.pll_Bw = obj.filter_bandwidths.pll;
        pll_initialization.fll_Bw = obj.filter_bandwidths.fll;
        pll_initialization.acquisition_frequency = obj.acquisition_doppler;

        dll_initialization.bw = obj.filter_bandwidths.dll;
        dll_initialization.nom_chipping_rate = obj.chipping_rate;

        % --- Making Initialization Struct for Cn0 Estimator --- %
        cn0_init.ave_coeff = initialization.cn0_ave_coeff;

        obj.phase_lock_loop = PhaseLockLoop(pll_initialization);
        obj.delay_lock_loop = DelayLockLoop(dll_initialization);
        obj.cn0_estimator   = Cn0Estimator(cn0_init);

        % --- Upsampling Preamble --- %
        obj.chips_per_subframe = obj.chips_per_bit*obj.bits_per_subframe*2;

        upsample_idx = ceil(0:1/obj.chips_per_bit:length(obj.preamble) - 1/obj.chips_per_bit) + 1;
        upsample_idx(upsample_idx == 9) = 1;
        obj.preamble = obj.preamble(upsample_idx);
        obj.preamble = [obj.preamble zeros(1,obj.chips_per_subframe - length(obj.preamble))];
        
    end

    function [obj,tracking_results] = ingestData(obj,input_data)

        obj.current_data = input_data;
        obj = generateCorrelators(obj);

        % --- Correlators for PLL --- %
        pll_correlators.IP = obj.full_cycle_power.IP;
        pll_correlators.QP = obj.full_cycle_power.QP;
        pll_correlators.IP1 = obj.half_cycle_power.IP1;
        pll_correlators.IP2 = obj.half_cycle_power.IP2;
        pll_correlators.QP1 = obj.half_cycle_power.QP1;
        pll_correlators.QP2 = obj.half_cycle_power.QP2;

        % --- Correlators for DLL --- %
        early_power = sqrt(obj.full_cycle_power.IE^2 + obj.full_cycle_power.QE^2);
        late_power  = sqrt(obj.full_cycle_power.IL^2 + obj.full_cycle_power.QL^2);

        % --- Running Sub-Classes --- %
        obj.phase_lock_loop = obj.phase_lock_loop.ingestData(obj.Tint,pll_correlators);
        obj.delay_lock_loop = obj.delay_lock_loop.ingestData(early_power,late_power,obj.Tint);

        % only update CN0 estimate if channel power is better than noise
        % power

        if(obj.channel_power>4*obj.noise_power)
            obj.cn0_estimator = obj.cn0_estimator.ingestData(obj.channel_power,obj.noise_power,obj.Tint);
            tracking_results.cn0_estimate = obj.cn0_estimator.Cn0_estimate;
        else
            tracking_results.cn0_estimate = 0.001;
        end
        
        obj.doppler_frequency = obj.phase_lock_loop.f_hat;
        obj.chipping_rate     = obj.delay_lock_loop.chipping_rate;

        tracking_results.IP = pll_correlators.IP;
        tracking_results.QP = pll_correlators.QP;
        tracking_results.doppler_estimate = obj.doppler_frequency;
        tracking_results.chipping_rate = obj.chipping_rate;
        tracking_results.early_power = early_power;
        tracking_results.late_power = late_power;
        tracking_results.prompt_power = sqrt(pll_correlators.IP^2 + pll_correlators.QP^2);
        tracking_results.carrier_rem_phase = obj.carrier_rem_phase;
        tracking_results.code_rem_phase = obj.code_rem_phase;
        tracking_results.e_fll = obj.phase_lock_loop.e_fll;
        tracking_results.e_pll = obj.phase_lock_loop.e_pll;

    end


    function obj = generateCorrelators(obj)
        
        obj.Tint = (1/obj.sample_rate)*length(obj.current_data);
        obj.Tsignal = 0:1/obj.sample_rate:obj.Tint;
        obj.Tsignal(end) = [];

        chip_spacing = ceil(obj.correlator_spacing*(obj.sample_rate/obj.chipping_rate));

        % --- NCO --- %
        obj.sin_signal = 2.*sin(2*pi*(obj.if_frequency + obj.doppler_frequency).*obj.Tsignal + obj.carrier_rem_phase);
        obj.cos_signal = 2.*cos(2*pi*(obj.if_frequency + obj.doppler_frequency).*obj.Tsignal + obj.carrier_rem_phase);
        obj.carrier_rem_phase = rem(2*pi*(obj.if_frequency + obj.doppler_frequency)*obj.Tint + obj.carrier_rem_phase,2*pi);

        % --- Shifted Code Replicas --- %
        early_code = circshift(obj.upsampled_code,chip_spacing);
        late_code  = circshift(obj.upsampled_code,-chip_spacing);

        % --- Full Cycle Correlators --- %
        obj.full_cycle_power.IP = sum(obj.current_data'.*obj.sin_signal.*obj.upsampled_code);
        obj.full_cycle_power.QP = sum(obj.current_data'.*obj.cos_signal.*obj.upsampled_code);

        obj.full_cycle_power.IE = sum(obj.current_data'.*obj.sin_signal.*early_code);
        obj.full_cycle_power.QE = sum(obj.current_data'.*obj.cos_signal.*early_code);

        obj.full_cycle_power.IL = sum(obj.current_data'.*obj.sin_signal.*late_code);
        obj.full_cycle_power.QL = sum(obj.current_data'.*obj.cos_signal.*late_code);

        % --- Half Cycle Correlators --- %
        half_data_length = floor(length(obj.current_data)/2);

        data_first_half  = obj.current_data(1:half_data_length);
        data_second_half = obj.current_data(half_data_length + 1:end);

        sin_first_half  = obj.sin_signal(1:half_data_length);
        sin_second_half = obj.sin_signal(half_data_length + 1:end);

        cos_first_half  = obj.cos_signal(1:half_data_length);
        cos_second_half = obj.cos_signal(half_data_length + 1:end);

        code_first_half  = obj.upsampled_code(1:half_data_length);
        code_second_half = obj.upsampled_code(half_data_length + 1:end);

        obj.half_cycle_power.IP1 = sum(data_first_half'.*sin_first_half.*code_first_half);
        obj.half_cycle_power.IP2 = sum(data_second_half'.*sin_second_half.*code_second_half);

        obj.half_cycle_power.QP1 = sum(data_first_half'.*cos_first_half.*code_first_half);
        obj.half_cycle_power.QP2 = sum(data_second_half'.*cos_second_half.*code_second_half);

        % --- Noise Correlators --- %
        
        for i = 1:50
            noise_correlator.IE(i,:) = sum(obj.current_data'.*obj.sin_signal.*circshift(early_code,300*i));
            noise_correlator.IL(i,:) = sum(obj.current_data'.*obj.sin_signal.*circshift(late_code,-300*i));
            noise_correlator.QE(i,:) = sum(obj.current_data'.*obj.cos_signal.*circshift(early_code,300*i));
            noise_correlator.QL(i,:) = sum(obj.current_data'.*obj.cos_signal.*circshift(late_code,-300*i));    
        end

        var_IE = (1/50)*sum(noise_correlator.IE.^2);
        var_IL = (1/50)*sum(noise_correlator.IL.^2);
        var_QE = (1/50)*sum(noise_correlator.QE.^2);
        var_QL = (1/50)*sum(noise_correlator.QL.^2);

        % --- CN0 Things --- %
        obj.channel_power = (obj.full_cycle_power.IE^2 + obj.full_cycle_power.IL^2) + ...
                            (obj.full_cycle_power.QE^2 + obj.full_cycle_power.QL^2);

        obj.noise_power = (var_IE+var_IL) + (var_QE+var_QL);

    end

    function [obj,length_upsamp_code] = upsamplePRN(obj)
        
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

        code = obj.ca_code;
        fsamp = obj.sample_rate;
        fchip = obj.chipping_rate;
        rem_code_phase = obj.code_rem_phase;
        
        % intialization
        code_length = length(code);
        samp_per_chip = fsamp/fchip;
        chip_per_samp = 1/samp_per_chip;
        
        samp_per_code_period = ceil((code_length-rem_code_phase)/chip_per_samp);
        appended_code = [code(end) code code(1)];
        
        % upsampling
        code_subchip_idx = rem_code_phase:chip_per_samp:(samp_per_code_period-1)*chip_per_samp + rem_code_phase; % [fractional chips]
        code_chip_idx = ceil(code_subchip_idx) + 1; % add 1 for one-indexing [whole chips]
        upsamp_code = appended_code(code_chip_idx);
        
        new_rem_code_phase = code_subchip_idx(samp_per_code_period) + chip_per_samp - code_length; % [samples]

        obj.upsampled_code = upsamp_code;
        obj.code_rem_phase = new_rem_code_phase;

        length_upsamp_code = length(obj.upsampled_code);

    end

    function obj = processDataBits(obj)

        % --- Detecting Preamble --- %


    end

end % end of methods


end % end of class definition