classdef PhaseLockLoop

%{
    Class for a Generic Phase Locked Loop
        
    Default will be a 3rd order PLL w/ a 2nd order FLL
        See Kaplan Book for example

    Inputs:
    1) IF Data
    2) Upsampled Prompt CA Code 
    
    Outputs:
    1) Phase Discriminator (Costas)
    2) Frequency Discriminator (Half Cycle)
    3) Phase Remainder
    4) Frequency

    Parameters:
    1) Bandwidth of Phase Lock Loop
    2) Bandwidth of Frequency Lock Loop

    To-Do:
    1) Make Properties
    2) Ingestion Function
        Intake Data
            a) IF Data
            b) CA Code

    3) Output Function
        output the results of this integration period

    4) Correlation Function

    5) Running Loop Filter

%}

properties

    % --- Generic Loop Filter Params --- %
    % These are from Kaplan Green Book
    a2 = 1.414;
    a3 = 1.1;
    b3 = 2.4;
    
    % --- PLL Properties --- %
    pll_Bw
    pll_W0

    % --- FLL Properties --- %
    fll_Bw 
    fll_W0

    % --- Input Data --- %
    if_data
    code_replica
    Tsignal
    Tint

    % --- Carrier Replicas --- %
    sin_signal
    cos_signal
    
    % --- Full Period Correlator Output --- %
    IP
    QP

    % --- Half Period Correlator Output --- %
    IP1
    IP2
    QP1
    QP2

    % --- Discriminator Outputs --- %
    e_pll
    e_fll

    % --- Signal Parameters --- %
    f_hat % <- is the frequency estimate from the loop filter
    f_acq % <- is the frequency from acquisition
    f_IF  % <- is the IF frequency (of the front end)
    current_phase
    new_phase

end % end of properties

methods

    function obj = PhaseLockLoop(initialization_struct)

        obj.pll_Bw = initialization_struct.pll_Bw;
        obj.fll_Bw = initialization_struct.fll_Bw;
        obj.f_acq  = initialization_struct.acquisition_frequency;
        obj.f_hat  = initialization_struct.acquisition_frequency;
        obj.f_IF   = initialization.f_IF;

        obj.current_phase = 0;
        obj.new_phase = 0;

    end

    % Function to intake data
    function obj = injestData(obj,if_data_in,code_in,Tsig_in)

        obj.if_data = if_data_in;
        obj.code_replica = code_in;
        obj.Tsignal = Tsig_in;
        obj.Tint = obj.Tsignal(end);

    end

    function obj = correlationUpdate(obj)

        obj.current_phase = obj.new_phase;
        
        length_data = length(obj.if_data);

        % --- Carrier Replicas --- %
        obj.sin_signal = sin(2*pi*(obj.f_IF+obj.f_hat)*obj.Tsignal + obj.current_phase);
        obj.cos_signal = cos(2*pi*(obj.f_IF+obj.f_hat)*obj.Tsignal + obj.current_phase);

        % --- PLL Correlator --- %
        obj.IP = sum(obj.if_data.*obj.sin_signal.*obj.code_replica);
        obj.QP = sum(obj.if_data.*obj.cos_signal.*obj.code_replica);

        % --- FLL Correlator --- %
        obj.IP1 = sum(obj.if_data(1:length_data/2).*obj.sin_signal(1:length_data/2).*obj.code_replica(1:length_data/2));
        obj.QP1 = sum(obj.if_data(1:length_data/2).*obj.cos_signal(1:length_data/2).*obj.code_replica(1:length_data/2));
        obj.IP2 = sum(obj.if_data((length_data/2 + 1):end).*obj.sin_signal((length_data/2 + 1):end).*obj.code_replica((length_data/2 + 1):end));
        obj.QP2 = sum(obj.if_data((length_data/2 + 1):end).*obj.cos_signal((length_data/2 + 1):end).*obj.code_replica((length_data/2 + 1):end));

        obj.new_phase = rem(2*pi*(obj.f_IF+obj.f_hat)*obj.Tint + obj.current_phase,2*pi);

    end

    function obj = discriminationUpdate(obj)

        % --- Costas (PLL) Discriminator --- %
        obj.e_pll = atan(obj.QP/obj.IP)/(2*pi);

        % --- FLL Discriminator ---- %
        cross = obj.IP1*obj.QP2 - obj.IP2*obj.QP1;
        dot   = obj.IP1*obj.IP2 + obj.QP1*obj.QP2;

        obj.e_fll = atan2(cross,dot)/(2*pi*obj.Tint);

    end

    function obj = runLoopFilter(obj)

        % Update Correlators and Discriminators based on current IF data
        correlationUpdate();
        discriminationUpdate();

        % --- PLL w/ FLL assistance from a combination of Dr. Martin thesis
        % and kapalan green book --- %

%         obj.

    end

    function output_struct = outputLoopResults(obj)


    end

end % end of methods


end % end of class
