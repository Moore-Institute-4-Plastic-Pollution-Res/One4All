library(testthat)

# Read rules ----
temp_dir <- tempdir()
temp_csv_path <- file.path(temp_dir, "test_rules.csv")

test_that("read_rules correctly reads a CSV file", {
    
    test_df <- data.frame(
        name = c("test1", "test2"),
        description = c("description1", "description2"),
        severity = c("error", "error"),
        rule = c("rule1", "rule2"),
        stringsAsFactors = FALSE
    )
    
    write.csv(test_df, temp_csv_path, row.names = FALSE)
    rules <- read_rules(temp_csv_path)
    expect_equal(rules, test_df)
    file.remove(temp_csv_path)
})

test_that("read_rules returns error on unsupported file type", {
    expect_error(read_rules(file_rules = "test_rules.txt"), 'Uploaded rules format is not currently supported, please provide a rules file in csv or xlsx format.')
})

test_that("read_rules returns error when required columns are missing", {
    test_df <- data.frame(
        name = c("test1", "test2"),
        description = c("description1", "description2"),
        stringsAsFactors = FALSE
    )
    
    write.csv(test_df, temp_csv_path, row.names = FALSE)
    expect_error(read_rules(temp_csv_path), 'Uploaded rules format is not currently supported, please provide a rules file with column names, "name", "description", "severity", "rule".')
})

test_that("read_rules returns error when sensitive words are in rules", {
    test_df <- data.frame(
        name = c("test1", "test2"),
        description = c("description1", "description2"),
        severity = c("error", "error"),
        rule = c("config", "rule2"),
        stringsAsFactors = FALSE
    )
    
    write.csv(test_df, temp_csv_path, row.names = FALSE)
    expect_error(read_rules(temp_csv_path), 'At this time we are unable to support any rules with the words "config" or "secret" in them as they could be malicious.')
})

test_that("read_rules returns error when words besides error or warning are in severity", {
    test_df <- data.frame(
        name = c("test1", "test2"),
        description = c("description1", "description2"),
        severity = c("severe1", "severe2"),
        rule = c("rule1", "rule2")
    )
    
    write.csv(test_df, temp_csv_path, row.names = FALSE)
    expect_error(read_rules(temp_csv_path), 'severity in the rules file can only be "error" or "warning"')
})

test_that("read_rules returns error when columns are not all character type", {
    test_df <- data.frame(
        name = c("test1", "test2"),
        description = c("description1", "description2"),
        severity = c("error", "error"),
        rule = c(1, 2)
    )
    
    write.csv(test_df, temp_csv_path, row.names = FALSE)
    expect_error(read_rules(temp_csv_path), 'Uploaded rules format is not currently supported, please provide a rules file with columns that are all character type.')
})

# Clean up
unlink(temp_csv_path)

#read data ----
# Assuming reformat_rules() is in your current environment.

# Test when rules don't have a 'dataset' column
test_that("rules without 'dataset' column are handled", {
    data("test_rules")
    data("valid_example")
    
    only_rules_particles <- test_rules |>  
        dplyr::filter(dataset == "particles")|>
        dplyr::select(-dataset)
    only_particles_data <- valid_example["particles"] 
    
    result <- reformat_rules(rules = only_rules_particles, data_formatted = only_particles_data)
    expect_s3_class(result, "data.frame")
    expect_true("dataset" %in% names(result))
    expect_equal(length(unique(result$dataset)), 1)
    expect_equal(unique(result$dataset), names(only_particles_data))
})

# Test when rules have '___' in the rule
test_that("rules with '___' are handled", {
    rules <- data.frame(name = c("name1"), 
                        severity = c("error"),
                        rule = c("___ > 2"),
                        dataset = c("data1"),
                        stringsAsFactors = FALSE)
    data_formatted <- list(data1 = data.frame(A = 1:3, B = 4:6))
    
    result <- reformat_rules(rules, data_formatted)
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 2)
    expect_equal(result$rule, c("A > 2", "B > 2"))
})

