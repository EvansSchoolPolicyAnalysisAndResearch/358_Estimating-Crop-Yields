
/*-----------------------------------------------------------------------------------------------------------------------------------------------------
*Title/Purpose 	: This do.file was developed by the Evans School Policy Analysis & Research Group (EPAR) 
				  for the comparison of crop yield estimates using different construction decisions
				  using the Tanzania National Panel Survey (TNPS) LSMS-ISA Wave 2 (2010-11)
*Author(s)		: Pierre Biscaye, Karen Chen, David Coomes, & Josh Merfeld

*Date			: 30 September 2017

----------------------------------------------------------------------------------------------------------------------------------------------------*/

*Data source
*-----------
*The Tanzania National Panel Survey was collected by the Tanzania National Bureau of Statistics (NBS) 
*and the World Bank's Living Standards Measurement Study - Integrated Surveys on Agriculture(LSMS - ISA)
*The data were collected over the period October 2010 to November 2011.
*All the raw data, questionnaires, and basic information documents are available for downloading free of charge at the following link
*http://microdata.worldbank.org/index.php/catalog/1050

*Throughout the do-file, we sometimes use the shorthand LSMS to refer to the Tanzania National Panel Survey.

*Summary of Executing the Master do.file
*-----------
*This Master do.file constructs selected indicators using the Tanzania TNPS (TZA LSMS) data set.
*First save the raw unzipped data files from the World Bank in a new "Raw data" folder. Do not change the structure or organization of the unzipped raw data files.
*The do. file constructs needed intermediate variables, saving dta files when appropriate in a "created data" folder that you will need to create.

*The code first generates the variables needed to calculate yields, then proceeds to generate a series of yield estimates by crop using different construction descisions.
*Summary statistics and output are saved in an "output" folder which you will also need to create.
 
*********************************
*** Directories and Paths     ***
*********************************
clear
clear matrix
clear mata
program drop _all
set more off

*NOTE: You will have to update the global macros below

*Add names of specific folders here
global tzn_wave2 "desired filepath/raw data folder name"
global created_data "desired filepath/created folder name"
global output "desired filepath/output folder name"


****************************************************************************************************************


*************************
*************************
**                     **
**  Crop Yield Begins  **
**         Here        **
**                     **
*************************
*************************
*Region variables for weights
use "$tzn_wave2/Data_Household/HH_SEC_A.dta", clear
keep y2_hhid y2_weight clusterid strataid
save "$created_data/tzn2_weights_merge.dta", replace


*Gender variables
use "$tzn_wave2/Data_Household/HH_SEC_B.dta", clear
ren indidy2 personid		// personid is the roster number, combination of y2_hhid and personid are unique id for this wave
gen female =hh_b02==2
gen age = hh_b04
gen head = hh_b05==1 if hh_b05!=.
keep personid female age y2_hhid head
save "$created_data/tzn2_gender_merge.dta", replace


*Collapsing for gender of head
gen male_head = female==0 & head==1
collapse (max) male_head, by(y2_hhid)
save "$created_data/tzn2_gender_head.dta", replace




*******
* LRS *
*******
*First starting with field sizes
use "$tzn_wave2/Data_Agriculture/AG_SEC2A.dta", clear
*Calculate field area in hectares
gen field_area = ag2a_09	//GPS measurement
*1,315 generated
replace field_area = ag2a_04 if ag2a_09==0 | ag2a_09==.			// use farmer's estimate if GPS measurement is 0 or missing 
*1,319 changes
replace field_area = field_area*0.404686		// convert acres to hectares


*Status of field
merge 1:1 y2_hhid plotnum using "$tzn_wave2/Data_Agriculture/AG_SEC3A.dta", gen(_merge_plotdetails_LRS)
* 0 not matched
* 6,038 matched
gen field_cultivated = ag3a_03==1 if ag3a_03!=.		// equals one if field was cultivated during LRS

*Gender/age variables
gen personid = ag3a_08_1
merge m:1 y2_hhid personid using "$created_data/tzn2_gender_merge.dta", gen(dm1_merge) keep(1 3)		// Dropping unmatched from using
*1,177 not matched from master
*4,861 matched
tab dm1_merge field_cultivated		// Almost all unmatched observations (>96%) are due to field not being cultivated
*First decision-maker variables
gen dm1_female = female
gen dm1_age = age
drop female age personid

*Second owner
gen personid = ag3a_08_2
merge m:1 y2_hhid personid using "$created_data/tzn2_gender_merge.dta", gen(dm2_merge) keep(1 3)		// Dropping unmatched from using
*3,368 not matched from master
*2,670 matched
gen dm2_female = female
gen dm2_age = age
drop female age personid

*Third
gen personid = ag3a_08_3
merge m:1 y2_hhid personid using "$created_data/tzn2_gender_merge.dta", gen(dm3_merge) keep(1 3)			// Dropping unmatched from using
*5,814 not matched from master
*224 matched
gen dm3_female = female
gen dm3_age = age
drop female age personid


