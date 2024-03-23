library(data.table)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)

# Option to use only the text-based fields to decide race of focus
# Set to False by default
textonly <- F

# Input files

# This is one of the output tables from data-post-production/01-merge-results/01_merge_preprocessed_results
path_fb2022_vars <- "fb_2022_adid_var1.csv.gz"

path_el_results <- "../entity_linking_2022/facebook/data/detected_entities_fb22.csv.gz"
path_wmpent <- "../datasets/wmp_entity_files/Facebook/2022/wmp_fb_2022_entities_v120122.csv"
path_cand <- "../datasets/candidates/wmpcand_120223_wmpid.csv"
path_cand_pol <- "../datasets/people/person_2022.csv"
# Output files
path_out_rdata <- "data/race_of_focus_fb2022.rdata"
path_out_rdata_textonly <- "data/race_of_focus_fb2022_textonly.rdata"
path_out_csv <- "data/race_of_focus_fb2022.csv"
path_out_csv_textonly <- "data/race_of_focus_fb2022_textonly.csv"

# Read fb2022 variables file
df <- fread(path_fb2022_vars, encoding = "UTF-8") %>%
  select(ad_id, pd_id, region_distribution, aws_face_img, aws_face_vid)
full_size <- nrow(df)

# Add in entity linking results directly from the EL repo
el <- fread(path_el_results)
# Merge in EL results
df <- left_join(df, el, by = "ad_id")
df$detected_entities[is.na(df$detected_entities)] <- ""

# WMP entities file
wmp_ents <- fread(path_wmpent)
# Keep only relevant columns
wmp_ents_all <- wmp_ents
wmp_ents <- wmp_ents %>% 
  select(pd_id, wmp_spontype, wmp_office, wmpid)
# Merge with candidates file for district
cands <- fread(path_cand) %>%
  filter(genelect_cd == 1)
cands$cand_office_dist[cands$cand_office == "H"] <- str_pad(cands$cand_office_dist[cands$cand_office == "H"], side = "left", pad = "0", width = 2)
cands$cand_office_dist[cands$cand_office == "S"] <- "S0"
cands$office <- paste(cands$cand_office_st, cands$cand_office_dist, sep = "")
cands <- cands %>%
  select(wmpid, office) %>%
  # Remove duplicate rows (only does anything in 2020, but keeping it for potential future use)
  filter(!duplicated(.))
wmp_ents <- wmp_ents %>% left_join(cands, "wmpid")

# Add office for candidates who aren't in the candidate file, but have an office in the WMP entity file
wmp_ents_all$office <- paste0(wmp_ents_all$hse_state, str_pad(wmp_ents_all$hse_district, 2, "left", "0"))
wmp_ents_all$office[(is.na(wmp_ents_all$sen_state) == F) & wmp_ents_all$sen_state != ""] <- paste0(wmp_ents_all$sen_state, "S0")[(is.na(wmp_ents_all$sen_state) == F) & wmp_ents_all$sen_state != ""]
wmp_ents_all$office[wmp_ents_all$office == "NA"] <- NA
for(i in 1:nrow(wmp_ents)){
  if((wmp_ents$wmp_spontype[i] == "campaign") & (wmp_ents$wmp_office[i] %in% c("us house", "us senate")) & is.na(wmp_ents$office[i])){
    wmp_ents$office[i] <- wmp_ents_all$office[match(wmp_ents$pd_id[i], wmp_ents_all$pd_id)]
  }
}

# Then merge into FB2022
df <- df %>% left_join(wmp_ents, "pd_id")


# ----
# Mentions

if(textonly == F){
  # Combine mentions and appearances
  df <- df %>% unite("all_entities", detected_entities, aws_face_img, aws_face_vid, sep = ",")
  df$all_entities <- 
    df$all_entities %>%
    str_remove_all("^[,]+") %>%
    str_remove_all("[,]+$") %>%
    str_split(",") %>%
    lapply(str_trim)
}
if(textonly == T){
  # Combine mentions and appearances
  df$all_entities <- 
    df$detected_entities %>%
    str_remove_all("^[,]+") %>%
    str_remove_all("[,]+$") %>%
    str_split(",") %>%
    lapply(str_trim)
  df <- df %>% select(-c(detected_entities, aws_face_img, aws_face_vid))
}

