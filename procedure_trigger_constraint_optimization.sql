USE TravelSafeDatabase;

-- CONSTRAINT
-- Ensures valid flight timing and duration constraints
ALTER TABLE Flight
ADD CONSTRAINT CK_Flight_TimingAndDuration 
CHECK (
    DepartureDateTime < ArrivalDateTime AND
    DATEDIFF(MINUTE, DepartureDateTime, ArrivalDateTime) = Duration AND
    DATEPART(HOUR, DepartureDateTime) BETWEEN 0 AND 23 AND
    DATEPART(MINUTE, DepartureDateTime) BETWEEN 0 AND 59 AND
    DATEPART(HOUR, ArrivalDateTime) BETWEEN 0 AND 23 AND
    DATEPART(MINUTE, ArrivalDateTime) BETWEEN 0 AND 59 AND
    Duration > 0 AND
    Duration <= 1440 -- Ensures that the duration is within a day
);

--Airline Meal Constraint

ALTER TABLE Airline_Meal ADD CONSTRAINT CK_AirlineMeal_MealType CHECK (MealType IN ('Refreshment', 'Single meal', 'Multi meal', 'Special meal'));


--Reservation Passenger Constraint
ALTER TABLE Reservation_Passenger ADD CONSTRAINT CK_ReservationPassenger_TravelType CHECK (TravelType IN ('InLap', 'InSeat'));






--STORED PROCEDURE

--1. procdure to calculate total reservation price
CREATE PROCEDURE GetReservationTotalPrice
    (@ReservationID INT,
	@TotalPrice DECIMAL(10, 2) OUT)
AS
BEGIN
    WITH CTE AS (
        SELECT 
            R.ID AS ReservationID,
            RF.ID AS ReservationFlightID,
            RP.ID AS ReservationPassengerID,
            RAB.ID AS ReservationAddBaggageID,
            ACB.Price AS AdditionalBaggagePrice,
            AGC.Price AS AgeCategoryPrice,
            C.Name AS ClassName,
            ALC.Price AS ClassPrice,
            RS.ID AS ReservationServiceID,
            ASE.Price AS ServicePrice,
            RM.ID AS ReservationMealID,
            AM.Price AS MealPrice,
            ROW_NUMBER() OVER(PARTITION BY RP.ID, RS.ID ORDER BY RP.ID) AS RowNum
        FROM Reservation AS R
        INNER JOIN Reservation_Flight AS RF ON R.ID = RF.ReservationID
        INNER JOIN Flight AS F ON RF.FlightID = F.ID
        INNER JOIN Aircraft AS A ON F.AircraftID = A.ID
        INNER JOIN Airline AS AL ON A.AirlineID = AL.ID
        INNER JOIN Reservation_Additional_Baggage AS RAB ON RAB.ReservationFlightID = RF.ID
        INNER JOIN Additional_Checked_Baggage AS ACB ON RAB.AdditionalBaggageID = ACB.ID AND ACB.AirlineID = AL.ID
        INNER JOIN Reservation_Passenger AS RP ON RF.ID = RP.ReservationFlightID
        INNER JOIN Passenger AS P ON RP.PassengerID = P.ID
        INNER JOIN Age_Category AS AC ON P.AgeCategoryID = AC.ID
        INNER JOIN Airline_Age_Category AS AGC ON AC.ID = AGC.CategoryID AND AL.ID=AGC.AirlineID
        INNER JOIN Class AS C ON RP.ClassID = C.ID
        INNER JOIN Airline_Class AS ALC ON ALC.ClassID = C.ID AND ALC.AirlineID = AL.ID
        LEFT JOIN Reservation_Meal AS RM ON RP.ID = RM.ReservationPassengerID
        LEFT JOIN Airline_Meal AS AM ON RM.MealID = AM.ID
        LEFT JOIN Reservation_Service AS RS ON RP.ID = RS.ReservationPassengerID
        LEFT JOIN Service AS SE ON RS.ServiceID = SE.ID
        LEFT JOIN Airline_Service AS ASE ON ASE.ServiceID = SE.ID AND ASE.AirlineID = AL.ID
        WHERE R.ID = @ReservationID
    )
    

    SELECT @TotalPrice=SUM(FlightTotal) 
    FROM (
        SELECT 
            ReservationPassengerTable.ReservationID AS ReservationID, 
            ReservationPassengerTable.ReservationFlightID as ReservationFlightID, 
            SUM(AgeTotal) + SUM(ClassTotal) + SUM(TotalServicePrice) + SUM(TotalMealPrice) + MAX(AdditionalBaggagePrice) AS FlightTotal
        FROM (
            SELECT 
                ReservationID,
                ReservationFlightID,
                ReservationPassengerID,
                SUM(DISTINCT AgeCategoryPrice) AS AgeTotal,
                SUM(DISTINCT ClassPrice) AS ClassTotal,
                SUM(ServicePrice) AS TotalServicePrice,
                SUM(MealPrice) AS TotalMealPrice,
                MAX(AdditionalBaggagePrice) AdditionalBaggagePrice
            FROM CTE
            WHERE RowNum = 1
            GROUP BY ReservationID, ReservationFlightID, ReservationPassengerID
        ) AS ReservationPassengerTable
        GROUP BY ReservationPassengerTable.ReservationID, ReservationPassengerTable.ReservationFlightID
    ) AS ReservationTable
    GROUP BY ReservationTable.ReservationID;
