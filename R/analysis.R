# libraries
library(tidyverse)
library(tidybayes)
library(readr)
library(ggplot2)
library(rjags)
library(R2jags)
library(tidybayes)
library(bayesplot) 


# load data
football_dat <- read_csv("data/football_dat.csv")

# EDA
glimpse(football_dat)
spread_vs_outcome <- ggplot(football_dat, aes(x=spread, y=outcome)) +
  geom_point(position = "jitter")
spread_vs_outcome
ggsave("output/plots/spread_vs_outcome.png", plot = spread_vs_outcome, width = 8, height = 6)
