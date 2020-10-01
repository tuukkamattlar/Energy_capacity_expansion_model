# allocaterUNI_MLUTIPLY_8755_30
# allocaterDIFF_MLUTIPLY_8755_30
# allocaterMIX_MLUTIPLY_8755_30
# allocaterUNI_ADD_8755_30



# result[i,1] = timeOf
# result[i,2] = objective_value(model)
# result_additional_storage[i,s,r] = value.(AdditionalStorage[s, r])
# result_charges[i,s,h,r,1] = value.(Charge[s, h, r])
# result_charges[i,s,h,r,2] = value.(Discharge[s, h, r])
# result_additional_capacity[i,t,r] = value.(AdditionalCapacity[t, r])
# result_AdditionalTrans[i,r,rr] = value.(AdditionalTrans[r, rr])
# result_hydros[i,h,r,1] = value.(HydroReservoirLevel[h, r])
# result_hydros[i,h,r,2] = value.(HydroOutflow[h, r])
# result_hydros[i,h,r,3] = value.(HydroOutBypass[h, r])
# result_trans[i,h,r,rr] = value.(Trans[h, r, rr])
# result_energyProduction[i,h,t,r] = value.(EnergyProduction[h, t, r])
# RENW[h,1] = value.(sum(EnergyProduction[h,5,r] for r in Region)) + value.(sum(EnergyProduction[h,6,r] for r in Region)) + value.(sum(EnergyProduction[h,7,r] for r in Region)) + value.(sum(EnergyProduction[h,8,r] for r in Region))
# RENW[h,2] = value.(sum(EnergyProduction[h,2,r] for r in Region)) + value.(sum(EnergyProduction[h,3,r] for r in Region)) + value.(sum(EnergyProduction[h,4,r] for r in Region))
# RENW[h,3] = value.(sum(EnergyProduction[h,t,r] for r in Region, t in Tech))
# result[i,3] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,2]+RENW[h,1] for h in Hours )
# result[i,4] = sum(RENW[h,1] for h in Hours)./sum(RENW[h,3] for h in Hours )
# result[i,5] = taxLeve
# return [
        #result,
        #RENW,
        #result_additional_storage,
        #result_charges,
        #result_additional_capacity,
        #result_AdditionalTrans,
        #result_hydros,
        #result_trans,
        #result_energyProduction]



## total taxes

tax_gen = zeros(30,6,4)

for i in 1:30
    for r in Region
        TAX_ = [1, 1, 1, 1, 1, 1]
        tax_gen[i,r,1] = allocaterUNI_MLUTIPLY_8755_30[1][i,5].*TAX_[r]
    end
    for r in Region
        TAX_ = [62, 2, 112, 1, 15, 0.07]
        tax_gen[i,r,2] = allocaterDIFF_MLUTIPLY_8755_30[1][i,5].*TAX_[r]
    end
    for r in Region
        TAX_ = [62, 10, 112, 10, 15, 10]
        tax_gen[i,r,3] = allocaterMIX_MLUTIPLY_8755_30[1][i,5].*TAX_[r]
    end
    for r in Region
        TAX_ = [62, 2, 112, 1, 15, 0.07]
        tax_gen[i,r,4] = allocaterUNI_ADD_8755_30[1][i,5].+TAX_[r]
    end
end



## RUNNING TIME ANALYSIS
plot(
    [
    sum(tax_gen[:,r,1] for r in Region),
    sum(tax_gen[:,r,2] for r in Region),
    sum(tax_gen[:,r,3] for r in Region),
    sum(tax_gen[:,r,4] for r in Region)
    ],
    [allocaterUNI_MLUTIPLY_8755_30[1][:,1],
    allocaterDIFF_MLUTIPLY_8755_30[1][:,1],
    allocaterMIX_MLUTIPLY_8755_30[1][:,1],
    allocaterUNI_ADD_8755_30[1][:,1]],
    layout=4,
    title=["UM" "DM" "MM" "UA"],
    label=["" "" "" ""],
    ylabel=["Run time (s)" "Run time (s)" "Run time (s)" "Run time (s)"],
    xlabel=["Iteration" "Iteration" "Iteration" "Iteration"]
)


plot(
    [allocaterUNI_MLUTIPLY_8755_30_NUC[1][:,1],
    allocaterDIFF_MLUTIPLY_8755_30NUC[1][:,1],
    allocaterMIX_MLUTIPLY_8755_30NUC[1][:,1],
    allocaterUNI_ADD_8755_30NUC[1][:,1]],
    layout=4,
    title=["UM" "DM" "MM" "UA"],
    label=["" "" "" ""],
    ylabel=["Run time (s)" "Run time (s)" "Run time (s)" "Run time (s)"],
    xlabel=["Iteration" "Iteration" "Iteration" "Iteration"]
)




