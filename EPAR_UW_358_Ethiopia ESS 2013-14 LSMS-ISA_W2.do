
/*-----------------------------------------------------------------------------------------------------------------------------------------------------
*Title/Purpose 	: This do.file was developed by the Evans School Policy Analysis & Research Group (EPAR) 
				  for the comparison of crop yield estimates using different construction decisions
				  using the Ethiopia Socioeconomic Survey (ESS) LSMS-ISA Wave 2 (2013-14)
*Author(s)		: Pierre Biscaye, Karen Chen, David Coomes, & Josh Merfeld

*Date			: 30 September 2017

----------------------------------------------------------------------------------------------------------------------------------------------------*/

*Data source
*-----------
*The Ethiopia Socioeconomic Survey was collected by the Ethiopia Central Statistical Agency (CSA) 
*and the World Bank's Living Standards Measurement Study - Integrated Surveys on Agriculture(LSMS - ISA)
*The data were collected over the period September to October 2013, November to December 2013, and February to April 2014. 
*All the raw data, questionnaires, and basic information documents are available for downloading free of charge at the following link
*http://microdata.worldbank.org/index.php/catalog/2247

*Throughout the do-file, we sometimes use the shorthand LSMS to refer to the Ethiopia Socioeconomic Survey.

*Summary of Executing the Master do.file
*-----------
*This Master do.file constructs selected indicators using the Ethiopia ESS (ETH LSMS) data set.
*First save the raw unzipped data files from the World Bank in a new "Raw data" folder. Do not change the structure or organization of the unzipped raw data files.
*The do. file constructs needed intermediate variables, saving dta files when appropriate in a "created data" folder that you will need to create.

*The code first generates the variables needed to calculate yields, then proceeds to generate a series of yield estimates by crop using different construction descisions.
*Summary statistics and output are saved in an "output" folder which you will also need to create.
*Note: The ESS survey does not ask respondents to separately report on agricultural production by season, unlike the TNPS.
 
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
global et_wave2 "desired filepath/raw data folder name"
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
*We need region variables for weights; for the time being, I will construct these identically to Pierre's construction in the land reform do-file
use "$et_wave2/Household/sect_cover_hh_w2.dta", clear
gen clusterid = ea_id2
gen strataid=saq01 if rural==1 //assign region as strataid to rural respondents; regions from from 1 to 7 and then 12 to 15
gen stratum_id=.
replace stratum_id=16 if rural==2 & saq01==1 //Tigray, small town
replace stratum_id=17 if rural==2 & saq01==3 //Amhara, small town
replace stratum_id=18 if rural==2 & saq01==4 //Oromiya, small town
replace stratum_id=19 if rural==2 & saq01==7 //SNNP, small town
replace stratum_id=20 if rural==2 & (saq01==2 | saq01==5 | saq01==6 | saq01==12 | saq01==13 | saq01==15) //Other regions, small town
replace stratum_id=21 if rural==3 & saq01==1 //Tigray, large town
replace stratum_id=22 if rural==3 & saq01==3 //Amhara, large town
replace stratum_id=23 if rural==3 & saq01==4 //Oromiya, large town
replace stratum_id=24 if rural==3 & saq01==7 //SNNP, large town
replace stratum_id=25 if rural==3 & saq01==14 //Addis Ababa, large town
replace stratum_id=26 if rural==3 & (saq01==2 | saq01==5 | saq01==6 | saq01==12 | saq01==13 | saq01==15) //Other regions, large town

replace strataid=stratum_id if rural!=1 //assign new strata IDs to urban respondents, stratified by region and small or large towns

keep clusterid strataid household_id2 pw2
save "$created_data/et2_weights_merge.dta", replace




*We also want gender variables
use "$et_wave2/Household/sect1_hh_w2.dta", clear
ren hh_s1q00 personid								// personid is the roster number, combination of household_id2 and personid are unique id for this wave
gen female =hh_s1q03==2
gen age = hh_s1q04_a
replace age = hh_s1q04h if hh_s1q04h!=.
gen head = hh_s1q02==1 if hh_s1q02!=.
keep personid female age household_id2 head
save "$created_data/et2_gender_merge.dta", replace