# exclude scotus, former potus candidates, senators not up for reelection
pol <- fread(path_cand_pol)

not_relevant_person <- pol[,which(names(pol) == "supcourt_2022"):which(names(pol) == "gov2022_noelect")]
not_relevant_person[is.na(not_relevant_person) == T] <- 0
# also include cabinet members etc. who don't have their own variable
not_relevant_person$other <- as.numeric(pol$face_category != "")
# anyone who has at least one 1 is not relevant
not_relevant_person <- apply(not_relevant_person, 1, function(x){any(x == 1)})
not_relevant_person <- pol$wmpid[not_relevant_person]

df$all_entities <- 
  lapply(df$all_entities, function(x){x[!x %in% not_relevant_person]}) %>%
  # if one of those people is the only one mentioned, 
  # it will be set to character(0), changing this to ""
  lapply(function(x){x[x != ""]})
rm(pol)
df$all_entities[unlist(lapply(df$all_entities, length)) == 0] <- ""

# Only unique entities within an ad
df$all_unique_entities <- lapply(df$all_entities, unique)
# Get the races of the ad's unique entities
df$all_unique_entities_races <- lapply(df$all_unique_entities, function(x){cands$office[match(x, cands$wmpid)]})
# Get the unique races
df$all_unique_entities_unique_races <- lapply(df$all_unique_entities_races, unique)
# How many unique races?
df$all_unique_entities_unique_races_N <- unlist(lapply(df$all_unique_entities_unique_races, function(x){length(x[is.na(x) == F])}))

# Unique mentions without presidential candidates
df$all_unique_entities_no_pres <- lapply(df$all_unique_entities, function(x){x[substr(x, 1, 1) != "P"]})
df$all_unique_entities_no_pres[lapply(df$all_unique_entities_no_pres, length) == 0] <- ""
# Get the races of the ad's unique entities
df$all_unique_entities_races_no_pres <- lapply(df$all_unique_entities_no_pres, function(x){cands$office[match(x, cands$wmpid)]})
# Get the unique races
df$all_unique_entities_unique_races_no_pres <- lapply(df$all_unique_entities_races_no_pres, unique)
# How many unique races?
df$all_unique_entities_unique_races_N_no_pres <- unlist(lapply(df$all_unique_entities_unique_races_no_pres, function(x){length(x[is.na(x) == F])}))


# ----
# Geo matches
# Note that the results are only reliable for ads that are actually in bucket 3.2.2.x

# Extract regional impressions (state & percentage)
# Start extracting the state from region distribution
df$region_distribution <- 
  df$region_distribution %>%
  str_replace_all("Washington, District of Columbia", "Washington District of Columbia") %>% 
  str_remove_all('\\"') %>% 
  str_remove_all('percentage:') %>% 
  str_remove_all(',region') %>% 
  str_remove_all('\\[|\\]|\\{|\\}')

# Split regions
tmp <- str_split(df$region_distribution, ",")
# For each region, split the percentage and the region name
tmp <- lapply(tmp, str_split_fixed, ":", n = 2)
# Only keep regions that are states
# the ,,drop = F avoids converting one-row matrices into vectors
# the first comma is for the subsetting, the second to specify arguments
tmp <- lapply(tmp, function(x){x[x[,2] %in% state.name,,drop = F]})
# Put each column of the resulting into the respective column in the dataframe
df$region_pct <- lapply(tmp, function(x){x[,1]})
df$region_distribution <- lapply(tmp, function(x){x[,2]})
# Convert state names to state abbreviations
df$region_distribution <- lapply(df$region_distribution, function(x){state.abb[match(x, state.name)]})

# States of mentioned entities (without presidential candidates)
df$entities_states <- 
  lapply(df$all_unique_entities_unique_races_no_pres, substr, 1, 2) %>%
  lapply(unique)

