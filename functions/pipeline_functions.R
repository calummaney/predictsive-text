#Step 1: load and filter PREDICTS data

#Syntax:
# e_var = embedding data

#Test prep
loadBDdata <- function(path = "input-data/diversity_public.rds"){
  div <- readRDS(path) |>
    transmute(
      Source_ID,
      SSBS,
      LandUse = Predominant_land_use,
      Habitat_as_described,
      location = UN_subregion,
      ecoregion = Ecoregion
    ) |> unique.data.frame() |>
    mutate(site_text = paste0(LandUse, " in ",location,". ",Habitat_as_described," in the ",ecoregion,"."))
  
  return(div)
}

#Step 2: embed land use classes + site descriptions


getSiteEmbeddings <- function(sites){
  text::textrpp_initialize(condaenv = "textrpp_reticulate")
  
  unique_siteTexts <- sites$site_text |> unique()
  
  siteTexts_classes <- data.frame(site_text = unique_siteTexts) |>
    left_join(sites,by="site_text") |>
    transmute(
      SSBS,
      site_text,
      LandUse
    ) |>
    unique.data.frame()
  
  rownames(siteTexts_classes) <- NULL
  
  e_siteText <- textEmbed(unique_siteTexts,
                          model = "bert-base-uncased",
                          device = "gpu",
                          aggregation_from_layers_to_tokens = "mean",
                          aggregation_from_tokens_to_texts = "mean",
                          mtry = length(unique_LocalTexts))
  
  testDF <- e_siteText[["texts"]][["texts"]]
  testDF$LandUse <- siteTexts_classes$LandUse
  
  #Bind unique descriptions back to the site data for export
  e_sites <- sites |> 
    left_join(cbind(siteTexts_classes,testDF), by = "site_text")
  
  #Check if the embeddings + descriptions are decent at picking back out the LU class (in the description)
  rf_check <- party::cforest(LandUse ~., data = testDF)
  testDF$predClassRF <- predict(rf_check)
  table(testDF$LandUse,testDF$predClassRF)
  
  return(
    list(
      embeddings = e_sites,
      trained_rf = rf_check
    )
  )
}


#Step 3: get local, spatiotemporal site descriptions
getLocalSiteData_iNat <- function(country = "Belize",nPerYear = 1000){
  #Get the admin bounds of the place you chose
  bounds <- rnaturalearth::ne_countries() |> filter(admin == country) |> select(admin)
  
  #Get all iNat observations from that country between 2017 and 2024 (max 10k per year)
  iNat_obs <- lapply(2017:2024,function(x){rinat::get_inat_obs(bounds = bounds,year = x,maxresults = nPerYear)}) |> bind_rows()
  
  #Filter to only observations with descriptions over a certain length
  iNat_obs_desc <- iNat_obs |> 
    filter(!is.na(description) & description != "" & nchar(description) > 40) |>
    filter(captive_cultivated != "true")
  
  return(iNat_obs_desc)
}

#Step3alt: load existing local site description data
getExistingLocalData <- function(csvFile = "input-data/copyOf_CT_belizeSites.csv",descColumn = "Description"){
  localSites <- read.csv(csvFile)
  
  localSiteDescs <- localSites[[descColumn]]
  
  #If missing geodata, add a placeholder for later
  if(is.null(localSites[["latitude"]])){
    localSites$latitude <- 0.00
    localSites$longitude <- 0.00
  }
  
  localSites <- localSites |>
    transmute(
      latitude,
      longitude,
      description = Description
    )
  
  return(localSites)
}

#Step 4: embed the locally-sourced descriptions
getLocalSiteEmbeddings <- function(localNatData){
  #Need to initialise python environment on the worker (?)
  text::textrpp_initialize(condaenv = "textrpp_reticulate")
  
  uniqueLocalSites <- localNatData |> transmute(latitude,longitude,description)
  
  unique_LocalTexts <- uniqueLocalSites$description
  
  e_localSiteText <- textEmbed(unique_LocalTexts,
                          model = "bert-base-uncased",
                          device = "gpu",
                          aggregation_from_layers_to_tokens = "mean",
                          aggregation_from_tokens_to_texts = "mean",
                          mtry = length(unique_LocalTexts))
  
  return(e_localSiteText)
}

#Step 5: classify the sites into their closest-matching PREDICTS category

predictPREDICTSclasses <- function(sites,localNatData,siteEmbeddings,localSiteEmbeddings){
  unique_siteTexts <- sites$site_text
  
  siteTexts_classes <- data.frame(site_text = unique_siteTexts, LandUse = sites$LandUse)
  
  rownames(siteTexts_classes) <- NULL
  
  testDF <- siteEmbeddings$embeddings[["texts"]][["texts"]]
  testDF$LandUse <- siteTexts_classes$LandUse
  
  localDF <- localSiteEmbeddings[["texts"]][["texts"]]
  localDF$LandUse <- "Local site data"
  
  #Test a PCA visualisation (for interest)
  allDF <- rbind(testDF |> mutate(origin = "db") |> mutate(ID = row_number()),localDF |> mutate(origin = "local") |> mutate(ID = row_number()))
  
  pca_e_siteText <- prcomp(allDF |> select(-c(LandUse,origin,ID)))
  visDF <- pca_e_siteText$x |> data.frame() |> select(PC1:PC10)
  visDF$LandUse <- allDF$LandUse
  visDF$origin <- allDF$origin
  visDF$ID <- allDF$ID
  ggplot(data = visDF) +
    geom_point(aes(x = PC1, y = PC2,color = LandUse),size=5)
  
  
  
  #Select local site data with PCA values within the bounds of our site data
  
  visDF_PC1_siteMin <- min(visDF$PC1[visDF$origin == "db"])
  visDF_PC1_siteMax <- max(visDF$PC1[visDF$origin == "db"])
  
  visDF_PC2_siteMin <- min(visDF$PC2[visDF$origin == "db"])
  visDF_PC2_siteMax <- max(visDF$PC2[visDF$origin == "db"])
  
  visDF_PC3_siteMin <- min(visDF$PC3[visDF$origin == "db"])
  visDF_PC3_siteMax <- max(visDF$PC3[visDF$origin == "db"])
  
  visDF <- visDF |>
    mutate(check =
      PC1 <= visDF_PC1_siteMax &
      PC2 <= visDF_PC2_siteMax &
      PC3 <= visDF_PC3_siteMax &
      PC1 >= visDF_PC1_siteMin &
      PC2 >= visDF_PC2_siteMin &
      PC3 >= visDF_PC3_siteMin
           )
  
  localDF_inBounds <- allDF[allDF$origin=="local" & visDF$check==TRUE,]

  localDF_inBounds$predLandUse = predict(
    object = siteEmbeddings$trained_rf,
    newdata = localDF_inBounds |> select(-LandUse,-origin)
    )
  
  origDescs <- localNatData |> transmute(latitude,longitude,description) |> unique.data.frame() |> pull(description)
  
  localDF_inBounds$originalDesc <- origDescs[localDF_inBounds$ID]
  
  return(localDF_inBounds)
}

#Step 6: extract satellite embeddings for the georeferenced, classified sites

#Step 7: Classify the entire local area with the classified site data

#Step 8: Attach any more ancillary data as necessary (e.g., HPD)

#Step 9: Apply biodiversity models to the classified site data