*Constructing three-part gendered decision-maker variable; male only (=1) female only (=2) or mixed (=3)
gen decision_maker_gender = 1 if (dm1_female==0 | dm1_female==.) & (dm2_female==0 | dm2_female==.) & (dm3_female==0 | dm3_female==.) & !(dm1_female==. & dm2_female==. & dm3_female==.)
replace decision_maker_gender = 2 if (dm1_female==1 | dm1_female==.) & (dm2_female==1 | dm2_female==.) & (dm3_female==1 | dm3_female==.) & !(dm1_female==. & dm2_female==. & dm3_female==.)
replace decision_maker_gender = 3 if decision_maker_gender==. & !(dm1_female==. & dm2_female==. & dm3_female==.)
la def dm_gender 1 "Male only" 2 "Female only" 3 "Mixed gender"
la val decision_maker_gender dm_gender

gen field_area_cultivated = field_area if field_cultivated==1
keep y2_hhid plotnum field_area field_area_cultivated decision_maker_gender field_cultivated

gen dm_male = decision_maker_gender==1 if decision_maker_gender!=.
gen dm_female = decision_maker_gender==2 if decision_maker_gender!=.
gen dm_mixed = decision_maker_gender==3 if decision_maker_gender!=.

save "$created_data/tzn2_field.dta", replace





*Now crops
use "$tzn_wave2/Data_Agriculture/AG_SEC4A.dta", clear
*Percent of area
gen pure_stand = ag4a_01==1
gen any_pure = pure_stand==1
gen any_mixed = pure_stand==0
gen percent_field = 0.25 if ag4a_02==1
replace percent_field = 0.50 if ag4a_02==2
replace percent_field = 0.75 if ag4a_02==3
replace percent_field = 1 if pure_stand==1


*Total area on field
bys y2_hhid plotnum: egen total_percent_field = total(percent_field)				// not by zaocode; we want to rescale for entire plot
replace percent_field = percent_field/total_percent_field if total_percent_field>1			// Rescaling


*Merging in area from tzn2_field
merge m:1 y2_hhid plotnum using "$created_data/tzn2_field.dta", nogen keep(1 3)	// dropping those only in using
*0 not matched
*8,206 matched


gen crop_area_planted = percent_field*field_area_cultivated

keep crop_area_planted* y2_hhid plotnum zaocode dm_* any_* decision_maker_gender pure_stand
save "$created_data/tzn2_crop.dta", replace






*Now to harvest
use "$tzn_wave2/Data_Agriculture/AG_SEC4A.dta", clear

gen kg_harvest = ag4a_15 if ag4a_12==1
replace kg_harvest = 0 if ag4a_07==3
drop if kg_harvest==.							// dropping those with missing kg


keep y2_hhid plotnum zaocode kg_harvest

*Merging area
merge m:1 y2_hhid plotnum zaocode using "$created_data/tzn2_crop.dta", nogen keep(1 3)
*0 not matched
*5,678 matched

*Creating new harvest variables
gen kg_harvest_male_dm = kg_harvest if dm_male==1
gen kg_harvest_female_dm = kg_harvest if dm_female==1
gen kg_harvest_mixed_dm = kg_harvest if dm_mixed==1
gen kg_harvest_purestand = kg_harvest if any_pure==1
gen kg_harvest_mixedstand = kg_harvest if any_mixed==1
gen kg_harvest_male_pure = kg_harvest if dm_male==1 & any_pure==1
gen kg_harvest_female_pure = kg_harvest if dm_female==1 & any_pure==1
gen kg_harvest_mixed_pure = kg_harvest if dm_mixed==1 & any_pure==1
gen kg_harvest_male_mixed = kg_harvest if dm_male==1 & any_mixed==1
gen kg_harvest_female_mixed = kg_harvest if dm_female==1 & any_mixed==1
gen kg_harvest_mixed_mixed = kg_harvest if dm_mixed==1 & any_mixed==1

gen count_plot = 1
gen count_male_dm = dm_male==1
gen count_female_dm = dm_female==1
gen count_mixed_dm = dm_mixed==1
gen count_purestand = any_pure==1
gen count_mixedstand = any_mixed==1
gen count_male_pure = dm_male==1 & any_pure==1
gen count_female_pure = dm_female==1 & any_pure==1
gen count_mixed_pure = dm_mixed==1 & any_pure==1
gen count_male_mixed = dm_male==1 & any_mixed==1
gen count_female_mixed = dm_female==1 & any_mixed==1
gen count_mixed_mixed = dm_mixed==1 & any_mixed==1

save "$created_data/tzn2_lrs.dta", replace		// saving BEFORE construction and winsorizing for total yields across both seasons; at the plot-crop level










