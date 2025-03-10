-- 1. Give counts of following for the properties for each region, to understand which regions prefer pools and fireplaces
-- Pool Count
SELECT 
    r.regionidzip,
	pl.poolcnt as pool_count, count(*) as num_of_properties
FROM zillow.property_table p
JOIN zillow.region_table r ON p.parcelid = r.parcelid
JOIN zillow.pool_table pl ON p.parcelid = pl.parcelid
GROUP BY r.regionidzip, pl.poolcnt;

-- Fireplace Count
SELECT 
    r.regionidcity,
	bl.fireplacecnt as fire_place_count, count(*) as num_of_properties
FROM zillow.property_table p
JOIN zillow.region_table r ON p.parcelid = r.parcelid
JOIN zillow.building_table bl ON p.parcelid = bl.parcelid
GROUP BY r.regionidcity, bl.fireplacecnt;

-- 2. List Average Property Value for each city, to assess the living expenses 
SELECT 
    r.regionidcity,
    COUNT(*) as total_properties,
    AVG(pr.taxvaluedollarcnt) as avg_property_value
FROM zillow.property_table p
JOIN zillow.region_table r ON p.parcelid = r.parcelid
JOIN zillow.price_table pr ON p.parcelid = pr.parcelid
GROUP BY r.regionidcity
ORDER BY avg_property_value, total_properties;

-- 3. List Average Property Size for each region, what is the trend looking like?
SELECT 
    r.regionidcity,
    COUNT(*) as total_properties,
    AVG(p.calculatedfinishedsquarefeet) as avg_sqft
FROM zillow.property_table p
JOIN zillow.region_table r ON p.parcelid = r.parcelid
WHERE p.yearbuilt IS NOT NULL
GROUP BY r.regionidcity;

-- 4. Find Average price for different property types and find premium property types
SELECT 
    blq.quality_description,
    COUNT(*) as total_properties,
    AVG(pr.taxvaluedollarcnt) as avg_property_value
FROM zillow.property_table p
JOIN zillow.building_quality_table blq ON p.buildingqualitytypeid = blq.buildingqualitytypeid
JOIN zillow.price_table pr ON p.parcelid = pr.parcelid
GROUP BY blq.quality_description;

-- 5. Average Property Tax Rate by County
SELECT 
    r.regionidcounty,
    COUNT(*) as total_properties,
    AVG(pr.taxamount/pr.taxvaluedollarcnt * 100) as avg_tax_rate_percentage
FROM zillow.property_table p
JOIN zillow.region_table r ON p.parcelid = r.parcelid
JOIN zillow.price_table pr ON p.parcelid = pr.parcelid
WHERE pr.taxvaluedollarcnt > 0
GROUP BY r.regionidcounty;

-- 6. What is the average price per square foot for properties by year built (for properties built after 2000)
SELECT 
    p.yearbuilt,
    COUNT(*) as total_properties,
    ROUND(AVG(pr.taxvaluedollarcnt / p.calculatedfinishedsquarefeet), 2) as avg_price_per_sqft
FROM zillow.property_table p
JOIN zillow.price_table pr ON p.parcelid = pr.parcelid
WHERE  
	p.yearbuilt > 2000 
    AND p.calculatedfinishedsquarefeet > 0 
    AND pr.taxvaluedollarcnt > 0
GROUP BY p.yearbuilt
ORDER BY p.yearbuilt DESC;

-- 7. List most popular Heating System Type and Air condition quality type
SELECT 
    "Heating System" as Type,
    h.hs_type AS System_Type,
    COUNT(b.heatingorsystemtypeid) AS Frequency
FROM zillow.building_table b
JOIN zillow.heating_system_quality_table h ON b.heatingorsystemtypeid = h.heatingsystemtypeid
GROUP BY System_Type
UNION ALL
SELECT 
    "AC System" as Type,
    ac.ac_type AS System_Type,
    COUNT(b.airconditioningtypeid) AS Frequency
FROM zillow.building_table b
JOIN zillow.air_conditioning_quality_table ac ON b.airconditioningtypeid = ac.airconditioningtypeid
GROUP BY System_Type;

