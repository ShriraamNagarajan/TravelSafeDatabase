-- i.	Create a query which shows direct flights only for given dates, origin & destination.	

SELECT 
    F.FlightNumber, 
    A.Name AS Airline, 
    F.DepartureCityCode, 
    F.ArrivalCityCode, 
    F.DepartureDateTime, 
    F.ArrivalDateTime, 
    F.Duration, 
    F.AvailableSeats
FROM 
    Flight F
JOIN 
    Airline A ON F.AircraftID = A.ID
WHERE 
    F.DepartureCityCode = 'NYC'
    AND F.ArrivalCityCode = 'LON'
    AND F.DepartureDateTime >= '2023-07-15 00:00:00'
    AND F.DepartureDateTime <= '2023-07-15 23:59:59'
ORDER BY 
    F.DepartureDateTime;



-- ii

SELECT 
    AirlineID, 
    AircraftCode, 
	ClassID,
    ClassName,
    SUM(ExpectedClassRevenue) AS ExpectedRevenue
FROM (
    SELECT 
        AL.ID AS AirlineID,
        A.Code AS AircraftCode,
        C.Name AS ClassName, 
		C.ID AS ClassID,
        CASE 
            WHEN C.Name = 'First Class' THEN AC.Price * A.FirstClassSeats
            WHEN C.Name = 'Business' THEN AC.Price * A.BusinessClassSeats
            WHEN C.Name = 'Economy' THEN AC.Price * A.EconomyClassSeats
            ELSE 0
        END AS ExpectedClassRevenue
    FROM 
        Aircraft AS A
    INNER JOIN 
        Airline AS AL ON A.AirlineID = AL.ID
    INNER JOIN 
        Airline_Class AS AC ON AL.ID = AC.AirlineID
    INNER JOIN 
        Class AS C ON C.ID = AC.ClassID
) AS RevenuePerClass
GROUP BY 
    ROLLUP(AirlineID, AircraftCode, ClassName, ClassID)



-- iii

SELECT 
	P.ID AS PassengerID,
	P.FirstName + ' ' + P.LastName AS PassengerName,
	AL.ID AS AirlineID,
	AL.Name AS AirlineName,
	F.FlightNumber,
	R.ID AS ReservationID,
	R.Status AS ReservationStatus
FROM 
	Passenger P
JOIN
	Reservation_Passenger RP ON P.ID = RP.PassengerID
JOIN
	Reservation_Flight RF ON RP.ReservationFlightID = RF.ID
INNER JOIN
	Reservation R ON RF.ReservationID = R.ID
INNER JOIN
	Flight F ON RF.FlightID = F.ID
INNER JOIN
	Aircraft A ON F.AircraftID = A.ID
INNER JOIN
	Airline AL ON A.AirlineID = AL.ID
WHERE AL.ID=1;

-- iv

SELECT 
    TOP 1 A.Name AS AirlineName,
    COUNT(RF.FlightID) AS NumberOfFlights
FROM 
    Reservation_Flight RF
JOIN 
    Flight F ON RF.FlightID = F.ID
JOIN 
    Aircraft AC ON F.AircraftID = AC.ID
JOIN 
    Airline A ON AC.AirlineID = A.ID
WHERE 
    F.DepartureCityCode = 'NYC'
    AND F.ArrivalCityCode = 'LON'
    AND F.DepartureDateTime BETWEEN '2023-07-01' AND '2023-07-31'
GROUP BY 
    A.Name
ORDER BY 
    COUNT(RF.ID) DESC;

-- v

SELECT 
    CASE 
        WHEN GROUPING(AC.CategoryName) = 1 THEN 'All Categories'
        ELSE AC.CategoryName
    END AS AgeCategory,
    COUNT(P.ID) AS NumberOfPassengers
FROM 
    Reservation_Passenger RP
JOIN 
    Reservation_Flight RF ON RP.ReservationFlightID = RF.ID
JOIN 
    Flight F ON RF.FlightID = F.ID
JOIN 
    Aircraft ACR ON F.AircraftID = ACR.ID
JOIN 
    Airline AL ON ACR.AirlineID = AL.ID
JOIN 
    Passenger P ON RP.PassengerID = P.ID
RIGHT JOIN 
    Age_Category AC ON P.AgeCategoryID = AC.ID
WHERE 
    (AL.ID = 1
    AND F.FlightNumber = 'AF100'
    AND CAST(F.DepartureDateTime AS DATE) = '2023-07-15 08:00:00.000') 
OR AL.ID IS NULL
GROUP BY 
    ROLLUP(AC.CategoryName)
ORDER BY 
    GROUPING(AC.CategoryName), AC.CategoryName;


--vi calculates the total revenue generated from ticket sales for each age category

SELECT 
    AC.CategoryName,
    ISNULL(SUM(AP.Price), 0) AS TotalRevenue
FROM 
    Age_Category AC
LEFT JOIN 
     Passenger P ON P.AgeCategoryID = AC.ID
LEFT JOIN 
    Reservation_Passenger RP ON RP.PassengerID = P.ID
LEFT JOIN 
    Reservation_Flight RF ON RP.ReservationFlightID = RF.ID
LEFT JOIN 
    Flight F ON RF.FlightID = F.ID
LEFT JOIN 
    Aircraft ACR ON F.AircraftID = ACR.ID
LEFT JOIN 
    Airline AL ON ACR.AirlineID = AL.ID
LEFT JOIN 
    Airline_Age_Category AP ON AP.CategoryID = AC.ID AND AP.AirlineID = AL.ID

GROUP BY 
    AC.CategoryName