*******
* SRS *		only going to use NEW plots (those not used in LRS)
*******
*First starting with field sizes
use "$tzn_wave2/Data_Agriculture/AG_SEC2B.dta", clear
*Calculate field area in hectares
gen field_area = ag2b_20	//GPS measurement
replace field_area = ag2b_15 if ag2b_20==0 | ag2b_20==.			// use farmer's estimate if GPS measurement is 0 or missing 
*22 changes
replace field_area = field_area*0.404686		// convert acres to hectares
*38 changes

*Status of field
merge 1:1 y2_hhid plotnum using "$tzn_wave2/Data_Agriculture/AG_SEC3B.dta", gen(_merge_plotdetails_SRS) keep(1 3)
*0 not matched
*38 matched
gen field_cultivated = ag3b_03==1 if ag3b_03!=.		// equals one if field was cultivated during SRS

*Gender/age variables
gen personid = ag3b_08_1
merge m:1 y2_hhid personid using "$created_data/tzn2_gender_merge.dta", gen(dm1_merge) keep(1 3)		// Dropping unmatched from using
*15 not matched from master
*23 matched
tab dm1_merge field_cultivated		// All unmatched observations are due to field not being cultivated
*First decision-maker variables
gen dm1_female = female
gen dm1_age = age
drop female age personid

*Second owner
gen personid = ag3b_08_2
merge m:1 y2_hhid personid using "$created_data/tzn2_gender_merge.dta", gen(dm2_merge) keep(1 3)		// Dropping unmatched from using
*29 not matched from master
*9 matched
gen dm2_female = female
gen dm2_age = age
drop female age personid

*Third
gen personid = ag3b_08_3
merge m:1 y2_hhid personid using "$created_data/tzn2_gender_merge.dta", gen(dm3_merge) keep(1 3)			// Dropping unmatched from using
*37 not matched from master
*1 matched
gen dm3_female = female
gen dm3_age = age
drop female age personid


*Constructing three-part gendered decision-maker variable; male only (=1) female only (=2) or mixed (=3)
gen decision_maker_gender = 1 if (dm1_female==0 | dm1_female==.) & (dm2_female==0 | dm2_female==.) & (dm3_female==0 | dm3_female==.) & !(dm1_female==. & dm2_female==. & dm3_female==.)
replace decision_maker_gender = 2 if (dm1_female==1 | dm1_female==.) & (dm2_female==1 | dm2_female==.) & (dm3_female==1 | dm3_female==.) & !(dm1_female==. & dm2_female==. & dm3_female==.)
replace decision_maker_gender = 3 if decision_maker_gender==. & !(dm1_female==. & dm2_female==. & dm3_female==.)
la def dm_gender 1 "Male only" 2 "Female only" 3 "Mixed gender"
la val decision_maker_gender dm_gender

gen field_area_cultivated = field_area if field_cultivated==1
keep y2_hhid plotnum field_area field_area_cultivated decision_maker_gender field_cultivated

gen dm_male = decision_maker_gender==1 if decision_maker_gender!=.
gen dm_female = decision_maker_gender==2 if decision_maker_gender!=.
gen dm_mixed = decision_maker_gender==3 if decision_maker_gender!=.

save "$created_data/tzn2_field_srs.dta", replace






*Now crops
use "$tzn_wave2/Data_Agriculture/AG_SEC4B.dta", clear
*Percent of area
gen pure_stand = ag4b_01==1
gen any_pure = pure_stand==1
gen any_mixed = pure_stand==0
gen percent_field = 0.25 if ag4b_02==1
replace percent_field = 0.50 if ag4b_02==2
replace percent_field = 0.75 if ag4b_02==3
replace percent_field = 1 if pure_stand==1


*Total area on field
bys y2_hhid plotnum: egen total_percent_field = total(percent_field)
replace percent_field = percent_field/total_percent_field if total_percent_field>1			// Rescaling


*Merging in area from `tzn2_field'
preserve
merge m:1 y2_hhid plotnum using "$created_data/tzn2_field_srs.dta", nogen keep(3)
*0 not matched
*54 matched
gen lrs_field = 0
tempfile temp
save `temp', replace
restore