# For each state in the region distribution
# check whether it is contained in the states of the mentioned entities
# And what it's position in that vector is
check <- map2(df$region_distribution, df$entities_states, function(x,y){match(x, y)})
# Only keep the non-NAs
check2 <- lapply(check, function(x){x[is.na(x) == F]})
# Races with overlap
df$matched_mentions <- map2(df$all_unique_entities_unique_races_no_pres, check2, function(x,y){x[y]})
# Set NAs to character(0), otherwise the next step sometimes works incorrectly
df$matched_mentions[is.na(df$matched_mentions)] <- list(as.character())
# How many of these are there?
df$state_matches <- unlist(lapply(check2, length))
# Add an indicator to the df for whether the ad has a match
df$state_match_binary <- ifelse(df$state_matches == 0, 0, 1)
# Impressions proportion of those races
check3 <- map2(df$entities_states, df$region_distribution, function(x,y){match(x, y)})
check3 <- lapply(check3, function(x){x[is.na(x) == F]})
df$matched_mentions_region_pct <- map2(df$region_pct, check3, function(x,y){x[y]})


# ----
# Buckets

df$bucket <- NA
df$bucket[df$wmp_spontype %in% c("campaign", "leadership PAC") & df$wmp_office %in% c("us house", "us senate")] <- "1"
df$bucket[df$wmp_office %in% c("down ballot", "governor")] <- "2"
df$bucket[is.na(df$bucket)] <- "3"
# Sub-buckets
df$sub_bucket <- df$bucket
df$sub_bucket[df$bucket == "3" & df$all_unique_entities_unique_races_N == 1] <- "3.1"
df$sub_bucket[df$bucket == "3" & df$all_unique_entities_unique_races_N == 0] <- "3.3"
df$sub_bucket[df$sub_bucket == "3" & df$all_unique_entities_unique_races_N_no_pres == 1] <- "3.2.1"
df$sub_bucket[df$sub_bucket == "3" & df$state_matches == 1] <- "3.2.2.1"
df$sub_bucket[df$sub_bucket == "3" & df$state_matches == 0] <- "3.2.2.3"
df$sub_bucket[df$sub_bucket == "3"] <- "3.2.2.2" # all remaining ones

# table(df$sub_bucket)

# ----
# Race of focus

# The following line correctly sets the race of focus for
# sub-buckets 3.2.2.1, and 3.2.2.2
df$race_of_focus <- map2(df$matched_mentions_region_pct, df$matched_mentions, function(x,y){y[which.max(x)]})
# Unlisting here requires a prior step, otherwise it crashes R
df$race_of_focus[unlist(lapply(df$race_of_focus, length)) == 0] <- NA
df$race_of_focus <- unlist(df$race_of_focus)
# Other buckets
df$race_of_focus[df$sub_bucket == "1"] <- df$office[df$sub_bucket == "1"]
df$race_of_focus[df$sub_bucket == "2"] <- "Downballot"
df$race_of_focus[df$sub_bucket == "3.1"] <- unlist(df$all_unique_entities_unique_races[df$sub_bucket == "3.1"])
df$race_of_focus[df$sub_bucket == "3.2.1"] <- unlist(df$all_unique_entities_unique_races_no_pres[df$sub_bucket == "3.2.1"])
df$race_of_focus[df$sub_bucket == "3.2.2.3"] <- "No race of focus"
df$race_of_focus[df$sub_bucket == "3.3"] <- "No race of focus"
# For bucket 3.2.2.1 and 3.2.2.2, get the proportions of the match
# Ignore the 'In FUN(X[[i]], ...) : no non-missing arguments, returning NA' warning
df$race_of_focus_region_pct <- unlist(lapply(df$matched_mentions_region_pct, max)) # Ignore the warnings
df$race_of_focus_region_pct[!df$sub_bucket %in% c("3.2.2.1", "3.2.2.2")] <- NA

if(textonly == F){
  # Use bzip2 compression because that was necessary for 2020 to keep it small enough for github
  save(df, file = path_out_rdata, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(df2, path_out_csv)
}
if(textonly == T){
  # Use bzip2 compression because that was necessary for 2020 to keep it small enough for github
  save(df, file = path_out_rdata_textonly, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(df2, path_out_csv_textonly)
}

# This should ideally be empty
table(df$sub_bucket[is.na(df$race_of_focus)])
