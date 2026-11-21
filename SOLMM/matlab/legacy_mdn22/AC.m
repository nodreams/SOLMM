%%混合模型 动态障碍物
function a_next_ac=AC(enemy,friend,agent,RBFNN,C,Q,N,alpha,gamma,delte_ERR,delte_COR,beta_star,beta,t)
% clear
% clc
% 
% S=250000;
% A=9;
% T=100;
% Q=rand(S,A);
% P=rand(S,A);
% alpha=0.5;
% gamma=0.95;
% delte_ERR = zeros(T,S);
% delte_COR = zeros(T,S);
% beta_star = zeros(T+1,S);
% beta_star(1) = 0.5;
% beta = zeros(T+1,S);
% beta(1) = 8.808;
% N=zeros(S,1);
% d_e = 30;
% picname="";
% didi="第";
% cgl="次成功了";
% zzz="陷入局部最小，已退出。";



%     enx=[70,78,86,110,118,290,322,366,382,402,  170,206,250];
%     eny=[410,330,428,370,210,382,250,78,130,90,  90,334,178];
% 
%     enemy=[];
%     for i=1:numel(enx)
%         enemy(i,:)=[enx(i),eny(i)];
%     end
%     eny_num=size(enx,2);

% eny_num=20;
% 
% for i =1:eny_num
%     enemy(i,1)=unifrnd(100,440,1,1);
%     enemy(i,2)=unifrnd(100,440,1,1);
% end


    enx=enemy(:,1);
    eny=enemy(:,2);

% friend=[450,450];
% agent=[50,50];
for i = 1:36
    a(i,:)=[cos((i-1)*pi/18),sin((i-1)*pi/18)];
end

% agent_jb=rectangle('Position',[agent(1)-6,agent(2)-6,12,12],'Curvature',[1,1],'FaceColor','k');
% friend_jb=rectangle('Position',[friend(1)-6,friend(2)-6,12,12],'Curvature',[1,1],'FaceColor','g');

% for i=1:size(enemy,1)
%     enemy_jb(i)=rectangle('Position',[enemy(i,1)-6,enemy(i,2)-6,12,12],'Curvature',[1,1],'FaceColor','r')
% end
% for i=1:length(enx)
%     set(enemy_jb(i),'EraseMode','Xor');
% end


% 
% set(friend_jb,'EraseMode','Xor');
% set(agent_jb,'EraseMode','Xor');
% 
% axis([0,500,0,500]);
% axis square
% f=gcf;
% set(f,'position',[500,200,900,700]); 
% a=10*[0,1;-sin(pi/18),cos(pi/18);-sin(pi/9),cos(pi/9);-sin(pi/6),cos(pi/6);-sin(2*pi/9),cos(2*pi/9);-sin(5*pi/18),cos(5*pi/18);
%     -sin(pi/3),cos(pi/3);-sin(7*pi/18),cos(7*pi/18);-sin(4*pi/9),cos(4*pi/9);-sin(pi/2),cos(pi/2);-sin(10*pi/18),cos(10*pi/18);
%     -sin(11*pi/18),cos(11*pi/18);-sin(2*pi/3),cos(2*pi/3);-sin(13*pi/18),cos(13*pi/18);-sin(7*pi/9),cos(7*pi/9);-sin(15*pi/18),cos(15*pi/18);
%     -sin(8*pi/9),cos(8*pi/9);-sin(17*pi/18),cos(17*pi/18);-sin(pi),cos(pi);-sin(19*pi/18),cos(19*pi/18);-sin(20*pi/18),cos(20*pi/18);
%     -sin(21*pi/18),cos(21*pi/18);-sin(22*pi/18),cos(22*pi/18);-sin(23*pi/18),cos(23*pi/18);-sin(24*pi/18),cos(24*pi/18);-sin(25*pi/18),cos(25*pi/18);
%     -sin(26*pi/18),cos(26*pi/18);-sin(27*pi/18),cos(27*pi/18);-sin(28*pi/18),cos(28*pi/18);-sin(29*pi/18),cos(29*pi/18);-sin(30*pi/18),cos(30*pi/18);
%     -sin(31*pi/18),cos(31*pi/18);-sin(32*pi/18),cos(32*pi/18);-sin(33*pi/18),cos(33*pi/18);-sin(34*pi/18),cos(34*pi/18);-sin(35*pi/18),cos(35*pi/18)];
% a_next=1;
tri=[];
tr=[];
tt=1;
load goodmodel
%%
% clear RBFNN
% N=zeros(250000,1);
% xn=6;
% yn=10000;
% zn=9;
% RBFNN.x_num=xn;
% RBFNN.y_num=yn;
% RBFNN.z_num=zn;
% for i=1:RBFNN.y_num
%     RBFNN.y(i).x_y_weight=ones(xn,1);
% end
% for i=1:RBFNN.z_num
%     RBFNN.z(i).y_z_weight=rand(yn,1);
% end
% RBFNN.y_response=zeros(yn,1);
% RBFNN.z_response=zeros(zn,1);
% C=zeros(250000,6);