END

DECLARE @Total DECIMAL(10, 2);
EXEC GetReservationTotalPrice @ReservationID = 1, @TotalPrice = @Total OUTPUT;
SELECT @Total AS TotalReservationPrice;


--2. Procedure to process payment and issue tickets

CREATE PROCEDURE ProcessPaymentAndIssueTickets
    @ReservationID INT,
    @Amount DECIMAL(10, 2),
    @PaymentMethod VARCHAR(50)
AS
BEGIN
    DECLARE @ReservationStatus VARCHAR(10);
    DECLARE @ReservationPassengerID INT;

    BEGIN TRANSACTION;

    -- Check current status of the reservation
    SELECT @ReservationStatus = Status FROM Reservation WHERE ID = @ReservationID;
    IF @ReservationStatus = 'Pending'
		BEGIN
			-- Add a payment record
			INSERT INTO Payment (ReservationID, Amount, PaymentDate)
			VALUES (@ReservationID, @Amount, GETDATE());

			-- Update reservation status to 'Confirmed'
			UPDATE Reservation
			SET Status = 'Confirmed'
			WHERE ID = @ReservationID;

			-- Issue tickets for all passengers on each flight linked to the reservation
			DECLARE TicketCursor CURSOR FOR
			SELECT ID FROM Reservation_Passenger WHERE ReservationFlightID IN 
				(SELECT ID FROM Reservation_Flight WHERE ReservationID = @ReservationID);

			OPEN TicketCursor;
			FETCH NEXT FROM TicketCursor INTO @ReservationPassengerID;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert ticket for each passenger-flight combination (assuming seat allocation handled separately)
				INSERT INTO Ticket (ReservationPassengerID, CheckInStatus, SeatNumber)
				VALUES (@ReservationPassengerID, 0, 'Not Assigned');  -- Seat number can be assigned later

				FETCH NEXT FROM TicketCursor INTO @ReservationPassengerID;
			END;

			CLOSE TicketCursor;
			DEALLOCATE TicketCursor;
		END
    ELSE
		BEGIN
			RAISERROR('Cannot process payment for non-pending reservation.', 16, 1);
		END

    COMMIT TRANSACTION;
END;


--test the procedure
EXEC ProcessPaymentAndIssueTickets @ReservationID = 1, @Amount = 1500, @PaymentMethod='Credit Card';



--3. Procedure to Cancel Reservation

CREATE PROCEDURE CancelReservation
    @ReservationID INT,
    @CancellationDate DATETIME
