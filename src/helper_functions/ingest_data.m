function path_to_IF_data = ingest_data

%{

    Author: Nick Ott

    The purpose of this script is to allow a user to specify the path to a
    folder containing simualted vehicel motion data as well as satellite
    position and velocity states and return the corresponding .csv files

    This script will also return the path to this folder (which will have
    to contain the IF data for the corresponding dataset). This path needs
    to be returned b/c the IF data is too large to read in it's entirety
    into the workspace, so the path will be returned for the tracking
    script to load the IF data in chunks.

%}

fprintf('PLEASE SELECT THE FOLDER CONTAINING SV DATA TO BE PROCESSED!\n');

path_to_data = uigetdir();

addpath(genpath(path_to_data));

path_IF = dir(fullfile(path_to_data,'*.bin'));

path_to_IF_data = [path_IF.folder '\' path_IF.name];

end
