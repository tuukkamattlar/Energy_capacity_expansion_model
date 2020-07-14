using Plots, CSV, DataFrames, StatsPlots, PlotThemes
gr()



#PLOTTING DISTRIBUTION
ud = CSV.read("data/cEU_22.csv"; delim=";") #RENEWABLES NINJA
reg = ["BE","BG","CZ","DK","DE","EE","IE","EL","ES","FR","HR","IT","CY","LV","LT","LU","HU","MT","NL","AT","PL","PT","RO","SI","SK","FI","SE","UK"]
udT = Matrix(ud[:,2:29])
udTT = transpose(udT[1:7,:])
theme(:wong2)
#1
pl = groupedbar(udTT, bar_position = :stack, bar_width=0.7, xticks = (1:28, reg), label = "")



savefig("europe.png")




#current().series_list[1].["Combustible Fuels", "Nuclear", "Hydro", "Wind", "Solar", "Other renewables", "Other Sources"][:label] = "label1"
#plot(label = ["Combustible Fuels", "Nuclear", "Hydro", "Wind", "Solar", "Other renewables", "Other Sources"])

#2

groupedbar(udTT[10:19,:], bar_position = :stack, bar_width=0.7, xticks = (1:28, ses[10:19]))