merge m:1 y2_hhid plotnum using "$created_data/tzn2_field.dta", nogen keep(3)
*0 not matched
*6,688 matched
gen lrs_field = 1
append using `temp'

gen crop_area_planted = percent_field*field_area_cultivated

keep crop_area_planted* y2_hhid plotnum zaocode dm_* any_* lrs_field decision_maker_gender pure_stand
save "$created_data/tzn2_crop_srs.dta", replace





*Now to harvest
use "$tzn_wave2/Data_Agriculture/AG_SEC4B.dta", clear

gen kg_harvest = ag4b_15 if ag4b_12==1
replace kg_harvest = 0 if ag4b_07==3
drop if kg_harvest==.

keep y2_hhid plotnum zaocode kg_harvest

*Merging area
merge m:1 y2_hhid plotnum zaocode using "$created_data/tzn2_crop_srs.dta", nogen keep(1 3)
*0 not matched
*6,742 matched

*Creating new harvest variables
gen kg_harvest_male_dm = kg_harvest if dm_male==1
gen kg_harvest_female_dm = kg_harvest if dm_female==1
gen kg_harvest_mixed_dm = kg_harvest if dm_mixed==1
gen kg_harvest_purestand = kg_harvest if any_pure==1
gen kg_harvest_mixedstand = kg_harvest if any_mixed==1
gen kg_harvest_male_pure = kg_harvest if dm_male==1 & any_pure==1
gen kg_harvest_female_pure = kg_harvest if dm_female==1 & any_pure==1
gen kg_harvest_mixed_pure = kg_harvest if dm_mixed==1 & any_pure==1
gen kg_harvest_male_mixed = kg_harvest if dm_male==1 & any_mixed==1
gen kg_harvest_female_mixed = kg_harvest if dm_female==1 & any_mixed==1
gen kg_harvest_mixed_mixed = kg_harvest if dm_mixed==1 & any_mixed==1

*Variables for fields
gen count_plot = 1
gen count_male_dm = dm_male==1
gen count_female_dm = dm_female==1
gen count_mixed_dm = dm_mixed==1
gen count_purestand = any_pure==1
gen count_mixedstand = any_mixed==1
gen count_male_pure = dm_male==1 & any_pure==1
gen count_female_pure = dm_female==1 & any_pure==1
gen count_mixed_pure = dm_mixed==1 & any_pure==1
gen count_male_mixed = dm_male==1 & any_mixed==1
gen count_female_mixed = dm_female==1 & any_mixed==1
gen count_mixed_mixed = dm_mixed==1 & any_mixed==1

append using "$created_data/tzn2_lrs.dta"		// appending plot-crop level data from LRS, collapsing everything to the household level below

*Replacing smaller area with zero
bys y2_hhid plotnum zaocode (crop_area_planted): replace crop_area_planted = 0 if _n==1 & crop_area_planted[1]<=crop_area_planted[2] & crop_area_planted[2]!=.

gen crop_area_planted_male_dm = crop_area_planted if dm_male==1
gen crop_area_planted_female_dm = crop_area_planted if dm_female==1
gen crop_area_planted_mixed_dm = crop_area_planted if dm_mixed==1
gen crop_area_planted_purestand = crop_area_planted if any_pure==1
gen crop_area_planted_mixedstand = crop_area_planted if any_pure==0
gen crop_area_planted_male_pure = crop_area_planted if dm_male==1 & any_pure==1
gen crop_area_planted_female_pure = crop_area_planted if dm_female==1 & any_pure==1
gen crop_area_planted_mixed_pure = crop_area_planted if dm_mixed==1 & any_pure==1
gen crop_area_planted_male_mixed = crop_area_planted if dm_male==1 & any_mixed==1
gen crop_area_planted_female_mixed = crop_area_planted if dm_female==1 & any_mixed==1
gen crop_area_planted_mixed_mixed = crop_area_planted if dm_mixed==1 & any_mixed==1

save "$created_data/tzn2_field_crop_level.dta", replace


*Collapsing to household level
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(y2_hhid zaocode)		// collapsing by hhid-crop (zaocode)


*Merging weights and survey variables
merge m:1 y2_hhid using "$created_data/tzn2_weights_merge.dta", nogen keep(1 3)
*0 not matched
*7,679 matched

*Merging Gender of head
merge m:1 y2_hhid using "$created_data/tzn2_gender_head.dta", nogen keep(1 3)
*0 not matched
*7,679 matched

save "$created_data/tzn2_cleaned.dta", replace









************************************
////// Generate Yield Estimates - LRS and SRS
************************************


*First, I am creating a separate crop_area variable FOR EACH crop
*local crop_name maize
foreach crop_name in maize paddy sorghum millet bulrush finger wheat{

if "`crop_name'"=="maize"{
	local crop 11
}
if "`crop_name'"=="paddy"{
	local crop 12	//Paddy
}
if "`crop_name'"=="sorghum"{
	local crop 13	//Sorghum
}
if "`crop_name'"=="millet"{
	local crop "14,15"	//Both Millets		JDM: Do we want to count these (bulrush/pearl and finger) as a single crop or two separate crops?
}
if "`crop_name'"=="bulrush"{
	local crop 14	//Bulrush Millet		
}
if "`crop_name'"=="finger"{
	local crop 15	//Finger Millet
}
*if "`crop_name'"=="wheat"{
*	local crop 16	//Wheat
*}
*if "`crop_name'"=="barley"{			// No observations 
*	local crop 17	//Barley
*}

