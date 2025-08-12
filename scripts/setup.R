library(targets)
library(text)
library(reticulate)

#First time only
use_targets()

#NOT RUN, I use a custom Conda environment with manually installed dependencies, as the one this made didn't work.
#textrpp_install_(envname = "text-torch")


reticulate::conda_create("textrpp_reticulate", packages = "python=3.9")
reticulate::use_condaenv("textrpp_reticulate")

#LOAD packages into my environment
rpp_packages <- c(
  "torch==2.2.0",
  "transformers==4.38.0",
  "huggingface_hub==0.20.0",
  "numpy==1.26.0",
  "pandas==2.0.3",
  "nltk==3.8.1",
  "scikit-learn==1.3.0",
  "datasets==2.16.1",
  "evaluate==0.4.0",
  "accelerate==0.26.0",
  "bertopic==0.16.3",
  "jsonschema==4.19.2",
  "sentence-transformers==2.2.2",
  "flair==0.13.0",
  "umap-learn==0.5.6",
  "hdbscan==0.8.33",
  "scipy==1.10.1",
  "aiohappyeyeballs==2.4.4"
)

reticulate::conda_install("textrpp_reticulate", packages = rpp_packages, pip = TRUE)

# Initialize the installed conda environment.
# save_profile = TRUE saves the settings so that you don't have to run textrpp_initialize() after restarting R. 
text::textrpp_initialize(condaenv = "textrpp_reticulate", save_profile = TRUE)

# Test so that the text package work.
textEmbed("hello")
