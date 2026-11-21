function [P,beta_a] = ACC(beta_a,a,reward,Q_pre,Q_next)

    P=zeros(1,9);
    delte = reward + 0.9*max(Q_next) - Q_pre(a);
    delte_ERR = 0;
    delte_COR = 0;
    if delte < 0
        delte_ERR = -delte;
    else
        delte_COR = delte;
    end
    beta_a = beta_a - 2.5*delte_COR + 0.25*delte_ERR;
    beta = 10/(1+exp(1-6*(1-beta_a)));
    for i = 1:9
        P(i) = exp(Q_pre(i) * beta)/sum(exp(Q_pre * beta));
    end
    
end