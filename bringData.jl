
TransResults = zeros(length(Hours), length(Region), length(Region), 2)
TransExpRestults = zeros(length(Region), length(Region))
AllResults = zeros(length(Hours), length(Tech)+2, length(Region),13)
for h in Hours
    for t in Tech
        for r in Region
            AllResults[h, t, r, 1] = value(EnergyProduction[h, t, r])
            AllResults[h, t, r, 2] = value(AdditionalCapacity[t, r])
            AllResults[h, t, r, 3] = value(StorageLevel[1,h,r])
            AllResults[h, t, r, 5] = value(Charge[1,h,r])
            AllResults[h, t, r, 6] = value(Discharge[1,h,r])
            AllResults[h, length(Tech)+1, r, 1] = value(Discharge[1,h,r])
            AllResults[h, length(Tech)+2, r, 1] = sum(value(Trans[h, r, rr]) for rr in Region) - sum(value(Trans[h, rr, r]) for rr in Region)
            for rr in Region[Region.>1]
                AllResults[h, length(Tech)+1, r, 1] = AllResults[h, length(Tech)+1, r, 1] + value(Trans[h, r, rr])
            end
        end
    end
end

for r in Region
    for rr in Region
        for h in Hours
            TransResults[h,r,rr,1] = value.(Trans[h, r, rr])
            TransResults[h, r, rr,2] = value.(Trans[h, r, rr]) - value.(Trans[h, rr, r])
        end
        TransExpRestults[r,rr] = value.(AdditionalTrans[r,rr])
    end
end
