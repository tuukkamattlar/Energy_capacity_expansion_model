using Plots

#APPLY CARBON TAX and LENGTH
TAX_initial = [62, 2, 112, 0, 15, 0.07]
TAX_initial = [50, 50, 50, 50, 50, 50].*2
TAX = TAX_initial
LEN = 4000

include("model.jl")








include("bringData.jl")


## GATHER THE RESULTS


#VISUALISATION PART
##

#GENERIC PLOTS FOR SOME REGIONS
plot(AllResults[:,:,1,1], title="Finland", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Hydro" "Storage" "Trans"])
plot(AllResults[:,:,2,1], title="Estonia", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Hydro" "Storage" "Trans"])
plot(AllResults[:,:,3,1], title="Sweden", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Hydro" "Storage" "Trans"])
plot(AllResults[:,:,4,1], title="Germany", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Hydro" "Storage" "Trans"])
plot(AllResults[:,:,5,1], title="Spain", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Hydro" "Storage" "Trans"])
plot(AllResults[:,:,6,1], title="Poland", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Hydro" "Storage" "Trans"])


plot(AllResults[1, :, 1, 2], title="Additional in FI")
plot(AllResults[1, :, 2, 2], title="Additional in EE")
plot(AllResults[1, :, 3, 2], title="Additional in SE")
plot(AllResults[1, :, 4, 2], title="Additional in DE")
plot(AllResults[1, :, 5, 2], title="Additional in ES")
plot(AllResults[1, :, 5, 2], title="Additional in PL")
plot(AllResults[:, 1, 1, 3], fill= true, title="storage")
plot(AllResults[:, 1, 1, 5], title="charge")
plot(AllResults[:, 1, 1, 6], title="discarge")

plot(TransResults[:,1,2,1])
plot(TransResults[:, 5,1,2] )
#TransExpRestults[r,rr]

## GATHERING DATA IN NEW FORMAT
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

## LOOP FOR DETERMINING RENEWABLES SHARE IN COMPARISON TO TAX LEVEL
L = 20
LEN = 200
TAX_loop =  [62, 2, 112, 0, 15, 0.07]
result = Matrix{Float64}(undef, L, 15)
RENW = Matrix{Float64}(undef, length(Hours), 3)
#opti = Matrix{undef}(undef, L)
#k = collect(1::L)
for i in 1:L
    TAX = [1, 1, 1, 1, 1, 1]*7*i
    i
    taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX[r]*(1/1000)*(proEmisFactor[t-1])*(1/eff[t]) for t in CarbonTech, h in Hours, r in Region))
    @objective(model, Min , useC + einvC + sinvC + taxC + rampExp + transInv + transCost)
    optimized = optimize!(model)
    result[i,1] = objective_value(model)
    #result[i,4] = optimized
    for h in Hours
        RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region))
        RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
        RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
    end
    result[i,2] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
    result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,3] for h in Hours )
end
plot(result[:,1])
plot(result[:,3])
plot(RENW[:,2])
plot(RENW[:,1])


## end
## end
## end
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