use "$created_data/tzn2_cleaned.dta", clear
keep if inlist(zaocode,`crop')

*Recoding zeros to missing if they should be missing
recode crop_area_planted (0=.)
recode crop_area_planted_male_dm (0=.) if count_male_dm!=0
recode crop_area_planted_female_dm (0=.) if count_female_dm!=0
recode crop_area_planted_mixed_dm (0=.) if count_mixed_dm!=0
recode crop_area_planted_purestand (0=.) if count_purestand!=0
recode crop_area_planted_mixedstand (0=.) if count_mixedstand!=0
recode crop_area_planted_male_pure (0=.) if count_male_pure!=0
recode crop_area_planted_female_pure (0=.) if count_female_pure!=0
recode crop_area_planted_mixed_pure (0=.) if count_mixed_pure!=0
recode crop_area_planted_male_mixed (0=.) if count_male_mixed!=0
recode crop_area_planted_female_mixed (0=.) if count_female_mixed!=0
recode crop_area_planted_mixed_mixed (0=.) if count_mixed_mixed!=0

winsor2 crop_area*, cuts(1 99) replace			// winsorizing at 1 and 99

*Creating yield variables at the household level	- with crop_area in the denominator, zeros/missings will result in missing kg_hectare; don't need the qualifiers
gen kg_hectare = kg_harvest/crop_area_planted
gen kg_hectare_male_dm = kg_harvest_male_dm/crop_area_planted_male_dm if count_male_dm!=0	// if >0, then there is at least one plot in the household that satisfies the criterion
gen kg_hectare_female_dm = kg_harvest_female_dm/crop_area_planted_female_dm if count_female_dm!=0
gen kg_hectare_mixed_dm = kg_harvest_mixed_dm/crop_area_planted_mixed_dm if count_mixed_dm!=0
gen kg_hectare_purestand = kg_harvest_purestand/crop_area_planted_purestand if count_purestand!=0
gen kg_hectare_mixedstand = kg_harvest_mixedstand/crop_area_planted_mixedstand if count_mixedstand!=0
gen kg_hectare_male_pure = kg_harvest_male_pure/crop_area_planted_male_pure if count_male_pure!=0
gen kg_hectare_female_pure = kg_harvest_female_pure/crop_area_planted_female_pure if count_female_pure!=0
gen kg_hectare_mixed_pure = kg_harvest_mixed_pure/crop_area_planted_mixed_pure if count_mixed_pure!=0
gen kg_hectare_male_mixed = kg_harvest_male_mixed/crop_area_planted_male_mixed if count_male_mixed!=0
gen kg_hectare_female_mixed = kg_harvest_female_mixed/crop_area_planted_female_mixed if count_female_mixed!=0
gen kg_hectare_mixed_mixed = kg_harvest_mixed_mixed/crop_area_planted_mixed_mixed if count_mixed_mixed!=0


*MAD for upper tail
foreach i of varlist kg_hectare*{
	gen `i'_MAD = `i'
	sum `i', d
	replace `i'_MAD = r(p50) if `i'>r(p50)+2*r(sd) & `i'!=.
	*replace `i'_MAD = r(p50) if `i'<r(p50)-2*r(sd) & `i'!=.		// Not replacing lower
}

*Now winsorizing top 1 percent
winsor2 kg_hectare*, cuts(0 99) replace



*Generate yield estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w2_all_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	modelwidth(6 2 6 6 6 2 6 6) varwidth(25) note("The decision-maker variable is constructed using the answers to the question Who decided what to plant on this plot in the long rainy season 2008? The decision-maker is coded as male only if all listed decision-makers are male. The variable is coded as female only if all listed decision-makers are female. The variable is otherwise coded as mixed. Winsorized values are replaced at the 99th percentile; any larger values are replaced with the 99th percentile. MAD values are constructed by replacing all values more than two standard deviations above the median with the median. In the top panel statistics include both the long and short rainy seasons, with output aggregated over both seasons but only the largest area planted used as area. In other words, if a household plants one hectare of maize in the long rainy season but two hectares of maize in the short rainy season, two hectares is used as the area for construction of total yield. In the bottom panel, only the long rainy season is included. The decision-maker variables are defined at the plot level but the stand variables are defined as the crop level. As such, some households are represented multiple times across variables. For example, some households have plots under both male-decision makers and female decision-makers, while some other households also have both mixed and pure stand plots. Area weights are used, which are constructed by multiplying the household weight by the area planted. These weights are constructed separately for each subsample.")
	;
#delimit cr




*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w2_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	;
#delimit cr







************************************
////// Generate Yield Estimates - LRS only
************************************



use "$created_data/tzn2_lrs.dta", clear

gen crop_area_planted_male_dm = crop_area_planted if dm_male==1
gen crop_area_planted_female_dm = crop_area_planted if dm_female==1
gen crop_area_planted_mixed_dm = crop_area_planted if dm_mixed==1
gen crop_area_planted_purestand = crop_area_planted if any_pure==1
gen crop_area_planted_mixedstand = crop_area_planted if any_pure==0
gen crop_area_planted_male_pure = crop_area_planted if dm_male==1 & any_pure==1
gen crop_area_planted_female_pure = crop_area_planted if dm_female==1 & any_pure==1
gen crop_area_planted_mixed_pure = crop_area_planted if dm_mixed==1 & any_pure==1
gen crop_area_planted_male_mixed = crop_area_planted if dm_male==1 & any_mixed==1
gen crop_area_planted_female_mixed = crop_area_planted if dm_female==1 & any_mixed==1
gen crop_area_planted_mixed_mixed = crop_area_planted if dm_mixed==1 & any_mixed==1

*Collapsing to household level
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(y2_hhid zaocode)				// hhid/crop level


*Merging weights and survey variables
merge m:1 y2_hhid using "$created_data/tzn2_weights_merge.dta", nogen keep(1 3)

*Merging Gender of head
merge m:1 y2_hhid using "$created_data/tzn2_gender_head.dta", nogen keep(1 3)								// 1 not matched from master
keep if inlist(zaocode,`crop')

*Recoding zeros to missing if they should be missing
recode crop_area_planted (0=.)
recode crop_area_planted_male_dm (0=.) if count_male_dm!=0
recode crop_area_planted_female_dm (0=.) if count_female_dm!=0
recode crop_area_planted_mixed_dm (0=.) if count_mixed_dm!=0
recode crop_area_planted_purestand (0=.) if count_purestand!=0
recode crop_area_planted_mixedstand (0=.) if count_mixedstand!=0
recode crop_area_planted_male_pure (0=.) if count_male_pure!=0
recode crop_area_planted_female_pure (0=.) if count_female_pure!=0
recode crop_area_planted_mixed_pure (0=.) if count_mixed_pure!=0
recode crop_area_planted_male_mixed (0=.) if count_male_mixed!=0
recode crop_area_planted_female_mixed (0=.) if count_female_mixed!=0
recode crop_area_planted_mixed_mixed (0=.) if count_mixed_mixed!=0

winsor2 crop_area*, cuts(1 99) replace			// winsorizing at 1 and 99

*Creating yield variables at the household level	- with crop_area in the denominator, zeros/missings will result in missing kg_hectare; don't need the qualifiers
gen kg_hectare = kg_harvest/crop_area_planted
gen kg_hectare_male_dm = kg_harvest_male_dm/crop_area_planted_male_dm if count_male_dm!=0	// if >0, then there is at least one plot in the household that satisfies the criterion
gen kg_hectare_female_dm = kg_harvest_female_dm/crop_area_planted_female_dm if count_female_dm!=0
gen kg_hectare_mixed_dm = kg_harvest_mixed_dm/crop_area_planted_mixed_dm if count_mixed_dm!=0
gen kg_hectare_purestand = kg_harvest_purestand/crop_area_planted_purestand if count_purestand!=0
gen kg_hectare_mixedstand = kg_harvest_mixedstand/crop_area_planted_mixedstand if count_mixedstand!=0
gen kg_hectare_male_pure = kg_harvest_male_pure/crop_area_planted_male_pure if count_male_pure!=0
gen kg_hectare_female_pure = kg_harvest_female_pure/crop_area_planted_female_pure if count_female_pure!=0
gen kg_hectare_mixed_pure = kg_harvest_mixed_pure/crop_area_planted_mixed_pure if count_mixed_pure!=0
gen kg_hectare_male_mixed = kg_harvest_male_mixed/crop_area_planted_male_mixed if count_male_mixed!=0
gen kg_hectare_female_mixed = kg_harvest_female_mixed/crop_area_planted_female_mixed if count_female_mixed!=0
gen kg_hectare_mixed_mixed = kg_harvest_mixed_mixed/crop_area_planted_mixed_mixed if count_mixed_mixed!=0


*MAD for upper tail
foreach i of varlist kg_hectare*{
	gen `i'_MAD = `i'
	sum `i', d
	replace `i'_MAD = r(p50) if `i'>r(p50)+2*r(sd) & `i'!=.
	*replace `i'_MAD = r(p50) if `i'<r(p50)-2*r(sd) & `i'!=.		// Not replacing lower
}

*Now winsorizing top 1 percent
winsor2 kg_hectare*, cuts(0 99) replace


*generating estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w2_LRS_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	;
#delimit cr





*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w2_LRS_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	;
#delimit cr






*Now by number of plots; this is a HOUSEHOLD-level variable, using household weights here
preserve
collapse (sum) count_*
eststo plot1: mean count_*
#delimit ;
	esttab plot1 using "$output/tzn_w2_plots_LRS_`crop_name'.rtf", cells(b(fmt(3)) se(fmt(3) par)) stats(subpop_N, label("Households")) replace
	coeflabels(count_plot "Plots" count_male_dm "Plots - Male" count_female_dm "Plots - Female" count_mixed_dm "Plots - Mixed Gender" count_purestand "Plots - Purestand"
	count_mixedstand "Plots - Mixed stand" count_male_pure "Plots - Male Pure" count_female_pure "Plots - Female Pure" count_mixed_pure "Plots - Mixed Gender Pure"
	count_male_mixed "Plots - Male Mixed" count_female_mixed "Plots - Female Mixed" count_mixed_mixed "Plots - Mixed Gender Mixed")
	;
#delimit cr
restore


********************************************************
* Using LRS area for all plots that are in LRS and SRS *
********************************************************
*SRS changes only

*Now to harvest
use "$tzn_wave2/Data_Agriculture/AG_SEC4B.dta", clear

gen kg_harvest = ag4b_15 if ag4b_12==1
replace kg_harvest = 0 if ag4b_07==3
drop if kg_harvest==.

keep y2_hhid plotnum zaocode kg_harvest

*Merging area
merge m:1 y2_hhid plotnum zaocode using "$created_data/tzn2_crop_srs.dta", nogen keep(1 3)
*0 not matched
*6,742 matched

*Creating new harvest variables
gen kg_harvest_male_dm = kg_harvest if dm_male==1
gen kg_harvest_female_dm = kg_harvest if dm_female==1
gen kg_harvest_mixed_dm = kg_harvest if dm_mixed==1
gen kg_harvest_purestand = kg_harvest if any_pure==1
gen kg_harvest_mixedstand = kg_harvest if any_mixed==1
gen kg_harvest_male_pure = kg_harvest if dm_male==1 & any_pure==1
gen kg_harvest_female_pure = kg_harvest if dm_female==1 & any_pure==1
gen kg_harvest_mixed_pure = kg_harvest if dm_mixed==1 & any_pure==1
gen kg_harvest_male_mixed = kg_harvest if dm_male==1 & any_mixed==1
gen kg_harvest_female_mixed = kg_harvest if dm_female==1 & any_mixed==1
gen kg_harvest_mixed_mixed = kg_harvest if dm_mixed==1 & any_mixed==1

*Variables for fields
gen count_plot = 1
gen count_male_dm = dm_male==1
gen count_female_dm = dm_female==1
gen count_mixed_dm = dm_mixed==1
gen count_purestand = any_pure==1
gen count_mixedstand = any_mixed==1
gen count_male_pure = dm_male==1 & any_pure==1
gen count_female_pure = dm_female==1 & any_pure==1
gen count_mixed_pure = dm_mixed==1 & any_pure==1
gen count_male_mixed = dm_male==1 & any_mixed==1
gen count_female_mixed = dm_female==1 & any_mixed==1
gen count_mixed_mixed = dm_mixed==1 & any_mixed==1

append using "$created_data/tzn2_lrs.dta", gen(lrs)		// appending plot-crop level data from LRS, collapsing everything to the household level below

*This is the change from above
bys y2_hhid plotnum zaocode (lrs): replace crop_area_planted=0 if lrs[1]==0 & lrs[2]==1 & _n==1 & crop_area_planted[2]!=0 & crop_area_planted[2]!=.	// replacing crop_area for first obs (srs) if first obs lrs==0 and second obs lrs==1 (but only if crop area from lrs is not zero or missing)

gen crop_area_planted_male_dm = crop_area_planted if dm_male==1
gen crop_area_planted_female_dm = crop_area_planted if dm_female==1
gen crop_area_planted_mixed_dm = crop_area_planted if dm_mixed==1
gen crop_area_planted_purestand = crop_area_planted if any_pure==1
gen crop_area_planted_mixedstand = crop_area_planted if any_pure==0
gen crop_area_planted_male_pure = crop_area_planted if dm_male==1 & any_pure==1
gen crop_area_planted_female_pure = crop_area_planted if dm_female==1 & any_pure==1
gen crop_area_planted_mixed_pure = crop_area_planted if dm_mixed==1 & any_pure==1
gen crop_area_planted_male_mixed = crop_area_planted if dm_male==1 & any_mixed==1
gen crop_area_planted_female_mixed = crop_area_planted if dm_female==1 & any_mixed==1
gen crop_area_planted_mixed_mixed = crop_area_planted if dm_mixed==1 & any_mixed==1

save "$created_data/tzn2_field_crop_level_lrsarea.dta", replace


*Collapsing to household level
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(y2_hhid zaocode)		// collapsing by hhid-crop (zaocode)


*Merging weights and survey variables
merge m:1 y2_hhid using "$created_data/tzn2_weights_merge.dta", nogen keep(1 3)
*0 not matched
*7,679 matched

*Merging Gender of head
merge m:1 y2_hhid using "$created_data/tzn2_gender_head.dta", nogen keep(1 3)
*0 not matched
*7,679 matched

save "$created_data/tzn2_cleaned_lrsarea.dta", replace












*First, I am creating a separate crop_area variable FOR EACH crop
*local crop_name maize
foreach crop_name in maize paddy sorghum millet bulrush finger wheat{

if "`crop_name'"=="maize"{
	local crop 11
}
if "`crop_name'"=="paddy"{
	local crop 12	//Paddy
}
if "`crop_name'"=="sorghum"{
	local crop 13	//Sorghum
}
if "`crop_name'"=="millet"{
	local crop "14,15"	//Both Millets		JDM: Do we want to count these (bulrush/pearl and finger) as a single crop or two separate crops?
}
if "`crop_name'"=="bulrush"{
	local crop 14	//Bulrush Millet		
}
if "`crop_name'"=="finger"{
	local crop 15	//Finger Millet
}
if "`crop_name'"=="wheat"{
	local crop 16	//Wheat
}
*if "`crop_name'"=="barley"{			// Not enough observations 
*	local crop 17	//Barley
*}

use "$created_data/tzn2_cleaned_lrsarea.dta", clear
keep if inlist(zaocode,`crop')

*Recoding zeros to missing if they should be missing
recode crop_area_planted (0=.)
recode crop_area_planted_male_dm (0=.) if count_male_dm!=0
recode crop_area_planted_female_dm (0=.) if count_female_dm!=0
recode crop_area_planted_mixed_dm (0=.) if count_mixed_dm!=0
recode crop_area_planted_purestand (0=.) if count_purestand!=0
recode crop_area_planted_mixedstand (0=.) if count_mixedstand!=0
recode crop_area_planted_male_pure (0=.) if count_male_pure!=0
recode crop_area_planted_female_pure (0=.) if count_female_pure!=0
recode crop_area_planted_mixed_pure (0=.) if count_mixed_pure!=0
recode crop_area_planted_male_mixed (0=.) if count_male_mixed!=0
recode crop_area_planted_female_mixed (0=.) if count_female_mixed!=0
recode crop_area_planted_mixed_mixed (0=.) if count_mixed_mixed!=0

winsor2 crop_area*, cuts(1 99) replace			// winsorizing at 1 and 99

*Creating yield variables at the household level	- with crop_area in the denominator, zeros/missings will result in missing kg_hectare; don't need the qualifiers
gen kg_hectare = kg_harvest/crop_area_planted
gen kg_hectare_male_dm = kg_harvest_male_dm/crop_area_planted_male_dm if count_male_dm!=0	// if >0, then there is at least one plot in the household that satisfies the criterion
gen kg_hectare_female_dm = kg_harvest_female_dm/crop_area_planted_female_dm if count_female_dm!=0
gen kg_hectare_mixed_dm = kg_harvest_mixed_dm/crop_area_planted_mixed_dm if count_mixed_dm!=0
gen kg_hectare_purestand = kg_harvest_purestand/crop_area_planted_purestand if count_purestand!=0
gen kg_hectare_mixedstand = kg_harvest_mixedstand/crop_area_planted_mixedstand if count_mixedstand!=0
gen kg_hectare_male_pure = kg_harvest_male_pure/crop_area_planted_male_pure if count_male_pure!=0
gen kg_hectare_female_pure = kg_harvest_female_pure/crop_area_planted_female_pure if count_female_pure!=0
gen kg_hectare_mixed_pure = kg_harvest_mixed_pure/crop_area_planted_mixed_pure if count_mixed_pure!=0
gen kg_hectare_male_mixed = kg_harvest_male_mixed/crop_area_planted_male_mixed if count_male_mixed!=0
gen kg_hectare_female_mixed = kg_harvest_female_mixed/crop_area_planted_female_mixed if count_female_mixed!=0
gen kg_hectare_mixed_mixed = kg_harvest_mixed_mixed/crop_area_planted_mixed_mixed if count_mixed_mixed!=0


*MAD for upper tail
foreach i of varlist kg_hectare*{
	gen `i'_MAD = `i'
	sum `i', d
	replace `i'_MAD = r(p50) if `i'>r(p50)+2*r(sd) & `i'!=.
	replace `i'_MAD = r(p50) if `i'<r(p50)-2*r(sd) & `i'!=.		// replacing lower end only, as well
}

*Now winsorizing top 1 percent
winsor2 kg_hectare*, cuts(0 99) replace



*generating estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w2_LRSarea_all_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	modelwidth(6 2 6 6 6 2 6 6) varwidth(25) note("The decision-maker variable is constructed using the answers to the question Who decided what to plant on this plot in the long rainy season 2008? The decision-maker is coded as male only if all listed decision-makers are male. The variable is coded as female only if all listed decision-makers are female. The variable is otherwise coded as mixed. Winsorized values are replaced at the 99th percentile; any larger values are replaced with the 99th percentile. MAD values are constructed by replacing all values more than two standard deviations above the median with the median. In the top panel statistics include both the long and short rainy seasons, with output aggregated over both seasons but only the largest area planted used as area. In other words, if a household plants one hectare of maize in the long rainy season but two hectares of maize in the short rainy season, two hectares is used as the area for construction of total yield. In the bottom panel, only the long rainy season is included. The decision-maker variables are defined at the plot level but the stand variables are defined as the crop level. As such, some households are represented multiple times across variables. For example, some households have plots under both male-decision makers and female decision-makers, while some other households also have both mixed and pure stand plots. Area weights are used, which are constructed by multiplying the household weight by the area planted. These weights are constructed separately for each subsample.")
	;
#delimit cr





*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

if !inlist(zaocode,16){
replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]
}

replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

if !inlist(zaocode,16){
replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*y2_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]
}

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w2_LRSarea_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD")
	;
#delimit cr
}




