
/*-----------------------------------------------------------------------------------------------------------------------------------------------------
*Title/Purpose 	: This do.file was developed by the Evans School Policy Analysis & Research Group (EPAR) 
				  for the comparison of crop yield estimates using different construction decisions
				  using the Tanzania National Panel Survey (TNPS) LSMS-ISA Wave 1 (2012-13)
*Author(s)		: Pierre Biscaye, Karen Chen, David Coomes, & Josh Merfeld

*Date			: 30 September 2017

----------------------------------------------------------------------------------------------------------------------------------------------------*/

*Data source
*-----------
*The Tanzania National Panel Survey was collected by the Tanzania National Bureau of Statistics (NBS) 
*and the World Bank's Living Standards Measurement Study - Integrated Surveys on Agriculture(LSMS - ISA)
*The data were collected over the period October 2012 to November 2013.
*All the raw data, questionnaires, and basic information documents are available for downloading free of charge at the following link
*http://microdata.worldbank.org/index.php/catalog/2252

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
global tzn_wave3 "desired filepath/raw data folder name"
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
use "$tzn_wave3/Household/HH_SEC_A.dta", clear
keep y3_hhid y3_weight clusterid strataid
save "$created_data/tzn3_weights_merge.dta", replace


*Gender variables
use "$tzn_wave3/Household/HH_SEC_B.dta", clear
ren indidy3 personid			// personid is the roster number, combination of household_id2 and personid are unique id for this wave
gen female =hh_b02==2
gen age = hh_b04
gen head = hh_b05==1 if hh_b05!=.
keep personid female age y3_hhid head
save "$created_data/tzn3_gender_merge.dta", replace


*Collapsing for gender of head
gen male_head = female==0 & head==1
collapse (max) male_head, by(y3_hhid)
save "$created_data/tzn3_gender_head.dta", replace




*******
* LRS *
*******
*First starting with field sizes
use "$tzn_wave3/Agriculture/AG_SEC_2A.dta", clear
*Calculate field area in hectares
gen field_area = ag2a_09	//GPS measurement
*3,761 generated
replace field_area = ag2a_04 if ag2a_09==0 | ag2a_09==.			// use farmer's estimate if GPS measurement is 0 or missing 
*2,064 changes
replace field_area = field_area*0.404686		// convert acres to hectares


*Status of field
merge 1:1 y3_hhid plotnum using "$tzn_wave3/Agriculture/AG_SEC_3A.dta", gen(_merge_plotdetails_LRS)
*0 not matched
*9,157 matched
gen field_cultivated = ag3a_03==1 if ag3a_03!=.		// equals one if field was cultivated during LRS

*Gender/age variables
gen personid = ag3a_08_1
merge m:1 y3_hhid personid using "$created_data/tzn3_gender_merge.dta", gen(dm1_merge) keep(1 3)		// Dropping unmatched from using
*2,996 not matched from master
*6,161 matched
tab dm1_merge field_cultivated		// Almost all unmatched observations (>96%) are due to field not being cultivated
*First decision-maker variables
gen dm1_female = female
gen dm1_age = age
drop female age personid

*Second owner
gen personid = ag3a_08_2
merge m:1 y3_hhid personid using "$created_data/tzn3_gender_merge.dta", gen(dm2_merge) keep(1 3)		// Dropping unmatched from using
*5,917 not matched from master
*3,240 matched
gen dm2_female = female
gen dm2_age = age
drop female age personid

*Third
gen personid = ag3a_08_3
merge m:1 y3_hhid personid using "$created_data/tzn3_gender_merge.dta", gen(dm3_merge) keep(1 3)		// Dropping unmatched from using
*8,987 not matched from master
*170 matched
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
keep y3_hhid plotnum field_area field_area_cultivated decision_maker_gender field_cultivated

gen dm_male = decision_maker_gender==1 if decision_maker_gender!=.
gen dm_female = decision_maker_gender==2 if decision_maker_gender!=.
gen dm_mixed = decision_maker_gender==3 if decision_maker_gender!=.

save "$created_data/tzn3_field.dta", replace





