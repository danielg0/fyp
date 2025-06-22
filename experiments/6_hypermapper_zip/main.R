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

broken_pareto <- function(x, y) {
	function(df) {
		print(df)
		ordered_df = df[order(df[x], df[y], decreasing=FALSE), ]
		front = ordered_df[which(!duplicated(cummin(ordered_df[y]))),]
		front
	}
}

# write a pareto function as a selection
dplyr_pareto <- function(df) {
	# function that returns whether a point has any strictly dominating points
	
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


d16000000 <- (read_csv("results/16000000/results.csv") %>%
	    mutate(best_energy = accumulate(energy, min),
	    	best_performance = accumulate(performance, min),
	    	best_energy_baseline = accumulate(energy_baseline, min),
	    	best_performance_baseline = accumulate(performance_baseline, min),
		cumulative_time = accumulate(time, sum)))

random <- (read_csv("results/random/results.csv") %>%
	    mutate(best_energy = accumulate(energy, min),
	    	best_performance = accumulate(performance, min),
	    	best_energy_baseline = accumulate(energy_baseline, min),
	    	best_performance_baseline = accumulate(performance_baseline, min),
		cumulative_time = accumulate(time, sum)))

d4000000 <- (read_csv("results/4000000/results.csv") %>%
	    mutate(best_energy = accumulate(energy, min),
	    	best_performance = accumulate(performance, min),
	    	best_energy_baseline = accumulate(energy_baseline, min),
	    	best_performance_baseline = accumulate(performance_baseline, min),
		cumulative_time = accumulate(time, sum)))


combined <- bind_rows(mutate(d16000000, interval="16000000"), mutate(d125000, interval="125000"), mutate(random, interval="Random"), mutate(d4000000, interval="4000000"))

comb_0 <- filter(combined, cumulative_time <= 2500)
comb_1 <- filter(combined, cumulative_time <= 5000)
comb_2 <- filter(combined, cumulative_time <= 7500)
comb_3 <- filter(combined, cumulative_time <= 10000)

energy <- ggplot(combined, aes(x = cumulative_time, y = best_energy_baseline, colour=interval)) +
	geom_point(size=0.5) + geom_line() +
	scale_x_continuous(labels = scales::label_timespan(), breaks=c(0, 3600, 7200, 10800, 14400), lim=c(0, 15000)) +
	labs(x = "CPU User Time", y = "Lowest Energy Configuration Found (nJ/instruction)", colour="Interval Size (instructions)") +
	theme_few(base_family="Latin Modern Roman", base_size=10) + theme(legend.position="bottom") + scale_colour_few()

ggsave("plots/hypermapper_energy.svg", width=15, height=15, unit="cm")

# More data from combining sets of simpoints
m16000000 <- (read_csv("results/more/16000000/results.csv") %>%
	      mutate(best_energy = accumulate(energy, min),
		best_performance = accumulate(performance, min),
		best_area = accumulate(area, min),
		best_energy_baseline = accumulate(energy_baseline, min),
		best_performance_baseline = accumulate(performance_baseline, min),
		best_area_baseline = accumulate(area_baseline, min),
		cumulative_time = accumulate(time, sum)))

mrandom <- (read_csv("results/more/random/results.csv") %>%
	      mutate(best_energy = accumulate(energy, min),
		best_performance = accumulate(performance, min),
		best_area = accumulate(area, min),
		best_energy_baseline = accumulate(energy_baseline, min),
		best_performance_baseline = accumulate(performance_baseline, min),
		best_area_baseline = accumulate(area_baseline, min),
		cumulative_time = accumulate(time, sum)))

mjoint <- (read_csv("results/more/combined/results.csv") %>%
	      mutate(best_energy = accumulate(energy, min),
		best_performance = accumulate(performance, min),
		best_area = accumulate(area, min),
		best_energy_baseline = accumulate(energy_baseline, min),
		best_performance_baseline = accumulate(performance_baseline, min),
		best_area_baseline = accumulate(area_baseline, min),
		cumulative_time = accumulate(time, sum)))

mcombined <- bind_rows(mutate(m16000000, interval = "16000000"),
		       mutate(mrandom, interval = "Random"),
		       mutate(mjoint, interval = "Joint"))

more_0 <- filter(mcombined, cumulative_time <= 5000)
more_1 <- filter(mcombined, cumulative_time <= 10000)
more_2 <- filter(mcombined, cumulative_time <= 20000)
more_3 <- filter(mcombined, cumulative_time <= 30000)

m016 <- filter(more_0, interval == "16000000")
m116 <- filter(more_1, interval == "16000000")
m216 <- filter(more_2, interval == "16000000")
m316 <- filter(more_3, interval == "16000000")

m0j <- filter(more_0, interval == "Joint")
m1j <- filter(more_1, interval == "Joint")
m2j <- filter(more_2, interval == "Joint")
m3j <- filter(more_3, interval == "Joint")

m0r <- filter(more_0, interval == "Random")
m1r <- filter(more_1, interval == "Random")
m2r <- filter(more_2, interval == "Random")
m3r <- filter(more_3, interval == "Random")

more_progressive <- bind_rows(mutate(more_0, cutoff = 5000),
			      mutate(more_1, cutoff = 10000),
			      mutate(more_2, cutoff = 20000),
			      mutate(more_3, cutoff = 30000))

# do an anti-join, filtering to all rows that would not have a match on the right hand side, to get pareto points, those rows that aren't dominated by another row
# sorting needed to ensure geom_step drawn in correct order
pareto_points <- (anti_join(more_progressive, more_progressive, join_by(cutoff, interval, x$performance_baseline > y$performance_baseline, x$area_baseline > y$area_baseline)) %>% arrange(performance_baseline, -area_baseline))

facet_pareto <- ggplot(more_progressive, aes(x = performance_baseline, y = area_baseline)) +
	geom_point(size = 0.5) +
#	geom_point(data = mcombined, alpha = 0.1, size = 0.5) +
	geom_step(data = pareto_points, colour = "red", linewidth = 0.25) +
#	geom_step(data = pareto_front(m116$performance, m116$area), aes(x = x, y = y)) +
	#geom_function(fun = better_pareto("performance_baseline", "area_baseline")) +
	facet_grid(rows = vars(interval), cols = vars(cutoff)) +
	labs(x = "Performance (cycles/instruction)", y = "Area (square mm)") +
	scale_colour_few()
ggsave(plot = facet_pareto + theme_few(base_family = "Latin Modern Sans", base_size = 10) + theme(plot.background = element_rect(fill = "#f9f9f9"), strip.background = element_rect(fill = "#f9f9f9"), rect = element_rect(fill = "#f9f9f9")), "plots/present_facet_pareto.svg", width = 12, height = 8, units="cm")

# number of pareto points found at each cutoff
pareto_count <- ggplot(group_by(pareto_points, interval, cutoff) %>% summarise(count = length(cutoff)),
       aes(x = cutoff, y = count, colour = interval)) +
	geom_line() + geom_point() +
	scale_x_continuous(labels = scales::label_timespan(), breaks = c(0, 7200, 14400, 21600, 28800), lim = c(0, NA)) +
	scale_y_continuous(lim = c(0, NA)) +
	labs(x = "CPU User Time", y = "Pareto Configurations", colour = "Method") +
	scale_colour_few() + theme_few(base_family = "Latin Modern Sans", base_size = 10) +
	theme(plot.background = element_rect(fill = "#f9f9f9"), strip.background = element_rect(fill = "#f9f9f9"), rect = element_rect(fill = "#f9f9f9"))
ggsave(plot = pareto_count, "plots/pareto_count.svg", width = 15, height = 10, units = "cm")
