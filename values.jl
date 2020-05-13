
#Technologies used
# 1 nuclear
# 2 coal slow
# 3 coal fast
# 4 gas
# 5 wind
# 6 solar
# 7 hydro

#LENGTH OF INVESTIGATION
LEN = 7000

################################################################################
# SETS

Tech            = collect(1:7)
CarbonTech      = collect(2:4)
RenewableTech   = collect(5:7)
TechNH          = collect(1:6)
Hours           = collect(1:LEN)
Storage         = collect(1:3)
Region          = collect(1:5)



################################################################################
# IMPORT DATA

usage       = CSV.read("data/usedata.csv") #RENEWABLES NINJA
dema        = CSV.read("data/demandinfinland.csv") #FINGRID (MWh)
locfromend  = 1000


sp      = length(usage[:,1])-length(Hours)-locfromend
ep      = length(usage[:,1])-locfromend
udata   = usage[sp:ep,2:7]

sp      = length(dema[:,1])-length(Hours)-locfromend-1
ep      = length(dema[:,1])-locfromend-1
dem     = dema[sp:ep,5]

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
iniCapT             = Matrix{Float64}(undef, length(Tech), length(Region))
maxCapT             = Matrix{Float64}(undef, length(Tech), length(Region))
capFactor           = zeros(length(Hours), length(Tech), length(Region))
#capFactor = Matrix{Float64}(undef, length(Hours), length(Tech), length(Region))
rampUpMax           = Array{Float64}(undef, length(Tech))
rampDownMax         = Array{Float64}(undef, length(Tech))
variableCostT       = Array{Float64}(undef, length(Tech))
fixedCostT          = Array{Float64}(undef, length(Tech))
invCostT            = Array{Float64}(undef, length(Tech))
expLifeTimeT        = Array{Float64}(undef, length(Tech))
eff                 = Array{Float64}(undef, length(Tech))
hydroMinReservoir   = Array{Float64}(undef, length(Region))
hydroMaxReservoir   = Array{Float64}(undef, length(Region))
hydroReservoirCapacity = Array{Float64}(undef, length(Region))
hydroInflow         = Matrix{Float64}(undef, length(Hours), length(Region))
hydroMinEnvFlow     = Array{Float64}(undef, length(Region))
hydroMaxOverall     = Array{Float64}(undef, length(Region))

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


#REGION RELATED
for r in Region

    # 1 nuclear
    iniCapT[1, r] = 2794
    maxCapT[1,r] = 10000 #random

    # 2 coal slow
    iniCapT[2,r] = 3200
    maxCapT[2,r] = 10000 #not known

    # 3 coal fast #not known
    iniCapT[3,r] = 0
    maxCapT[3,r] = 0

    # 4 gas
    iniCapT[4,r] = 1000 #"wiki"
    maxCapT[4,r] = 50000

    # 5 wind
    iniCapT[5,r] = 2000
    maxCapT[5,r] = 20000

    # 6 solar
    iniCapT[6,r] = 80 #wiki
    maxCapT[6,r] = 15000 #not known

    # 7 hydro
    hydroMinReservoir[r]        = 2000 #TODO
    hydroMaxReservoir[r]        = 8000 #TODO
    hydroReservoirCapacity[r]   = 1000 #TODO
    hydroMinEnvFlow[r]          = 500 #TODO
    hydroMaxOverall[r]          = 3000
    for h in Hours
        hydroInflow[h,r]        = 700 .+rand(Float64,1)[1]*200 #TODO
    end




end

#OTHERS

# 1 nuclear
rampUpMax[1]        = 1 #not known
rampDownMax[1]      = 1 #not known
variableCostT[1]    = 1 #or 37??
fixedCostT[1]       = 200 #not known
invCostT[1]         = 5000000
expLifeTimeT[1]     = 60 #not known
eff[1]              = 0.4

