### Calculate the estimated vs realized TAC
library(ggplot2)
library(scales)
library(reshape2)
library(PacifichakeMSE)
library(patchwork)
library(PNWColors) # remotes::install_github('jakelawlor/PNWColors')

# source('load_data_seasons.R')
# source('getSelec.R')
# source('load_files.R')
# source('load_files_OM.R')

df.tac <- read.csv('inst/extdata/TAC.csv')

df <- load_data_seasons(nseason = 1, nspace = 1)
sim.data <- run.agebased.true.catch(df)
## Calculate the theoretical TAC
SSB <- seq(0, sum(sim.data$SSB0)*2, length.out = dim(df.tac)[1])
SSB_0 <- sum(sim.data$SSB0)

TAC <- matrix(NA, dim(df.tac)[1])

TAC[(SSB/SSB_0)< 0.1]<- 0 # add a very low catch (fix later)
TAC[(SSB/SSB_0)> 0.4]<- 0.4*SSB[(SSB/SSB_0)> 0.4] # For simplicity assume SSB is the same as V (it's close)

ix <- (SSB/SSB_0)<= 0.4 & (SSB/SSB_0) >= 0.1
TAC[ix]<- 0.4*SSB[ix]*((SSB[ix]-0.1*SSB_0)*((0.4*SSB_0/SSB[ix])/(0.4*SSB_0-0.1*SSB_0)))


df.plot <- data.frame(SSB = SSB, TAC = TAC)

ggplot(data = df.plot, aes(x = SSB*1e-6, y = TAC*1e-6))+geom_line()+
  scale_y_continuous('TAC (million tonnes)')+scale_x_continuous('SSB (million tonnes)')+theme_classic()

df.tac$theotac <- TAC


### Do a regression on the difference between

#lm.JMC <- lm(TAC ~ AssessTac, data = df.tac[df.tac$Year >= 2012,])
#lm.STAR <- lm(TAC ~ AssessTac, data = df.tac[df.tac$Year < 2012,])
lm.historical <- lm(TAC ~ AssessTac, data = df.tac)
lm.realized <- lm(Realized ~ AssessTac, data = df.tac)


#### Print the TAC calc adjustment ####
#
# df.adjTAC <- data.frame(incpt = c(lm.JMC$coefficients[1],lm.realized$coefficients[1], lm.STAR$coefficients[1]),
#                         slp = c(lm.JMC$coefficients[2],lm.realized$coefficients[2], lm.STAR$coefficients[2]),
#                         adj = c('JMC','Realized','STAR'))

df.adjTAC <- data.frame(incpt = c(lm.historical$coefficients[1],lm.realized$coefficients[1]),
                        slp = c(lm.historical$coefficients[2],lm.realized$coefficients[2]),
                        adj = c('historical','realized'))

#write.csv(df.adjTAC, 'adjusted_tac_fn.csv', row.names = FALSE)
#
# df.plot <- data.frame(TAC = TAC,
#                       TAC.JMC = predict(lm.JMC, newdata = data.frame(AssessTac = TAC)),
#                       TAC.realized = predict(lm.realized, newdata = data.frame(AssessTac = TAC)),
#                       TAC.STAR = predict(lm.STAR, newdata = data.frame(AssessTac = TAC)),
#                       SSB = SSB)

# finer-scale sequence of values spanning range of TAC
TAC.fine <- seq(0, max(TAC), length = 100)
df.plot <- data.frame(TAC = TAC.fine,
                      TAC.historical = predict(lm.historical, newdata = data.frame(AssessTac = TAC.fine)),
                      TAC.realized = predict(lm.realized, newdata = data.frame(AssessTac = TAC.fine)))


df.plot$TAC.historical[df.plot$TAC.historical > df.plot$TAC] <- df.plot$TAC[df.plot$TAC.historical > df.plot$TAC]
df.plot$TAC.realized[df.plot$TAC.realized > df.plot$TAC] <- df.plot$TAC[df.plot$TAC.realized > df.plot$TAC]
#df.plot$TAC.STAR[df.plot$TAC.STAR > df.plot$TAC] <-df.plot$TAC[df.plot$TAC.STAR >TAC]
# Floor data
df.plot$Floor <- df.plot$TAC*0.5
df.plot$Floor[df.plot$Floor<= 180000] <- 180000
df.plot$TAC.HCR <- df.plot$TAC

