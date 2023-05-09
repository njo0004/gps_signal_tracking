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

%}

properties

    % --- Filter Settings --- %
    Wn % <- natural frequency 
    zeta % <- damping ratio
    Bw % <- bandwidth

    % --- Control Gains --- %
    Kp
    Ki

    % --- Signal Settings --- %
    Tsignal % <- is the vector to simulate the sin and cosine carrier waves over
    
end % end of properties

methods

    function obj = PhaseLockLoop(initialization_struct)

        obj.Bw = initialization_struct.Bw;
        obj.zeta = initialization_struct.zeta;
        obj.Wn = obj.Bw*obj.zeta;

        obj.Kp = 2*obj.zeta*obj.Wn;
        obj.Ki = obj.Wn^2;

    end


end % end of methods


end % end of class
