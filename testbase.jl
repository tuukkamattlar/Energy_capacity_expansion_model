using Plots
using JuMP, Gurobi, CSV


function setTaxLevels(taxValues, L, LEN)

    Tech            = collect(1:8)
    CarbonTech      = collect(2:4)
    RenewableTech   = collect(5:7)
    TechNR          = collect(1:7)
    TechNRR          = collect(1:6)
    Hours           = collect(1:LEN)
    Storage         = collect(1:1)
    Region          = collect(1:6)



    ################################################################################
    # IMPORT DATA

    d_demand       = CSV.read("data/DemandData.csv")
    d_available    = CSV.read("data/AvailabilityData.csv")
    d_capacity     = CSV.read("data/CapacityData.csv")
    d_trans        = CSV.read("data/TransData.csv")
    d_ror          = CSV.read("data/RORdata.csv")
    d_res          = CSV.read("data/RESdata.csv")

    ################################################################################
    # PARAMETERS

    #TECH
    iniCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    maxCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    capFactor           = zeros(length(Hours), length(TechNR), length(Region))
    #capFactor = Matrix{Float64}(undef, length(Hours), length(Tech), length(Region))
    rampUpMax           = Array{Float64}(undef, length(Tech))
    rampDownMax         = Array{Float64}(undef, length(Tech))
    variableCostT       = Array{Float64}(undef, length(Tech))
    fixedCostT          = Array{Float64}(undef, length(Tech))
    invCostT            = Array{Float64}(undef, length(Tech))
    expLifeTimeT        = Array{Float64}(undef, length(Tech))
    eff                 = Array{Float64}(undef, length(Tech))
    hydroMinReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroMaxReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroReservoirCapacity = Array{Float64}(undef, length(Region)) #OK
    hydroInflow         = Matrix{Float64}(undef, length(Hours), length(Region)) #OK
    hydroMinEnvFlow     = Array{Float64}(undef, length(Region)) #OK
    hydroMaxOverall     = Array{Float64}(undef, length(Region)) #OK

    #for t in Tech
    #    iniCapT[t] = 400
    #    maxCapT[t] = 600
    #    rampUpMax[t] = 0.05
    #    rampDownMax[t] = 20
    #    variableCostT[t] = 400
    #    fixedCostT[t] = 200
    #    invCostT[t] = 10000
    #    expLifeTimeT[t] = 50
    #end
    #http://smartenergytransition.fi/en/
    #finnish-energy-system-can-be-made-100-fossil-fuel-free/

    # CAPACITY

    for t in TechNR
        k = t+1
        for r in Region
            iniCapT[t,r] = d_capacity[r, k]
            maxCapT[t,r] = d_capacity[r, k+15]
        end
    end



    # CAPACITY HYDRO

    for r in Region
        hydroMinReservoir[r]        = d_capacity[r, 11]
        hydroMaxReservoir[r]        = d_capacity[r, 12]
        hydroReservoirCapacity[r]   = d_capacity[r, 13]
        hydroMinEnvFlow[r]          = d_capacity[r, 14]
        hydroMaxOverall[r]          = d_capacity[r, 25]
        hydroInflow[1,r]            = 1000*d_res[1, r]
        for h in Hours[Hours.>1]
            hydroInflow[h,r]        = 1000*d_res[cld(h,24), r]/24
        end
    end

    #GENERAL

    # 1 nuclear
    rampUpMax[1]        = 0.01 #not known
    rampDownMax[1]      = 0.01 #not known
    variableCostT[1]    = 10
    fixedCostT[1]       = 130000 #pro kwh and year
    invCostT[1]         = 5000000
    expLifeTimeT[1]     = 60
    eff[1]              = 0.4

    # 2 coal
    rampUpMax[2]        = 0.1 #not known
    rampDownMax[2]      = 0.6 #not known
    variableCostT[2]    = 11
    fixedCostT[2]       = 100000 #pro kwh and year
    invCostT[2]         = 1600000
    expLifeTimeT[2]     = 40 #not known
    eff[2]              = 0.45

    # 3 biomass and waste etc
    rampUpMax[3]        = 0.1
    rampDownMax[3]      = 0.1
    variableCostT[3]    = 50
    fixedCostT[3]       = 100000 #pro kwh and year
    invCostT[3]         = 3700000
    expLifeTimeT[3]     = 25
    eff[3]              = 0.25

    # 4 (bio)gas
    rampUpMax[4]        = 0.5 #https://www.wartsila.com/energy/learn-more/technical-comparisons/combustion-engine-vs-gas-turbine-ramp-rate
    rampDownMax[4]      = 0.5 #not known
    variableCostT[4]    = 85
    fixedCostT[4]       = 20000 #pro kwh and year
    invCostT[4]         = 700000
    expLifeTimeT[4]     = 30
    eff[4]              = 0.6

    # 5 wind
    rampUpMax[5]        = 1
    rampDownMax[5]      = 1
    variableCostT[5]    = 0
    fixedCostT[5]       = 40000 #pro kwh and year
    invCostT[5]         = 1090000
    expLifeTimeT[5]     = 25
    eff[5]              = 1

    # 6 solar
    rampUpMax[6]        = 1
    rampDownMax[6]      = 1
    variableCostT[6]    = 0
    fixedCostT[6]       = 30000 #pro kwh and year
    invCostT[6]         = 690000
    expLifeTimeT[6]     = 30
    eff[6]              = 1

    # 7 HydroROR
    rampUpMax[7]        = 1 #not known
    rampDownMax[7]      = 1 #not known
    variableCostT[7]    = 0
    fixedCostT[7]       = 70000 #pro kwh and year
    invCostT[7]         = 3450000
    expLifeTimeT[7]     = 80 #not known
    eff[7]              = 1 #not known

    # 8 HydroRes
    rampUpMax[8]        = 0.2 #not known
    rampDownMax[8]      = 0.3 #not known
    variableCostT[8]    = 110
    fixedCostT[8]       = 20000 #pro kwh and year
    invCostT[8]         = 1300000
    expLifeTimeT[8]     = 40 #not known
    eff[8]              = 1 #not known


    #Capacity factors for generation
    for h in Hours
        for r in Region #TODO
            capFactor[h, 1, r] = 1
            capFactor[h, 2, r] = 1
            capFactor[h, 3, r] = 1
            capFactor[h, 4, r] = 1
            capFactor[h, 5, r] = d_available[h, r*4]
            capFactor[h, 6, r] = d_available[h, r*4-2]
            capFactor[h, 7, r] = 1000*d_ror[cld(h,24), r]/24
        end
    end

    #OTHER
    proEmisFactor =  Array{Float64}(undef, length(CarbonTech))
    proEmisFactor[1] = 0.2*1000 #coal kgC02/kWh -> MWh same as MW
    proEmisFactor[2] = 0.5*1000 #biomass/waste
    proEmisFactor[3] = 0.4*1000 #biogas


    #STORAGE
    chargeMax       = Array{Float64}(undef, length(Storage))
    dischargeMax    = Array{Float64}(undef, length(Storage))
    iniCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    maxCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    invCostS        = Array{Float64}(undef, length(Storage))
    expLifeTimeS    = Array{Float64}(undef, length(Storage))

    for s in Storage
        for r in Region #TODO
            iniCapS[s,r] = d_capacity[r, 10]
            maxCapS[s,r] = d_capacity[r, 10+15]
        end
        #general
        chargeMax[s] = 500
        dischargeMax[s] = 800
        invCostS[s]     = 240000 #ok
        expLifeTimeS[s] = 10 #ok
    end

    batteryEff = 0.9;

    # DEMAND
    Demand = Matrix{Float64}(undef, length(Hours), length(Region))

    for h in Hours
        for r in Region
            Demand[h, r] = d_demand[h, 4*r]
        end
    end

    transCap = Matrix{Float64}(undef, length(Region), length(Region))
    maxTransCap = Matrix{Float64}(undef, length(Region), length(Region))
    transLen = Matrix{Float64}(undef, length(Region), length(Region))
    for r in Region
        for rr in Region
                transCap[r, rr]     = d_trans[r,rr + 1]
                maxTransCap[r,rr]   = d_trans[r,rr + 8]
                transLen[r, rr]     = d_trans[r,rr + 15]
        end
    end


    transInvCost = 460 #ok
    transCost    = 0.0001
    transEff    = 0.95






    #TAX_initial = [62, 2, 112, 1, 15, 0.07]
    TAX = taxValues
    result = Matrix{Float64}(undef, L, 20)
    RENW = Matrix{Float64}(undef, length(Hours), 3)
    result_additional_storage = zeros(L, length(Storage), length(Region))
    result_charges = zeros(L,length(Storage),length(Hours),length(Region),3)
    result_additional_capacity = zeros(L,length(Tech),length(Region))
    result_AdditionalTrans = zeros(L,length(Region),length(Region))
    result_hydros = zeros(L,length(Hours),length(Region),3)
    result_trans = zeros(L,length(Hours),length(Region),length(Region))
    result_energyProduction = zeros(L, length(Hours),length(Tech),length(Region))



    for i in 1:L
        taxLevel = i*6
        TAX = taxValues.*taxLevel
        ##LAUNCH MODEL
        model = Model(Gurobi.Optimizer)
        #set_optimizer_attributes(model, "Presolve" => 15000, "Heuristics" => 0.01)

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
        @constraint(model, [h in Hours, t in TechNRR, r in Region],
            EnergyProduction[h,t,r]
            <=
            capFactor[h,t,r]*(iniCapT[t,r]
            + AdditionalCapacity[t,r])
        )


        #@constraint(model, [t in TechNH, r in Region], 0 <= AdditionalCapacity[t,r])
        @constraint(model, [t in TechNR, r in Region],
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
        @constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])
        @constraint(model, [s in Storage, h in Hours[Hours.>1], r in Region], StorageLevel[s,h,r] - StorageLevel[s,h-1,r] == Charge[s,h-1,r] - Discharge[s,h-1,r]*batteryEff)
        @constraint(model, [s in Storage, h in Hours, r in Region], StorageLevel[s,h,r] <= AdditionalStorage[s,r] + iniCapS[s,r])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Charge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Charge[s,h,r] <= chargeMax[s])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Discharge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Discharge[s,h,r] <= dischargeMax[s])#@constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])

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

        ## HYDRO RES

        @constraint(model, [h in Hours[Hours.>24], r in Region], hydroMinReservoir[r] <= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours, r in Region], hydroMaxReservoir[r] >= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours[Hours.<LEN], r in Region], HydroReservoirLevel[h+1,r] == HydroReservoirLevel[h,r] + hydroInflow[h,r] - HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutBypass[h,r] + EnergyProduction[h,8,r] == HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutflow[h,r] >= hydroMinEnvFlow[r])
        @constraint(model, [h in Hours, r in Region], EnergyProduction[h,8,r] <= hydroReservoirCapacity[r] + AdditionalCapacity[8,r])
        #@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] == EnergyProduction[h,7,r])
        @constraint(model, [r in Region], AdditionalCapacity[8,r] <= hydroMaxOverall[r])

        ## HYDRO ROR

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            capFactor[h,7,r]
        )

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            iniCapT[7,r]
        )

        ## EXPRESSIONS

        useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t,r]*(1/eff[t])
            + fixedCostT[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])*(1/eff[t]) for t in TechNR, h in Hours, r in Region)
        )
        einvC = @expression(model, sum(AdditionalCapacity[t,r]*invCostT[t]*(1/expLifeTimeT[t]) for t in Tech, r in Region))
        sinvC = @expression(model, sum(AdditionalStorage[s,r]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage, r in Region))
        taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX[r]*(1/1000)*(proEmisFactor[t-1])*(1/eff[t]) for t in CarbonTech, h in Hours, r in Region))
        #rampExp = @expression(model, sum(((EnergyProduction[h,1,r] - EnergyProduction[h-1,1,r])^2)*10 for h in Hours[Hours.>1], r in Region)) #for nuclear only
        transInv = @expression(model, sum(AdditionalTrans[r, rr]*transInvCost*transLen[r,rr] for r in Region, rr in Region))
        transCostF = @expression(model, sum(transCost*Trans[h,r,rr] for h in Hours, r in Region, rr in Region))


        ## OBJECTIVE
        @objective(model, Min , (useC + einvC + sinvC + taxC + transInv + transCostF)*0.0000001)



        ##OPTIMIZE
        timeOf = @elapsed optimize!(model)
        print(i)
        result[i,1] = timeOf
        result[i,2] = objective_value(model)

        for r in Region
            for s in Storage
                result_additional_storage[i,s,r] = value.(AdditionalStorage[s, r])
                for h in Hours
                    result_charges[i,s,h,r,1] = value.(Charge[s, h, r])
                    result_charges[i,s,h,r,2] = value.(Discharge[s, h, r])
                    result_charges[i,s,h,r,3] = value.(StorageLevel[s, h, r])
                end
            end
            for t in Tech
                result_additional_capacity[i,t,r] = value.(AdditionalCapacity[t, r])
            end
            for rr in Region
                result_AdditionalTrans[i,r,rr] = value.(AdditionalTrans[r, rr])
            end
            for h in Hours
                result_hydros[i,h,r,1] = value.(HydroReservoirLevel[h, r])
                result_hydros[i,h,r,2] = value.(HydroOutflow[h, r])
                result_hydros[i,h,r,3] = value.(HydroOutBypass[h, r])

                for rr in Region
                    result_trans[i,h,r,rr] = value.(Trans[h, r, rr])
                end

                for t in Tech
                    result_energyProduction[i,h,t,r] = value.(EnergyProduction[h, t, r])
                end
            end
        end

        for h in Hours
            RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region)) + value.(sum(EnergyProduction[h,8,r] for r in Region))
            RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
            RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
        end
        result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
        result[i,4] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,3] for h in Hours )
        result[i,5] = taxLevel

    end
    return [result, RENW,result_additional_storage, result_charges, result_additional_capacity,result_AdditionalTrans,result_hydros,result_trans,result_energyProduction]
