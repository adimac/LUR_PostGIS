require(nlme)
require(Metrics)
require(plyr)
require(reshape)
require(predictmeans)
require(rgeos)
require(sp)
require(maptools)
require(caret)
require(RANN)
require(spdep)
require(car)

lur.vars <- read.csv("my_data\\input_vars.csv") ##output file from PostGIS processing procedures

######################################################################
#######get rid of extraneous variables XEN_code - coded###############
####################more efficient####################################
######################################################################
min.lur <- as.formula(mean_no2 ~ 1) ## Set null model (intercept only)
min.lur.lm <- lm(min.lur, data = lur.vars)

max.lur <- paste("mean_no2", paste(names(lur.vars)[1:length(lur.vars) - 1], 
                              collapse=" + "),sep = "~") ## Set max model (all variables)
max.lur.lm <- lm(as.formula(max.lur), data = lur.vars)

fwd.lur <- step(min.lur.lm, scope=list(lower=min.lur.lm, upper=max.lur.lm), direction="both")
summary(fwd.lur)

##linear regression - stepwise after removing extraneous and obeying "rules" for LUR
 summary(lm(lur.vars$mean_no2~lur.vars$disconurban10000 + lur.vars$majorroadlength100 +
#            lur.vars$conturb1000 + lur.vars$forest500 + lur.vars$agri10000))
#      
# 
 full <- lm(lur.vars$mean_no2~lur.vars$disconurban10000 + lur.vars$majorroadlength100 +
#              lur.vars$conturb1000 + lur.vars$forest500 + lur.vars$agri10000)


##check collinearity
vif(full)


##plot changes
v <- names(full$coefficients)[-1]
step.r2 <- sapply(1:length(v), function(x) summary(lm(as.formula(paste("mean_no2", 
                                                                       paste(v[1:x], collapse = " + "), sep = "~")), data = lur.vars))$adj.r.squared)

## Percentage difference in R2 between steps
diff.r2 <- (step.r2[2:length(v)] - step.r2[1:length(v) - 1]) * 100

diff.r2
step.r2

dev.off()
par(mfrow = c(1, 2))
plot(diff.r2, type = "o", main = "R2 difference")
plot(step.r2, type = "o", main = "R2") 

##diagnostics for eval (graphs produced - q-q, residuals, cook's d etc)
plot(full)






#####################################################################
######most correlated variable - manual stepwise#####################
############user-intensive and inefficient###########################
#####################################################################
cor.table <- apply(lur.vars, 2, function(x) cor(lur.vars$mean_no2, x))
cor.table[is.na(cor.table)] <- 0
which(cor.table == max(abs(cor.table[2:length(cor.table)])))

##select variable from roadlengths
lur.vars.roadlengths <- lur.vars[c("roadlength25", "roadlength50", "roadlength100", "roadlength300", "roadlength500",
                                   "roadlength1000", "majorroadlength25", "majorroadlength50", "majorroadlength100",
                                   "majorroadlength300", "majorroadlength500", "majorroadlength1000")]
cor.table <- apply(lur.vars.roadlengths, 2, function(x) cor(lur.vars$mean_no2, x))
cor.table[is.na(cor.table)] <- 0
which(cor.table == max(abs(cor.table[1:length(cor.table)])))

##check performance
summary(lm(lur.vars$mean_no2~lur.vars$disconurban10000 + lur.vars$roadlength1000))

##select variable from roaddists
lur.vars.roaddists <- lur.vars[c("distnear", "distinvnear", "intinvdist", "distnearmajor", "invdistmajor", "intmajorinvdist")]
cor.table <- apply(lur.vars.roaddists, 2, function(x) cor(lur.vars$mean_no2, x))
cor.table[is.na(cor.table)] <- 0
which(cor.table == max(abs(cor.table[1:length(cor.table)])))

##check performance
summary(lm(lur.vars$mean_no2~lur.vars$disconurban10000 + lur.vars$roadlength1000 + lur.vars$distnearmajor))
