# Run the hake assessment 
source('R/load_files.R')
source('R/getParameters_ss.R')
source('R/load_data_ss.R')
library(r4ss)
library(dplyr)
library(reshape2)
# Read the assessment data 
mod <- SS_output('inst/extdata/SS32018/', printstats=FALSE, verbose = FALSE) # Read the true selectivity 

df <- load_data_ss(mod)
df$smul <- 0.5

years <- df$years

#U[2,] <- 0.01
parms.ss <- getParameters_ss(TRUE, mod)


compile("src/runHakeassessment_ss.cpp")
dyn.load(dynlib("src/runHakeassessment_ss"))
obj <-MakeADFun(df,parms.ss,DLL="runHakeassessment_ss")#, )

vars <- obj$report()

age_survey  <- obj$report()$age_survey_est
age_catch <- obj$report()$age_catch
# Compare the two models with the same parameters 

SSBass <- vars$SSB
SSB.ss3 <- mod$derived_quants$Value[grep('SSB_1966', mod$derived_quants$Label):grep('SSB_2018', mod$derived_quants$Label)]
R.ss <- mod$derived_quants$Value[grep('Recr_1966', mod$derived_quants$Label):grep('Recr_2018', mod$derived_quants$Label)]


lower <- obj$par-Inf

lower[names(lower) == 'F0'] <- 0.001
upper <- obj$par+Inf
#upper[names(upper) == 'psel_fish' ] <- 5
upper[names(upper) == 'PSEL'] <- 9
upper[names(upper) == 'logh'] <- log(0.999)
upper[names(upper) == 'F0'] <- 2


system.time(opt<-nlminb(obj$par,obj$fn,obj$gr,lower=lower,upper=upper, 
                        control = list(iter.max = 2000,
                                       eval.max = 2000))) #

system.time(rep<-sdreport(obj))
rep

xx<- Check_Identifiable_vs2(obj)
# 
# tt <- TMBhelper::Optimize(obj,fn = obj$fn,obj$gr,lower=lower,upper=upper,
#                            control = list(iter.max = 1e8, eval.max = 1e8,
#                                           rel.tol = 1e-10))
#rep
sdrep <- summary(rep)
rep.values<-rownames(sdrep)


source('R/getUncertainty.R')
df$nyear <- length(years)
df$year <- years

SSB <- getUncertainty('SSB',df,sdrep)
F0 <- getUncertainty('Fyear',df,sdrep)
Catch <- getUncertainty('Catch',df,sdrep)
Surveyobs <- getUncertainty('Surveyobs',df,sdrep)
R <- getUncertainty('R',df,sdrep)
surveyselec.est <- getUncertainty('surveyselc', df,sdrep)
catchselec.est <- getUncertainty('catchselec', df,sdrep)
SSB0 <- getUncertainty('SSBzero', df,sdrep)


#png('Figures/SSB_survey_mid.png', width = 16, height = 12, unit = 'cm', res =400)
plotValues(SSB, data.frame(x= df$years, y= SSB.ss3),'SSB')
#dev.off()


## Do the same plot with 
df.plot <- data.frame(SSB = SSB$name/(SSB0$name*1e-6))

plotValues(Catch, data.frame(x = df$years,y =df$Catchobs), 'Catch')

#png('Figures/F0.png', width = 16, height = 12, unit = 'cm', res =400)
plotValues(F0, data.frame(x = df$years,y =df$F0), 'F0')
#dev.off()
# yl <- ylimits(Biomass$name*1e-9,df$survey[df$survey > 1]*1e-9)
# plot(years[df$survey>1],Biomass$name[df$survey>1]*1e-9, xlim = c(1990,2019), ylim = yl, xlab= 'survey')
# points(years[df$survey > 1],df$survey[df$survey > 1]*1e-9, col = 'green')
Surveyobs[Surveyobs$year < 1995,] <- NA

plotValues(Surveyobs, data.frame(y = df$survey[df$flag_survey == 1], x = df$years[df$flag_survey == 1]), 'survey biomass')

#png('estimated_F0.png', width = 16, height = 12, unit = 'cm', res =400)
plotValues(F0, data.frame(y =assessment$F0, x= assessment$year), 'Fishing mortality')
dev.off()
# Likelihood contributions 

nms <- c('SDR','Selectivity','Catch','survey','survey comps','Catch comps','Priors')

LogLik<- getUncertainty('ans_tot', df)
LogLik$lik <- nms

#png('Figures/LogLikelihoods.png', width = 16, height = 12, unit = 'cm', res =400)
ggplot(LogLik, aes(y = -name, x= lik))+geom_point()+theme_classic()+scale_y_continuous('LogLikelihood')+scale_x_discrete(name = '')+
  geom_errorbar(aes(x = lik, ymin = -min, ymax = -max), col = 'black')
#dev.off()

# Plot the age comps in all years  
ages <- 1:15
comp.year <- length(df$flag_catch[df$flag_catch == 1])