-- 8. What are the distribution statistics of bedroom and bathroom counts in the building dataset(Min, Q1, Q2, Q3, Max)
WITH RankedRooms AS (
    SELECT 
        bedroomcnt,
        bathroomcnt,
        PERCENT_RANK() OVER (ORDER BY bedroomcnt) as bedroom_pct_rank,
        PERCENT_RANK() OVER (ORDER BY bathroomcnt) as bathroom_pct_rank
    FROM zillow.building_table
    WHERE bedroomcnt IS NOT NULL 
    AND bathroomcnt IS NOT NULL
)
SELECT 
    'Bedroom Count' AS Metric,
    MIN(bedroomcnt) AS Min_Value,
    MIN(CASE WHEN bedroom_pct_rank >= 0.25 THEN bedroomcnt END) AS Q1,
    MIN(CASE WHEN bedroom_pct_rank >= 0.50 THEN bedroomcnt END) AS Q2,
    MIN(CASE WHEN bedroom_pct_rank >= 0.75 THEN bedroomcnt END) AS Q3,
	MAX(bedroomcnt) AS Max_Value
FROM RankedRooms
UNION ALL
SELECT 
    'Bathroom Count' AS Metric,
    MIN(bathroomcnt) AS Min_Value,
    MIN(CASE WHEN bathroom_pct_rank >= 0.25 THEN bathroomcnt END) AS Q1,
    MIN(CASE WHEN bathroom_pct_rank >= 0.50 THEN bathroomcnt END) AS Q2,
    MIN(CASE WHEN bathroom_pct_rank >= 0.75 THEN bathroomcnt END) AS Q3,
    MAX(bathroomcnt) AS Max_Value
FROM RankedRooms;

-- 9. Find number of properties and their average price in the top 5% of their city by price
SELECT 
    regionidcity, 
    COUNT(parcelid) as total_properties,
    AVG(taxvaluedollarcnt) as avg_price
FROM (
    SELECT 
        p.parcelid,
        r.regionidcity,
        pr.taxvaluedollarcnt,
        PERCENT_RANK() OVER (PARTITION BY r.regionidcity 
                            ORDER BY pr.taxvaluedollarcnt) as price_percentile
    FROM zillow.property_table p
    JOIN zillow.region_table r ON p.parcelid = r.parcelid
    JOIN zillow.price_table pr ON p.parcelid = pr.parcelid
) ranked_properties
WHERE price_percentile >= 0.95
GROUP BY regionidcity;

-- 10. Calculate year-over-year price changes for these cities - 96125, 96127 and property type. Consider years from 2000 to 2015
WITH YearlyPrices AS (
    SELECT 
        r.regionidzip,
        p.yearbuilt as year,
        AVG(pr.taxvaluedollarcnt) as avg_price
    FROM zillow.property_table p
    JOIN zillow.region_table r ON p.parcelid = r.parcelid
    JOIN zillow.price_table pr ON p.parcelid = pr.parcelid
    WHERE r.regionidzip in (96127, 96389)
    AND p.yearbuilt between 2000 and 2015
    GROUP BY r.regionidzip, p.yearbuilt
),
PriceChanges AS (
    SELECT 
        yp1.regionidzip,
        yp1.year,
        yp1.avg_price,
        yp1.avg_price - LAG(yp1.avg_price) OVER (
            PARTITION BY yp1.regionidzip ORDER BY yp1.year
        ) as price_change,
        ((yp1.avg_price - LAG(yp1.avg_price) OVER (
            PARTITION BY yp1.regionidzip ORDER BY yp1.year
        )) / LAG(yp1.avg_price) OVER (
            PARTITION BY yp1.regionidzip ORDER BY yp1.year
        ) * 100) as price_change_percent
    FROM YearlyPrices yp1
)
SELECT *
FROM PriceChanges
ORDER BY regionidzip, year;

-- 11. What is the percentage share of properties in each property type for the entire dataset, and how does it rank among other types?
WITH Property_Count AS (
    SELECT 
        p.propertylandusetypeid,
        COUNT(*) AS Property_Count,
        SUM(COUNT(*)) OVER () AS Total_Properties
    FROM 
        zillow.property_table p
    GROUP BY 
        p.propertylandusetypeid
)
SELECT 
    pc.propertylandusetypeid AS Land_Use_Type_ID,
    pc.Property_Count,
    ROUND((pc.Property_Count * 100.0) / pc.Total_Properties, 2) AS Percentage_Share,
    RANK() OVER (ORDER BY pc.Property_Count DESC) AS rank_number
FROM 
    Property_Count pc
ORDER BY 
    rank_number;
    
