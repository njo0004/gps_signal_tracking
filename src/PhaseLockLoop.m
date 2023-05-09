classdef PhaseLockLoop

    %{
        Class for a Generic Phase Lock Loop
            
        I have developed a working second order phase lock loop on IFEN
        data that is successful in tracking GPS signals for a specific PRN
        given IF data

        I will implement a second order PLL for now, with the goal of
        upgrading it to a 3rd order PLL assisted w/ a second order FLL

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
