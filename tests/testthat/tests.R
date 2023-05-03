library(testthat)

#Certificate df ----

test_that("certificate_df function returns a valid data frame", {
    x <- list(
        data_formatted = data.frame(a = 1:3, b = 4:6),
        rules = validator(a > 0, b > 0)
    )
    result <- certificate_df(x, mongo_key = FALSE)
    
    # Check if the result is a data frame
    expect_true(is.data.frame(result))
    
    # Check if the result has the correct columns
    expect_identical(colnames(result), c("time", "data", "rules", "package_version", "web_hash"))
    
    # Check if the result has the correct number of rows
    expect_equal(nrow(result), 1)
    
    # Check if the result has non-empty values for each column
    expect_true(all(!sapply(result, is.null)))
})



#Test the validate data function ----

# Helper function to create temporary files for testing
create_temp_file <- function(content, ext = ".csv") {
    tmp_file <- tempfile(fileext = ext)
    writeLines(content, tmp_file)
    return(tmp_file)
}

# Test data and rules files
test_data_csv <- "column1,column2\n1,2\n3,4"
test_rules_csv <- "name,description,severity,rule\nrule1,Test rule 1,low,column1 > 0"

test_that("validate_data returns an error for invalid file types", {
    invalid_file <- create_temp_file(test_data_csv, ext = ".txt")
    
    result <- validate_data(files_data = list(invalid_file), file_rules = invalid_file)
    expect_equal(result$status, "error")
})

test_that("validate_data returns an error for rules file with incorrect column names", {
    incorrect_rules_csv <- "name,description,severity,wrong_rule_column\nrule1,Test rule 1,low,column1 > 0"
    incorrect_rules_file <- create_temp_file(incorrect_rules_csv)
    
    result <- validate_data(files_data = list(create_temp_file(test_data_csv)), file_rules = incorrect_rules_file)
    expect_equal(result$status, "error")
})

test_that("validate_data returns an error for rules with sensitive words", {
    sensitive_rules_csv <- "name,description,severity,rule\nrule1,Test rule 1,low,config"
    sensitive_rules_file <- create_temp_file(sensitive_rules_csv)
    
    result <- validate_data(files_data = list(create_temp_file(test_data_csv)), file_rules = sensitive_rules_file)
    expect_equal(result$status, "error")
})

test_that("validate_data returns an error for rules file with incorrect column types", {
    incorrect_column_type_rules_csv <- "name,description,severity,rule\n1,Test rule 1,low,column1 > 0"
    incorrect_column_type_rules_file <- create_temp_file(incorrect_column_type_rules_csv)
    
    result <- validate_data(files_data = list(create_temp_file(test_data_csv)), file_rules = incorrect_column_type_rules_file)
    expect_equal(result$status, "error")
})

test_that("validate_data returns an error for rules file with incorrect dataset names", {
    incorrect_dataset_rules_csv <- "name,description,severity,rule,dataset\nrule1,Test rule 1,low,column1 > 0,WrongDataset"
    incorrect_dataset_rules_file <- create_temp_file(incorrect_dataset_rules_csv)
    
    result <- validate_data(files_data = list(create_temp_file(test_data_csv)), data_names = c("CorrectDataset"), file_rules = incorrect_dataset_rules_file)
    expect_equal(result$status, "error")
})

#Remote share ----

# Test case 1: Check if remote_share returns an error when no upload methods are specified
test_that("No upload methods specified error", {
    result <- remote_share(validation, data_formatted, verified, valid_rules, valid_key,
                           ckan_url = NULL, ckan_key = NULL, ckan_package = NULL,
                           url_to_send, rules, results, s3_key_id = NULL, s3_secret_key = NULL, s3_region = NULL, 
                           s3_bucket = NULL, mongo_key = NULL, old_cert = NULL)
    
    expect_equal(result$status, "error")
    expect_equal(result$message$title, "No upload methods available")
}) #Could use some better tests here. 

#Rules broken ----

# Sample validation results data frame
sample_results <- data.frame(
    description = c("Rule 1", "Rule 2", "Rule 3"),
    status = c("error", "success", "error"),
    name = c("rule1", "rule2", "rule3"),
    expression = c("col1 > 0", "col2 <= 5", "col3 != 10"),
    stringsAsFactors = FALSE
)

# Test case 1: Check if rules_broken returns only errors when show_decision is FALSE
test_that("rules_broken returns only errors", {
    broken_rules <- rules_broken(sample_results, show_decision = FALSE)
    expect_equal(nrow(broken_rules), 3)
    expect_equal(broken_rules$status, c("error", "success", "error"))
})

# Test case 2: Check if rules_broken returns both errors and successes when show_decision is TRUE
test_that("rules_broken returns errors and successes", {
    broken_rules <- rules_broken(sample_results, show_decision = TRUE)
    expect_equal(nrow(broken_rules), 2)
    expect_equal(broken_rules$status, c("error", "error"))
})

#Rows for rules ----

# Sample data
sample_data <- data.frame(
    col1 = c(1, -2, 3, -4, 5),
    col2 = c(6, 7, 8, 9, 10)
)