*Collapsing for gender of head
gen male_head = female==0 & head==1
collapse (max) male_head, by(household_id2)
save "$created_data/et2_gender_head.dta", replace






*First starting with field sizes
use "$et_wave2/Post-Planting/sect3_pp_w2.dta", clear
*First creating variable with sq meters
gen field_area = pp_s3q02_a*10000 if pp_s3q02_c==1			// hectares to sq m
replace field_area = pp_s3q02_a if pp_s3q02_c==2			// already in sq m

*For rest of units, we need to use the conversion factors; renaming variables to merge conversion data
gen region = saq01
gen zone = saq02
gen woreda = saq03
gen local_unit = pp_s3q02_c
merge m:1 region zone woreda local_unit using "$et_wave2/Geodata/ET_local_area_unit_conversion.dta", gen(conversion_merge) keep(1 3)	// 57 not matched from using, dropping these
*17,942 not matched from master
*15,205 matched
replace field_area = pp_s3q02_a*conversion if !inlist(pp_s3q02_c,1,2) & pp_s3q02_c!=.			// non-traditional units (all "other" crops are missing conversion, so no problem with this code)

*Field area is currently farmer reported. Let's replace with GPS area when available
replace field_area = pp_s3q05_a if pp_s3q05_a!=. & pp_s3q05_a!=0			// 30,635 changes -- available for almost all plots
replace field_area = field_area*0.0001						// Changing back into hectares

gen field_cultivated = pp_s3q03==1 if pp_s3q03!=.			// equals one if field was cultivated this season

*Gender/age variables
gen personid = pp_s3q10a
merge m:1 household_id2 personid using "$created_data/et2_gender_merge.dta", gen(dm1_merge) keep(1 3)			// Dropping unmatched from using
*10,277 not matched from master
*22,870 matched
tab dm1_merge field_cultivated		// Almost all unmatched observations (>98%) are due to field not being cultivated
*First decision-maker variables
gen dm1_female = female
gen dm1_age = age
drop female age personid

*Second owner
gen personid = pp_s3q10c_a
merge m:1 household_id2 personid using "$created_data/et2_gender_merge.dta", gen(dm2_merge) keep(1 3)			// Dropping unmatched from using
*17,895 not matched from master		//Not matched mostly due to missing decision-maker variable
*15,252 matched
gen dm2_female = female
gen dm2_age = age
drop female age personid

*Third
gen personid = pp_s3q10c_b
merge m:1 household_id2 personid using "$created_data/et2_gender_merge.dta", gen(dm3_merge) keep(1 3)			// Dropping unmatched from using
*30,367 not matched from master
*2,780 matched
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
keep household_id2 holder_id parcel_id field_id field_area field_area_cultivated decision_maker_gender field_cultivated

gen dm_male = decision_maker_gender==1
gen dm_female = decision_maker_gender==2
gen dm_mixed = decision_maker_gender==3

isid holder_id parcel_id field_id		// check
save "$created_data/et2_field.dta", replace







*Now crops
use "$et_wave2/Post-Planting/sect4_pp_w2.dta", clear
*Percent of area
gen pure_stand = pp_s4q02==1
gen any_pure = pure_stand
gen any_mixed = !pure_stand
gen percent_field = pp_s4q03/100
replace percent_field = 1 if pure_stand==1

*Total area on field
bys holder_id parcel_id field_id: egen total_percent_field = total(percent_field)
replace percent_field = percent_field/total_percent_field if total_percent_field>1		// only 254 changes


*Merging in area from et2_field
merge m:1 holder_id parcel_id field_id using "$created_data/et2_field.dta", nogen keep(1 3)	// dropping those only in using
*60 not matched from master (across all crops)
*29,775 matched

gen crop_area_planted = percent_field*field_area_cultivated
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

