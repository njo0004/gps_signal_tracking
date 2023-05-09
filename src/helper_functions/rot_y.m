function out = rot_y(angle)

out = [cos(angle) 0 -sin(angle);...
       0          1  0;...
       sin(angle) 0  cos(angle)];

end