AS
BEGIN
    DECLARE @EarliestFlightTime DATETIME;
    DECLARE @PassengerID INT;
    DECLARE @RefundAmount DECIMAL(10, 2);
    DECLARE @TotalAmount DECIMAL(10, 2);

    -- Get the earliest flight time for the reservation
    SELECT TOP 1 @EarliestFlightTime = f.DepartureDateTime
    FROM Flight f
    INNER JOIN Reservation_Flight rf ON f.ID = rf.FlightID
    WHERE rf.ReservationID = @ReservationID
    ORDER BY f.DepartureDateTime ASC;

    IF @EarliestFlightTime IS NULL
    BEGIN
        RAISERROR('No flights found for the given reservation.', 16, 1);
        RETURN;
    END;

    -- Get the total amount for the reservation
    SELECT @TotalAmount = Amount 
    FROM Payment 
    WHERE ReservationID = @ReservationID;

    -- Perform cancellation
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Insert into Cancellation table
        INSERT INTO Cancellation (ReservationID, CancellationDate)
        VALUES (@ReservationID, @CancellationDate);

        -- Update the reservation status to 'Cancelled'
        UPDATE Reservation
        SET Status = 'Cancelled'
        WHERE ID = @ReservationID;

        -- If cancellation is more than 24 hours before the earliest flight, provide a refund
		IF DATEDIFF(HOUR, @CancellationDate, @EarliestFlightTime) < 24 PRINT 'Sorry, Refund will not be provided'

        IF DATEDIFF(HOUR, @CancellationDate, @EarliestFlightTime) >= 24 
        BEGIN
            DECLARE @CancellationID INT;
            SET @CancellationID = SCOPE_IDENTITY();

            -- Use the total amount as the refund amount
            SET @RefundAmount = @TotalAmount;

            -- Get the PassengerID from the Reservation
            SELECT @PassengerID = ReservationMadeBy
            FROM Reservation 
            WHERE ID = @ReservationID;

            -- Insert into Cancellation_Refund table
            INSERT INTO Cancellation_Refund (CancellationID, PassengerID, Amount, ExpirationDate)
            VALUES (@CancellationID, @PassengerID, @RefundAmount, DATEADD(YEAR, 1, @CancellationDate));

			--Update the passenger's credit balance
			UPDATE Credit_Account
			SET Balance = Balance + @RefundAmount;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

--test the procedure
EXEC CancelReservation @ReservationID = 1, @CancellationDate = '2023-06-15 08:00:00.000';




--Trigger

--This trigger ensures that any modification to the FlightID in the Reservation_Flight table
--does not change the flight's arrival and departure locations and that the new flight times are within one year of the original dates.