%%
% agent=[0,0];
% for i=1:500
%     agent(1)=agent(1)+1;
%     
%     for j=500
%         agent(2)=agent(2)+1;
%         
%         a_ri=[friend(2)-agent(2),friend(1)-agent(1)];
%         for k=1:numel(enx)
%             b_ri(k,1:2)=[enemy(k,1)-agent(1,1),enemy(k,2)-agent(1,2)];
%             b_ri(k,3)=norm(b_ri(k,1:2));
%         end
%         
% %         b2_ri=[enemy_2(2)-agent(2),agent(1)-enemy_2(1)];
% %         b2_dis=norm(b2_ri);
% %         b3_ri=[enemy_3(2)-agent(2),agent(1)-enemy_3(1)];
% %         b3_dis=norm(b3_ri);
% %         b4_ri=[enemy_4(2)-agent(2),agent(1)-enemy_4(1)];
% %         b4_dis=norm(b4_ri);
% %         
% %         b_ri=[b1_ri,b1_dis;b2_ri,b2_dis;b3_ri,b3_dis;b4_ri,b4_dis];
%         
%         fri_theta=acos(a_ri(1)/(norm(a_ri)));%0~180
%         if a_ri(2)<0
%             fri_theta= -fri_theta;%-180~180
%         end                
%         fri_dis=norm(a_ri);
% 
%         [b_dis,index]=sort(b_ri(:,3));
%         bb_ri=b_ri(index(1),1:2);
%     
%         en_theta=acos(bb_ri(1)/(norm(bb_ri)));%0~180
%         if bb_ri(2)<0
%             en_theta=-en_theta;%-180~180
%         end
%         en_dis=b_dis(1);
% 
%         ii=500*(i-1)+j;
%         C(ii,:)=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/210];
% 
%     end
% end

%%
% for t=1:T
    asdgasd=0;
    reward=0;
%     friend=[450,450];
%     enx=[70,78,86,110,118,290,322,366,382,402,  170,206,250];
%     eny=[410,330,428,370,210,382,250,78,130,90,  90,334,178];
%     enemy=[];
%     for i=1:numel(enx)
%         enemy(i,:)=[enx(i),eny(i)];
%     end
%     agent=[50,50];
    s = (agent(1)-1)*500 + agent(2);
    N(s) = N(s)+1;
    tri(t)=0; 
%     distance_dynamic = [];
%     enemy_xy = [];
%     enemy_xy(:,:,1) = enemy(11:13,1:2);
%     agent_xy = [];
%     agent_xy(1,:) = agent;
    
%     while(1) 
%         asdgasd=asdgasd+1;
        %智能体
%         drawnow;
        

        d_fri=sqrt((agent(1)-friend(1))^2+(agent(2)-friend(2))^2);
        a_ri=[friend(1)-agent(1),friend(2)-agent(2)];
        for k=1:numel(enx)
            b_ri(k,1:2)=[enemy(k,1)-agent(1),enemy(k,2)-agent(2)];
            b_ri(k,3)=norm(b_ri(k,1:2));
        end
        
        fri_theta=acos(a_ri(1)/(norm(a_ri)));%0~180
        if a_ri(2)<0
            fri_theta=-fri_theta;%-180~180
        end                
        fri_dis=norm(a_ri);

        [b_dis,index]=sort(b_ri(:,3));
        bb_ri=b_ri(index(1),1:2);
    
        en_theta=acos(bb_ri(1)/(norm(bb_ri)));%0~180
        if bb_ri(2)<0
            en_theta=-en_theta;%-180~180
        end
        en_dis=b_dis(1);
                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        RBFNN.x_input=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/210];
        var=1;
        for i=1:RBFNN.y_num
            RBFNN.y_response(i)=exp(-((norm(RBFNN.x_input-C(i,:)))^2)/(2*(var^2)));
        end
        RBFNN.y_response=RBFNN.y_response/norm(RBFNN.y_response);
        for i=1:RBFNN.z_num
            RBFNN.z_response(i)=(RBFNN.y_response)'*(RBFNN.z(i).y_z_weight/norm(RBFNN.z(i).y_z_weight));
        end

