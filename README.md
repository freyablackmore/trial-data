# Criminal Activity Committed Upon Release 

_Freya Blackmore_

_January 4th, 2025_

# Summary
This file includes a data task analyzing the commitment of new criminal activity following a bail release. 


# Data
The imported data includes six data sets. 

``` Bonds_Q1_2020.csv ```

``` Bonds_Q2_2020.csv ```

``` Bonds_Q3_2020.csv ```

The bond data sets include information regarding when and how bonds were set, made, and on what conditions. 

``` Criminal_History_Q1_2020.csv ```

``` Criminal_History_Q2_2020.csv ```

``` Criminal_History_Q3_2020.csv ```

The criminal history data sets outline the previous criminal activity committed by individuals, and the timings of these activities. 

The initial section of this code works to clean the bond data sets. There are discrepancies within the original data sets regarding how certain information is recorded and grouped, and the first step to working with this data is to standardize the column labels and content. 

Then, the data tables are combined into one complete data set which is used for the subsequent analysis. 

# Analysis 

The first section of analysis includes creating a two panel figute. Panel A depicts the proportion of release type by race. Panel B depicts the proportion of release type by the initial bail hearing result. 

[Figure1_TwoPanel.pdf](https://github.com/user-attachments/files/18693748/Figure1_TwoPanel.pdf)

The second section of analysis includes a logistic regression examining commitment of new crimes pretrial, controlling for the number of prior charges against a defendant, the defendant's sex, and the defendant's race. 

The model shows a statistically significant result for sex (lower liklihood of pretrial new criminal activity for me), prior charges (lower liklihood of pretrial new criminal activity for those with fewer prior charges), and race for black defendants (lower liklihood of pretrial new criminal activity for black defendants).