# 2 coal slow
rampUpMax[2]        = 0.1 #not known
rampDownMax[2]      = 0.6 #not known
variableCostT[2]    = 11
fixedCostT[2]       = 100 #not known
invCostT[2]         = 1600000
expLifeTimeT[2]     = 40 #not known
eff[2]              = 0.45

# 3 coal fast #not known
rampUpMax[3]        = 0.1
rampDownMax[3]      = 0.1
variableCostT[3]    = 11
fixedCostT[3]       = 100
invCostT[3]         = 1600000
expLifeTimeT[3]     = 50
eff[3]              = 0.4

# 4 gas
rampUpMax[4] = 0.1 #not known
rampDownMax[4] = 0.1 #not known
variableCostT[4] = 22
fixedCostT[4] = 150 #not known
invCostT[4] = 500000
expLifeTimeT[4] = 40 #not known
eff[4] = 0.6

# 5 wind
rampUpMax[5] = 1 #not known
rampDownMax[5] = 1 #not known
variableCostT[5] = 0 #not known
fixedCostT[5] = 50 #not known
invCostT[5] = 1200000
expLifeTimeT[5] = 30 #not known
eff[5] = 1

# 6 solar
rampUpMax[6] = 1 #not known
rampDownMax[6] = 1 #not known
variableCostT[6] = 0
fixedCostT[6] = 100 #not known
invCostT[6] = 800000
expLifeTimeT[6] = 30 #not known
eff[6] = 1 #not known

# 7 hydro
rampUpMax[7] = 1 #not known
rampDownMax[7] = 1 #not known
variableCostT[7] = 0
fixedCostT[7] = 100 #not known
invCostT[7] = 1000000
expLifeTimeT[7] = 50 #not known
eff[7] = 0.7 #not known


#Capacity factors for generation
for h in Hours
    for r in Region #TODO
        capFactor[h, 1, r] = 1
        capFactor[h, 2, r] = 1
        capFactor[h, 3, r] = 1
        capFactor[h, 4, r] = 1
        capFactor[h, 5, r] = udata[h,5]
        capFactor[h, 6, r] = udata[h,6]
        capFactor[h, 7, r] = ((sin((h+3)/5))^2)./2 .+0.3 .+rand(Float64,1)[1]*0.2 #TO BE CONSTRUCTED BETTER

    end
end

#OTHER
proEmisFactor =  Array{Float64}(undef, length(CarbonTech))

for c in CarbonTech
    proEmisFactor[c-1] = 8.4 #checked
end



#STORAGE
chargeMax       = Array{Float64}(undef, length(Storage))
dischargeMax    = Array{Float64}(undef, length(Storage))
iniCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
maxCapS         = Matrix{Float64}(undef, length(Storage), length(Region))
invCostS        = Array{Float64}(undef, length(Storage))
expLifeTimeS    = Array{Float64}(undef, length(Storage))

for s in Storage
    for r in Region #TODO
        iniCapS[s,r] = 800
        maxCapS[s,r] = 1000
    end
    chargeMax[s] = 500
    dischargeMax[s] = 800
    invCostS[s]     = 40000
    expLifeTimeS[s] = 20
end

# DEMAND
Demand = Matrix{Float64}(undef, length(Hours), length(Region))

for h in Hours
    for r in Region
        Demand[h, r] = udata[h,4] #TODO
    end

end

transCap = Matrix{Float64}(undef, length(Region), length(Region))
maxTransCap = Matrix{Float64}(undef, length(Region), length(Region))
transLen = Matrix{Float64}(undef, length(Region), length(Region))
for r in Region
    for rr in Region
        if rr == r
            transCap[r, rr]     = 0
            maxTransCap[r,rr]   = 0
            transLen[r, rr]     = 0
         else
            transCap[r, rr]     = 500
            maxTransCap[r,rr]   = 700
            transLen[r, rr]     = 500
        end
    end
end

transInvCost = 30
transCost    = 5



#plot(capFactor)
#plot(Demand)
