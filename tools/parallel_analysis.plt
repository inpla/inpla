# -------------------------------------------------
# parallel_analysis.plt
#
# Plot execution profiles produced by Inpla.
#
# This script visualises:
#   - executed active pairs per step (stacked bars, left y-axis)
#   - number of agents per step (line plot, right y-axis)
#
# Expected CSV header:
#   step,exec(<num>),stacked,agents,rule1,rule2,...
#
# Basic usage:
#   $ gnuplot tools/parallel_analysis.plt
#
# Example:
#   $ ./inpla -f add1.in -s 0 2> tmp.csv
#   $ gnuplot -e "file='tmp.csv'; outfile='add1.eps'; title_text='(a+b)+c'" tools/parallel_analysis.plt
#
# Main parameters:
#   file        : input CSV file        (default: "tmp.csv")
#   outfile     : output figure file    (default: "analysis.pdf")
#   title_text  : plot title            (default: "Analysis")
#   fig_w       : figure width          (default: 3.5)
#   fig_h       : figure height         (default: 2.5)
#   font_size   : base font size        (default: 12)
#   key_fsize   : legend font size      (default: follow font_size)
#   png_dpi     : DPI used for PNG      (default: 200)
#   x_max       : maximum x value
#   y_max       : maximum y value (executions)
#   y2_max      : maximum y2 value (agents)
#   x_step      : x-axis tick step (optional)
#   y_step      : y-axis tick step
#   y2_step     : y2-axis tick step
#
# Notes:
#   - The output format is selected automatically from the extension
#     of 'outfile' (.pdf, .png, .eps).
#   - CSV data from Inpla is typically written to STDERR.
#   - Use title_text instead of title to avoid clashes with
#     gnuplot's internal 'set title' command.
# -------------------------------------------------

reset
set datafile separator comma

# --------------------------------
# Named arguments and default values
# --------------------------------
if (!exists("file"))        file = "tmp.csv"
if (!exists("outfile"))     outfile = "analysis.pdf"
if (!exists("title_text"))  title_text = "Analysis"

if (!exists("fig_w"))       fig_w = 3.5
if (!exists("fig_h"))       fig_h = 2.5
if (!exists("font_size"))   font_size = 12
if (!exists("key_fsize"))   key_fsize = -1
if (!exists("png_dpi"))     png_dpi = 200

if (!exists("x_max"))       x_max = -1
if (!exists("y_max"))       y_max = -1
if (!exists("y2_max"))      y2_max = -1

if (!exists("x_step"))      x_step = -1
if (!exists("y_step"))      y_step = -1
if (!exists("y2_step"))     y2_step = -1

if (!exists("show_key"))    show_key = 1

# --------------------------------
# Retrieve data summary
# --------------------------------
# Skip the header row when collecting statistics
stats file every ::1 nooutput

if (!exists("STATS_columns") || !exists("STATS_records") || STATS_records < 1) {
    print sprintf("Error: no valid numeric data rows found in %s", file)
    exit
}

ncols = STATS_columns
nrows = STATS_records

# Column 4 = agents
stats file every ::1 using 4 nooutput
agents_max = STATS_max
agents_top = (agents_max > 0) ? agents_max * 1.1 : 1

actual_xmax = (x_max > 0) ? x_max : nrows

# --------------------------------
# Configure x-axis tick thinning
# --------------------------------
xtic_every = 1
if (actual_xmax > 15)  xtic_every = 2
if (actual_xmax > 30)  xtic_every = 5
if (actual_xmax > 60)  xtic_every = 10
if (actual_xmax > 120) xtic_every = 20
if (actual_xmax > 240) xtic_every = 50
if (actual_xmax > 600) xtic_every = 100

# If x_step is explicitly specified, use it
if (x_step > 0) {
    xtic_every = x_step
}

# --------------------------------
# Auto-detect output format and set terminal
# --------------------------------
outlen = strlen(outfile)
is_png = (outlen >= 4 && substr(outfile, outlen-3, outlen) eq ".png")
is_eps = (outlen >= 4 && substr(outfile, outlen-3, outlen) eq ".eps")

base_fsize = font_size
xaxis_label = "step\n\n"

