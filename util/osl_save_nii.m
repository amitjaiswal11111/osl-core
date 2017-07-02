function osl_save_nii(vol,res,xform,fname)
	% Save a nii file together with a given xform matrix
	%
	% INPUTS
	% vol - volume matrix to save to nii file
	% res - Spatial resolution
	% fname - File name of nii file to save
	% xform - 4x4 matrix. 
	%
	% Could use osl_load_nii to get res and xform from a standard mask
	%
	% Romesh Abeysuriya 2017
	
	% Resolution can be specified in 3 ways
	% - Single number = same in all dimensions, with time resolution of 1
	% - 3 numbers, different in all dimensions, time resolution of 1
	% - 4 numbers, complete resolution specification
	
	switch length(res)
		case 1
			r = [res res res 1];
		case 3
			r = [res 1];
		case 4
			r = res;
		otherwise
			error('Unknown resolution - should be 1, 3, or 4 elements long');
	end

    save_avw(vol,fname,'d',r);
 
    runcmd(['fslorient -setqform ' num2str(reshape(xform',1,16)) ' ' fname])
    runcmd(['fslorient -setsform ' num2str(reshape(xform',1,16)) ' ' fname])
	runcmd(['fslorient -setsformcode 0 ' fname])
	runcmd(['fslorient -setqformcode 2 ' fname])
