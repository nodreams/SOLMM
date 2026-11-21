function memorycons(Ndata_fri_short,Ndata_eny_short,Ndata_u_short,Ndata_u_bad_short,epochs)

if nargin < 5
    epochs = 10;
end
validateattributes(epochs, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'});

load gongguMDN2.mat
y_100_num=100;
y_011_num=1000;
%%%%%%%%%%% 训练网络 %%%%%%%%
%%以智能体初始坐标为原点，计算智能体与障碍物和目标的夹角与距离
%%夹角计算公式 两个向量 a，b 夹角公式为theta = acos(dot(a,b)/norm(a)*norm(b))
%% xla=[1,0];yla=[0,1];分别代表x轴和y轴

xla=[1,0];yla=[0,1];

%% 计算输入
% 计算智能体与障碍物的夹角和距离

% 计算智能体与目标的夹角和距离
%Ndata_fri
for j=1:length(Ndata_fri_short)
    fri_zuobiao=[Ndata_fri_short(j,1),Ndata_fri_short(j,2)];
    fri_thetax_i=acos(dot(fri_zuobiao,xla)/(norm(fri_zuobiao)*norm(xla)));
    fri_thetay_i=acos(dot(fri_zuobiao,yla)/(norm(fri_zuobiao)*norm(yla)));
    %计算夹角
    if(fri_thetay_i>pi/2)
        fri_theta(j)=2*pi-fri_thetax_i;
    else
        fri_theta(j)=fri_thetax_i;
    end
    
    % %     计算距离
    fri_dis(j)=norm(fri_zuobiao);

    if fri_dis(j)<=25
        network.X.Xs(j)=0;
    else
        network.X.Xs(j)=1;
    end

end
%%以智能体初始坐标为原点，计算智能体与障碍物和目标的夹角与距离
%Ndata_eny
for j=1:length(Ndata_eny_short)
    en_zuobiao=[Ndata_eny_short(j,1),Ndata_eny_short(j,2)];                              %障碍物坐标
    en_thetax_i=acos(dot(en_zuobiao,xla)/(norm(en_zuobiao)*norm(xla)));   %dot(en_coordinate,xla)是障碍物坐标沿x轴的投影，(norm(en_coordinate)*norm(xla))障碍物坐标的模，en_thetax_i障碍物沿x轴的夹角
    en_thetay_i=acos(dot(en_zuobiao,yla)/(norm(en_zuobiao)*norm(yla)));   %障碍物沿Y轴的夹角
    %计算夹角
    if(en_thetay_i>pi/2)
        en_theta(j)=2*pi-en_thetax_i;
    else
        en_theta(j)=en_thetax_i;
    end
    %     计算距离
    en_dis(j)=norm(en_zuobiao);
    
    arfa=abs(en_theta(j)-fri_theta(j));

        if en_dis(j)<=65
        network.X.Xp(j)=1;
    else
        network.X.Xp(j)=0;
    end
    
end

for mm=1:epochs
    
    for j = 1:length(Ndata_fri_short)
%% 计算X层输入
        network.X.X_input=[cos(fri_theta(j)),sin(fri_theta(j)),cos(en_theta(j)),sin(en_theta(j)),fri_dis(j)/(fri_dis(j)+en_dis(j)),en_dis(j)/(fri_dis(j)+en_dis(j))];
        %[目标与智能体的夹角余弦，目标与智能体的夹角正弦，障碍物与智能体夹角的余弦，障碍物与智能体夹角的正弦，智能体距目标距离/（智能体距障碍物距离+距目标距离），智能体距障碍物距离/（智能体距障碍物距离+距目标距离）]


        
        if ((en_dis(j)<=65)&&(en_dis(j)>=22))
            w_p=(65-en_dis(j))/(65-22);
        elseif en_dis(j)<22
            w_p=22/en_dis(j);
        else
            w_p=0;
        end
        %释放奖励的开关
        if (fri_dis(j)<=200)&&(fri_dis(j)>=45)
            w_s=(fri_dis(j)-45)/200;
        elseif fri_dis(j)>200
            w_s=fri_dis(j)/200;
        else
            w_s=0;
        end
  
%% 计算Y层响应值
%y_u--------------------------------------------------------------------------------------    
    %y_100_u
    
            for i = 1:network.Y.y_100_u_neuron_num
                network.Y.y_100_u.response(i)=(network.X.X_input/norm(network.X.X_input))*...
                    (network.Y.y_100_u_neuron(i).X_Y_100_u_weight/norm(network.Y.y_100_u_neuron(i).X_Y_100_u_weight));
            end

            [top_k_y_100_u,winner_num_y_100_u]=sort(network.Y.y_100_u.response,'descend');
            network.Y.y_100_u.response=zeros(y_100_num,1);
            for i=1:6
                network.Y.y_100_u.response(winner_num_y_100_u(i))=1;        
            end



        %y_011_u

            for i=1:network.Y.y_011_u_neuron_num
                network.Y.y_011_u.response(i)=(network.Y.y_100_u.response'/norm(network.Y.y_100_u.response))*...
                    (network.Y.y_011_u_neuron(i).Y_100_u_Y_011_u_weight/norm(network.Y.y_011_u_neuron(i).Y_100_u_Y_011_u_weight));

            end

            [top_k_y_011_u,winner_num_y_011_u]=sort(network.Y.y_011_u.response,'descend');
            network.Y.y_011_u.response=zeros(y_011_num,1);
            network.Y.y_011_u.response(winner_num_y_011_u(1))=1;

    %% 更新Y层权值
 
        k=1;
        d100u=find(network.Y.y_100_u.age==1);%%返回年龄等于1的神经元位置
        d011u=find(network.Y.y_011_u.age==1);
        yuzhi=0.95;

    %%  更新y各部分权重
%y_u----------------------------------------------------------------------------------
            %y_100_u
%         if isempty(d100u)==0
%             for i=1:k
%                 if top_k_y_100_u(i)<yuzhi
%                     winner_num_y_100_u(i)=d100u(i);
%                 end
%             end
%         end

        for i=1:6
            temp_i=winner_num_y_100_u(i);
            w2=(1+w_p+w_s)/network.Y.y_100_u.age(temp_i);
            network.Y.y_100_u_neuron(temp_i).X_Y_100_u_weight=network.Y.y_100_u_neuron(temp_i).X_Y_100_u_weight*(1-w2)+...
                (network.X.X_input'/norm(network.X.X_input))*w2;

            network.Y.y_100_u.age(temp_i)=network.Y.y_100_u.age(temp_i)+1;
        end
    
        if isempty(d011u)==0
            if top_k_y_011_u(1)<yuzhi
                winner_num_y_011_u(1)=d011u(1);
            end
        end
    %y_011_u
        for i=1:k
            temp_i=winner_num_y_011_u(i);
            w2=(1+w_p+w_s)/network.Y.y_011_u.age(temp_i);
            network.Y.y_011_u_neuron(temp_i).Y_100_u_Y_011_u_weight=network.Y.y_011_u_neuron(temp_i).Y_100_u_Y_011_u_weight*(1-w2)+...
                network.Y.y_100_u.response*w2;

            network.Y.y_011_u.age(temp_i)=network.Y.y_011_u.age(temp_i)+1;
        end


    
    %% 更新Z层权值
%     %z_u
% 
%     network.Z.z_neuron(Ndata_u_short(j)).Y_011_Z_weight=((network.Z.z.age(Ndata_u_short(j))-1)/network.Z.z.age(Ndata_u_short(j)))*network.Z.z_neuron(Ndata_u_short(j)).Y_011_Z_weight+...
%        network.Y.y_011.response/network.Z.z.age(Ndata_u_short(j));
%     network.Z.z.age(Ndata_u_short(j))=network.Z.z.age(Ndata_u_short(j))+1;
   
%z_u
        network.Z.z_u_neuron(Ndata_u_bad_short(j)).Y_011_u_Z_weight=(network.Z.z_u_neuron(Ndata_u_bad_short(j)).Y_011_u_Z_weight-network.Y.y_011_u.response)/(network.Z.z_u.age(Ndata_u_bad_short(j))-1);
        network.Z.z_u.age(Ndata_u_bad_short(j))=network.Z.z_u.age(Ndata_u_bad_short(j))-1;
        
        network.Z.z_u_neuron(Ndata_u_short(j)).Y_011_u_Z_weight=(network.Z.z_u.age(Ndata_u_short(j))-1)*network.Z.z_u_neuron(Ndata_u_short(j)).Y_011_u_Z_weight...
            /network.Z.z_u.age(Ndata_u_short(j))+network.Y.y_011_u.response/network.Z.z_u.age(Ndata_u_short(j));
        network.Z.z_u.age(Ndata_u_short(j))=network.Z.z_u.age(Ndata_u_short(j))+1;

        %z_p

    end
mm
end
save gongguMDN2.mat