age_catch_est <- getUncertainty('age_catch_est', df)
age_catch <- getUncertainty('age_catch', df)

age_catch_est$age <- rep(ages, df$nyear)
age_catch_est$year <- rep(df$year, each = 15)

head(age_catch_est)

df.plot <- data.frame(comps = c(age_catch_est$name,age_catch$name), 
                      year = rep(age_catch_est$year,2), age = rep(age_catch_est$age,2), model = rep(c('estimated','data'), each = 780))

df.plot <- df.plot[which(df.plot$year %in% df$year[df$flag_catch == 1]),]

#png('Figures/age_comps_catch.png', width = 16, height = 12, unit = 'cm', res =400)
ggplot(data = df.plot, aes(x = age, y = comps, color = model))+geom_line()+facet_wrap(facets = ~year)+theme_bw()
dev.off()

ages <- 1:15
comp.year <- length(df$flag_survey[df$flag_survey == 1])

age_survey_est <- getUncertainty('age_survey_est', df)
age_survey <- getUncertainty('age_survey', df)

age_survey_est$age <- rep(ages, df$nyear)
age_survey_est$year <- rep(df$year, each = 15)

head(age_survey_est)

df.plot <- data.frame(comps = c(age_survey_est$name,age_survey$name), 
                      year = rep(age_survey_est$year,2), age = rep(age_survey_est$age,2), model = rep(c('estimated','data'), each = 780))

df.plot <- df.plot[which(df.plot$year %in% df$year[df$flag_survey == 1]),]

#png('Figures/age_comps_survey.png', width = 16, height = 12, unit = 'cm', res =400)
ggplot(data = df.plot, aes(x = age, y = comps, color = model))+geom_line()+facet_wrap(facets = ~year)+theme_bw()
#dev.off()

## Compare parameter estimations with the ones from the SS3 assessment 
parms.true <- getParameters(TRUE) # Parameters estimated in the SS3 model 
# Non related parameters

nms <- unlist(strsplit(names(rep$par.fixed)[1:6],split ='log'))[2*(1:6)]
vals <- exp(rep$par.fixed)[1:6]
err <- sdrep[,2][1:6]

SE <- vals*err

df.plot.parms <- data.frame(value = vals, min = vals-2*SE, max = vals+2*SE, name =nms, model = 'TMB')

df.assessment <- data.frame(value = exp(as.numeric(parms.true[1:6])), min = NA, max = NA, name = nms, model = 'SS3')

df.plot.parms <- rbind(df.plot.parms,df.assessment)

#png('Figures/parameters_estimated.png', width = 16, height = 12, unit = 'cm', res =400)
ggplot(df.plot.parms, aes(x = name, y = value, colour = model))+
  geom_point(size = 2)+geom_linerange(aes(ymin = min, ymax = max))+theme_classic()+facet_wrap(~name, scale = 'free')+
  theme(strip.text.x = element_blank())+scale_x_discrete('')
#dev.off()
png('Figures/parameters_estimated.png', width = 16, height = 12, unit = 'cm', res =400)
ggplot(df.plot.parms[df.plot.parms$name %in% c('Rinit', 'h', 'Minit', 'SDsurv'),], aes(x = name, y = value, colour = model))+
  geom_point(size = 2)+geom_linerange(aes(ymin = min, ymax = max))+theme_classic()+facet_wrap(~name, scale = 'free')+
  theme(strip.text.x = element_blank())+scale_x_discrete('')
dev.off()
# plot the base and survey selectivity 
source('getSelec.R')

sel.ss3 <- getSelec(df$age,psel =parms.true['psel_fish'][[1]],Smin = df$Smin,df$Smax)
sel.tmb <- getSelec(df$age, psel = rep$par.fixed[names(rep$par.fixed) == 'psel_fish'], Smin = df$Smin, Smax = df$Smax)

sel.survey.ss3 <- getSelec(df$age,psel =parms.true['psel_surv'][[1]],Smin = df$Smin_survey,df$Smax_survey)
sel.survey.tmb <- getSelec(df$age,psel = rep$par.fixed[names(rep$par.fixed) == 'psel_surv'],Smin = df$Smin_survey,df$Smax_survey)

df.plot <- data.frame(age = rep(df$age, 4), sel = c(sel.ss3,sel.tmb,sel.survey.ss3,sel.survey.tmb), 
                      fleet = rep(c('fishery','survey'), each = length(df$age)*2), 
                      model = rep(c('ss3','TMB'), each = length(df$age)))

png('Figures/selectivities.png', width = 16, height = 12, unit = 'cm', res =400)
ggplot(df.plot, aes(x = age, y = sel, color = model))+geom_line()+facet_wrap(~fleet)
dev.off()

# 
# fit <- tmbstan(obj = obj, chains = 1, init = unlist(parms), lower = lower, upper = upper)
# launch_shinystan(fit)


