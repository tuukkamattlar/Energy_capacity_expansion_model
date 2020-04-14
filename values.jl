
#Technologies used
# 1 nuclear
# 2 coal slow
# 3 coal fast
# 4 gas
# 5 wind
# 6 solar
# 7 hydro

#LENGTH OF INVESTIGATION
LEN = 700

################################################################################
# SETS

Tech = collect(1:7)
CarbonTech = collect(2:4)
RenewableTech = collect(5:7)
Hours = collect(1:LEN)
Storage = collect(1:3)



################################################################################
# IMPORT DATA

usage = CSV.read("data/usedata.csv") #RENEWABLES NINJA
dema = CSV.read("data/demandinfinland.csv") #FINGRID (MWh)
locfromend = 1000

sp = length(usage[:,1])-length(Hours)-locfromend
ep  = length(usage[:,1])-locfromend
udata = usage[sp:ep,2:7]

sp = length(dema[:,1])-length(Hours)-locfromend-1
ep  = length(dema[:,1])-locfromend-1
dem = dema[sp:ep,5]

#plot(udata[:,1])
for h in Hours
    udata[h, 5] = min(udata[h,1]+udata[h,2]+udata[h,3]+udata[h,4]+udata[h,5], 1)
    udata[h, 4] = parse(Float64, dem[h])
end
#plot(udata[:,6])
#plot(udata[:,5])
#plot(udata[:,4])

################################################################################
# PARAMETERS

#TECH
iniCapT = Array{Float64}(undef, length(Tech))
maxCapT = Array{Float64}(undef, length(Tech))
capFactor = Matrix{Float64}(undef, length(Hours), length(Tech))
rampUpMax = Array{Float64}(undef, length(Tech))
rampDownMax = Array{Float64}(undef, length(Tech))
variableCostT = Array{Float64}(undef, length(Tech))
fixedCostT = Array{Float64}(undef, length(Tech))
invCostT = Array{Float64}(undef, length(Tech))
expLifeTimeT = Array{Float64}(undef, length(Tech))
eff = Array{Float64}(undef, length(Tech))

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

# 1 nuclear
iniCapT[1] = 2794
maxCapT[1] = 50000
rampUpMax[1] = 1
rampDownMax[1] = 1
variableCostT[1] = 37
fixedCostT[1] = 200
invCostT[1] = 5000000
expLifeTimeT[1] = 60
eff[1] = 0.4

# 2 coal slow
iniCapT[2] = 3200
maxCapT[2] = 40000
rampUpMax[2] = 0.1
rampDownMax[2] = 0.6
variableCostT[2] = 11
fixedCostT[2] = 100
invCostT[2] = 1600000
expLifeTimeT[2] = 50
eff[2] = 0.45

# 3 coal fast
iniCapT[3] = 0
maxCapT[3] = 0
rampUpMax[3] = 0.1
rampDownMax[3] = 0.1
variableCostT[3] = 11
fixedCostT[3] = 100
invCostT[3] = 1600000
expLifeTimeT[3] = 50
eff[3] = 0.4

# 4 gas
iniCapT[4] = 1000
maxCapT[4] = 50000
rampUpMax[4] = 0.1
rampDownMax[4] = 0.1
variableCostT[4] = 22
fixedCostT[4] = 100
invCostT[4] = 500000
expLifeTimeT[4] = 50
eff[4] = 0.6

# 5 wind
iniCapT[5] = 2000
maxCapT[5] = 20000
rampUpMax[5] = 1
rampDownMax[5] = 1
variableCostT[5] = 0
fixedCostT[5] = 100
invCostT[5] = 1200000
expLifeTimeT[5] = 50
eff[5] = 1

# 6 solar
iniCapT[6] = 80
maxCapT[6] = 15000
rampUpMax[6] = 1
rampDownMax[6] = 1
variableCostT[6] = 0
fixedCostT[6] = 100
invCostT[6] = 800000
expLifeTimeT[6] = 50
eff[6] = 1

# 7 hydro
iniCapT[7] = 3100
maxCapT[7] = 50000
rampUpMax[7] = 0.5
rampDownMax[7] = 0.5
variableCostT[7] = 0
fixedCostT[7] = 100
invCostT[7] = 1000000
expLifeTimeT[7] = 50
eff[7] = 1



for h in Hours
    capFactor[h, 1] = 1
    capFactor[h, 2] = 1
    capFactor[h, 3] = 1
    capFactor[h, 4] = 1
    capFactor[h, 5] = udata[h,5]
    capFactor[h, 6] = udata[h,6]
    capFactor[h, 7] = ((sin((h+3)/5))^2)./2 .+0.3 .+rand(Float64,1)[1]*0.2 #TO BE CONSTRUCTED BETTER
end

#OTHER
proEmisFactor =  Array{Float64}(undef, length(CarbonTech))

for c in CarbonTech
    proEmisFactor[c-1] = 300
end



#STORAGE
chargeMax = Array{Float64}(undef, length(Storage))
dischargeMax = Array{Float64}(undef, length(Storage))
iniCapS = Array{Float64}(undef, length(Storage))
maxCapS = Array{Float64}(undef, length(Storage))
invCostS = Array{Float64}(undef, length(Storage))
expLifeTimeS = Array{Float64}(undef, length(Storage))

for s in Storage
    chargeMax[s] = 40
    dischargeMax[s] = 40
    iniCapS[s] = 500
    maxCapS[s] = 800
    invCostS[s] = 400
    expLifeTimeS[s] = 20
end

# DEMAND
Demand = Array{Float64}(undef, length(Hours))

for h in Hours
    Demand[h] = udata[h,4]
end

#plot(capFactor)
#plot(Demand)
