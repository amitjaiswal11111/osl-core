function opt = osl_check_opt(optin)

% opt = osl_check_opt(opt)
%
% Checks an OPT (OSL's Preprocessing Tool) struct has all the appropriate
% settings, which can then be passed to osl_run_opt to do an OPT
% analysis. Throws an error if any required inputs are missing, fills other
% settings with default values.
%
% Required inputs:
%
% opt.raw_fif_files: A list of the existing raw fif files for subjects (need these if
% want to do SSS Maxfiltering)
% e.g.:
% raw_fif_files{1}=[testdir '/fifs/sub1_face'];
% raw_fif_files{2}=[testdir '/fifs/sub2_face'];
% etc...
%
% OR:
%
% opt.input_files: A list of the base input (e.g. fif) files for input into the SPM
% convert call
% e.g.:
% input_files{1}=[testdir '/fifs/sub1_face_sss'];
% input_files{2}=[testdir '/fifs/sub2_face_sss'];
% etc...
%
% OR:
%
% opt.spm_files: A list of the spm meeg files for input into SPM (require
% .mat extensions).
% e.g.:
% spm_files{1}=[testdir '/spm_files/sub1.mat'];
% spm_files{2}=[testdir '/spm_files/sub2.mat'];
% etc...
%
% AND:
%
% opt.datatype: Specifies the datatype, i.e. 'neuromag', 'ctf', 'eeg'
% e.g. opt.datatype='neuromag';
%
% Optional inputs:
%
% See inside this function (e.g. use "type osl_check_opt") to see the other
% optional settings, or just look at the fields in the output opt!
%
% MWW 2013

opt=[];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% required inputs

try, opt.datatype=optin.datatype; optin = rmfield(optin,'datatype'); catch, error('Need to specify opt.datatype'); end; % datatype: 'neuromag', 'ctf', 'eeg'

try, opt.raw_fif_files=optin.raw_fif_files; optin = rmfield(optin,'raw_fif_files'); catch, opt.raw_fif_files=[]; end; % Specify a list of the raw fif files for subjects
% OR:
try, opt.input_files=optin.input_files; optin = rmfield(optin,'input_files'); catch, opt.input_files=[]; end; % Specify a list of the base input (e.g. fif) files for input into the SPM
% OR:
try, opt.spm_files=optin.spm_files; optin = rmfield(optin,'spm_files'); catch, opt.spm_files=[]; end; % Specify a list of the SPM MEEG files (do this if jumping the maxfilter/convert stage

% check list of SPM MEEG filenames input
if(~isempty(opt.raw_fif_files)),
    sess=opt.raw_fif_files;
    if ~strcmp(opt.datatype,'neuromag'), error('Should only specify raw fif files if using neuromag datatype'); end;
    opt.input_file_type='raw_fif_files';
elseif(~isempty(opt.input_files)),
    sess=opt.input_files;
    opt.input_file_type='input_files';
elseif(~isempty(opt.spm_files)),
    sess=opt.spm_files;
    opt.input_file_type='spm_files';
else
    error('Either opt.raw_fif_files, or opt.input_files, or opt.spm_files need to be specified');
end;
disp(['Using opt.' opt.input_file_type ' as input']);
try, optin = rmfield(optin,'input_file_type');catch, end;

num_sessions=length(sess);

% check that full directory names have been specified
for iSess = 1:num_sessions,
    sessPath = fileparts(sess{iSess});
    if isempty(sessPath) || strcmpi(sessPath(1), '.'),
        error([mfilename ':FullPathNotSpecified'], ...
              'Please specify full paths for the fif, input or spm files. \n');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% optional settings:

try, opt.sessions_to_do=optin.sessions_to_do; optin = rmfield(optin,'sessions_to_do'); catch, opt.sessions_to_do=1:num_sessions; end;

try, opt.dirname=optin.dirname; optin = rmfield(optin,'dirname'); catch, opt.dirname=[sess{1} '.opt']; end; % directory name which will be created and within which all results associated with this source recon will be stored
if(isempty(findstr(opt.dirname, '.opt')))
    opt.dirname=[opt.dirname, '.opt'];
end

try, opt.modalities=optin.modalities; optin = rmfield(optin,'modalities');
catch,
    switch opt.datatype
        case 'neuromag'
            opt.modalities={'MEGMAG';'MEGPLANAR'};
        case 'ctf'
            opt.modalities={'MEGGRAD'};
        case 'eeg'
            opt.modalities={'EEG'};
    end;
end;

% flag to indicate whether SPM files generated by opt stages other than the
% final one should be cleaned up as the pipeline progresses. A value of 0 means
% nothing will be deleted, 1 means most files will be deleted (apart from
% post-sss fif and pre/post africa files) and 2 means that everything will be
% cleaned up
try, opt.cleanup_files=optin.cleanup_files; optin = rmfield(optin,'cleanup_files'); catch, opt.cleanup_files=1; end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% convert settings

try, opt.convert.trigger_channel_mask=optin.convert.trigger_channel_mask; optin.convert = rmfield(optin.convert,'trigger_channel_mask'); catch, opt.convert.trigger_channel_mask='0000000000111111'; end;  % binary mask to use on the trigger channel
try, opt.convert.spm_files_basenames=optin.convert.spm_files_basenames; optin.convert = rmfield(optin.convert,'spm_files_basenames'); catch, for ii=1:num_sessions, opt.convert.spm_files_basenames{ii}=['spm_meg' num2str(ii)]; end; end; % basename used for SPM MEEG object files
try, opt.convert.bad_epochs=optin.convert.bad_epochs; optin.convert = rmfield(optin.convert,'bad_epochs'); catch, opt.convert.bad_epochs=cell(num_sessions,1); end; % Bad epochs to ignore once the SPM object has been created, one cell for each session, where the cell contains a (N_epochs x 2) matrix of epochs indicating the start and end time (in secs) (use -1 to indicate the start or end of the data)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% maxfilter settings
try, opt.maxfilter.remote_port=optin.maxfilter.remote_port; optin.maxfilter = rmfield(optin.maxfilter,'remote_port');
catch
    opt.maxfilter.remote_port = 0;
end

try, opt.maxfilter.do=optin.maxfilter.do; optin.maxfilter = rmfield(optin.maxfilter,'do');
catch,
    switch opt.datatype
        case 'neuromag'
            opt.maxfilter.do=1;
        otherwise
            opt.maxfilter.do=0;
    end;
end; % flag to indicate whether to do maxfilter or not (e.g. would not do it because it has been pre-run or because we are not using neuromag data)

try, opt.maxfilter.do_sss=optin.maxfilter.do_sss; optin.maxfilter = rmfield(optin.maxfilter,'do_sss'); catch, opt.maxfilter.do_sss=1; end; % flag to indicate whether actual SSS maxfiltering should be done or not
try, opt.maxfilter.do_remove_badchans_pre_sss=optin.maxfilter.do_remove_badchans_pre_sss; optin.maxfilter = rmfield(optin.maxfilter,'do_remove_badchans_pre_sss'); catch, opt.maxfilter.do_remove_badchans_pre_sss=1; end; % flag to indicate whether bad chans should be removed before running SSS
try, opt.maxfilter.max_badchans_pre_sss=optin.maxfilter.max_badchans_pre_sss; optin.maxfilter = rmfield(optin.maxfilter,'max_badchans_pre_sss'); catch, opt.maxfilter.max_badchans_pre_sss=10; end; % maximum number of bad chans to be removed before running SSS
try, opt.maxfilter.movement_compensation=optin.maxfilter.movement_compensation; optin.maxfilter = rmfield(optin.maxfilter,'movement_compensation'); catch, opt.maxfilter.movement_compensation=1; end; % flag to indicate whether move comp should be done
try, opt.maxfilter.trans_ref_file=optin.maxfilter.trans_ref_file; optin.maxfilter = rmfield(optin.maxfilter,'trans_ref_file'); catch, opt.maxfilter.trans_ref_file=[]; end; % trans reference file to pass to maxfilter call using the -trans flag
try, opt.maxfilter.temporal_extension=optin.maxfilter.temporal_extension; optin.maxfilter = rmfield(optin.maxfilter,'temporal_extension'); catch, opt.maxfilter.temporal_extension=0; end; % flag to indicate whether Maxfilter temporal extension should be done
try, opt.maxfilter.maxfilt_dir=optin.maxfilter.maxfilt_dir; optin.maxfilter = rmfield(optin.maxfilter,'maxfilt_dir'); catch, opt.maxfilter.maxfilt_dir='/neuro/bin/util'; end; % where to find MaxFilter exe. Defaults to S.maxfilt_dir = '/neuro/bin/util'.
try, opt.maxfilter.bad_epochs=optin.maxfilter.bad_epochs; optin.maxfilter = rmfield(optin.maxfilter,'bad_epochs'); catch, opt.maxfilter.bad_epochs=cell(num_sessions,1); end; % Bad epochs to ignore (by maxfilter (passed using the -skip Maxfilter option), one cell for each session, where the cell contains a (N_epochs x 2) matrix of epochs, where each row indicates the start and end time of each bad epoch (in secs)
try, opt.maxfilter.cal_file = optin.maxfilter.cal_file; optin.maxfilter = rmfield(optin.maxfilter,'cal_file'); catch, opt.maxfilter.cal_file = 0;end
try, opt.maxfilter.ctc_file = optin.maxfilter.ctc_file; optin.maxfilter = rmfield(optin.maxfilter,'ctc_file'); catch, opt.maxfilter.ctc_file = 0;end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% downsample settings

try, opt.downsample.do=optin.downsample.do; optin.downsample = rmfield(optin.downsample,'do'); catch, opt.downsample.do=1; end; % flag to do or not do downsample
try, opt.downsample.freq=optin.downsample.freq; optin.downsample = rmfield(optin.downsample,'freq'); catch, opt.downsample.freq=250; end; % downsample freq in Hz

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% highpass settings

try, opt.highpass.do=optin.highpass.do; optin.highpass = rmfield(optin.highpass,'do'); catch, opt.highpass.do=0; end; % flag to indicate if high pass filtering should be done 
try, opt.highpass.cutoff=optin.highpass.cutoff; optin.highpass = rmfield(optin.highpass,'cutoff'); catch, opt.highpass.cutoff=0.1; end; % highpass cutoff in Hz

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% mains settings

try, opt.mains.do=optin.mains.do; optin.mains = rmfield(optin.mains,'do'); catch, opt.mains.do=0; end; % flag to indicate if mains filtering should be done 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% trial and chan outlier detection settings

try, opt.bad_segments.do=optin.bad_segments.do; optin.bad_segments = rmfield(optin.bad_segments,'do'); catch, opt.bad_segments.do=1; end; % flag to indicate if bad_segment marking should be done
try, opt.bad_segments.dummy_epoch_tsize=optin.bad_segments.dummy_epoch_tsize; optin.bad_segments = rmfield(optin.bad_segments,'dummy_epoch_tsize'); catch, opt.bad_segments.dummy_epoch_tsize=2; end; % size of dummy epochs (in secs) to do outlier bad segment marking
try, opt.bad_segments.outlier_measure_fns=optin.bad_segments.outlier_measure_fns; optin.bad_segments = rmfield(optin.bad_segments,'outlier_measure_fns'); catch, opt.bad_segments.outlier_measure_fns={'std'}; end; % list of outlier metric func names to use for bad segment marking
try, opt.bad_segments.wthresh_ev=optin.bad_segments.wthresh_ev; optin.bad_segments = rmfield(optin.bad_segments,'wthresh_ev'); catch, opt.bad_segments.wthresh_ev=0.3*ones(length(opt.bad_segments.outlier_measure_fns),1); end; % list of robust GLM weights thresholds to use on EVs for bad segment marking, the LOWER the theshold the less aggressive the rejection
try, opt.bad_segments.wthresh_chan=optin.bad_segments.wthresh_chan; optin.bad_segments = rmfield(optin.bad_segments,'wthresh_chan'); catch, opt.bad_segments.wthresh_chan=0.01*ones(length(opt.bad_segments.outlier_measure_fns),1); end;% list of robust GLM weights thresholds to use on chans for bad segment marking, the LOWER the theshold the less aggressive the rejection

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% africa settings

try, do_africa=optin.africa.do; optin.africa = rmfield(optin.africa,'do'); catch, do_africa=1; end; % flag to do or not do africa
try, opt.africa.todo.ica=optin.africa.todo.ica; optin.africa.todo = rmfield(optin.africa.todo,'ica'); catch, opt.africa.todo.ica=do_africa; end; % flag to do or not do ica decomposition
try, opt.africa.todo.ident=optin.africa.todo.ident; optin.africa.todo = rmfield(optin.africa.todo,'ident'); catch, opt.africa.todo.ident=do_africa; end; % flag to do or not do artefact rejection
try, opt.africa.todo.remove=optin.africa.todo.remove; optin.africa.todo = rmfield(optin.africa.todo,'remove'); catch, opt.africa.todo.remove=do_africa; end; % flag to do or not do artefactual component removal
try, opt.africa.precompute_topos=optin.africa.precompute_topos; optin.africa = rmfield(optin.africa,'precompute_topos'); catch, opt.africa.precompute_topos=1; end; % flag to do or not do precomputation of topos of IC spatial maps after ica has been computed for future use in ident

try, opt.africa.used_maxfilter=optin.africa.used_maxfilter; optin.africa = rmfield(optin.africa,'used_maxfilter');
catch,
    switch opt.datatype
        case 'neuromag'
            if strcmp(opt.input_file_type,'raw_fif_files'),
                opt.africa.used_maxfilter=opt.maxfilter.do_sss;
            else
                opt.africa.used_maxfilter=1;
                warning('opt.datatype is neuromag, Will assume that data has been maxfiltered and will set opt.africa.used_maxfilter=1');
            end;
        otherwise
            opt.africa.used_maxfilter=0;
    end;
end; % flag to indicate if SSS Maxfilter has been done

% africa.ident settings (used in identifying which artefacts are bad):
opt.africa.ident=[];
try, opt.africa.ident.artefact_chans=optin.africa.ident.artefact_chans; optin.africa.ident = rmfield(optin.africa.ident,'artefact_chans'); catch, opt.africa.ident.artefact_chans={'ECG','EOG'}; end; % list of names of artefact channels
try, opt.africa.ident.artefact_chans_corr_thresh=optin.africa.ident.artefact_chans_corr_thresh; optin.africa.ident = rmfield(optin.africa.ident,'artefact_chans_corr_thresh'); catch, opt.africa.ident.artefact_chans_corr_thresh=ones(length(opt.africa.ident.artefact_chans),1)*0.15; end; % vector setting the correlation threshold to use for each of the artefact chans
try, opt.africa.ident.do_kurt=optin.africa.ident.do_kurt; optin.africa.ident = rmfield(optin.africa.ident,'do_kurt'); catch, opt.africa.ident.do_kurt=1; end; % flag to do detection of bad ICA components based on high kurtosis
try, opt.africa.ident.kurtosis_wthresh=optin.africa.ident.kurtosis_wthresh; optin.africa.ident = rmfield(optin.africa.ident,'kurtosis_wthresh'); catch, opt.africa.ident.kurtosis_wthresh=0.4; end; % threshold to use on robust GLM weights. Set to zero to not use. Set between 0 and 1, where a value closer to 1 gives more aggressive rejection
try, opt.africa.ident.kurtosis_thresh=optin.africa.ident.kurtosis_thresh; optin.africa.ident = rmfield(optin.africa.ident,'kurtosis_thresh'); catch, opt.africa.ident.kurtosis_thresh=0; end; % threshold to use on kurtosis. Set to zero to not use. Both the thresh and wthresh conditions must be met to reject 
try, opt.africa.ident.do_mains=optin.africa.ident.do_mains; optin.africa.ident = rmfield(optin.africa.ident,'do_mains'); catch, opt.africa.ident.do_mains=1; end; % flag to indicate whether or not mains component should be looked for
try, opt.africa.ident.mains_frequency=optin.africa.ident.mains_frequency; optin.africa.ident = rmfield(optin.africa.ident,'mains_frequency'); catch, opt.africa.ident.mains_frequency=50; end; % mains freq in Hz
try, opt.africa.ident.mains_kurt_thresh=optin.africa.ident.mains_kurt_thresh; optin.africa.ident = rmfield(optin.africa.ident,'mains_kurt_thresh'); catch, opt.africa.ident.mains_kurt_thresh=0.2; end; % mains kurtosis threshold (below which Mains IC must be)
try, opt.africa.ident.func=optin.africa.ident.func; optin.africa.ident = rmfield(optin.africa.ident,'func'); catch, opt.africa.ident.func=@identify_artefactual_components_auto; end; % function pointer to artefact detection algorithm
try, opt.africa.ident.max_num_artefact_comps=optin.africa.ident.max_num_artefact_comps; optin.africa.ident = rmfield(optin.africa.ident,'max_num_artefact_comps'); catch, opt.africa.ident.max_num_artefact_comps=10; end; % max number of components that will be allowed to be labelled as bad in each category

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% epoch settings

try, opt.epoch.do=optin.epoch.do; optin.epoch = rmfield(optin.epoch,'do'); catch, opt.epoch.do=1; end; % flag to indicate if epoching should be done
try, opt.epoch.time_range=optin.epoch.time_range; optin.epoch = rmfield(optin.epoch,'time_range'); catch, opt.epoch.time_range=[0.5 2]; end; % epoch time range
try, opt.epoch.timing_delay=optin.epoch.timing_delay; optin.epoch = rmfield(optin.epoch,'timing_delay'); catch, opt.epoch.timing_delay=0; end; % time delay adjustment (e.g. due to delay in visual presentations) in secs
try, opt.epoch.trialdef=optin.epoch.trialdef; optin.epoch = rmfield(optin.epoch,'trialdef'); catch, opt.epoch.trialdef=1; end;
% trialdef, e.g.:
%opt.epoch.trialdef(1).conditionlabel = 'StimLRespL';
%opt.epoch.trialdef(1).eventtype = 'STI101_down';
%opt.epoch.trialdef(1).eventvalue = 11;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% trial and chan outlier detection settings

try, opt.outliers.do=optin.outliers.do; optin.outliers = rmfield(optin.outliers,'do'); catch, opt.outliers.do=1; end; % flag to indicate if outliersing should be done
try, opt.outliers.outlier_measure_fns=optin.outliers.outlier_measure_fns; optin.outliers = rmfield(optin.outliers,'outlier_measure_fns'); catch, opt.outliers.outlier_measure_fns={'min','std'}; end; % list of outlier metric func names to use
try, opt.outliers.wthresh_ev=optin.outliers.wthresh_ev; optin.outliers = rmfield(optin.outliers,'wthresh_ev'); catch, opt.outliers.wthresh_ev=0.4*ones(length(opt.outliers.outlier_measure_fns),1); end; % list of robust GLM weights thresholds to use on EVs
try, opt.outliers.wthresh_chan=optin.outliers.wthresh_chan; optin.outliers = rmfield(optin.outliers,'wthresh_chan'); catch, opt.outliers.wthresh_chan=0.01*ones(length(opt.outliers.outlier_measure_fns),1); end;% list of robust GLM weights thresholds to use on chans

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% coreg settings

try, opt.coreg.do=optin.coreg.do; optin.coreg = rmfield(optin.coreg,'do'); catch, opt.coreg.do=1; end; % flag to do or not do downsample
try, opt.coreg.useheadshape = optin.coreg.useheadshape; optin.coreg = rmfield(optin.coreg,'useheadshape'); catch, opt.coreg.useheadshape=1; end
try, opt.coreg.mri = optin.coreg.mri; optin.coreg = rmfield(optin.coreg,'mri'); catch, for i=1:num_sessions, opt.coreg.mri{i}=''; end; end
try, opt.coreg.use_rhino = optin.coreg.use_rhino; optin.coreg = rmfield(optin.coreg,'use_rhino'); catch, opt.coreg.use_rhino = 1; end % Use RHINO coregistration
try, opt.coreg.forward_meg = optin.coreg.forward_meg; optin.coreg = rmfield(optin.coreg,'forward_meg'); catch, opt.coreg.forward_meg = 'Single Shell'; end % MEG forward model, typically either 'MEG Local Spheres' or 'Single Shell'
try, opt.coreg.fid_label = optin.coreg.fid_label; optin.coreg = rmfield(optin.coreg,'fid_label');
catch,
    switch opt.datatype
        case 'neuromag'
            opt.coreg.fid_label.nasion='Nasion'; opt.coreg.fid_label.lpa='LPA'; opt.coreg.fid_label.rpa='RPA';
        case 'ctf'
            opt.coreg.fid_label.nasion='nas'; opt.coreg.fid_label.lpa='lpa'; opt.coreg.fid_label.rpa='rpa';
        case 'eeg'
            opt.coreg.fid_label.nasion='Nasion'; opt.coreg.fid_label.lpa='LPA'; opt.coreg.fid_label.rpa='RPA';
        otherwise
            opt.coreg.fid_label=[];
    end;
end; % To see what these should be look at: D.fiducials.fid.label



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% copy any results
try, opt.results=optin.results;
    optin = rmfield(optin,'results'); catch, end;
try, opt.date=optin.date; optin = rmfield(optin,'date'); catch, end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% check people haven't set any wierd fields
if isfield(optin,'epoch'),
wierdfields = fieldnames(optin.epoch);
if ~isempty(wierdfields)
    disp('The following opt.epoch settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)
end;

if isfield(optin,'outliers'),
wierdfields = fieldnames(optin.outliers);
if ~isempty(wierdfields)
    disp('The following opt.outliers settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)
end;

if isfield(optin,'bad_segments'),
wierdfields = fieldnames(optin.bad_segments);
if ~isempty(wierdfields)
    disp('The following opt.bad_segments settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)
end;

if isfield(optin,'highpass'),
wierdfields = fieldnames(optin.highpass);
if ~isempty(wierdfields)
    disp('The following opt.highpass settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');

end % if ~isempty(wierdfields)
end;

if isfield(optin,'mains'),
wierdfields = fieldnames(optin.mains);
if ~isempty(wierdfields)
    disp('The following opt.mains settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');

end % if ~isempty(wierdfields)
end;

if isfield(optin,'downsample'),
wierdfields = fieldnames(optin.downsample);
if ~isempty(wierdfields)
    disp('The following opt.downsample settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');

end % if ~isempty(wierdfields)
end;

try, optin.coreg = rmfield(optin.coreg,'fid_label');catch, end;
if isfield(optin,'coreg'),
wierdfields = fieldnames(optin.coreg);
if ~isempty(wierdfields)
    disp('The following opt.coreg settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)
end;

if isfield(optin,'maxfilter'),
wierdfields = fieldnames(optin.maxfilter);
if ~isempty(wierdfields)
    disp('The following opt.maxfilter settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)
end;

if isfield(optin,'convert'),
wierdfields = fieldnames(optin.convert);
if ~isempty(wierdfields)
    disp('The following opt.convert settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)
end;

try, optin.africa = rmfield(optin.africa,'ident');catch, end;
try, optin.africa = rmfield(optin.africa,'todo');catch, end;
if isfield(optin,'africa'),
wierdfields = fieldnames(optin.africa);
if ~isempty(wierdfields)
    disp('The following opt.africa settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');

end % if ~isempty(wierdfields)
end;

%try, optin = rmfield(optin,'osl_version');catch, end;
try, optin = rmfield(optin,'osl2_version');catch, end;
try, optin = rmfield(optin,'epoch');catch, end;
try, optin = rmfield(optin,'outliers');catch, end;
try, optin = rmfield(optin,'bad_segments');catch, end;
try, optin = rmfield(optin,'highpass');catch, end;
try, optin = rmfield(optin,'mains');catch, end;
try, optin = rmfield(optin,'downsample');catch, end;
try, optin = rmfield(optin,'coreg');catch, end;
try, optin = rmfield(optin,'maxfilter');catch, end;
try, optin = rmfield(optin,'convert');catch, end;
try, optin = rmfield(optin,'africa');catch, end;
try, optin = rmfield(optin,'fname'); catch, end;


wierdfields = fieldnames(optin);
if ~isempty(wierdfields)
    disp('The following opt settings were not recognized by osl_check_opt');

    for iprint = 1:numel(wierdfields)
        disp([' ' wierdfields{iprint} ' '])
    end
    error('Invalid osl_check_opt settings');
end % if ~isempty(wierdfields)

%% add osl version
opt.osl2_version=osl_version;

