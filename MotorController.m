classdef MotorController
    
    properties
        N
        VGateDrive
        RgExternalCharge
        RgExternalDischarge
        VGateDiode
        Fs
        mosfet
        motor
    end
    
    methods
        
        function [P_loss, P_switching_loss, P_gate_drive, P_reverse, P_conduction] ...
                = Loss(mc, Vbus, Vout, Vn, Iout, show_plots)
            
            % Find the ripple current
            Iripple = (Vbus-Vn).*(Vout./Vbus)*1/mc.Fs/mc.motor.L_LN;
            %fprintf('%.3f\n',Iripple);
            
            % Whether the current is positive or negative, the losses will
            % be the same.  The difference is whether it is in the high
            % side FET or the low side.
            Iavg = abs(Iout);
            
            % Build a gate charge vs gate voltage profile
            % (like illustrated in the datasheet)
            Vgs   = [0 mc.mosfet.Vpl mc.mosfet.Vpl mc.VGateDrive ];
            q = [0 mc.mosfet.Qgs mc.mosfet.Qgs+mc.mosfet.Qgd mc.mosfet.QgTotal ];

            % Timestep for gate-drive charging
            dt = 10e-10;
            t = 0:dt:0.1e-6;

            % Specify initial conditions for on and off.
            Ig_on = zeros(1,length(t));
            Qg_on = zeros(1,length(t));
            Vg_on = zeros(1,length(t));

            Ig_off = zeros(1,length(t));
            Qg_off = zeros(1,length(t));
            Vg_off = zeros(1,length(t));

            Ig_off(1) = 0;
            Qg_off(1) = mc.mosfet.QgTotal;
            Vg_off(1) = mc.VGateDrive;

            for i = 2:length(t)
                % Calculate the gate waveforms for turn-on
                Qg_on(i) = Qg_on(i-1) + Ig_on(i-1)*dt;
                Vg_on(i) = interp1(q,Vgs,Qg_on(i));
                Ig_on(i) = (mc.VGateDrive-Vg_on(i))/(mc.mosfet.RgInternal+mc.RgExternalCharge);
            
                % Then determine the turn-off waveforms
                Qg_off(i) = Qg_off(i-1) - Ig_on(i-1)*dt;
                Vg_off(i) = interp1(q,Vgs,Qg_off(i));
                %Ig_off(i) = (Vg_off(i)-mc.VGateDiode-mc.mosfet.RgInternal*Ig_off(i-1))...
                %    /(mc.RgExternalDischarge) ...
                %    + (Vg_off(i)-mc.mosfet.RgInternal*Ig_off(i-1))/(mc.RgExternalCharge);
                
                Ig_off(i) = (Vg_off(i)-mc.mosfet.RgInternal*Ig_off(i-1))/(mc.RgExternalCharge);
            end
                           
            % Next, let's calcualte the loss when the current starts flowing
            % and the voltage remains at vbus
            
            % Determine the critical times for events to start/stop
            t_Vth_on = t(sum(Vg_on<mc.mosfet.Vth));
            t_Vpl_on= t(sum(Vg_on<mc.mosfet.Vpl));
            t_Vpl2_on = t(sum(Vg_on<=mc.mosfet.Vpl));
            
            t_Vpl2_off = t(sum(Vg_off>mc.mosfet.Vpl));
            t_Vpl_off = t(sum(Vg_off>=mc.mosfet.Vpl));
            t_Vth_off = t(sum(Vg_off>mc.mosfet.Vth));
            
            % Determine the duration of those peroids
            tri = t_Vpl_on-t_Vth_on;
            tfv = t_Vpl2_on-t_Vpl_on;
            
            trv = t_Vpl_off - t_Vpl2_off;
            tfi = t_Vth_off - t_Vpl2_off;
            
            if ( Iavg > 0)
                IonRipple = -Iripple;
                IoffRipple = Iripple;
            else
                IonRipple = Iripple;
                IoffRipple = -Iripple;
            end
            
            time_on  = [ 0 t_Vth_on t_Vpl_on t_Vpl2_on max(t) ];
            Ids_on   = [ 0 0 Iavg+IonRipple Iavg+IonRipple Iavg+IonRipple ];
            Vds_on   = [ Vbus Vbus Vbus 0 0 ];
            P_on     = Ids_on .* Vds_on;

            time_off  = [ 0 t_Vpl2_off t_Vpl_off t_Vth_off max(t) ];
            Ids_off   = [ Iavg+IoffRipple Iavg+IoffRipple Iavg+IoffRipple 0 0 ];
            Vds_off   = [ 0 0 Vbus Vbus Vbus ];
            P_off     = Ids_off .* Vds_off;
            
            if ( show_plots )
                % Plot the Results
                figure;
                subplot(5,2,1);
                plot(t.*1e9,Qg_on.*1e9,'linewidth',2);
                ylabel('Qg (nC)','fontweight','bold');
                title('MOSFET Turn-On','fontweight','bold');
                grid on;

                subplot(5,2,2);
                plot(t.*1e9,Qg_off.*1e9,'linewidth',2);
                title('MOSFET Turn-Off','fontweight','bold');
                grid on;

                subplot(5,2,3);
                plot(t.*1e9,Vg_on,'linewidth',2);
                ylabel('Vg (V)','fontweight','bold');
                grid on;

                subplot(5,2,4);
                plot(t.*1e9,Vg_off,'linewidth',2);
                grid on;

                subplot(5,2,5);
                plot(t.*1e9,Ig_on,'linewidth',2);
                ylabel('Ig (A)','fontweight','bold');
                grid on;

                subplot(5,2,6);
                plot(t.*1e9,Ig_off,'linewidth',2);
                grid on;

                subplot(5,2,7);
                [AX, H1, H2] = plotyy(time_on.*1e9,Ids_on,time_on.*1e9,Vds_on);
                set(H1,'linewidth',2);
                set(H2,'linewidth',2);
                set(get(AX(1),'Ylabel'),'String','I_{DS} (A)') 
                set(get(AX(2),'Ylabel'),'String','V_{DS} (A)') 
                set(AX(1),'YLim',[0 Iavg+10]) 
                set(AX(2),'YLim',[0 Vbus+10]) 
                grid on;

                subplot(5,2,8);
                [AX, H1, H2] = plotyy(time_off.*1e9,Ids_off,time_off.*1e9,Vds_off);
                set(H1,'linewidth',2);
                set(H2,'linewidth',2);
                set(get(AX(1),'Ylabel'),'String','I_{DS} (A)') 
                set(get(AX(2),'Ylabel'),'String','V_{DS} (A)') 
                set(AX(1),'YLim',[0 Iavg+10]) 
                set(AX(2),'YLim',[0 Vbus+10]) 
                grid on;

                subplot(5,2,9);
                plot(time_on.*1e9,P_on,'linewidth',2);
                ylabel('Power (w)','fontweight','bold');
                xlabel('Time (ns)','fontweight','bold');
                grid on;

                subplot(5,2,10);
                plot(time_off.*1e9,P_off,'linewidth',2);
                ylabel('Power (w)','fontweight','bold');
                xlabel('Time (ns)','fontweight','bold');
                grid on;
            end

            P_switching_loss = (trapz(time_on,P_on) + trapz(time_off,P_off))*mc.Fs;
            P_gate_drive     = (trapz(t,Ig_off*mc.VGateDrive) + trapz(t,Ig_on*mc.VGateDrive))*mc.N*mc.Fs*2;
            P_reverse = mc.mosfet.Qrr * mc.Fs * Vbus *  mc.N;
            P_conduction = Iavg^2 * (mc.mosfet.RdsOn/mc.N);

            P_loss = P_switching_loss + P_gate_drive + P_conduction + P_reverse;
            
        end

    end
    
end

