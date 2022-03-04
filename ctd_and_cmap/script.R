library(tidyverse)
library(cmap4r)
# If I run into issues with this I'll regenerate it
set_authorization(cmap_key = "6acd63a0-4c63-11ea-aa09-71d9d763e28d")
library(xml2)
library(gridExtra)

# tblWHATEVER found by searching online catalog, finding website
#   https://simonscmap.com/catalog/datasets/HOT_Bottle_ALOHA and
#   looking for something like tblWHATEVER
#   SQL column names are in table at bottom under "Short Name"
cmap_data <- exec_manualquery("SELECT * FROM tblHOT_Bottle WHERE pressure_ctd_bottle_hot < 300")

nitr_plot <- cmap_data %>% 
  select(depth=pressure_ctd_bottle_hot, nostar=NO2_NO3_bottle_hot) %>%
  ggplot(aes(x=depth, y=nostar)) +
  geom_point(aes(color=depth), alpha=0.5) +
  stat_smooth(color="#FFFFFFAA", se = FALSE, lwd=3) +
  stat_smooth(color="black", se = FALSE) +
  coord_flip() +
  scale_x_reverse() +
  scale_color_gradient(high = "#142e47", low = "#55b0f5") +
  theme_minimal() +
  theme(legend.position = "none") +
  xlab("Depth (meters)") +
  ylab("Nitrate + nitrite (uM)")
nitr_plot

base_url  <- "http://scope.soest.hawaii.edu/FTP/scope/ctd/paragon1/"
ctd_data <- base_url %>%
  read_html() %>%
  xml_find_all("//table//td/a") %>%
  xml_text() %>%
  str_subset("dn") %>%
  data.frame(basename=.) %>%
  mutate(station=as.numeric(str_extract(basename, "(?<=s)\\d+"))) %>%
  mutate(cast = as.numeric(str_extract(basename, "(?<=c)\\d+"))) %>%
  mutate(url=paste(base_url, basename, sep="/")) %>%
  pmap_dfr(function(...){
    row_data <- data.frame(...)
    cat("\rReading", row_data$basename)
    # url_data <- read.table(row_data$url, skip = 3)
    # names(url_data) <- c("depth", "temp", "salinity", "oxygen", "PAR",
    #                      "chl", "attenuation", "transmissometer", "n_obs", "q")
    url_data <- read.table(row_data$url, skip = 3)[,c(1,2,3,5,6)]
    names(url_data) <- c("depth", "temp", "salinity", "PAR", "chl")
    cbind(row_data, url_data)
  })
ctd_summary <- "http://scope.soest.hawaii.edu/data/scope2021/paragon1.sum" %>%
  read.table(skip = 4) %>%
  set_names(c("station", "cast", "month", "day", "year", "time", 
              "lat_deg", "lat_min", "lat_dir","lon_deg", "lon_min", 
              "lon_dir", "max_depth", "n_bottles")) %>%
  select(station, cast, time)
PAR_plot <- ctd_data %>%
  left_join(ctd_summary) %>%
  mutate(hour=as.numeric(str_extract(time, "\\d+(?=:)"))) %>%
  filter(between(hour, 10, 14)) %>%
  filter(depth<300) %>%
  # filter(PAR<3) %>%
  ggplot(aes(x=depth, y=PAR, color=depth)) +
  geom_jitter(height = 0.02, alpha=0.5) +
  stat_smooth(color="#FFFFFFDD", se = FALSE, lwd=2, method = "loess", span=0.1) +
  stat_smooth(color="black", se = FALSE, method = "loess", span=0.1) +
  scale_x_reverse() +
  coord_flip() +
  scale_color_gradient(high = "#142e47", low = "#55b0f5") +
  ylim(0, 2.5) +
  theme_minimal() +
  theme(legend.position = "none", 
        axis.text.y = element_blank(),
        axis.title.y = element_blank())
PAR_plot

chl_plot <- ctd_data %>%
  filter(depth<300) %>%
  ggplot(aes(x=depth, y=chl, color=depth)) +
  geom_point(alpha=0.5) +
  stat_smooth(color="#FFFFFFAA", se = FALSE, lwd=2, method = "loess", span=0.1) +
  stat_smooth(color="black", se = FALSE, method = "loess", span=0.1) +
  scale_x_reverse() +
  coord_flip() +
  scale_color_gradient(high = "#142e47", low = "#55b0f5") +
  theme_minimal() +
  theme(legend.position = "none", 
        axis.text.y = element_blank(),
        axis.title.y = element_blank()) +
  ylab("Fluorometric chlorophyll")
chl_plot

gp <- grid.arrange(nitr_plot, PAR_plot, chl_plot, nrow=1)

ggsave(filename = "ctd_and_cmap.png", plot = gp, device = "png", 
       width = 8, height = 3, units = "in", dpi = 144, type="cairo")
