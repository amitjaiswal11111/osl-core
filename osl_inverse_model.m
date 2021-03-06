function D = osl_inverse_model(D,mni_coords,S)
% OSL_INVERSE_MODEL runs MEG forward model in SPM12
%
% This function passes a limited set of parameters to SPM batch and returns
% an SPM object containing the inverse solution in an online montage.
%
% D = osl_inverse_model(D,mni_coords,S)
% 
% REQUIRED INPUTS:
%
% D             - SPM MEG object filename (or SPM MEG object)
%
% mni_coords    - [N x 3] list of MNI coordinates to beamform to
%
% 
% OPTIONAL INPUTS: 
%
% Passed in as a struct:
%
% S.modalities     - Sensor modalities to use (e.g. MEG,MEGPLANAR, or both) 
%                    (default MEGPLANAR for Neuromag, MEG for CTF)
% 
% S.fuse           - fuse modalities or not
%                     (default 'no')
%
% S.type           - Beamformer type to use {'Scalar' or 'Vector'}
%                     (default 'Scalar')
%
% S.timespan       - Time range to use in seconds [start end]
%                     (default [0 Inf])
%
% S.pca_order      - PCA dimensionality to use for covariance matrix inversion
%                     (default to full rank)
%
% S.use_class_channel     
%                  - flag indicating whether or not to use the class channel
%                    in S.D to determine the time samples to be used for
%                     (default is 0)
%
% S.inverse_method - inverse method to use
%                     (default is to use 'beamform')
%
% S.conditions     - conditions to use
%                     (default is to use all)
%
% S.dirname        - dir to output results to
%                     (default is a temporary directory created within D.path)
%
% S.prefix         - write new SPM file by prepending this prefix
%                     (default is '')
%
% AB 2014, MWW 2014


%%%%%%%%%%%%%%%%%%%%%%%   P A R S E   I N P U T S   %%%%%%%%%%%%%%%%%%%%%%%
if nargin == 1
    error('For clarity, new function syntax makes requires inputs positional. See function definition at top of file - changes required should be trivial');
end

old_dir = pwd; % Back up the original working directory

if nargin < 3 || isempty(S) 
    S = struct;
end


% Check SPM File Specification:
try
    if ~strcmp(class(D),'meeg'),  
        D = char(D);
        [pathstr,filestr] = fileparts(D);
        D = fullfile(pathstr,[filestr '.mat']); % force .mat suffix
        D = spm_eeg_load(D);
    end
    D.check;
catch
    error('SPM file specification not recognised or incorrect');
end
D.save(); % Save the object to disk to ensure that the current online montage is used

% Check Modality Specification:
try
    S.modalities = cellstr(S.modalities);
    S.modalities = S.modalities(:);
    S = ft_checkopt(S,'modalities','cell',{{'MEG'},{'MEGMAG'},{'MEGPLANAR'},{'MEGMAG';'MEGPLANAR'},{'MEGPLANAR';'MEGMAG'},{'EEG'}});
catch
    if any(strcmp(unique(D.chantype),'MEGPLANAR'))
        default_modality = {'MEGPLANAR'};
    else
        default_modality = {'MEG'};
    end
    warning(['Modalities specification not recognised or incorrect, assigning default: ' char(default_modality)])
    S = ft_setopt(S,'modalities',default_modality);
end

% Check Vector/Scalar Specification:
try
    S = ft_checkopt(S,'type','char',{'Scalar','Vector'});
catch 
    warning('Beamformer type not recognised or incorrect, assigning default: "Scalar"')
    S = ft_setopt(S,'type','Scalar');
end

% Check Timespan Specification:
try
    S.timespan = ft_getopt(S,'timespan',[0 Inf]); % For [] case
    S = ft_checkopt(S,'timespan',{'ascendingdoublebivector'});
catch 
    warning('Timespan specification not recognised or incorrect, using entire time window')
    S = ft_setopt(S,'timespan',[0 Inf]);
end

% Check PCA Order Specification:
try
    S = ft_checkopt(S,'pca_order',{'single','double'});
catch 
    warning('PCA order specification not recognised or incorrect, assuming full rank for now')
    S = ft_setopt(S,'pca_order',D.nchannels);
end

% Check fuse Specification:
try
    S = ft_checkopt(S,'fuse','char',{'no','all','meg'});
catch 
    warning('fuse specification not recognised or incorrect, assuming fuse=''no'' for now')
    S = ft_setopt(S,'fuse','no');
end

% Check inverse_method Specification:
try
    S = ft_checkopt(S,'inverse_method','char',{'beamform','beamform_bilateral','mne_eye','mne_diag_datacov','mne_adaptive'});
catch 
    warning('inverse_method specification not recognised or incorrect, assuming beamform for now')
    S = ft_setopt(S,'inverse_method','beamform');
end

% Check use_class_channel Specification:
try
    S = ft_checkopt(S,'use_class_channel',{'logical','doublescalar'});
catch 
    S.use_class_channel = false;
end

% Check conditions Specification:
try
    cond = setdiff(S.conditions,D.condlist);
    if ~isempty(cond),
        error(['Condition "' cond{1} '" is not a valid condition']);
    end
catch 
    warning('conditions specification not recognised or incorrect, assuming conditions=all for now')
    S.conditions = {'all'};
end

% Check dirname Specification:
try
    S = ft_checkopt(S,'dirname','char');
catch
    [~,tn] = fileparts(tempname(D.path));
    S.dirname = fullfile(D.path,sprintf('osl_bf_temp_%s',tn(3:3+7))); 
    if ~exist(S.dirname,'dir')
        mkdir(S.dirname);
    end