CREATE TRIGGER trg_CheckFlightModification
ON Reservation_Flight
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(FlightID)
    BEGIN
        DECLARE @OldFlightID INT = (SELECT FlightID FROM deleted);
        DECLARE @NewFlightID INT = (SELECT FlightID FROM inserted);

        -- Check if the new flight has the same departure and arrival destinations
        IF NOT EXISTS (
            SELECT * FROM Flight fOld
            JOIN Flight fNew ON 
                fOld.DepartureCityCode = fNew.DepartureCityCode AND
                fOld.ArrivalCityCode = fNew.ArrivalCityCode
            WHERE fOld.ID = @OldFlightID AND fNew.ID = @NewFlightID
        )
        BEGIN
            RAISERROR ('Flight modification error: Departure and Arrival locations must remain the same.', 16, 1);
            ROLLBACK TRANSACTION;
        END

        -- Check if the new flight times are within one year of the original flight times
        IF NOT EXISTS (
            SELECT * FROM Flight fOld
            JOIN Flight fNew ON 
                DATEDIFF(YEAR, fOld.DepartureDateTime, fNew.DepartureDateTime) BETWEEN -1 AND 1 AND
                DATEDIFF(YEAR, fOld.ArrivalDateTime, fNew.ArrivalDateTime) BETWEEN -1 AND 1
            WHERE fOld.ID = @OldFlightID AND fNew.ID = @NewFlightID
        )
        BEGIN
            RAISERROR ('Flight modification error: New flight times must be within one year of the original times.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;

--TESTING THE TRIGGER

UPDATE Reservation_Flight
SET FlightID = 1
WHERE ID = 1;




--2. This trigger will check the maximum allowed passengers for a flight when a new passenger
--is added to a reservation and prevent the addition if the maximum is reached.
CREATE TRIGGER trg_CheckMaxPassengers
ON Reservation_Flight
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables
    DECLARE @ReservationID INT;
    DECLARE @FlightID INT;
    DECLARE @AirlineID INT;
    DECLARE @MaxPassengers INT;
    DECLARE @CurrentPassengers INT;

    -- Fetch ReservationID and FlightID from the inserted record in Reservation_Flight
    SELECT @ReservationID = ReservationID, @FlightID = FlightID
    FROM inserted;

    -- Get the total number of passengers associated with the reservation
    SELECT @CurrentPassengers = NumberOfPassengers
    FROM Reservation
    WHERE ID = @ReservationID;

    -- Get AirlineID and the maximum number of passengers allowed from the related Flight and Airline
    SELECT @AirlineID = A.ID, @MaxPassengers = A.MaxPassengersPerBooking
    FROM Airline A
    JOIN Aircraft AC ON A.ID = AC.AirlineID
    JOIN Flight F ON AC.ID = F.AircraftID
    WHERE F.ID = @FlightID;

    -- Check if the current number of passengers exceeds the maximum allowed
    IF @CurrentPassengers > @MaxPassengers
    BEGIN
        RAISERROR ('Cannot add more passengers. Maximum capacity reached for airline ID %d.', 16, 1, @AirlineID);
        ROLLBACK TRANSACTION;
    END
END;


--test the trigger

INSERT INTO Reservation (ReservationDate, Status, TripType, ReservationMadeBy, NumberOfPassengers)
VALUES ('2023-01-01 08:00:00', 'Confirmed', 'RoundTrip', NULL, 6); 

INSERT INTO Reservation_Flight (ReservationID, FlightID)
VALUES (4, 1);



--3. trigger to update seats count on reservation cancellationa 
CREATE TRIGGER trg_UpdateAvailableSeatsOnReservationCancellation
ON Reservation
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
	-- Check if the reservation status was updated to 'Cancelled'
	 IF UPDATE(Status) AND EXISTS (
			SELECT 1 FROM inserted WHERE Status = 'Cancelled'
		)
    BEGIN
        DECLARE @FlightPassengerCounts TABLE (FlightID INT, PassengerCount INT);
        DECLARE @ReservationID INT;
		--get the reservation id
		SELECT @ReservationID=ID FROM inserted;

		-- Insert passenger counts by flight into the temporary table
		INSERT INTO @FlightPassengerCounts (FlightID, PassengerCount)
        SELECT Reservation_Flight.FlightID, COUNT(Reservation_Passenger.ID) AS PassengerCount
        FROM Reservation_Flight
        JOIN Reservation_Passenger ON Reservation_Flight.ID = Reservation_Passenger.ReservationFlightID
        WHERE Reservation_Flight.ReservationID = @ReservationID
        GROUP BY Reservation_Flight.FlightID;

		
        -- Update available seats in the Flight table
        UPDATE Flight
        SET AvailableSeats = AvailableSeats + fp.PassengerCount
        FROM Flight
        JOIN @FlightPassengerCounts fp ON Flight.ID = fp.FlightID
        WHERE AvailableSeats >= fp.PassengerCount;
	END
END


--testing the trigger
UPDATE Reservation
SET Status='Cancelled'
WHERE ID=1;



--OPTIMIZATION
USE TravelSafeDatabaseCopy;


--STRATEGY 1: HORIZONTAL PARTITIONING
--Query tested: Query to get the details of flights to 'City101' for the current year


--test on unparitioned partitioned table
SET STATISTICS TIME ON;
SELECT *
FROM Flight f
JOIN CityCode cc ON f.DepartureCityCode = cc.Code
WHERE YEAR(f.DepartureDateTime) = YEAR(GETDATE()) 
AND cc.CityName = 'City101'; 
SET STATISTICS TIME OFF;


--partitioning process to partition current and previous years data into separate tables
CREATE TABLE Flight_CurrentYear (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AircraftID INT,
    FlightNumber VARCHAR(20) NOT NULL,
    DepartureCityCode VARCHAR(10),
    ArrivalCityCode VARCHAR(10),
    DepartureDateTime DATETIME NOT NULL,
    ArrivalDateTime DATETIME NOT NULL,
    Duration INT NOT NULL,
    AvailableSeats INT NOT NULL CHECK (AvailableSeats >= 0),
    CONSTRAINT FK_Flight_CurrentYear_Aircraft FOREIGN KEY (AircraftID) REFERENCES Aircraft(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_Flight_CurrentYear_DepartureCityCode FOREIGN KEY (DepartureCityCode) REFERENCES CityCode(Code) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Flight_CurrentYear_ArrivalCityCode FOREIGN KEY (ArrivalCityCode) REFERENCES CityCode(Code) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE Flight_History (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AircraftID INT,
    FlightNumber VARCHAR(20) NOT NULL,
    DepartureCityCode VARCHAR(10),
    ArrivalCityCode VARCHAR(10),
    DepartureDateTime DATETIME NOT NULL,
    ArrivalDateTime DATETIME NOT NULL,
    Duration INT NOT NULL,
    AvailableSeats INT NOT NULL CHECK (AvailableSeats >= 0),
    CONSTRAINT FK_Flight_History_Aircraft FOREIGN KEY (AircraftID) REFERENCES Aircraft(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_Flight_History_DepartureCityCode FOREIGN KEY (DepartureCityCode) REFERENCES CityCode(Code) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Flight_History_ArrivalCityCode FOREIGN KEY (ArrivalCityCode) REFERENCES CityCode(Code) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- Insert data into the partitioned tables
INSERT INTO Flight_CurrentYear (AircraftID, FlightNumber, DepartureCityCode, ArrivalCityCode, DepartureDateTime, ArrivalDateTime, Duration, AvailableSeats)
SELECT AircraftID, FlightNumber, DepartureCityCode, ArrivalCityCode, DepartureDateTime, ArrivalDateTime, Duration, AvailableSeats
FROM Flight
WHERE YEAR(DepartureDateTime) = YEAR(GETDATE());

INSERT INTO Flight_History (AircraftID, FlightNumber, DepartureCityCode, ArrivalCityCode, DepartureDateTime, ArrivalDateTime, Duration, AvailableSeats)
SELECT AircraftID, FlightNumber, DepartureCityCode, ArrivalCityCode, DepartureDateTime, ArrivalDateTime, Duration, AvailableSeats
FROM Flight
WHERE YEAR(DepartureDateTime) <> YEAR(GETDATE());




--test on partitioned table
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT f.*
FROM Flight_CurrentYear f
JOIN CityCode cc ON f.DepartureCityCode = cc.Code
WHERE  cc.CityName = 'City101';
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;





--STRATEGY 2: CACHING THROUGH MATERIALIZED VIEWS
--2. CACHING
--Tested query;  Query to retrieve number of flights per airline for a given year

--test without caching

SET STATISTICS IO ON
SET STATISTICS TIME ON
SELECT 
    a.Name as AirlineName,
    COUNT(f.ID) as TotalFlights
FROM 
    Airline a
JOIN 
    Aircraft ac ON a.ID = ac.AirlineID
JOIN 
    Flight f ON ac.ID = f.AircraftID
WHERE 
    YEAR(f.DepartureDateTime) = YEAR(GETDATE())
GROUP BY 
    a.Name;
SET STATISTICS IO OFF
SET STATISTICS TIME OFF







--test after caching

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
-- Create the view with SCHEMABINDING
CREATE VIEW dbo.AirlineFlightCounts
WITH SCHEMABINDING
AS
SELECT 
    a.Name AS AirlineName,
    COUNT_BIG(*) AS TotalFlights
FROM 
    dbo.Airline a
JOIN 
    dbo.Aircraft ac ON a.ID = ac.AirlineID
JOIN 
    dbo.Flight f ON ac.ID = f.AircraftID
WHERE 
    YEAR(f.DepartureDateTime) = YEAR(GETDATE())
GROUP BY 
    a.Name;
GO

-- Create a unique clustered index on the view
CREATE UNIQUE CLUSTERED INDEX idx_AirlineName ON dbo.AirlineFlightCounts (AirlineName);
GO

-- Query the indexed view
SELECT * FROM dbo.AirlineFlightCounts;
GO


SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


--STRATEGY 3: Optimization Technique: Non-Clustered Index


-- Query to find passenger name, date of birth and email for those matching a passport number pattern without indiex

--without indexing.
SET STATISTICS IO ON
SET STATISTICS TIME ON
SELECT P.FirstName, P.LastName, P.DateOfBirth, P.Email, P.PassportNumber FROM Passenger AS P
WHERE PassportNumber LIKE ('P1%')
SET STATISTICS IO OFF
SET STATISTICS TIME OFF

--USING INDEXING

CREATE INDEX idx_passenger_passport ON Passenger(PassportNumber);


SET STATISTICS IO ON
SET STATISTICS TIME ON
SELECT * FROM Passenger
WHERE PassportNumber LIKE ('P1%');
SET STATISTICS IO OFF
SET STATISTICS TIME OFF


--STRATEGY 4: Denormalization

--before denormalization
--sample query to test: Query which displays the types of non-vegetarian meals offered on flights.

SET STATISTICS IO ON
SET STATISTICS TIME ON
SELECT 
	F.ID AS FlightID,
	F.FlightNumber,
	F.DepartureCityCode,
	F.ArrivalCityCode,
	F.DepartureDateTime,
	F.ArrivalDateTime,
	AL.Name AS Airline,
	AM.MealType,
	AM.Vegetarian

FROM 
	Flight AS F
INNER JOIN
	Aircraft AS A ON F.AircraftID = A.ID
INNER JOIN
	Airline AS AL ON A.AirlineID = AL.ID
INNER JOIN 
	Airline_Meal AS AM ON AM.AirlineID = AL.ID
WHERE AM.Vegetarian=0;
SET STATISTICS IO OFF
SET STATISTICS TIME OFF


--denormalization
-- using the Duplicating FK attributes in 1:* relationship to reduce joins technique

ALTER TABLE Flight
ADD AirlineID INT;

ALTER TABLE Flight
ADD CONSTRAINT FK_Flight_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID)
ON DELETE NO ACTION
ON UPDATE NO ACTION;


UPDATE Flight
SET AirlineID = (
    SELECT Aircraft.AirlineID
    FROM Aircraft
    WHERE Aircraft.ID = Flight.AircraftID
);




--after denormalization

SET STATISTICS IO ON
SET STATISTICS TIME ON
SELECT 
	F.ID AS FlightID,
	F.FlightNumber,
	F.DepartureCityCode,
	F.ArrivalCityCode,
	F.DepartureDateTime,
	F.ArrivalDateTime,
	AL.Name AS Airline,
	AM.MealType,
	AM.Vegetarian

FROM 
	Flight AS F
INNER JOIN
	Airline AS AL ON F.AirlineID = AL.ID
INNER JOIN 
	Airline_Meal AS AM ON AM.AirlineID = AL.ID
WHERE AM.Vegetarian=0;
SET STATISTICS IO OFF
SET STATISTICS TIME OFF