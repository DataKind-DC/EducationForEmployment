* I don't know why we have this and another merged dataset?
/*
import excel using "C:/Users/wb576985/Downloads/EMP_Stat (1).xlsx", clear firstrow

* We're interested in retention, keep variables related to that
gen interest = 1 if strpos(employmentstatuschecktype,"Post-Placement")
keep if interest == 1

* Data note 
* Data not available for certain placement does NOT mean they were not retained,
* but rather that they have not been interiewed by that period yet.

* Instead, for each post-placement period, we can check "still at same employer" | "same company"
* step - grab the numeric
gen postplacement_month= regexs(2) if regexm(employmentstatuschecktype, "^([^0-9]*)([0-9]+)([^0-9]*)$")

* Keep interested vars 
keep contactid stillatsameemployer employmentstatuschecktype currentlyworking currentpositiontype satisfhoursworkedperweekcurrent fixedtermcontractlengthcurrent fixedtermcontractlengthprevious

tempfile empstat 
save `empstat', replace
*/
* yw note - I was going to do a 1:m merge with the contacts processed, but I see that someone already did it and cleaned it (Kristen Tuoho's file?)- I am using this as the output dataset 
import excel using "C:/Users/wb576985/Downloads/contactsProcessed_and_JobData_Clean.xlsx", clear firstrow

rename *, lower


* keep interested vars 
* note: all the "proxy" vars seem to be dummy versions of the y/n vars
keep contactid currently_working_proxy same_employer_proxy position_type efe_training_relevance_to_sector gender nationality beneficiaryspecialization levelofeducation numberdaysretainedjob pl_* mainobstacletosecurejob motivationfortraining received_prior_profskills_train retention_6_months retention_3_months retention_9_months retention_12_months countryofprogramming emp_stat_type survey_created_date //months_job 

drop pl_*_data

* A lil cleaning
rename (currently_working_proxy same_employer_proxy efe_training_relevance_to_sector levelofeducation numberdaysretainedjob mainobstacletosecurejob received_prior_profskills_train motivationfortraining countryofprogramming) (working same_employer efe_relevance educ retention_days main_obstacle pre_train_skills efe_reason country) 


rename retention_*_months retention_*

* Make Numeric
foreach v of varlist working-retention_12 {
	cap replace `v' = "" if `v' == "NA"
}


destring *, replace


* Fill in info from latest experience
* If same employer, also working

* Order the calls 
gen order = 1 if emp_stat_type  == "At Grad Placement Status Check"
replace order = 2 if emp_stat_type  == "3-Month Placement Status Check"
replace order = 3 if emp_stat_type  == "6-Month Placement Status Check"
replace order = 4 if emp_stat_type  == "9-Month Placement Status Check"
replace order = 5 if emp_stat_type  == "12-Month Placement Status Check"
replace order = 6 if emp_stat_type  == "3-Month Post-Placement Status Check"
replace order = 7 if emp_stat_type  == "6-Month Post-Placement Status Check"
replace order = 8 if emp_stat_type  == "9-Month PostPlacement Status Check"
replace order = 9 if emp_stat_type  == "12-Month Post-Placement Status Check"


* Order the rows by survey date, since some emp_stat_type is missing
gen date = date(survey_created_date, "DMY")
format date %td

bys contactid (date): gen n = _n


gen position = position_type
bys contactid (n): fillmissing position, with(any) 
bys contactid (n): fillmissing efe_relevance, with(any) 

/*Test
//bys contactid (order): fillmissing test, with(any) 
//gen test2 = position_type
*/
* We don't want it filled if the person is no longer employed 
* If same employer = 1, definitionally they are also working
replace position = "" if working == 0 
replace efe_relevance = "" if working == 0

replace working = 1 if same_employer == 1

replace position = "Unemployed" if working == 0

* Keep the twomost recent survey response
* Get previous employment info if new job is different or no longer working 
preserve 

* First, the most recent one
bysort contactid (n): keep if n==n[_N]

tempfile recent 
save `recent', replace

* keep the second most recent one 
restore 
bysort contactid (n): drop if n==n[_N]
bysort contactid (n): keep if n==n[_N]

keep contactid n position working emp_stat_type efe_relevance
rename (position working emp_stat_type efe_relevance) (prev_position prev_working prev_emp_stat_type prev_efe_relevance)

merge 1:1 contactid using `recent', nogen 

* make pretty 
gen post_month= regexs(2) if regexm(emp_stat_type, "^([^0-9]*)([0-9]+)([^0-9]*)$")

sort country contactid n 

replace country = subinstr(country, " Beneficiary", "", .)

gen retention_months = (retention_days / 365) * 12

drop position_type 

order contactid country gender order n date emp_stat_type retention_days working same_employer position retention_* 

export excel "C:/Users/wb576985/Downloads/efe_tableau.xlsx", replace