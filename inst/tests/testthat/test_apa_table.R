context("apa_table()")

test_that(
  ""
  , {
    load("mixed_data.rdata")

    library("dplyr")
    descriptives <- mixed_data %>% group_by(Dosage) %>%
      summarize(
        Mean = printnum( mean(Recall) )
        , Median = printnum( median(Recall) )
        , SD = printnum( sd(Recall) )
        , Min = printnum( min(Recall) )
        , Max = printnum( max(Recall) )
      )

    expect_error(apa_table(descriptives, added_colnames = letters[1:5]), "Too many column names. Please check length of 'added_colnames'. ")
  }
)
