using JuMP # used for mathematical programming
using Plots
using Gurobi
using DataFrames
using VegaLite
using VegaDatasets
using CSV

#NOTE: Technologies used
# 1 nuclear
# 2 coal slow
# 3 coal fast
# 4 gas
# 5 wind
# 6 solar
# 7 water


#GENERATE AND IMPORT DATA
include("values.jl")

#APPLY CARBON TAX
TAX = 1000

#LAUNCH MODEL
model = Model(Gurobi.Optimizer)

#VARIABLES
@variable(model, 0 <= Charge[Storage, Hours])
@variable(model, 0 <= Discharge[Storage, Hours])
@variable(model, 0 <= StorageLevel[Storage, Hours])
@variable(model, 0 <= AdditionalStorage[Storage])
#@variable(model, 0 <= SatisfiedDemand[Hours])
@variable(model, 0 <= EnergyProduction[Hours, Tech])
@variable(model, 0 <= AdditionalCapacity[Tech])


#CONSTRAINTS
# PRODUCTION PRO TECHNOLOGY
@constraint(model, [h in Hours, t in Tech], 0 <= EnergyProduction[h,t])
@constraint(model, [h in Hours, t in Tech], EnergyProduction[h,t]
    <= capFactor[h,t]*(iniCapT[t] + AdditionalCapacity[t])
)
@constraint(model, [t in Tech], 0 <= AdditionalCapacity[t])
@constraint(model, [t in Tech], AdditionalCapacity[t] + iniCapT[t] <= maxCapT[t])

# STORAGE
@constraint(model, [s in Storage, h in Hours], 0 <= StorageLevel[s,h])
@constraint(model, [s in Storage, h in Hours], StorageLevel[s,h] <= maxCapS[s])
@constraint(model, [s in Storage, h in Hours], 0 <= Charge[s,h])
@constraint(model, [s in Storage, h in Hours], Charge[s,h] <= chargeMax[s])
@constraint(model, [s in Storage, h in Hours], 0 <= Discharge[s,h])
@constraint(model, [s in Storage, h in Hours], Discharge[s,h] <= dischargeMax[s])

# MEETING THE DEMAND
@constraint(model, [h in Hours],
    sum(EnergyProduction[h,t] for t in Tech)
    + sum(Discharge[s,h] - Charge[s,h] for s in Storage)
    == Demand[h]
)

# RAMPING LIMITATIONS
@constraint(model, [h in Hours[Hours.>1], t in Tech],
    EnergyProduction[h,t] - EnergyProduction[h-1,t]
    >= -rampDownMax[t]*(iniCapT[t] + AdditionalCapacity[t])
)
@constraint(model, [h in Hours[Hours.>1], t in Tech],
    EnergyProduction[h,t] - EnergyProduction[h-1,t]
    <= rampUpMax[t]*(iniCapT[t] + AdditionalCapacity[t])
)


#EXPRESSIONS

useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t]
    + fixedCostT[t]*(iniCapT[t] + AdditionalCapacity[t]) for t in Tech, h in Hours)
)
einvC = @expression(model, sum(AdditionalCapacity[t]*invCostT[t]*(1/expLifeTimeT[t]) for t in Tech))
sinvC = @expression(model, sum(AdditionalStorage[s]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage))
taxC = @expression(model, sum(EnergyProduction[h,t]*TAX*(1/proEmisFactor[t-1]) for t in CarbonTech, h in Hours))
rampExp = @expression(model, sum(((EnergyProduction[h,1] - EnergyProduction[h-1,1])^2)*1000 for h in Hours[Hours.>1]))


#OBJECTIVE
@objective(model, Min , useC + einvC + sinvC + taxC + rampExp)



#OPTIMIZE
optimized = optimize!(model)
termination_status(model)



#RESULTS

Results = Matrix{Float64}(undef, length(Hours), 15)
for h in Hours
    Results[h, 1] = value(EnergyProduction[h,1])
    Results[h, 2] = value(EnergyProduction[h,2])
    Results[h, 3] = value(EnergyProduction[h,3])
    Results[h, 4] = value(EnergyProduction[h,4])
    Results[h, 5] = value(EnergyProduction[h,5])
    Results[h, 6] = value(EnergyProduction[h,6])
    Results[h, 7] = value(EnergyProduction[h,7])
    #Results[h, 8] = value(EnergyProduction[h,8])
    Results[h, 9] = value(Charge[1, h])
    Results[h, 10] = value(Charge[2, h])
    Results[h, 11] = value(Charge[3, h])
    Results[h, 12] = sum(Results[h, i] for i in 1:8)
    Results[h, 13] = sum(Results[h, i] for i in 9:11)
    #Results[h, 9] = Results[h,8]-Demand[h]
end

plot(Results[:,1:7], label = ["Nuclear" "CHP" "CHP2" "Gas" "Wind" "PV" "Hydro"])

plot(Results[:,13])

pt = Matrix{Float64}(undef, length(Hours), 15)
for h in Hours
    pt[h, 1] = Results[h,1]
    pt[h, 2] = pt[h,1] + Results[h,2]
    pt[h, 3] = pt[h,2] + Results[h,3]
    pt[h, 4] = pt[h,3]+ Results[h,4]
    pt[h, 5] = pt[h,4]+ Results[h,5]
    pt[h, 6] = pt[h,5]+Results[h,6]
    pt[h, 7] = pt[h,6]+Results[h,7]
end
plot(pt[:,1:7], label = ["Nuclear" "CHP" "CHP2" "Gas" "Wind" "PV" "Hydro"])



#SAVE THE OBJECTIVE





#LOOP FOR TESTING
L = 100
result = Matrix{Float64}(undef, L, 15)
RENW = Matrix{Float64}(undef, length(Hours), 2)
for i in 1:L
    TAX = i*50
    taxC = @expression(model, sum(EnergyProduction[h,t]*TAX*(1/proEmisFactor[t-1]) for t in CarbonTech, h in Hours))
    @objective(model, Min , useC + einvC + sinvC + taxC + rampExp)
    optimized = optimize!(model)
    result[i,1] = objective_value(model)
    for h in Hours
        RENW[h,1] = value(EnergyProduction[h,5]) + value(EnergyProduction[h,6]) + value(EnergyProduction[h,7])
        RENW[h,2] = value(EnergyProduction[h,2]) + value(EnergyProduction[h,3])+value(EnergyProduction[h,4])
    end
    result[i,2] = sum(RENW[h,1] for h in Hours)/sum(RENW[h,2]+RENW[h,1] for h in Hours )
end

plot(result[:,1])
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
