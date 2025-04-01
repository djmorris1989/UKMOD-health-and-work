*** ------------------------------------------------------------------------- 
*** README
***
*** The purpose of this do-file is to process the raw Family Resources Survey
*** data for 2021/22 in order to merge to the FRS-based UKMOD output data from
*** models in UKMOD run using the uk_2021_a1 input data
***
*** store the individual stata files for the 2021/22 data together in one 
*** unique folder. set the global "data" below to the filepath for that folder.
*** also set filepaths to the locations where temporary data and outputs will be
*** saved, and to the UKMOD model folder.
***
*** ------------------------------------------------------------------------

*************************************************************************
**** 0. PREAMBLE

* set working directory
cd "C:\Users\cm1djm\Documents\UKMOD methods"

* set file paths
global data "input\Family Resources Survey\2021-22\"
global temp "input\"
global output "output\"
global ukmod "UKMOD\UKMOD-PUBLIC-B2025.03\"

*************************************************************************
**** 1. read in the adult data and job data files. Merge together and
**** retain the variables needed

* clean the job data file first. There is one observation per individual-job 
* in this file but we want one observation per person. For those with more than
* one job (very few people) use the first job only as this will be the longest 
* employment spell.

use "${data}job.dta", clear
keep if JOBTYPE == 1

save "${temp}temp_job.dta", replace

* read in the adult data
use "${data}adult.dta", clear

* select the variables needed
global keeplist "SERNUM BENUNIT PERSON DISD01 DISD02 DISD03 DISD04 DISD05 DISD06 DISD07 DISD08 DISD09 DISD10 MONTH"

keep $keeplist

* generate a year variable
gen YEAR = . 
replace YEAR = 2021 if MONTH > 3
replace YEAR = 2022 if MONTH <= 3

* generate dummy variables for health conditions
gen health1_sight     = (DISD01 == 1)
gen health2_hearing   = (DISD02 == 1)
gen health3_mobility  = (DISD03 == 1)
gen health4_dexterity = (DISD04 == 1)
gen health5_learning  = (DISD05 == 1)
gen health6_memory    = (DISD06 == 1)
gen health7_mentalhlt = (DISD07 == 1)
gen health8_stamina   = (DISD08 == 1)
gen health9_behaviour = (DISD09 == 1)
gen health10_other    = (DISD10 == 1)

drop DISD*

* merge in the job data file, retaining the variables needed
merge 1:1 SERNUM BENUNIT PERSON using "${temp}temp_job.dta", keepusing(WRKPREV WORKMTH WORKYR)
erase "${temp}temp_job.dta"

* You should find that the _merge variable has values 1 (adult data only) or 3 (matched).
* There shouldn't be any 2s (job data only)

*   Matching result from |
*                  merge |      Freq.     Percent        Cum.
*------------------------+-----------------------------------
*        Master only (1) |     12,010       43.66       43.66
*            Matched (3) |     15,498       56.34      100.00
*------------------------+-----------------------------------
*                  Total |     27,508      100.00

drop _merge 

* generate the identifer variables from SERNUM, BENUNIT, and PERSON as they are
* named in the UKMOD data. These three together uniquely identify individuals in the data
* - SERNUM: Household identifier
* - BENUNIT: Benefit unit identifier
* - PERSON: Person identifier within the benefit unit

rename *, lower

gen idorigperson = person
gen idorighh = sernum
gen idorigbenunit = benunit

***************************************************************************
**** 2. Clean variables 

** generate activity before current job (note a lot of missing)
replace wrkprev = . if wrkprev < 0

** generate time in current job 
gen time = ym(year, month)
gen strt = ym(workyr, workmth)

gen time_in_job = (time - strt) + 1
replace time_in_job = . if time_in_job < 0 /* 1 observation is negative */
label var time_in_job "Months in current employment"

drop year month workyr workmth time strt

save "${temp}frs_cleaned_21_22.dta", replace

***************************************************************************
**** 3. read in the UKMOD outputs and merge in the raw FRS data 

import delimited "${ukmod}Output\uk_2024_std.txt", clear

keep idorigperson idorighh idorigbenunit les ils_origy ils_ben ils_tax ils_sicdy ils_sicer ils_earns ils_dispy

merge 1:1 idorigperson idorighh idorigbenunit using "${temp}frs_cleaned_21_22.dta"

** you will get some unmerged observations again, this time from the UKMOD dataset.
** the UKMOD dataset includes the child (<16) data. The number of matched 
** observations is the same number as in the adult dataset (27,508).

* Result                      Number of obs
*    -----------------------------------------
*    Not matched                         7,082
*        from master                     7,082  (_merge==1)
*        from using                          0  (_merge==2)
*
*    Matched                            27,508  (_merge==3)
*    -----------------------------------------

keep if _merge == 3
drop _merge

*** for more details of UKMOD income variables, see country report section 6.3

*** market income includes earnings (ils_earn) plus investment income, propoerty income,
*** personal pension income, net maintenance paymnts, private transfers, and income from odd jobs

label variable idorighh "Household identifier"
label variable idorigbenunit "Benefit unit identifier"
label variable idorigperson "Person identifier"
label variable les "Labour market status"
label variable ils_origy "Original/Market income"
label variable ils_ben "All benefits = ils_pen + ils_benmt + ils_bennt"
label variable ils_tax "Direct taxes"
label variable ils_earns "Income from employment and self-employment"
label variable ils_sicdy "All employee/self-employed national insurance contributions"
label variable ils_sicer "Employer national insurance contributions"
label variable ils_dispy "Disposable income = ils_origy + ils_ben - ils_tax - ils_sicdy"
label variable wrkprev "Status before current job"
label variable time_in_job "Months worked in current job"
label variable health1_sight "Health problems: sight"
label variable health2_hearing "Health problems: hearing"
label variable health3_mobility "Health problems: mobility"
label variable health4_dexterity "Health problems: dexterity"
label variable health5_learning "Health problems: learning difficulties"
label variable health6_memory "Health problems: memory"
label variable health7_mentalhlt "Health problems: mental health"
label variable health8_stamina "Health problems: stamina"
label variable health9_behaviour "Health problems: behavioural/social"
label variable health10_other "Health problems: other"

label define empstat 0 "pre-school/under 5" 2 "employer/self-employed" 3 "employed" 4 "pensioner" 5 "unemployed" 6 "student" 7 "inactive" 8 "sick/disabled" 9 "family worker", modify
label values les empstat

drop sernum benunit person

save "${output}ukmod_output_2021.dta", replace


