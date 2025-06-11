library(tidyverse)
library(ggthemes)

d125000 <- (read_csv("results/125000/results.csv") %>%
	    mutate(best_energy = accumulate(energy, min),
	    	best_performance = accumulate(performance, min),
	    	best_energy_baseline = accumulate(energy_baseline, min),
	    	best_performance_baseline = accumulate(performance_baseline, min),
		cumulative_time = accumulate(time, sum)))

pareto_front <- function(x, y) {
	df = data.frame(x = x, y = y)
	ordered_df = df[order(df$x, df$y, decreasing=FALSE),]
	front = ordered_df[which(!duplicated(cummin(ordered_df$y))),]
	front
}

# split overall experiment into 5 24000 cycle intervals
d125000_0 <- filter(d125000, cumulative_time <= 24000)
d125000_1 <- filter(d125000, cumulative_time <= 48000)
d125000_2 <- filter(d125000, cumulative_time <= 72000)
d125000_3 <- filter(d125000, cumulative_time <= 96000)
d125000_4 <- filter(d125000, cumulative_time <= 120000)

p <- ggplot(d125000, aes(x = energy_baseline, y = performance_baseline)) + #geom_point() +
	geom_step(data = pareto_front(d125000_0$energy_baseline, d125000_0$performance_baseline), aes(x = x, y = y, colour="0")) +
	geom_step(data = pareto_front(d125000_1$energy_baseline, d125000_1$performance_baseline), aes(x = x, y = y, colour="1")) +
	geom_step(data = pareto_front(d125000_2$energy_baseline, d125000_2$performance_baseline), aes(x = x, y = y, colour="2")) +
	geom_step(data = pareto_front(d125000_3$energy_baseline, d125000_3$performance_baseline), aes(x = x, y = y, colour="3")) +
	geom_step(data = pareto_front(d125000_4$energy_baseline, d125000_4$performance_baseline), aes(x = x, y = y, colour="4"))


q <- ggplot(d125000, aes(x = energy, y = performance)) + #geom_point() +
	geom_step(data = pareto_front(d125000_0$energy, d125000_0$performance), aes(x = x, y = y, colour="0")) +
	geom_step(data = pareto_front(d125000_1$energy, d125000_1$performance), aes(x = x, y = y, colour="1")) +
	geom_step(data = pareto_front(d125000_2$energy, d125000_2$performance), aes(x = x, y = y, colour="2")) +
	geom_step(data = pareto_front(d125000_3$energy, d125000_3$performance), aes(x = x, y = y, colour="3")) +
	geom_step(data = pareto_front(d125000_4$energy, d125000_4$performance), aes(x = x, y = y, colour="4"))

