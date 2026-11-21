clear
clc

%% 方向
for i = 1:36
    abcdefg(i,:)=[cos((i-1)*pi/18),sin((i-1)*pi/18)];
end


enx=[78,118,290,345,366,382,360,225,195,330,290,165,430,365,259,135,210];
eny=[330,210,382,325,78,130,260,211,267,200,300,170,340,395,162,85,140];
enylen=length(enx);
enemy=[enx',eny'];
enemy_d1=[300,255];
enemy_d2=[206,334];
enemy_d3=[420,265];
enemy_d4=[110,140];
fx=50;
fy=450;
ax=450;
ay=50;
friend=[fx,fy];
agent=[ax,ay];
eny_mov=5;
eny_fan_mov=7;
fri_mov=12;



%% AC参数
S=250000;
A=9;
T=100;
Q=rand(S,A);
P=rand(S,A);
alpha=0.5;
gamma=0.95;
delte_ERR = zeros(T,S);
delte_COR = zeros(T,S);
beta_star = zeros(T+1,S);
beta_star(1) = 0.5;
beta = zeros(T+1,S);
beta(1) = 8.808;
N=zeros(S,1);
d_e = 30;
t=0;
arrive=0;
clear RBFNN
N=zeros(250000,1);
xn=6;
yn=10000;
zn=9;
RBFNN.x_num=xn;
RBFNN.y_num=yn;
RBFNN.z_num=zn;
for i=1:RBFNN.y_num
    RBFNN.y(i).x_y_weight=ones(xn,1);
end
for i=1:RBFNN.z_num
    RBFNN.z(i).y_z_weight=rand(yn,1);
end
RBFNN.y_response=zeros(yn,1);
RBFNN.z_response=zeros(zn,1);
C=zeros(250000,6);

ditu.qishi=[0,0];

for i=1:500
    ditu.qishi(1)=ditu.qishi(1)+1;
    
    for j=500
        ditu.qishi(2)=ditu.qishi(2)+1;
        
        a_ri=[friend(1)-ditu.qishi(1),friend(2)-ditu.qishi(2)];
        for k=1:length(enemy)
            b_ri(k,1:2)=[enemy(k,1)-ditu.qishi(1,1),enemy(k,2)-ditu.qishi(1,2)];
            b_ri(k,3)=norm(b_ri(k,1:2));
        end
        
  
        fri_theta=acos(a_ri(1)/(norm(a_ri)));%0~180
        if a_ri(2)<0
            fri_theta= -fri_theta;%-180~180
        end                
        fri_dis=norm(a_ri);

        [b_dis,index]=sort(b_ri(:,3));
        bb_ri=b_ri(index(1),1:2);
    
        en_theta=acos(bb_ri(1)/(norm(bb_ri)));%0~180
        if bb_ri(2)<0
            en_theta=-en_theta;%-180~180
        end
        en_dis=b_dis(1);

        ii=500*(i-1)+j;
        C(ii,:)=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/210];

    end
end
% 

  
    enemy_d1_sum=[];
        enemy_d2_sum=[];
    enemy_d3_sum=[];
        enemy_d4_sum=[];
%     pause(5);
    agent=[50,50];
    t=t+1;
for yunxingcishu=1:50
    bushu=0;
        dis_min_eny=[];

        enemy_d1=[300,255];
enemy_d2=[206,334];
enemy_d3=[420,265];
enemy_d4=[110,140];
    agent=[450,50];
     Ndata_fri_linshi=[];
    Ndata_eny_linshi=[];
    Ndata_u_linshi=[];

    while(1)
        k=0;
        k=k+1;

