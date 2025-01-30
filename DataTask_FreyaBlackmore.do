
* Freya Blackmore
* January 2nd, 2024



* set the working directory to a relative path
* File -> Change Working Directory -> Choose 


* ----------- Uploading Data Sets ----------------

clear
* Import the bond .csv files
import delimited "input/Bonds_Q1_2020.csv", clear
save "dtas/bond1.dta", replace
import delimited "input/Bonds_Q2_2020.csv", clear
save "dtas/bond2.dta", replace
import delimited "input/Bonds_Q3_2020.csv", clear
save "dtas/bond3.dta", replace

* Import the criminal history .csv files
import delimited "input/Criminal_History_Q1_2020.csv", clear
save "dtas/criminal_history1.dta", replace
import delimited "input/Criminal_History_Q2_2020.csv", clear
save "dtas/criminal_history2.dta", replace
import delimited "input/Criminal_History_Q3_2020.csv", clear
save "dtas/criminal_history3.dta", replace

* --------------- Normalizing/cleaning data discrepancies ---------------
* bond2 holds data in 6 columns, 3 for BOND MADE and 3 for BOND SET
* bond1 and bond3 hold the same data in 3 columns, managing both BOND MADE and BOND SET
* the following standardizes the data to three columns 
* Release_Type, Bond_Amount, pretrial_release_date (to be used for determining NCAs) 


* acorrecting column disparities 
use "dtas/bond2.dta", clear
format case_no %15.0f // standardizing case_no format
gen Release_Type = bond_activity_description1  // CASH/SURETY or ROR
gen Bond_Amount = bond_activity_description2  // extract bond amount
gen pretrial_release_date = bond_activity_date1 // day individual made bond
drop bond_activity1 bond_activity_description1 bond_activity2 bond_activity_description2 bond_activity_date1 bond_activity_date2 // drop recategorized bond columns
drop case_cause_status offense casecompletiondate hearingcourt eyes uscitizen height_weight hair placeofbirth judgename // drop extraneous info
save "dtas/clean_bond2.dta", replace


use "dtas/bond1.dta", clear
destring case_no, replace force
format case_no %15.0f  // standardizing case_no format
gen Bond_Amount = bond_activity_description if bond_activity == "BOND SET" // separating out bond amounts from release types
gen Release_Type = bond_activity_description if bond_activity == "BOND MADE" // ^^
gen pretrial_release_date = bond_activity_date if bond_activity == "BOND MADE" // recording day individual made bond
drop bond_activity bond_activity_description
collapse (firstnm) spn filedate race_sex dob court broad_offense_type disposition_date Bond_Amount Release_Type pretrial_release_date, by(case_no)
save "dtas/clean_bond1.dta", replace


use "dtas/bond3.dta", clear
format case_no  %15.0f  // standardizing case_no format
gen Bond_Amount = bond_activity_description if bond_activity == "BOND SET" // separating out bond amounts from release types
gen Release_Type = bond_activity_description if bond_activity == "BOND MADE" // ^^
gen pretrial_release_date = bond_activity_date if bond_activity == "BOND MADE" // recording day individual made bond
drop bond_activity bond_activity_description
collapse (firstnm) spn filedate race_sex dob court broad_offense_type disposition_date Bond_Amount Release_Type pretrial_release_date, by(case_no)
save "dtas/clean_bond3.dta", replace

* merging separate bond data sets into one master set
use "dtas/clean_bond1.dta", clear
append using "dtas/clean_bond2.dta" "dtas/clean_bond3.dta"
save "dtas/combined_bond.dta", replace


* ------------ PART 1: Creating Complete Data Table --------------- 
* the following creates all requested columns for the final data set

use "dtas/combined_bond.dta", clear

* 1. correcting naming conventions
rename case_no Case_No
rename spn SPN
rename court Court
rename broad_offense_type Offense_Type


* 2. Creating Defendant_Race and Defendant_Sex columns
// separating race_sex values by "/" into individual columns
split race_sex, p(" / ") generate(Defendant_) 
rename Defendant_1 Defendant_Race
rename Defendant_2 Defendant_Sex
drop race_sex


