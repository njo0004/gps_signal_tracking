classdef SoftwareDefinedReceiver

%{

    Need to receive the initialization parameters (defined in a struct), as
    well as the handle of the IF data file and the length of data to
    process:

    To-Do:
    1) Create Acquisition Class from initialization parameters pertaining
    to acquisition

    2) Perform acquisition in constructor (this is so we can create the
    first set of tracking channels that we need to do positioning)
    
    3) Once acquisition is done, create a number of tracking channels where
    the number of channels is equal to the number of SV's that have been
    acquired (This should also happen in the constructor)

%}

properties

    % --- Data File Parameters --- %
    data_type = "int8"; % <- data type for the IF data I recorded
    data_size
    file_id

    % --- General Properties --- %
    if_data_handle
    if_frequency
    sv_prns
    
    nominal_chipping_rate
    sample_rate
    
    % --- Acquisition Properties --- %
    acquisition_init = struct('aq_threshold',0,'acquisition_period',0,'step_size',0,'f_if',0,'f_s',0,'if_data',0,'prn',0);
    acquisition_length

    % --- Tracking Properties --- %
    filter_bandwidths
    cn0_averaging_window

    % --- Acquisition Class Handle --- %
    signal_acquistion

end

methods

    function obj = SoftwareDefinedReceiver(initialization)
        
        obj.sv_prns = initialization.sv_prns;
        obj.if_data_handle = initialization.path_to_if_data;
        
        obj.file_id = fopen(sprtinf('%s',obj.if_data_handle));
        fseek(obj.file_id,0,'bof');

        % --- GPS Front End Parameters --- %
        obj.if_frequency = initialization.if_frequency;
        obj.sample_rate  = initialization.sample_rate;

        % --- Making the things we need to do acquisition --- %
        
        obj.acquisition_length = initialization.acquistion_length;

        obj.acquisition_init.aq_threshold = initialization.acquisition_threshold;
        obj.acquisition_init.acquisition_period = initialization.acquisition_threshold;
        obj.acquisition_init.step_size          = initialization.acquisiton_step_size;
        obj.acquisition_init.f_if = obj.if_frequency;
        obj.acquisition_init.f_s = obj.sample_rate;
        obj.acquisition_init.prn = obj.sv_prns;
        [obj.acquisition_init.if_data,~] = fread(obj.file_id,floor(obj.acquisition_length*obj.sample_rate));

        obj.signal_acquistion = SignalAcquisition(obj.acquisition_init);

    end


end




end