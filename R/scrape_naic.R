library(janitor)
library(magrittr)
library(openxlsx)
library(pdftools)
library(rvest)
library(tabulizer)
library(tidyverse)

# Scrape the PDF locations & their info from website.
home = rvest::html_session('http://www.naic.org/prod_serv_model_laws.htm')

info = home %>%
  rvest::html_nodes(css = 'td td td a') %>%
  rvest::html_text()

# Create empty list to store extracted tables.
tables = vector(mode = 'list', length = length(info))

for (i in 1:length(tables)) {

  # Construct the URL of the doc.
  url = paste0('http://www.naic.org/store/free/', info[[i]], '.pdf')

  # Scrape the text of the doc.
  raw = pdftools::pdf_text(pdf = url)

  # Get the page numbers of the table (different for every doc).
  table_pages = which(
    stringr::str_detect(string = raw, pattern = 'NAIC MEMBER'))

  # Extract the table from the doc text.
  tables[[i]] = tabulizer::extract_tables(file = url, pages = table_pages) %>%
    map(.f = ~ as_tibble(.x)) %>%
    dplyr::bind_rows() %>%
    mutate_all(.funs = funs(ifelse(. == '', NA, .))) %>%
    janitor::remove_empty(which = 'cols') %>%
    filter(V1 != '')

  # Clean the data.
  # For some reason, combining this pipeline w/ the previous one causes problems
  tables[[i]] %<>%
    magrittr::set_colnames(
      {tables[[i]] %>%
          slice(1) %>%
          mutate_all(.funs = funs(
            ifelse(is.na(.), str_c('v', round(runif(1), digits = 3)), .))) %>%
          as.character()}
    ) %>%
    filter(`NAIC MEMBER` != 'NAIC MEMBER') %>%
    mutate(document = info[[i]])

  print(str_c(i, ': ', info[[i]], ' scraped.'))

  Sys.sleep(1)

}

# Write out tables as Excel spreadsheets.
for (table in tables) {

  doc = table %>%
    select(document) %>%
    unique() %>%
    as.character()

  openxlsx::write.xlsx(
    x = table,
    file = str_c('data/raw/', doc, '.xlsx'))

}
