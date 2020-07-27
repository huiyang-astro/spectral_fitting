;+
; NAME:
;   read_spec
;
; AUTHOR:
;   He-Yang Liu
;   My Github homepage:
;       https://github.com/AstroHeyang
;
; PURPOSE:
;   Read the spectrum and then return wave and flux after correction (both deredden and redshift) 
;
; CALLING SEQUENCE:
;   spec = spec_fit(spec_file, z, ra, dec)
;
; DESCRIPTION:
;   The power-law model is used to represent the AGN continuum.
;
; INPUT:
;   spec_file - ISIS spectrum
;
;
; KEYWORD PARAMETERS:
;   NULL
;
; OUTPUT:
;	struct, {wave, flux, flux_error, z, ra, dec} 
;-

function powerlaw, x, p
    if n_elements(p) lt 2 then begin
        print, "powlaw: n_elements(p) lt 2. ERROR!"
            return, !VALUES.F_NAN
    endif

    wave = exp(x)
    y = p[0] * (wave/5000.d)^p[1]

    return,y
end

PRO plot_result, linefit_file, index_fit=index_fit, hb_func=hb_func, sdss=sdss, filename=filename

	entry_device = !d.name
    set_plot,'PS'
	out_dir = './results/'
	device,filename = out_dir+filename,/color
	!P.Multi = [0,2,1,0,0]
	p1 = [0.1,0.3,0.97,0.98]
	p2 = [0.1,0.1,0.97,0.30]

	if not keyword_set(linefit_file) then begin
        linefit_file = 'line_J2118.fits'
    endif
	if not keyword_set(hb_func) then begin
		hb_func = '2g'
	endif

	spec = mrdfits(linefit_file,1)
	wave = spec.wave
	flux = spec.flux
	error = spec.error
	model_x = spec.model_x
	model_y = spec.model_y
	
	x_title = '!17'+'Rest Frame Wavelength '+textoidl('\lambda(\AA)')+'!17'
	x_range = [4750,5050]
	x_index = where(wave gt x_range[0] and wave lt x_range[1])
	y_range = [-1, 1.1*max(flux[x_index])]
	image_title = textoidl('J2118-Hbeta-' + hb_func) 

	plot, wave, flux, xr=x_range, yr=y_range, xs=1, ys=1,  title=image_title,$
		color=fsc_color('black'), xthick=2.0, ythick=2.0, charthick=1.8, $
		charsize=1.5, position=p1, xtickformat='(A1)'
	oplot, model_x, model_y, color=fsc_color('red'), thick=2.5

	pl = powerlaw(alog(wave), [spec.pl[0], spec.pl[2]])

	hb4861n = gauss1(alog(wave), [	spec.hb4861_n[0], $
									spec.hb4861_n[2], $
									spec.hb4861_n[4]])

	if hb_func eq '1g1l' then begin
		hb4861b1 = lorentz1(alog(wave), [	spec.hb4861_b[0], $
											spec.hb4861_b[2], $
											spec.hb4861_b[4]])
	endif else begin
		hb4861b1 = gauss1(alog(wave), [	spec.hb4861_b[0], $
										spec.hb4861_b[2], $
										spec.hb4861_b[4]])
	endelse

	oplot, wave, hb4861n + pl, color=fsc_color('green'), linestyle=1, thick=3.0
	oplot, wave, hb4861b1 + pl, color=fsc_color('blue'), linestyle=1, thick=3.0

	;TODO: calculate the 2-gauss case for [OIII]
	if spec.hb4861_b[10] gt 0 then begin
		hb4861b2 = gauss1(alog(wave), [	spec.hb4861_b[6], $
										spec.hb4861_b[8], $
										spec.hb4861_b[10]])
		oplot, wave, hb4861b2 + pl, color=fsc_color('blue'), linestyle=1, thick=2.0
		oplot, wave, hb4861b1 + hb4861b2 + pl, color=fsc_color('blue'), linestyle=0, thick=2.0

		wave_fwhm = wave[0] + dindgen(800000)/100.0
		hb4861b   = gauss1(alog(wave_fwhm),[spec.hb4861_b[0],$
											spec.hb4861_b[2],$
											spec.hb4861_b[4]]) $
				  + gauss1(alog(wave_fwhm),[spec.hb4861_b[6],$
											spec.hb4861_b[8]/3d5,$
											spec.hb4861_b[10]])

		index_hb4861b = where(hb4861b ge 0.5*max(hb4861b))
        fwhm_bhb = ( max( wave_fwhm(index_hb4861b)  ) - min( wave_fwhm(index_hb4861b) ) )*3d5/4862.68
	endif else begin
		fwhm_bhb = 2.354*spec.hb4861_b[2]*3d5
	endelse

	; variable quantities
	if keyword_set(sdss) then begin
		spec_type = 'SDSS'
	endif else begin
		spec_type = 'ISIS medium aperture'
	endelse

	if hb_func eq '2g' then begin
		hb_model = 'NL1G+BL1G'
	endif else if hb_func eq '1g1l' then begin
		hb_model = 'NL1G+BL1L'
	endif else begin 
		hb_model = 'NL1G+BL2G'
	endelse

	if not keyword_set(index_fit) then begin
		index_fit = [4750, 5050]
	endif
	fitting_region = textoidl(strtrim(string(index_fit[0]), 2) + '-' + strtrim(string(index_fit[1]), 2) + ' \AA')

	fwhm_nhb = 2.354*spec.hb4861_n[2]*3d5
	xpo = 0.2 & ypo = 0.85
	xyouts_size = 1.0
	xyouts, xpo, ypo+0.05, textoidl('Spectrum: ')+spec_type, color=fsc_color('black'),charsize=xyouts_size, /normal
	xyouts, xpo, ypo, textoidl('H\beta model: ')+hb_model, color=fsc_color('black'),charsize=xyouts_size, /normal
	xyouts, xpo, ypo-0.05, 'Reduced Chisq: '+string(spec.reduced_chisq, format='(F4.2)'), charsize=xyouts_size, /normal 
	xyouts, xpo, ypo-0.1, 'Fitting Region: '+fitting_region, charsize=xyouts_size, /normal 
    xyouts, xpo, ypo-0.15,textoidl('FWHM(H\beta_N): '+string(fwhm_nhb,format='(I4)') + ' km/s'), $ 
		charsize=xyouts_size ,/normal
    xyouts, xpo, ypo-0.2,textoidl('FWHM(H\beta_B): '+string(fwhm_bhb,format='(I4)') + ' km/s'), $ 
		charsize=xyouts_size ,/normal

	y_title = textoidl('\Delta \chi^2')
	yrange = [-2, 34]
	plot, spec.model_x, spec.chisq, color=fsc_color('black'), linestyle=1, thick=2.0,$
		xtitle=x_title, ytitle=y_title,xr=x_range,xs=1,xthick=2.0, ythick=2.0,position=p2,$
		yrange=yrange, ys=1, charthick=1.8
	oplot, spec.model_x, spec.model_x*0., linestyle=2, thick=3.0

	device,/close_file
    set_plot,entry_device
END
