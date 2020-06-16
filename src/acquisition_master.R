suppressPackageStartupMessages({
    library(httr)
    library(jsonlite)
    library(tidyr)
    library(plyr)
    library(data.table)
    library(dtplyr)
    library(tidyverse)
    library(lubridate)
    library(feather)
    library(glue)
    library(logging)
    library(emayili)
    library(neonUtilities)
    library(tinsel)
})

setwd('/home/mike/git/macrosheds/data_acquisition')
conf = jsonlite::fromJSON('config.json')

#set up global logger. network-domain loggers are set up later
logging::basicConfig()
logging::addHandler(logging::writeToFile, logger='ms',
    file='logs/0_ms_master.log')

source('src/global_helpers.R')
source_decoratees('src/global_helpers.R') #parse decorators

network_domain = sm(read_csv('data/general/site_data.csv')) %>%
    filter(as.logical(in_workflow)) %>%
    select(network, domain) %>%
    distinct() %>%
    arrange(network, domain)

ms_globals = c(ls(all.names=TRUE), 'email_err_msgs')

# dmnrow=3
for(dmnrow in 1:nrow(network_domain)){

    network = network_domain$network[dmnrow]
    domain = network_domain$domain[dmnrow]

    logger_module = set_up_logger(network=network, domain=domain)
    loginfo(logger=logger_module,
        msg=glue('Processing network: {n}, domain: {d}', n=network, d=domain))

    get_all_local_helpers(network=network, domain=domain)

    ms_retrieve(network=network, domain=domain)
    ms_munge(network=network, domain=domain)
    # ms_derive(network=network, domain=domain)

    retain_ms_globals(ms_globals)
}

if(length(email_err_msgs)){
    email_err(email_err_msgs, conf$report_emails, conf$gmail_pw)
}

loginfo('Run complete', logger='ms.module')