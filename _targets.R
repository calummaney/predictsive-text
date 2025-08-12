# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)


# Set target options:
tar_option_set(
  packages = c("tidyverse","text","rinat","rnaturalearth","party"), # Packages that your targets need for their tasks.
  format = "qs", # Optionally set the default storage format. qs is fast.
  controller = crew::crew_controller_local(workers = 3, seconds_idle = 60)
)

# Run the R scripts in the R/ folder with your custom functions:
tar_source("functions")

# Replace the target list below with your own:
list(
  tar_target(
    name = sites,
    command = loadBDdata()
  ),
  tar_target(
    name = siteEmbeddings,
    command = getSiteEmbeddings(sites)
  ),
  tar_target(
    name = localNatData,
    command = getLocalSiteData_iNat(country = "Ghana",nPerYear = 1000) #getExistingLocalData()
  ),
  tar_target(
    name = localSiteEmbeddings,
    command = getLocalSiteEmbeddings(localNatData)
  ),
  tar_target(
    name = predictedPREDICTSclasses,
    command = predictPREDICTSclasses(sites,localNatData,siteEmbeddings,localSiteEmbeddings)
  )
)