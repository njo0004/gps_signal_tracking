function rot_mat_out = euler_to_rotMat(eul_in)

%{
    Author: Nicholas Ott

    Purpose: Intake a set of euler angles and output the corresponding
    relative rotation matrix based on roll pitch and yaw state estimates
    
%}

roll  = eul_in(1);
pitch = eul_in(2);
yaw   = eul_in(3);

rot_mat_out = rot_x(roll)*rot_y(pitch)*rot_z(yaw);

end