end








LEN = 8755
INVESTIGATION = 30
include("values.jl")
TAX = [62, 2, 112, 1, 15, 0.07]
TAX = [1, 1, 1, 1, 1, 1]

#allocaterFREE_MLUTIPLY_8000_100 = setTaxLevels(TAX, INVESTIGATION, LEN)

#MAIN RUNNER BELOW
allocaterUNI_MLUTIPLY_8755_30 = setTaxLevels(TAX, INVESTIGATION, LEN)

plot( allocaterFREE_MLUTIPLY_8000_100[1][:,1], layout=4)
summer = sum(allocaterUNI_MLUTIPLY_8755_30[9][:,h,8,1] for h in Hours)
plot(summer)
plot( allocaterFREE_MLUTIPLY_8000_100[9][:,1,1,1])


## total costs
total_costs_uni_multi = allocaterUNI_MLUTIPLY_8755_30[1][:,2]
tax_level_uni_multi = allocaterUNI_MLUTIPLY_8755_30[1][:,5]
plot(tax_level_uni_multi, total_costs_uni_multi.*10000000, title="Total costs of uniform tax", ylabel="Total costs (€)", xlabel="Tax level (€)", label="")


## res SHARE

total_costs_uni_multi = zeros(30, 10)

for i in 1:30
    for t in Tech
        total_costs_uni_multi[i, t] = sum(allocaterUNI_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
    end
end

res_uni_multi = zeros(30)
for i in 1:30
    res_uni_multi[i] = sum(total_costs_uni_multi[i,t] for t in 5:8)/(sum(total_costs_uni_multi[i,t] for t in 2:8))
end

plot(tax_level_uni_multi, res_uni_multi, title="RES share excluding nuclear of uniform tax", ylabel="Total costs (€)", xlabel="Tax level (€)", label="")

plot(sum(allocaterUNI_MLUTIPLY_8755_30[5][:,t,3] for t in Tech))

plot(tax_level_uni_multi, total_costs_uni_multi[:, 8], title="Total costs of uniform tax", ylabel="Total costs (€)", xlabel="Tax level (€)", label="")
#Technologies used
# 1 nuclear
# 2 coal
# 3 biomass and waste
# 4 (bio)gas
# 5 wind
# 6 solar
# 7 Direct hydro
# 8 Storal hydro



































################################################################################
function setTaxLevelsOWN(taxValues, L, LEN)

    Tech            = collect(1:8)
    CarbonTech      = collect(2:4)
    RenewableTech   = collect(5:7)
    TechNR          = collect(1:7)
    TechNRR          = collect(1:6)
    Hours           = collect(1:LEN)
    Storage         = collect(1:1)
    Region          = collect(1:6)



    ################################################################################
    # IMPORT DATA

    d_demand       = CSV.read("data/DemandData.csv")
    d_available    = CSV.read("data/AvailabilityData.csv")
    d_capacity     = CSV.read("data/CapacityData.csv")
    d_trans        = CSV.read("data/TransData.csv")
    d_ror          = CSV.read("data/RORdata.csv")
    d_res          = CSV.read("data/RESdata.csv")

    ################################################################################
    # PARAMETERS

    #TECH
    iniCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    maxCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    capFactor           = zeros(length(Hours), length(TechNR), length(Region))
    #capFactor = Matrix{Float64}(undef, length(Hours), length(Tech), length(Region))
    rampUpMax           = Array{Float64}(undef, length(Tech))
    rampDownMax         = Array{Float64}(undef, length(Tech))
    variableCostT       = Array{Float64}(undef, length(Tech))
    fixedCostT          = Array{Float64}(undef, length(Tech))
    invCostT            = Array{Float64}(undef, length(Tech))
    expLifeTimeT        = Array{Float64}(undef, length(Tech))
    eff                 = Array{Float64}(undef, length(Tech))
    hydroMinReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroMaxReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroReservoirCapacity = Array{Float64}(undef, length(Region)) #OK
    hydroInflow         = Matrix{Float64}(undef, length(Hours), length(Region)) #OK
    hydroMinEnvFlow     = Array{Float64}(undef, length(Region)) #OK
    hydroMaxOverall     = Array{Float64}(undef, length(Region)) #OK

    #for t in Tech
    #    iniCapT[t] = 400
    #    maxCapT[t] = 600
    #    rampUpMax[t] = 0.05
    #    rampDownMax[t] = 20
    #    variableCostT[t] = 400
    #    fixedCostT[t] = 200
    #    invCostT[t] = 10000
    #    expLifeTimeT[t] = 50
    #end
    #http://smartenergytransition.fi/en/
    #finnish-energy-system-can-be-made-100-fossil-fuel-free/

    # CAPACITY

    for t in TechNR
        k = t+1
        for r in Region
            iniCapT[t,r] = d_capacity[r, k]
            maxCapT[t,r] = d_capacity[r, k+15]
        end
    end



    # CAPACITY HYDRO

    for r in Region
        hydroMinReservoir[r]        = d_capacity[r, 11]
        hydroMaxReservoir[r]        = d_capacity[r, 12]
        hydroReservoirCapacity[r]   = d_capacity[r, 13]
        hydroMinEnvFlow[r]          = d_capacity[r, 14]
        hydroMaxOverall[r]          = d_capacity[r, 25]
        hydroInflow[1,r]            = 1000*d_res[1, r]
        for h in Hours[Hours.>1]
            hydroInflow[h,r]        = 1000*d_res[cld(h,24), r]/24
        end
    end

    #GENERAL

    # 1 nuclear
    rampUpMax[1]        = 0.01 #not known
    rampDownMax[1]      = 0.01 #not known
    variableCostT[1]    = 10
    fixedCostT[1]       = 130000 #pro kwh and year
    invCostT[1]         = 5000000
    expLifeTimeT[1]     = 60
    eff[1]              = 0.4

    # 2 coal
    rampUpMax[2]        = 0.1 #not known
    rampDownMax[2]      = 0.6 #not known
    variableCostT[2]    = 11
    fixedCostT[2]       = 100000 #pro kwh and year
    invCostT[2]         = 1600000
    expLifeTimeT[2]     = 40 #not known
    eff[2]              = 0.45

    # 3 biomass and waste etc
    rampUpMax[3]        = 0.1
    rampDownMax[3]      = 0.1
    variableCostT[3]    = 50
    fixedCostT[3]       = 100000 #pro kwh and year
    invCostT[3]         = 3700000
    expLifeTimeT[3]     = 25
    eff[3]              = 0.25

    # 4 (bio)gas
    rampUpMax[4]        = 0.5 #https://www.wartsila.com/energy/learn-more/technical-comparisons/combustion-engine-vs-gas-turbine-ramp-rate
    rampDownMax[4]      = 0.5 #not known
    variableCostT[4]    = 85
    fixedCostT[4]       = 20000 #pro kwh and year
    invCostT[4]         = 700000
    expLifeTimeT[4]     = 30
    eff[4]              = 0.6

    # 5 wind
    rampUpMax[5]        = 1
    rampDownMax[5]      = 1
    variableCostT[5]    = 0
    fixedCostT[5]       = 40000 #pro kwh and year
    invCostT[5]         = 1090000
    expLifeTimeT[5]     = 25
    eff[5]              = 1

    # 6 solar
    rampUpMax[6]        = 1
    rampDownMax[6]      = 1
    variableCostT[6]    = 0
    fixedCostT[6]       = 30000 #pro kwh and year
    invCostT[6]         = 690000
    expLifeTimeT[6]     = 30
    eff[6]              = 1

    # 7 HydroROR
    rampUpMax[7]        = 1 #not known
    rampDownMax[7]      = 1 #not known
    variableCostT[7]    = 0
    fixedCostT[7]       = 70000 #pro kwh and year
    invCostT[7]         = 3450000
    expLifeTimeT[7]     = 80 #not known
    eff[7]              = 1 #not known

    # 8 HydroRes
    rampUpMax[8]        = 0.2 #not known
    rampDownMax[8]      = 0.3 #not known
    variableCostT[8]    = 110
    fixedCostT[8]       = 20000 #pro kwh and year
    invCostT[8]         = 1300000
    expLifeTimeT[8]     = 40 #not known
    eff[8]              = 1 #not known


    #Capacity factors for generation
    for h in Hours
        for r in Region #TODO
            capFactor[h, 1, r] = 1
            capFactor[h, 2, r] = 1
            capFactor[h, 3, r] = 1
            capFactor[h, 4, r] = 1
            capFactor[h, 5, r] = d_available[h, r*4]
            capFactor[h, 6, r] = d_available[h, r*4-2]
            capFactor[h, 7, r] = 1000*d_ror[cld(h,24), r]/24
        end
    end

    #OTHER
    proEmisFactor =  Array{Float64}(undef, length(CarbonTech))
    proEmisFactor[1] = 0.2*1000 #coal kgC02/kWh -> MWh same as MW
    proEmisFactor[2] = 0.5*1000 #biomass/waste
    proEmisFactor[3] = 0.4*1000 #biogas


    #STORAGE
    chargeMax       = Array{Float64}(undef, length(Storage))
    dischargeMax    = Array{Float64}(undef, length(Storage))
    iniCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    maxCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    invCostS        = Array{Float64}(undef, length(Storage))
    expLifeTimeS    = Array{Float64}(undef, length(Storage))

    for s in Storage
        for r in Region #TODO
            iniCapS[s,r] = d_capacity[r, 10]
            maxCapS[s,r] = d_capacity[r, 10+15]
        end
        #general
        chargeMax[s] = 500
        dischargeMax[s] = 800
        invCostS[s]     = 240000 #ok
        expLifeTimeS[s] = 10 #ok
    end

    batteryEff = 0.9;

    # DEMAND
    Demand = Matrix{Float64}(undef, length(Hours), length(Region))

    for h in Hours
        for r in Region
            Demand[h, r] = d_demand[h, 4*r]
        end
    end

    transCap = Matrix{Float64}(undef, length(Region), length(Region))
    maxTransCap = Matrix{Float64}(undef, length(Region), length(Region))
    transLen = Matrix{Float64}(undef, length(Region), length(Region))
    for r in Region
        for rr in Region
                transCap[r, rr]     = d_trans[r,rr + 1]
                maxTransCap[r,rr]   = d_trans[r,rr + 8]
                transLen[r, rr]     = d_trans[r,rr + 15]
        end
    end


    transInvCost = 460 #ok
    transCost    = 0.0001
    transEff    = 0.95






    #TAX_initial = [62, 2, 112, 1, 15, 0.07]
    TAX = taxValues
    result = Matrix{Float64}(undef, L, 20)
    RENW = Matrix{Float64}(undef, length(Hours), 3)
    result_additional_storage = zeros(L, length(Storage), length(Region))
    result_charges = zeros(L,length(Storage),length(Hours),length(Region),3)
    result_additional_capacity = zeros(L,length(Tech),length(Region))
    result_AdditionalTrans = zeros(L,length(Region),length(Region))
    result_hydros = zeros(L,length(Hours),length(Region),3)
    result_trans = zeros(L,length(Hours),length(Region),length(Region))
    result_energyProduction = zeros(L, length(Hours),length(Tech),length(Region))



    for i in 1:L
        taxLevel = i*0.17 - 0.17
        TAX = taxValues.*taxLevel
        ##LAUNCH MODEL
        model = Model(Gurobi.Optimizer)
        #set_optimizer_attributes(model, "Presolve" => 15000, "Heuristics" => 0.01)

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
        @constraint(model, [h in Hours, t in TechNRR, r in Region],
            EnergyProduction[h,t,r]
            <=
            capFactor[h,t,r]*(iniCapT[t,r]
            + AdditionalCapacity[t,r])
        )


        #@constraint(model, [t in TechNH, r in Region], 0 <= AdditionalCapacity[t,r])
        @constraint(model, [t in TechNR, r in Region],
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
        @constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])
        @constraint(model, [s in Storage, h in Hours[Hours.>1], r in Region], StorageLevel[s,h,r] - StorageLevel[s,h-1,r] == Charge[s,h-1,r] - Discharge[s,h-1,r]*batteryEff)
        @constraint(model, [s in Storage, h in Hours, r in Region], StorageLevel[s,h,r] <= AdditionalStorage[s,r] + iniCapS[s,r])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Charge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Charge[s,h,r] <= chargeMax[s])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Discharge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Discharge[s,h,r] <= dischargeMax[s])#@constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])

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

        ## HYDRO RES

        @constraint(model, [h in Hours[Hours.>24], r in Region], hydroMinReservoir[r] <= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours, r in Region], hydroMaxReservoir[r] >= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours[Hours.<LEN], r in Region], HydroReservoirLevel[h+1,r] == HydroReservoirLevel[h,r] + hydroInflow[h,r] - HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutBypass[h,r] + EnergyProduction[h,8,r] == HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutflow[h,r] >= hydroMinEnvFlow[r])
        @constraint(model, [h in Hours, r in Region], EnergyProduction[h,8,r] <= hydroReservoirCapacity[r] + AdditionalCapacity[8,r])
        #@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] == EnergyProduction[h,7,r])
        @constraint(model, [r in Region], AdditionalCapacity[8,r] <= hydroMaxOverall[r])

        ## HYDRO ROR

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            capFactor[h,7,r]
        )

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            iniCapT[7,r]
        )

        ## EXPRESSIONS

        useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t,r]*(1/eff[t])
            + fixedCostT[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])*(1/eff[t]) for t in TechNR, h in Hours, r in Region)
        )
        einvC = @expression(model, sum(AdditionalCapacity[t,r]*invCostT[t]*(1/expLifeTimeT[t]) for t in Tech, r in Region))
        sinvC = @expression(model, sum(AdditionalStorage[s,r]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage, r in Region))
        taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX[r]*(1/1000)*(proEmisFactor[t-1])*(1/eff[t]) for t in CarbonTech, h in Hours, r in Region))
        #rampExp = @expression(model, sum(((EnergyProduction[h,1,r] - EnergyProduction[h-1,1,r])^2)*10 for h in Hours[Hours.>1], r in Region)) #for nuclear only
        transInv = @expression(model, sum(AdditionalTrans[r, rr]*transInvCost*transLen[r,rr] for r in Region, rr in Region))
        transCostF = @expression(model, sum(transCost*Trans[h,r,rr] for h in Hours, r in Region, rr in Region))


        ## OBJECTIVE
        @objective(model, Min , (useC + einvC + sinvC + taxC + transInv + transCostF)*0.0000001)



        ##OPTIMIZE
        timeOf = @elapsed optimize!(model)
        print(i)
        result[i,1] = timeOf
        result[i,2] = objective_value(model)

        for r in Region
            for s in Storage
                result_additional_storage[i,s,r] = value.(AdditionalStorage[s, r])
                for h in Hours
                    result_charges[i,s,h,r,1] = value.(Charge[s, h, r])
                    result_charges[i,s,h,r,2] = value.(Discharge[s, h, r])
                    result_charges[i,s,h,r,3] = value.(StorageLevel[s, h, r])
                end
            end
            for t in Tech
                result_additional_capacity[i,t,r] = value.(AdditionalCapacity[t, r])
            end
            for rr in Region
                result_AdditionalTrans[i,r,rr] = value.(AdditionalTrans[r, rr])
            end
            for h in Hours
                result_hydros[i,h,r,1] = value.(HydroReservoirLevel[h, r])
                result_hydros[i,h,r,2] = value.(HydroOutflow[h, r])
                result_hydros[i,h,r,3] = value.(HydroOutBypass[h, r])

                for rr in Region
                    result_trans[i,h,r,rr] = value.(Trans[h, r, rr])
                end

                for t in Tech
                    result_energyProduction[i,h,t,r] = value.(EnergyProduction[h, t, r])
                end
            end
        end

        for h in Hours
            RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region)) + value.(sum(EnergyProduction[h,8,r] for r in Region))
            RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
            RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
        end
        result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
        result[i,4] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,3] for h in Hours )
        result[i,5] = taxLevel

    end
    return [result, RENW,result_additional_storage, result_charges, result_additional_capacity,result_AdditionalTrans,result_hydros,result_trans,result_energyProduction]