end

% Check prefix Specification:
try
    S = ft_checkopt(S,'prefix','char');
catch 
    S = ft_setopt(S,'prefix','');
end

%%%%%%%%%%%%%%%%%%   R U N   I N V E R S E   M O D E L   %%%%%%%%%%%%%%%%%%

clear matlabbatch

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
matlabbatch{1}.spm.tools.beamforming.data.dir                                   = {S.dirname};
matlabbatch{1}.spm.tools.beamforming.data.D                                     = {fullfile(D.path,D.fname)};
matlabbatch{1}.spm.tools.beamforming.data.val                                   = 1;
matlabbatch{1}.spm.tools.beamforming.data.gradsource                            = 'inv';
matlabbatch{1}.spm.tools.beamforming.data.space                                 = 'MNI-aligned';
matlabbatch{1}.spm.tools.beamforming.data.overwrite                             = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
matlabbatch{2}.spm.tools.beamforming.sources.BF(1)                              = cfg_dep('Prepare data: BF.mat file', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','BF'));
matlabbatch{2}.spm.tools.beamforming.sources.reduce_rank                        = [2 3];
matlabbatch{2}.spm.tools.beamforming.sources.keep3d                             = 1;
matlabbatch{2}.spm.tools.beamforming.sources.visualise                          = 0;
matlabbatch{2}.spm.tools.beamforming.sources.plugin.mni_coords.pos              = mni_coords;


% MESH STUFF!
%matlabbatch{2}.spm.tools.beamforming.sources.BF(1)                              = cfg_dep('Prepare data: BF.mat file', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','BF'));
%matlabbatch{2}.spm.tools.beamforming.sources.reduce_rank                        = [2 3];
%matlabbatch{2}.spm.tools.beamforming.sources.keep3d                             = 1;
%matlabbatch{2}.spm.tools.beamforming.sources.visualise                          = 0;
%matlabbatch{2}.spm.tools.beamforming.sources.plugin.mesh.orient                 = 'Original';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
matlabbatch{3}.spm.tools.beamforming.features.BF(1)                             = cfg_dep('Define sources: BF.mat file', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','BF'));

if strcmp(S.conditions{1},'all')
    matlabbatch{3}.spm.tools.beamforming.features.whatconditions.all            = 1;
else
    matlabbatch{3}.spm.tools.beamforming.features.whatconditions.condlabel      = S.conditions;
end

if ~S.use_class_channel
    if D.ntrials == 1
        matlabbatch{3}.spm.tools.beamforming.features.plugin.contcov            = struct([]);
        matlabbatch{3}.spm.tools.beamforming.features.woi                       = S.timespan;
    else
        matlabbatch{3}.spm.tools.beamforming.features.plugin.cov                = struct([]);
        matlabbatch{3}.spm.tools.beamforming.features.woi                       = S.timespan;
    end
else
    matlabbatch{3}.spm.tools.beamforming.features.plugin.cov_bysamples          = struct([]);
    matlabbatch{3}.spm.tools.beamforming.features.woi                           = S.timespan;
end

for jj=1:length(S.modalities),
    matlabbatch{3}.spm.tools.beamforming.features.modality{jj}                  = S.modalities{jj};
end

matlabbatch{3}.spm.tools.beamforming.features.fuse                              = S.fuse;
matlabbatch{3}.spm.tools.beamforming.features.regularisation.manual.lambda      = 0;
matlabbatch{3}.spm.tools.beamforming.features.bootstrap                         = false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

matlabbatch{4}.spm.tools.beamforming.inverse.BF(1)                              = cfg_dep('Define sources: BF.mat file', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','BF'));

switch S.inverse_method,
    case 'beamform'
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.lcmv_multicov.pca_order     = S.pca_order;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.lcmv_multicov.type          = S.type;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.lcmv_multicov.bilateral     = 0;
    case 'beamform_bilateral'
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.lcmv_multicov.pca_order     = S.pca_order;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.lcmv_multicov.type          = S.type;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.lcmv_multicov.bilateral     = 1;
    case 'mne_diag_datacov'
        mne_lambda=1;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_multicov.noise_cov_type = 'diag_datacov';
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_multicov.lambda         = mne_lambda;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_multicov.type           = S.type;
    case 'mne_eye'
        mne_lambda=1;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_multicov.noise_cov_type = 'eye';    
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_multicov.lambda         = mne_lambda;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_multicov.type           = S.type;
    case 'mne_adaptive'
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_adaptive.Noise          = S.MNE.Noise;
        matlabbatch{4}.spm.tools.beamforming.inverse.plugin.mne_adaptive.Options        = S.MNE.Options;
    otherwise 
        disp('Inversion method unknown!');        
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
matlabbatch{5}.spm.tools.beamforming.output.BF(1)                               = cfg_dep('Inverse solution: BF.mat file', substruct('.','val', '{}',{4}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','BF'));
matlabbatch{5}.spm.tools.beamforming.output.plugin.montage_osl.normalise        = 'both';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
matlabbatch{6}.spm.tools.beamforming.write.BF(1)                                = cfg_dep('Output: BF.mat file', substruct('.','val', '{}',{5}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','BF'));
matlabbatch{6}.spm.tools.beamforming.write.plugin.spmeeg_osl.prefix             = S.prefix;


spm_jobman('run',matlabbatch)

D = spm_eeg_load(D.fullfile); % Load the file back from disk with the new online montages
cd(old_dir); % Restore the working directory

end