keep crop_area_planted* holder_id parcel_id field_id household_id2 crop_code dm_* any_*
save "$created_data/et2_crop.dta", replace








*Before harvest, need to prepare the conversion factors
use "$et_wave2/Geodata/Crop_CF_Wave2.dta", clear
*I am going to reshape to crop/unit/region level
ren mean_cf_nat mean_cf100
sort crop_code unit_cd mean_cf100
duplicates drop crop_code unit_cd, force				// most of these will not matter for us (since we are interested in cereals only for now)

reshape long mean_cf, i(crop_code unit_cd) j(region)	// reshaping to crop/region/unit level
recode region (99=5)
ren mean_cf conversion
save "$created_data/et2_cf.dta", replace




*FOOD conversion factors
use "$et_wave2/Geodata/Food_CF_Wave2.dta", clear
ren mean_cf_nat mean_cf100
sort item_cd unit_cd mean_cf100

reshape long mean_cf, i(item_cd unit_cd) j(region)	// reshaping to crop/region/unit level
collapse (median) mean_cf, by(region unit_cd)
tab unit_cd, sum(mean_cf)
******



*Now to harvest
use "$et_wave2/Post-Harvest/sect9_ph_w2.dta", clear
ren saq01 region
ren ph_s9q04_b unit_cd		// for merge
merge m:1 crop_code unit_cd region using "$created_data/et2_cf.dta", gen(cf_merge) keep(1 3)
*11,577 not matched from master
*17,998 matched
bys crop_code unit_cd: egen national_conv = median(conversion)
replace conversion = national_conv if conversion==.			// replacing with national median if missing -- 1,368

*There is some variation in conversion across crops, but they seem to correlate well enough to use units
bys unit_cd region: egen national_conv_unit = median(conversion)
replace conversion = national_conv_unit if conversion==. & unit_cd!=14		// Not for "other" ones -- 932

tab unit_cd			// 16.53 percent of field-crop observations are reported with "other" units
*IMPORTANT: We are going to use the food conversion factors for the more common "other" units
*Replacing with overall medians taken from FOOD conversion factors above, as there are still many missings
tab ph_s9q04_b_other
gen conversion_food = conversion
replace conversion = 65 if inlist(ph_s9q04_b_other,"MADABERIYA","LUQA (MADABERIYA)","MADABERIYA SHER","TELEQU MADABERIYA","TENESHU MADABERIYA","SHERA")
replace conversion = .36 if ph_s9q04_b_other=="AKARA"
replace conversion = 16.2 if ph_s9q04_b_other=="AMBAZA"
replace conversion = .203 if ph_s9q04_b_other=="BERECHEKO"
replace conversion = 17.5 if ph_s9q04_b_other=="BUNCHES"
replace conversion = .792 if ph_s9q04_b_other=="CBC   TASA"
replace conversion = 3.158 if ph_s9q04_b_other=="FESTAL"
replace conversion = 8.793 if ph_s9q04_b_other=="JERIKAN"
replace conversion = 65.92 if ph_s9q04_b_other=="JONIYA" | ph_s9q04_b_other=="KESHA"
replace conversion = 1.021 if ph_s9q04_b_other=="JOG"
replace conversion = 1 if ph_s9q04_b_other=="KILLO GRAM"
replace conversion = 0.35 if ph_s9q04_b_other=="KUBAYA"
replace conversion = 1.37 if inlist(ph_s9q04_b_other,"SAHIN","SAHIN/EKIF","SAHENE","SEHAN")
replace conversion = .792 if inlist(ph_s9q04_b_other,"TASA","TANIKA","SHEMBER","SELEMON")
replace conversion = 10.4 if ph_s9q04_b_other=="ZENBILE"
replace conversion = .27 if ph_s9q04_b_other=="ZOREBA" | ph_s9q04_b_other=="ZEREBA"
gen nonstandard_conversion = conversion_food==. & conversion!=.		// indicator that observation is one of the above conversions added manually - JDM: Good addition!
drop conversion_food

