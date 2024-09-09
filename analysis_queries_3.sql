use TravelSafeDatabase

--Student 3
--Question 1 
SELECT 
    ArrivalCityCode AS 'Destination City Code',
    MIN(Duration) AS 'Minimum duration',
    MAX(Duration) AS 'Maximum duration',
    AVG(Duration) AS 'Average duration'
FROM 
    Flight
GROUP BY 
    ArrivalCityCode;

--Another version
SELECT 
    MIN(Duration) AS 'Minimum duration',
    MAX(Duration) AS 'Maximum duration',
    AVG(Duration) AS 'Average duration'
FROM 
    Flight
WHERE ArrivalCityCode = 'LON';




--Question 2

SELECT 
	P.FirstName,
	P.LastName,
	RF.ID AS [FlightID],
	F.DepartureDateTime AS [Journey Date],
	R.NumberOfPassengers AS [Number of Booked Seats],
	C.Name AS [Class Name]
FROM
	Passenger AS P
INNER JOIN 
	Reservation_Passenger AS RP ON P.ID = RP.PassengerID
INNER JOIN
	Class AS C ON RP.ClassID = C.ID
INNER JOIN
	Reservation_Flight AS RF ON RF.ID = RP.ReservationFlightID
INNER JOIN
	Flight AS F ON RF.FlightID = F.ID
INNER JOIN 
	Reservation AS R ON RF.ReservationID = R.ID
WHERE P.ID = 1;




--Question 3
Select 
	AM.Name
	,AM.MealType
	,AM.Price
from 
	Airline_Meal as AM
left JOIN 
	Reservation_Meal as RM on AM.ID = RM.MealID
Where
	RM.MealID IS NULL;


--question 4
SELECT
    P.ID,
    P.FirstName,
    P.LastName,
    P.DateOfBirth,
    P.PassportNumber,
    P.Email,
    A.Name AS AirlineName,
    F.DepartureDateTime,
    F.ArrivalDateTime,
    F.DepartureCityCode,
    F.ArrivalCityCode,
	R.TripType
FROM
    Passenger P
JOIN
	Reservation_Passenger as RP on P.ID = RP.PassengerID
JOIN
	Reservation_Flight as RF on RP.ReservationFlightID = RF.ID
JOIN
	Reservation as R on RF.ReservationID = R.ID
JOIN 
	Flight as F on RF.FlightID = F.ID
JOIN
	Aircraft as AC on F.AircraftID = AC.ID
JOIN 
	Airline as A on AC.AirlineID = A.ID
WHERE 
	A.Name = 'SkyTravel' 
	AND CONVERT(date, R.ReservationDate) = '2023-07-16'
	AND R.TripType = 'Multi-City'




--quesiton 5
SELECT 
    A.Name AS AirlineName,
    F.DepartureDateTime AS TravelDate,
    COUNT(RP.PassengerID) AS UnaccompaniedPassengerCount
FROM 
    Airline A
JOIN 
    Aircraft AC ON A.ID = AC.AirlineID
JOIN 
    Flight F ON AC.ID = F.AircraftID
JOIN 
    Reservation_Flight RF ON F.ID = RF.FlightID
JOIN 
    Reservation R ON RF.ReservationID = R.ID
JOIN 
    Reservation_Passenger RP ON RF.ID = RP.ReservationFlightID
JOIN 
    Passenger P ON RP.PassengerID = P.ID
JOIN 
    Reservation_Service RS ON RP.PassengerID = RS.ReservationPassengerID
JOIN 
    Service S ON RS.ServiceID = S.ID
WHERE 
    S.Name = 'Unaccompanied Minor Service'
AND F.DepartureDateTime IS NOT NULL
	AND CAST(F.DepartureDateTime as DATE) = '2023-07-15'
GROUP BY 
    ROLLUP (A.Name, F.DepartureDateTime)
ORDER BY 
    A.Name, F.DepartureDateTime;


--Question 6 this question shows the popularity and total revenue of all the services (Meal, special service) across different ageGroup

WITH ServiceRevenue AS (--with clause is use to create a temporary table that wont be stored in the database.
						--all the query thats done will be shown inside the with temp table
    -- Calculate revenue from meals service
    SELECT 
        ac.CategoryName,
        'Meal' AS ServiceType,
        am.Name AS ServiceName,
        COUNT(*) AS BookingCount,
        SUM(am.Price) AS TotalRevenue
    FROM 
		Reservation_Meal rm
    JOIN 
		Reservation_Passenger rp ON rm.ReservationPassengerID = rp.ID
    JOIN
		Passenger p ON rp.PassengerID = p.ID
    JOIN
		Age_Category ac ON p.AgeCategoryID = ac.ID
    JOIN
		Airline_Meal am ON rm.MealID = am.ID
    GROUP BY 
		ac.CategoryName, am.Name

    UNION ALL --combine the result of 2 select statement

    -- Calculate revenue from other services
    SELECT 
        ac.CategoryName,
        'Other' AS ServiceType,
        s.Name AS ServiceName,
        COUNT(*) AS BookingCount,
        SUM(ARS.Price) AS TotalRevenue
    FROM 
		Reservation_Service rs
    JOIN 
		Reservation_Passenger rp ON rs.ReservationPassengerID = rp.ID
    JOIN 
		Passenger p ON rp.PassengerID = p.ID
    JOIN 
		Age_Category ac ON p.AgeCategoryID = ac.ID
    JOIN 
		Service s ON rs.ServiceID = s.ID
    JOIN 
		Airline_Service as ARS ON rs.ServiceID = ARS.ServiceID
    GROUP BY 
		ac.CategoryName, s.Name
)
SELECT 
*
FROM ServiceRevenue
ORDER BY CategoryName, TotalRevenue DESC;



