function a_next=action_select(enemy,agent,friend,a_next_ac,a_next_mdn2)


for i = 1:36
    abcdefg(i,:)=[cos((i-1)*pi/18),sin((i-1)*pi/18)];
end

%% 计算动作改变前的位置信息
a_ri_now=[friend(1)-agent(1),friend(2)-agent(2)];
friend_theta_now=acos(a_ri_now(1)/norm(a_ri_now));
if a_ri_now(2)<0
    friend_theta_now=2*pi-friend_theta_now;
end


for i = 1:size(enemy,1)
    b_ri_now(i,1:2)=[enemy(i,1)-agent(1),enemy(i,2)-agent(2)];
    b_ri_now(i,3)=norm(b_ri_now(i,1:2));

end

[b_dis_now,index_now]=sort(b_ri_now(:,3));
enemy_dis_now=b_dis_now(1);
enemy_theta_now=acos(b_ri_now(index_now(1),1)/b_ri_now(index_now(1),3));
if b_ri_now(index_now(1),2)<0
    enemy_theta_now=2*pi-enemy_theta_now;
end

jiaodu_cha_now=abs(friend_theta_now-enemy_theta_now);

%% 计算通过ac改变
agent_ac=agent+abcdefg(a_next_ac,:)*15;
agent_ac=round(agent_ac);


a_ri_ac=[friend(1)-agent_ac(1),friend(2)-agent_ac(2)];
friend_theta_ac=acos(a_ri_ac(1)/norm(a_ri_ac));
if a_ri_ac(2)<0
    friend_theta_ac=2*pi-friend_theta_ac;
end

for i = 1:size(enemy,1)
    b_ri_ac(i,1:2)=[enemy(i,1)-agent_ac(1),enemy(i,2)-agent_ac(2)];
    b_ri_ac(i,3)=norm(b_ri_ac(i,1:2));
end

[b_dis_ac,index_ac]=sort(b_ri_ac(:,3));
enemy_dis_ac=b_dis_ac(1);
enemy_theta_ac=acos(b_ri_ac(index_ac(1),1)/b_ri_ac(index_ac(1),3));
if b_ri_ac(index_ac(1),2)<0
    enemy_theta_ac=2*pi-enemy_theta_ac;
end

jiaodu_cha_ac=abs(friend_theta_ac-enemy_theta_ac);

%% 计算通过mdn2改变
agent_mdn2=agent+abcdefg(a_next_mdn2,:)*15;
agent_mdn2=round(agent_mdn2);

a_ri_mdn2=[friend(1)-agent_mdn2(1),friend(2)-agent_mdn2(2)];
friend_theta_mdn2=acos(a_ri_mdn2(1)/norm(a_ri_mdn2));
if a_ri_mdn2(2)<0
    friend_theta_mdn2=2*pi-friend_theta_mdn2;
end

for i = 1:size(enemy,1)
    b_ri_mdn2(i,1:2)=[enemy(i,1)-agent_mdn2(1),enemy(i,2)-agent_mdn2(2)];
    b_ri_mdn2(i,3)=norm(b_ri_mdn2(i,1:2));
end

[b_dis_mdn2,index_mdn2]=sort(b_ri_mdn2(:,3));
enemy_dis_mdn2=b_dis_mdn2(1);
enemy_theta_mdn2=acos(b_ri_mdn2(index_mdn2(1),1)/b_ri_mdn2(index_mdn2(1),3));
if b_ri_mdn2(index_mdn2(1),2)<0
    enemy_theta_mdn2=2*pi-enemy_theta_mdn2;
end

jiaodu_cha_mdn2=abs(friend_theta_mdn2-enemy_theta_mdn2);

%% 动作选择
while(1)

%     
    if enemy_dis_ac<=15
        a_next=a_next_mdn2(1);
        break
    end
    
    if enemy_dis_mdn2<=15
        a_next=a_next_ac(1);
        break
    end

    
    w1=0.7;
    w2=0.3;
    w3=0.3;
    a111111=norm(a_ri_now)-norm(a_ri_mdn2);
    a22222=norm(a_ri_now)-norm(a_ri_ac);
    mdn2_goal=((norm(a_ri_now)-norm(a_ri_mdn2))/15)*w1+((enemy_dis_mdn2-enemy_dis_now)/15)*w2;
    ac_goal=((norm(a_ri_now)-norm(a_ri_ac))/15)*w1+((enemy_dis_ac-enemy_dis_now)/15)*w2;

    if mdn2_goal>ac_goal
        a_next=a_next_mdn2(1);
    else
        a_next=a_next_ac(1);
    end
    break
    
    
    
    
end
