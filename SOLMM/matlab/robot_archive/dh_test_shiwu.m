function a_next = dh_test_shiwu(agent,laserMap,friend)

persistent checkpoint
if isempty(checkpoint)
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    checkpoint = load(fullfile(root, 'models', 'goodmodel.mat'), 'network');
end
network = checkpoint.network;
un=200; 
pnum=200;
snum=200;
nn=36;

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




            network.X.Xu_input=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/(fri_dis+en_dis)];
            %%
            %Yu响应值
            for i=1:network.Y.y_u_neuron_num
                network.Y.y_u.response(i)=(network.X.Xu_input/norm(network.X.Xu_input))*...
                    (network.Y.y_u_neuron(i).X_Y_weight/norm(network.Y.y_u_neuron(i).X_Y_weight));
            end

            %Yp响应值 60
            if en_dis<=0.65
                for i=1:network.Y.y_p_neuron_num
                    network.Y.y_p.response(i)=(network.X.Xu_input/norm(network.X.Xu_input))*...
                        (network.Y.y_p_neuron(i).X_Y_weight/norm(network.Y.y_p_neuron(i).X_Y_weight));
                end
            else
                network.Y.y_p.response=zeros(pnum,1);
            end
            %Ys响应值  60
            if fri_dis>=0.25
                for i=1:network.Y.y_s_neuron_num
                    network.Y.y_s.response(i)=(network.X.Xu_input/norm(network.X.Xu_input))*...
                        (network.Y.y_s_neuron(i).X_Y_weight/norm(network.Y.y_s_neuron(i).X_Y_weight));
                end
            else
                network.Y.y_s.response=zeros(snum,1);
            end
            %%  对y层各部分的响应值进行处理
            %对Yu响应值处理
            [top_k_Yu,winner_num_Yu]=sort(network.Y.y_u.response,'descend');
            network.Y.y_u.response=zeros(un,1);
            network.Y.y_u.response(winner_num_Yu(1))=1;

            %对Yp响应值处理
            if en_dis<=0.65
                [top_k_Yp,winner_num_Yp]=sort(network.Y.y_p.response,'descend');
                network.Y.y_p.response=zeros(pnum,1);
                network.Y.y_p.response(winner_num_Yp(1))=1;
            end
            %对Ys响应值处理
            if fri_dis>0.25
                [top_k_Ys,winner_num_Ys]=sort(network.Y.y_s.response,'descend');
                network.Y.y_s.response=zeros(snum,1);
                network.Y.y_s.response(winner_num_Ys(1))=1;
            end


            %%求z层各响应值及最终z输出network.z.out

            %z层各响应值
            for i=1:network.Z.z_u_neuron_num
                network.Z.z_u.response(i)=(network.Y.y_u.response'*network.Z.z_u_neuron(i).Y_Z_weight);
                network.Z.z_p.response(i)=(network.Y.y_p.response'*network.Z.z_p_neuron(i).Y_Z_weight);
                network.Z.z_s.response(i)=(network.Y.y_s.response'*network.Z.z_s_neuron(i).Y_Z_weight);
            end
            %求z综合输出       A、B是正数，且A<B，数值待定       暂定A=3，B=8  .
            for i=1:network.Z.z_u_neuron_num
                %    network.Z.z_neuron(i).out=network.Z.z_u_neuron(i).response*(1+A*network.Z.z_s_neuron(i).response-B*network.Z.z_p_neuron(i).response);
                 network.Z.z_neuron(i).out=network.Z.z_u.response(i)*(1+3*network.Z.z_s.response(i)-8*network.Z.z_p.response(i));
        %           network.Z.z_neuron(i).out=network.Z.z_u.response(i)+*network.Z.z_s.response(i)-*network.Z.z_p.response(i);
                if network.Z.z_neuron(i).out<0
                    network.Z.z_neuron(i).out=0;
                end
            end
            for i=1:network.Z.z_u_neuron_num
                cc(i,1)=network.Z.z_neuron(i).out;
            end

            [out_max,a_next]=max(cc(1:36));



