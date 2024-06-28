library(shiny)
library(dplyr)
library(DT)
library(shinythemes)
library(shinyWidgets)
library(validate)
library(digest)
library(data.table)
library(bs4Dash)
library(ckanr)
library(purrr)
library(shinyjs)
library(sentimentr)
library(listviewer)
library(RCurl)
library(readxl)
library(stringr)
library(openxlsx)
library(config)
library(aws.s3)
library(One4All)
library(mongolite)

config <- config::get(file = "example_config.yml")

#Data checks ----

mongo_collection = config$mongo_collection
mongo_key = config$mongo_key 

# Check for duplicates
pull_data <- function(request = '{"samples.SampleID": 1}') {
    # Connect to MongoDB
    conn <- mongo(collection = mongo_collection, url = mongo_key)
    
    # Find all documents in the collection
    conn$find('{}', request)[-1] |> unlist() |> unique()
}

if(isTruthy(config$mongo_key)) {
    database <- mongo(url = config$mongo_key, collection = config$mongo_collection)
} 

if(isTruthy(config$s3_secret_key)){
    Sys.setenv(
        "AWS_ACCESS_KEY_ID" = config$s3_key_id,
        "AWS_SECRET_ACCESS_KEY" = config$s3_secret_key,
        "AWS_DEFAULT_REGION" = config$s3_region
    )
}


# Options ----
options(shiny.maxRequestSize = 1000*1024^2)