# Test when rules have 'is_foreign_key' in the rule
test_that("'is_foreign_key' rules are handled", {
    rules <- data.frame(name = c("name1", "name2"), 
                        severity = c("error", "error"),
                        rule = c("is_foreign_key(A)", "is_foreign_key(A)"),
                        dataset = c("data1", "data2"),
                        stringsAsFactors = FALSE)
    data_formatted <- list(data1 = data.frame(A = 1:3, B = 4:6),
                           data2 = data.frame(A = 1:3, C = 10:12))
    
    result <- reformat_rules(rules, data_formatted)
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 2)
    expect_equal(result$rule, c("A %in% c(\"1\", \"2\", \"3\")", "A %in% c(\"1\", \"2\", \"3\")"))
})

# Test when rules have 'is_foreign_key' in the rule
test_that("'check_exists_in_zip' rules are handled", {
    rules <- data.frame(name = c("name1"), 
                        severity = c("error"),
                        rule = c("check_exists_in_zip(file)"),
                        dataset = c("data1"),
                        stringsAsFactors = FALSE)
    
    zip_data <- "fakedir\\test.zip"
    
    bad_data <- NULL
    
    data_formatted <- list(data1 = data.frame(file = "rules.csv"))
    
    result <- reformat_rules(rules, data_formatted, zip_data)
    result2 <- reformat_rules(rules, data_formatted, bad_data)
    
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 1)
    expect_equal(result$rule, "check_exists_in_zip(zip_path = \"fakedir\\test.zip\", file_name = file) == TRUE")
    expect_equal(result2$rule, "check_exists_in_zip(zip_path = \"\", file_name = file) == TRUE")
    
})

# read data ----
# Test for csv file reading
test_that("read_data reads csv files correctly", {
    # Create a temporary csv file
    temp_file <- tempfile(fileext = ".csv")
    write.csv(mtcars, temp_file, row.names = FALSE)
    
    result <- read_data(temp_file)
    
    # Check that the returned object is a list
    expect_type(result, "list")
    
    # Check that the content of the list is a data frame
    expect_s3_class(result[[1]], "data.frame")
    
    # Clean up
    file.remove(temp_file)
})

# Test for error when mixed file types are provided
test_that("read_data returns an error for mixed file types", {
    # Create a temporary csv and xlsx files
    temp_file1 <- tempfile(fileext = ".csv")
    temp_file2 <- tempfile(fileext = ".txt")
    write.csv(mtcars, temp_file1, row.names = FALSE)
    write.table(mtcars, temp_file2, row.names = FALSE)
    
    # Expect an error when trying to read mixed file types
    expect_error(read_data(c(temp_file1, temp_file2)), 
                 "You cannot mix data types, choose either csv or xlsx for all datasets.")
    
    # Clean up
    file.remove(c(temp_file1, temp_file2))
})

#Name data ----

test_that("name_data correctly handles csv file paths", {
    # Here you should replace with paths to your actual test csv files
    test_files <- c("/path/to/your/test/file1.csv", "/path/to/your/test/file2.csv")
    expected_names <- c("file1", "file2")
    expect_equal(name_data(files_data = test_files), expected_names)
})

test_that("name_data correctly handles xlsx file paths", {
    test_files <- paste0(tempdir(), "\\createWorkbookExample.xlsx")
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "sheet1")
    openxlsx::addWorksheet(wb, "sheet2")
    
    ## Save workbook to working directory
    openxlsx::saveWorkbook(wb, file = test_files, overwrite = TRUE)
    
    # Here you should replace with paths to your actual test xlsx file

    # And replace with your actual sheet names
    expected_names <- c("sheet1", "sheet2")
    expect_equal(name_data(files_data = test_files), expected_names)
})

