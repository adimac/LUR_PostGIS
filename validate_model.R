require(nlme)
require(Metrics)
require(plyr)
require(reshape)
require(ggplot2)
require(predictmeans)
require(rgeos)
require(sp)
require(caret)
require(RANN)
require(spdep)
require(car)
require(splitstackshape)
require(dplyr)

set.seed(6789)
df <- read.csv("mydata\\input_vars.csv")
x <- df

#save the strata
strata <- list()

for (i in 1:10) {
  ssize <- 48 / nrow(x)
  if (i < 10) {
    #take sample
    s <- stratified(x, c("region", "site_type"), size = ssize)$gid
    #Remove sampled points from the pool
    x <- x[-which(x$gid %in% as.integer(s)), ]
  } else {
    s <- x$gid
  }
  
  #Save strata to a list for later
  strata[[i]] <- s
  
  #progress
  print(paste("sample", i, ": size=", length(s), sep=" "))
}

#Remove duplicates
l <- unlist(strata)
l <- l[duplicated(l)]
l.found <- rep(FALSE, length(l))
l

for (i in 1:10) {
  for(j in 1:length(strata[[i]])) {
    for (k in 1:length(l)) {
      if (strata[[i]][j] == l[k] && !l.found[k]) {
        l.found[k] <- TRUE
        strata[[i]] <- strata[[i]][-j]
      }
    }
  }
}

#Shuffle around - Get all strata to size 48 or less
pool <- vector()
for (i in 1:10) {
  if (length(strata[[i]]) > 48) {
    #Too big
    while (length(strata[[i]]) != 48) {
      #throw away point
      j <- floor(runif(1, 1, length(strata[[i]])))
      stolen <- strata[[i]][j]
      strata[[i]] <- strata[[i]][-j]
      
      #add the point a pool
      pool <- append(pool, stolen)
      print(stolen)
    }
  }
}

#Shuffle around - redistribute 'pool' back to strata < 48
j <- 1
for (i in 1:9) {
  if (length(strata[[i]] < 48)) {
    while (length(strata[[i]]) != 48) {
      #append point
      strata[[i]] <- append(strata[[i]], pool[j])
      j <- j + 1
    }
  }
}
#if any left add to strata 10
if (j != length(pool)) {
  for (i in j:length(pool)) {
    strata[[10]] <- append(strata[[10]], pool[i])
  }
}

#check the lengths
unlist(lapply(strata, length))


#Do the models (reconstruct dataset based on strata)

store.pred <- data.frame()
store.p <- matrix(0, 0, length(coef(this.lm)))
store.c <- matrix(0, 0, length(coef(this.lm)))
store.rsd <- vector()

store.rmse <- vector()
store.r2 <- vector()

df <- read.csv("mydata\\input_vars.csv")
for (i in 1:10) {
  print(i)
  this.set <- which(df$gid %in% strata[[i]])
  validation <- df[this.set, ]
  training <- df[-this.set, ]
  
  #model#
  this.lm <- lm("mean_no2 ~ disconurban10000 + majorroadlength100 + conturb1000 + forest500 + agri10000", data = training)
  
  this.pred <- data.frame(predict(this.lm, newdata = validation, response="predict"))
  this.pred$obs <- validation$mean_no2
  this.pred$gid <- validation$gid
  this.pred$site <- validation$site_type
  
  
  
  names(this.pred) <- c("pred", "obs", "gid", "site")
  
  store.pred <- rbind(store.pred, this.pred)
  
  #Save some accuracy stats
  store.p <- rbind(store.p, summary(this.lm)$coefficients[, 4]) 
  store.c <- rbind(store.c, summary(this.lm)$coefficients[, 1])
  store.rsd <- append(store.rsd, this.lm$residuals)
  
  
  
  print(summary(this.lm)$adj.r.squared)
  # store.rsq <- append(store.rsq, summary(lm.lur)$adj.r.squared)
  
  
  store.r2 <- append(store.r2, summary(this.lm)$adj.r.squared)
  store.rmse <- append(store.rmse, summary(this.lm)$sigma)
  
  ##Rsq, RMSE, coefficients etc...
  
}

##DO SOME PLOTS
valid.out <- data.frame(R2 = store.r2, RMSE = store.rmse)
valid.out <- cbind(valid.out, store.c)
store.p <- data.frame(store.p)
names(store.p) <- paste0(names(this.lm$coefficients), "_p")
valid.out <- cbind(valid.out, store.p)

##boxplots on p values
#ggplot(melt(valid.out[  , 9:14]), aes(y=value, x=variable)) + 
#  geom_boxplot() + facet_wrap(~variable, scales = "free") +
#  ylab("p-value") + ggtitle("Model p-values")

#boxplots on coefficients
ggplot(melt(valid.out[  , 3:8]), aes(y=value, x=variable)) + 
  geom_boxplot() + facet_wrap(~variable, scales = "free") +
  ylab("coeff") + ggtitle("Model coefficients")

#boxplots on R2
# bp <- data.frame(value = valid.out$R2, label = "R2")
# ggplot(bp, aes(y=value, x="")) + geom_boxplot() + 
#   facet_wrap(~label, nrow = 1, scales = "free") +
#   xlab("") + ylab("") + ggtitle("Model R2")


##scatterplot
ggplot(store.pred, aes(obs, pred, color=factor(site))) + geom_point() +
  geom_abline(aes(intercept=0, slope=1), lty=2) +
  ggtitle("French National LUR Model") +
  xlab(expression(Measured~NO[2]~mu~g~m^"-3")) +
  ylab(expression(Modelled~NO[2]~mu~g~m^"-3")) +
  theme_grey(base_size = 26) +
  theme(plot.title = element_text(hjust = 0), legend.title = element_blank()) +
  ylim(0, 120) +
  xlim(0, 120)


#actual lm of the line obs vs pred
over <- lm(store.pred$obs ~ store.pred$pred)
summary(over)