# Validation rules
rules <- validator(
    col1 > 0,
    col2 <= 9
)

# Generate a validation report
report <- confront(sample_data, rules)

# Find the broken rules
results <- summary(report) %>%
    mutate(status = ifelse(fails > 0 | error | warning , "error", "success")) %>%
    mutate(description = "test")

broken_rules <- rules_broken(results, show_decision = FALSE)

# Test case 1: Check if rows_for_rules returns the correct violating rows
test_that("rows_for_rules returns violating rows", {
    violating_rows <- rows_for_rules(sample_data, report, broken_rules, c(1,2))
    expect_equal(nrow(violating_rows), 3)
    expect_equal(violating_rows$col1, c(-2, -4, 5))
    expect_equal(violating_rows$col2, c(7, 9, 10))
})

#Check Luhn ----
test_that("checkLuhn returns correct results", {
    # Test case 1: Valid Luhn number
    expect_true(checkLuhn("4532015112830366"))
    
    # Test case 2: Invalid Luhn number
    expect_false(checkLuhn("4532015112830367"))
    
    # Test case 3: Non-numeric input
    expect_false(checkLuhn("ABC123"))
    
    # Test case 4: Number with spaces and dashes
    expect_true(checkLuhn("4532 0151-1283 0366"))
    
    # Test case 5: Number with less than 2 digits
    expect_false(checkLuhn("1"))
})


#Check images ----

test_that("check_images returns correct results", {
# Test case 1: Valid PNG image URL
expect_equal(
    check_images("https://example.com/image.png"),
    '<img src ="https://example.com/image.png" height = "50"></img>'
)

# Test case 2: Valid JPG image URL
expect_equal(
    check_images("https://example.com/image.jpg"),
    '<img src ="https://example.com/image.jpg" height = "50"></img>'
)

# Test case 3: Invalid image URL
expect_equal(
    check_images("https://example.com/text"),
    "https://example.com/text"
)

# Test case 4: Empty input
expect_equal(
    check_images(""),
    ""
)
})


#Check hyperlinks ----
test_that("check_other_hyperlinks returns correct results", {
    # Test case 1: Valid non-image hyperlink
    expect_equal(
        check_other_hyperlinks("https://example.com/page"),
        '<a href ="https://example.com/page">https://example.com/page</a>'
    )
    
    # Test case 2: PNG image URL
    expect_equal(
        check_other_hyperlinks("https://example.com/image.png"),
        "https://example.com/image.png"
    )
    
    # Test case 3: JPG image URL
    expect_equal(
        check_other_hyperlinks("https://example.com/image.jpg"),
        "https://example.com/image.jpg"
    )
    
    # Test case 4: Non-https URL
    expect_equal(
        check_other_hyperlinks("http://example.com/page"),
        "http://example.com/page"
    )
    
    # Test case 5: Empty input
    expect_equal(
        check_other_hyperlinks(""),
        ""
    )
})

#Profanity ----
test_that("test_profanity returns correct results", {
    
    profane_string <- profanity_banned[1]
    clean_string <- "This is a clean sentence."
    # Test case 1: Clean sentence
    expect_true(test_profanity(clean_string))
    
    # Test case 2: Sentence containing profanity
    # Replace 'badword' with an actual profane word for this test to work
    expect_false(test_profanity(profane_string))
    
    # Test case 3: Empty input
    expect_true(test_profanity(""))
    
    # Test case 4: Non-alphabetic characters
    expect_true(test_profanity("1234567890!@#$%^&*()"))
    
})

#Excel formatter ----

# Load your create_valid_excel function here

test_that("create_valid_excel creates a valid Excel file", {
    # Validation rules as a data frame
    validation_rules <- data.frame(
        name = c("MethodologyID_valid", "SamplingDevice", "AirFiltration",
                 "ParticleID_blank", "ParticleID"),
        description = c("URL address is valid and can be found on the internet.",
                        "Device used to collect sample and dimensions",
                        "Is there HEPA air filtration system in the lab?",
                        "Unique ID for each particle cannot be blank",
                        "Unique ID for each particle must be unique"),
        dataset = c("methodology", "methodology", "methodology",
                    "particles", "particles"),
        valid_example = c("https://example.com", "10 L Glass Jar", "Yes",
                          "1_23jreh334", "1_23jreh334"),
        severity = c("error", "error", "error", "error", "error"),
        rule = c("check_uploadable(MethodologyID) == TRUE", "!is.na(SamplingDevice)",
                 "AirFiltration %in% c(\"Yes\", \"No\")",
                 "!is.na(ParticleID)", "is_unique(ParticleID)")
    )
    
    temp_file_rules_csv <- tempfile(fileext = ".csv")
    write.csv(validation_rules, temp_file_rules_csv, row.names = FALSE)
    
    # Create the Excel file
    output_file <- "test_output.xlsx"
    create_valid_excel(temp_file_rules_csv, file_name = output_file) #TODO: Has warnings, perhaps add some example datasets and rules from water pact
    
    # Check if the file exists
    expect_true(file.exists(output_file))
    
    # Load the created Excel file
    wb <- loadWorkbook(output_file)
    
    # Check the presence of worksheets
    expect_equal(length(sheets(wb)), 4)
    expect_true("Rules" %in% sheets(wb))
    expect_true("methodology" %in% sheets(wb))
    expect_true("particles" %in% sheets(wb))
    expect_true("Lookup" %in% sheets(wb))
    
    # Perform additional checks on the worksheets as needed
    
    # Clean up: delete the output file
    file.remove(output_file)
})

