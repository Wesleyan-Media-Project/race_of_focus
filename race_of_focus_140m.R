library(data.table)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)

# Option to use only the text-based fields or only the image-based fields to decide race of focus
# can be 'text', 'image', and 'text_image' (default)
medium <- "text_image"

# Input files

# Output from fb_2020 repo
path_140m_vars <- "../fb_2020/fb_2020_140m_adid_var1.csv.gz"

path_el_results <- "../entity_linking/facebook/data/entity_linking_results_140m_notext_combined.csv.gz"
path_wmpent <- "../datasets/wmp_entity_files/Facebook/2020/wmp_fb_entities_v090622.csv"
path_cand <- "../datasets/candidates/cand2020_05192022.csv"
path_cand_pol <- "../datasets/candidates/face_url_politician.csv"
# Output files
path_out_rdata <- "data/race_of_focus_140m.rdata"
path_out_rdata_textonly <- "data/race_of_focus_140m_textonly.rdata"
path_out_rdata_imageonly <- "data/race_of_focus_140m_imageonly.rdata"
path_out_csv <- "data/race_of_focus_140m.csv"
path_out_csv_textonly <- "data/race_of_focus_140m_textonly.csv"
path_out_csv_imageonly <- "data/race_of_focus_140m_imageonly.csv"

# Read 1.40m variables file
df <- fread(path_140m_vars, encoding = "UTF-8") %>%
  select(ad_id, pd_id, region_distribution, aws_face)
full_size <- nrow(df)

# remove semicolons, delete this once Jielu fixes it
df$aws_face <- str_replace_all(df$aws_face, ";", ",")

# Add in entity linking results directly from the EL repo
el <- fread(path_el_results)
el <- el[match(df$ad_id, el$ad_id),]
df$detected_entities <- el$detected_entities

# WMP entities file
wmp_ents <- fread(path_wmpent)
# Keep only relevant columns
wmp_ents_all <- wmp_ents
wmp_ents <- wmp_ents %>% 
  select(pd_id, wmp_spontype, wmp_office_post090120, fecid_formerge)
# Merge with candidates file for district
cands <- fread(path_cand) %>%
  select(fec_id, office) %>%
  # Remove duplicate row (Jake Laturner)
  filter(!duplicated(.))
wmp_ents <- wmp_ents %>% left_join(cands, c("fecid_formerge" = "fec_id"))

# Add office for candidates who aren't in the candidate file, but have an office in the WMP entity file
wmp_ents_all$office <- paste0(wmp_ents_all$hse_state, str_pad(wmp_ents_all$hse_district, 2, "left", "0"))
wmp_ents_all$office[(is.na(wmp_ents_all$sen_state) == F) & wmp_ents_all$sen_state != ""] <- paste0(wmp_ents_all$sen_state, "S0")[(is.na(wmp_ents_all$sen_state) == F) & wmp_ents_all$sen_state != ""]
wmp_ents_all$office[wmp_ents_all$wmp_pres == 1] <- "PRES"
wmp_ents_all$office[wmp_ents_all$office == "NA"] <- NA
for(i in 1:nrow(wmp_ents)){
  if((wmp_ents$wmp_spontype[i] == "campaign") & (wmp_ents$wmp_office[i] %in% c("us house", "us senate", "president")) & is.na(wmp_ents$office[i])){
    wmp_ents$office[i] <- wmp_ents_all$office[match(wmp_ents$pd_id[i], wmp_ents_all$pd_id)]
  }
}

# Then merge into 1.40m
df <- df %>% left_join(wmp_ents, "pd_id")


# ----
# Mentions

