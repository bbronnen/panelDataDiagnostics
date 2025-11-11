// |====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|
// underscanning.do 
// bugs -> bart.bronnenberg@tilburguniversity.edu
//
// produces the following files to output 
// 
// 
// |====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|====+====|

clear all

global locationRaw ../../raw
 // 

// determines run order of programs in this do-file.
program main
	preAmbule
	local countries " DE NL"
	foreach country of local countries{
//		loop_over_years `country'
		annual_trends `country'
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


program loop_over_years
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
		display "`country' in year `yyyy'"

		import delim using "$locationRaw/`country'/Barcode_`country'_`yyyy'.csv", varn(1) clear
		cap rename barcode_ean barcode 
		cap rename barcode_ean_description barcode_description
		
		if "`country'" == "DE" 	{
			keep if inlist(category_name, "TOILETTENPAPIER FEUCHT", "TOILETTENPAPIER TROCKEN", "VOLLWASCHMITTEL", "VORWASCH-/ EINWEICHMITTEL" ) 
		} 

		if "`country'" == "NL" {
			cap replace category_name = "vochtig toiletpapier-doek" if category_name == "vochtig toiletpapier/doekjes" 
			keep if inlist(category_name, "vochtig toiletpapier-doek", "toiletpapier", "wasmiddelen capsule", "wasmiddelen poeder", "wasmiddelen tablet", "wasmiddelen vloeibaar") 
		} 
		keep category_name barcode barcode_description measurement_unit
		drop if missing(barcode)
		bys barcode: drop if _n>1
		duplicates drop 
		save ../temp/products.dta, replace

		import delim using "$locationRaw/`country'/`fn'_`yyyy'.csv", varn(1) clear 
		gen year = `yyyy'
		
		collapse (sum) total_value total_volume total_unit, by(barcode panelist quarter)
		mmerge barcode using ../temp/products.dta, unm(using) type(n:1)

		replace measure = "GR" if measure=="ML" & "`country'"=="DE"
		replace measure = "gr" if measure=="ml" & "`country'"=="NL"
		
		collapse (sum) total_value total_volume total_unit, by(category_name panelist quarter measurement_unit)
	
		if `yyyy' > 2012 {
			append using ../temp/select_sales_`country'.dta
		}

		save ../temp/select_sales_`country'.dta, replace
		sleep 1000
	}
end

program annual_trends
	args country
	use ../temp/select_sales_`country'.dta, clear
	sort panelist category quarter
	drop if missing(panelist)|missing(quarter)
	save ../temp/select_sales_`country'.dta, replace
	import delim using "$locationRaw/`country'/panelist.csv", varn(1) clear
	drop if missing(panelist)|missing(quarter)
	if "`country'" == "NL" {
		destring household_size, force replace
	}
	keep panelist quarter household_size age 
	mmerge panelist quarter using ../temp/select_sales_`country'.dta, type(1:n) unm(none)
	if "`country'" == "NL" {
		keep if inlist(category_name, "toiletpapier", "vochtig toiletpapier-doek")
		replace category_name = "toilet paper dry (rolls)" if category_name == "toiletpapier" 
		replace category_name = "toilet paper wet (sheets)" if category_name == "vochtig toiletpapier-doek" 
	}
	if "`country'" == "DE" {
		keep if inlist(category_name, "TOILETTENPAPIER TROCKEN", "TOILETTENPAPIER FEUCHT")
		replace category_name = "toilet paper dry (rolls)" if category_name == "TOILETTENPAPIER TROCKEN" 
		replace category_name = "toilet paper wet (sheets)" if category_name == "TOILETTENPAPIER FEUCHT" 
	}
	sort panelist category quarter
	gen total_vol_pc = total_vol / household_size
	egen cat = group(category_name)
	gen year = floor(quarter/100)
	gen qq = quarter - 100*year
	bys category_name: areg total_vol_pc i.year i.qq, abs(panelist)
	
	collapse (mean) total_volume household_size, by(year category_name measure)  
	gen vol_pc = total_volume/household_size
	sort cat year
	twoway connected vol_pc year, by(category_name, yrescale)
	graph export "../output/BWI_`country'.png", replace
	
end



main