test_that("name_data uses data_names argument when provided", {
    test_files <- c("irrelevant")
    expected_names <- c("name1", "name2")
    expect_equal(name_data(files_data = test_files, data_names = expected_names), expected_names)
})


#Certificate df ----
test_that("certificate_df function returns a valid data frame", {
    x <- list(
        data_formatted = data.frame(a = 1:3, b = 4:6),
        rules = validate::validator(a > 0, b > 0)
    )
    result <- certificate_df(x)
    
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

# validate_data ----

test_that("validate_data returns a success for rules files that are valid for the datasets", {
    data("valid_example")
    data("test_rules")
    result <- validate_data(files_data = valid_example, data_names = names(valid_example), file_rules = test_rules)
    expect_false(unique(result$issues))
})

test_that("validate_data returns an correct values with invalid example", {
    data("invalid_example")
    data("test_rules")
    result <- validate_data(files_data = invalid_example, data_names = names(invalid_example), file_rules = test_rules) |>
        expect_warning()
    expect_false(any(result$issues))
})

test_that("validate_data returns a warning when there is a column that is in the rules or data that isn't matched", {
    data("invalid_example")
    data("test_rules")
    expect_warning(validate_data(files_data = invalid_example, data_names = names(invalid_example), file_rules = test_rules |> dplyr::filter(name != "PickingStrategy")))
})

test_that("validate_data returns an error when the data has more than one dataset but the rules doesn't have a dataset column", {
    data("invalid_example")
    data("test_rules")
    expect_error(validate_data(files_data = invalid_example, data_names = names(invalid_example), file_rules = test_rules |> dplyr::select(-dataset)))
})

test_that("validate_data returns an error when rules file has a dataset listed that isn't in the datasets", {
    data("invalid_example")
    data("test_rules")
    expect_error(validate_data(files_data = invalid_example, data_names = names(invalid_example), file_rules = test_rules |> dplyr::mutate(dataset = ifelse(dataset == "methodology", "test", "methodology"))))
})

#Remote share ----
# Test case 1: Check if remote_share returns an error when no upload methods are specified
test_that("No upload methods specified error", {
    expect_error(remote_share())
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
rules <- validate::validator(
    col1 > 0,
    col2 <= 9,
    col3 == "test",
    nrow(.) == 4
)

# Generate a validation report
report <- validate::confront(sample_data, rules)

# Find the broken rules
results <- validate::summary(report) %>%
    dplyr::mutate(status = ifelse(fails > 0 | error | warning , "error", "success")) %>%
    dplyr::mutate(description = "test")

broken_rules <- rules_broken(results, show_decision = FALSE)

# Test case 1: Check if rows_for_rules returns the correct violating rows
test_that("rows_for_rules returns violating rows", {
    violating_rows <- rows_for_rules(sample_data, report, broken_rules, c(1,2))
    expect_equal(nrow(violating_rows), 3)
    expect_equal(violating_rows$col1, c(-2, -4, 5))
    expect_equal(violating_rows$col2, c(7, 9, 10))
    expect_identical(rows_for_rules(sample_data, report, broken_rules, c(3)), sample_data) |> expect_warning()
    expect_identical(rows_for_rules(sample_data, report, broken_rules, c(4)), sample_data) |> expect_warning()
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
    
    profane_string <- lexicon::profanity_banned[1]
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
    data("test_rules")
    
    temp_file_rules_csv <- tempfile(fileext = ".csv")
    write.csv(test_rules, temp_file_rules_csv, row.names = FALSE)
    
    output_file <- "test_output.xlsx"
    # Create the Excel file

    suppressWarnings(workbook <- create_valid_excel(temp_file_rules_csv)) #TODO: Has warnings, perhaps add some example datasets and rules from water pact
    
    openxlsx::saveWorkbook(wb = workbook, file = output_file, overwrite = T)
    # Check if the file exists
    expect_true(file.exists(output_file))
    
    # Load the created Excel file
    wb <- openxlsx::loadWorkbook(output_file)
    
    # Check the presence of worksheets
    expect_equal(length(openxlsx::sheets(wb)), 5)
    expect_true(all(c("RULES", "methodology", "LOOKUP", "particles", "samples") %in% openxlsx::sheets(wb)))
    
    # Perform additional checks on the worksheets as needed
    
    # Clean up: delete the output file
    file.remove(output_file)
    
    
})

#remote_download ----

# Add your setup code here if needed
# This code will run before all the tests in this file

# Test for successful data download
test_that("remote_download fails without inputs", {
    # Run the remote_download function
    expect_error(remote_download())
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


test_that("check_exists_in_zip correctly identifies existing files in a zip", {
    old_wd <- getwd() # Save the current working directory
    temp_dir <- tempdir()
    test_file <- file.path(temp_dir, "test_file.txt")
    test_zip <- file.path(temp_dir, "test.zip")
    
    writeLines("This is a test file.", test_file)
    
    setwd(temp_dir) # Set the working directory to the temp directory
    zip(zipfile = "test.zip", files = "test_file.txt") # Zip the test file
    setwd(old_wd) # Restore the original working directory
    
    expect_true(check_exists_in_zip(zip_path = test_zip, file_name = "test_file.txt"))
    expect_false(check_exists_in_zip(zip_path = test_zip, file_name = "non_existing_file.txt"))
    expect_false(check_exists_in_zip(zip_path = NULL, file_name = "non_existing_file.txt"))
    expect_false(check_exists_in_zip(zip_path = NULL, file_name = NA))
    expect_false(check_exists_in_zip(zip_path = "", file_name = NA))
    expect_false(check_exists_in_zip(zip_path = test_zip, file_name = NA))
    expect_identical(check_exists_in_zip(zip_path = NULL, file_name = c(NA, NA)), c(F, F))
    
    unlink(test_file)
    unlink(test_zip)
})

#Test locally only ----
test_that("remote_download retrieves identical data from all sources", {
    
    testthat::skip_on_cran()
    
    # Load the required configuration
    config <- config::get(file = "config_pl_for_tests.yml")
    
    # Load the necessary datasets
    data("valid_example")
    data("invalid_example")
    data("test_rules")
    
    # Perform the validation
    result_valid <- validate_data(files_data = valid_example,
                                  data_names = c("methodology", "samples", "particles"),
                                  file_rules = test_rules)
    
    test_file <- tempfile(pattern = "file", fileext = ".RData")
    
    save(valid_example, file = test_file)
    
    # Perform the remote share
    test_remote <- remote_share(validation = result_valid, 
                                data_formatted = result_valid$data_formatted, 
                                files = test_file,
                                verified = config$valid_key, 
                                valid_key = config$valid_key, 
                                valid_rules = digest::digest(test_rules), 
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
                                mongo_collection = config$mongo_collection,
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
                               mongo_key = config$mongo_key,
                               mongo_collection = config$mongo_collection)

    # Compare datasets from different sources
    expect_identical(dataset$s3$methodology, dataset$ckan$methodology, dataset$mongodb$methodology)
    expect_identical(dataset$s3$samples, dataset$ckan$samples, dataset$mongodb$samples)
    expect_identical(dataset$s3$particles, dataset$ckan$particles, dataset$mongodb$particles)
    file.remove(test_file)
})

#Test locally only ----
test_that("remote_download retrieves zip data from all ckan and s3", {
    
    testthat::skip_on_cran()
    
    # Load the required configuration
    config <- config::get(file = "config_pl_for_tests.yml")
    
    # Load the necessary datasets
    data("valid_example")
    data("invalid_example")
    data("test_rules")
    
    # Perform the validation
    result_valid <- validate_data(files_data = valid_example,
                                  data_names = c("methodology", "samples", "particles"),
                                  file_rules = test_rules)
    
    test_file <- tempfile(pattern = "file", fileext = ".RData")
    
    save(valid_example, file = test_file)
    
    # Perform the remote share
    test_remote <- remote_share(validation = result_valid, 
                                data_formatted = result_valid$data_formatted, 
                                files = test_file,
                                verified = config$valid_key, 
                                valid_key = config$valid_key, 
                                valid_rules = digest::digest(test_rules), 
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
                                mongo_collection = config$mongo_collection,
                                old_cert = NULL)
    
    test_file_zip <- tempfile(pattern = "file", fileext = ".zip")
    
    # Download the data using remote_download
    expect_error(remote_raw_download(hashed_data = test_remote$hashed_data, 
                        file_path = test_file_zip,
                        ckan_url = config$ckan_url, 
                        ckan_key = config$ckan_key, 
                        ckan_package = config$ckan_package,
                        s3_key_id = config$s3_key_id,
                        s3_secret_key = config$s3_secret_key,
                        s3_region = config$s3_region,
                        s3_bucket = config$s3_bucket))
    
    remote_raw_download(hashed_data = test_remote$hashed_data, 
                        file_path = test_file_zip,
                        ckan_url = config$ckan_url, 
                        ckan_key = config$ckan_key, 
                        ckan_package = config$ckan_package)
    
    expect_true(file.exists(test_file_zip))
    
    test_file_zip2 <- tempfile(pattern = "file2", fileext = ".zip")
    
    remote_raw_download(hashed_data = test_remote$hashed_data, 
                        file_path = test_file_zip2,
                        s3_key_id = config$s3_key_id,
                        s3_secret_key = config$s3_secret_key,
                        s3_region = config$s3_region,
                        s3_bucket = config$s3_bucket)
    
    expect_true(file.exists(test_file_zip2))
})

test_that("check_for_malicious_files works correctly", {
    # Create a temp directory to work in
    tmp_dir <- tempdir()
    
    # Create a couple of text files
    file.create(file.path(tmp_dir, "safe_file.txt"))
    file.create(file.path(tmp_dir, "malicious_file.vbs"))
    
    # Navigate to the temp directory
    old_dir <- getwd()
    
    setwd(tmp_dir)
    
    # Create zip archives
    clean_zip <- "clean.zip"
    malicious_zip <- "malicious.zip"
    
    # Zip the files
    zip::zip(clean_zip, "safe_file.txt")
    zip::zip(malicious_zip, c("malicious_file.vbs", "safe_file.txt"))
    
    # Test the function with zip files
    files_in_zip_clean <- utils::unzip(clean_zip, list = TRUE)$Name
    files_in_zip_malicious <- utils::unzip(malicious_zip, list = TRUE)$Name
    
    expect_false(check_for_malicious_files(files_in_zip_clean))
    expect_true(check_for_malicious_files(files_in_zip_malicious))
    
    # Test the function with individual file paths
    expect_false(check_for_malicious_files("safe_file.txt"))
    expect_true(check_for_malicious_files("malicious_file.vbs"))
    
    # Navigate back to the original directory
    setwd(old_dir)
})

# Query MongoDB Document by ObjectID
test_that("query_document_by_object_id returns the correct document", {
    
    testthat::skip_on_cran()
    
    # Load the required configuration
    config <- config::get(file = "config_pl_for_tests.yml")
    
    result <- query_document_by_object_id(
        apiKey = config$apiKey,
        collection = config$mongo_collection,
        database = 'test',
        dataSource = 'Cluster0',
        objectId = "6527260827276a6fca07bba1"
    )
    
    expect_true(!is.null(result) && length(result) > 0,
                info = "Query result should not be NULL or empty.")
})

# Run app
tmp <- file.path(tempdir(), "Validator-testthat")
dir.create(tmp, showWarnings = F)

test_that("run_app() wrapper doesn't produce errors", {
    run_app(path = tmp, test_mode = T) |>
        expect_silent()
})

# Tidy up
unlink(tmp, recursive = T)
