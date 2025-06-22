library(tidyverse)
library(scales)
library(ggthemes)

library(showtext)
font_add("Latin Modern Roman", "/usr/share/fonts/OTF/lmroman10-regular.otf")
font_add("Latin Modern Sans", "/usr/share/fonts/OTF/lmsans10-regular.otf")
showtext_auto()

pareto_front <- function(x, y) {
	df = data.frame(x = x, y = y)
	ordered_df = df[order(df$x, df$y, decreasing=FALSE),]
	front = ordered_df[which(!duplicated(cummin(ordered_df$y))),]
	front
}

data <- read_csv("results/results.csv")
spec_data <- read_csv("../2.1_test/results/results.csv")
data <- bind_rows(data, filter(spec_data, benchmark == "spec.x264"))

variance <- (data %>% group_by(benchmark, interval, cluster) %>% summarise(cpi_var = var(cpi), len = length(cpi), ipc_var = var(ipc), cpi_sd = sd(cpi), ipc_sd = sd(ipc)))
mean_variance <- (variance %>% group_by(interval) %>% summarise(cpi_mean = mean(cpi_var, na.rm = TRUE), ipc_mean = mean(ipc_var, na.rm = TRUE)))

# be AWARE of the filter occurring here
variance_by_interval <- ggplot(filter(variance, len == 10), aes(x = 0, y = ipc_var)) +

#	geom_violin(scale = "width") +
#	geom_hline(aes(yintercept = ipc_mean), mean_variance, colour = "red") +

	geom_boxplot(outliers = FALSE, width=0.5) +

	geom_jitter(alpha=0.25, width = 0.125) +
#	geom_point() +

#	geom_smooth(se = FALSE) +
#	geom_line(data = mean_variance, aes(x = interval, y = mean), color = "blue") +

#	scale_x_continuous(transform = "log2", breaks = seq(1000, 32000, by=1000),
#		labels = c("1000", "2000", "", "4000", rep("", 3), "8000", rep("", 7), "16000", rep("", 15), "32000")) +
	scale_x_continuous(breaks = c(), lim=c(-0.3, 0.3)) +
	facet_grid(cols = vars(interval), labeller = labeller(interval = \(xs)label_comma()(map_vec(xs, as.integer)))) +
	labs(x = "Interval Size (instructions)", y = "Cluster Estimated IPC Variance") +
	scale_colour_few()

ggsave(plot = variance_by_interval + theme_few(base_family="Latin Modern Roman", base_size=10),
       "plots/variance_by_interval_ipc.svg", width=15, height=8, unit="cm")
ggsave(plot = variance_by_interval + theme_few(base_family="Latin Modern Sans", base_size=10) + theme(plot.background = element_rect(fill = "#f9f9f9"), strip.background = element_rect(fill = "#f9f9f9"), rect = element_rect(fill = "#f9f9f9")),
       "plots/present_var_by_interval_ipc.svg", width=15, height=10, unit="cm")

# calculate weighted average
selected <- (filter(data, index == 0) %>%
# interval used for simulation interval (ie. the number of instructions executed)
# width is the group of weights we should use
# add on subsampled data
	mutate(source = "Super-sample", width = interval, cputime=timing) %>% select(!timing) %>%
# fix off-by-one in data. output folders use one-indexed gem5 checkpoint id and weights use zero-index simpoint cluster
	bind_rows(read_csv("../5_downsampling/results.csv") %>% mutate(cluster = cluster - 1, source = "Truncated", width = 4000000)) %>%
	bind_rows(read_csv("../5.1_x264/results.csv")       %>% mutate(cluster = cluster - 1, source = "Truncated", width = 4000000)))

weights <- read_csv("simpoints/weights.csv")
spec_weights <- read_csv("../2.1_test/simpoints/weights.csv")
weights <- bind_rows(weights, filter(spec_weights, benchmark == "spec.x264"))
# rename interval column as width
weights <- (mutate(weights, width = interval) %>% select(!interval))

estimates <- selected %>% select(!index) %>%
	full_join(weights) %>% group_by(benchmark, interval, source) %>%
	summarise(weighted_cpi = sum(cpi * weight), weighted_ipc = sum(ipc * weight), cputime = sum(cputime))

# get regular samples to compare to
regular <- (bind_rows(read_csv("./regular.csv"), read_csv("../2.1_test/regular.csv")) %>%
	    group_by(benchmark, interval) %>%
	    summarise(weighted_cpi = mean(cpi, na.rm=TRUE), weighted_ipc = mean(ipc, na.rm=TRUE), ipc_var = var(ipc, na.rm=TRUE), cputime=sum(cputime)) %>%
	    mutate(source = "Random"))

