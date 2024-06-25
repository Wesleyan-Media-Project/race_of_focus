# CREATIVE --- Race of Focus

Welcome! This repo contains scripts for determining the electoral race an electoral ad is focused on.

This repo is a part of the [Cross-platform Election Advertising Transparency Initiative (CREATIVE)](https://www.creativewmp.com/). CREATIVE is an academic research project that has the goal of providing the public with analysis tools for more transparency of political ads across online platforms. In particular, CREATIVE provides cross-platform integration and standardization of political ads collected from Google and Facebook. CREATIVE is a joint project of the [Wesleyan Media Project (WMP)](https://mediaproject.wesleyan.edu/) and the [privacy-tech-lab](https://privacytechlab.org/) at [Wesleyan University](https://www.wesleyan.edu).

To analyze the different dimensions of political ad transparency we have developed an analysis pipeline. The scripts in this repo are part of the Data Classification step in our pipeline.

![A picture of the repo pipeline with this repo highlighted](CREATIVE_step3_032524.png)

## Table of Contents

[1. Introduction](#1-introduction)  
[2. Data](#2-data)  
[3. Setup](#3-setup)  
[4. Thank You!](#4-thank-you)

## 1. Introduction

This repo contains scripts for determining the electoral race an electoral ad is focused on based on which candidates are mentioned within it.

Specifically, this repo contains four R scripts with each being based on different datasets:

- `race_of_focus_140m.R` uses data from Facebook from 2020 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)
- `race_of_focus_fb_2022.R` uses data from Facebook from 2022 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)
- `race_of_focus_google_2020.R` uses data from Google from 2020 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)
- `race_of_focus_google_2022.R` uses data from Google from 2022 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)

You can use the scripts in this repo to analyze ad data beyond the data we already analyzed. Check the Setup section for detailed instructions how to do so.

## 2. Data

The data created by the scripts in this repo is in Rdata and csv format. Each R scripts outputs two Rdata files and two csv format files. We give two versions to allow users to choose between the types of data that more general (csv) or more efficient for R (Rdata).

When determining which race an ad is focused on, we use different criteria based on the type of the sponsor of the ad (wmp_spontype). In general, we have three different groups of sponsors: federal candidate, down ballow candidate, and non-candidate group. For each type, we use a different decision-making for race of focus. For instance, for federal candidate and down ballot candidate ads, we simply take the office/race of the sponsor as race of focus. For non-candidate ads, we have a longer process which we visualize below. 

Once our race of focus classification is complete (output in the `race_of_focus` column), we then put these classification results into buckets and sub-buckets to help users categorize each ad into a group. This classification is represented as numbered indices (e.g. 1, 3.2.1) in the output column `sub_bucket`. 

The following diagram documents what each numbered sub-bucket represents and visualizes our decision-making process. For example, if an observation, i.e. an ad, is labeled sub-bucket 1 from our repo output, it represents an ad from a federal candidate race, and we make this decision because this ad was sponsored by a known federal candidate campaign. The variable `wmp_spontype` indicating whether an ad sponsor is a candidate campaign, national party, local party, or interest group can be found in one of our input files in the scripts. For an ad sponsored by a candidate's campaign, its race of focus is the candidate's race. For ads that were not sponsored by a candidate's campaign (e.g. by parties and outside groups instead), we determine the races of focus based on patterns of candidate mentions in the text fields and geolocations of targeted or exposed audiences. Using the `sub_bucket` indices, users can conveniently filter for ads relevant to the races of their interest for analysis. 

![Diagram showing the process by which the race of focus is deduced](race_of_focus_chart.png)

## 3. Setup

You can run the scripts in this repo in any order. Each R script in the repo acts on its own without calling the any other script due to each of these scripts using different datasets.

### 3.1 Install R and Packages

First, to use the scripts in this repo make sure you have R installed. In addition, while R can be ran from the terminal, many people find it easier to use RStudio along with R. You can find [RStudio here](https://rstudio-education.github.io/hopr/starting.html). Here is a [tutorial that walks you through downloading and using both programs](https://education.rstudio.com/learn/beginner/).

The script has been tried on and thus should run with no issues on R versions 4.2, 4.3 and 4.4. 

Next, make sure you have the following packages installed in R. You can simply install latest versions of each package. We provide a list of these packages with the earliest versions these scripts should work with [here](https://github.com/Wesleyan-Media-Project/race_of_focus/blob/main/requirements_r.txt)). The scripts might work with lower versions as well but this is not validated:

- purrr >= 1.0.1
- stringr >= 1.5.0
- dplyr >= 1.1.0
- tidyr >= 1.3.0      
- data.table >= 1.14.8
- R.utils >= 2.12.2

### 3.2 Download Dataset Files

The R scripts that are in the repo reference data from existing ads we collected and processed. Depending on which platform (Google or Facebook) and which year (2020 or 2022) you are interested in, you may find the data we already collected to be sufficient. The links to download these files are provided here:

- `race_of_focus_140m.R` uses data from Facebook from 2020 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)
- `race_of_focus_fb_2022.R` uses data from Facebook from 2022 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)
- `race_of_focus_google_2020.R` uses data from Google from 2020 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)
- `race_of_focus_google_2022.R` uses data from Google from 2022 (ADD FIGSHARE LINK FOR VAR1 FILE ONCE READY)

