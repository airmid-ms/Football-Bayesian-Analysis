# libraries
library(tidyverse)
library(tidybayes)
library(rjags)
library(R2jags)
library(bayesplot) 
library(patchwork)


# load data
football_dat <- read_csv("data/football_dat.csv")

# EDA
glimpse(football_dat)
spread_vs_outcome <- ggplot(football_dat, aes(x=spread, y=outcome)) +
  geom_point(position = "jitter")
spread_vs_outcome
ggsave("output/plots/spread_vs_outcome.png", plot = spread_vs_outcome, width = 8, height = 6)

# model

football_model <- "
 model {
  
    # Likelihood
    for (i in 1:n_game) {
    y.i[i] ~ dnorm(mu.i[i], sigma[i]^-2) 
    mu.i[i] <- alpha + beta*(x.i[i])
    sigma[i] <- exp(alpha_sigma + beta_sigma*x.i[i])
    }
    
    # Prior
    alpha ~ dnorm(0, 10^-2) 
    beta ~ dnorm(0, 10^-2) 
    alpha_sigma ~ dnorm(0, 10^-2) 
    beta_sigma ~ dnorm(0, 10^-2) 
  
 }
" 

## A standard linear regression would not be able to tell whether a larger spread makes the outcome more predictable. 
## So a heteroscedastic regression was used instead so that both the mean and variance of the outcome are modeled as opposed to just the mean.

football_data <- list(
  y.i = football_dat$outcome,
  x.i = football_dat$spread,
  n_game = nrow(football_dat))


params <- c("alpha", "beta", "alpha_sigma", "beta_sigma") 

mod <- jags(data = football_data,
            parameters.to.save = params,
            n.iter = 4000,
            n.burnin = 2000,
            model.file = textConnection(football_model))
plot(mod)

mod$BUGSoutput$summary[c("alpha", "beta", "alpha_sigma", "beta_sigma"), ]


## model summary
## alpha: Median = 0.22, Cred Int = (-0.77, 1.19) beta: Median = 1, Cred Int = (0.84, 1.17) alpha_sigma: Median = 2.66, Cred Int = (2.61, 2.71) beta_sigma: Median = -0.0076, Cred Int = (-0.016, 0.0007)

## There does appear to be a relationship between the outcome and spread. The credible interval does not include 0 and so there appears to be a significant relationship between outcome and point spread. The median is positive, indicating that when point spread increases so does the outcome.

## There does not appear to be a relationship between the residual variation and spread. The credible interval for beta sigma includes 0 and the median is very close to 0, there does not appear to be a relationship between residual variation and point spread.



# Posterior Predictive Checking
football_model <- "
 model {
  
    # Likelihood
    for (i in 1:n_game) {
    y.i[i] ~ dnorm(mu.i[i], sigma[i]^-2) 
    mu.i[i] <- alpha + beta*(x.i[i])
    sigma[i] <- exp(alpha_sigma + beta_sigma*x.i[i])
    }
    
    # Prior
    alpha ~ dnorm(0, 10^-2) 
    beta ~ dnorm(0, 10^-2) 
    alpha_sigma ~ dnorm(0, 10^-2) 
    beta_sigma ~ dnorm(0, 10^-2) 
    
    # Posterior prediction
    for(i in 1:n_game) {
    yrep[i] ~ dnorm(mu.i[i], sigma[i]^-2)
    }
  
}
"  
football_data <- list(
  y.i = football_dat$outcome, 
  x.i = football_dat$spread,
  n_game = nrow(football_dat))


params <- c("alpha", "beta", "alpha_sigma", "beta_sigma", "yrep") 

mod <- jags(data = football_data,
            parameters.to.save = params,
            n.iter = 4000,
            n.burnin = 2000,
            model.file = textConnection(football_model))

plot(mod)

mod$BUGSoutput$summary[c("alpha", "beta", "alpha_sigma", "beta_sigma"), ]

## extracting observed outcomes, simulated replicates and predictor for PPC
y <- football_dat$outcome
yrep <- mod$BUGSoutput$sims.list$yrep
x <- football_dat$spread

## minimum test stat
d <- function(x) min(x)

## comparing distribution of simulated min to observed min
ppc1 <- ppc_stat(y, yrep, stat = "d")
ggsave("output/plots/ppc_minimum.png", plot = ppc1, width = 8, height = 6)

## The PPC stat plot shows that the observed minimum is within the simulated minimum distribution. This shows the model is generating simulated data similar to the observed data.


## comparing simulated median/intervals against the spread
ppc2 <- ppc_intervals(y, yrep, x)
ggsave("output/plots/ppc_intervals.png", plot = ppc2, width = 8, height = 6)

## The PPC intervals plot shows that the model manages to capture a decent range of the observed values variability. The models uncertainty does change in relation to the spread units.

combined <- ppc1 + ppc2
ggsave("output/plots/ppc_combined.png", plot = combined, width = 12, height = 5)


# Predictive Modelling
# checking what the median response is when spread = 16
index <- which(football_data$x.i == 16)
yrep_x16 <- yrep[,index]
median(yrep_x16)
quantile(yrep_x16, 0.025)
quantile(yrep_x16, 0.975)

# adding
football_model <- "
 model {
  
    # Likelihood
    for (i in 1:n_game) {
    y.i[i] ~ dnorm(mu.i[i], sigma[i]^-2) 
    mu.i[i] <- alpha + beta*(x.i[i])
    sigma[i] <- exp(alpha_sigma + beta_sigma*x.i[i])
    }
    
    # Prior
    alpha ~ dnorm(0, 10^-2) 
    beta ~ dnorm(0, 10^-2) 
    alpha_sigma ~ dnorm(0, 10^-2) 
    beta_sigma ~ dnorm(0, 10^-2) 
    
    # Posterior prediction for observed games
    for(i in 1:n_game) {
    yrep[i] ~ dnorm(mu.i[i], sigma[i]^-2)
    }
    
    # Prediction for a new game with spread = x_new
    mu_new <- alpha + beta * x_new
    sigma_new <- exp(alpha_sigma + beta_sigma * x_new)
    y_new ~ dnorm(mu_new, sigma_new^-2)
  
}
"  

## new spread value = 16
football_data <- list(
  y.i = football_dat$outcome,
  x.i = football_dat$spread,
  n_game = nrow(football_dat),
  x_new = 16) 

params <- c("alpha", "beta", "alpha_sigma", "beta_sigma", "yrep", "y_new") 

mod <- jags(data = football_data,
            parameters.to.save = params,
            n.iter = 4000,
            n.burnin = 2000,
            model.file = textConnection(football_model))

## Prediction for spread = 16
y_new_samples <- mod$BUGSoutput$sims.list$y_new
median(y_new_samples)
quantile(y_new_samples, c(0.025, 0.975))

## Median and intervals line up very closely, shows the model performs well and isn't overfitting.
