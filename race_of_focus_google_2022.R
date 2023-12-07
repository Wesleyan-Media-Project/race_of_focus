# Implements race_of_focus, as detailed here:
# https://docs.google.com/presentation/d/11E9kX1oVYfMooTdD1GAJfwJtdPIQpYB3lJ7i5e83ZEw/edit#slide=id.g12d57307ead_0_0

library(data.table)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)
library(haven)
library(tidyverse)

# Option to use only the text-based fields to decide race of focus
# Set to False by default
#textonly <- F
textonly <- T

####Input Files####
#goggle files
path_g2022_vars <- "../google_2022/google2022_adidlevel_merged.csv"
g2022 <- fread(path_g2022_vars, encoding = "UTF-8")

#entity linking files
path_el_results <- "../entity_linking_2022/google/data/entity_linking_results_google_2022_notext_combined.csv.gz"
entity <- fread(path_el_results, encoding = "UTF-8")

path_wmpent <- "../datasets/wmp_entity_files/Google/wmp_google_2022_entities_v112822.csv"
wmpent <- fread(path_wmpent, encoding = "UTF-8")

#candidate files
path_cand <- "../datasets/candidates/wmpcand_120223_wmpid.csv"
cand2022 <- fread(path_cand, encoding = "UTF-8")

#faces
path_cand_pol <- "../datasets/people/person_2022.csv"
pol <- fread(path_cand_pol, encoding = "UTF-8")


# Output files
path_out_rdata <- "data/race_of_focus_google_2022.rdata"
path_out_rdata_textonly <- "data/race_of_focus_google_2022_textonly.rdata"
path_out_csv <- "data/race_of_focus_google_2022.csv"
path_out_csv_textonly <- "data/race_of_focus_google_2022_textonly.csv"

####Process####
# g2022: combine aws columns 
g2022$aws_face_vid <- str_replace_all(g2022$aws_face_vid, ";", ",")
g2022$aws_face_img <- str_replace_all(g2022$aws_face_img, ";", ",")
# Combine two columns with values separated by commas
g2022$aws_face <- paste(g2022$aws_face_vid, g2022$aws_face_img, sep = ",")
g2022$aws_face <- str_replace_all(g2022$aws_face, "NA", "")

g2022 <- g2022 %>% 
  mutate(aws_face = ifelse(grepl("^[,]+$", aws_face), NA, aws_face)) %>%
  mutate(aws_face = sub("^,+", "", aws_face)) %>%
  mutate(aws_face = sub(",+$", "", aws_face))

# Read Google 2022 variables file
g2022 %>%
  select(ad_id, advertiser_id, geo_targeting_included, aws_face)

full_size <- nrow(g2022)

# Add in entity linking results directly from the EL repo
entity2 <- entity[match(g2022$ad_id, entity$ad_id),]
g2022$detected_entities <- entity2$detected_entities

# WMP entities file
# Keep only relevant columns
wmpent2 <- wmpent %>% 
  select(advertiser_id, wmp_spontype_new, wmp_office, hse_fecid, sen_fecid)

wmpent2 <- wmpent2 %>%
  mutate(fecid_formerge = coalesce(sen_fecid, hse_fecid))

wmpent3 <- wmpent2 %>% 
  select(advertiser_id, wmp_spontype_new, wmp_office, fecid_formerge)


# Merge with candidates file for district
cand2022$cand_office_dist <- sprintf("%02d", cand2022$cand_office_dist)

cand2022$office <- paste(cand2022$cand_office_st, cand2022$cand_office_dist, sep = "")

cand2022_2 <- cand2022 %>%
  select(cand_id, office, wmpid) %>%
  # Remove duplicate rows
  filter(!duplicated(.))

wmpent4 <- wmpent3 %>% left_join(cand2022_2, c("fecid_formerge" = "cand_id"))

# Then merge into google
g2022_2 <- g2022 %>% left_join(wmpent4, "advertiser_id")


# Mentions ####

if(textonly == F){
  # Combine mentions and appearances
  g2022_2$all_entities <- 
    paste(g2022_2$detected_entities, g2022_2$aws_face, sep = ",") %>%
    str_remove(",$") %>%
    str_split(",") %>%
    lapply(str_trim)
  g2022_3 <- g2022_2 %>% select(-c(detected_entities, aws_face))
}