end



#LEN = 8755
#INVESTIGATION = 30
include("values.jl")
TAX = [62, 2, 112, 1, 15, 0.07]
#MAIN RUNNER BELOW
allocaterDIFF_MLUTIPLY_8755_30 = setTaxLevelsOWN(TAX, INVESTIGATION, LEN)




plot( allocaterDIFF_MLUTIPLY_8755_30[1][:,1])
summerDiff = sum(allocaterDIFF_MLUTIPLY_8755_30[9][:,h,8,1] for h in Hours)
plot(summerDiff)
plot( allocaterDIFF_MLUTIPLY_8755_30[9][:,1,1,1])


## total costs
total_costs_diff_multi = allocaterDIFF_MLUTIPLY_8755_30[1][:,2]
tax_level_diff_multi = allocaterDIFF_MLUTIPLY_8755_30[1][:,5]
plot(tax_level_diff_multi, total_costs_diff_multi.*10000000, title="Total costs of uniform tax", ylabel="Total costs (€)", xlabel="Tax level (€)", label="")


## res SHARE

total_costs_diff_multi = zeros(30, 10)

for i in 1:30
    for t in Tech
        total_costs_diff_multi[i, t] = sum(allocaterUNI_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
    end
end

res_diff_multi = zeros(30)
for i in 1:30
    res_diff_multi[i] = sum(tax_level_diff_multi[i,t] for t in 5:8)/(sum(tax_level_diff_multi[i,t] for t in 2:8))
end

plot(tax_level_diff_multi, res_diff_multi, title="RES share excluding nuclear of uniform tax", ylabel="Total costs (€)", xlabel="Tax level (€)", label="")

plot(sum(allocaterUNI_MLUTIPLY_8755_30[5][:,t,3] for t in Tech))

plot(tax_level_uni_multi, total_costs_uni_multi[:, 8], title="Total costs of uniform tax", ylabel="Total costs (€)", xlabel="Tax level (€)", label="")
#Technologies used
# 1 nuclear
# 2 coal
# 3 biomass and waste
# 4 (bio)gas
# 5 wind
# 6 solar
# 7 Direct hydro
# 8 Storal hydro































################################################################################
function setTaxLevelsMIX(taxValues, L, LEN)

    Tech            = collect(1:8)
    CarbonTech      = collect(2:4)
    RenewableTech   = collect(5:7)
    TechNR          = collect(1:7)
    TechNRR          = collect(1:6)
    Hours           = collect(1:LEN)
    Storage         = collect(1:1)
    Region          = collect(1:6)



    ################################################################################
    # IMPORT DATA

    d_demand       = CSV.read("data/DemandData.csv")
    d_available    = CSV.read("data/AvailabilityData.csv")
    d_capacity     = CSV.read("data/CapacityData.csv")
    d_trans        = CSV.read("data/TransData.csv")
    d_ror          = CSV.read("data/RORdata.csv")
    d_res          = CSV.read("data/RESdata.csv")

    ################################################################################
    # PARAMETERS

    #TECH
    iniCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    maxCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    capFactor           = zeros(length(Hours), length(TechNR), length(Region))
    #capFactor = Matrix{Float64}(undef, length(Hours), length(Tech), length(Region))
    rampUpMax           = Array{Float64}(undef, length(Tech))
    rampDownMax         = Array{Float64}(undef, length(Tech))
    variableCostT       = Array{Float64}(undef, length(Tech))
    fixedCostT          = Array{Float64}(undef, length(Tech))
    invCostT            = Array{Float64}(undef, length(Tech))
    expLifeTimeT        = Array{Float64}(undef, length(Tech))
    eff                 = Array{Float64}(undef, length(Tech))
    hydroMinReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroMaxReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroReservoirCapacity = Array{Float64}(undef, length(Region)) #OK
    hydroInflow         = Matrix{Float64}(undef, length(Hours), length(Region)) #OK
    hydroMinEnvFlow     = Array{Float64}(undef, length(Region)) #OK
    hydroMaxOverall     = Array{Float64}(undef, length(Region)) #OK

    #for t in Tech
    #    iniCapT[t] = 400
    #    maxCapT[t] = 600
    #    rampUpMax[t] = 0.05
    #    rampDownMax[t] = 20
    #    variableCostT[t] = 400
    #    fixedCostT[t] = 200
    #    invCostT[t] = 10000
    #    expLifeTimeT[t] = 50
    #end
    #http://smartenergytransition.fi/en/
    #finnish-energy-system-can-be-made-100-fossil-fuel-free/

    # CAPACITY

    for t in TechNR
        k = t+1
        for r in Region
            iniCapT[t,r] = d_capacity[r, k]
            maxCapT[t,r] = d_capacity[r, k+15]
        end
    end



    # CAPACITY HYDRO

    for r in Region
        hydroMinReservoir[r]        = d_capacity[r, 11]
        hydroMaxReservoir[r]        = d_capacity[r, 12]
        hydroReservoirCapacity[r]   = d_capacity[r, 13]
        hydroMinEnvFlow[r]          = d_capacity[r, 14]
        hydroMaxOverall[r]          = d_capacity[r, 25]
        hydroInflow[1,r]            = 1000*d_res[1, r]
        for h in Hours[Hours.>1]
            hydroInflow[h,r]        = 1000*d_res[cld(h,24), r]/24
        end
    end

    #GENERAL

    # 1 nuclear
    rampUpMax[1]        = 0.01 #not known
    rampDownMax[1]      = 0.01 #not known
    variableCostT[1]    = 10
    fixedCostT[1]       = 130000 #pro kwh and year
    invCostT[1]         = 5000000
    expLifeTimeT[1]     = 60
    eff[1]              = 0.4

    # 2 coal
    rampUpMax[2]        = 0.1 #not known
    rampDownMax[2]      = 0.6 #not known
    variableCostT[2]    = 11
    fixedCostT[2]       = 100000 #pro kwh and year
    invCostT[2]         = 1600000
    expLifeTimeT[2]     = 40 #not known
    eff[2]              = 0.45

    # 3 biomass and waste etc
    rampUpMax[3]        = 0.1
    rampDownMax[3]      = 0.1
    variableCostT[3]    = 50
    fixedCostT[3]       = 100000 #pro kwh and year
    invCostT[3]         = 3700000
    expLifeTimeT[3]     = 25
    eff[3]              = 0.25

    # 4 (bio)gas
    rampUpMax[4]        = 0.5 #https://www.wartsila.com/energy/learn-more/technical-comparisons/combustion-engine-vs-gas-turbine-ramp-rate
    rampDownMax[4]      = 0.5 #not known
    variableCostT[4]    = 85
    fixedCostT[4]       = 20000 #pro kwh and year
    invCostT[4]         = 700000
    expLifeTimeT[4]     = 30
    eff[4]              = 0.6

    # 5 wind
    rampUpMax[5]        = 1
    rampDownMax[5]      = 1
    variableCostT[5]    = 0
    fixedCostT[5]       = 40000 #pro kwh and year
    invCostT[5]         = 1090000
    expLifeTimeT[5]     = 25
    eff[5]              = 1

    # 6 solar
    rampUpMax[6]        = 1
    rampDownMax[6]      = 1
    variableCostT[6]    = 0
    fixedCostT[6]       = 30000 #pro kwh and year
    invCostT[6]         = 690000
    expLifeTimeT[6]     = 30
    eff[6]              = 1

    # 7 HydroROR
    rampUpMax[7]        = 1 #not known
    rampDownMax[7]      = 1 #not known
    variableCostT[7]    = 0
    fixedCostT[7]       = 70000 #pro kwh and year
    invCostT[7]         = 3450000
    expLifeTimeT[7]     = 80 #not known
    eff[7]              = 1 #not known

    # 8 HydroRes
    rampUpMax[8]        = 0.2 #not known
    rampDownMax[8]      = 0.3 #not known
    variableCostT[8]    = 110
    fixedCostT[8]       = 20000 #pro kwh and year
    invCostT[8]         = 1300000
    expLifeTimeT[8]     = 40 #not known
    eff[8]              = 1 #not known


    #Capacity factors for generation
    for h in Hours
        for r in Region #TODO
            capFactor[h, 1, r] = 1
            capFactor[h, 2, r] = 1
            capFactor[h, 3, r] = 1
            capFactor[h, 4, r] = 1
            capFactor[h, 5, r] = d_available[h, r*4]
            capFactor[h, 6, r] = d_available[h, r*4-2]
            capFactor[h, 7, r] = 1000*d_ror[cld(h,24), r]/24
        end
    end

    #OTHER
    proEmisFactor =  Array{Float64}(undef, length(CarbonTech))
    proEmisFactor[1] = 0.2*1000 #coal kgC02/kWh -> MWh same as MW
    proEmisFactor[2] = 0.5*1000 #biomass/waste
    proEmisFactor[3] = 0.4*1000 #biogas


    #STORAGE
    chargeMax       = Array{Float64}(undef, length(Storage))
    dischargeMax    = Array{Float64}(undef, length(Storage))
    iniCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    maxCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    invCostS        = Array{Float64}(undef, length(Storage))
    expLifeTimeS    = Array{Float64}(undef, length(Storage))

    for s in Storage
        for r in Region #TODO
            iniCapS[s,r] = d_capacity[r, 10]
            maxCapS[s,r] = d_capacity[r, 10+15]
        end
        #general
        chargeMax[s] = 500
        dischargeMax[s] = 800
        invCostS[s]     = 240000 #ok
        expLifeTimeS[s] = 10 #ok
    end

    batteryEff = 0.9;

    # DEMAND
    Demand = Matrix{Float64}(undef, length(Hours), length(Region))

    for h in Hours
        for r in Region
            Demand[h, r] = d_demand[h, 4*r]
        end
    end

    transCap = Matrix{Float64}(undef, length(Region), length(Region))
    maxTransCap = Matrix{Float64}(undef, length(Region), length(Region))
    transLen = Matrix{Float64}(undef, length(Region), length(Region))
    for r in Region
        for rr in Region
                transCap[r, rr]     = d_trans[r,rr + 1]
                maxTransCap[r,rr]   = d_trans[r,rr + 8]
                transLen[r, rr]     = d_trans[r,rr + 15]
        end
    end


    transInvCost = 460 #ok
    transCost    = 0.0001
    transEff    = 0.95






    #TAX_initial = [62, 2, 112, 1, 15, 0.07]
    TAX = taxValues
    result = Matrix{Float64}(undef, L, 20)
    RENW = Matrix{Float64}(undef, length(Hours), 3)
    result_additional_storage = zeros(L, length(Storage), length(Region))
    result_charges = zeros(L,length(Storage),length(Hours),length(Region),3)
    result_additional_capacity = zeros(L,length(Tech),length(Region))
    result_AdditionalTrans = zeros(L,length(Region),length(Region))
    result_hydros = zeros(L,length(Hours),length(Region),3)
    result_trans = zeros(L,length(Hours),length(Region),length(Region))
    result_energyProduction = zeros(L, length(Hours),length(Tech),length(Region))



    for i in 1:L
        taxLevel = i*0.17 - 0.17
        TAX = taxValues.*taxLevel
        ##LAUNCH MODEL
        model = Model(Gurobi.Optimizer)
        #set_optimizer_attributes(model, "Presolve" => 15000, "Heuristics" => 0.01)

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
        @constraint(model, [h in Hours, t in TechNRR, r in Region],
            EnergyProduction[h,t,r]
            <=
            capFactor[h,t,r]*(iniCapT[t,r]
            + AdditionalCapacity[t,r])
        )


        #@constraint(model, [t in TechNH, r in Region], 0 <= AdditionalCapacity[t,r])
        @constraint(model, [t in TechNR, r in Region],
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
        @constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])
        @constraint(model, [s in Storage, h in Hours[Hours.>1], r in Region], StorageLevel[s,h,r] - StorageLevel[s,h-1,r] == Charge[s,h-1,r] - Discharge[s,h-1,r]*batteryEff)
        @constraint(model, [s in Storage, h in Hours, r in Region], StorageLevel[s,h,r] <= AdditionalStorage[s,r] + iniCapS[s,r])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Charge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Charge[s,h,r] <= chargeMax[s])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Discharge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Discharge[s,h,r] <= dischargeMax[s])#@constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])

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

        ## HYDRO RES

        @constraint(model, [h in Hours[Hours.>24], r in Region], hydroMinReservoir[r] <= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours, r in Region], hydroMaxReservoir[r] >= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours[Hours.<LEN], r in Region], HydroReservoirLevel[h+1,r] == HydroReservoirLevel[h,r] + hydroInflow[h,r] - HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutBypass[h,r] + EnergyProduction[h,8,r] == HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutflow[h,r] >= hydroMinEnvFlow[r])
        @constraint(model, [h in Hours, r in Region], EnergyProduction[h,8,r] <= hydroReservoirCapacity[r] + AdditionalCapacity[8,r])
        #@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] == EnergyProduction[h,7,r])
        @constraint(model, [r in Region], AdditionalCapacity[8,r] <= hydroMaxOverall[r])

        ## HYDRO ROR

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            capFactor[h,7,r]
        )

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            iniCapT[7,r]
        )

        ## EXPRESSIONS

        useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t,r]*(1/eff[t])
            + fixedCostT[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])*(1/eff[t]) for t in TechNR, h in Hours, r in Region)
        )
        einvC = @expression(model, sum(AdditionalCapacity[t,r]*invCostT[t]*(1/expLifeTimeT[t]) for t in Tech, r in Region))
        sinvC = @expression(model, sum(AdditionalStorage[s,r]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage, r in Region))
        taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX[r]*(1/1000)*(proEmisFactor[t-1])*(1/eff[t]) for t in CarbonTech, h in Hours, r in Region))
        #rampExp = @expression(model, sum(((EnergyProduction[h,1,r] - EnergyProduction[h-1,1,r])^2)*10 for h in Hours[Hours.>1], r in Region)) #for nuclear only
        transInv = @expression(model, sum(AdditionalTrans[r, rr]*transInvCost*transLen[r,rr] for r in Region, rr in Region))
        transCostF = @expression(model, sum(transCost*Trans[h,r,rr] for h in Hours, r in Region, rr in Region))


        ## OBJECTIVE
        @objective(model, Min , (useC + einvC + sinvC + taxC + transInv + transCostF)*0.0000001)



        ##OPTIMIZE
        timeOf = @elapsed optimize!(model)
        print(i)
        result[i,1] = timeOf
        result[i,2] = objective_value(model)

        for r in Region
            for s in Storage
                result_additional_storage[i,s,r] = value.(AdditionalStorage[s, r])
                for h in Hours
                    result_charges[i,s,h,r,1] = value.(Charge[s, h, r])
                    result_charges[i,s,h,r,2] = value.(Discharge[s, h, r])
                    result_charges[i,s,h,r,3] = value.(StorageLevel[s, h, r])
                end
            end
            for t in Tech
                result_additional_capacity[i,t,r] = value.(AdditionalCapacity[t, r])
            end
            for rr in Region
                result_AdditionalTrans[i,r,rr] = value.(AdditionalTrans[r, rr])
            end
            for h in Hours
                result_hydros[i,h,r,1] = value.(HydroReservoirLevel[h, r])
                result_hydros[i,h,r,2] = value.(HydroOutflow[h, r])
                result_hydros[i,h,r,3] = value.(HydroOutBypass[h, r])

                for rr in Region
                    result_trans[i,h,r,rr] = value.(Trans[h, r, rr])
                end

                for t in Tech
                    result_energyProduction[i,h,t,r] = value.(EnergyProduction[h, t, r])
                end
            end
        end

        for h in Hours
            RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region)) + value.(sum(EnergyProduction[h,8,r] for r in Region))
            RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
            RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
        end
        result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
        result[i,4] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,3] for h in Hours )
        result[i,5] = taxLevel

    end
    return [result, RENW,result_additional_storage, result_charges, result_additional_capacity,result_AdditionalTrans,result_hydros,result_trans,result_energyProduction]
