classdef SignalAcquisition

%{
    A class I am creating to do GPS Satellite Signal Tracking
        The class will do serial acquisition for now, with the end goal of
        upgrading to do either serial or parallel acquisition

    To-Do:
    1) Constructor [done]
        -> To-Do:
            1)

    2) Upsample function [done]
        -> To-Do:
            1) 

    3) Serial Search Function [done]
        -> To-Do:
            1) 

    4) Parallel Search Function [done]
        -> To-Do:
            1) 
%}

    properties

        % --- General Parameters --- %
        IF_frequency % <= mix frequency of data
        chipping_rate = 1.023e6 % <= rate of chips (chips/second)
        chipping_cycles % <- number of cycles of PRN
        ca_sample_rate % <= is the sample rate of the IF Data 
        Tint % <= integration period
        nom_samples_per_chip

        % --- Acquisition Parameters --- %
        sv_prns % <= is the list of PRN's to search through
        IF_data % <= is input data
        acquisition_threshold % <- ratio of the two largest peaks in acquisition plane for current SV

    end % end of properties

    methods

        % ======================================================== %
        % Class Constructor
        function obj = SignalAcquisition(initiation_struct)

            obj.sv_prns = initiation_struct.prn;
            obj.ca_sample_rate = initiation_struct.f_s;
            
            obj.nom_samples_per_chip = obj.ca_sample_rate/obj.chipping_rate;

            if_data_in = initiation_struct.if_data;
            if_freq_in = initiation_struct.f_if;

            % Checking Dimensions of Data 
            [r,c] = size(if_data_in);
            
            if(r>c)
                if_data_in = if_data_in';
            end

            obj.IF_data = if_data_in;
            obj.IF_frequency = if_freq_in;

            obj.acquisition_threshold = initiation_struct.aq_threshold;

        end

        %=================== Utility  ============================== %

        % Upsample the PRN
        function [upsampled_ca_code,obj] = upsamplePRN(obj,prn,data_length)

            % --- Grabbing Stuff from class obj --- %            
            
            % how many samples we want to add
            samples_per_chip = obj.nom_samples_per_chip;

            upsample_idx = ceil(0:1/samples_per_chip:1023-(1/samples_per_chip)) + 1;        

            current_prn = obj.sv_prns(prn,:);
            current_prn = [current_prn(end) current_prn current_prn(1)];

            upsampled_single_code(1,:) = current_prn(upsample_idx);
            number_prn_cycle = data_length/length(upsampled_single_code);
             
            obj.chipping_cycles = number_prn_cycle;

            upsampled_ca_code(1,:) = repmat(upsampled_single_code,1,number_prn_cycle);

        end

        % ========================================================== %


        % ================= Acquisition ============================ %
        function search_struct = acquireSV(obj,search_type)

            if(search_type == "parallel")
                fprintf('Beginning Parallel Search!\n')
                fprintf('Parallelizing Code Search\n\n')

                search_struct = parallelSearch(obj);

            elseif(search_type == "serial")
                fprintf('Beginning Serial Search!\n')
                
                search_struct = serialSearch(obj);
            end

        end

        % Serial Search
        function serial_correlation_plane = serialSearch(obj)

            %{
                Wipe off Carrier First
                    I need to make my local replica of the carrier wave
                    over time (cos or sin (t = 0:dt:t_end))
                    
                Need to search over entire chips (I only need to get within
                +- one chip to begin DLL tracking I think?)

                Correlate to get I and Q data, then sum and return as a
                struct
                    correlation 3D matrix
            %}

            % --- Grabbing stuff from class obj --- %
            data = obj.IF_data;
            [num_codes,length_prn] = size(obj.sv_prns);

            % --- Making Time Vector for local Carrier Replica --- %
            t_end = length(data)/obj.ca_sample_rate;
            t = 0:1/obj.ca_sample_rate:t_end;
            t(end) = [];

            % Indeces for saving R
            j = 1;
            k = 1;
            
            for i = 1:num_codes
                
                code_replica = upsamplePRN(obj,i);

                for dop_shift = -5000:500:5000
                    
                    f = dop_shift + obj.IF_frequency;
                    
                    % --- Wiping off Carrier Wave --- %
                    I = 2*(data.*sin(2*pi*f*t));
                    Q = 2*(data.*cos(2*pi*f*t));

                    shifted_code = circshift(code_replica,0);

                    for code_shift = 1:1:length_prn
                        
                        I_correlated = sum(I.*shifted_code);
                        Q_correlated = sum(Q.*shifted_code);

                        R(j,k) = (I_correlated)^2 + (Q_correlated)^2;
    
                        shifted_code = circshift(code_replica,code_shift);

                        k = k + 1;
                    
                    end

                    k = 1;

                    j = j + 1;
    
                end

                correlation_plane(:,:,i) = R;
                
                clear R I Q

                j = 1;
                k = 1;

            end
            
            serial_correlation_plane = correlation_plane;

        end % end of serial search

        % Parallel Search
        function parallel_correlation = parallelSearch(obj)
    
            %{
                From Tanner Watts Thesis:
                1) Generate In Phase and Quadrature Carrier Samples like in
                serial 
            %}

            data = obj.IF_data;
            length_data = length(data);

            [num_codes,length_prn] = size(obj.sv_prns);

            % --- Making Time Vector for local Carrier Replica --- %
            t_end = length(data)/obj.ca_sample_rate;
            t = 0:1/obj.ca_sample_rate:t_end;
            t(end) = [];

            j = 1;

            for i = 1:num_codes

                [code_replica,obj] = upsamplePRN(obj,i,length_data);

                for doppler_shift = -5000:250:5000
                
                    f = obj.IF_frequency + doppler_shift;

                    % --- Generating Carrier Replicas --- %
                    I = data.*sin(2*pi*f*t);
                    Q = data.*cos(2*pi*f*t);

                    fft_IQ = fft(I + Q);
                    fft_Code = fft(code_replica);

                    fft_both = fft_IQ.*conj(fft_Code);

                    correlated_val(:,j) = abs(ifft(fft_both)).^2;
                                        
                    max_freq_bin(j) = max(correlated_val(:,j));
                  
                    j = j + 1;
                end

                sorted_freq_bin = sort(max_freq_bin,'descend');

                if((sorted_freq_bin(1)/sorted_freq_bin(2))>=obj.acquisition_threshold)

                    freq_bin_idx = find(max_freq_bin==sorted_freq_bin(1));
                    
                    bin_correlated = correlated_val(:,freq_bin_idx);
                    max_correlation = max(bin_correlated);
                    sample_shift = find(bin_correlated == max_correlation);
                    sample_shift = sample_shift(1);

                    parallel_correlation.dop_shift(i) = -5000+250*(freq_bin_idx-1);
                    parallel_correlation.correlation(:,:,i) = correlated_val;
                    parallel_correlation.code_shift(i) = sample_shift;
                    parallel_correlation.acquired_sv(i) = i;

                    fprintf('===================================\n')
                    fprintf('SV # %.f has been acquired!\n',i)
                    fprintf('Shift is %.f Hz and %.f Samples! \n',parallel_correlation.dop_shift(i),parallel_correlation.code_shift(i))
                    fprintf('===================================\n \n')

                    one_cycle = correlated_val(1:length_data/obj.chipping_cycles,:);

                    figure
                    mesh(one_cycle)
                    title('Acquisition Plane for SV',i)
                    ylabel('Code Shift (Samples)')
                    xlabel('Doppler Shift (Bins)')
                    zlabel('Correlation')
                end
                
                j = 1;

                
                clear correlated_val max_freq_bin

            end

        end % end of parallel search

        % Search Through New Data
        function [correlation_update,obj] = passNewData(obj,new_data,search_type)

            fprintf('===================================\n')
            fprintf('RECEIVED NEW DATA!\n')
            fprintf('===================================\n \n')

            if(length(obj.IF_data) == length(new_data))

                [r_old,~] = size(obj.IF_data);
                [r_new,~] = size(new_data);

                if(r_old ~=r_new)
                    new_data = new_data';
                end
                obj.IF_data = new_data;

            else
                error('updated data must be the same length as old data\n')
            end

            if(search_type == "serial")

                fprintf('Running Serial Search\n')
                
                correlation_update = serialSearch(obj);
            elseif(search_type == "parallel")

                fprintf('Running Parallel Search\n')
                fprintf('Parallelizing Code Search\n\n')

                correlation_update = parallelSearch(obj);
            end

        end % end of update data function
        % ========================================================== %


    end % end of methods

end