gen kg_harvest = ph_s9q04_a*conversion
drop if kg_harvest==.							// dropping those with missing kg
tab nonstandard_conversion, sum(kg_harvest)		// slightly lower for those with nonstandard conversions, but this is not necessarily surprising


keep crop_code holder_id parcel_id field_id kg_harvest nonstandard_conversion
*Merging area
merge m:1 holder_id parcel_id field_id crop_code using "$created_data/et2_crop.dta", nogen keep(1 3)			// 10 not matched across all crops

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

save "$created_data/et2_field_level.dta", replace


*Collapsing to household level
collapse (sum) kg_harvest* crop_area_planted* count_* (max) dm_*  any_*, by(household_id2 crop_code)		// collapsing by hhid-crop (zaocode)


*Merging weights and survey variables
merge m:1 household_id2 using "$created_data/et2_weights_merge.dta", nogen keep(1 3)							// 7 not matched from master (across all crops)

*Merging Gender of head
merge m:1 household_id using "$created_data/et2_gender_head.dta", nogen keep(1 3)								// 7 not matched from master (across all crops)

save "$created_data/et2_cleaned.dta", replace











************************************
////// Generate Yield Estimates
************************************




*Now the analysis
foreach crop_name in maize barley millet sorghum teff wheat{

if "`crop_name'"=="barley"{
	local crop 1
}
if "`crop_name'"=="maize"{
	local crop 2
}
if "`crop_name'"=="millet"{
	local crop 3
}
if "`crop_name'"=="sorghum"{
	local crop 6
}
if "`crop_name'"=="teff"{
	local crop 7
}
if "`crop_name'"=="wheat"{
	local crop 8
}
use "$created_data/et2_cleaned.dta", clear
keep if inlist(crop_code,`crop')

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

winsor2 crop_area*, cuts(1 99) replace

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
	*replace `i'_MAD = r(p50) if `i'<r(p50)-2*r(sd) & `i'!=.		// we shouldn't do MAD 
}

*Now winsorizing top 1 percent
winsor2 kg_hectare*, replace cuts(0 99)


*Generating estimates
gen kg_temp = kg_hectare
gen kg_MAD_temp = kg_hectare_MAD
gen weight_temp = crop_area_planted*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_dm
replace kg_MAD_temp = kg_hectare_male_dm_MAD
replace weight_temp = crop_area_planted_male_dm*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_dm
replace kg_MAD_temp = kg_hectare_female_dm_MAD
replace weight_temp = crop_area_planted_female_dm*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_dm
replace kg_MAD_temp = kg_hectare_mixed_dm_MAD
replace weight_temp = crop_area_planted_mixed_dm*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_purestand
replace kg_MAD_temp = kg_hectare_purestand_MAD
replace weight_temp = crop_area_planted_purestand*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixedstand
replace kg_MAD_temp = kg_hectare_mixedstand_MAD
replace weight_temp = crop_area_planted_mixedstand*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

drop kg_temp kg_MAD_temp weight_temp


#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/et_w2_all_`crop_name'.rtf", cells(b(fmt(0 0)) se(fmt(0 0) par)) stats(subpop_N, label("Households")) replace
	mlabels("All" "Male" "Female" "Mixed" "Pure" "Mixed") mgroups("" "Gender of Decision-Maker" "Type of Stand", pattern(1 1 0 0 1 0))
	coeflabels(harv_temp "Harvest (kg)" area_temp "Area planted (ha)" kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD") extracols(2 5)
	modelwidth(6 2 6 6 6 2 6 6) varwidth(25) note("The decision-maker variable is constructed using the answers to the question Who in the household makes primary decisions concerning crops to be planted, input use, and the timing of cropping activities on this field? The decision-maker is coded as male only if all listed decision-makers are male. The variable is coded as female only if all listed decision-makers are male. The variable is otherwise coded as mixed. Winsorized values are replaced at the 99th percentile; any larger values are replaced with the 99th percentile. MAD values are constructed by replacing all values more than two standard deviations above the median with the median. The decision-maker variables are defined at the field level but the stand variables are defined as the crop level. As such, some households are represented multiple times across variables. For example, some households have plots under both male-decision makers and female decision-makers, while some other households also have both mixed and pure stand plots.")
	;
#delimit cr








*Now breaking down by pure/mixed and gender
gen kg_temp = kg_hectare_male_pure
gen kg_MAD_temp = kg_hectare_male_pure_MAD
gen weight_temp = crop_area_planted_male_pure*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv1: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_female_pure
replace kg_MAD_temp = kg_hectare_female_pure_MAD
replace weight_temp = crop_area_planted_female_pure*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv2: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_mixed_pure
replace kg_MAD_temp = kg_hectare_mixed_pure_MAD
replace weight_temp = crop_area_planted_mixed_pure*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv3: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

replace kg_temp = kg_hectare_male_mixed
replace kg_MAD_temp = kg_hectare_male_mixed_MAD
replace weight_temp = crop_area_planted_male_mixed*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv4: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]

if !inlist(crop_code,3,7,8){
replace kg_temp = kg_hectare_female_mixed
replace kg_MAD_temp = kg_hectare_female_mixed_MAD
replace weight_temp = crop_area_planted_female_mixed*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv5: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]
}

replace kg_temp = kg_hectare_mixed_mixed
replace kg_MAD_temp = kg_hectare_mixed_mixed_MAD
replace weight_temp = crop_area_planted_mixed_mixed*pw2
svyset clusterid [pweight=weight_temp], strata(strataid) singleunit(centered)
eststo harv6: svy: mean kg_temp kg_MAD_temp
matrix N = e(_N)
estadd scalar subpop_N = N[1,1]


drop kg_temp kg_MAD_temp weight_temp

#delimit ;
	esttab harv1 harv2 harv3 harv4 harv5 harv6 using "$output/et_w2_gender_`crop_name'.rtf", cells(b(fmt(0)) se(fmt(0) par)) stats(subpop_N, label("Households")) replace
	mlabels("Male-Pure" "Female-Pure" "Mixed-Pure" "Male-Mixed" "Female-Mixed" "Mixed-Mixed") coeflabels(kg_temp "Yield (kg/ha) - Winsorized" kg_MAD_temp "Yield (kg/ha) - MAD")
	;
#delimit cr






*Now by number of plots
preserve
collapse (sum) count_*
eststo harv1: mean count_*
#delimit ;
	esttab harv1 using "$output/et_w2_plots_all_`crop_name'.rtf", cells(b(fmt(3)) se(fmt(3) par)) stats(subpop_N, label("Households")) replace
	coeflabels(count_plot "Plots" count_male_dm "Plots - Male" count_female_dm "Plots - Female" count_mixed_dm "Plots - Mixed Gender" count_purestand "Plots - Purestand"
	count_mixedstand "Plots - Mixed stand" count_male_pure "Plots - Male Pure" count_female_pure "Plots - Female Pure" count_mixed_pure "Plots - Mixed Gender Pure"
	count_male_mixed "Plots - Male Mixed" count_female_mixed "Plots - Female Mixed" count_mixed_mixed "Plots - Mixed Gender Mixed")
	;
#delimit cr
restore






gen crop_weight_int = round(crop_area_planted*pw2)

graph drop _all
hist kg_hectare [fweight=crop_weight_int], xtitle("yield - kg/ha") title("All") graphregion(color(white)) percent name(g1) legend(off)
hist kg_hectare_purestand [fweight=crop_weight_int], xtitle("yield - kg/ha") title("Pure Stand") graphregion(color(white)) percent name(g2) legend(off)
hist kg_hectare_mixedstand [fweight=crop_weight_int], xtitle("yield - kg/ha") title("Mixed Stand") graphregion(color(white)) percent name(g3) legend(off)
graph combine g2 g3 g1, graphregion(color(white)) ycommon
graph export "$output/et_w2_hist_`crop_name'.pdf", replace
}





















