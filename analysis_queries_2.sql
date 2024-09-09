USE TravelSafeDatabase;
--1. Create a query which displays flight details, such as, the aircraft code, regular fare, and discounted fare for the first class. 
--A 25% discount is being offered. Label the columns as Aircraft, Regular First-Class fare, and Discounted First Class fare.

SELECT 
	F.ID AS [Flight ID],
    A.Code AS [Aircraft Code],
    AC.Price AS [Regular First-Class fare],
    AC.Price * 0.75 AS [Discounted First Class fare]
FROM 
    Flight AS F
INNER JOIN 
    Aircraft AS A ON F.AircraftID = A.ID
INNER JOIN 
    Airline_Class AS AC ON A.AirlineID = AC.AirlineID
INNER JOIN 
    Class AS C ON AC.ClassID = C.ID
WHERE 
    C.Name = 'First Class';


--2. Create a query which displays the sorted details of flights to given city code with the least duration flight displayed first.

SELECT 
    F.ID AS [Flight ID],
    F.FlightNumber AS [Flight Number],
    AL.Name AS [Airline],
    F.ArrivalCityCode AS [Arrival City Code],
    F.DepartureCityCode AS [Departure City Code],
    F.ArrivalDateTime AS [Arrival Date Time],
	F.AvailableSeats AS [Available Seats],
    F.Duration AS [Duration (mins)]
FROM 
    Flight AS F
INNER JOIN 
    Aircraft AS A ON F.AircraftID = A.ID
INNER JOIN 
	Airline AS AL ON A.AirlineID = AL.ID
WHERE 
    F.ArrivalCityCode = 'LON'  
ORDER BY F.Duration ASC;



--3. Create a query which displays the types of non-vegetarian meals offered on flights.

SELECT 
	F.ID AS [Flight ID],
	AL.Name AS Airline,
	AM.Name AS [Meal Name],
	AM.MealType AS [Meal Type],
	AM.Vegetarian AS [Is Vegetarian]

FROM 
	Flight AS F
INNER JOIN
	Aircraft AS A ON F.AircraftID = A.ID
INNER JOIN
	Airline AS AL ON A.AirlineID = AL.ID
INNER JOIN 
	Airline_Meal AS AM ON AM.AirlineID = AL.ID
WHERE AM.Vegetarian=0;




--4. Create a query which shows the names of countries to which TSI provides flight reservations. Ensure that duplicate country names are eliminated from the list.

SELECT DISTINCT Country 
FROM CityCode;




--5. Create a query which provides, for each airline, the following information:
--The total number of flights scheduled in a given date. Result should contain both detailed breakup & summary for flights for each airline along with overall summary.

--Hint: you may wish to use rollup or cube statements with a query.  Some marks will be awarded for the query structure, even if you cannot generate the totals.

SELECT
    A.Name AS Airline,
    CONVERT(VARCHAR(10), F.DepartureDateTime, 111) AS [Flight Departure Date],
    F.FlightNumber AS [Flight Number],
    COUNT(F.ID) AS [Total Flights]
FROM
    Flight AS F
JOIN
    Aircraft AS AC ON F.AircraftID = AC.ID
JOIN
    Airline AS A ON AC.AirlineID = A.ID
WHERE
    CONVERT(VARCHAR, F.DepartureDateTime, 111) = '2023/07/17'
GROUP BY
    ROLLUP (A.Name, CONVERT(VARCHAR(10), F.DepartureDateTime, 111), F.FlightNumber)
ORDER BY
    GROUPING(A.Name),
    GROUPING(CONVERT(VARCHAR(10), F.DepartureDateTime, 111)),
    GROUPING(F.FlightNumber),
    A.Name,
    CONVERT(VARCHAR(10), F.DepartureDateTime, 111),
    F.FlightNumber;





--6. 
--Airline Statistic Query: Query to generate airline statistics including average flight duration,
--average seat occupancy, average meal price, maximum meal price, average class price and maximum class price for a given airline
SELECT
    AFS.AirlineID AS AirlineID,
    AFS.[Total Flights],
    AFS.[Average Flight Duration (Hour)],
    AFS.[Average Seat Occupancy],
    AMS.[Average Meal Price],
    AMS.[Maximum Meal Price],
    ACS.[Average Class Price],
    ACS.[Maximum Class Price]
FROM
    (
        SELECT 
            A.ID AS AirlineID,
            COUNT(F.ID) AS [Total Flights],
            AVG(DATEDIFF(HOUR, '00:00:00', F.Duration)) AS [Average Flight Duration (Hour)],
            AVG(CAST(F.AvailableSeats AS FLOAT) / CAST(AC.TotalSeats AS FLOAT)) AS [Average Seat Occupancy]
        FROM
            Airline AS A
        LEFT JOIN
            Aircraft AS AC ON AC.AirlineID = A.ID
        LEFT JOIN
            Flight AS F ON AC.ID = F.AircraftID
        GROUP BY 
            A.ID
    ) AS AFS
INNER JOIN
    (
        SELECT 
            A.ID AS AirlineID,
            AVG(AM.Price) AS [Average Meal Price],
            MAX(AM.Price) AS [Maximum Meal Price]
        FROM 
            Airline AS A
        INNER JOIN    
            Airline_Meal AS AM ON AM.AirlineID = A.ID
        GROUP BY 
            A.ID
    ) AS AMS ON AFS.AirlineID = AMS.AirlineID
INNER JOIN
    (
        SELECT 
            A.ID AS AirlineID,
            AVG(AC.Price) AS [Average Class Price],
            MAX(AC.Price) AS [Maximum Class Price]
        FROM 
            Airline AS A
        INNER JOIN    
            Airline_Class AS AC ON AC.AirlineID = A.ID
        GROUP BY 
            A.ID
    ) AS ACS ON AFS.AirlineID = ACS.AirlineID