* 3. creating Defendant_Age column
// using dob to determine age 
// today - dob = age
gen dob_date = date(dob, "MDY")
format dob_date %td
gen Defendant_Age = floor((today() - dob_date) / 365.25)
drop dob dob_date


* 4. creating Pretrial_Release column
// ASSUMPTION: no ROR or cash/surety payment means the defendant was NOT released pretrial
gen Pretrial_Release = cond(missing(Release_Type), "No", "Yes")


* 5. creating New_Criminal_Activity column
gen New_Criminal_Activity = "No"

* normalizing date formats across columns
gen Filing_Date = date(filedate, "MDY")
gen Pretrial_Release_Date = date(pretrial_release_date, "MDY")
gen Disposition_Date = date(disposition_date, "DMY")
format Filing_Date %td
format Pretrial_Release_Date %td
format Disposition_Date %td
drop disposition_date filedate pretrial_release_date

* marking each case where another case committed by that defendant occurs between the release and disposition of the defendant in the original case
* next filing date > original release date AND next filing date < original disposition date
* the case from which a defendant was released and then commits a NCA are marked with "Pretrial NCA"
sort SPN Filing_Date
bysort SPN (Filing_Date): replace New_Criminal_Activity = "Pretrial NCA" if Pretrial_Release == "Yes" & Filing_Date != Filing_Date[_n+1] & Filing_Date[_n+1] > Pretrial_Release_Date & Filing_Date[_n+1] <= Disposition_Date
* missing values in stata are interpretted as incredibly large numeric values. therefore, the filedate will always be less than a missing disposition date
* this allows the logic to hold, as a missing date represents an ongoing trial, in which a new file date will always fall before the disposition
save "dtas/combined_bond.dta", replace


* 6. creating Prior_Charges column

use "dtas/criminal_history1.dta", clear
append using "dtas/criminal_history2.dta" "dtas/criminal_history2.dta"
save "dtas/combined_criminal_history.dta", replace

* ASSUMPTION: each individual case_no associated with an SPN is a prior charge
use "dtas/combined_criminal_history.dta", clear
duplicates drop case_no, force // dropping cases that are repeated
drop if regexm(history_disposition, "^Dismissed") // dropping cases that were dismissed
rename spn SPN
bysort SPN: egen Prior_Charges_Count = count(SPN) // counting the occurences of each SPN identifier 
drop case_no history_case_cause_nbr_status history_file_date_book_date history_disposition history_bondamt history_offense history_nextsetting disposition_date history_broad_offense_type // dropping extraneous information
collapse (count) Prior_Charges_Count, by(SPN) // two columns, SPN identifier and count of associated cases
save "dtas/combined_criminal_history.dta", replace

* merging the count of associated cases onto the final dataset by SPN 
use "dtas/combined_bond.dta", clear
merge m:m SPN using "dtas/combined_criminal_history.dta"
rename Prior_Charges_Count Prior_Charges
replace Prior_Charges = 0 if missing(Prior_Charges) // ASSUMPTION: if empty, assume no prior charges
drop _merge Pretrial_Release_Date


* 7. Cleaning Data: Removing entries missing crucial identification information
drop if missing(Case_No) | missing(Defendant_Race) | missing(Defendant_Sex)
save "dtas/combined_bond.dta", replace
save "output/Final_Cleaned_Dataset.dta", replace




* ------------ PART 2: Two Panel Figure -----------------
use "dtas/combined_bond.dta", clear

* ASSUMPTIONS: assumptions made regarding the meaning of the race labels
* note: I would not make assumptions in usual circumstances, but have now for the sake of graph clarity
replace Defendant_Race = "Black" if Defendant_Race == "B"
replace Defendant_Race = "White" if Defendant_Race == "W"
replace Defendant_Race = "Asian" if Defendant_Race == "A"
replace Defendant_Race = "Indigenous" if Defendant_Race == "I"
replace Defendant_Race = "Unknown" if Defendant_Race == "U"

