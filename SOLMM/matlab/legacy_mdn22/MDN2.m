function a_next_mdn2=MDN2(enemy,friend,agent)
% dn2_create
% dn2_train


%%%% 创建地图
% figure();
% hold on
%% 初始坐标
% ax=50;ay=50;
% fx=450;fy=450;
% enx1=7;eny1=8;
% enx2=4;eny2=6;
% enx3=6;eny3=4;
% enx4=3;eny4=3;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
xla=[1,0];yla=[0,1];
% agent=[ax,ay];          %智能体
% friend=[fx,fy];         %目标机器人
% enemy_1=[enx1,eny1];
% enemy_2=[enx2,eny2];uo
% enemy_3=[enx3,eny3];
% enemy_4=[enx4,eny4]; %四个静态障碍物

% enx1=420;eny1=900;
% enx1=420;eny1=320;
% %enx2=600;eny2=550;
% %enx2=600;eny2=600;%修改
% enx2=600;eny2=518;
% enx3=544;eny3=707;
% enx4=290;eny4=340;
% enx5=480;eny5=400;
% %enx6=400;eny6=470;
% enx6=420;eny6=500;
% enx7=490;eny7=670;
% enx8=300;eny8=600;
% %enx9=260;eny9=500;%修改
% enx9=270;eny9=500;
% %enx10=700;eny10=200;
% %enx10=650;eny10=300;
% enx10=550;eny10=490;
% enx11=450;eny11=450;
% enx12=320;eny12=400;
% enx13=700;eny13=700;
% enx14=650;eny14=350;
% enx15=800;eny15=670;
% enx16=830;eny16=800;
% enx=[enx1,enx2,enx3,enx4,enx5,enx6,enx7,enx8,enx9,enx10,enx11,enx12,enx13,enx14,enx15]/100;
% % eny=[eny1,eny2,eny3,eny4,eny5,eny6,eny7,eny8,eny9,eny10,eny11,eny12,eny13,eny14,eny15]/100;
% enx=[410,78,355,110,118,170,206,230,290,350,366,382,300,225,150,195,296,330,290,110];
% eny=[210,330,270,370,210,90,334,125,382,350,78,130,130,211,160,267,260,200,300,130];
% enemy=[enx',eny'];


% eny_num=25;
% 
% for i =1:eny_num
%     enemy(i,1)=unifrnd(100,440,1,1);
%     enemy(i,2)=unifrnd(100,440,1,1);
%     
% end
    enx=enemy(:,1);
    eny=enemy(:,2);
% 
% 
% p1=plot(agent(1),agent(2),'ks','markersize',10','MarkerFaceColor','k');
% p2=plot(friend(1),friend(2),'gp','markersize',15,'MarkerFaceColor','g');
% 
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% a=[];
% for i = 1:36
%     a(i,:)=[cos((i-1)*pi/18),sin((i-1)*pi/18)];
% end



% a=0.2*[1,0;cos(pi/18),sin(pi/18);cos(pi/9),sin(pi/9);cos(pi/6),sin(pi/6);cos(2*pi/9),sin(2*pi/9);cos(5*pi/18),sin(5*pi/18);cos(pi/3),sin(pi/3);
%     cos(7*pi/18),sin(7*pi/18);cos(4*pi/9),sin(4*pi/9);cos(pi/2),sin(pi/2);cos(10*pi/18),sin(10*pi/18);cos(11*pi/18),sin(11*pi/18);cos(2*pi/3),sin(2*pi/3);
%     cos(13*pi/18),sin(13*pi/18);cos(7*pi/9),sin(7*pi/9);cos(15*pi/18),sin(15*pi/18);cos(8*pi/9),sin(8*pi/9);cos(17*pi/18),sin(17*pi/18);cos(pi),sin(pi);
%     cos(19*pi/18),sin(19*pi/18);cos(20*pi/18),sin(20*pi/18);cos(21*pi/18),sin(21*pi/18);cos(22*pi/18),sin(22*pi/18);cos(23*pi/18),sin(23*pi/18);
%     cos(24*pi/18),sin(24*pi/18);cos(25*pi/18),sin(25*pi/18);cos(26*pi/18),sin(26*pi/18);cos(27*pi/18),sin(27*pi/18);cos(28*pi/18),sin(28*pi/18);
%     cos(29*pi/18),sin(29*pi/18);cos(30*pi/18),sin(30*pi/27);cos(31*pi/18),sin(31*pi/18);cos(32*pi/18),sin(32*pi/18);cos(33*pi/18),sin(33*pi/18);
%     cos(34*pi/18),sin(34*pi/18);cos(35*pi/18),sin(35*pi/18)];
% tri=[];
% tr=[];              
% tt=0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% tic
%     while(1)
%         drawnow;
%         tt=tt+1
        a_ri=[friend(1)-agent(1),friend(2)-agent(2)];
%         enemy=[enemy_1;enemy_2;enemy_3;enemy_4];
        for i = 1:length(enemy)
            b_ri(i,1:2)=[enemy(i,1)-agent(1),enemy(i,2)-agent(2)];
            b_ri(i,3)=norm(b_ri(i,1:2));
        end
        a_next1 = dn2_test(a_ri,b_ri);

%         agent_next(1,1:2) = a(a_next1(1),1:2);
        a_next_mdn2 = a_next1(1);
%         agent= agent+agent_next*20;
%         agent=round(agent);
%         dis_fri=norm(friend-agent);
%         for i = 1:size(b_ri,1)
%             dis_enemy(i)=norm(enemy(i,:)-agent);
%         end
%         [dis,index]=sort(dis_enemy);
%         dis_en=dis(1);

%         set(agent_jb,'Position',[agent(1)-6,agent(2)-6,12,12],'Curvature',[1,1],'FaceColor','k');
        %
%         p1=plot(agent(1),agent(2),'k^','Markersize',1,'Markerfacecolor','k');
% %         text(agent(1),agent(2),num2str(tt),'color','k','FontSize',8);
%         p2=plot(friend(1),friend(2),'gp','markersize',15,'MarkerFaceColor','g');
%         p3=plot(enemy_1(1),enemy_1(2),'r.','markersize',30);
%         plot(enemy_2(1),enemy_2(2),'r.','markersize',30)
%         plot(enemy_3(1),enemy_3(2),'r.','markersize',30)
%         plot(enemy_4(1),enemy_4(2),'r.','markersize',30)
%  for i=1:size(enemy,1)
%         plot(enemy(i,1),enemy(i,2),'r.','markersize',30)
%     end
%         tri(tt)=tri(tt)+1;
        %% 结束条件
%         if agent(1)>490||agent(1)<20||agent(2)>490||agent(2)<20
%             break
%         end 
%         if dis_fri<15
%             
%             break;
%         end
%         if dis_en< 15
%             break
%         end
        
        
%     end
%     toc
    
%     if dis_fri<0.3
%         tr(tt)=tri(t);
%         tt=tt+1;
%     end
