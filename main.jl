using JuMP, Plots, Gurobi, CSV
#using DataFrames
#using VegaLite
#using VegaDatasets

#NOTE: Technologies used
# 1 nuclear
# 2 coal slow
# 3 coal fast
# 4 gas
# 5 wind
# 6 solar
# 7 water

#IMPORT DATA
include("values.jl")

#APPLY CARBON TAX
TAX = 25

#LAUNCH MODEL
model = Model(Gurobi.Optimizer)

#VARIABLES
@variable(model, 0 <= Charge[Storage, Hours, Region])
@variable(model, 0 <= Discharge[Storage, Hours, Region])
@variable(model, 0 <= StorageLevel[Storage, Hours, Region])
@variable(model, 0 <= AdditionalStorage[Storage, Region])
@variable(model, 0 <= EnergyProduction[Hours, Tech, Region])
@variable(model, 0 <= AdditionalCapacity[Tech, Region])
@variable(model, 0 <= Trans[Hours, Region, Region])
@variable(model, 0 <= AdditionalTrans[Region, Region])
@variable(model, 0 <= HydroReservoirLevel[Hours, Region])
@variable(model, 0 <= HydroOutflow[Hours, Region])
@variable(model, 0 <= HydroOutBypass[Hours, Region])
@variable(model, 0 <= HydroOutPower[Hours, Region])
@variable(model, TransBin[Hours,Region, Region], Bin)

#CONSTRAINTS
# PRODUCTION PRO TECHNOLOGY
@constraint(model, [h in Hours, t in Tech, r in Region], 0 <= EnergyProduction[h,t,r])

#FOLLOWING ONLY FOR NON-HYDRO TECHNOLOGIES
@constraint(model, [h in Hours, t in TechNH, r in Region],
    EnergyProduction[h,t,r]
    <=
    capFactor[h,t,r]*(iniCapT[t,r]
    + AdditionalCapacity[t,r])
)
#@constraint(model, [t in Tech, r in Region], 0 <= AdditionalCapacity[t,r])
@constraint(model, [t in TechNH, r in Region],
    AdditionalCapacity[t,r]
    + iniCapT[t,r]
    <=
    maxCapT[t,r]
)

# STORAGE
@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= StorageLevel[s,h,r])
@constraint(model, [s in Storage, h in Hours, r in Region], StorageLevel[s,h,r] <= maxCapS[s,r])
@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Charge[s,h,r])
@constraint(model, [s in Storage, h in Hours, r in Region], Charge[s,h,r] <= chargeMax[s])
@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Discharge[s,h,r])
@constraint(model, [s in Storage, h in Hours, r in Region], Discharge[s,h,r] <= dischargeMax[s])
@constraint(model, [r in Region, h in Hours], Trans[h,r,r] == 0) #cannot trans ele within
@constraint(model, [r in Region], AdditionalTrans[r,r] == 0) #cannot trans ele within
@constraint(model, [r in Region, rr in Region, h in Hours], Trans[h, r, rr] <= transCap[r, rr] + AdditionalTrans[r, rr])
@constraint(model, [r in Region, rr in Region, h in Hours], transCap[r,rr] + AdditionalTrans[r,rr] <= maxTransCap[r, rr])
#@constraint(model, [r in Region, rr in Region, h in Hours], TransBin[h,rr,r]*Trans[h,rr,r] + TransBin[h,r,rr]*Trans[h,r,rr] <= Trans[h,r,rr] + Trans[h,rr,r] -1   )


# MEETING THE DEMAND
@constraint(model, [h in Hours, r in Region],
    sum(EnergyProduction[h,t,r] for t in Tech)
    + sum(Discharge[s,h,r] - Charge[s,h,r] for s in Storage) + sum(Trans[h,r,from] for from in Region)
    - sum(Trans[h,to,r] for to in Region)
    == Demand[h, r]
)

# RAMPING LIMITATIONS
@constraint(model, [h in Hours[Hours.>1], t in Tech, r in Region],
    EnergyProduction[h,t,r] - EnergyProduction[h-1,t,r]
    >= -rampDownMax[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])
)
@constraint(model, [h in Hours[Hours.>1], t in Tech, r in Region],
    EnergyProduction[h,t,r] - EnergyProduction[h-1,t,r]
    <= rampUpMax[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])
)

