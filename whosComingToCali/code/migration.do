set trace on
set tracedepth 2
set more off
timer clear
clear
set matsize 1600
set seed 123

sysuse auto


/*===========================================================================================*/
/*                                     Main Program                                          */
/*===========================================================================================*/
/*
	Comment out programs that don't need to be run. 
*/

capture program drop main
program define main
    paths, computer("School") 
	clean_county_income
	readin_migration_flows
	
end


/*===========================================================================================*/
/*                                     Sub Programs                                      */
/*===========================================================================================*/


/*---------------------------------------------------------*/
/* Define Path Macros 					                   */
/*---------------------------------------------------------*/
capture program drop paths
program define paths
syntax [, computer(string)]

	*CHANGE THESE PATHS BELOW TO YOUR COMPUTER DIRECTORIES
	
	*School desktop
	if "`computer'" == "School"{
		global dataRAW "C:/Users/carli/Dropbox/projects/baecon101/whosComingToCali/dataRAW/"
		global dataCLEAN "C:/Users/carli/Dropbox/projects/baecon101/whosComingToCali/dataCLEAN/"
		global output "C:/Users/carli/Dropbox/projects/baecon101/whosComingToCali/output/" 
		global code "C:/Users/carli/Dropbox/projects/baecon101/whosComingToCali/code/"
	}
	
	
	if "`computer'" == "Home"{
	
		global dataRAW "C:/Users/Daniel and Carla/Dropbox/projects/baecon101/whosComingToCali/dataRAW/"
		global dataCLEAN "C:/Users/Daniel and Carla/Dropbox/projects/baecon101/whosComingToCali/dataCLEAN/"
		global output "C:/Users/carli/Daniel and Carla/projects/baecon101/whosComingToCali/output/" 
		global code "C:/Users/carli/Daniel and Carla/projects/baecon101/whosComingToCali/code/"
			
	}
	
	
end	


/*---------------------------------------------------------*/
/* county income data						      */
/*---------------------------------------------------------*/
capture program drop clean_county_income
program define clean_county_income
	/*
		Imports median household income in each county for the years 2000 and 2010
		Drops unneccesary variables, renames variables of interest, classifies
		each county has low-income, middle-income, and high-income in 2000 and 2010. 
	*/
	
	//Importing 2000 Median County Household Income
	import delimited "$dataRAW/nhgisMedianCountyIncome/nhgis0020_ds151_2000_county.csv", clear
	rename gmy001 medInc 
	keep medInc county countya statea
	
	//Labeling counties low-income, middle-income, and high-income
	xtile quantile3 = medInc, nquantiles(3)
	xtile quantile10 =  medInc, nquantiles(10)
	save "$dataRAW/nhgisMedianCountyIncome/nhgisMedIncClean2000.dta", replace
	
	//Importing 2010 Median County Income
	import delimited "$dataRAW/nhgisMedianCountyIncome/nhgis0020_ds176_20105_2010_county.csv", clear
	rename joie001 medInc
	keep medInc county countya statea
	
	//Labeling counties low-income, middle-income, and high-income
	xtile quantile3 = medInc, nquantiles(3)
	xtile quantile10 =  medInc, nquantiles(10)
	save "$dataRAW/nhgisMedianCountyIncome/nhgisMedIncClean2010.dta", replace
	
	
