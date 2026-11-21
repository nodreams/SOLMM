function a_next = dn2_test(a_ri,b_ri)
% global network
load gongguMDN2.mat
% load yuanshiMDN2.mat
% un=400; 

y_100_num=100;
y_011_num=1000;
nn=36;
circle=300;
cc = zeros(nn,1);
bb_ri=[];
dis_zhanbi=0.35;


%% 朋友和敌人分别与智能体的角度theta、欧氏距离dis
    
    fri_theta=acos(a_ri(1)/(norm(a_ri)));%0~180
    if a_ri(2)<0
        fri_theta=2*pi-fri_theta;%-180~180
    end                
    fri_dis=norm(a_ri);

    [b_dis,index]=sort(b_ri(:,3));
    
    bb_ri=b_ri(index(1),1:2);
    
    en_theta=acos(bb_ri(1)/(norm(bb_ri)));%0~180
    if bb_ri(2)<0
        en_theta=2*pi-en_theta;%-180~180
    end        
    en_dis=b_dis(1);
%     [b_dis,index]=sort(b_ri(:,3));
%     en_theta=acos(b_ri(index(1),1)/norm(b_ri(index(1))));
%     if b_ri(index(1),2)<0
%         en_theta=2*pi-en_theta;
%     end
    chazhijiao=abs(fri_theta-en_theta);
%     
    while(1)
        if b_ri(index(1),3) < circle 
            if chazhijiao>pi/2
                a_next=zhixian(fri_theta);
                    break    
            end
%             if b_ri(index(1),3) > 75
%                 length_bri = size(b_ri);
%                 for k = 1 : length_bri(1)
% 
% %                         if b_ri(index(k),1)>0 && b_ri(index(k),2)>0 && b_ri(index(k),3)<150
%                         if b_ri(index(k),3)<200
%                             bb_ri(k,1:3)=b_ri(index(k),1:3);
%                             length_bbri = size(bb_ri);                            
%                             if length_bbri(1) >= 5
%                                 break
%                             end 
%                         end
%              
%                 end
%                 
%                 length_bbri =  isempty(bb_ri);                
%                 if length_bbri == 1
%                     a_next=zhixian(fri_theta);
%                     break      
%                 else
%                     length_bbri = size(bb_ri);
%                 end
%                                 
%                 if length_bbri(1)<1
%                     a_next = zhixian(fri_theta);
%                     break
%                 else                   
%                     for m = 1 : length_bbri(1)
%                         en_theta(m)=acos(bb_ri(m,1)/norm(bb_ri(m,1:2)));
%                         en_thetamin(m)=abs(en_theta(m) - fri_theta);
%                         
%                     end
%                     
%                     for i = 1 :size(bb_ri)
%                         choose_value(i)=bb_ri(i,3)/circle*dis_zhanbi+en_thetamin(i)/(2*pi)*(1-dis_zhanbi);
%                     end
%                     
%                     [choose_value,index_cv]=sort(choose_value);                    
%                     
% %                     [b_theta,index1]=sort(en_thetamin);
% 
%                     en_theta = en_theta(index_cv(1));
% 
%                     en_dis = bb_ri(index_cv(1),3);
%                 end
%             else
%                 bb_ri(1,1:2)=b_ri(index(1),1:2);
%                 
%                 en_theta=acos(b_ri(index(1),1)/b_ri(index(1),3));%0~180
%                 if b_ri(index(1),2)<0
%                     en_theta=2*pi-en_theta;%-180~180
%                 end        
%                 en_dis=b_ri(index(1),3); 
%             end
            
                

            %%    
        %     network.X.Xu_input=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/210];
            network.X.X_input=[cos(fri_theta),sin(fri_theta),cos(en_theta),sin(en_theta),fri_dis/(fri_dis+en_dis),en_dis/(fri_dis+en_dis)];
            %%
        for i = 1:network.Y.y_100_u_neuron_num
            network.Y.y_100_u.response(i)=(network.X.X_input/norm(network.X.X_input))*...
                (network.Y.y_100_u_neuron(i).X_Y_100_u_weight/norm(network.Y.y_100_u_neuron(i).X_Y_100_u_weight));
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
                (network.Y.y_011_u_neuron(i).Y_100_u_Y_011_u_weight/norm(network.Y.y_011_u_neuron(i).Y_100_u_Y_011_u_weight));
                
        end
    
        [top_k_y_011_u,winner_num_y_011_u]=sort(network.Y.y_011_u.response,'descend');
        network.Y.y_011_u.response=zeros(y_011_num,1);
        network.Y.y_011_u.response(winner_num_y_011_u(1))=1;
%         
        if en_dis<=65
            for i=1:network.Y.y_100_p_neuron_num
            %计算自底向上的响应
                network.Y.y_100_p.response(i)=(network.X.X_input/norm(network.X.X_input))*...
                    (network.Y.y_100_p_neuron(i).X_Y_100_p_weight/norm(network.Y.y_100_p_neuron(i).X_Y_100_p_weight));
            end
        
            [top_k_y_100_p,winner_num_y_100_p]=sort(network.Y.y_100_p.response,'descend');
            network.Y.y_100_p.response=zeros(y_100_num,1);
            for i=1:6
                network.Y.y_100_p.response(winner_num_y_100_p(i))=1;
            end
        
%     %y_011_p           
            for i=1:network.Y.y_011_p_neuron_num
                network.Y.y_011_p.response(i)=network.Y.y_100_p.response'*...
                    (network.Y.y_011_p_neuron(i).Y_100_p_Y_011_p_weight/norm(network.Y.y_011_p_neuron(i).Y_100_p_Y_011_p_weight));
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
                    (network.Y.y_100_s_neuron(i).X_Y_100_s_weight/norm(network.Y.y_100_s_neuron(i).X_Y_100_s_weight));
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
                    (network.Y.y_011_s_neuron(i).Y_100_s_Y_011_s_weight/norm(network.Y.y_011_s_neuron(i).Y_100_s_Y_011_s_weight));
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
                network.Z.z_u.response(i)=(network.Y.y_011_u.response'*network.Z.z_u_neuron(i).Y_011_u_Z_weight);
                network.Z.z_p.response(i)=(network.Y.y_011_p.response'*network.Z.z_p_neuron(i).Y_011_p_Z_weight);
                network.Z.z_s.response(i)=(network.Y.y_011_s.response'*network.Z.z_s_neuron(i).Y_011_s_Z_weight);

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
        %     a_next = 10*(a_next-1);
        else
            a_next = zhixian(fri_theta);
        end
            break
        end
   