%%

        [m,index]=sort(Q(s,:));            
        e=rand;
        if e<0.1
            aa=floor(9*rand)+1;
        else
            aa=index(9);
        end
        aa = 4*aa-3;
        
%         [p_sort,p_index]=sort(P(s,:));
%         aa = p_index(9);
%         aa = 4*aa-3;
            
%             co = min(1,exp((500-N(s))/200));
%             a_next = co*a_next + (1-co)*aa;
%         if N(s)>200
%             disp(zzz);
%             N(s)=0;
%             break
%         end                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
         
        if N(s)>4                         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            a_next = aa;
        else
           a_dn= dh_test(a_ri,b_ri);
            a_next=a_dn(1);
        end

        a_next_ac=a_next;
 %%
        agent= agent+a(a_next,:)*3;
        a_next_like = round((a_next+3)/4);
        if  a_next_like > 9
            a_next_like = 1;
        end
        agent=round(agent);
        agent_like = round(agent);
        s_next = (agent_like(1)-1)*500 + agent_like(2);
        
        N(s_next) = N(s_next)+1;
        dd_fri=sqrt((agent(1)-friend(1))^2+(agent(2)-friend(2))^2);
              
%         set(friend_jb,'Position',[friend(1)-10,friend(2)-10,20,20],'Curvature',[1,1],'FaceColor','g');
%         set(agent_jb,'Position',[agent(1)-6,agent(2)-6,12,12],'Curvature',[1,1],'FaceColor','k');
%         for i =1:eny_num
%             set(enemy_jb(i),'Position',[enemy(i,1)-6,enemy(i,2)-6,12,12],'Curvature',[1,1],'FaceColor','r');
%         end
        
%%    

        d_s=30;
        d_E = [];
        for k=1:numel(enx)
            d_E(k)=sqrt((agent(1)-enemy(k,1))^2+(agent(2)-enemy(k,2))^2);
        end
        d_e=min(d_E);
       
        
        if agent(1)>480||agent(1)<20||agent(2)>480||agent(2)<20||d_e<d_s||asdgasd>=1000
            reward = -100;
        else
            reward = reward+0;
        end
        
        if dd_fri<d_s
            reward = reward+100;
        elseif dd_fri<25
            reward = reward+10;
        end
        
        if dd_fri<d_fri
            reward = reward+1;
        else
            reward = reward-1;
        end
        
%%      
        Q(s,a_next_like) = (1-alpha)*Q(s,a_next_like) + alpha * (reward + gamma * max(Q(s_next,:)));
        [P(s,:),beta_star(t+1,s)] = ACC(beta_star(t,s),a_next_like,reward,Q(s,:),Q(s_next,:));
        beta(t+1,s) = 10/(1+exp(1-6*(1-beta_star(t+1,s))));
        
        error=(Q(s,:))'-RBFNN.z_response;
        for i=1:RBFNN.z_num
            RBFNN.z(i).y_z_weight=0.1*RBFNN.z(i).y_z_weight+(0.9*error(i)*RBFNN.y_response);
        end

 %%       
        s = s_next;
        tri(t)=tri(t)+1;
        agent_xy((tri(t)+1),:) = agent;
        

%         
%         if agent(1)>480||agent(1)<20||agent(2)>480||agent(2)<20||d_e<15||asdgasd>=1000
%             break
%         end
%         if dd_fri<25
%             break
%         end
        
%     end
    
%%

    %智能体路径
     
    
%%  

%     if dd_fri<25
%         disp([didi,t,cgl]) %%%%%%%%%%%%%%%%%%
%         picname=['D:\Desktop\2021年1月18日\' num2str(t) '.fig'];%保存的文件名：如i=1时，picname=1.fig
%         saveas(gcf,picname)      %%%%%%%%%%%%%%%%%%%%
%         tr(tt)=tri(t);
%         tt=tt+1;  
%         
%     end
    
%     if tri(t)<44&&dd_fri<15
%         break
%     end
    
% end
