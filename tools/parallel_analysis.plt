# -------------------------------------------------
# How to use it:
# 
# 1. Basic Run (Defaults)
# If your data is named tmp.csv, simply run:
# $ gnuplot analysis_color.plt
# (This outputs a file named analysis.pdf by default)
# 
# 2. Customise Input and Output Files
# You can pass your own filenames and output formats (.png, .eps, or
# .pdf) using the -e flag:
# $ gnuplot -e "file='my_data.csv'; outfile='result.png'" analysis_color.plt
# 
# 3. Add a Custom Title
# You can also change the graph title on the fly:
# $ gnuplot -e "file='my_data.csv'; outfile='result.eps'; title_text='Simulation Run A'" analysis_color.plt
# 
# 4. Resize for Side-by-Side in LaTeX (EPS only)
# If you want to put two graphs side-by-side in a LaTeX document,
# you can easily adjust the width, height (in inches),
# and font size so it fits perfectly in a single column without squashing the text:
# $ gnuplot -e "file='my_data.csv'; outfile='graph1.eps'; eps_w=4.5; eps_h=3.5; eps_fsize=12" analysis_color.plt
#
# 5. Set Maximum Limits and Grid Steps (For Perfect Comparison)
# $ gnuplot -e "file='data1.csv'; x_max=150; y_max=3000; y_step=500; y2_max=200; y2_step=50" analysis_color.plt

reset
set datafile separator comma

# --------------------------------
# Named arguments and default values
# --------------------------------
if (!exists("file"))       file = "tmp.csv"
if (!exists("outfile"))    outfile = "analysis.pdf"
if (!exists("title_text")) title_text = "Analysis"

if (!exists("eps_w"))      eps_w = 3.5
if (!exists("eps_h"))      eps_h = 2.5
if (!exists("eps_fsize"))  eps_fsize = 12

if (!exists("x_max"))      x_max = -1
if (!exists("y_max"))      y_max = -1
if (!exists("y2_max"))     y2_max = -1

if (!exists("y_step"))     y_step = -1
if (!exists("y2_step"))    y2_step = -1

# --------------------------------
# Retrieve data summary
# --------------------------------
stats file using 1 nooutput
ncols = STATS_columns
nrows = STATS_records

stats file using 4 nooutput
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

# --------------------------------
# Auto-detect output format and Adjust Font Size
# --------------------------------
outlen = strlen(outfile)
is_png = (outlen >= 4 && substr(outfile, outlen-3, outlen) eq ".png")
is_eps = (outlen >= 4 && substr(outfile, outlen-3, outlen) eq ".eps")

base_fsize = 10
key_fsize = 9
xaxis_label = "step\n\n"

if (is_png) {
    set terminal pngcairo size 1000,600 font "sans,".base_fsize noenhanced
} else {
    if (is_eps) {
        xaxis_label = "step\n"
        base_fsize = eps_fsize
        key_fsize = eps_fsize - 2
        set terminal epscairo size eps_w, eps_h font "sans,".base_fsize noenhanced
    } else {
        set terminal pdf size 10,6 font "sans,".base_fsize noenhanced
    }
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

if (y_max > 0) { set yrange [0:y_max] } else { set yrange [0:*] }

if (y_step > 0) { set ytics y_step }

# --- Y2 axis (Right) ---
set y2label "Agents"
set y2tics

if (y2_max > 0) { set y2range [0:y2_max] } else { set y2range [0:agents_top] }

if (y2_step > 0) { set y2tics y2_step }


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
set key outside below center vertical maxrows 4 Left reverse samplen 1.5 spacing 1.2 font ",".key_fsize width 2

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
print "========================================="

set output