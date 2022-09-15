# Implements race_of_focus, as detailed here:
# https://docs.google.com/presentation/d/11E9kX1oVYfMooTdD1GAJfwJtdPIQpYB3lJ7i5e83ZEw/edit#slide=id.g12d57307ead_0_0

library(haven)
library(data.table)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)

# Input files
path_full118m <- "../118m/fb_2020_adid_02282022.csv"
path_wmpent <- "../datasets/wmp_entity_files/Facebook/2020/wmp_fb_entities_v051822.dta"
path_cand <- "../datasets/candidates/cand2020_05192022.csv"
path_cand_pol <- "../datasets/candidates/face_url_politician.csv"
# Output files
path_out_rdata <- "data/race_of_focus.rdata"
path_out_csv <- "data/race_of_focus.csv"

# Read full 1.18m file
df <- fread(path_full118m, encoding = "UTF-8") %>%
  select(ad_id, pd_id, page_name, region_distribution, detected_entities, aws_face)
full_size <- nrow(df)

# WMP entities file
wmp_ents <- read_dta(path_wmpent)
# Keep only relevant columns
wmp_ents <- wmp_ents %>% 
  select(pd_id, wmp_spontype, wmp_office_post090120, fecid_formerge)
# Merge with candidates file for district
cands <- fread(path_cand) %>%
  select(fec_id, office) %>%
  # Remove duplicate row (Jake Laturner)
  filter(!duplicated(.))
wmp_ents <- wmp_ents %>% left_join(cands, c("fecid_formerge" = "fec_id"))
# Then merge into 1.18m
df <- df %>% left_join(wmp_ents, "pd_id")


# ----
# Mentions

# Combine mentions and appearances
df$all_entities <- 
  paste(df$detected_entities, df$aws_face, sep = ",") %>%
  str_remove(",$") %>%
  str_split(",") %>%
  lapply(str_trim)
df <- df %>% select(-c(detected_entities, aws_face))

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
# Extract the percentage
df$region_pct <- str_extract_all(df$region_distribution, "[0-9|\\.]+")
# Finish extracting the state
df$region_distribution <- 
  df$region_distribution %>%
  str_remove_all("[0-9|\\:|\\.]") %>%
  str_split(",") %>%
  lapply(function(x){state.abb[match(x, state.name)]}) %>%
  lapply(unique)


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

save(df, file = path_out_rdata, compress = T)
df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
fwrite(df2, path_out_csv)
