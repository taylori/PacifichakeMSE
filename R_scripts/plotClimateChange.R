library(reshape2)
library(cowplot)
library(RColorBrewer)
library(PacifichakeMSE)
library(patchwork)

simyears <- 30
df <- load_data_seasons()
year.future <- c(df$years,(df$years[length(df$years)]+1):(df$years[length(df$years)]+simyears))

cincrease <- 0
mincrease <- 0

# Plot the way climate works
cincrease <- c(0,0.02,0.04)
mincrease <- c(0,0.005,0.02)

movemax <- matrix(NA, length(cincrease), simyears)
moveout <- matrix(NA, length(cincrease), simyears)

moveout[,1] <- df$moveout
movemax[,1] <- df$movemax[1]

for(j in 1:length(cincrease)){
  for(time in 2:simyears){

    movemax[j,time] <- movemax[j,time-1]+cincrease[j]
    moveout[j,time] <- moveout[j,time-1]-mincrease[j]


    if(movemax[j,time] >0.9){
      movemax[j,time] <- 0.9 # Not moving more than 90% out t

      if(moveout[j,time] <= 0.5){
        moveout[j,time] <- 0.5
      }
    }
  }
}

cols <- PNWColors::pnw_palette('Starfish',n = 4, type = 'discrete')[2:4]

df.tmp <- as.data.frame(t(movemax))
names(df.tmp) <- c('base \nscenario', 'moderate \nincrease ','high \nincrease')
df.tmp$year <- year.future[year.future > 2018]

df.plot <- melt(df.tmp, id.vars = 'year', measure.vars = 1:length(cincrease), value.name = 'movemax', variable.name = 'Scenario')

p1 <- ggplot(df.plot, aes(x = year, y = movemax, color = Scenario))+theme_classic()+geom_line(size = 1.4)+
  coord_cartesian(ylim = c(0.2,1))+
  scale_color_manual(values = cols)+
  scale_y_continuous('max movement rate')+
  theme(legend.position = 'top', legend.title = element_blank(),
        axis.line.x = element_blank(),
        axis.title.x.bottom = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.x = element_blank(),
        legend.text = element_text(size = 10),
        legend.spacing.x =unit(0.001,'cm'))
p1


df.tmp <- as.data.frame(t(moveout))
names(df.tmp) <- c('base scenario', 'moderate increase','high increase')
df.tmp$year <- year.future[year.future > 2018]

df.plot <- melt(df.tmp, id.vars = 'year', measure.vars = 1:length(cincrease), value.name = 'moveout', variable.name = 'Scenario')
p2 <- ggplot(df.plot, aes(x = year, y = moveout, color = Scenario))+theme_classic()+geom_line(size = 1.4)+coord_cartesian(ylim = c(0.3,0.9))+
  scale_color_manual(values = cols)+scale_y_continuous('return rate')+
  theme(legend.position = 'none')


png('results/Figs/climate_movement.png', width= 8, height = 10, units = 'cm', res = 400)
#windows(width = 8/2.54, height = 10/2.54)
p1 / p2 + plot_annotation(tag_levels = 'a')
dev.off()




