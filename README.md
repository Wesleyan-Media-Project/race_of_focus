# Wesleyan Media Project - Race of Focus 

Welcome! This repo identifies which race an ad focuses on as based on which candidates are mentioned in it. 

This repo is part of the Cross-platform Election Advertising Transparency Initiative (CREATIVE). CREATIVE is a jointly founded infrastructure project by Wesleyan Media Project [(WMP)](https://mediaproject.wesleyan.edu) and [Privacy Tech Lab](https://privacytechlab.org) at Wesleyan University in Connecticut. This program is funded by a National Science Foundation [grant](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2235006) to support making WMP’s work and data accessible to anyone. CREATIVE aims to provide cross-platform integration and standardization of digital advertising data related to federal elections by scraping or gaining access to digital ads themselves. (For more information on the CREATIVE project, click [here](https://www.creativewmp.com/)).

To analyze the different dimensions of political ad transparency we have developed an analysis pipeline. The scripts in this repo are part of the Data Classification Step in our pipeline. 
![A picture of the repo pipeline with this repo highlighted](CREATIVE_step3_032524.png)


## Table of Contents
[1. Introduction](#introduction)<br>
[2. Data](#data)<br>
[3. Setup](#setup)<br>
[4. Thank You!](#thank-you)<br>


## 1. Introduction
This repository contains code that identifies the race an ad focuses on based on which candidates are mentioned within it.

This repo contains four R scripts, and each script is based on different datasets. 
`race_of_focus_140m.R` uses data from Facebook from 2020, `race_of_focus_fb_2022.R` uses data from Facebook from 2022, `race_of_focus_google_2020.R` uses data from Google from 2020 and `race_of_focus_google_2022.R` uses data from Google from 2022.

It should be possible to use this repo to process ad data besides that of ads we collected. 
More details on this are given in the Setup Section. 

## 2. Data

The data created by the scripts in this repo is in fdata and csv format. Each R-file outputs 2 fdata scripts and 2 csv format ones. 

In order to visualize how the race is determined as based on ad sponsor, consult this diagram. 

![Diagram showing the process by which the race of focus is deduced](race_of_focus_chart.png)

## 3. Setup
It is important that you know that there is no order that these scripts should be ran in. Each R file in the repo acts on its own, without calling the other R files, due to each of these scripts using different datasets. 

In order to use this directory, you must
### 1. Install R and Packages
First, make sure you have R installed. In addition, while R can be ran from the terminal, many people find it much easier to use R-Studio along with R. A link to this program can be found [here](https://rstudio-education.github.io/hopr/starting.html) <br>
<br>
Here is a [link](https://education.rstudio.com/learn/beginner/) that walks you through downloading and using both programs. <br>
The script uses R (4.2.2).
<br>
Next, make sure you have the following packages installed in R (the exact version we used of each package is listed [in the requirements_r.txt file)](https://github.com/Wesleyan-Media-Project/race_of_focus/blob/main/requirements_r.txt) : <br>
purrr <br>
stringr <br>
dplyr <br>
tidyr <br> 
data.table <br>
R.utils <br>
<br>
A guide for installing older versions of packages can be found [here](https://support.posit.co/hc/en-us/articles/219949047-Installing-older-versions-of-packages). 


### 2. Download Files Needed 
The R files that are in the repo reference data from existing ads we collected and processed. Depending on which platform (Google or Facebook) and which year (2020 or 2022)
you are interested in ad data from, you may find the data we used to be sufficent. In this case you can download directly from this repo and run files directly on R given that relevant packages along with needed files are installed. 

However, if you wish to process your own ad data, this is also possible. To do so, you will want to change the name of your data to match the pre-existing files used in the script and ensure that you add a file path within the input siles section of the scripts you are using that matches the file path found on your computer. In addition, if you are processing your own ad data, you will need to run entity_linking against it and put it as the path to path_el_results to make path_el_results correct. 

If you are using data from existing ads we collected and processed, then you can use the R-files from this repo. Ensure that you modify the file path within the input files section of the scripts you are using so that they match up with what is found on your computer. 

Given that you are using data from existing ads we collected and processed, keep in mind that there is no correct order for the R-files in this repo to be ran. Each R-file is ran independently and is based on different data. Depending one which R-file you are running, you will need to download various additional repos into the same top-level folder as the race_of_focus repo. 

You can find the exact files needed for each script by looking at the code in the R-file that you are running and specifically at what is under #Input files. For example, `path_140m_vars <- "../fb_2020/fb_2020_140m_adid_var1.csv.gz"` means that you neeed the file `fb_2020_140m_adid_var1.csv.gz`. 

Some of the files needed are not actually in the github directories they are listed as being under due to being too large. Instead, these are available on Figshare. These include the files that are used in the first line of code after #Input Files. (These files will be available in Figshare, they are currently found in the deltalab Google Drive, internally)

Here are the repos you will need to download for each R script. 

Currently, 
running `race_of_focus_140m.R` requres datasets from the repos: <br>
[`fb_2020`](https://github.com/Wesleyan-Media-Project/fb_2020), [`entity_linking`](https://github.com/Wesleyan-Media-Project/entity_linking) and [`datasets`](https://github.com/Wesleyan-Media-Project/datasets)

running `race_of_focus_google_2020.R` requires: <br>
[`google_2020`](https://github.com/Wesleyan-Media-Project/google_2020), [`entity_linking`](https://github.com/Wesleyan-Media-Project/entity_linking), and [`datasets`](https://github.com/Wesleyan-Media-Project/datasets) 

running `race_of_focus_fb_2022.R` requires: <br>
[`data-post-production`](https://github.com/Wesleyan-Media-Project/data-post-production), [`entity_linking_2022`](https://github.com/Wesleyan-Media-Project/entity_linking_2022), and [`datasets`](https://github.com/Wesleyan-Media-Project/datasets) 


running `race_of_focus_google_2022.R` requires: <br>
[`data-post-production`](https://github.com/Wesleyan-Media-Project/data-post-production), [`entity_linking_2022`](https://github.com/Wesleyan-Media-Project/entity_linking_2022), and [`datasets`](https://github.com/Wesleyan-Media-Project/datasets) 


### 3. Run R file 
You should now be able to run the script. By default, the script uses both candidate mentions and appearances. For mentions only, change the line reading `textonly <- F` to `textonly <- T` in the repos `race_of_focus_fb_2022.R`, `race_of_focus_google_2020.R` and `race_of_focus_google_2022.R` or change the line reading `medium <- "image"` to `medium <- "text"` in `race_of_focus_140m.R`. 

If you need some help running the script, reference [this article](https://docs.posit.co/ide/user/ide/guide/code/execution.html). Running the `race_of_focus_fb_2022.R` script took around 20 minutes on a M2 Macbook, for reference. 

## 4. Thank You

<p align="center"><strong>We would like to thank our financial supporters!</strong></p><br>

<p align="center">This material is based upon work supported by the National Science Foundation under Grant Numbers 2235006, 2235007, and 2235008.</p>

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://www.nsf.gov/awardsearch/showAward?AWD_ID=2235006">
    <img class="img-fluid" src="nsf.png" height="150px" alt="National Science Foundation Logo">
  </a>
</p>

<p align="center">The Cross-Platform Election Advertising Transparency Initiative (CREATIVE) is a joint infrastructure project of the Wesleyan Media Project and privacy-tech-lab at Wesleyan University in Connecticut.

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://www.creativewmp.com/">
    <img class="img-fluid" src="CREATIVE_logo.png"  width="220px" alt="CREATIVE Logo">
  </a>
</p>

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://mediaproject.wesleyan.edu/">
    <img src="wmp-logo.png" width="218px" height="100px" alt="Wesleyan Media Project logo">
  </a>
</p>

<p align="center" style="display: flex; justify-content: center; align-items: center;">
  <a href="https://privacytechlab.org/" style="margin-right: 20px;">
    <img src="./plt_logo.png" width="200px" alt="privacy-tech-lab logo">
  </a>
</p>