end
/*---------------------------------------------------------*/
/* migration data */
/*---------------------------------------------------------*/
capture program drop readin_migration_flows
program define readin_migration_flows
	
	/*Cleans county-to-county inflow migration files for the state of California 
	for the years 2005 and 2015
	
	Merges clean migration data with median county income data created by 
	clean_county_income
	
	Saves merged files for 2005 and 2015. 
	*/	
	
	*Migration for 2005-06
	local years 0506
	foreach y in `years'{
		insheet using "$dataRAW/irsMigrationFlows/in`y'/co`y'CAi.txt", clear  
		rename v1 state_to
		rename v2 county_to
		rename v3 state_from
		rename v4 county_from
		rename v7 number_returns
		rename v8 number_exemptions
		drop if v5=="XX"
		keep state_to county_to state_from county_from number_returns number_exemptions
		drop if state_from > 56 //Dropping everything except county to county flows		
		local t: type number_returns
		if regexm("`t'","str"){
		replace number_returns=regexr(number_returns, ",","")
		replace number_returns=regexr(number_returns, ",","")
		replace number_returns=regexr(number_returns, ",","")
		replace number_returns=regexr(number_returns, ",","")
		replace number_returns=regexr(number_returns, ",","")
		replace number_returns=regexr(number_returns, ",","")
		}
		local t: type number_exemptions
		if regexm("`t'","str"){		
		replace number_exemptions=regexr(number_exemptions, ",","")
		replace number_exemptions=regexr(number_exemptions, ",","")
		replace number_exemptions=regexr(number_exemptions, ",","")
		replace number_exemptions=regexr(number_exemptions, ",","")
		replace number_exemptions=regexr(number_exemptions, ",","")
		replace number_exemptions=regexr(number_exemptions, ",","")	
		}
		destring number_returns, replace force
		destring number_exemptions, replace force	
		if substr("`y'", 3, 1) == "0"{
			gen year="20" + substr("`y'", 3, 2) 
			}
		else{
			gen year = "19" + substr("`y'", 3, 2)
			}
				
		//Cleaning up variables
		destring year, replace
		rename number_exemptions migration_in
	
		//Merging with Census 2000 county income data (I've verfied both sets are using fips)
		*Coding Broomfiled county, CO (created 2001) as Boulder County
		replace county_from = 13 if county_from == 14 & state_from == 8
		tempfile migration 
		save `migration'		
		use "$dataRAW/nhgisMedianCountyIncome/nhgisMedIncClean2000.dta", clear		
		
		rename countya county_from 
		rename statea state_from		
		merge 1:m state_from county_from using `migration'
		
		createShares
		
		//Cleaning up the variables and saving
		drop if county_to == .
		gen state_to = 6		
	
		labelVariables
		
		save "$dataCLEAN/migrationIn_totals0506.dta", replace
		export delimited "$dataCLEAN/migrationIn_totals0506.csv", replace 
	}
	
		
	*Migration year 2015
	local years 1516
	foreach y in `years'{		
		import excel "$dataRAW/irsMigrationFlows/`y'migrationdata/`y'ca.xls", ///
			sheet("County Inflow") clear
	
		drop if _n < 7 //dropping the title rows
		rename A state_to 
		rename B county_to
		rename C state_from
		rename D county_from
		rename E state_abbr
		rename F county_name
		rename G number_returns
		rename H migration_in
		drop I
		destring state_from, replace
		drop if state_from > 56 //Dropping everything but county to county flows
		destring state_to county_to county_from number_returns ///
			migration_in, replace
		gen year = 2016
			
	
		//Merging with Census 2010 county income data (I've verfied both sets are using fips)
		tempfile migration 
		save `migration'		
		use "$dataRAW/nhgisMedianCountyIncome/nhgisMedIncClean2010.dta", clear
		rename countya county_from 
		rename statea state_from		
		merge 1:m state_from county_from using `migration'
		
		createShares
	
		
		//Cleaning up the variables and saving
		drop if county_to == .
		gen state_to = 6
		
		labelVariables

		save "$dataCLEAN/migrationIn_totals1516.dta", replace
		export delimited "$dataCLEAN/migrationIn_totals1516.csv", replace 
	}
				


end

/*---------------------------------------------------------*/
/* create shares of migrants */
/*---------------------------------------------------------*/
capture program drop createShares
program define createShares
	
	/*
	Used in readin_migration_flows
	*/
	
	//Total migration in for each county
	preserve
		collapse (sum) migration_in, by (county_to year)
		tempfile totalIn
		save `totalIn'
	restore
	
	//Slicing in migration by 3 income quantiles of county_from
	preserve
		collapse (sum) migration_in, by (county_to quantile3 year)		
		reshape wide migration_in, i(county_to) j(quantile3)
		tempfile quantile3
		save `quantile3'
	restore
	
	//Getting in-migrants from the 90 percentile of median county income
	drop if quantile10 != 10
	collapse (sum) migration_in, by (county_to year)
	rename migration_in migration_in90p
	merge 1:1 county_to using `totalIn', nogen
	merge 1:1 county_to using `quantile3', nogen

	//Shares of migrants
	gen migShare1 = migration_in1/migration_in*100
	gen migShare2 = migration_in2/migration_in*100
	gen migShare3 = migration_in3/migration_in*100
	gen migShare90p = migration_in90p/migration_in*100


end

/*---------------------------------------------------------*/
/* label variables */
/*---------------------------------------------------------*/
capture program drop labelVariables
program define labelVariables
	/* 
	Used in readin_migration_flows
	*/
	
	label variable migration_in "Total migration in. NOT PER CAPITA"
	label variable migration_in90p "Number of migrants from richest 10% of counties"
	label variable migration_in1 "Number of migrants from bottom third of counties"
	label variable migration_in2 "Number of migrants from middle third of counties"
	label variable migration_in3 "Number of migrants from top third of counties"
	label variable migShare1 "Share of migrants from bottom third of counties"
	label variable migShare2 "Share of migrants from middle third of counties"
	label variable migShare3 "Share of migrants from top third of counties"
	label variable migShare90p "Share of migrants from richest 10% of counties"	
end
/*---------------------------------------------------------*/
/* Run main program                                */
/*---------------------------------------------------------*/

main
