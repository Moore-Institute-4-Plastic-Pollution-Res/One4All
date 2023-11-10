library(mongolite)

# Establish a connection to MongoDB
mongo1 <- mongo(collection = "MongoDB1", 
                url = "mongodb+srv://hannah:Singinglove2019@cluster0.hzb0jlh.mongodb.net/?retryWrites=true&w=majority")

# Convert the string to ObjectId within the query string
query <- '{"_id": {"$oid": "6526f71aa83ac8e88d0c2093"}}'

# Query data from MongoDB
result <- mongo1$find(query)

# Convert MongoDB data to R data frame
data_frame <- as.data.frame(result)