if(textonly == T){
  # Combine mentions and appearances
  g2022_2$all_entities <- 
    g2022_2$detected_entities %>%
    str_remove(",$") %>%
    str_split(",") %>%
    lapply(str_trim)
  g2022_3 <- g2022_2 %>% select(-c(detected_entities, aws_face))
}

#Exclusions
# exclude scotus, former potus candidates, senators not up for reelection
pol <- fread(path_cand_pol)

not_relevant_person <- pol[,which(names(pol) == "supcourt_2022"):which(names(pol) == "gov2022_noelect")]
not_relevant_person[is.na(not_relevant_person) == T] <- 0
# also include cabinet members etc. who don't have their own variable
not_relevant_person$other <- as.numeric(pol$face_category != "")
# anyone who has at least one 1 is not relevant
not_relevant_person <- apply(not_relevant_person, 1, function(x){any(x == 1)})
not_relevant_person <- pol$wmpid[not_relevant_person]

g2022_3$all_entities <- 
  lapply(g2022_3$all_entities, function(x){x[!x %in% not_relevant_person]}) %>%
  # if one of those people is the only one mentioned, 
  # it will be set to character(0), changing this to ""
  lapply(function(x){x[x != ""]})
rm(pol)
g2022_3$all_entities[unlist(lapply(g2022_3$all_entities, length)) == 0] <- ""


#####
#remove NAs
g2022_3$all_entities <- lapply(g2022_3$all_entities, function(lst) lst[lst != "NA"])

g2022_3$all_entities[unlist(lapply(g2022_3$all_entities, length)) == 0] <- ""
# Only unique entities within an ad
g2022_3$all_unique_entities <- lapply(g2022_3$all_entities, unique)
# Get the races of the ad's unique entities
g2022_3$all_unique_entities_races <- lapply(g2022_3$all_unique_entities, 
                                            function(x){cand2022_2$office[match(x, cand2022_2$wmpid)]})
# Get the unique races
g2022_3$all_unique_entities_unique_races <- lapply(g2022_3$all_unique_entities_races, unique)
# How many unique races?
g2022_3$all_unique_entities_unique_races_N <- unlist(lapply(g2022_3$all_unique_entities_unique_races, 
                                                            function(x){length(x[is.na(x) == F])}))
# Unique mentions without presidential candidates
g2022_3$all_unique_entities_no_pres <- lapply(g2022_3$all_unique_entities, 
                                              function(x){x[substr(x, 1, 1) != "P"]})
g2022_3$all_unique_entities_no_pres[lapply(g2022_3$all_unique_entities_no_pres, length) == 0] <- ""
# Get the races of the ad's unique entities
g2022_3$all_unique_entities_races_no_pres <- lapply(g2022_3$all_unique_entities_no_pres, 
                                                    function(x){cand2022_2$office[match(x, cand2022_2$wmpid)]})
# Get the unique races
g2022_3$all_unique_entities_unique_races_no_pres <- lapply(g2022_3$all_unique_entities_races_no_pres, unique)
# How many unique races?
g2022_3$all_unique_entities_unique_races_N_no_pres <- unlist(lapply(g2022_3$all_unique_entities_unique_races_no_pres, 
                                                                    function(x){length(x[is.na(x) == F])}))

# ----
# Geo matches
# Note that the results are only reliable for ads that are actually in bucket 3.2.2.x

# Extract regional impressions (states)
g2022_3$region_distribution <- str_remove_all(g2022_3$geo_targeting_included, "\\-[0-9]+")
g2022_3$region_distribution <- str_split(g2022_3$region_distribution, ",")

normalize_regions <- function(x){
  detected_abbs <- state.abb[match(x[x %in% state.name], state.name)]
  x[x %in% state.name] <- detected_abbs
  x <- unique(x[x %in% state.abb])
  return(x)
}

g2022_3$region_distribution <- lapply(g2022_3$region_distribution, normalize_regions)

