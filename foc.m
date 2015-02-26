% simulate one cycle


function [Ia Ib Ic V1 V2 V3 VN] = foc(IPeak, VqSet, Vbus, draw_plot)

    t = 0:0.05:1;
    w = 2 * pi;

    Ia = cos(w*t) * IPeak;
    Ib = cos(w*t-2*pi/3) * IPeak;
    Ic = cos(w*t-4*pi/3) * IPeak;

    Ialpha = Ia;
    Ibeta = Ia/sqrt(3) + 2*Ib/sqrt(3);
    
    sinTheta = sin(w*t-pi/2);
    cosTheta = cos(w*t-pi/2);

    Id =  Ialpha .* cosTheta + Ibeta .* sinTheta;
    Iq = -Ialpha .* sinTheta + Ibeta .* cosTheta;

    Vd = 0*ones(1,length(t));
    Vq = VqSet*ones(1,length(t));

    Valpha = Vd .* cosTheta - Vq .* sinTheta;
    Vbeta =  Vd .* sinTheta + Vq .* cosTheta;

    Va = Valpha;
    Vb = -Valpha * 0.5 + sqrt(3.0)/2.0 * Vbeta;
    Vc = -Valpha * 0.5 - sqrt(3.0)/2.0 * Vbeta;

    %Va = Va*0.5;
    %Vb = Vb*0.5;
    %Vc = Vc*0.5;

    Vk = (( max([Va; Vb; Vc])' + min([Va; Vb; Vc])' ) * 0.5);

    V1 = (Va - Vk')/Vbus+0.5;
    V2 = (Vb - Vk')/Vbus+0.5;
    V3 = (Vc - Vk')/Vbus+0.5;

    VN = (V1 + V2 + V3) / 3;     
    
    if (draw_plot)
        subplot(331);
        plot(t,Ia,t,Ib,t,Ic);
        legend('Ia','Ib','Ic');

        subplot(334);
        plot(t,Ialpha,t,Ibeta);
        legend('I\alpha','I\beta');

        subplot(337);
        plot(t,Id,t,Iq);
        legend('Id','Iq');

        subplot(338);
        plot(t,Vd,t,Vq);
        legend('Vd','Vq');

        subplot(335);
        plot(t,Valpha,t,Vbeta);
        legend('V\alpha','V\beta');

        subplot(332);
        plot(t,Va,t,Vb,t,Vc);
        legend('Va','Vb','Vc');

        subplot(333);
        plot(t,V1*Vbus,t,V2*Vbus,t,V3*Vbus,t,VN*Vbus);
        legend('V1','V2','V3','VN')
    end
end