*Now crops
use "$tzn_wave3/Agriculture/AG_SEC_4A.dta", clear
*Percent of area
gen pure_stand = ag4a_01==1
gen any_pure = pure_stand==1
gen any_mixed = pure_stand==0
gen percent_field = 0.25 if ag4a_02==1
replace percent_field = 0.50 if ag4a_02==2
replace percent_field = 0.75 if ag4a_02==3
replace percent_field = 1 if pure_stand==1
duplicates report y3_hhid plotnum zaocode		// There area a few duplicates
duplicates drop y3_hhid plotnum zaocode, force	// The percent_field and pure_stand variables are the same, so dropping duplicates

*Total area on field
bys y3_hhid plotnum: egen total_percent_field = total(percent_field)			// total on plot across ALL crops
replace percent_field = percent_field/total_percent_field if total_percent_field>1			// Rescaling


*Merging in area from tzn3_field
merge m:1 y3_hhid plotnum using "$created_data/tzn3_field.dta", nogen keep(1 3)	// dropping those only in using
*539 not matched from master
*9,644 matched


gen crop_area_planted = percent_field*field_area_cultivated

keep crop_area_planted* y3_hhid plotnum zaocode dm_* any_* pure_stand decision_maker_gender
save "$created_data/tzn3_crop.dta", replace





*Now to harvest
use "$tzn_wave3/Agriculture/AG_SEC_4A.dta", clear

gen kg_harvest = ag4a_28 if ag4a_25==1			// Only those that have completed harvest (just 46 plot-crops haven't completed)
replace kg_harvest = 0 if ag4a_20==3
drop if kg_harvest==.							// dropping those with missing kg (to prevent collapsing problems below with zeros instead of missings)

keep y3_hhid plotnum zaocode kg_harvest

*Merging area
merge m:1 y3_hhid plotnum zaocode using "$created_data/tzn3_crop.dta", nogen keep(1 3)			// All matched


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

save "$created_data/tzn3_lrs.dta", replace			// saving BEFORE construction and winsorizing for total yields across both seasons; at plot-crop level












*******
* SRS * Adding area of only NEW plots (those not used in LRS)
*******
*First starting with field sizes
use "$tzn_wave3/Agriculture/AG_SEC_2B.dta", clear
*Calculate field area in hectares
gen field_area = ag2b_20	//GPS measurement
replace field_area = ag2b_15 if ag2b_15==0 | ag2b_15==.			// use farmer's estimate if GPS measurement is 0 or missing 
replace field_area = field_area*0.404686		// convert acres to hectares


*Status of field
merge 1:1 y3_hhid plotnum using "$tzn_wave3/Agriculture/AG_SEC_3B.dta", gen(_merge_plotdetails_SRS) keep(1 3)
*3,287 not matched from master
*1,726 matched
gen field_cultivated = ag3b_03==1 if ag3b_03!=.		// equals one if field was cultivated during SRS

*Gender/age variables
gen personid = ag3b_08_1
merge m:1 y3_hhid personid using "$created_data/tzn3_gender_merge.dta", gen(dm1_merge) keep(1 3)		// Dropping unmatched from using
*4,992 not matched from master
*21 matched
tab dm1_merge field_cultivated		// All unmatched observations are due to field not being cultivated
*First decision-maker variables
gen dm1_female = female
gen dm1_age = age
drop female age personid

*Second owner
gen personid = ag3b_08_2
merge m:1 y3_hhid personid using "$created_data/tzn3_gender_merge.dta", gen(dm2_merge) keep(1 3)		// Dropping unmatched from using
*5,002 not matched from master
*11 matched
gen dm2_female = female
gen dm2_age = age
drop female age personid

*Third
gen personid = ag3b_08_3
merge m:1 y3_hhid personid using "$created_data/tzn3_gender_merge.dta", gen(dm3_merge) keep(1 3)			// Dropping unmatched from using
*5,013 not matched
*0 matched
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
keep y3_hhid plotnum field_area field_area_cultivated decision_maker_gender field_cultivated

gen dm_male = decision_maker_gender==1 if decision_maker_gender!=.
gen dm_female = decision_maker_gender==2 if decision_maker_gender!=.
gen dm_mixed = decision_maker_gender==3 if decision_maker_gender!=.

save "$created_data/tzn3_field_srs.dta", replace