However, if you wish to process your own ad data, this is also possible. To do so, you will want to change the name of your data to match the pre-existing files used in the script and ensure that you add a file path within the input files section of the scripts you are using that matches the file path found on your computer. In addition, if you are processing your own ad data, you will need to run entity_linking [2020](https://github.com/Wesleyan-Media-Project/entity_linking) or [2022](https://github.com/Wesleyan-Media-Project/entity_linking_2022) again and put it as the path to path_el_results to make path_el_results correct.

If you are using data from existing ads we collected and processed, then you can use the R scripts from this repo. Ensure that you modify the file path within the input files section of the scripts you are using so that they match up with what is found on your computer.

Given that you are using data from existing ads we collected and processed, keep in mind that there is no correct order for the R scripts in this repo to be ran. Each R script is ran independently and is based on different data.

You can find the exact files needed for each script by looking at the code in the R script that you are running and specifically at what is under #Input files. For example, `path_140m_vars <- "../fb_2020/fb_2020_140m_adid_var1.csv.gz"` means that you need the file `fb_2020_140m_adid_var1.csv.gz`.

Some of the files needed are not actually in the GitHub directories due to being too large. Instead, these are available on Figshare. These include the files that are used in the first line of code after #Input Files.

Here are the repos you will need to download for each R script. The files from these repos are used as input files in race of focus scripts.

Running `race_of_focus_140m.R` requires datasets from the repos:

- [`fb_2020`](https://github.com/Wesleyan-Media-Project/fb_2020)
- [`entity_linking`](https://github.com/Wesleyan-Media-Project/entity_linking)
- [`datasets`](https://github.com/Wesleyan-Media-Project/datasets)

Running `race_of_focus_google_2020.R` requires:

- [`google_2020`](https://github.com/Wesleyan-Media-Project/google_2020)
- [`entity_linking`](https://github.com/Wesleyan-Media-Project/entity_linking)
- [`datasets`](https://github.com/Wesleyan-Media-Project/datasets)

Running `race_of_focus_fb_2022.R` requires:

- [`data-post-production`](https://github.com/Wesleyan-Media-Project/data-post-production)
- [`entity_linking_2022`](https://github.com/Wesleyan-Media-Project/entity_linking_2022)
- [`datasets`](https://github.com/Wesleyan-Media-Project/datasets)

Running `race_of_focus_google_2022.R` requires:

- [`data-post-production`](https://github.com/Wesleyan-Media-Project/data-post-production)
- [`entity_linking_2022`](https://github.com/Wesleyan-Media-Project/entity_linking_2022)
- [`datasets`](https://github.com/Wesleyan-Media-Project/datasets)

### 3.3 Run R Scripts

You should now be able to run the script. By default, the script uses both candidate mentions and appearances. For mentions only, change the line within each script that is reading `textonly <- F` to `textonly <- T` in the repos `race_of_focus_fb_2022.R`, `race_of_focus_google_2020.R` and `race_of_focus_google_2022.R` or change the line reading `medium <- "image"` to `medium <- "text"` in `race_of_focus_140m.R`. We provide this option to allow users to decide on race of focus using the text mentions or visual appearances of candidates .

If you need some help running the script, reference [this article](https://docs.posit.co/ide/user/ide/guide/code/execution.html). Running the `race_of_focus_fb_2022.R` script took around 20 minutes on a M2 Macbook, for reference.

## 4. Thank You

<p align="center"><strong>We would like to thank our supporters!</strong></p><br>

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
