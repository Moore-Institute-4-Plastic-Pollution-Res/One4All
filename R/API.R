library(httr)
library(jsonlite)

query_mongodb_api <- function(collection, database, dataSource, apiKey, objectId) {
    # Construct the URL
    url <- 'https://us-west-2.aws.data.mongodb-api.com/app/data-crrct/endpoint/data/v1/action/findOne'
    
    # Set up headers
    headers <- c(
        'Content-Type' = 'application/json',
        'Access-Control-Request-Headers' = '*',
        'api-key' = apiKey
    )
    
    # Create the body of the request
    body <- list(
        collection = collection,
        database = database,
        dataSource = dataSource,
        projection = list("_id" = 1)  # Adjust projection as needed
    )
    
    # Make the POST request
    response <- POST(url, add_headers(.headers = headers), body = body, encode = "json")
    
    # Check the response
    result <- content(response, "parsed")
    
    return(result)
}

# Example usage
apiKey <- 'oHUi48HmGj7wNFapFJNI6Wj7upVNbPKzksNNbl7hizWtQaym4loFn7YlMtfIKJpZ'
objectId <- '6527260827276a6fca07bba1'

result <- query_mongodb_api(
    collection = 'MongoDB1',
    database = 'test',
    dataSource = 'Cluster0',
    apiKey = apiKey,
    objectId = objectId
)

print(result)