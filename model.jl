using JuMP, Gurobi
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

##LAUNCH MODEL
model = Model(Gurobi.Optimizer)

## VARIABLES
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
#@variable(model, 0 <= HydroOutPower[Hours, Region])
#@variable(model, TransBin[Hours,Region, Region], Bin)

## CONSTRAINTS
# PRODUCTION PRO TECHNOLOGY
#@constraint(model, [h in Hours, t in Tech, r in Region], 0 <= EnergyProduction[h,t,r])
#FOLLOWING ONLY FOR NON-HYDRO TECHNOLOGIES
@constraint(model, [h in Hours, t in TechNH, r in Region],
    EnergyProduction[h,t,r]
    <=
    capFactor[h,t,r]*(iniCapT[t,r]
    + AdditionalCapacity[t,r])
)
#@constraint(model, [t in TechNH, r in Region], 0 <= AdditionalCapacity[t,r])
@constraint(model, [t in TechNH, r in Region],
    AdditionalCapacity[t,r]
    <=
    maxCapT[t,r]
)

## MEETING THE DEMAND
@constraint(model, [h in Hours, r in Region],
    sum(EnergyProduction[h,t,r] for t in Tech)
    + sum(Discharge[s,h,r] - Charge[s,h,r] for s in Storage) + sum(Trans[h,r,from] for from in Region)
    - sum(Trans[h,to,r] for to in Region)
    == Demand[h, r]
)


## STORAGE
@constraint(model, [s in Storage, h in Hours[Hours.>1], r in Region], StorageLevel[s,h,r] - StorageLevel[s,h-1,r] == Charge[s,h-1,r] - Discharge[s,h-1,r])
@constraint(model, [s in Storage, h in Hours, r in Region], StorageLevel[s,h,r] <= AdditionalStorage[s,r] + iniCapS[s,r])
#@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Charge[s,h,r])
@constraint(model, [s in Storage, h in Hours, r in Region], Charge[s,h,r] <= chargeMax[s])
#@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Discharge[s,h,r])
@constraint(model, [s in Storage, h in Hours, r in Region], Discharge[s,h,r] <= dischargeMax[s])
@constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])

## TRANS
#@constraint(model, [r in Region, h in Hours], Trans[h,r,r] == 0) #cannot trans ele within
@constraint(model, [r in Region], AdditionalTrans[r,r] == 0) #cannot trans ele within
@constraint(model, [r in Region, rr in Region, h in Hours], Trans[h, r, rr] <= transCap[r, rr] + AdditionalTrans[r, rr])
@constraint(model, [r in Region, rr in Region, h in Hours], transCap[r,rr] + AdditionalTrans[r,rr] <= maxTransCap[r, rr])
#@constraint(model, [r in Region, rr in Region, h in Hours], TransBin[h,rr,r]*Trans[h,rr,r] + 1 >= Trans[h,rr,r])



## RAMPING LIMITATIONS
@constraint(model, [h in Hours[Hours.>1], t in Tech, r in Region],
    EnergyProduction[h,t,r] - EnergyProduction[h-1,t,r]
    >= -rampDownMax[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])
)
@constraint(model, [h in Hours[Hours.>1], t in Tech, r in Region],
    EnergyProduction[h,t,r] - EnergyProduction[h-1,t,r]
    <= rampUpMax[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])
)

## HYDRO

@constraint(model, [h in Hours, r in Region], hydroMinReservoir[r] <= HydroReservoirLevel[h,r])
@constraint(model, [h in Hours, r in Region], hydroMaxReservoir[r] >= HydroReservoirLevel[h,r])
@constraint(model, [h in Hours[Hours.<LEN], r in Region], HydroReservoirLevel[h+1,r] == HydroReservoirLevel[h,r] + hydroInflow[h,r] - HydroOutflow[h,r])
@constraint(model, [h in Hours, r in Region], HydroOutBypass[h,r] + EnergyProduction[h,8,r] == HydroOutflow[h,r])
@constraint(model, [h in Hours, r in Region], HydroOutflow[h,r] >= hydroMinEnvFlow[r])
@constraint(model, [h in Hours, r in Region], EnergyProduction[h,8,r] <= hydroReservoirCapacity[r] + AdditionalCapacity[8,r])
#@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] == EnergyProduction[h,7,r])
@constraint(model, [r in Region], AdditionalCapacity[8,r] <= hydroMaxOverall[r])

## EXPRESSIONS

useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t,r]*(1/eff[t])
    + fixedCostT[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])*(1/eff[t]) for t in TechNH, h in Hours, r in Region)
)
einvC = @expression(model, sum(AdditionalCapacity[t,r]*invCostT[t]*(1/expLifeTimeT[t]) for t in Tech, r in Region))
sinvC = @expression(model, sum(AdditionalStorage[s,r]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage, r in Region))
taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX[r]*(1/1000)*(proEmisFactor[t-1])*(1/eff[t]) for t in CarbonTech, h in Hours, r in Region))
rampExp = @expression(model, sum(((EnergyProduction[h,1,r] - EnergyProduction[h-1,1,r])^2)*1000 for h in Hours[Hours.>1], r in Region)) #for nuclear only
transInv = @expression(model, sum(AdditionalTrans[r, rr]*transInvCost*transLen[r,rr] for r in Region, rr in Region))
transCost = @expression(model, sum(transCost*Trans[h,r,rr] for h in Hours, r in Region, rr in Region))


## OBJECTIVE
@objective(model, Min , useC + einvC + sinvC + taxC + rampExp + transInv + transCost)



##OPTIMIZE
optimized = optimize!(model)
termination_status(model)