## CT vs total price



## CT vs RES SHARE

total_production = zeros(30, 10, 4)
total_productionNUC = zeros(30, 10, 4)

for i in 1:30
    for t in Tech
        total_production[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_production[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_production[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_production[i, t, 4] = sum(allocaterUNI_ADD_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30_NUC[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30NUC[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30NUC[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 4] = sum(allocaterUNI_ADD_8755_30NUC[9][i,h,t,r] for h in Hours, r in Region)
    end
end

res_share_all = zeros(30,4)
total_CT = zeros(30,4)
res_share_allNUC = zeros(30,4)
total_CTNUC = zeros(30,4)
for i in 1:30
    res_share_all[i,1] = sum(total_production[i,t,1] for t in 5:8)/(sum(total_production[i,t,1] for t in 1:8))
    res_share_all[i,2] = sum(total_production[i,t,2] for t in 5:8)/(sum(total_production[i,t,2] for t in 1:8))
    res_share_all[i,3] = sum(total_production[i,t,3] for t in 5:8)/(sum(total_production[i,t,3] for t in 1:8))
    res_share_all[i,4] = sum(total_production[i,t,4] for t in 5:8)/(sum(total_production[i,t,4] for t in 1:8))
    res_share_allNUC[i,1] = sum(total_productionNUC[i,t,1] for t in 5:8)/(sum(total_productionNUC[i,t,1] for t in 1:8))
    res_share_allNUC[i,2] = sum(total_productionNUC[i,t,2] for t in 5:8)/(sum(total_productionNUC[i,t,2] for t in 1:8))
    res_share_allNUC[i,3] = sum(total_productionNUC[i,t,3] for t in 5:8)/(sum(total_productionNUC[i,t,3] for t in 1:8))
    res_share_allNUC[i,4] = sum(total_productionNUC[i,t,4] for t in 5:8)/(sum(total_productionNUC[i,t,4] for t in 1:8))
end


plot(
    [[
    sum(tax_gen[:,r,1] for r in Region),
    sum(tax_gen[:,r,2] for r in Region),
    sum(tax_gen[:,r,3] for r in Region),
    sum(tax_gen[:,r,4] for r in Region)
    ]],
    [[res_share_all[:,1],
    res_share_all[:,2],
    res_share_all[:,3],
    res_share_all[:,4]]],
    layout=4,
    title=["UM" "DM" "MM" "UA"],
    label=["" "" "" ""],
    ylabel=["RES share" "RES share" "RES share" "RES share"],
    xlabel=["Total CT" "Total CT" "Total CT" "Total CT"]
)


plot(
    [res_share_allNUC[:,1],
    res_share_allNUC[:,2],
    res_share_allNUC[:,3],
    res_share_allNUC[:,4]],
    layout=4,
    title=["UM" "DM" "MM" "UA"],
    label=["" "" "" ""],
    ylabel=["RES share" "RES share" "RES share" "RES share"],
    xlabel=["Iteration" "Iteration" "Iteration" "Iteration"]
)




## CT vs RES SHARE IN FINLAND

total_productionFIN = zeros(30, 10, 4)
total_productionFINNUC = zeros(30, 10, 4)

for i in 1:30
    for t in Tech
        total_productionFIN[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30[9][i,h,t,1] for h in Hours)
        total_productionFIN[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30[9][i,h,t,1] for h in Hours)
        total_productionFIN[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30[9][i,h,t,1] for h in Hours)
        total_productionFIN[i, t, 4] = sum(allocaterUNI_ADD_8755_30[9][i,h,t,1] for h in Hours)
        total_productionFINNUC[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30_NUC[9][i,h,t,1] for h in Hours)
        total_productionFINNUC[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30NUC[9][i,h,t,1] for h in Hours)
        total_productionFINNUC[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30NUC[9][i,h,t,1] for h in Hours)
        total_productionFINNUC[i, t, 4] = sum(allocaterUNI_ADD_8755_30NUC[9][i,h,t,1] for h in Hours)
    end
end

res_share_FIN = zeros(30,4)
total_CT_FIN = zeros(30,4)
res_share_FINNUC = zeros(30,4)
total_CT_FINNUC = zeros(30,4)
for i in 1:30
    res_share_FIN[i,1] = sum(total_productionFIN[i,t,1] for t in 5:8)/(sum(total_productionFIN[i,t,1] for t in 1:8))
    res_share_FIN[i,2] = sum(total_productionFIN[i,t,2] for t in 5:8)/(sum(total_productionFIN[i,t,2] for t in 1:8))
    res_share_FIN[i,3] = sum(total_productionFIN[i,t,3] for t in 5:8)/(sum(total_productionFIN[i,t,3] for t in 1:8))
    res_share_FIN[i,4] = sum(total_productionFIN[i,t,4] for t in 5:8)/(sum(total_productionFIN[i,t,4] for t in 1:8))
    res_share_FINNUC[i,1] = sum(total_productionFINNUC[i,t,1] for t in 5:8)/(sum(total_productionFINNUC[i,t,1] for t in 1:8))
    res_share_FINNUC[i,2] = sum(total_productionFINNUC[i,t,2] for t in 5:8)/(sum(total_productionFINNUC[i,t,2] for t in 1:8))
    res_share_FINNUC[i,3] = sum(total_productionFINNUC[i,t,3] for t in 5:8)/(sum(total_productionFINNUC[i,t,3] for t in 1:8))
    res_share_FINNUC[i,4] = sum(total_productionFINNUC[i,t,4] for t in 5:8)/(sum(total_productionFINNUC[i,t,4] for t in 1:8))
end


plot(
    [
    sum(tax_gen[:,r,1] for r in Region),
    sum(tax_gen[:,r,2] for r in Region),
    sum(tax_gen[:,r,3] for r in Region),
    sum(tax_gen[:,r,4] for r in Region)
    ],
    [res_share_FIN[:,1],
    res_share_FIN[:,2],
    res_share_FIN[:,3],
    res_share_FIN[:,4]],
    layout=4,
    title=["UM" "DM" "MM" "UA"],
    label=["" "" "" ""],
    ylabel=["RES FIN" "RES FIN" "RES FIN" "RES FIN"],
    xlabel=["Iteration" "Iteration" "Iteration" "Iteration"]
)

plot(
    [res_share_FINNUC[:,1],
    res_share_FINNUC[:,2],
    res_share_FINNUC[:,3],
    res_share_FINNUC[:,4]],
    layout=4,
    title=["UM" "DM" "MM" "UA"],
    label=["" "" "" ""],
    ylabel=["RES FIN" "RES FIN" "RES FIN" "RES FIN"],
    xlabel=["Iteration" "Iteration" "Iteration" "Iteration"]
)




## NUCLEAR USAGE

total_production = zeros(30, 10, 4)*
total_productionNUC = zeros(30, 10, 4)

for i in 1:30
    for t in Tech
        total_production[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_production[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_production[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_production[i, t, 4] = sum(allocaterUNI_ADD_8755_30[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30_NUC[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30NUC[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30NUC[9][i,h,t,r] for h in Hours, r in Region)
        total_productionNUC[i, t, 4] = sum(allocaterUNI_ADD_8755_30NUC[9][i,h,t,r] for h in Hours, r in Region)
    end
end

res_share_all = zeros(30,4)
total_CT = zeros(30,4)
res_share_allNUC = zeros(30,4)
total_CTNUC = zeros(30,4)
for i in 1:30
    res_share_all[i,1] = sum(total_production[i,t,1] for t in 5:8)/(sum(total_production[i,t,1] for t in 1:8))
    res_share_all[i,2] = sum(total_production[i,t,2] for t in 5:8)/(sum(total_production[i,t,2] for t in 1:8))
    res_share_all[i,3] = sum(total_production[i,t,3] for t in 5:8)/(sum(total_production[i,t,3] for t in 1:8))
    res_share_all[i,4] = sum(total_production[i,t,4] for t in 5:8)/(sum(total_production[i,t,4] for t in 1:8))
    res_share_allNUC[i,1] = sum(total_productionNUC[i,t,1] for t in 5:8)/(sum(total_productionNUC[i,t,1] for t in 1:8))
    res_share_allNUC[i,2] = sum(total_productionNUC[i,t,2] for t in 5:8)/(sum(total_productionNUC[i,t,2] for t in 1:8))
    res_share_allNUC[i,3] = sum(total_productionNUC[i,t,3] for t in 5:8)/(sum(total_productionNUC[i,t,3] for t in 1:8))
    res_share_allNUC[i,4] = sum(total_productionNUC[i,t,4] for t in 5:8)/(sum(total_productionNUC[i,t,4] for t in 1:8))
end


plot(allocaterUNI_MLUTIPLY_8755_30_NUC[5][:,:, 6])


## ADDITIONAL TECNOLOGIES in ALL COUTNRIES

add_technologies = zeros(30, 10,12)

for i in 1:30
    for t in Tech
        add_technologies[i, t, 1] = sum(allocaterUNI_MLUTIPLY_8755_30[5][i,h,t,1] for h in Hours)
        add_technologies[i, t, 2] = sum(allocaterDIFF_MLUTIPLY_8755_30[5][i,h,t,1] for h in Hours)
        add_technologies[i, t, 3] = sum(allocaterMIX_MLUTIPLY_8755_30[5][i,h,t,1] for h in Hours)
        add_technologies[i, t, 4] = sum(allocaterUNI_ADD_8755_30[5][i,h,t,1] for h in Hours)
    end
end





##

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
