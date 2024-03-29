clear all;
if ~exist("conAssign")
    run C:\tomlab\startup.m
else
    disp("TomLab Initiated");
end
%%
addpath(genpath(pwd));
run gen_param.m
max_iter=1000;
param.nMC=50;

%% Initialize estimators
% This experiment mainly shows that as the
estimator_list = {'FD','FD2','AFD','AFD2','HM','EE'};
statistic_list = {'average','bias','var','time','iter'};
gamma_a_list = [0,2,5];
norm_p=[];
norm_p_modified=[];

for estimator = estimator_list
    for statistic = statistic_list
        eval([statistic{1} '_' estimator{1} '=[];']);
    end
end
%%
% for gamma_a = gamma_a_list
    gamma_a = 1;

    param.gamma.gamma_a = gamma_a;
    [F_struct,state] = DDCMixture.statetransition(param); %Generate
    
    f_1 = F_struct{1}; f_0 = F_struct{2};
    F_0 = kron([0,1;0,1],F_struct{2});
    F_1 = kron([1,0;1,0],F_struct{1});

    F   = [F_0;F_1];

    F_til = F_1 - F_0;
    
    theta_vec = [theta.VP0,theta.VP1,theta.VP2,theta.FC0,theta.FC1,theta.EC0,theta.EC1]';
    param.P     = F_struct;
    param.state = state;
    param.n_type = 1;
    param.n_action = 2;
    ev=zeros(param.n_state,param.n_action);
    pi = DDCMixture.dpidth(param) * theta_vec;
    [p1,ev] = DDCMixture.solveNFXP(ev,pi,param); 
    param.p1=p1;
    
    u_1 = pi + 0.5772156649015328606065120900824 - log(p1);
    u_0 = 0.5772156649015328606065120900824 - log(1-p1);
    u_til = u_1 - u_0;
    u_e = diag(p1) * u_1 + u_0;
    F_e = diag(p1) * F_til + F_0;
    B_k = [eye(32);-f_0' * inv(f_1')]; M_k = inv(B_k' * B_k) * B_k';
    
    disp("TEST1: The condition is sufficiently close to 0");
    disp(sum(sum(abs(F_til * M_k' - [f_1;f_1]))));
    N_f_til = F_til * M_k'; N_f_0 = F_0 * M_k';
    V_til = -(1/param.beta)* inv(N_f_til'*N_f_til)* N_f_til' * u_til ;
    disp("TEST2: V_til - ev(:,1) + (f_1\f_0 ) * ev(:,2)");
    disp(sum(abs(V_til - ev(:,1) + (f_1\f_0 ) * ev(:,2))));
    disp("Moment Condition 1: u_til + \beta N_f_til * V_til = 0");
    disp(sum(abs(u_til + param.beta * N_f_til * V_til)));
    
    V_til - ev(:,1) + f_1\f_0 * ev(:,2);
    ev(:,1) - f_1\f_0 * ev(:,2) + f_1\(u_til(1:32))/param.beta;
    ev(:,1) - ev(:,2) - u_0(1:32) + u_0(33:64) ;
    (V_til  - u_0(1:32) + u_0(33:64) + ( f_1\f_0 - eye(32) ) * ev(:,2))
    
    disp("Moment Condition 2: V_til_t = B_k' * [u_0 + beta F_0 M_k' V_til_t+1 ]");
    disp(sum(abs(V_til - B_k' * (u_0 + param.beta * F_0 * M_k' * V_til))));
    
    disp(sum(abs(V_til - B_k' * (u_0 + param.beta * F_0 * M_k'  * V_til))));
    
    
    V_til_1 = B_k' * (u_0 + param.beta * F_0 * inv(eye(32)-f_1\f_0)) * (V_til + (1/param.beta)*(u_til(1:32) - u_til(33:64))  );
    disp("Moment Condition 3: u_til + beta F_til M_k' V_til_t+1");
    disp(sum(abs(u_til + param.beta * F_til * M_k' * V_til_1)));
    
    disp("Combied Moment Condition: ")
    u_til + param.beta * F_til * M_k' * B_k' * (u_0 + param.beta * F_0 *M_k' * -(1/param.beta)* inv(N_f_til'*N_f_til)* N_f_til' * u_til) ; 
    %% Simulate
    ts = tic; 
    for i = 1: param.nMC
        [datasim.at,datasim.yt,datasim.zt] = ...
            DDCMixture.simdata(theta_vec,param,param.nT,param.nM);
        Data{i} = datasim;
    end
    
    TimeSimulation = toc(ts);
    fprintf('Simulation %d observations of mixture data used %f seconds \n', param.nMC ,TimeSimulation);

    theta_vec0 = zeros(7,1);

%%
    parfor i = 1:param.nMC
        
        opt = struct();
        opt.true_ccp=0;
        fprintf('Estimating sample %d out of %d\n', i, param.nMC);
        datasim = Data{i};

        ts = tic;
        opt.method = 'EE'; opt.max_iter=max_iter; %The sequential version
        [theta_hat,iter] = DDCMixture.SingleEstimation(datasim,param,theta_vec0,p_star,opt);
        TimeEstimation =  toc(ts);
        ResultTable_EE(i,:) = theta_hat;
        IterTable_EE(i) = iter;
        TimeTable_EE(i) = TimeEstimation;

        ts = tic;
        opt.method = 'HM';opt.max_iter=max_iter;
        [theta_hat,iter] = DDCMixture.SingleEstimation(datasim,param,theta_vec0,p_star,opt);
        TimeEstimation =  toc(ts);
        ResultTable_HM(i,:) = theta_hat;
        IterTable_HM(i) = iter;
        TimeTable_HM(i) = TimeEstimation;


        ts = tic;
        opt.method = 'FD';opt.max_iter=max_iter;
        [theta_hat,iter] = DDCMixture.SingleEstimation(datasim,param,theta_vec0,p_default,opt);
        TimeEstimation =  toc(ts);
        ResultTable_FD(i,:) = theta_hat;
        IterTable_FD(i) = iter;
        TimeTable_FD(i) = TimeEstimation;


        ts = tic;
        opt.method = 'FD';opt.max_iter=max_iter;
        [theta_hat,iter] = DDCMixture.SingleEstimation(datasim,param,theta_vec0,p_star,opt);
        TimeEstimation =  toc(ts);
        ResultTable_AFD(i,:) = theta_hat;
        IterTable_AFD(i) = iter;
        TimeTable_AFD(i) = TimeEstimation;


%         The two step AFD with error correctoin

        opt.method = 'FD2';
        ts = tic;opt.max_iter=max_iter;
        [theta_hat,iter] = DDCMixture.SingleEstimation(datasim,param,theta_vec0,p_star,opt);
        TimeEstimation =  toc(ts);
        ResultTable_AFD2(i,:) = theta_hat;
        IterTable_AFD2(i) = iter;
        TimeTable_AFD2(i) = TimeEstimation;

        opt.method = 'FD2';
        ts = tic;opt.max_iter=max_iter;
        [theta_hat,iter] = DDCMixture.SingleEstimation(datasim,param,theta_vec0,p_default,opt);
        TimeEstimation =  toc(ts);
        ResultTable_FD2(i,:) = theta_hat;
        IterTable_FD2(i) = iter;
        TimeTable_FD2(i) = TimeEstimation;

    end
    % Put into summary
    for estimator = estimator_list
        eval(['average_' estimator{1} '=[average_' estimator{1}  ' transpose(mean(abs(ResultTable_' estimator{1} ' - transpose(theta_vec))))]; ']);
        eval(['bias_' estimator{1} '=[bias_' estimator{1}  ' transpose(abs(mean(ResultTable_' estimator{1} ' - transpose(theta_vec))))]; ']);
        eval(['var_' estimator{1} '=[var_' estimator{1}  ' transpose(var(ResultTable_' estimator{1} ' - transpose(theta_vec)))]; ']);
        eval(['time_' estimator{1} '=[time_' estimator{1}  ' transpose(TimeTable_' estimator{1} ')]; ']);
        eval(['iter_' estimator{1} '=[iter_' estimator{1}  ' transpose(IterTable_' estimator{1} ')]; ']);
    end

%% Diary Session
diarystr = sprintf('diary/Table_sequential_gammaa_%d_M%d_T%d.txt',param.nGrid,param.nM,param.nT);
delete(diarystr);
diary(diarystr);
disp(['This experiment uses 2 step estimator with different values of'...
    '$\gamma_a$. The size of the sample is N=100, T=120 with 500 Monte Carlo'...
    'Simulations.']);

input.data = [norm_p;norm_p_modified];
input.tableRowLabels = {'norm before modified', 'norm after modified'};
input.tableColLabels = num2cell(gamma_a_list);
input.tableCaption = 'The norm of the differences in transition densities';
latexTable(input);


% Bias and Variance Table
input.tableRowLabels = param_cell;
input.tableColLabels = num2cell(gamma_a_list);


for estimator = estimator_list
    eval(['input.data  = bias_' estimator{1} ';']);
    eval(['input.variance= var_' estimator{1} ';']);
    input.tableCaption = ['The bias and variance of ' estimator{1} ' estimator'];
    input.tableLabel=['sequential' estimator{1}];
    latexVarianceTable(input);
end


command_str_time = '[';command_str_iter = '[';
for estimator = estimator_list
    command_str_time = [command_str_time '; mean(time_',estimator{1},') '];
    command_str_iter = [command_str_iter '; mean(iter_',estimator{1},') '];
end
command_str_time = [command_str_time ']'];command_str_iter = [command_str_iter ']'];

input.data = eval(command_str_time);
input.variance = eval(command_str_iter);
input.tableColLabels = num2cell(gamma_a_list);
input.tableRowLabels = estimator_list;
input.tableCaption = 'The averaged time used';
latexVarianceTable(input);
diary off;