#remote_download ----
context("remote_download tests")

# Add your setup code here if needed
# This code will run before all the tests in this file

# Test for successful data download
test_that("remote_download successfully downloads data", {
    # Setup the remote sources and hashed_data for testing
    # Be cautious with real credentials and consider using a separate set of credentials for testing purposes
    
    hashed_data <- "example_hash"
    ckan_url <- "https://example.com"
    ckan_key <- "your_ckan_key"
    ckan_package <- "your_ckan_package"
    s3_key_id <- "your_s3_key_id"
    s3_secret_key <- "your_s3_secret_key"
    s3_region <- "your_s3_region"
    s3_bucket <- "your_s3_bucket"
    mongo_key <- "your_mongo_key"
    
    # Run the remote_download function
    downloaded_data <- remote_download(hashed_data = hashed_data,
                                       ckan_url = ckan_url,
                                       ckan_key = ckan_key,
                                       ckan_package = ckan_package,
                                       s3_key_id = s3_key_id,
                                       s3_secret_key = s3_secret_key,
                                       s3_region = s3_region,
                                       s3_bucket = s3_bucket,
                                       mongo_key = mongo_key)
    
    # Test that the downloaded_data is a list
    expect_is(downloaded_data, "list")
    
    # Test that the downloaded_data has the expected length
    expect_length(downloaded_data, length_of_expected_data) # Replace length_of_expected_data with the expected length
})

#Posixct test ----
test_that("is.POSIXct works correctly", {
    # Test with POSIXct object
    posixct_obj <- as.POSIXct("2021-01-01")
    expect_true(is.POSIXct(posixct_obj))
    
    # Test with Date object
    date_obj <- Sys.Date()
    expect_false(is.POSIXct(date_obj))
    
    # Test with character object
    char_obj <- "2021-01-01"
    expect_false(is.POSIXct(char_obj))
    
    # Test with numeric object
    num_obj <- 42
    expect_false(is.POSIXct(num_obj))
})

#Test locally only ----
test_that("remote_download retrieves identical data from all sources", {
    # Load the required configuration
    config <- config::get(file = "G:/My Drive/MooreInstitute/Projects/PeoplesLab/Code/One4All/inst/shiny/config.yml")
    
    # Load the necessary datasets
    data("valid_example")
    data("invalid_example")
    data("test_rules")
    
    # Perform the validation
    result_valid <- validate_data(files_data = valid_example,
                                  data_names = c("methodology", "particles", "samples"),
                                  file_rules = test_rules)
    
    # Perform the remote share
    test_remote <- remote_share(validation = result_valid, 
                                data_formatted = result_valid$data_formatted, 
                                verified = config$valid_key, 
                                valid_key = config$valid_key, 
                                valid_rules = config$valid_rules, 
                                ckan_url = config$ckan_url, 
                                ckan_key = config$ckan_key, 
                                ckan_package = config$ckan_package, 
                                url_to_send = config$ckan_url_to_send, 
                                rules = test_rules, 
                                results = valid_example$results, 
                                s3_key_id = config$s3_key_id, 
                                s3_secret_key = config$s3_secret_key, 
                                s3_region = config$s3_region, 
                                s3_bucket = config$s3_bucket, 
                                mongo_key = config$mongo_key, 
                                old_cert = NULL)
    
    # Download the data using remote_download
    dataset <- remote_download(hashed_data = test_remote$hashed_data, 
                               ckan_url = config$ckan_url, 
                               ckan_key = config$ckan_key, 
                               ckan_package = config$ckan_package,
                               s3_key_id = config$s3_key_id,
                               s3_secret_key = config$s3_secret_key,
                               s3_region = config$s3_region,
                               s3_bucket = config$s3_bucket,
                               mongo_key = config$mongo_key)
    
    # Compare datasets from different sources
    expect_identical(dataset$s3$certificate, dataset$ckan$certificate)
    expect_identical(dataset$s3$methodology, dataset$ckan$methodology)
    expect_identical(dataset$s3$samples, dataset$ckan$samples)
    expect_identical(dataset$s3$particles, dataset$ckan$particles)
    expect_identical(dataset$s3$particles, dataset$mongo$particles)
    expect_identical(dataset$s3$certificate, dataset$mongo$certificate)
    expect_identical(dataset$s3$methodology, dataset$mongo$methodology) 
    expect_identical(dataset$s3$samples, dataset$mongo$samples)
})


# Add more test cases as needed