*Now crops
use "$tzn_wave3/Agriculture/AG_SEC_4B.dta", clear
drop if zaocode==.
*Percent of area
gen pure_stand = ag4b_01==1
gen any_pure = pure_stand==1
gen any_mixed = pure_stand==0
gen percent_field = 0.25 if ag4b_02==1
replace percent_field = 0.50 if ag4b_02==2
replace percent_field = 0.75 if ag4b_02==3
replace percent_field = 1 if pure_stand==1


*Total area on field
bys y3_hhid plotnum: egen total_percent_field = total(percent_field)			// Total across all crops on plot
replace percent_field = percent_field/total_percent_field if total_percent_field>1			// Rescaling


*Merging in area from `tzn3_field'
preserve
merge m:1 y3_hhid plotnum using "$created_data/tzn3_field_srs.dta", nogen keep(3)
*0 not matched
*4,248 matched
gen lrs_field = 0
tempfile temp
save `temp', replace
restore

merge m:1 y3_hhid plotnum using "$created_data/tzn3_field.dta", nogen keep(3)
*0 not matched
*3,898 matched
gen lrs_field = 1
append using `temp'

gen crop_area_planted = percent_field*field_area_cultivated

keep crop_area_planted* y3_hhid plotnum zaocode dm_* any_* lrs_field pure_* decision_*
save "$created_data/tzn3_crop_srs.dta", replace




*Now to harvest
use "$tzn_wave3/Agriculture/AG_SEC_4B.dta", clear
drop if zaocode==.			// lots of plots that weren't actually used

gen kg_harvest = ag4b_28 if ag4b_25==1
replace kg_harvest = 0 if ag4b_20==3
drop if kg_harvest==.

keep y3_hhid plotnum zaocode kg_harvest

*Merging area
merge m:1 y3_hhid plotnum zaocode using "$created_data/tzn3_crop_srs.dta", nogen keep(1 3)


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

append using "$created_data/tzn3_lrs.dta"				// appending plot-crop level data from LRS, collapsing everything to the household level below

*Replacing smaller area with zero

bys y3_hhid plotnum zaocode (crop_area_planted): replace crop_area_planted = 0 if _n==1 & crop_area_planted[1]<=crop_area_planted[2] & crop_area_planted[2]!=.

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


save "$created_data/tzn3_field_crop_level.dta", replace


*Collapsing to household level
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(y3_hhid zaocode)		// collapsing by hhid-crop (zaocode)
*If the count_ variables are equal to zero after collapse, that means NO plot in the household meets the criteria for that count (since count=0 means no 1's at all within household)


*Merging weights and survey variables
merge m:1 y3_hhid using "$created_data/tzn3_weights_merge.dta", nogen keep(1 3)



*Merging Gender of head
merge m:1 y3_hhid using "$created_data/tzn3_gender_head.dta", nogen keep(1 3)



save "$created_data/tzn3_cleaned.dta", replace








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
*if "`crop_name'"=="finger"{				// Not enough for any of the subsamples; we can still do main estimation if interested in these crops
*	local crop 15	//Finger Millet
*}
*if "`crop_name'"=="wheat"{
*	local crop 16	//Wheat
*}
*if "`crop_name'"=="barley"{			// Not enough observations 
*	local crop 17	//Barley
*}

use "$created_data/tzn3_cleaned.dta", clear
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



*Generating estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w3_all_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	modelwidth(6 2 6 6 6 2 6 6) varwidth(25) note("The decision-maker variable is constructed using the answers to the question Who decided what to plant on this plot in the long rainy season 2008? The decision-maker is coded as male only if all listed decision-makers are male. The variable is coded as female only if all listed decision-makers are female. The variable is otherwise coded as mixed. Winsorized values are replaced at the 99th percentile; any larger values are replaced with the 99th percentile. MAD values are constructed by replacing all values more than two standard deviations above the median with the median. In the top panel statistics include both the long and short rainy seasons, with output aggregated over both seasons but only the largest area planted used as area. In other words, if a household plants one hectare of maize in the long rainy season but two hectares of maize in the short rainy season, two hectares is used as the area for construction of total yield. In the bottom panel, only the long rainy season is included. The decision-maker variables are defined at the plot level but the stand variables are defined as the crop level. As such, some households are represented multiple times across variables. For example, some households have plots under both male-decision makers and female decision-makers, while some other households also have both mixed and pure stand plots. Area weights are used, which are constructed by multiplying the household weight by the area planted. These weights are constructed separately for each subsample.")
	;
