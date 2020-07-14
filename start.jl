using Plots

#APPLY CARBON TAX and LENGTH
TAX = 25
LEN = 1000

include("main.jl")










## GATHER THE RESULTS

TransResults = zeros(length(Hours), length(Region), length(Region))
TransExpRestults = zeros(length(Region), length(Region))
AllResults = zeros(length(Hours), length(Tech), length(Region),5)

for h in Hours
    for t in Tech
        for r in Region
            AllResults[h, t, r, 1] = value(EnergyProduction[h, t, r])
            #AllResults[h, t, r, 2] = AdditionalCapacity[t, r]
            #AllResults[h, t, r, 3] = AdditionalCapacity[t, r]
            #AllResults[h, t, r, 4] = AdditionalCapacity[t, r]
        end
    end
end

for r in Region
    for rr in Region
        for h in Hours
            TransResults[h,r,rr] = value.(Trans[h, r, rr])
        end
        TransExpRestults[r,rr] = value.(AdditionalTrans[r,rr])
    end
end

#VISUALISATION PART
##

#GENERIC PLOTS FOR SOME REGIONS
for r in Region
    plot(AllResults[:,1:7,r,1], title="Region", label = ["Nuclear" "CHP" "OTHER COAL" "Gas" "Wind" "PV" "Hydro"])
end
plot(AllResults[:,1:7,1,1], label = ["Nuclear" "CHP" "OTHER COAL" "Gas" "Wind" "PV" "Hydro"])
plot(AllResults[:,1:7,2,1], label = ["Nuclear" "CHP" "OTHER COAL" "Gas" "Wind" "PV" "Hydro"])
plot(AllResults[:,1:7,3,1], label = ["Nuclear" "CHP" "OTHER COAL" "Gas" "Wind" "PV" "Hydro"])
plot(AllResults[:,1:7,4,1], label = ["Nuclear" "CHP" "OTHER COAL" "Gas" "Wind" "PV" "Hydro"])

##GATHERING DATA IN NEW FORMAT
pt = zeros(length(Hours), length(Region), length(Tech),2)
for h in Hours
    for r in Region
        pt[h, r, 1,1] = AllResults[h,1,r,1] + AllResults[h,2,r,1] + AllResults[h,3,r,1] + AllResults[h,4,r,1] + AllResults[h,5,r,1] + AllResults[h,6,r,1] + AllResults[h,7,r,1]
        pt[h, r, 2,1] = AllResults[h,1,r,1] + AllResults[h,2,r,1] + AllResults[h,3,r,1] + AllResults[h,4,r,1] + AllResults[h,5,r,1] + AllResults[h,7,r,1]
        pt[h, r, 3,1] = AllResults[h,1,r,1] + AllResults[h,2,r,1] + AllResults[h,3,r,1] + AllResults[h,4,r,1] + AllResults[h,7,r,1]
        pt[h, r, 4,1] = AllResults[h,1,r,1] + AllResults[h,2,r,1] + AllResults[h,3,r,1] + AllResults[h,7,r,1]
        pt[h, r, 5,1] = AllResults[h,1,r,1] + AllResults[h,2,r,1] + AllResults[h,3,r,1]
        pt[h, r, 6,1] = AllResults[h,1,r,1] + AllResults[h,3,r,1]
        pt[h, r, 7,1] = AllResults[h,3,r,1]

        pt[h, r, 1,2] = 1
        pt[h, r, 2,2] = (pt[h, r, 2,1])/pt[h, r, 1,1]
        pt[h, r, 3,2] = (pt[h, r, 3,1])/pt[h, r, 1,1]
        pt[h, r, 4,2] = (pt[h, r, 4,1])/pt[h, r, 1,1]
        pt[h, r, 5,2] = (pt[h, r, 5,1])/pt[h, r, 1,1]
        pt[h, r, 6,2] = (pt[h, r, 6,1])/pt[h, r, 1,1]
        pt[h, r, 7,2] = (pt[h, r, 7,1])/pt[h, r, 1,1]

    end
end

##PLOTTING THE GENERATION FOR A COUNTRY (select second parameter as in Region)
#STACKED PLOT
plot(pt[:,1,:,1], fill = (0, 1), palette=cgrad([:red, :green, :yellow, :blue]), label = ["PV" "WIND" "GAS" "HYDRO" "CHP" "Nuclear" "OTHER COAL"], ylim=0:12000)
#STACKED %-WISE PLOT
plot(pt[:,1,:,2], fill = (0, 0), palette=cgrad([:red, :green, :yellow, :blue, :red, :green, :yellow, :blue]), label = ["PV" "WIND" "GAS" "HYDRO" "CHP" "Nuclear" "OTHER COAL"], ylim=0:12000)

#TRANSMISSION
plot(TransResults[:,1,:])
#PROMBLEM: THERE STILL SEEMS TO BE

