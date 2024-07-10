library(data.table)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)
library(haven)

# Option to use only the text-based fields to decide race of focus
# Set to False by default
textonly <- F

# Input files
path_google_2020_vars <- "../datasets/google/google_2020_adid_var1.csv.gz"
path_el_results <- "../entity_linking/google/data/entity_linking_results_google_2020_notext_combined.csv.gz"
path_wmpent <- "../datasets/wmp_entity_files/Google/2020/wmp_google_entities_v040521.dta"
path_cand <- "../datasets/candidates/cand2020_05192022.csv"
path_cand_pol <- "../datasets/candidates/face_url_politician.csv"
# Output files
path_out_rdata <- "data/race_of_focus_google_2020.rdata"
path_out_rdata_textonly <- "data/race_of_focus_google_2020_textonly.rdata"
path_out_csv <- "data/race_of_focus_google_2020.csv"
path_out_csv_textonly <- "data/race_of_focus_google_2020_textonly.csv"

# Read Google 2020 variables file
df <- fread(path_google_2020_vars, encoding = "UTF-8") %>%
  select(ad_id, advertiser_id, geo_targeting_included_02142022, aws_face)
full_size <- nrow(df)

# Add in entity linking results directly from the EL repo
el <- fread(path_el_results)
el <- el[match(df$ad_id, el$ad_id),]
df$detected_entities <- el$detected_entities

# WMP entities file
wmp_ents <- read_dta(path_wmpent)
# Keep only relevant columns
wmp_ents <- wmp_ents %>% 
  select(advertiser_id, wmp_spontype, wmp_office, pres_fecid, hse_fecid, sen_fecid)
wmp_ents$fecid_formerge <- wmp_ents$pres_fecid
wmp_ents$fecid_formerge[wmp_ents$fecid_formerge == ""] <- wmp_ents$sen_fecid[wmp_ents$fecid_formerge == ""]
wmp_ents$fecid_formerge[wmp_ents$fecid_formerge == ""] <- wmp_ents$hse_fecid[wmp_ents$fecid_formerge == ""]
wmp_ents <- wmp_ents %>% 
  select(advertiser_id, wmp_spontype, wmp_office, fecid_formerge)
# Merge with candidates file for district
cands <- fread(path_cand) %>%
  select(fec_id, office) %>%
  # Remove duplicate row (Jake Laturner)
  filter(!duplicated(.))
wmp_ents <- wmp_ents %>% left_join(cands, c("fecid_formerge" = "fec_id"))
# Then merge into 1.40m
df <- df %>% left_join(wmp_ents, "advertiser_id")


# ----
# Mentions

if(textonly == F){
  # Combine mentions and appearances
  df$all_entities <- 
    paste(df$detected_entities, df$aws_face, sep = ",") %>%
    str_remove(",$") %>%
    str_split(",") %>%
    lapply(str_trim)
  df <- df %>% select(-c(detected_entities, aws_face))
}
if(textonly == T){
  # Combine mentions and appearances
  df$all_entities <- 
    df$detected_entities %>%
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

# Extract regional impressions (states)
df$region_distribution <- str_remove_all(df$geo_targeting_included_02142022, "\\-[0-9]+")
df$region_distribution <- str_split(df$region_distribution, ",")

normalize_regions <- function(x){
  detected_abbs <- state.abb[match(x[x %in% state.name], state.name)]
  x[x %in% state.name] <- detected_abbs
  x <- unique(x[x %in% state.abb])
  return(x)
}
df$region_distribution <- lapply(df$region_distribution, normalize_regions)

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
#df$matched_mentions_region_pct <- map2(df$region_pct, check3, function(x,y){x[y]})


# ----
# Buckets

df$bucket <- NA
df$bucket[df$wmp_spontype %in% c("campaign", "leadership PAC") & df$wmp_office %in% c("president", "us house", "us senate")] <- "1"
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
# df$race_of_focus <- map2(df$matched_mentions_region_pct, df$matched_mentions, function(x,y){y[which.max(x)]})
# Unlisting here requires a prior step, otherwise it crashes R
# df$race_of_focus[unlist(lapply(df$race_of_focus, length)) == 0] <- NA
# df$race_of_focus <- unlist(df$race_of_focus)
# Other buckets
df$race_of_focus <- NA
df$race_of_focus[df$sub_bucket == "1"] <- df$office[df$sub_bucket == "1"]
df$race_of_focus[df$sub_bucket == "2"] <- "Downballot"
df$race_of_focus[df$sub_bucket == "3.1"] <- unlist(df$all_unique_entities_unique_races[df$sub_bucket == "3.1"])
# df$race_of_focus[df$sub_bucket == "3.2.1"] <- unlist(df$all_unique_entities_unique_races_no_pres[df$sub_bucket == "3.2.1"])
# df$race_of_focus[df$sub_bucket == "3.2.2.3"] <- "No race of focus"
df$race_of_focus[df$sub_bucket == "3.3"] <- "No race of focus"
# For bucket 3.2.2.1 and 3.2.2.2, get the proportions of the match
# Ignore the 'In FUN(X[[i]], ...) : no non-missing arguments, returning NA' warning
# df$race_of_focus_region_pct <- unlist(lapply(df$matched_mentions_region_pct, max)) # Ignore the warnings
# df$race_of_focus_region_pct[!df$sub_bucket %in% c("3.2.2.1", "3.2.2.2")] <- NA

if(textonly == F){
  # Use bzip2 compression to sneak it under the 100Mb mark (otherwise its 105mb, this way it's 73mb)
  save(df, file = path_out_rdata, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus)#, race_of_focus_region_pct)
  fwrite(df2, path_out_csv)
}
if(textonly == T){
  # Use bzip2 compression to sneak it under the 100Mb mark (otherwise its 105mb, this way it's 73mb)
  save(df, file = path_out_rdata_textonly, compress = "bzip2")
  df2 <- df %>% select(ad_id, sub_bucket, race_of_focus, race_of_focus_region_pct)
  fwrite(df2, path_out_csv_textonly)
}