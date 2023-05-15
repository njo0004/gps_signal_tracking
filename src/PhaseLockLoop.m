classdef PhaseLockLoop

%{
    Class for a Generic Phase Locked Loop
        
    Default will be a 3rd order PLL w/ a 2nd order FLL
        See Kaplan Book for example

    Inputs:
    1) IF Data
    2) Correlators
    
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
    4) Discrimination Function [done]
    5) Running Loop Filter [done]

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

    pll_int_1 = 0;
    pll_int_2 = 0;

    pll_e_hat

    % --- FLL Properties --- %
    fll_Bw 
    fll_W0

    % --- Input Data --- %
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

    current_phase
    new_phase

end % end of properties

methods

    function obj = PhaseLockLoop(initialization_struct)

        obj.pll_Bw = initialization_struct.pll_Bw;
        obj.pll_W0 = obj.pll_Bw/0.7845; % <- see kaplan book for this
        
        obj.fll_Bw = initialization_struct.fll_Bw;
        obj.fll_W0 = obj.fll_Bw/0.53;

        obj.f_acq  = initialization_struct.acquisition_frequency;
        obj.f_hat  = initialization_struct.acquisition_frequency;

        obj.current_phase = 0;
        obj.new_phase = 0;

    end

    % Function to intake data
    function [obj,output] = ingestData(obj,Tint,correlators)

        obj.Tint = Tint;

        obj.IP = correlators.IP;
        obj.QP = correlators.QP;

        obj.IP1 = correlators.IP1;
        obj.IP2 = correlators.IP2;
        obj.QP1 = correlators.QP1;
        obj.QP2 = correlators.QP2;

        % --- Running Class --- %
        discriminationUpdate(obj);
        runLoopFilter(obj);
        output = outputLoopResults(obj);

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

        % Update Discriminators based on current IF data

        % --- PLL w/ FLL assistance from a combination of Dr. Martin thesis
        % and kapalan green book --- %

        fll_ctrl_term_1 = obj.a2*obj.fll_W0*obj.e_fll;
        fll_ctrl_term_2 = obj.fll_W0^2*obj.Tint*obj.e_fll;

        pll_ctrl_term_1 = obj.pll_W0^3*obj.Tint*obj.e_pll;
        pll_ctrl_term_2 = obj.a3*obj.pll_W0^2*obj.e_pll;
        pll_ctrl_term_3 = obj.b3*obj.pll_W0*obj.e_pll;

        % --- Loop Filter --- %
        obj.pll_int_1 = obj.pll_int_1 + fll_ctrl_term_2 + pll_ctrl_term_1;
        obj.pll_int_2 = obj.pll_int_2 + (fll_ctrl_term_1+pll_ctrl_term_2+obj.pll_int_1)*obj.Tint;
        obj.pll_e_hat = obj.pll_int_2 + pll_ctrl_term_3;

        % --- Updating Doppler Estimate --- %
        obj.f_hat = obj.f_acq + obj.pll_e_hat;

    end

    function output_struct = outputLoopResults(obj)

        output_struct.doppler_est = obj.f_hat;
        output_struct.phase_est = obj.new_phase;
        output_struct.e_pll = obj.e_pll;
        output_struct.e_fll = obj.e_fll;

    end

end % end of methods


end % end of class