#HYDRO
@constraint(model, [h in Hours, r in Region], hydroMinReservoir[r] <= HydroReservoirLevel[h,r])
@constraint(model, [h in Hours, r in Region], hydroMaxReservoir[r] >= HydroReservoirLevel[h,r])
@constraint(model, [h in Hours[Hours.>(LEN-1)], r in Region], HydroReservoirLevel[h+1,r] == HydroReservoirLevel[h,r] + hydroInflow[h,r] - HydroOutflow[h,r])
@constraint(model, [h in Hours, r in Region], HydroOutBypass[h,r] + HydroOutPower[h,r] == HydroOutflow[h,r])
@constraint(model, [h in Hours, r in Region], HydroOutflow[h,r] >= hydroMinEnvFlow[r])
@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] <= hydroReservoirCapacity[r] + AdditionalCapacity[7,r])
@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] == EnergyProduction[h,7,r])
@constraint(model, [r in Region], hydroReservoirCapacity[r] + AdditionalCapacity[7,r] <= hydroMaxOverall[r])

#EXPRESSIONS

useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t,r]/eff[t]
    + fixedCostT[t]*(iniCapT[t,r] + AdditionalCapacity[t,r]) for t in TechNH, h in Hours, r in Region)
)
einvC = @expression(model, sum(AdditionalCapacity[t,r]*invCostT[t]*(1/expLifeTimeT[t]) for t in TechNH, r in Region))
sinvC = @expression(model, sum(AdditionalStorage[s,r]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage, r in Region))
taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX*(1/proEmisFactor[t-1])/eff[t] for t in CarbonTech, h in Hours, r in Region))
rampExp = @expression(model, sum(((EnergyProduction[h,1,r] - EnergyProduction[h-1,1,r])^2)*1000 for h in Hours[Hours.>1], r in Region))
transInv = @expression(model, sum(AdditionalTrans[r, rr]*transInvCost*transLen[r,rr] for r in Region, rr in Region))
transCost = @expression(model, sum(transCost*(Trans[h,r,rr]) for h in Hours, r in Region, rr in Region))
hydroinvC = @expression(model, sum(AdditionalCapacity[7,r]*invCostT[7]*(1/(expLifeTimeT[7])) for r in Region))

#OBJECTIVE
@objective(model, Min , useC + einvC + sinvC + taxC + rampExp + transInv + transCost + hydroinvC)



#OPTIMIZE
optimized = optimize!(model)
termination_status(model)



#RESULTS

Results = Matrix{Float64}(undef, length(Hours), 15)
NodesResults = zeros(length(Hours), length(Region), length(Region))
for h in Hours
    Results[h, 1] = value(EnergyProduction[h,1,1])
    Results[h, 2] = value(EnergyProduction[h,2,1])
    Results[h, 3] = value(EnergyProduction[h,3,1])
    Results[h, 4] = value(EnergyProduction[h,4,1])
    Results[h, 5] = value(EnergyProduction[h,5,1])
    Results[h, 6] = value(EnergyProduction[h,6,1])
    Results[h, 7] = value(EnergyProduction[h,7,1])
    #Results[h, 8] = value(EnergyProduction[h,8])
    Results[h, 9] = value(Charge[1, h,1])
    Results[h, 10] = value(Charge[2, h,1])
    Results[h, 11] = value(Charge[3, h,1])
    Results[h, 12] = sum(Results[h, i] for i in 1:8)
    Results[h, 13] = sum(Results[h, i] for i in 9:11)
    #Results[h, 9] = Results[h,8]-Demand[h]
end

for h in Hours
    for r in Region
        for rr in Region
            NodesResults[h,r,rr] = value.(Trans[h, r, rr])
        end
    end
end

plot(Results[:,1:7], label = ["Nuclear" "CHP" "CHP2" "Gas" "Wind" "PV" "Hydro"])


plot(Results[:,7],fill = (0, 1), palette=cgrad([:red, :green, :yellow, :blue]))


plot(Results[:,13])

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


#SAVE THE OBJECTIVE





#LOOP FOR TESTING
L = 100
result = Matrix{Float64}(undef, L, 15)
RENW = Matrix{Float64}(undef, length(Hours), 2)
#k = collect(1::L)
for i in 1:L
    TAX = i*2
    taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX*(1/proEmisFactor[t-1]) for t in CarbonTech, h in Hours, r in Region))
    @objective(model, Min , useC + einvC + sinvC + taxC + rampExp + transInv + transCost)
    optimized = optimize!(model)
    result[i,1] = objective_value(model)
    for h in Hours
        RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region))
        RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
    end
    result[i,2] = sum(RENW[h,1] for h in Hours)/sum(RENW[h,2]+RENW[h,1] for h in Hours )
end

plot(result[:,2])























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