df.plot.w <- melt(df.plot, id.vars = 'TAC', value.name = 'Quota', variable.name = 'HCR')
nhcr <- unique(df.plot.w$HCR)
cols <- PNWColors::pnw_palette('Starfish',n = 4, type = 'discrete')
# add alpha transparency to color vector
cols <- adjustcolor(cols, alpha.f = 0.7)

df.plot.w$HCR <- factor(df.plot.w$HCR, levels = c("TAC.HCR", "TAC.historical", "TAC.realized",
                                                  'Floor'))

# cols <- LaCroixColoR::lacroix_palette('PassionFruit', n = 4, type = 'discrete')
# cols <- RColorBrewer::brewer.pal(4, 'Accent')

p1 <- ggplot(df.plot.w, aes(x= TAC*1e-3, y = Quota*1e-3, color = HCR))+geom_line(linetype = 2, size = 0.8)+
  scale_y_continuous('Catch \n(thousand tonnes)')+scale_color_manual(values = cols,
                                                                     labels = c('base scenario','historical','realized','floor'))+
  scale_x_continuous('Harvest control rule')+ coord_cartesian(ylim=c(0, 800), xlim = c(0,1000))+
  geom_point(data = df.tac,aes(x=AssessTac*1e-3, y = Realized*1e-3), color = cols[3])+
  geom_point(data = df.tac,aes(x=AssessTac*1e-3,y = TAC*1e-3), color = cols[2])+
  theme_classic()+
  #geom_point(data = df.tac[df.tac$Year >= 2012,],aes(x=AssessTac*1e-3,y = TAC*1e-3), color = alpha(cols[4],0.5))+
  theme(legend.title = element_blank(),
        legend.key.size =  unit(.2, "cm"),
        legend.text=element_text(size=7),
        legend.position = c(0.15,0.8))
p1

p3 <- ggplot(df.plot.w[df.plot.w$HCR != 'Floor',], aes(x= TAC*1e-3, y = Quota*1e-3, color = HCR))+geom_line(linetype = 2, size = 0.8)+
  scale_y_continuous('Catch \n(thousand tonnes)')+scale_color_manual(values = cols[1:3],
                                                                     labels = c('base scenario','historical','realized'))+
  scale_x_continuous('Harvest control rule')+ coord_cartesian(ylim=c(0, 800), xlim = c(0,1000))+
  geom_point(data = df.tac,aes(x=AssessTac*1e-3, y = Realized*1e-3), color = cols[3])+
  geom_point(data = df.tac,aes(x=AssessTac*1e-3,y = TAC*1e-3), color = cols[2])+
  theme_classic()+
  #geom_point(data = df.tac[df.tac$Year >= 2012,],aes(x=AssessTac*1e-3,y = TAC*1e-3), color = alpha(cols[4],0.5))+
  theme(legend.title = element_blank(),
        legend.key.size =  unit(.2, "cm"),
        legend.text=element_text(size=7),
        legend.position = c(0.2,0.8))
p3

#
p2 <- ggplot(df.plot, aes(x = SSB*1e-6, y = TAC*1e-6))+geom_line(size = 0.8)+
  geom_line(aes(y = TAC.JMC*1e-6), color = alpha('red',0.5), linetype = 2, size = 0.8)+
  geom_line(aes(y = TAC.realized*1e-6), color = alpha('blue',0.5), linetype = 2, size = 0.8)+
  scale_y_continuous('TAC (million tonnes)')+
  scale_x_continuous('SSB (million tonnes)')+theme_classic()
#png('SSB_tac.png', width = 16, height = 12, unit = 'cm', res =400)
p2
# dev.off()



png('results/Figs/tacplot.png', width = 12, height = 8, unit = 'cm', res =400)
p1
dev.off()

# Without the floor thing
png('results/Climate/tacs.png', width = 8, height = 5, unit = 'cm', res =400)
p3
dev.off()
