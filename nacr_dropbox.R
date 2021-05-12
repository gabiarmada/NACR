#' \code{nacr_drop} Get NACR data from Dropbox
#' 
#' @title nacr_drop 
#' @param fileread Filename from Daniel Tong/NACR
#' @param latlonfile Filename containing latitude and longitude values 
#' @param whkeep1 Which rows to keep (based on lat/long organization for efficiency)
#' @param fipsdat1 Row, column and fips information from lat/long data
#' @author Jenna Krall and Gabi Armada 
#' @export

library(here)
library(dplyr)
library(rdrop2)
library(ncdf4)
library(housingData)

nacr_drop <- function(fileread, latlonfile, whkeep1, fipsdat1, cols1, rows1) {
    # download files from dropbox
    drop_download(path = file.path("NACR", fileread),
                  local_path = file.path(here(), fileread),
                  overwrite = T, progress = F, verbose = F)
    drop_download(path = file.path("NACR", latlonfile),
                  local_path = file.path(here(), latlonfile),
                  overwrite = T, progress = F, verbose = F)
    # read files
    ncfile <- nc_open(file.path(here(), fileread))
    latlon <- nc_open(file.path(here(), latlonfile))
    
    # get PM, lat, lon 
    pm1 <- ncvar_get(ncfile, "PM25_TOT") 
    lat1 <- ncvar_get(latlon, "LAT")
    lon1 <- ncvar_get(latlon, "LON")
    # find rows and columns
    pm2 <- data.frame(pm = as.vector(pm1),
                      lat = as.vector(lat1), 
                      lon = as.vector(lon1),
                      col = as.vector(cols1),
                      row = as.vector(rows1))
    # keep only grids desired
    pm2 <- pm2[whkeep1, ]
    # get fips for averaging
    pm2 <- left_join(pm2, fipsdat1, by = c("row", "col")) %>%
        select(-col, -row) %>%
        group_by(FIPS) %>%
        summarize(pm = mean(pm, na.rm = T)) %>%
        #mutate(fips = paste0("fips_", FIPS)) %>%
        #pivot_wider(names_from = "fips", values_from = "pm") %>%
        mutate(name = fileread)
    
    # include lat/ lon centroid in output
    data("geoCounty")
    geoCounty <- filter(geoCounty, fips %in% pm2$FIPS) %>%
        rename(FIPS = fips)%>%
        select(FIPS, lon, lat)
    pm2 <- merge(geoCounty, pm2, by = "FIPS")
    
    # remove files locally
    rm1 <- paste0("rm ", fileread)
    rm2 <- paste0("rm ", latlonfile)
    system(rm1)
    system(rm2)
    
    # close files 
    nc_close(ncfile)
    nc_close(latlon)
    
    # return
    pm2
}
