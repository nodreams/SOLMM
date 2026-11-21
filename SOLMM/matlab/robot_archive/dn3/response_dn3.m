function action_angle = response_dn3(input)
    global network
    [m,n]=size(network.Y.Y_100.W_xy);
    for i=1:n
        A(1,i)=norm(network.Y.Y_100.W_xy(:,i));
    end
    A=repmat(A,m,1);
    norm_W_xy = network.Y.Y_100.W_xy./A;
    clear A
    r_y_100 = (input/norm(input)) * norm_W_xy;
    [~,index] = max(r_y_100);
    r_ = zeros(1,length(network.Y.Y_100.age));
    r_(index) = 1;

    % y_011 response
    r_y_011 = r_ * network.Y.Y_011.W_yy;
    [~,index] = max(r_y_011);
    r_ = zeros(1,length(network.Y.Y_011.age));
    r_(index) = 1;

    % z response
    r_z = r_ * network.Z.W_yz;
    [~,action] = max(r_z);
%     if action > 18
%        action = action - 36;
%     end
%     action_angle = action*pi/18;
    action_angle = 10*(action-1);