#delimit cr





*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w3_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD")
	;
#delimit cr




************************************
////// Generate Yield Estimates - LRS only
************************************


use "$created_data/tzn3_lrs.dta", clear


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
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(y3_hhid zaocode)				// hhid/crop level



*Merging weights and survey variables
merge m:1 y3_hhid using "$created_data/tzn3_weights_merge.dta", nogen keep(1 3)

*Merging Gender of head
merge m:1 y3_hhid using "$created_data/tzn3_gender_head.dta", nogen keep(1 3)								// 1 not matched from master
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



*Generating estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w3_LRS_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	;
#delimit cr




*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w3_LRS_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	;
#delimit cr




********************************************************
* Using LRS area for all plots that are in LRS and SRS *
********************************************************
*Only changes are in SRS code


*Now to harvest
use "$tzn_wave3/Agriculture/AG_SEC_4B.dta", clear
drop if zaocode==.			// lots of plots that weren't actually used

gen kg_harvest = ag4b_28 if ag4b_25==1
replace kg_harvest = 0 if ag4b_20==3
drop if kg_harvest==.

keep y3_hhid plotnum zaocode kg_harvest

*Merging area
merge m:1 y3_hhid plotnum zaocode using "$created_data/tzn3_crop_srs.dta", nogen keep(1 3)


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

append using "$created_data/tzn3_lrs.dta", gen(lrs)				// appending plot-crop level data from LRS, collapsing everything to the household level below

*Replacing smaller area with zero
bys y3_hhid plotnum zaocode (lrs): replace crop_area_planted=0 if lrs[1]==0 & lrs[2]==1 & _n==1 & crop_area_planted[2]!=0 & crop_area_planted[2]!=.	// replacing crop_area for first obs (srs) if first obs lrs==0 and second obs lrs==1 (but only if crop area from lrs is not zero or missing)

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


save "$created_data/tzn3_field_crop_level_lrsarea.dta", replace


*Collapsing to household level
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(y3_hhid zaocode)		// collapsing by hhid-crop (zaocode)
*If the count_ variables are equal to zero after collapse, that means NO plot in the household meets the criteria for that count (since count=0 means no 1's at all within household)


*Merging weights and survey variables
merge m:1 y3_hhid using "$created_data/tzn3_weights_merge.dta", nogen keep(1 3)



*Merging Gender of head
merge m:1 y3_hhid using "$created_data/tzn3_gender_head.dta", nogen keep(1 3)



save "$created_data/tzn3_cleaned_lrsarea.dta", replace













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

use "$created_data/tzn3_cleaned_lrsarea.dta", clear
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



*Generating estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w3_LRSarea_all_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	modelwidth(6 2 6 6 6 2 6 6) varwidth(25) note("The decision-maker variable is constructed using the answers to the question Who decided what to plant on this plot in the long rainy season 2008? The decision-maker is coded as male only if all listed decision-makers are male. The variable is coded as female only if all listed decision-makers are female. The variable is otherwise coded as mixed. Winsorized values are replaced at the 99th percentile; any larger values are replaced with the 99th percentile. MAD values are constructed by replacing all values more than two standard deviations above the median with the median. In the top panel statistics include both the long and short rainy seasons, with output aggregated over both seasons but only the largest area planted used as area. In other words, if a household plants one hectare of maize in the long rainy season but two hectares of maize in the short rainy season, two hectares is used as the area for construction of total yield. In the bottom panel, only the long rainy season is included. The decision-maker variables are defined at the plot level but the stand variables are defined as the crop level. As such, some households are represented multiple times across variables. For example, some households have plots under both male-decision makers and female decision-makers, while some other households also have both mixed and pure stand plots. Area weights are used, which are constructed by multiplying the household weight by the area planted. These weights are constructed separately for each subsample.")
	;
#delimit cr





*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

if !inlist(zaocode,15){
replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]
}

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

if !inlist(zaocode,16){
replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*y3_weight
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]
}

drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/tzn_w3_LRSarea_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD")
	;
#delimit cr
}

