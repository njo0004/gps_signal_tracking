classdef DelayLockLoop
    
    %{
        This class is the Delay Locked Loop to perform code tracking for a
        given PRN ranging code. As the wavelength of the discrete C/A code
        is roughly 300 m, doppler effects from motion of both the SV and
        the receiver have a substantailly less pronounced effect on the
        time rate of change of the code doppler frequency. Due to this, I
        will be implementing a 2nd order DLL initially. Under very high
        dynamics this may be insufficient, however under such circumstances
        the carrier (PLL) tracking will break first. 

        Inputs:
            IF data
                this will be shifted by the tracking class (which will
                manage the DLL and PLL) such that the code offset from
                acquisition will be handled outside of the DLL
            Correlators

        Outputs:
            1) discriminator output
            2) loop filter output
            3) updated chipping rate
        Properties:

            Bandwidth (I will keep zeta = 0.707)
            nominal_chipping_rate
            control gains
            Integrators
                -> Tint
            Chip spacing (default to half a chip)
            nominal chipping rate
            updated chipping rate

        Methods:
            constructor
            
            ingest data

            discriminator update

            loop filter 

            output results of loop filter

    %}


    properties

        bandwidth
        
        Kp
        Ki

        err_int = 0;
        e_dll
        Tint
        e_hat
        
        chipping_rate
        nominal_chipping_rate

        % correlator outputs from tracking class
        early_power
        late_power

    end % end of properties
    
    methods

        function obj = DelayLockLoop(initialization)

            obj.bandwidth = initialization.bw;
            obj.Kp = 2*0.707*(obj.bandwidth);
            obj.Ki = (obj.bandwidth)^2;
            obj.nominal_chipping_rate = initialization.nom_chipping_rate;

        end
        
        function obj = discriminatorUpdate(obj)

            E = obj.early_power;
            L = obj.late_power;

            obj.e_dll = 0.5*((E-L)/(E+L));
            obj.err_int = obj.err_int + obj.e_dll*obj.Tint;

        end

        function [obj,output] = ingestData(obj,early_power,late_power,Tint)

            obj.early_power = early_power;
            obj.late_power = late_power;
            obj.Tint = Tint;

            obj = discriminatorUpdate(obj);
            obj = runLoopFilter(obj);
            output = outputLoopResults(obj);

        end

        function obj = runLoopFilter(obj)

            obj.e_hat = obj.Kp*obj.e_dll + obj.Ki*obj.err_int;
            obj.chipping_rate = obj.nominal_chipping_rate - obj.e_hat;

        end

        function output = outputLoopResults(obj)

            output.chipping_rate = obj.chipping_rate;
            output.e_dll = obj.e_dll;
            output.filter_output = obj.e_hat;

        end

    end % end of methods
end