# States of mentioned entities
g2022_3$entities_states <- 
  lapply(g2022_3$all_unique_entities_unique_races_no_pres, substr, 1, 2) %>%
  lapply(unique)

# For each state in the region distribution
# check whether it is contained in the states of the mentioned entities
# And what it's position in that vector is
check <- map2(g2022_3$region_distribution, g2022_3$entities_states, function(x,y){match(x, y)})
# Only keep the non-NAs
check2 <- lapply(check, function(x){x[is.na(x) == F]})

# Races with overlap
g2022_3$matched_mentions <- map2(g2022_3$all_unique_entities_unique_races_no_pres, check2, function(x,y){x[y]})
# Set NAs to character(0), otherwise the next step sometimes works incorrectly
g2022_3$matched_mentions[is.na(g2022_3$matched_mentions)] <- list(as.character())
# How many of these are there?
g2022_3$state_matches <- unlist(lapply(check2, length))
# Add an indicator to the g2022_3 for whether the ad has a match
g2022_3$state_match_binary <- ifelse(g2022_3$state_matches == 0, 0, 1)
# Impressions proportion of those races
check3 <- map2(g2022_3$entities_states, g2022_3$region_distribution, function(x,y){match(x, y)})
check3 <- lapply(check3, function(x){x[is.na(x) == F]})
#g2022_3$matched_mentions_region_pct <- map2(g2022_3$region_pct, check3, function(x,y){x[y]})



####
# Note that the results are only reliable for ads that are actually in bucket 3.2.2.x

# Extract regional impressions (state & percentage)
# Start extracting the state from region distribution
g2022_3$region_distribution <- 
  g2022_3$region_distribution %>%
  str_replace_all("Washington, District of Columbia", "Washington District of Columbia") %>% 
  str_remove_all('\\"') %>% 
  str_remove_all('percentage:') %>% 
  str_remove_all(',region') %>% 
  str_remove_all('\\[|\\]|\\{|\\}')

# Split regions
tmp <- str_split(g2022_3$region_distribution, ",")
# For each region, split the percentage and the region name
tmp <- lapply(tmp, str_split_fixed, ":", n = 2)
# Only keep regions that are states
# the ,,drop = F avoids converting one-row matrices into vectors
# the first comma is for the subsetting, the second to specify arguments
tmp <- lapply(tmp, function(x){x[x[,2] %in% state.name,,drop = F]})
# Put each column of the resulting into the respective column in the dataframe
g2022_3$region_pct <- lapply(tmp, function(x){x[,1]})
g2022_3$region_distribution <- lapply(tmp, function(x){x[,2]})
# Convert state names to state abbreviations
g2022_3$region_distribution <- lapply(g2022_3$region_distribution, function(x){state.abb[match(x, state.name)]})

# States of mentioned entities (without presidential candidates)
g2022_3$entities_states <- 
  lapply(g2022_3$all_unique_entities_unique_races_no_pres, substr, 1, 2) %>%
  lapply(unique)

# For each state in the region distribution
# check whether it is contained in the states of the mentioned entities
# And what it's position in that vector is
check <- map2(g2022_3$region_distribution, g2022_3$entities_states, function(x,y){match(x, y)})
# Only keep the non-NAs
check2 <- lapply(check, function(x){x[is.na(x) == F]})
# Races with overlap
g2022_3$matched_mentions <- map2(g2022_3$all_unique_entities_unique_races_no_pres, check2, function(x,y){x[y]})
# Set NAs to character(0), otherwise the next step sometimes works incorrectly
g2022_3$matched_mentions[is.na(g2022_3$matched_mentions)] <- list(as.character())
# How many of these are there?
g2022_3$state_matches <- unlist(lapply(check2, length))
# Add an indicator to the df for whether the ad has a match
g2022_3$state_match_binary <- ifelse(g2022_3$state_matches == 0, 0, 1)
# Impressions proportion of those races
check3 <- map2(g2022_3$entities_states, g2022_3$region_distribution, function(x,y){match(x, y)})
check3 <- lapply(check3, function(x){x[is.na(x) == F]})
g2022_3$matched_mentions_region_pct <- map2(g2022_3$region_pct, check3, function(x,y){x[y]})
####
# ----
# Buckets

