# gps_signal_tracking
A home-brewed attempt to develop a comprehensive gps signal tracking system (first in matlab then in python) to intake IF data and produce a gps position solution

I will be importing the following work from software that I developed in a class I took on GPS navigation:

  1) SignalAcquisition
    a) This class is responsible for intaking a set (max 20 ms) of IF data and running through a parallel search algorithm to identify satellites (SV's) in view, as well as the initial conditions (code shift and doppler shift) to initiate a tracking channel per SV
    
The following needs to be done:

  1) PLL matlab class
    a) I will be implementing a 3rd order PLL that is assisted w/ a 2nd order FLL to handle relatively dynamic data while providing a smoother estimate of doppler
    
  2) DLL matlab class
    a) This will probably be just a second order DLL for now. The effect of doppler on the code tracking is less pronounced than the effect of doppler on the carrier tracking, so this will be simpler for now. If stability concerns become an issue, the plan is to share doppler information from the PLL into the DLL and use this to compensate for error.
    
  3) Tracking Channel Class
    a) This will be the class in which an instance will be created to perform tracking for a single SV. It will intake initial conditions and settings (Bandwidths) and then pass these to the child PLL and DLL matlab classes. 
