function [Ndata_fri_short,Ndata_eny_short,Ndata_u_short,Ndata_u_bad_short]=fxxz(Ndata_fri_linshi,Ndata_eny_linshi,Ndata_u_linshi)

Ndata_u_short=[];
Ndata_fri_short=[];
Ndata_eny_short=[];
Ndata_u_bad_short=[];
% axis([0,100,0,100]);
for i = 1:36
    aaaa(i,:)=0.2*[cos((i-1)*pi/18),sin((i-1)*pi/18)];
end
% plot(0,0,'k.','markersize',10);
% a=rand(10,2)*100;
xla=[1,0];yla=[0,1];
for i=1:length(Ndata_fri_linshi)
    %     plot1=plot(Ndata_fri(i,1),Ndata_fri(i,2),'gp','markersize',5);
    %     plot2=plot(Ndata_eny(i,1),Ndata_eny(i,2),'r.','markersize',10);
    %     delete(plot1);
    %     delete(plot2);
    %     dis_eny=sqrt(Ndata_eny(i,1)^2+Ndata_eny(i,2)^2);
    fri_zuobiao=[Ndata_fri_linshi(i,1),Ndata_fri_linshi(i,2)];
    fri_thetax_i=acos(dot(fri_zuobiao,xla)/(norm(fri_zuobiao)*norm(xla)));
    fri_thetay_i=acos(dot(fri_zuobiao,yla)/(norm(fri_zuobiao)*norm(yla)));
    %计算夹角
    if(fri_thetay_i>pi/2)
        fri_theta=2*pi-fri_thetax_i;
    else
        fri_theta=fri_thetax_i;
    end
    fri_dis=norm(fri_zuobiao);
    
    en_zuobiao=[Ndata_eny_linshi(i,1),Ndata_eny_linshi(i,2)];                              %障碍物坐标
    en_thetax_i=acos(dot(en_zuobiao,xla)/(norm(en_zuobiao)*norm(xla)));   %dot(en_coordinate,xla)是障碍物坐标沿x轴的投影，(norm(en_coordinate)*norm(xla))障碍物坐标的模，en_thetax_i障碍物沿x轴的夹角
    en_thetay_i=acos(dot(en_zuobiao,yla)/(norm(en_zuobiao)*norm(yla)));   %障碍物沿Y轴的夹角
    %计算夹角
    if(en_thetay_i>pi/2)
        en_theta=2*pi-en_thetax_i;
    else
        en_theta=en_thetax_i;
    end
    %     计算距离
    en_dis=norm(en_zuobiao);
    
    for zzz=1:36
        ccc(zzz)=abs((zzz-1)*pi/18-fri_theta);
        ddd(zzz)=abs((zzz-1)*pi/18-en_theta);
    end
    [out_max1,index1]=sort(ccc);
    [out_max2,index2]=sort(ddd);
    
    jiaodu_cha=abs(fri_theta-en_theta);
    
    if fri_dis>45
        Ndata_s(i)=index1(1);
    else
        Ndata_s(i)=0;
    end
     
    if en_dis>=65
        Ndata_p(i)=0;
    else
        Ndata_p(i)=index2(1);
    end
    
    
    
    
    
    if en_dis>=65
        Ndata_u=index1(1);
    else
        if jiaodu_cha>pi/2
            Ndata_u=index1(1);
        elseif jiaodu_cha>pi/4
            if en_dis*sin(jiaodu_cha)>40
                Ndata_u=index1(1);
            else
                if en_theta>fri_theta
                    asdasgfsaddsad=index2(1)-2;
                    if asdasgfsaddsad<1
                        asdasgfsaddsad=asdasgfsaddsad+36;
                    end
                else
                    asdasgfsaddsad=index2(1)+2;
                    if asdasgfsaddsad>36
                        asdasgfsaddsad=asdasgfsaddsad-36;
                    end
                end
                Ndata_u=asdasgfsaddsad;
            end
        elseif jiaodu_cha>pi/8
            if en_dis*sin(jiaodu_cha)>45
                Ndata_u=index1(1);
            else
                if en_theta>fri_theta
                    asdasgfsaddsad=index2(1)-4;
                    if asdasgfsaddsad<1
                        asdasgfsaddsad=asdasgfsaddsad+36;
                    end
                else
                    asdasgfsaddsad=index2(1)+4;
                    if asdasgfsaddsad>36
                        asdasgfsaddsad=asdasgfsaddsad-36;
                    end
                end
                Ndata_u=asdasgfsaddsad;
            end
        else
            if en_dis>55
                hjhjhjhjhjhj=5;
            elseif en_dis>45
                hjhjhjhjhjhj=7;
            else
                hjhjhjhjhjhj=9;
            end
            
            if en_theta>fri_theta
                asdasgfsaddsad=index2(1)-hjhjhjhjhjhj;
                if asdasgfsaddsad<1
                    asdasgfsaddsad=asdasgfsaddsad+36;
                end
            else
                asdasgfsaddsad=index2(1)+hjhjhjhjhjhj;
                if asdasgfsaddsad>36
                    asdasgfsaddsad=asdasgfsaddsad-36;
                end
            end
            Ndata_u=asdasgfsaddsad;
        end
        
        
        
        
    end
        if Ndata_u==Ndata_u_linshi(i)
            Ndata_fri_short=Ndata_fri_short;
            Ndata_eny_short=Ndata_eny_short;
            Ndata_u_short=Ndata_u_short;
        else
            Ndata_fri_short=[Ndata_fri_short;Ndata_fri_linshi(i,1),Ndata_fri_linshi(i,2)];
            Ndata_eny_short=[Ndata_eny_short;Ndata_eny_linshi(i,1),Ndata_eny_linshi(i,2)];
            Ndata_u_short=[Ndata_u_short;Ndata_u];
            Ndata_u_bad_short=[Ndata_u_bad_short;Ndata_u_linshi(i)];
        end
    end


    
    
    
