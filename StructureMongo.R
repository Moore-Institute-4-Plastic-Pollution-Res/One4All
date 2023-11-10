# Connect to MongoDB
library(mongolite)
library(jsonlite)

mongo_conn <- mongo(collection = "MongoDB1", url = "mongodb+srv://hannah:Singinglove2019@cluster0.hzb0jlh.mongodb.net/?retryWrites=true&w=majority")

# Retrieve all records from MongoDB
all_records <- mongo_conn$find('{}')

# Create empty lists for the tables
methodology <- list()
particles <- list()
samples <- list()
certificate <- list()

# Iterate over all records
for (i in 1:length(all_records)) {
    # Extract fields for methodology, particles, samples, and certificates
    methodology_data <- all_records[i]$methodology
    particles_data <- all_records[i]$particles
    samples_data <- all_records[i]$samples
    certificates_data <- all_records[i]$certificate
    
    # Append entries to respective lists
    methodology <- c(methodology, methodology_data)
    particles <- c(particles, particles_data)
    samples <- c(samples, samples_data)
    certificate <- c(certificate, certificates_data)
}

# Create a new document with merged arrays
merged_document <- list(
    methodology = methodology,
    particles = particles,
    samples = samples,
    certificate = certificate,
    processed = TRUE
)

# Debugging: Print the merged document
print(merged_document)

# Insert the merged data into a new MongoDB document
insert_result <- mongo_conn$insert(merged_document)

# Debugging: Print the insert result
print(insert_result)