reg_var <- ggplot(regular, aes(x = interval, y = ipc_var, colour=benchmark)) + geom_point()

estimates <- bind_rows(estimates, regular)

# get baseline to compare to
baseline <- read_csv("baseline/baseline.csv")
spec_baseline <- read_csv("../2.1_test/baseline/baseline.csv")
baseline <- bind_rows(baseline, filter(spec_baseline, benchmark == "spec.x264"))

error <- baseline %>% full_join(estimates, by = join_by(benchmark)) %>%
	mutate(cpi_error = abs(weighted_cpi - real_cpi),
	       ipc_error = abs(weighted_ipc - real_ipc),
	       cpi_percent_error = cpi_error / real_cpi,
	       ipc_percent_error = ipc_error / real_ipc)

ipc_error_by_interval <- ggplot(filter(error, source != "Random"), aes(x = interval, y = ipc_percent_error, colour = benchmark, linetype = source)) +
	geom_vline(xintercept=4000000, linetype="dotted") +
	geom_point() + geom_line() +
	scale_y_continuous(lim = c(0, NA), labels = scales::label_percent()) +
	scale_x_continuous(labels = scales::label_comma()) +
	labs(x = "Interval Width (instructions)", y = "IPC Error", colour = "Benchmark", linetype="Method") +
	 scale_colour_few()
ggsave(plot = ipc_error_by_interval + theme_few(base_family="Latin Modern Roman", base_size=10) + theme(legend.position="bottom"), "plots/ipc_error_by_interval.svg", width=15, height=8, unit="cm")
ggsave(plot = ipc_error_by_interval + theme_few(base_family="Latin Modern Sans", base_size=10) + theme(legend.position="bottom", plot.background = element_rect(fill = "#f9f9f9"), strip.background = element_rect(fill = "#f9f9f9"), rect = element_rect(fill = "#f9f9f9")), "plots/present_ipc_error_by_interval.svg", width=15, height=10, unit="cm")

random_e <- filter(error, source == "Random")
random_pf <- pareto_front(random_e$cputime, random_e$ipc_percent_error) 
super_e <- filter(error, source == "Super-sample")
super_pf <- pareto_front(super_e$cputime, super_e$ipc_percent_error)
trunc_e <- filter(error, source == "Truncated")
trunc_pf <- pareto_front(trunc_e$cputime, trunc_e$ipc_percent_error)

pareto_error <- ggplot(error, aes(x = cputime, y = ipc_percent_error, colour = source)) +
       	geom_point() +
	geom_step(data = random_pf, aes(x=x, y=y, colour="Random")) +
	geom_step(data = super_pf, aes(x=x, y=y, colour="Super-sample")) +
	geom_step(data = trunc_pf, aes(x=x, y=y, colour="Truncated")) +
	scale_y_continuous(lim = c(0, max(error$ipc_percent_error)), labels = scales::label_percent()) +
	scale_x_continuous(lim = c(0, max(error$cputime)), labels = scales::label_timespan(), breaks=c(0, 120, 240, 360, 480, 600)) +
	labs(x = "CPU User Time", y = "IPC Error", colour = "Method") +
	scale_colour_few()
ggsave(plot=pareto_error + theme_few(base_family="Latin Modern Roman", base_size=10) + theme(legend.position="bottom"), "plots/error_pareto.svg", width=15, height=15, unit="cm")
ggsave(plot=pareto_error + theme_few(base_family="Latin Modern Sans", base_size=10) + theme(plot.background = element_rect(fill = "#f9f9f9"), strip.background = element_rect(fill = "#f9f9f9"), rect = element_rect(fill = "#f9f9f9")), "plots/present_error_pareto.svg", width=14, height=10, unit="cm")


# variance summarised plot with random samples too
variance_summary = bind_rows(
	filter(variance, len == 10) %>% group_by(benchmark, interval) %>%
		summarise(ipc_var = median(ipc_var, na.rm=TRUE)) %>%
		mutate(source = "Super-sample"),
	regular %>% select(benchmark, interval, ipc_var, source)
)

variance_clear <- ggplot(variance_summary, aes(x = interval, y = ipc_var, colour = source)) +
	geom_point() +
	geom_line() +
	facet_grid(rows = vars(benchmark), scales = "free") +
	scale_x_continuous(labels = scales::label_comma()) +
	scale_colour_few() +
	labs(y = "IPC Variance", x = "Interval Width (instructions)", colour = "Method")
ggsave(plot = variance_clear + theme_few(base_family="Latin Modern Roman", base_size=10), "plots/variance_clearer.svg", width=15, height=8, unit="cm")
ggsave(plot = variance_clear + theme_few(base_family="Latin Modern Sans", base_size=10), "plots/present_variance_clearer.svg", width=15, height=10, unit="cm")
