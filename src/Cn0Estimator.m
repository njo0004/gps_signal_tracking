classdef Cn0Estimator

    %{

        CN0 Estimator is behaving weird,
        tracking channel 7, there is a loss of inphase power at around the
        20000th integration period, this should result in a lowering of the
        CN0? However what I see is a spike in CN0 which doesnt seem right.
        I will work to implement the algorithm from Anderson Givahn's
        thesis and compare to the current estimation scheme

    %}

    properties

        % --- Inputs --- %
        Tint
        averaging_window
        IP

        % --- Output --- %
        Cn0_estimate
        SNR_estimate

        % --- Internal Properties --- %
        P_n
        P_d
        counter

    end

    
    methods
        
        function obj = Cn0Estimator(initialization)

            obj.averaging_window = initialization.ave_window;
            obj.counter = 1;

        end

        function [obj,cn0_count] = ingestData(obj,IP)

            obj.IP(obj.counter) = IP;
                
            if(obj.counter == 1)

                % --- Initialize to very small bc of divide by zero
                % problems (is filtered out via averaging) --- %
                obj.P_d(obj.counter) = 0.0001;
                obj.P_n(obj.counter) = 0.0001;

            else
    
                obj.P_d(obj.counter) = (abs(obj.IP(obj.counter)) - abs(obj.IP(obj.counter-1)))^2;
            
                obj.P_n(obj.counter) = 0.5*(obj.IP(obj.counter)^2 + obj.IP(obj.counter-1)^2);
                 
            end

            cn0_count = obj.counter;

            obj.counter = obj.counter + 1;

        end

        function [obj,cn0_estimate] = getCn0Estimate(obj,Tint)

            obj.Tint = Tint;
            obj = calcCn0Estimate(obj);

            cn0_estimate = obj.Cn0_estimate;

        end

        function obj = calcCn0Estimate(obj)
            
            obj.SNR_estimate = inv((1/obj.averaging_window).*sum(obj.P_n)/sum(obj.P_d));
            obj.Cn0_estimate = 10*log10(obj.SNR_estimate/obj.Tint);
            
            obj.counter = 1;
            obj.P_d = [];
            obj.P_n = [];

        end

    end


end