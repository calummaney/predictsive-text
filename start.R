library(targets)
library(tidyverse)
library(text)

tar_visnetwork()

tar_make()

tar_meta(fields = error, complete_only = TRUE)

tar_load(sites)
tar_load(siteEmbeddings)
tar_load(localNatData)
tar_load(localSiteEmbeddings)


tar_load(predictedPREDICTSclasses)
