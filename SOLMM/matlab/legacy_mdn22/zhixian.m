function a_next = zhixian (fri_theta)        


for i = 1:36
            cc1(i)=  abs((i-1)*pi/18-fri_theta);
        end
        [out_max1,a_next]=sort(cc1);