%% 动态障碍物        
     random_number1 = randi([-5, 5],500,2);%生成一个1到4之间的随机数
     random_number2 = randi([-5, 5],500,2);
     random_number3 = randi([-5, 5],500,2);
     random_number4 = randi([-5, 5],500,2);
     %动态1
     fx1=[0.4*random_number1(k,1),0.4*random_number1(k,2)];
     enemy_d1=enemy_d1+fx1*eny_mov;
     enemy_d1_sum=[enemy_d1_sum;enemy_d1];
        %动态2
     fx2=[0.4*random_number2(k,1),0.4*random_number2(k,2)];
     enemy_d2=enemy_d2+fx2*eny_mov;
     enemy_d2_sum=[enemy_d2_sum;enemy_d2];     
          %动态3
     fx3=[0.4*random_number3(k,1),0.4*random_number3(k,2)];
     enemy_d3=enemy_d3+fx3*eny_mov;
     enemy_d3_sum=[enemy_d3_sum;enemy_d3];
          %动态4
     fx4=[0.4*random_number4(k,1),0.4*random_number4(k,2)];
     enemy_d4=enemy_d4+fx4*eny_mov;
     enemy_d4_sum=[enemy_d4_sum;enemy_d4];

         enemy(enylen+1,1)=enemy_d1(1);
         enemy(enylen+1,2)=enemy_d1(2);
         enemy(enylen+2,1)=enemy_d2(1);
         enemy(enylen+2,2)=enemy_d2(2);
         enemy(enylen+3,1)=enemy_d3(1);
         enemy(enylen+3,2)=enemy_d3(2);
         enemy(enylen+4,1)=enemy_d4(1);
         enemy(enylen+4,2)=enemy_d4(2);
          for i=1:length(enemy)-4
             enemy_zhuang(i,1:2)=enemy_d1-enemy(i);
             enemy_zhuang(i,3)=norm(enemy_zhuang(i,1:2));
         end
                 [enemy_zhug,index_zhuang]=sortrows(enemy_zhuang,3);
         if enemy_zhug(1,3)<40
              enemy_d1=enemy_d1-fx1*eny_fan_mov;
         end
         
         for i=1:length(enemy)-4
             enemy_zhuang(i,1:2)=enemy_d2-enemy(i);
             enemy_zhuang(i,3)=norm(enemy_zhuang(i,1:2));
         end
                 [enemy_zhug,index_zhuang]=sortrows(enemy_zhuang,3);
         if enemy_zhug(1,3)<40
              enemy_d2=enemy_d2-fx2*eny_fan_mov;
         end
         
         for i=1:length(enemy)-4
             enemy_zhuang(i,1:2)=enemy_d3-enemy(i);
             enemy_zhuang(i,3)=norm(enemy_zhuang(i,1:2));
         end
                 [enemy_zhug,index_zhuang]=sortrows(enemy_zhuang,3);
         if enemy_zhug(1,3)<40
              enemy_d3=enemy_d3-fx3*eny_fan_mov;
         end
         
         for i=1:length(enemy)-4
             enemy_zhuang(i,1:2)=enemy_d4-enemy(i);
             enemy_zhuang(i,3)=norm(enemy_zhuang(i,1:2));
         end
                 [enemy_zhug,index_zhuang]=sortrows(enemy_zhuang,3);
         if enemy_zhug(1,3)<40
              enemy_d4=enemy_d4-fx4*eny_fan_mov;
         end
         

                        %%
        for k=1:length(enemy)
            b_ri(k,1:2)=[enemy(k,1)-agent(1,1),enemy(k,2)-agent(1,2)];
            b_ri(k,3)=norm(b_ri(k,1:2));
        end
        b_ri(length(enemy)+1,1:2)=[enemy_d1(1)-agent(1,1),enemy_d1(2)-agent(1,2)];
         b_ri(length(enemy)+1,3)=norm( b_ri(length(enemy)+1,1:2));
        b_ri(length(enemy)+2,1:2)=[enemy_d2(1)-agent(1,1),enemy_d2(2)-agent(1,2)];
         b_ri(length(enemy)+2,3)=norm( b_ri(length(enemy)+2,1:2));
        b_ri(length(enemy)+3,1:2)=[enemy_d3(1)-agent(1,1),enemy_d3(2)-agent(1,2)];
         b_ri(length(enemy)+3,3)=norm( b_ri(length(enemy)+3,1:2));
        b_ri(length(enemy)+4,1:2)=[enemy_d4(1)-agent(1,1),enemy_d4(2)-agent(1,2)];
         b_ri(length(enemy)+4,3)=norm( b_ri(length(enemy)+4,1:2));     
     
        [dis,index]=sort(b_ri(:,3));
        dis_en=dis(1);
        
        dis_min_eny=[dis_min_eny;dis_en];

        
        Ndata_fri_linshi=[Ndata_fri_linshi;(friend(1)-agent(1)),(friend(2)-agent(2))];
        Ndata_eny_linshi=[Ndata_eny_linshi;b_ri(index(1),1:2)];
        a_next_ac=AC(enemy,friend,agent,RBFNN,C,Q,N,alpha,gamma,delte_ERR,delte_COR,beta_star,beta,t);
        a_next_mdn2=MDN2(enemy,friend,agent);
        a_next=action_select(enemy,agent,friend,a_next_ac,a_next_mdn2);
        Ndata_u_linshi=[Ndata_u_linshi;a_next_mdn2];
        agent=agent+abcdefg(a_next,:)*fri_mov;
        agent=round(agent);
        bushu=bushu+1;
        dis_fri=norm(friend-agent);




        
        if agent(1)>480||agent(1)<20||agent(2)>480||agent(2)<20
            break
        end
        if dis_fri<15
            arrive=arrive+1;
                        zong_bushu(arrive,1)=yunxingcishu;
            zong_bushu(arrive,2)=bushu;
            break;
        end
        if dis_en< 14
            break
        end
        
    end
    
%     [Ndata_fri_short,Ndata_eny_short,Ndata_u_short,Ndata_u_bad_short]=fxxz(Ndata_fri_linshi,Ndata_eny_linshi,Ndata_u_linshi);
%         memorycons(Ndata_fri_short,Ndata_eny_short,Ndata_u_short,Ndata_u_bad_short);

        yunxingcishu
    success_rate=arrive/yunxingcishu
    
           dis_min_huatu(yunxingcishu,1)=min(dis_min_eny);



    

        end

    xlswrite('historical_hybrid_clearance.xlsx',dis_min_huatu);
xlswrite('historical_hybrid_steps.xlsx',zong_bushu);