##LOOP FOR DETERMINING RENEWABLES SHARE IN COMPARISON TO TAX LEVEL
L = 50
result = Matrix{Float64}(undef, L, 15)
RENW = Matrix{Float64}(undef, length(Hours), 3)
#k = collect(1::L)
for i in 1:L
    TAX = i*10-10
    taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX*(1/proEmisFactor[t-1]) for t in CarbonTech, h in Hours, r in Region))
    @objective(model, Min , useC + einvC + sinvC + taxC + rampExp + transInv + transCost)
    optimized = optimize!(model)
    result[i,1] = objective_value(model)
    for h in Hours
        RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region))
        RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
        RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
    end
    result[i,2] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
    result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,3] for h in Hours )
end
plot(result[:,2])
plot(RENW[:,2])
plot(RENW[:,1])




## == FOLLOWING IS FULLY LEGACY ONLY FOR CODE SUPPORT REASONS == ##
###################################################################

pt = Matrix{Float64}(undef, length(Hours), 15)
for h in Hours
    pt[h, 1] = Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4] + Results[h,6] + Results[h,5] + Results[h,13]
    pt[h, 2] = Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4] + Results[h,6] + Results[h,5]
    pt[h, 3] = Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4] + Results[h,6]
    pt[h, 4] = Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4]
    pt[h, 5] = Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7]
    pt[h, 7] = Results[h,1] + Results[h,2] + Results[h,3]
    pt[h, 7] = Results[h,1] + Results[h,2]
    pt[h, 8] = Results[h,1]
end
plot(pt[:,1:8], fill = (0, 1), palette=cgrad([:red, :green, :yellow, :blue]), label = ["Storage" "Wind" "PV" "Gas" "Hydro" "CHP2" "CHP" "Nuclear"], ylim=0:12000)

#plot(pt[:,1])


pt = Matrix{Float64}(undef, length(Hours), 15)
for h in Hours
    a = 8*Results[h,1] + 7*Results[h,2] + 6*Results[h,3] + 5*Results[h,7] + 4*Results[h,4] + 3*Results[h,6] + 2*Results[h,5] + Results[h,13]
    pt[h, 1] = (Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4] + Results[h,6] + Results[h,5] + Results[h,13])/a
    pt[h, 2] = (Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4] + Results[h,6] + Results[h,5])/a
    pt[h, 3] = (Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4] + Results[h,6])/a
    pt[h, 4] = (Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7] + Results[h,4])/a
    pt[h, 5] = (Results[h,1] + Results[h,2] + Results[h,3] + Results[h,7])/a
    pt[h, 6] = (Results[h,1] + Results[h,2] + Results[h,3])/a
    pt[h, 7] = (Results[h,1] + Results[h,2])/a
    pt[h, 8] = (Results[h,1])/a
    pt[h, 8] = sum(pt[h,i] for i in 1:8)
    pt[h, 7] = sum(pt[h,i] for i in 1:7)
    pt[h, 6] = sum(pt[h,i] for i in 1:6)
    pt[h, 5] = sum(pt[h,i] for i in 1:5)
    pt[h, 4] = sum(pt[h,i] for i in 1:4)
    pt[h, 3] = sum(pt[h,i] for i in 1:3)
    pt[h, 2] = sum(pt[h,i] for i in 1:2)
    pt[h, 1] = sum(pt[h,i] for i in 1:1)
end
plot(pt[:,1:8], fill = (0, 1), label = ["Storage" "Wind" "PV" "Gas" "Hydro" "CHP2" "CHP" "Nuclear"], ylim=0:12000)
plot(pt[:,5])

additions = Array{Float64}(undef, length(Tech)+3)
for t in Tech
    additions[t] = value(AdditionalCapacity[t])
end
additions[8] = value(AdditionalStorage[1])
additions[9] = value(AdditionalStorage[2])
additions[10] = value(AdditionalStorage[3])
plot(additions)


rf = convert(DataFrame, Results)
using RCall
@rlibrary ggplot2

ggplot(data=Results, aes(x=rf, group=cut, fill=cut)) +
    geom_density(adjust=1.5, position="fill") +
    theme_ipsum()
)


CSV.write("exampletoplot.csv",rf;append=true)


p = rf %>%
  # Compute the proportions:
group_by(year) %>%
mutate(freq = n / sum(n)) %>%
ungroup() %>%

# Plot
ggplot( aes(x=year, y=freq, fill=name, color=name, text=name)) +
  geom_area(  ) +
  scale_fill_viridis(discrete = TRUE) +
  scale_color_viridis(discrete = TRUE) +
  theme(legend.position="none") +
  ggtitle("Popularity of American names in the previous 30 years") +
  theme_ipsum() +
  theme(legend.position="none")
ggplotly(p, tooltip="text")


dataset("Results") |>
@vlplot(
    width=400,
    height=100,
    :area,
    transform=[
        {density="x1",bandwidth=0.3,groupby=["Major_Genre"],extent=[0, 10],counts=true,steps=50}
    ],
    x={"value:q", title="IMDB Rating"},
    y= {"density:q",stack=true},
    color={"Major_Genre:n",scale={scheme=:category20}}
)
