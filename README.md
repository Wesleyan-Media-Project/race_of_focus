# Wesleyan Media Project - Race of Focus 

Welcome! This repo is part of the Cross-platform Election Advertising Transparency initiatIVE (CREATIVE) project. CREATIVE is a joint infrastructure project of WMP and privacy-tech-lab at Wesleyan University. CREATIVE provides cross-platform integration and standardization of political ads collected from Google and Facebook.

This repo is part of the Preliminary Data Classification section.

[A picture of the repo pipeline with this repo highlighted] https://mediaproject.wesleyan.edu/wp-content/uploads/2023/08/wmp_pipeline_051123_v2_circle.png OR
https://camo.githubusercontent.com/f7339b7a62588f2b2931a9e7de16801f2686a1d8a69d979a3a440131abc82322/68747470733a2f2f6d6564696170726f6a6563742e7765736c6579616e2e6564752f77702d636f6e74656e742f75706c6f6164732f323032332f30362f776d705f706970656c696e655f3131313732325f746162732e706e67 


## Table of Contents

- [Introduction](#introduction)

- [Objective](#objective)

- [Data](#data)

- [Setup](#setup)

## Introduction
This repository contains code that identifies the race an ad focuses on based on which candidates are mentioned within it.

This repo contains three R scripts, and each script is based on different datasets. 
race_of_focus_140m.R uses data from Facebook from 2020, race_of_focus_fb_2022.R uses data from Facebook from 2022 and race_of_focus_google_2020.R uses data from Google from 2020.

In addition, it should be possible to use this repo to process ad data besides that of ads we collected. 
More details on this are given in the Setup Section. 

## Objective

Each of our repos belongs to one or more of the the following categories:
- Data Collection
- Data Storage & Processing
- Preliminary Data Classification
- Final Data Classification

This repo is part of the Preliminary Data Classification section.


## Data

The data created by the scripts in this repo is in fdata and csv format. Each R-file outputs 2 fdata scripts and 2 csv format ones. 

An individual record contains the following fields:
give descriptions/variable names once issue with fb_2020_140m_adid_var1.csv.gz is done 


## Setup
It is important that you know that there is no order that these scripts should be ran in. Each R file in the repo
acts on its own, without calling the other R files. 

In order to use this directory, you must
### 1. Install R and Packages
First, make sure you have R installed. In addition, while R can be ran from the terminal, many people find it much easier to use r-studio along with R  <br>
https://rstudio-education.github.io/hopr/starting.html here is a link that walks you through downloading and using both programs. <br>
The script uses R (4.2.2).
<br>
Next, make sure you have the following packages installed in R (exact version we used are listed [in the requirements_r.txt file](https://github.com/Wesleyan-Media-Project/race_of_focus/blob/main/requirements_r.txt) : <br>
purrr <br>
stringr <br>
dplyr <br>
tidyr <br> 
data.table <br>
R.utils <br>


### 2. Download Files Needed 
The R files that are in the repo reference data from existing ads we collected and processed. Depending on which platform (Google or Facebook) and which year (2020 or 2022)
you are interested in ad data from, you may find the data we used to be sufficent. In this case you can download directly from this repo and run files directly on R given that relevant packages along with needed files are installed.

However, if you wish to process your own ad data, this is also possible. To do so, you will want to change the name of your data to match the pre-existing path. In addition, if you are processing your own ad data, you will need to run entity_linking against it and put it as the path to path_el_results to make path_el_results correct. 

If you are using data from existing ads we collected and processed, then you can use the R-files from this repo directly. In this case, keep in mind that there is no correct order for the R-files in this repo to be ran. Each R-file is ran independently and is based on different data. Depending one which R-file you are running, you will need to download various additional repos into the same top-level folder as the race_of_focus repo. 

You can find the exact files needed for each script by looking at the code in the R-file that you are running and specifically at what is under #Input files. For example, path_140m_vars <- "../fb_2020/fb_2020_140m_adid_var1.csv.gz"
means that you neeed the file fb_2020_140m_adid_var1.csv.gz that is found in the fb_2020 repo.

Here are the repos you will need to download for each R script. 

Some of the files needed are not actually in the github directories they are listed as being under due to being too large.

Instead, these are currently on the Delta Lab Google Drive. This Google Drive will not be shared with the general public, but the data it utilizes will be shared in another manner (possibly through Figma links?). (ONCE THIS HAPPENS THIS WILL BE CHANGED)

Currently, 
running race_of_focus_140m.R requres: <br>
fb_2020 (fb_2020_140m_adid_var1.csv.gz, which is needed for this repo, is hosted on the google drive), entity_linking, datasets

running race_of_focus_google_2020.R requires: <br>
google_2020, entity_linking, datasets 

running race_of_focus_fb_2022.R requires: <br>
fb_2022, entity_linking_2022, datasets 


### 3. Run R file 
You should now be able to run the script. By default, the script uses both candidate mentions and appearances. For mentions only, change line 12 from textonly <- F to textonly <- T (line 13 in race_of_focus_google_2020.R).
