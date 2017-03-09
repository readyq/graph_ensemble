function [] = fig2_plot_ensemble_identification(param)
% identify ensembles by switching on and off each neuron

% parameters
expt_name = param.expt_name;
ee = param.ee;
p = param.p;
ge_type = param.ge_type;
data_path = param.data_path;
fig_path = param.fig_path.ens;
result_path_base = param.result_path_base;
ccode_path = param.ccode_path;
rwbmap = param.rwbmap;
num_expt = length(expt_name);
linew = param.linew;

load(ccode_path);
load(rwbmap);

%% initialize
cos_sim = struct();
cos_sim_avg = struct();
cos_thresh = struct();
pred = struct();
pred_stats = struct();

%%
expt_count = 0;
for n = 1:num_expt
    
    expt_ee = ee{n}{1};
    
    model_path = [result_path_base '\' expt_name{n} '\models\']; 
    
    load([data_path expt_name{n} '\' expt_name{n} '.mat']);
    load([data_path expt_name{n} '\Pks_Frames.mat']);
    best_model = load([model_path expt_name{n} '_' expt_ee ...
        '_loopy_best_model_' ge_type '.mat']);
    svd_data = load([data_path 'ensembles\' expt_name{n} '_core_svd.mat']);
    num_stim = length(unique(setdiff(vis_stim,0)));
    num_node = size(best_model.graph,1);
    num_frame = length(Pks_Frame);
    num_frame_full = size(Spikes,2);
    vis_stim_high = vis_stim(Pks_Frame);
%     data_high = Spikes(:,Pks_Frame);
    load([data_path expt_name{n} '\' expt_name{n} '_' expt_ee '.mat']);
    data_high = data';
    
    best_model.ep_on = getOnEdgePot(best_model.graph,best_model.G);
    best_model.ep_on = best_model.ep_on - tril(best_model.ep_on);
    epsum = sum(best_model.ep_on,2);
    epsum(sum(best_model.graph,2)==0) = NaN;
    
    % shuffled models
    shuffle_model = load([model_path 'shuffled_' expt_name{n} '_' ...
        expt_ee '_loopy_fulldata.mat']);
    for ii = 1:length(shuffle_model.graphs)
        shuffle_model.ep_on{ii} = getOnEdgePot(shuffle_model.graphs{ii},...
            shuffle_model.G{ii})';
        shuffle_model.epsum{ii} = sum(shuffle_model.ep_on{ii},2);
        shuffle_model.epsum{ii}(sum(shuffle_model.graphs{ii},2)==0) = NaN;
    end
    shuffle_model.mepsum = nanmean(cellfun(@(x) nanmean(x),shuffle_model.epsum));
    shuffle_model.sdepsum = nanstd(cellfun(@(x) nanmean(x),shuffle_model.epsum));
    
    
    %% find SVD ensemble
    core_svd = cell(num_stim,1);
    for ii = 1:num_stim
        for jj = 1:length(svd_data.svd_state)
            if strcmp(num2str(ii),svd_data.svd_state{jj})
                core_svd{ii} = svd_data.core_svd{jj};
                break;
            end
        end
    end
    
    %% find ensemble with CRF
    % predict each neuron in turn
    LL_frame = zeros(num_node,num_frame,2);
    for ii = 1:num_node
        for jj = 1:num_frame
            frame_vec = data_high(:,jj)';
            frame_vec(ii) = 0;
            LL_frame(ii,jj,1) = compute_avg_log_likelihood(best_model.node_pot,...
                best_model.edge_pot,best_model.logZ,frame_vec);
            frame_vec(ii) = 1;
            LL_frame(ii,jj,2) = compute_avg_log_likelihood(best_model.node_pot,...
                best_model.edge_pot,best_model.logZ,frame_vec);
        end
    end
    LL_on = squeeze(LL_frame(:,:,2)-LL_frame(:,:,1));
    
    % ------------ AUC - should work for multiple stimuli ------------ %
    auc = zeros(num_node,num_stim);
    for ii = 1:num_stim
        true_label = double(vis_stim_high==ii)';
        for jj = 1:num_node
            [~,~,~,auc(jj,ii)] = perfcurve(true_label,LL_on(jj,:),1);
        end
    end
    
    % find best threshold
%     th_vec = 0.5:0.05:0.8;
%     acc_vec = zeros(length(th_vec),num_stim);
%     for ii = 1:num_stim
%         true_label = vis_stim_high'==ii;
%         for jj = 1:length(th_vec)
%             core = find(auc(:,ii)>max(auc(:,setdiff(1:num_stim,ii)),[],2)&...
%                 auc(:,ii)>th_vec(jj));
%             if ~isempty(core)
%                 [~,~,~,~,acc] = core_cos_sim(core,data_high',true_label);
%             else
%                 acc = 0;
%             end
%             acc_vec(jj,ii) = acc;
%         end
%     end
%     th = zeros(num_stim,1);
%     for ii = 1:num_stim
%         [~,best_indx] = max(acc_vec(:,ii));
%         th(ii) = th_vec(best_indx);
%     end
%         
%     % find ensembles
%     core_crf = cell(num_stim,1);
%     for ii = 1:num_stim
%         core_crf{ii} = find(auc(:,ii)>max(auc(:,setdiff(1:num_stim,ii)),[],2)&...
%             auc(:,ii)>th(ii));
%         core_crf{ii} = setdiff(core_crf{ii},num_node-num_stim+ii);
%     end

    % ------------------- use LL and TPR/FPR ---------------- %
%     % threshold and count
%     thr = zeros(num_node,1);
%     LL_pred = nan(num_node,num_frame);
%     for ii = 1:num_node
%         [LL_pred(ii,:),thr(ii)] = pred_from_LL(LL_on(ii,:),qnoise);
%     end
%     
%     % calculate TPR and FPR
%     TPR = zeros(num_node,num_stim);
%     FPR = zeros(num_node,num_stim);
%     for ii = 1:num_stim
%         for jj = 1:num_node
%             TP = sum(LL_pred(jj,:)==1&vis_stim_high'==ii);
%             FP = sum(LL_pred(jj,:)~=1&vis_stim_high'==ii);
%             TN = sum(LL_pred(jj,:)~=1&vis_stim_high'~=ii);
%             FN = sum(LL_pred(jj,:)==1&vis_stim_high'~=ii);
%             TPR(jj,ii) = TP/(TP+FN);
%             FPR(jj,ii) = FP/(FP+TN);
%         end
%     end
%     
%     % find the best threshold for each stimulus
%     th_vec = 0.1:0.1:0.9;
%     acc_vec = zeros(length(th_vec),num_stim);
%     for ii = 1:num_stim
%         true_label = vis_stim_high'==ii;
%         for jj = 1:length(th_vec)
%             core = find(TPR(:,ii)>th_vec(jj)&FPR(:,ii)<th_vec(jj));
%             if ~isempty(core)
%                 [~,~,~,~,acc] = core_cos_sim(core,data_high',true_label);
%             else
%                 acc = 0;
%             end
%             acc_vec(jj,ii) = acc;
%         end
%     end
%     th = zeros(num_stim,1);
%     for ii = 1:num_stim
%         [~,best_indx] = max(acc_vec(:,ii));
%         th(ii) = th_vec(best_indx);
%     end
%     
%     % identify ensembles
%     core_crf = cell(num_stim,1);
%     for ii = 1:num_stim
%         core_crf{ii} = find(TPR(:,ii)>th(ii)&FPR(:,ii)<th(ii));
%     end
    
    % --------------------- node strength + AUC --------------------- %
    auc_ens = cell(num_stim,1);
    core_crf = cell(num_stim,1);
    for ii = 1:num_stim
        num_ens = sum(best_model.graph(num_node-num_stim+ii,:));
        for jj = 1:100
            rd_ens = randperm(num_node,num_ens);
            [~,sim_core] = core_cos_sim(rd_ens,data_high',...
                true_label);
            [~,~,~,auc_ens{ii}(jj)] = perfcurve(true_label,sim_core,1);
        end
        core_crf{ii} = find(auc(:,ii)>(mean(auc_ens{ii})+std(auc_ens{ii}))&...
            (epsum>(shuffle_model.mepsum+shuffle_model.sdepsum)));
        core_crf{ii} = setdiff(core_crf{ii},num_node-num_stim+ii);
    end
    
%     th_vec = 0.5:0.05:0.8;
%     th = zeros(num_stim,1);
%     core_crf = cell(num_stim,1);
%     for ii = 1:num_stim
%         
%         % find best threshold
%         acc_vec = zeros(length(th_vec),1);
%         true_label = vis_stim_high'==ii;
%         core = cell(length(th_vec),1);
%         for jj = 1:length(th_vec)
%             core{jj} = find(auc(:,ii)>th_vec(jj)&(epsum>shuffle_model.mepsum+...
%                 shuffle_model.sdepsum));
%             if ~isempty(core{jj})
%                 [~,~,~,~,acc] = core_cos_sim(core{jj},data_high',true_label);
%             else
%                 acc = 0;
%             end
%             acc_vec(jj) = acc;
%         end
%         
%         [~,indx] = max(acc_vec);
%         core_crf{ii} = setdiff(core{indx},num_node-num_stim+ii);
%         th(ii) = th_vec(indx);
%         
%     end
    
    %% plot each neuron in ROC space - AUC
%     nodesz = 15;
%     figure; set(gcf,'color','w','position',[2060 403 247 230])
%     hold on
%     plot([0 1],[0 1],'k--')
%     plot([0 th(1)],th(1)*[1 1],'k--')
%     plot(th(2)*[1 1],[0 th(2)],'k--')
%     scatter(auc(:,1),auc(:,2),nodesz,mycc.gray,'filled')
%     scatter(auc(core_crf{1},1),auc(core_crf{1},2),nodesz,mycc.red,'filled')
%     scatter(auc(core_crf{2},1),auc(core_crf{2},2),nodesz,mycc.blue,'filled')
%     xlim([0 1]); ylim([0 1])
%     xlabel('AUC 1'); ylabel('AUC 2');
%     
%     print(gcf,'-dpdf','-painters',[fig_path expt_name{n} '_core_ROCspace.pdf'])   

%     %% plot each neuron in ROC space - LL and FPR/TPR
%     nodesz = 15;
%     figure; set(gcf,'color','w','position',[1984 327 622 274])
%     subplot(1,2,1); hold on
%     plot([0 1],[0 1],'k--')
%     plot([0 th(1)],th(1)*[1 1],'k--')
%     plot(th(1)*[1 1],[th(1) 1],'k--')
%     scatter(FPR(:,1),TPR(:,1),nodesz,mycc.gray,'filled')
%     scatter(FPR(core_crf{1},1),TPR(core_crf{1},1),nodesz,mycc.red,'filled')
%     xlim([0 1]); ylim([0 1])
%     xlabel('FPR'); ylabel('TPR');
%     subplot(1,2,2); hold on
%     plot([0 1],[0 1],'k--')
%     plot([0 th(2)],th(2)*[1 1],'k--')
%     plot(th(2)*[1 1],[th(2) 1],'k--')
%     scatter(FPR(:,2),TPR(:,2),nodesz,mycc.gray,'filled')
%     scatter(FPR(core_crf{2},2),TPR(core_crf{2},2),nodesz,mycc.blue,'filled')
%     xlim([0 1]); ylim([0 1])
%     xlabel('FPR'); ylabel('TPR');
%     
%     print(gcf,'-dpdf','-painters',[fig_path expt_name{n} '_core_ROCspace.pdf'])
%     

    % --------------------- node strength + AUC --------------------- %
    nodesz = 30;
    nsmi = min(epsum);
    nsma = max(epsum);
    aucmi = 0;
    aucma = 1;
    figure; set(gcf,'color','w','position',[1967 615 555 253])
    for ii = 1:num_stim
        subplot(1,num_stim,ii); hold on
        scatter(epsum,auc(:,ii),nodesz,mycc.gray,'filled')
        scatter(epsum(core_crf{ii}),auc(core_crf{ii},ii),nodesz,mycc.red,'filled')
%         plot([nsmi nsma],th(ii)*[1 1],'k--');
        plot([nsmi nsma],mean(auc_ens{ii})*[1 1],'k--');
        plot([nsmi nsma],(mean(auc_ens{ii})+std(auc_ens{ii}))*[1 1],'--',...
            'color',mycc.gray_light);
        plot([nsmi nsma],(mean(auc_ens{ii})-std(auc_ens{ii}))*[1 1],'--',...
            'color',mycc.gray_light);
        plot(shuffle_model.mepsum*[1 1],[aucmi aucma],'k--');
        plot((shuffle_model.mepsum+shuffle_model.sdepsum)*[1 1],[aucmi aucma],'--',...
            'color',mycc.gray_light);
        plot((shuffle_model.mepsum-shuffle_model.sdepsum)*[1 1],[aucmi aucma],'--',...
            'color',mycc.gray_light);
        xlim([nsmi nsma]); ylim([aucmi aucma])
        xlabel('node strength'); ylabel(['AUC' num2str(ii)]);
    end
    print(gcf,'-dpdf','-painters',[fig_path expt_name{n} '_core_NS_AUC.pdf'])   
    
    %% plot prediction example
    % find a representative cell for stim 1
    [~,indx] = max(auc(core_crf{1},1));
    indx = core_crf{1}(indx);
    [pred,thr] = pred_from_LL(LL_on(indx,:),0.7);
    LL_cell_nor = (LL_on(indx,:)-min(LL_on(indx,:)))/(max(LL_on(indx,:))-min(LL_on(indx,:)));
    thr_cell_nor = (thr-min(LL_on(indx,:)))/(max(LL_on(indx,:))-min(LL_on(indx,:)));
    plot_pred(pred,LL_cell_nor,thr_cell_nor,vis_stim_high==1,cmap)
    set(gcf,'position',[1991 394 758 126])
    caxis([0 2])
    
    print(gcf,'-dpdf','-painters',[fig_path expt_name{n} '_' ...
        expt_ee '_stim1_representative_cell.pdf'])
    
    % find a representative cell for stim 2
    [~,indx] = max(auc(core_crf{2},2));
    indx = core_crf{2}(indx);
    [pred,thr] = pred_from_LL(LL_on(indx,:),0.7);
    LL_cell_nor = (LL_on(indx,:)-min(LL_on(indx,:)))/(max(LL_on(indx,:))-min(LL_on(indx,:)));
    thr_cell_nor = (thr-min(LL_on(indx,:)))/(max(LL_on(indx,:))-min(LL_on(indx,:)));
    plot_pred(pred,LL_cell_nor,thr_cell_nor,vis_stim_high==2,cmap)
    set(gcf,'position',[1991 394 758 126])
    caxis([0 1])
 
    print(gcf,'-dpdf','-painters',[fig_path expt_name{n} '_' ...
        expt_ee '_stim2_representative_cell.pdf'])
    
    %% plot ensemble highlight
    figure; set(gcf,'color','w','position',[2162 447 434 267])
    subplot(1,2,1)
    plotGraphHighlight(Coord_active,core_crf{1},mycc.red)
    subplot(1,2,2)
    plotGraphHighlight(Coord_active,core_crf{2},mycc.blue)
    print(gcf,'-dpdf','-painters',[fig_path expt_name{n} '_' ...
        expt_ee '_vis_core.pdf'])
    
    %% plot SVD+CRF, calc sim
    rr = 1;
    figure;
    set(gcf,'color','w','position',[2041 430 543 338]);
    set(gcf,'paperpositionmode','auto')
    for ii = 1:num_stim

        % plot
        subplot(1,num_stim,ii);
        plotCoreOverlay(Coord_active,core_crf{ii},core_svd{ii},mycc.orange,...
            mycc.green,rr)
        
        true_label = double(vis_stim_high==ii)';
        
        % make it fair
        if ~isempty(core_svd{ii})
            expt_count = expt_count+1;
            
            crf_svd = intersect(core_crf{ii},core_svd{ii});
            num_cell(expt_count) = size(Spikes,1);
            num_crf(expt_count) = length(core_crf{ii});
            num_svd(expt_count) = length(core_svd{ii});
            num_crf_svd(expt_count) = length(crf_svd);
            
            % SVD
            [pred.svd{expt_count},cos_sim.svd{expt_count},cos_thresh.svd{expt_count},...
                cos_sim_avg.svd{expt_count},acc,prc,rec] = core_cos_sim(core_svd{ii},data_high',true_label);
            pred_stats.svd(expt_count,:) = [acc,prc,rec];
            % CRF
            [pred.crf{expt_count},cos_sim.crf{expt_count},cos_thresh.crf{expt_count},...
                cos_sim_avg.crf{expt_count},acc,prc,rec] = core_cos_sim(core_crf{ii},data_high',true_label);
            pred_stats.crf(expt_count,:) = [acc,prc,rec];
        end
        
    end
    
    % check if directory exists
    if exist([result_path_base '\' expt_name{n} '\core'],'dir')~=7
        mkdir([result_path_base '\' expt_name{n} '\core\']);
    end
    save([result_path_base '\' expt_name{n} '\core\' expt_ee '_crf_svd_core.mat'],...
        'core_crf','core_svd');
    
    %% plot cos sim
%     pind = expt_count-num_stim+1:expt_count;
%     sind = [1,3,2,4]; % sort by vis stim type
%     pred_mat = reshape([cell2mat(pred.crf(pind));cell2mat(pred.svd(pind))]',[],num_stim*2)';
%     plot_pred_raster(pred_mat(sind,:),vis_stim_high,cmap)
    
%     print(gcf,'-dpdf','-painters','-bestfit',[fig_path expt_name{n} '_' ...
%         expt_ee '_mc_svd_core_pred_raster_' ge_type '.pdf'])
    
end

%% plot stats
figure;
set(gcf,'color','w','position',[2041 533 993 235]);
set(gcf,'paperpositionmode','auto')

stepsz = 0.5;
binsz = 0.1;
ww = 0.2;

% mean sim value
subplot(1,4,1); hold on
% svd model
mcs = cell2mat(cos_sim_avg.svd');
scatter((stepsz-binsz)*ones(size(mcs(:,1))),mcs(:,1),30,mycc.green_light,'+','linewidth',linew);
scatter((stepsz+binsz)*ones(size(mcs(:,2))),mcs(:,2),30,mycc.green,'+','linewidth',linew);
plot([(stepsz-binsz)*ones(size(mcs(:,1))),(stepsz+binsz)*ones(size(mcs(:,1)))]',...
    mcs','color',mycc.gray);
plot([stepsz-binsz*1.5,stepsz-binsz*0.5],nanmean(mcs(:,1))*ones(2,1),'color',...
    mycc.black,'linewidth',linew);
plot([stepsz+binsz*0.5,stepsz+binsz*1.5],nanmean(mcs(:,2))*ones(2,1),'color',...
    mycc.black,'linewidth',linew);
% crf model
mcs = cell2mat(cos_sim_avg.crf');
scatter((2*stepsz-binsz)*ones(size(mcs(:,1))),mcs(:,1),30,mycc.orange_light,'+','linewidth',linew);
scatter((2*stepsz+binsz)*ones(size(mcs(:,2))),mcs(:,2),30,mycc.orange,'+','linewidth',linew);
plot([(2*stepsz-binsz)*ones(size(mcs(:,1))),(2*stepsz+binsz)*ones(size(mcs(:,1)))]',...
    mcs','color',mycc.gray);
plot([2*stepsz-binsz*1.5,2*stepsz-binsz*0.5],mean(mcs(:,1))*ones(2,1),'color',...
    mycc.black,'linewidth',linew);
plot([2*stepsz+binsz*0.5,2*stepsz+binsz*1.5],mean(mcs(:,2))*ones(2,1),'color',...
    mycc.black,'linewidth',linew);
xlim([0.2 3*stepsz-0.2])
% ylim([0 1])
set(gca,'xtick',[1,2]*stepsz);
set(gca,'xticklabel',{'SVD','CRF'})
ylabel('Similarity')

% accuracy
subplot(1,4,2); hold on
h = boxplot(pred_stats.svd(:,1),'positions',stepsz,'width',ww,'colors',mycc.green);
setBoxStyle(h,linew)
h = boxplot(pred_stats.crf(:,1),'positions',2*stepsz,'width',ww,'colors',mycc.orange);
setBoxStyle(h,linew)
xlim([0 3*stepsz]); ylim([0 1])
set(gca,'xtick',[1,2]*stepsz);
set(gca,'xticklabel',{'SVD','CRF'})
ylabel('Accuracy')
box off

% precision
subplot(1,4,3); hold on
h = boxplot(pred_stats.svd(:,2),'positions',stepsz,'width',ww,'colors',mycc.green);
setBoxStyle(h,linew)
h = boxplot(pred_stats.crf(:,2),'positions',2*stepsz,'width',ww,'colors',mycc.orange);
setBoxStyle(h,linew)
xlim([0 3*stepsz]); ylim([0 1])
set(gca,'xtick',[1,2]*stepsz);
set(gca,'xticklabel',{'SVD','CRF'})
ylabel('Precision')
box off

% recall
subplot(1,4,4); hold on
h = boxplot(pred_stats.svd(:,3),'positions',stepsz,'width',ww,'colors',mycc.green);
setBoxStyle(h,linew)
h = boxplot(pred_stats.crf(:,3),'positions',2*stepsz,'width',ww,'colors',mycc.orange);
setBoxStyle(h,linew)
xlim([0 3*stepsz]); ylim([0 1])
set(gca,'xtick',[1,2]*stepsz);
set(gca,'xticklabel',{'SVD','CRF'})
ylabel('Recall')
box off
% 
% print(gcf,'-dpdf','-painters',[fig_path 'core_pred_stats.pdf'])


end
