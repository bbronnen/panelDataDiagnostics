// |====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|
// purchases.do 
// bugs -> bart.bronnenberg@tilburguniversity.edu
//
// produces the following files to output 
// 
// 
// |====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|

clear all

global locationRaw ../../raw

// determines run order of programs in this do-file.
program main
	preAmbule
	local countries "DE NL"
	foreach country of local countries{

	}
end

// intitialize
program preAmbule
	cap log close
	set linesize 250
	version 17
	set more off, permanently
	set seed 12345678
	set sortseed 12345678
	set scheme s2mono
	set type double, permanently 
	adopath + ../../lib/ado 
end 


program check_barcode
	args country
	
	local begin = 2012
	local end = 2024
	if "`country'" == "DE" {
		local fn = "purchase"
	}
	if "`country'" == "NL" {
		local fn = "purchase_promo"
	}
	
	forvalues yyyy = `begin'/`end' {
		local country = "NL"
		display "`country' in year `yyyy'"
		import delim using "$locationRaw/`country'/Barcode_`country'_`yyyy'.csv", rowrange(1:1) clear
		ds 
		local vars `r(varlist)'
		list `vars'
		clear
		set obs `: word count `vars''
		gen variable = ""
		local i = 1
		foreach v of local vars {
			replace variable = "`v'" in `i'
			local ++i
		}
		gen year_`yyyy' = 1
    
		if `yyyy' > 2012 {
			mmerge variable using ../temp/variables_`country'.dta, type(1:1) unm(both)
			drop _m
		}
		save ../temp/variables_`country'.dta, replace
		sleep 1000
	}

end
	

program check_units_barcode
	args country
	local country = "DE"
	local begin = 2012
	local end = 2024
	if "`country'" == "DE" {
		local fn = "purchase"
	}
	if "`country'" == "NL" {
		local fn = "purchase_promo"
	}
	
	forvalues yyyy = `begin'/`end' {

		display "`country' in year `yyyy'"
		import delim using "$locationRaw/`country'/Barcode_`country'_`yyyy'.csv", varn(1) clear
		keep category_name measurement_unit
		replace measurement="GR" if inlist(measurement,"GR","gram","ml","ML") 
		gen obs = 1 
		collapse (sum) obs, by(category measurement) 
		gen year = `yyyy'
		if `yyyy' > 2012 {
			append using ../temp/measurement_`country'.dta
			sort category measurement year
		}
		save ../temp/measurement_`country'.dta, replace		
	}
	use ../temp/measurement_DE.dta, replace		
	if measure 
	bys cat year: gen flag = _N>1
	gsort -flag category year	
	drop year flag obs
	duplicates drop
	
end



// variables present in each year after unifyVarNames
// DE: variable barcode barcode_description brand category_name manufacturer measurement_unit pl sub_brand
// NL: variable barcode barcode_description brand category_name manufacturer measurement_unit pl sub_brand volume_per_unit 


//	import delim using "$locationRaw/NL/purchase_promo_2012.csv", rowrange(1:1000) clear
//	import delim using "$locationRaw/NL/barcode_NL_2017.csv", rowrange(1:1000) clear
end
	
	
program unifyVarNames

	if "`country'" == "DE"  {
		cap rename barcode_ean barcode 
		cap rename barcode_ean_deascription barcode_description
	}
	if "`country'" == "NL"  {
		cap rename barcode_ean barcode 
		cap rename barcode_ean_deascription barcode_description
	}

end

program workaround_2024_NL_incomplete
	
	forvalues yyyy = 2022/2024 {
		import delim using "../../../raw/NL/legacy/`yyyy'/barcode.csv", varn(1) case(preserve) clear
		gen vintage = `yyyy'

		if `yyyy'>2022 append using ../temp/bc.dta
		save ../temp/bc.dta, replace
		}
		
	sort Barcode vintage
//	drop if missing(Category_name)
//	drop if missing(Barcode_description)
	
	bys Barcode (vintage): keep if _n==1 //keep earliest data with Category_name and Barcode_description
	tab vintage 
	drop vintage
	export delimited using  "../../../raw/NL/barcode.csv", replace
end

main