if (is_png) {
    png_w = int(fig_w * png_dpi)
    png_h = int(fig_h * png_dpi)
    set terminal pngcairo size png_w,png_h font "sans,".base_fsize noenhanced
} else {
    if (is_eps) {
        xaxis_label = "step\n"
        set terminal epscairo size fig_w, fig_h font "sans,".base_fsize noenhanced
    } else {
        set terminal pdf size fig_w, fig_h font "sans,".base_fsize noenhanced
    }
}

# If legend font size is not specified, follow the base font size
if (key_fsize <= 0) {
    key_fsize = base_fsize
}

set output outfile

# --------------------------------
# Axis and style configuration
# --------------------------------
set title title_text
set xlabel xaxis_label

# --- Y1 axis (Left) ---
set ylabel "Executions"
set ytics nomirror

if (y_max > 0) { 
    set yrange [0:y_max]
} else { 
    set yrange [0:*]
}

if (y_step > 0) { 
    set ytics y_step
}

# --- Y2 axis (Right) ---
set y2label "Agents"
set y2tics

if (y2_max > 0) { 
    set y2range [0:y2_max]
} else { 
    set y2range [0:agents_top]
}

if (y2_step > 0) { 
    set y2tics y2_step
}

set grid y
if (is_eps) {
    set style fill solid 1.0 noborder
} else {
    set style fill solid 0.8 border -1
}

# --------------------------------
# X-axis ticks
# --------------------------------
set xrange [-1 : actual_xmax]
unset xtics
set xtics ("0" -1) out nomirror
set for [i=xtic_every:actual_xmax:xtic_every] xtics add (sprintf("%d", i) i-1)

# --------------------------------
# Legend
# --------------------------------
if (show_key) {
   set key outside below center horizontal samplen 1.5 spacing 1.2 font ",".key_fsize width 2
} else {
  unset key
}
set style data histograms
set style histogram rowstacked
set boxwidth 0.8

# --------------------------------
# Draw termination line if data ends before x_max
# --------------------------------
data_end_x = nrows - 1
if (x_max > 0 && data_end_x < x_max) {
    set arrow from data_end_x, graph 0 to data_end_x, graph 1 nohead dt 2 lc rgb "gray" lw 1.5
}

# --------------------------------
# Plotting
# --------------------------------
plot \
    file using 5 axes x1y1 title columnhead(5) lc rgb "#4e79a7", \
    for [i=6:ncols] file using i axes x1y1 \
        title columnhead(i) lc rgb ( \
            ((i-5)%24==0 ? "#4e79a7" : \
             (i-5)%24==1 ? "#f28e2b" : \
             (i-5)%24==2 ? "#e15759" : \
             (i-5)%24==3 ? "#76b7b2" : \
             (i-5)%24==4 ? "#59a14f" : \
             (i-5)%24==5 ? "#edc948" : \
             (i-5)%24==6 ? "#b07aa1" : \
             (i-5)%24==7 ? "#ff9da7" : \
             (i-5)%24==8 ? "#9c755f" : \
             (i-5)%24==9 ? "#bab0ab" : \
             (i-5)%24==10 ? "#1f77b4" : \
             (i-5)%24==11 ? "#ff7f0e" : \
             (i-5)%24==12 ? "#2ca02c" : \
             (i-5)%24==13 ? "#d62728" : \
             (i-5)%24==14 ? "#9467bd" : "#888888")), \
    file using 0:4 axes x1y2 with lines lw 2 lc rgb "#1f77b4" title columnhead(4)

# --------------------------------
# Console Output
# --------------------------------
print "========================================="
print " Graph plotted successfully: ", outfile
print "-----------------------------------------"
print sprintf(" X-axis max (step)   : %g", GPVAL_X_MAX)
print sprintf(" Y-axis max (Exec)   : %g", GPVAL_Y_MAX)
print sprintf(" Y2-axis max (Agents): %g", GPVAL_Y2_MAX)
print sprintf(" Figure size         : %.2f x %.2f", fig_w, fig_h)
print sprintf(" Base font size      : %g", base_fsize)
print sprintf(" Legend font size    : %g", key_fsize)
if (is_png) {
    print sprintf(" PNG pixel size      : %d x %d", png_w, png_h)
}
print "========================================="

set output