g2022_3$bucket <- NA
g2022_3$bucket[g2022_3$wmp_spontype_new %in% c("campaign", "leadership PAC") & g2022_3$wmp_office %in% c("president", "us house", "us senate")] <- "1"
g2022_3$bucket[g2022_3$wmp_office %in% c("down ballot", "governor")] <- "2"
g2022_3$bucket[is.na(g2022_3$bucket)] <- "3"

# Sub-buckets
g2022_3$sub_bucket <- g2022_3$bucket
g2022_3$sub_bucket[g2022_3$bucket == "3" & g2022_3$all_unique_entities_unique_races_N == 1] <- "3.1"
g2022_3$sub_bucket[g2022_3$bucket == "3" & g2022_3$all_unique_entities_unique_races_N == 0] <- "3.3"
g2022_3$sub_bucket[g2022_3$sub_bucket == "3" & g2022_3$all_unique_entities_unique_races_N_no_pres == 1] <- "3.2.1"
g2022_3$sub_bucket[g2022_3$sub_bucket == "3" & g2022_3$state_matches == 1] <- "3.2.2.1"
g2022_3$sub_bucket[g2022_3$sub_bucket == "3" & g2022_3$state_matches == 0] <- "3.2.2.3"
g2022_3$sub_bucket[g2022_3$sub_bucket == "3"] <- "3.2.2.2" # all remaining ones

table(g2022_3$sub_bucket)

#write_csv(g2022_3, "google22_buckets.csv")

# ----
# Race of focus

#load the g2022_3 again if needed

# The following line correctly sets the race of focus for
# sub-buckets 3.2.2.1, and 3.2.2.2
#g2022_3$race_of_focus <- map2(g2022_3$matched_mentions_region_pct, 
#                              g2022_3$matched_mentions, function(x,y){y[which.max(x)]})
# Unlisting here requires a prior step, otherwise it crashes R
#g2022_3$race_of_focus[unlist(lapply(g2022_3$race_of_focus, length)) == 0] <- NA
#g2022_3$race_of_focus <- unlist(g2022_3$race_of_focus)

# Other buckets
g2022_3$race_of_focus <- NA
g2022_3$race_of_focus[g2022_3$sub_bucket == "1"] <- g2022_3$office[g2022_3$sub_bucket == "1"]
g2022_3$race_of_focus[g2022_3$sub_bucket == "2"] <- "Downballot"
g2022_3$race_of_focus[g2022_3$sub_bucket == "3.1"] <- unlist(g2022_3$all_unique_entities_unique_races[g2022_3$sub_bucket == "3.1"])

#g2022_3$race_of_focus[g2022_3$sub_bucket == "3.2.1"] <- unlist(g2022_3$all_unique_entities_unique_races_no_pres[df$sub_bucket == "3.2.1"])
#g2022_3$race_of_focus[g2022_3$sub_bucket == "3.2.2.3"] <- "No race of focus"

g2022_3$race_of_focus[g2022_3$sub_bucket == "3.3"] <- "No race of focus"

# For bucket 3.2.2.1 and 3.2.2.2, get the proportions of the match
# Ignore the 'In FUN(X[[i]], ...) : no non-missing arguments, returning NA' warning
g2022_3$race_of_focus_region_pct <- unlist(lapply(g2022_3$matched_mentions_region_pct, max)) # Ignore the warnings
g2022_3$race_of_focus_region_pct[!g2022_3$sub_bucket %in% c("3.2.2.1", "3.2.2.2")] <- NA

if(textonly == F){
  # Use bzip2 compression to sneak it under the 100Mb mark
  save(g2022_3, file = path_out_rdata, compress = "bzip2")
  g2022_4 <- g2022_3 %>% select(ad_id, sub_bucket, race_of_focus)#, race_of_focus_region_pct)
  fwrite(g2022_4, path_out_csv)
}


if(textonly == T){
  # Use bzip2 compression to sneak it under the 100Mb mark
  save(g2022_3, file = path_out_rdata_textonly, compress = "bzip2")
  g2022_4 <- g2022_3 %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(g2022_4, path_out_csv_textonly)
}
