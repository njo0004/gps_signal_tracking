function [skew_mat_out] = skew_sym_mat(gyro_measurements)

%{
    Author: Nicholas Ott
    
    Purpose: Intake a set of body frame intertia angular rate measurements
    and output the skew symmetric matrix of that measurement set. This is
    readily useful in an ECEF imu mechanization 

%}

X = gyro_measurements(1);
Y = gyro_measurements(2);
Z = gyro_measurements(3);

skew_mat_out = [0 -Z  Y;...
                Z  0 -X;...
               -Y  X  0];

end