end



#LEN = 8755
#INVESTIGATION = 30
include("values.jl")
TAX = [62, 10, 112, 10, 15, 10] #at least 10
#MAIN RUNNER BELOW
allocaterMIX_MLUTIPLY_8755_30 = setTaxLevelsMIX(TAX, INVESTIGATION, LEN)


































################################################################################
function setTaxLevelsADD(taxValues, L, LEN)

    Tech            = collect(1:8)
    CarbonTech      = collect(2:4)
    RenewableTech   = collect(5:7)
    TechNR          = collect(1:7)
    TechNRR          = collect(1:6)
    Hours           = collect(1:LEN)
    Storage         = collect(1:1)
    Region          = collect(1:6)



    ################################################################################
    # IMPORT DATA

    d_demand       = CSV.read("data/DemandData.csv")
    d_available    = CSV.read("data/AvailabilityData.csv")
    d_capacity     = CSV.read("data/CapacityData.csv")
    d_trans        = CSV.read("data/TransData.csv")
    d_ror          = CSV.read("data/RORdata.csv")
    d_res          = CSV.read("data/RESdata.csv")

    ################################################################################
    # PARAMETERS

    #TECH
    iniCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    maxCapT             = Matrix{Float64}(undef, length(Tech), length(Region)) #OK
    capFactor           = zeros(length(Hours), length(TechNR), length(Region))
    #capFactor = Matrix{Float64}(undef, length(Hours), length(Tech), length(Region))
    rampUpMax           = Array{Float64}(undef, length(Tech))
    rampDownMax         = Array{Float64}(undef, length(Tech))
    variableCostT       = Array{Float64}(undef, length(Tech))
    fixedCostT          = Array{Float64}(undef, length(Tech))
    invCostT            = Array{Float64}(undef, length(Tech))
    expLifeTimeT        = Array{Float64}(undef, length(Tech))
    eff                 = Array{Float64}(undef, length(Tech))
    hydroMinReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroMaxReservoir   = Array{Float64}(undef, length(Region)) #OK
    hydroReservoirCapacity = Array{Float64}(undef, length(Region)) #OK
    hydroInflow         = Matrix{Float64}(undef, length(Hours), length(Region)) #OK
    hydroMinEnvFlow     = Array{Float64}(undef, length(Region)) #OK
    hydroMaxOverall     = Array{Float64}(undef, length(Region)) #OK

    #for t in Tech
    #    iniCapT[t] = 400
    #    maxCapT[t] = 600
    #    rampUpMax[t] = 0.05
    #    rampDownMax[t] = 20
    #    variableCostT[t] = 400
    #    fixedCostT[t] = 200
    #    invCostT[t] = 10000
    #    expLifeTimeT[t] = 50
    #end
    #http://smartenergytransition.fi/en/
    #finnish-energy-system-can-be-made-100-fossil-fuel-free/

    # CAPACITY

    for t in TechNR
        k = t+1
        for r in Region
            iniCapT[t,r] = d_capacity[r, k]
            maxCapT[t,r] = d_capacity[r, k+15]
        end
    end



    # CAPACITY HYDRO

    for r in Region
        hydroMinReservoir[r]        = d_capacity[r, 11]
        hydroMaxReservoir[r]        = d_capacity[r, 12]
        hydroReservoirCapacity[r]   = d_capacity[r, 13]
        hydroMinEnvFlow[r]          = d_capacity[r, 14]
        hydroMaxOverall[r]          = d_capacity[r, 25]
        hydroInflow[1,r]            = 1000*d_res[1, r]
        for h in Hours[Hours.>1]
            hydroInflow[h,r]        = 1000*d_res[cld(h,24), r]/24
        end
    end

    #GENERAL

    # 1 nuclear
    rampUpMax[1]        = 0.01 #not known
    rampDownMax[1]      = 0.01 #not known
    variableCostT[1]    = 10
    fixedCostT[1]       = 130000 #pro kwh and year
    invCostT[1]         = 5000000
    expLifeTimeT[1]     = 60
    eff[1]              = 0.4

    # 2 coal
    rampUpMax[2]        = 0.1 #not known
    rampDownMax[2]      = 0.6 #not known
    variableCostT[2]    = 11
    fixedCostT[2]       = 100000 #pro kwh and year
    invCostT[2]         = 1600000
    expLifeTimeT[2]     = 40 #not known
    eff[2]              = 0.45

    # 3 biomass and waste etc
    rampUpMax[3]        = 0.1
    rampDownMax[3]      = 0.1
    variableCostT[3]    = 50
    fixedCostT[3]       = 100000 #pro kwh and year
    invCostT[3]         = 3700000
    expLifeTimeT[3]     = 25
    eff[3]              = 0.25

    # 4 (bio)gas
    rampUpMax[4]        = 0.5 #https://www.wartsila.com/energy/learn-more/technical-comparisons/combustion-engine-vs-gas-turbine-ramp-rate
    rampDownMax[4]      = 0.5 #not known
    variableCostT[4]    = 85
    fixedCostT[4]       = 20000 #pro kwh and year
    invCostT[4]         = 700000
    expLifeTimeT[4]     = 30
    eff[4]              = 0.6

    # 5 wind
    rampUpMax[5]        = 1
    rampDownMax[5]      = 1
    variableCostT[5]    = 0
    fixedCostT[5]       = 40000 #pro kwh and year
    invCostT[5]         = 1090000
    expLifeTimeT[5]     = 25
    eff[5]              = 1

    # 6 solar
    rampUpMax[6]        = 1
    rampDownMax[6]      = 1
    variableCostT[6]    = 0
    fixedCostT[6]       = 30000 #pro kwh and year
    invCostT[6]         = 690000
    expLifeTimeT[6]     = 30
    eff[6]              = 1

    # 7 HydroROR
    rampUpMax[7]        = 1 #not known
    rampDownMax[7]      = 1 #not known
    variableCostT[7]    = 0
    fixedCostT[7]       = 70000 #pro kwh and year
    invCostT[7]         = 3450000
    expLifeTimeT[7]     = 80 #not known
    eff[7]              = 1 #not known

    # 8 HydroRes
    rampUpMax[8]        = 0.2 #not known
    rampDownMax[8]      = 0.3 #not known
    variableCostT[8]    = 110
    fixedCostT[8]       = 20000 #pro kwh and year
    invCostT[8]         = 1300000
    expLifeTimeT[8]     = 40 #not known
    eff[8]              = 1 #not known


    #Capacity factors for generation
    for h in Hours
        for r in Region #TODO
            capFactor[h, 1, r] = 1
            capFactor[h, 2, r] = 1
            capFactor[h, 3, r] = 1
            capFactor[h, 4, r] = 1
            capFactor[h, 5, r] = d_available[h, r*4]
            capFactor[h, 6, r] = d_available[h, r*4-2]
            capFactor[h, 7, r] = 1000*d_ror[cld(h,24), r]/24
        end
    end

    #OTHER
    proEmisFactor =  Array{Float64}(undef, length(CarbonTech))
    proEmisFactor[1] = 0.2*1000 #coal kgC02/kWh -> MWh same as MW
    proEmisFactor[2] = 0.5*1000 #biomass/waste
    proEmisFactor[3] = 0.4*1000 #biogas


    #STORAGE
    chargeMax       = Array{Float64}(undef, length(Storage))
    dischargeMax    = Array{Float64}(undef, length(Storage))
    iniCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    maxCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
    invCostS        = Array{Float64}(undef, length(Storage))
    expLifeTimeS    = Array{Float64}(undef, length(Storage))

    for s in Storage
        for r in Region #TODO
            iniCapS[s,r] = d_capacity[r, 10]
            maxCapS[s,r] = d_capacity[r, 10+15]
        end
        #general
        chargeMax[s] = 500
        dischargeMax[s] = 800
        invCostS[s]     = 240000 #ok
        expLifeTimeS[s] = 10 #ok
    end

    batteryEff = 0.9;

    # DEMAND
    Demand = Matrix{Float64}(undef, length(Hours), length(Region))

    for h in Hours
        for r in Region
            Demand[h, r] = d_demand[h, 4*r]
        end
    end

    transCap = Matrix{Float64}(undef, length(Region), length(Region))
    maxTransCap = Matrix{Float64}(undef, length(Region), length(Region))
    transLen = Matrix{Float64}(undef, length(Region), length(Region))
    for r in Region
        for rr in Region
                transCap[r, rr]     = d_trans[r,rr + 1]
                maxTransCap[r,rr]   = d_trans[r,rr + 8]
                transLen[r, rr]     = d_trans[r,rr + 15]
        end
    end


    transInvCost = 460 #ok
    transCost    = 0.0001
    transEff    = 0.95






    #TAX_initial = [62, 2, 112, 1, 15, 0.07]
    TAX = taxValues
    result = Matrix{Float64}(undef, L, 20)
    RENW = Matrix{Float64}(undef, length(Hours), 3)
    result_additional_storage = zeros(L, length(Storage), length(Region))
    result_charges = zeros(L,length(Storage),length(Hours),length(Region),3)
    result_additional_capacity = zeros(L,length(Tech),length(Region))
    result_AdditionalTrans = zeros(L,length(Region),length(Region))
    result_hydros = zeros(L,length(Hours),length(Region),3)
    result_trans = zeros(L,length(Hours),length(Region),length(Region))
    result_energyProduction = zeros(L, length(Hours),length(Tech),length(Region))



    for i in 1:L
        taxLevel = i*3 - 3
        TAX = taxValues.+taxLevel
        ##LAUNCH MODEL
        model = Model(Gurobi.Optimizer)
        #set_optimizer_attributes(model, "Presolve" => 15000, "Heuristics" => 0.01)

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
        @constraint(model, [h in Hours, t in TechNRR, r in Region],
            EnergyProduction[h,t,r]
            <=
            capFactor[h,t,r]*(iniCapT[t,r]
            + AdditionalCapacity[t,r])
        )


        #@constraint(model, [t in TechNH, r in Region], 0 <= AdditionalCapacity[t,r])
        @constraint(model, [t in TechNR, r in Region],
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
        @constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])
        @constraint(model, [s in Storage, h in Hours[Hours.>1], r in Region], StorageLevel[s,h,r] - StorageLevel[s,h-1,r] == Charge[s,h-1,r] - Discharge[s,h-1,r]*batteryEff)
        @constraint(model, [s in Storage, h in Hours, r in Region], StorageLevel[s,h,r] <= AdditionalStorage[s,r] + iniCapS[s,r])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Charge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Charge[s,h,r] <= chargeMax[s])
        #@constraint(model, [s in Storage, h in Hours, r in Region], 0 <= Discharge[s,h,r])
        @constraint(model, [s in Storage, h in Hours, r in Region], Discharge[s,h,r] <= dischargeMax[s])#@constraint(model, [s in Storage, r in Region], AdditionalStorage[s,r] <= maxCapS[s,r])

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

        ## HYDRO RES

        @constraint(model, [h in Hours[Hours.>24], r in Region], hydroMinReservoir[r] <= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours, r in Region], hydroMaxReservoir[r] >= HydroReservoirLevel[h,r])
        @constraint(model, [h in Hours[Hours.<LEN], r in Region], HydroReservoirLevel[h+1,r] == HydroReservoirLevel[h,r] + hydroInflow[h,r] - HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutBypass[h,r] + EnergyProduction[h,8,r] == HydroOutflow[h,r])
        @constraint(model, [h in Hours, r in Region], HydroOutflow[h,r] >= hydroMinEnvFlow[r])
        @constraint(model, [h in Hours, r in Region], EnergyProduction[h,8,r] <= hydroReservoirCapacity[r] + AdditionalCapacity[8,r])
        #@constraint(model, [h in Hours, r in Region], HydroOutPower[h,r] == EnergyProduction[h,7,r])
        @constraint(model, [r in Region], AdditionalCapacity[8,r] <= hydroMaxOverall[r])

        ## HYDRO ROR

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            capFactor[h,7,r]
        )

        @constraint(model, [h in Hours, r in Region],
            EnergyProduction[h,7,r]
            <=
            iniCapT[7,r]
        )

        ## EXPRESSIONS

        useC = @expression(model, sum(variableCostT[t]*EnergyProduction[h,t,r]*(1/eff[t])
            + fixedCostT[t]*(iniCapT[t,r] + AdditionalCapacity[t,r])*(1/eff[t]) for t in TechNR, h in Hours, r in Region)
        )
        einvC = @expression(model, sum(AdditionalCapacity[t,r]*invCostT[t]*(1/expLifeTimeT[t]) for t in Tech, r in Region))
        sinvC = @expression(model, sum(AdditionalStorage[s,r]*invCostS[s]*(1/expLifeTimeS[s]) for s in Storage, r in Region))
        taxC = @expression(model, sum(EnergyProduction[h,t,r]*TAX[r]*(1/1000)*(proEmisFactor[t-1])*(1/eff[t]) for t in CarbonTech, h in Hours, r in Region))
        #rampExp = @expression(model, sum(((EnergyProduction[h,1,r] - EnergyProduction[h-1,1,r])^2)*10 for h in Hours[Hours.>1], r in Region)) #for nuclear only
        transInv = @expression(model, sum(AdditionalTrans[r, rr]*transInvCost*transLen[r,rr] for r in Region, rr in Region))
        transCostF = @expression(model, sum(transCost*Trans[h,r,rr] for h in Hours, r in Region, rr in Region))


        ## OBJECTIVE
        @objective(model, Min , (useC + einvC + sinvC + taxC + transInv + transCostF)*0.0000001)



        ##OPTIMIZE
        timeOf = @elapsed optimize!(model)
        print(i)
        result[i,1] = timeOf
        result[i,2] = objective_value(model)

        for r in Region
            for s in Storage
                result_additional_storage[i,s,r] = value.(AdditionalStorage[s, r])
                for h in Hours
                    result_charges[i,s,h,r,1] = value.(Charge[s, h, r])
                    result_charges[i,s,h,r,2] = value.(Discharge[s, h, r])
                    result_charges[i,s,h,r,3] = value.(StorageLevel[s, h, r])
                end
            end
            for t in Tech
                result_additional_capacity[i,t,r] = value.(AdditionalCapacity[t, r])
            end
            for rr in Region
                result_AdditionalTrans[i,r,rr] = value.(AdditionalTrans[r, rr])
            end
            for h in Hours
                result_hydros[i,h,r,1] = value.(HydroReservoirLevel[h, r])
                result_hydros[i,h,r,2] = value.(HydroOutflow[h, r])
                result_hydros[i,h,r,3] = value.(HydroOutBypass[h, r])

                for rr in Region
                    result_trans[i,h,r,rr] = value.(Trans[h, r, rr])
                end

                for t in Tech
                    result_energyProduction[i,h,t,r] = value.(EnergyProduction[h, t, r])
                end
            end
        end

        for h in Hours
            RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region)) + value.(sum(EnergyProduction[h,8,r] for r in Region))
            RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
            RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
        end
        result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
        result[i,4] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,3] for h in Hours )
        result[i,5] = taxLevel

    end
    return [result, RENW,result_additional_storage, result_charges, result_additional_capacity,result_AdditionalTrans,result_hydros,result_trans,result_energyProduction]
end



#LEN = 8755
#INVESTIGATION = 30
include("values.jl")
TAX = [62, 2, 112, 1, 15, 0.07] #noat least 10
#MAIN RUNNER BELOW
allocaterUNI_ADD_8755_30 = setTaxLevelsADD(TAX, INVESTIGATION, LEN)
