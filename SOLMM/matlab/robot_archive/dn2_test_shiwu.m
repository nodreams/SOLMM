function a_next = dn2_test_shiwu(agent,laserMap,friend)
% global network
persistent checkpoint
if isempty(checkpoint)
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    checkpoint = load(fullfile(root, 'models', 'gongguMDN2.mat'), 'network');
end
network = checkpoint.network;
% un=400; 

y_100_num=100;
y_011_num=1000;
nn=36;

cc = zeros(nn,1);




%% 朋友和敌人分别与智能体的角度theta、欧氏距离dis
    
     a_ri=[friend(1)-agent(1),friend(2)-agent(2)];
    
        for k=1:size(laserMap, 1)
            b_ri(k,1:2)=[laserMap(k,1)-agent(1),laserMap(k,2)-agent(2)];
            b_ri(k,3)=norm(b_ri(k,1:2));
        end
%% 朋友和敌人分别与智能体的角度theta、欧氏距离dis
    
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

            %%    
        %     network.X.Xu_input=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/210];
            network.X.X_input=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/(fri_dis+en_dis)];
            %%
        for i = 1:network.Y.y_100_u_neuron_num
            network.Y.y_100_u.response(i)=(network.X.X_input/norm(network.X.X_input))*...
                normalized_weight(network.Y.y_100_u_neuron(i).X_Y_100_u_weight);
        end
        
        [top_k_y_100_u,winner_num_y_100_u]=sort(network.Y.y_100_u.response,'descend');
        network.Y.y_100_u.response=zeros(y_100_num,1);
        for i=1:6
            network.Y.y_100_u.response(winner_num_y_100_u(i))=1; 
        end
        
        for i=1:network.Y.y_011_u_neuron_num
            %         计算自底向上的响应
            % 响应 = 输入 * 权重 （全都要做归一化处理）

            network.Y.y_011_u.response(i)=(network.Y.y_100_u.response'/norm(network.Y.y_100_u.response))*...
                normalized_weight(network.Y.y_011_u_neuron(i).Y_100_u_Y_011_u_weight);
                
        end
    
        [top_k_y_011_u,winner_num_y_011_u]=sort(network.Y.y_011_u.response,'descend');
        network.Y.y_011_u.response=zeros(y_011_num,1);
        network.Y.y_011_u.response(winner_num_y_011_u(1))=1;
%         
        if en_dis<=65
            for i=1:network.Y.y_100_p_neuron_num
            %计算自底向上的响应
                network.Y.y_100_p.response(i)=(network.X.X_input/norm(network.X.X_input))*...
                    normalized_weight(network.Y.y_100_p_neuron(i).X_Y_100_p_weight);
            end
        
            [top_k_y_100_p,winner_num_y_100_p]=sort(network.Y.y_100_p.response,'descend');
            network.Y.y_100_p.response=zeros(y_100_num,1);
            for i=1:6
                network.Y.y_100_p.response(winner_num_y_100_p(i))=1;
            end
        
%     %y_011_p           
            for i=1:network.Y.y_011_p_neuron_num
                network.Y.y_011_p.response(i)=network.Y.y_100_p.response'*...
                    normalized_weight(network.Y.y_011_p_neuron(i).Y_100_p_Y_011_p_weight);
            end
            
            [top_k_y_011_p,winner_num_y_011_p]=sort(network.Y.y_011_p.response,'descend');
            network.Y.y_011_p.response=zeros(y_011_num,1);
            network.Y.y_011_p.response(winner_num_y_011_p(1))=1;
        else
            network.Y.y_011_p.response=zeros(y_011_num,1);
        end
            
        if fri_dis>=45
            for i=1:network.Y.y_100_s_neuron_num
            %计算自底向上的响应
                network.Y.y_100_s.response(i)=(network.X.X_input/norm(network.X.X_input))*...
                    normalized_weight(network.Y.y_100_s_neuron(i).X_Y_100_s_weight);
            end
        
            [top_k_y_100_s,winner_num_y_100_s]=sort(network.Y.y_100_s.response,'descend');
            network.Y.y_100_s.response=zeros(y_100_num,1);
            for i=1:6
                network.Y.y_100_s.response(winner_num_y_100_s(i))=1;
            end
%         
%     %y_011_s           
            for i=1:network.Y.y_011_s_neuron_num
                network.Y.y_011_s.response(i)=network.Y.y_100_s.response'*...
                    normalized_weight(network.Y.y_011_s_neuron(i).Y_100_s_Y_011_s_weight);
            end
    
            [top_k_y_011_s,winner_num_y_011_s]=sort(network.Y.y_011_s.response,'descend');
            network.Y.y_011_s.response=zeros(y_011_num,1);
            network.Y.y_011_s.response(winner_num_y_011_s(1))=1;
    
        else
            network.Y.y_011_s.response=zeros(y_011_num,1);
        end
    %y_011

    
            %%  对y层各部分的响应值进行处理
          %%求z层各响应值及最终z输出network.z.out

            %z层各响应值
            for i=1:network.Z.z_u_neuron_num
                network.Z.z_u.response(i)=(network.Y.y_011_u.response'*double(network.Z.z_u_neuron(i).Y_011_u_Z_weight));
                network.Z.z_p.response(i)=(network.Y.y_011_p.response'*double(network.Z.z_p_neuron(i).Y_011_p_Z_weight));
                network.Z.z_s.response(i)=(network.Y.y_011_s.response'*double(network.Z.z_s_neuron(i).Y_011_s_Z_weight));

            end
            %求z综合输出       A、B是正数，且A<B，数值待定       暂定A=3，B=8  .
            for i=1:network.Z.z_u_neuron_num
                %    network.Z.z_neuron(i).out=network.Z.z_u_neuron(i).response*(1+A*network.Z.z_s_neuron(i).response-B*network.Z.z_p_neuron(i).response);
%                  network.Z.z_neuron(i).out=network.Z.z_u.response(i)*20+network.Z.z_s.response(i)*1-network.Z.z_p.response(i)*3;
%                  network.Z.z_neuron(i).out=network.Z.z_u.response(i);
%                     network.Z.z_neuron(i).out=network.Z.z_u.response(i);
                    network.Z.z_neuron(i).out=network.Z.z_u.response(i)*(1+3*network.Z.z_s.response(i)-10*network.Z.z_p.response(i));

        %           network.Z.z_neuron(i).out=network.Z.z_u.response(i)+*network.Z.z_s.response(i)-*network.Z.z_p.response(i);
                if network.Z.z_neuron(i).out<0
                    network.Z.z_neuron(i).out=0;
                end
            end
            for i=1:network.Z.z_u_neuron_num
                cc(i,1)=network.Z.z_neuron(i).out;
            end

            [out_max,a_next]=max(cc(1:36));
end

function weight = normalized_weight(weight)
weight = double(weight);
weight = weight / max(norm(weight), eps);
end
