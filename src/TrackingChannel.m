classdef TrackingChannel
    
    %{

        Inputs
            Initial Doppler
            Loop Filter Bandwidths 
                PLL
                FLL
                DLL

    %}

properties



end % end of properties

methods

    function obj = TrackingChannel(initialization)

        phase_lock_loop = PhaseLockLoop();
        delay_lock_loop = DelayLockLoop();

    end


end % end of methods


end % end of class definition