% script for figure 4, identifying ensembles using different methods

%% parameters
rng(1000);
expt_name = {'m21_d2_vis','m37_d2'};
ee = {{'01_high','02_high'},{'vis_02_high'}};
vis_stim_seq = {[1,2],[2]};
stim_cstr = {'r','b'};
num_stim = 2;
num_rand = 100;
k = 3;
p = [0.05,0.01];
sample_step = 0.1;
qnoise = 0.7;
save_path = 'C:\Shuting\fwMatch\results\stats\';
all_fig_path = 'C:\Shuting\fwMatch\results\fig\stats\';

%% ensemble predictions
num_ee = sum(cellfun('length',ee).*length(expt_name));
sample_seq = -0.9:sample_step:0.9;
[~,indx] = min(abs(sample_seq));
sample_seq(indx) = 0;
rand_seq = 0.1:sample_step:1;

% initialize
core_plus_stats_all = cell(num_ee,length(sample_seq));
core_plus_sim_all = cell(num_ee,length(sample_seq));
core_plus_sim_stim_all= cell(num_ee,length(sample_seq));
core_plus_sim_nostim_all = cell(num_ee,length(sample_seq));
core_plus_pred_all = cell(num_ee,length(sample_seq));

ee_count = 0;

for n = 1:length(expt_name)
    
    expt_ee = ee{n};
    num_expt = length(expt_ee);
    core_path = ['C:\Shuting\fwMatch\results\' expt_name{n} '\core\']; 
    
    load(['C:\Shuting\fwMatch\data\' expt_name{n} '\' expt_name{n} '.mat']);
    num_node = size(Spikes,1);
    
    ee_stim = vis_stim_seq{n};
    
    for e = 1:num_expt
        
        % set path
        model_path = ['C:\Shuting\fwMatch\results\' expt_name{n} '\models\']; 
        cc_path = ['C:\Shuting\fwMatch\results\' expt_name{n} '\cc\']; 
        core_path = ['C:\Shuting\fwMatch\results\' expt_name{n} '\core\'];
        fig_path = ['C:\Shuting\fwMatch\results\' expt_name{n} '\fig\'];
        
        load([core_path expt_name{n} '_core_OSI_' num2str(ee_stim(e)) '.mat']);
        load(['C:\Shuting\fwMatch\data\' expt_name{n} '\Pks_Frames.mat']);
        load(['C:\Shuting\fwMatch\data\' expt_name{n} '\' expt_name{n} ...
            '_' expt_ee{e} '.mat']);
        load('C:\Shuting\fwMatch\results\wrbmap.mat');
        
        vis_stim_high = vis_stim(Pks_Frame);
        data_high = Spikes(:,Pks_Frame)';
        
        ensemble = core_osi;
        num_core = length(ensemble);
        ee_count = ee_count+1;
        
        %% ensemble plus
        noncore = setdiff(1:num_node,ensemble);
        core_plus_seq = round(num_core*sample_seq);
        
        core_plus_sim = cell(length(sample_seq),1);
        core_plus_sim_stim = cell(length(sample_seq),1);
        core_plus_sim_nostim = cell(length(sample_seq),1);
        core_plus_pred = cell(length(sample_seq),1);
        core_plus_stats = cell(length(sample_seq),1);
        
        for i = 1:length(sample_seq)
            for j = 1:num_rand
                
                % random sample
                if core_plus_seq(i) < 0
                    rand_core = ensemble(randperm(num_core,...
                        num_core+core_plus_seq(i)));
                    rand_core_vec = zeros(1,num_node);
                    rand_core_vec(rand_core) = 1;
                else
                    rand_core = noncore(randperm(length(noncore),...
                        min([core_plus_seq(i),length(noncore)])));
                    rand_core_vec = zeros(1,num_node);
                    rand_core_vec([ensemble',rand_core]) = 1;
                end
                
                % cosine similarity
                ts = 1-pdist2(data_high,rand_core_vec,'cosine');
                core_plus_sim{i}(j,:) = ts;
                
                % similarity with and without correct stimuli
                core_plus_sim_nostim{i}(j,:) = ts(vis_stim_high~=ee_stim(e));
                core_plus_sim_stim{i}(j,:) = ts(vis_stim_high==ee_stim(e));
                
                % prediction
                thresh = 3*std(ts(ts<=quantile(ts,qnoise)))+...
                    mean(ts(ts<=quantile(ts,qnoise)));
                core_plus_pred{i}(j,:) = ts>thresh;
                
                % accuracy
                TP = sum(core_plus_pred{i}(j,:)==1&vis_stim_high'==ee_stim(e));
                TN = sum(core_plus_pred{i}(j,:)==0&vis_stim_high'~=ee_stim(e));
                FP = sum(core_plus_pred{i}(j,:)==1&vis_stim_high'~=ee_stim(e));
                FN = sum(core_plus_pred{i}(j,:)==0&vis_stim_high'==ee_stim(e));
                ee_acc = (TP+TN)/(TP+TN+FN+FP);
                ee_prc = TP/(TP+FP);
                ee_rec = TP/(TP+FN);
                
                core_plus_stats{i}(j,:) = [ee_acc,ee_prc,ee_rec];
                
            end
        end

        core_plus_sim_all(ee_count,:) = core_plus_sim';
        core_plus_sim_stim_all(ee_count,:) = core_plus_sim_stim';
        core_plus_sim_nostim_all(ee_count,:) = core_plus_sim_nostim';
        core_plus_pred_all(ee_count,:) = core_plus_pred';
        core_plus_stats_all(ee_count,:) = core_plus_stats';

        
        %% --------- plot core prediction example ----------%
        num_frame = length(vis_stim_high);
        vis_stim_mat = vis_stim_high'.*double(vis_stim_high'==ee_stim(e));
        rr = 0.3;

        % true ensemble
        core_indx = ensemble;
        core_vec = zeros(1,num_node);
        core_vec(core_indx) = 1;
        sim_core = 1-pdist2(data_high,core_vec,'cosine');
        thresh = 3*std(sim_core(sim_core<=quantile(sim_core,qnoise)))+...
            mean(sim_core(sim_core<=quantile(sim_core,qnoise)));
        core_pred = sim_core>thresh;

        h1 = figure;
        set(h1,'color','w','position',[1982 526 289 241],'PaperPositionMode','auto');
        plotGraphHighlight(Coord_active,core_indx,'r');
        title('ensemble')
        h2 = figure;
        set(h2,'color','w','position',[2239 745 746 146],'PaperPositionMode','auto');
        imagesc(vis_stim_mat);
        colormap(cmap);caxis([0 2]);hold on;
        plot((find(core_pred)*[1,1])',(ones(sum(core_pred),1)*[1-0.2,1-0.4])',...
            'color',[0,0,0,rr]);
        plot(1:num_frame,1+0.5-sim_core*0.8,'color',0*[1,1,1]);
        plot([1,num_frame],1+0.5-0.8*thresh*[1,1],'-','color',0.7*[1,1,1]);
        ylim([0.5 1.5])
        set(gca,'xtick',[],'ytick',[])

        saveas(h1,[fig_path expt_name{n} '_' expt_ee{e} '_k_' num2str(k) ...
            '_osi_plus_example_cell.fig']);
        saveas(h1,[fig_path expt_name{n} '_' expt_ee{e} '_k_' num2str(k) ...
            '_osi_plus_example_cell.pdf']);
        saveas(h2,[fig_path expt_name{n} '_' expt_ee{e} '_k_' num2str(k) ...
            '_osi_plus_example_trace.fig']);
        saveas(h2,[fig_path expt_name{n} '_' expt_ee{e} '_k_' num2str(k) ...
            '_osi_plus_example_trace.pdf']);
        
    end

end

%% save results
% save([save_path num2str(k) '_osi_core_plus_pred_stats.mat'],'core_plus_sim_all',...
%     'core_plus_pred_all','core_plus_stats_all','core_plus_sim_stim_all',...
%     'core_plus_sim_nostim_all','-v7.3');

%% plot ensemble plus stats
figure;
set(gcf,'color','w','position',[2000,21,406,692],'PaperPositionMode','auto')
subplot(3,1,1);
for i = 1:length(sample_seq)
    hold on;
    cr_stats = cell2mat(core_plus_stats_all(:,i));
    h = boxplot(cr_stats(:,1),'positions',sample_seq(i),'width',...
        sample_step*0.5,'colors',[0 0 0]);
    set(h(7,:),'visible','off')
end
xlim([sample_seq(1)-sample_step,sample_seq(end)+sample_step])
ylim([0 1])
set(gca,'xtick',sample_seq,'xticklabel',sample_seq,'XTickLabelRotation',45)
xlabel('ensemble %');ylabel('accuracy');box off
set(findobj(gcf,'LineStyle','--'),'LineStyle','-')
set(findobj(gca,'type','line'),'linew',1)

subplot(3,1,2);
for i = 1:length(sample_seq)
    hold on;
    cr_stats = cell2mat(core_plus_stats_all(:,i));
    h = boxplot(cr_stats(:,2),'positions',sample_seq(i),'width',...
        sample_step*0.5,'colors',[0 0 0]);
    set(h(7,:),'visible','off')
end
xlim([sample_seq(1)-sample_step,sample_seq(end)+sample_step])
ylim([0 1])
set(gca,'xtick',sample_seq,'xticklabel',sample_seq,'XTickLabelRotation',45)
xlabel('ensemble %');ylabel('precision');box off
set(findobj(gcf,'LineStyle','--'),'LineStyle','-')
set(findobj(gca,'type','line'),'linew',1)

subplot(3,1,3);
for i = 1:length(sample_seq)
    hold on;
    cr_stats = cell2mat(core_plus_stats_all(:,i));
    h = boxplot(cr_stats(:,3),'positions',sample_seq(i),'width',...
        sample_step*0.5,'colors',[0 0 0]);
    set(h(7,:),'visible','off')
end
xlim([sample_seq(1)-sample_step,sample_seq(end)+sample_step])
ylim([0 1])
set(gca,'xtick',sample_seq,'xticklabel',sample_seq,'XTickLabelRotation',45)
xlabel('ensemble %');ylabel('recall');box off
set(findobj(gcf,'LineStyle','--'),'LineStyle','-')
set(findobj(gca,'type','line'),'linew',1)

saveas(gcf,[all_fig_path 'core_plus_pred_stats.fig']);
saveas(gcf,[all_fig_path 'core_plus_pred_stats.pdf']);

%% ------------ plot averaged similarity --------- %
% ensemble plus
binsz = 0.02;
figure;hold on;
set(gcf,'color','w','position',[2417,495,383,183],'PaperPositionMode','auto')
for i = 1:length(sample_seq)
    arr_to_plot1 = cell2mat(cellfun(@(x) x(:),core_plus_sim_nostim_all(:,i),...
        'uniformoutput',false));
    h = boxplot(arr_to_plot1,'positions',sample_seq(i)-binsz,...
        'width',sample_step*0.2,'colors',[0 0 0]);
    set(h(7,:),'visible','off')
    arr_to_plot2 = cell2mat(cellfun(@(x) x(:),core_plus_sim_stim_all(:,i),...
        'uniformoutput',false));
    h = boxplot(arr_to_plot2,'positions',sample_seq(i)+binsz,...
        'width',sample_step*0.2,'colors',[1 0.5 0]);
    set(h(7,:),'visible','off')
    [~,pval] = ttest2(arr_to_plot1,arr_to_plot2);
    if pval<p(2)
        scatter([sample_seq(i)-0.01,sample_seq(i)+0.01],[0.9,0.9],'k*');
    elseif pval<p(1)
        scatter(sample_seq(i)-0.01,0.9,'k*');
    end
    xlim([sample_seq(1)-sample_step,sample_seq(end)+sample_step]);
    ylim([0 1]);box off
    xlabel('ensemble %');ylabel('mean similarity')
    set(findobj(gcf,'LineStyle','--'),'LineStyle','-')
    set(findobj(gca,'type','line'),'linew',1)
    set(gca,'xtick',sample_seq,'xticklabel',sample_seq,'XTickLabelRotation',45)
end

saveas(gcf,[all_fig_path 'osi_core_plus_avg_sim.fig']);
saveas(gcf,[all_fig_path 'osi_core_plus_avg_sim.pdf']);