if(medium == "text_image"){
  # Combine mentions and appearances
  df$all_entities <- 
    paste(df$detected_entities, df$aws_face, sep = ",") %>%
    str_remove(",$") %>%
    str_split(",") %>%
    lapply(str_trim)
  df <- df %>% select(-c(detected_entities, aws_face))
}
if(medium == "text"){
  # Combine mentions and appearances
  df$all_entities <- 
    df$detected_entities %>%
    str_remove(",$") %>%
    str_split(",") %>%
    lapply(str_trim)
  df <- df %>% select(-c(detected_entities, aws_face))
}
if(medium == "image"){
  # Combine mentions and appearances
  df$all_entities <- 
    df$aws_face %>%
    str_remove(",$") %>%
    str_split(",") %>%
    lapply(str_trim)
  df <- df %>% select(-c(detected_entities, aws_face))
}

# exclude scotus, former potus candidates, senators not up for reelection
pol <- fread(path_cand_pol)
df$all_entities <- 
  lapply(df$all_entities, function(x){x[!x %in% pol$fec_ids]}) %>%
  # if one of those people is the only one mentioned, 
  # it will be set to character(0), changing this to ""
  lapply(function(x){x[x != ""]})
rm(pol)
df$all_entities[unlist(lapply(df$all_entities, length)) == 0] <- ""

# Only unique entities within an ad
df$all_unique_entities <- lapply(df$all_entities, unique)
# Get the races of the ad's unique entities
df$all_unique_entities_races <- lapply(df$all_unique_entities, function(x){cands$office[match(x, cands$fec_id)]})
# Get the unique races
df$all_unique_entities_unique_races <- lapply(df$all_unique_entities_races, unique)
# How many unique races?
df$all_unique_entities_unique_races_N <- unlist(lapply(df$all_unique_entities_unique_races, function(x){length(x[is.na(x) == F])}))

# Unique mentions without presidential candidates
df$all_unique_entities_no_pres <- lapply(df$all_unique_entities, function(x){x[substr(x, 1, 1) != "P"]})
df$all_unique_entities_no_pres[lapply(df$all_unique_entities_no_pres, length) == 0] <- ""
# Get the races of the ad's unique entities
df$all_unique_entities_races_no_pres <- lapply(df$all_unique_entities_no_pres, function(x){cands$office[match(x, cands$fec_id)]})
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


# # Extract the percentage
# df$region_pct <- str_extract_all(df$region_distribution, "[0-9|\\.]+")
# # Finish extracting the state
# df$region_distribution <- 
#   df$region_distribution %>%
#   str_remove_all("[0-9|\\:|\\.]") %>%
#   str_split(",") %>%
#   lapply(function(x){state.abb[match(x, state.name)]}) %>%
#   lapply(unique)
# df$region_distribution <- lapply(df$region_distribution, function(x){x[is.na(x) == F]})

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
df$bucket[df$wmp_spontype %in% c("campaign", "leadership PAC") & df$wmp_office_post090120 %in% c("president", "us house", "us senate")] <- "1"
df$bucket[df$wmp_office_post090120 %in% c("down ballot", "governor")] <- "2"
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

if(medium == "text_image"){
  # Use bzip2 compression to sneak it under the 100Mb mark (otherwise its 105mb, this way it's 73mb)
  save(df, file = path_out_rdata, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(df2, path_out_csv)
}
if(medium == "text"){
  # Use bzip2 compression to sneak it under the 100Mb mark (otherwise its 105mb, this way it's 73mb)
  save(df, file = path_out_rdata_textonly, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(df2, path_out_csv_textonly)
}
if(medium == "image"){
  # Use bzip2 compression to sneak it under the 100Mb mark (otherwise its 105mb, this way it's 73mb)
  save(df, file = path_out_rdata_imageonly, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(df2, path_out_csv_imageonly)
}

# pdids for which race of focus is NA -- this won't work any more
#missing_rof <- unique(df$pd_id[is.na(df$race_of_focus)])
#writeLines(missing_rof, "data/pdids_for_which_race_of_focus_is_NA_2020.txt")

# This should ideally be empty
table(df$sub_bucket[is.na(df$race_of_focus)])