* Panel A
// ASSUMPTION: if individual is not released via ROR, they were assigned a monetary bail
gen Release_Category = ""
replace Release_Category = "Released on Recognizance" if Release_Type == "Release on Recognizance"
replace Release_Category = "Assigned Monetary Bail" if Release_Type != "Release on Recognizance"

// ASSUMPTION: bars are desired as the proportion of total defendants
// ASSUMPTION: Release_Type is the dominant variable

graph hbar (percent), over(Release_Category, label(labsize(small)) relabel(`r(relabel)')) over(Defendant_Race,label(labsize(small) angle(90))) ///
    title("Panel A", size(medium)) ///
	subtitle("Proportion of Release Types by Defendant Race", size(small)) ///
	ytitle("Percent of Defendants", size(small)) ///
	blabel(bar, format(%4.1f)) ///
	intensity(25)
graph save "output/PanelA_ReleaseByRace.png", replace


* Panel B
// ASSUMPTION: if individual was not subject to ROR or CASH/SURETY, they were detained
replace Pretrial_Release = "Detained" if Pretrial_Release == "No"
replace Pretrial_Release = "Released" if Pretrial_Release == "Yes"

// ASSUMPTION: bars are desired as the proportion of total defendants
// ASSUMPTION: Release_Type is the dominant variable

graph hbar (percent), over(Release_Category, label(labsize(small)) relabel(`r(relabel)')) over(Pretrial_Release,label(labsize(small) angle(90))) ///
    title("Panel B", size(medium)) ///
	subtitle("Proportion of Release Types by Initial Bail Hearing Result", size(small)) ///
	ytitle("Percent of Defendants", size(small)) ///
	blabel(bar, format(%4.1f)) ///
	intensity(25)
graph save "output/PanelB_ReleaseByInitialBail.png", replace


* Two Panel Figure 
graph combine "output/PanelA_ReleaseByRace.png" "output/PanelB_ReleaseByInitialBail.png", title("Figure 1: Release Type Proportions by Race and Bail Hearing Outcome") ///
    subtitle("Panel A: By Race | Panel B: By Hearing Outcome") ///
    colfirst
graph export "output/Figure1_TwoPanel.pdf", replace
	


* ------------ PART 3: Regression Estimate -----------------
ssc install outreg2
ssc install asdoc
use "dtas/combined_bond.dta", clear

replace Defendant_Race = "Black" if Defendant_Race == "B"
replace Defendant_Race = "White" if Defendant_Race == "W"
replace Defendant_Race = "Asian" if Defendant_Race == "A"
replace Defendant_Race = "Indigenous" if Defendant_Race == "I"
replace Defendant_Race = "Unknown" if Defendant_Race == "U"

* creating Yic dummy variable for whether or not a pretrial NCA was committed
gen Y_ic = .
replace Y_ic = 0 if New_Criminal_Activity == "No" // No pre trial NCA 
replace Y_ic = 1 if New_Criminal_Activity == "Pretrial NCA" // Pre trial NCA

* creating dummy variable for whether the individual was released or not
gen Released_ic = .
replace Released_ic = 0 if Pretrial_Release == "No"  // was not released
replace Released_ic = 1 if Pretrial_Release == "Yes" // was released 

* encoding categorical variables (race, sex) into numeric variables
encode Defendant_Sex, gen(Defendant_Sex_num) // male 2, female 1
encode Defendant_Race, gen(Defendant_Race_num)
save "dtas/combined_bond.dta", replace

asdoc logit Y_ic Released_ic i.Defendant_Race_num Defendant_Sex_num Prior_Charges
logit Y_ic i.Defendant_Race_num Defendant_Sex_num Prior_Charges
outreg2 using "logit_results.tex", replace tex

outreg2 using "logit_results.tex", replace tex ///
    title("Logistic Regression Results") ///
    addstat(Pseudo R2, e(r2_p), Log-likelihood, e(ll))
	
save "output/logit_results.tex", replace











