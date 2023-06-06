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

    % --- General Properties --- %
    if_data_handle
    if_frequency
    
    sv_prns
    nominal_chipping_rate
    sample_rate
    
    % --- Acquisition Properties --- %
    acquisition_init = struct('acquisition_threshold',0,'acquisition_period',0,'acquisition_step_size',0);

    % --- Tracking Properties --- %
    filter_bandwidths
    cn0_averaging_window

end

methods

    function obj = SoftwareDefinedReceiver(initialization)

        acquisition_init.aq_threshold = initialization.

    end


end




end