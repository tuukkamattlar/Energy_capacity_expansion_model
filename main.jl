using Plots

#APPLY CARBON TAX and LENGTH
TAX_initial = [62, 2, 112, 0, 15, 0.07]
TAX_initial = [50, 50, 50, 50, 50, 50].*2
TAX = TAX_initial
LEN = 100

include("model.jl")
include("values.jl")


include("bringData.jl")

function runner(inp)
    getData(inp)
    value = runModel(inp)
    state = value
end


## test run time
invLen = 100
timetaken = zeros(invLen, 3)
steptime = zeros(5)
for i in 1:invLen
    include("model.jl")
    iteration = i*80
    timetaken[i,1] = @elapsed runner(iteration)
    timetaken[i,2] = @elapsed runner(iteration)
    #timetaken[i,3] = @elapsed runner(i*30)
    #timetaken[i,4] = @elapsed runner(i*30)
    #timetaken[i,5] = @elapsed runner(i*30)
    timetaken[i,3] = iteration
    #timetaken[i,7] = sum(timetaken[i,s] for s in 1:5)/4
end

timetaken[60,2] = 123.4
timetaken[75,1] = 200.1
timetaken[82,1] = 296.1

togetherTime = zeros(100)
for i in 1:100
    iter = i*80
    togetherTime[i] = (timetaken[i,1] + timetaken[i,2] )/2
end

plot(timetaken[:,3], togetherTime[:] , title="Running time", ylabel="Seconds (s)", xlabel="Hours in the model (h)", label="")

plot(timetaken[:,2], timetaken[:,1], title="Running time", ylabel="Seconds (s)", xlabel="Hours in the model (h)", label="")


## GATHER THE RESULTS

## run the main analysis

function setTaxLevels(taxValues, L, LEN)
    TAX_initial = [62, 2, 112, 1, 15, 0.07]
    TAX = taxValues
    result = Matrix{Float64}(undef, L, 20)
    include("values.jl")
    #include("model.jl")
    #getData(LEN)
    RENW = Matrix{Float64}(undef, length(Hours), 3)
    result_additional_storage = zeros(L, length(Storage), length(Region))
    result_charges = zeros(L,length(Storage),length(Hours),length(Region),3)
    result_additional_capacity = zeros(L,length(Tech),length(Region))
    result_AdditionalTrans = zeros(L,length(Region),length(Region))
    result_hydros = zeros(L,length(Hours),length(Region),3)
    result_trans = zeros(L,length(Hours),length(Region),length(Region))
    result_energyProduction = zeros(L, length(Hours),length(Tech),length(Region))

    Tech            = collect(1:8)
    CarbonTech      = collect(2:4)
    RenewableTech   = collect(5:7)
    TechNR          = collect(1:7)
    TechNRR          = collect(1:6)
    Hours           = collect(1:LEN)
    Storage         = collect(1:1)
    Region          = collect(1:6)

    for i in 1:L
        taxLevel = i*5-5
        TAX = TAX_initial.*taxLevel
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





LEN = 1000
INVESTIGATION = 10
TAX = [62, 2, 112, 1, 15, 0.07]
allocaterFREE_MLUTIPLY_8000_100 = setTaxLevels([62, 2, 112, 15, 15, 0.07], INVESTIGATION, LEN)
plot( allocater[1][:,1])



plot(result[:,1])
plot(result[:,4])
plot(RENW[:,2])
plot(RENW[:,1])

suomiT = zeros(L,length(Tech))
for i in 1:L
    for t in Tech
        suomiT[i,t] = sum(result_energyProduction[i,h,t,1] for h in Hours)
    end
end
plot(suomiT[:,8])

##


#VISUALISATION PART
##

#GENERIC PLOTS FOR SOME REGIONS
plot(AllResults[:,:,1,1], title="Finland", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Direct Hydro" "Storal Hydro" "Storage" "Trans"])
plot(AllResults[:,:,2,1], title="Estonia", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Direct Hydro" "Storal Hydro" "Storage" "Trans"])
plot(AllResults[:,:,3,1], title="Sweden", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Direct Hydro" "Storal Hydro" "Storage" "Trans"])
plot(AllResults[:,:,4,1], title="Germany", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Direct Hydro" "Storal Hydro" "Storage" "Trans"])
plot(AllResults[:,:,5,1], title="Spain", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Direct Hydro" "Storal Hydro" "Storage" "Trans"])
plot(AllResults[:,:,6,1], title="Poland", label = ["Nuclear" "CHP" "Other coal" "Gas" "Wind" "PV" "Direct Hydro" "Storal Hydro" "Storage" "Trans"])


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
plot(AllResults[:,10,4,1], title="Trans in a country")
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
LEN = 50
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
