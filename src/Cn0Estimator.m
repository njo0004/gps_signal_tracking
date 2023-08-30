classdef Cn0Estimator

    %{

        CN0 estimator will be implemented like in Anderson's Masters Thesis

    %}

    properties

        % --- Inputs --- %
        averaging_coefficient
        channel_power % <- measured channel power
        noise_power % <- variance in noise correlator
        integration_period

        % --- Output --- %
        Cn0_estimate

        % --- Internal Properties --- %
        noise_power_smoothed

    end

    
    methods
        
        function obj = Cn0Estimator(initialization)

            obj.averaging_coefficient = initialization.ave_coeff;

            obj.noise_power_smoothed = 0;
        end

        function [obj] = ingestData(obj,channel_power_in,noise_power_in,Tint)
            
            obj.integration_period = Tint;
            obj.channel_power = channel_power_in;
            obj.noise_power = noise_power_in;
            obj = calcCn0Estimate(obj);

        end

        function obj = calcCn0Estimate(obj)
            
            obj.noise_power_smoothed = (1-obj.averaging_coefficient)*obj.noise_power_smoothed+...
                                       obj.averaging_coefficient*obj.noise_power;

            obj.Cn0_estimate = 10*log10((obj.channel_power - 4*obj.noise_power_smoothed)/(2*obj.integration_period*obj.noise_power_smoothed));

        end

    end


end