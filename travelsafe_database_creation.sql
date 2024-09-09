CREATE DATABASE TravelSafeDatabase;
USE TravelSafeDatabase;

CREATE TABLE Age_Category (
    ID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName VARCHAR(10) NOT NULL,
    MinAge INT NOT NULL,
    MaxAge INT
);


CREATE TABLE Passenger (
    ID INT PRIMARY KEY IDENTITY(1,1),
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    PassportNumber VARCHAR(20) NOT NULL UNIQUE,
    Email VARCHAR(100) NOT NULL,
    AgeCategoryID INT,
    CONSTRAINT FK_Passenger_AgeCategory FOREIGN KEY (AgeCategoryID) REFERENCES Age_Category(ID) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE Airline (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(100) NOT NULL,
	Country VARCHAR(50) NOT NULL,
    RestrictUnder12TravelAlone BIT NOT NULL,
    MaxPassengersPerBooking INT
);

CREATE TABLE Aircraft (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AirlineID INT,
    Code VARCHAR(50) NOT NULL,
    TotalSeats INT NOT NULL,
	FirstClassSeats INT NOT NULL,
    BusinessClassSeats INT NOT NULL,
    EconomyClassSeats INT NOT NULL,
    CONSTRAINT FK_Aircraft_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE CityCode (
    Code VARCHAR(10) PRIMARY KEY,
    CityName VARCHAR(50) NOT NULL,
    Country VARCHAR(50) NOT NULL
);




CREATE TABLE Flight (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AircraftID INT,
    FlightNumber VARCHAR(20) NOT NULL,
	DepartureCityCode VARCHAR(10),
    ArrivalCityCode VARCHAR(10),
    DepartureDateTime DATETIME NOT NULL,
    ArrivalDateTime DATETIME NOT NULL,
    Duration INT NOT NULL,
    AvailableSeats INT NOT NULL,
    CONSTRAINT FK_Flight_Aircraft FOREIGN KEY (AircraftID) REFERENCES Aircraft(ID) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT FK_Flight_DepartureCityCode FOREIGN KEY (DepartureCityCode) REFERENCES CityCode(Code) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Flight_ArrivalCityCode FOREIGN KEY (ArrivalCityCode) REFERENCES CityCode(Code) ON DELETE NO ACTION ON UPDATE NO ACTION,
);

CREATE TABLE Class (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(20) NOT NULL,
    Description TEXT
);

CREATE TABLE Airline_Class (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AirlineID INT,
    ClassID INT,
    Price DECIMAL(10, 2) NOT NULL,
	CarryOnWeightLimit DECIMAL(5, 2) NOT NULL,
    CheckedWeightLimit DECIMAL(5, 2) NOT NULL,
    CONSTRAINT FK_AirlineClass_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_AirlineClass_Class FOREIGN KEY (ClassID) REFERENCES Class(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Airline_Meal (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AirlineID INT,
	Name VARCHAR(50) NOT NULL,
    MealType VARCHAR(15) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    Vegetarian BIT NOT NULL,
    CONSTRAINT FK_AirlineMeal_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Service (
    ID INT PRIMARY KEY IDENTITY(1,1),
    Name VARCHAR(50) NOT NULL,
    Description TEXT
);

CREATE TABLE Airline_Service (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AirlineID INT,
    ServiceID INT,
    Price DECIMAL(10, 2) NOT NULL,
    CONSTRAINT FK_AirlineService_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_AirlineService_Service FOREIGN KEY (ServiceID) REFERENCES Service(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Airline_Age_Category(
    ID INT PRIMARY KEY IDENTITY(1,1),
    AirlineID INT,
    CategoryID INT,
    Price DECIMAL(7, 2) NOT NULL,
    CONSTRAINT FK_AirlineAgeCategory_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_AirlineAgeCategory_AgeCategory FOREIGN KEY (CategoryID) REFERENCES Age_Category(ID) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE Additional_Checked_Baggage (
    ID INT PRIMARY KEY IDENTITY(1,1),
    AirlineID INT,
    BaggageLimit DECIMAL(5, 2) NOT NULL,
    Price DECIMAL(7, 2) NOT NULL,
    CONSTRAINT FK_AdditionalBaggage_Airline FOREIGN KEY (AirlineID) REFERENCES Airline(ID)
);


CREATE TABLE Reservation (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationDate DATETIME NOT NULL,
    Status VARCHAR(10) NOT NULL,
    TripType VARCHAR(10) NOT NULL,
    ReservationMadeBy INT,
    NumberOfPassengers INT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Reservation_ReservationMadeBy FOREIGN KEY (ReservationMadeBy) REFERENCES Passenger(ID)
);

CREATE TABLE Reservation_Flight (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationID INT,
    FlightID INT,
    CONSTRAINT FK_ReservationFlight_Reservation FOREIGN KEY (ReservationID) REFERENCES Reservation(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ReservationFlight_Flight FOREIGN KEY (FlightID) REFERENCES Flight(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Reservation_Passenger (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationFlightID INT,
    PassengerID INT,
	ClassID INT,
    TravelType VARCHAR(10) NOT NULL DEFAULT 'InSeat',
    CONSTRAINT FK_ReservationPassenger_ReservationFlight FOREIGN KEY (ReservationFlightID) REFERENCES Reservation_Flight(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ReservationPassenger_Passenger FOREIGN KEY (PassengerID) REFERENCES Passenger(ID) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT FK_ReservationPassenger_Class FOREIGN KEY (ClassID) REFERENCES Class(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Reservation_Service (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationPassengerID INT,
    ServiceID INT,
    CONSTRAINT FK_ReservationService_ReservationPassenger FOREIGN KEY (ReservationPassengerID) REFERENCES Reservation_Passenger(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ReservationService_Service FOREIGN KEY (ServiceID) REFERENCES Service(ID) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE Reservation_Meal (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationPassengerID INT,
    MealID INT,
    CONSTRAINT FK_ReservationMeal_ReservationPassenger FOREIGN KEY (ReservationPassengerID) REFERENCES Reservation_Passenger(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ReservationMeal_Meal FOREIGN KEY (MealID) REFERENCES Airline_Meal(ID) 
);

CREATE TABLE Reservation_Additional_Baggage (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationFlightID INT,
    AdditionalBaggageID INT,
    CONSTRAINT FK_ReservationAdditionalBaggage_ReservationFlight FOREIGN KEY (ReservationFlightID) REFERENCES Reservation_Flight(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_ReservationAdditionalBaggage_AdditionalBaggage FOREIGN KEY (AdditionalBaggageID) REFERENCES Additional_Checked_Baggage(ID) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE Ticket (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationPassengerID INT,
    CheckInStatus BIT NOT NULL,
    SeatNumber VARCHAR(15) NOT NULL,
    CONSTRAINT FK_Ticket_ReservationPassenger FOREIGN KEY (ReservationPassengerID) REFERENCES Reservation_Passenger(ID) ON DELETE CASCADE ON UPDATE CASCADE
);



CREATE TABLE Payment (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationID INT,
    Amount DECIMAL(10, 2) NOT NULL,
    PaymentDate DATETIME NOT NULL,
    CONSTRAINT FK_Payment_Reservation FOREIGN KEY (ReservationID) REFERENCES Reservation(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Cancellation (
    ID INT PRIMARY KEY IDENTITY(1,1),
    ReservationID INT,
    CancellationDate DATETIME NOT NULL,
    CONSTRAINT FK_Cancellation_Reservation FOREIGN KEY (ReservationID) REFERENCES Reservation(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Cancellation_Refund (
    ID INT PRIMARY KEY IDENTITY(1,1),
    CancellationID INT,
    PassengerID INT,
	Amount DECIMAL(10, 2) NOT NULL,
	ExpirationDate DATE NOT NULL,
    CONSTRAINT FK_CancellationRefund_Cancellation FOREIGN KEY (CancellationID) REFERENCES Cancellation(ID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_CancellationRefund_Passenger FOREIGN KEY (PassengerID) REFERENCES Passenger(ID) ON DELETE SET NULL ON UPDATE CASCADE
);


CREATE TABLE Credit_Account (
    ID INT PRIMARY KEY IDENTITY(1,1),
    PassengerID INT NOT NULL,
    Balance DECIMAL(5, 2) NOT NULL,
    CONSTRAINT FK_CreditAccount_Passenger FOREIGN KEY (PassengerID) REFERENCES Passenger(ID) ON DELETE CASCADE ON UPDATE CASCADE
);




--DATA INSERTION/SEEDING



--Age Category Data
INSERT INTO Age_Category (CategoryName, MinAge, MaxAge) VALUES 
('Infant', 0, 1),
('Child', 2, 12),
('Adult', 13, 64),
('Senior', 65, NULL);

--Passenger Data
INSERT INTO Passenger (FirstName, LastName, DateOfBirth, PassportNumber, Email, AgeCategoryID) VALUES 
('John', 'Doe', '1990-01-01', 'A1234567', 'john.doe@example.com', 3),
('Jane', 'Doe', '2010-05-15', 'B1234567', 'jane.doe@example.com', 2);

--Airline Data
INSERT INTO Airline (Name, Country, RestrictUnder12TravelAlone, MaxPassengersPerBooking) VALUES 
('AirFly', 'USA', 1, 5),
('SkyTravel', 'UK', 1, 4);

--Aircraft Data
INSERT INTO Aircraft (AirlineID, Code, TotalSeats, FirstClassSeats, BusinessClassSeats, EconomyClassSeats) VALUES 
(1, 'AF001', 150, 10, 20, 120),
(2, 'ST001', 200, 20, 30, 150);

-- City Code Data
INSERT INTO CityCode (Code, CityName, Country) VALUES 
('NYC', 'New York', 'USA'),
('LON', 'London', 'UK');

--Flight Data
INSERT INTO Flight (AircraftID, FlightNumber, DepartureCityCode, ArrivalCityCode, DepartureDateTime, ArrivalDateTime, Duration, AvailableSeats) VALUES 
(1, 'AF100', 'NYC', 'LON', '2023-07-15 08:00:00', '2023-07-15 20:00:00', 720, 150), 
(2, 'ST200', 'LON', 'NYC', '2023-07-16 09:00:00', '2023-07-16 21:00:00', 720, 200), 
(1, 'AF100', 'NYC', 'LON', '2023-07-17 08:00:00', '2023-07-18 20:00:00', 2160, 250), 
(2, 'AF100', 'NYC', 'LON', '2023-07-18 08:00:00', '2023-07-19 20:00:00', 2160, 250);


-- Class Data
INSERT INTO Class (Name, Description) VALUES 
('First Class', 'Premium seating and exclusive services'),
('Economy', 'Standard seating and service'),
('Business', 'Enhanced seating, service, and meal options');


-- Airline_Class Data
INSERT INTO Airline_Class (AirlineID, ClassID, Price, CarryOnWeightLimit, CheckedWeightLimit) VALUES 
(1, 1, 299.99, 7.5, 15.0),
(1, 2, 599.99, 10.0, 20.0),
(1, 3, 999.99, 15.0, 30.0),
(2, 1, 249.99, 8.0, 18.0),
(2, 2, 549.99, 12.0, 25.0),
(2, 3, 899.99, 20.0, 35.0);

-- Airline_Meal Data
INSERT INTO Airline_Meal (AirlineID, Name, MealType, Price, Vegetarian) VALUES 
(1, 'Standard Meal', 'Single meal', 25.00, 0),
(1, 'Vegetarian Delight', 'Single meal', 30.00, 1),
(2, 'Chicken Meal', 'Single meal', 28.00, 0),
(2, 'Vegan Meal', 'Single meal', 32.00, 1);

-- Service Data
INSERT INTO Service (Name, Description) VALUES 
('Special Child Care', 'Dedicated care and assistance for children during the flight'),
('Wheelchair Service', 'Assistance with boarding, deplaning, and moving through the airport for passengers using wheelchairs'),
('Unaccompanied Minor Service', 'Supervision and assistance for children traveling alone');

-- Airline_Service Data
INSERT INTO Airline_Service (AirlineID, ServiceID, Price) VALUES 
(1, 1, 10.50),
(1, 2, 12.50),
(1, 3, 11.50),
(2, 1, 9.50),
(2, 2, 8.50),
(2, 3, 7.50);

-- Airline_Age_Category Data
INSERT INTO Airline_Age_Category (AirlineID, CategoryID, Price) VALUES 
(1, 1, 150.00),
(1, 2, 180.00),
(1, 3, 200.00),
(1, 4, 220.00),
(2, 1, 140.00),
(2, 2, 170.00),
(2, 3, 190.00),
(2, 4, 210.00);

-- Additional_Checked_Baggage Data
INSERT INTO Additional_Checked_Baggage (AirlineID, BaggageLimit, Price) VALUES 
(1, 10.0, 50.00),
(2, 15.0, 70.00);

-- Reservation Data
INSERT INTO Reservation (ReservationDate, Status, TripType, ReservationMadeBy, NumberOfPassengers) VALUES 
('2023-07-15 10:00:00', 'Confirmed', 'One-Way', 1, 2),
('2023-07-16 10:00:00', 'Cancelled', 'One-Way', 2, 1);

---Reservation_Flight Data
INSERT INTO Reservation_Flight (ReservationID, FlightID) VALUES 
(1, 1),
(2, 2);

--Reservation_Passenger Data
INSERT INTO Reservation_Passenger (ReservationFlightID, PassengerID, ClassID, TravelType) VALUES 
(1, 1, 1, 'InSeat'),
(1, 2, 1, 'InSeat'),
(2, 1, 1, 'InSeat');

--Reservation_Service Data
INSERT INTO Reservation_Service (ReservationPassengerID, ServiceID) VALUES 
(1, 3),
(1, 1),
(2, 1);

--Reservation_Meal Data
INSERT INTO Reservation_Meal (ReservationPassengerID, MealID) VALUES 
(1, 2),
(1, 1),
(2, 1);

--Reservation_Additional_Baggage Data
INSERT INTO Reservation_Additional_Baggage (ReservationFlightID, AdditionalBaggageID) VALUES 
(1, 1);

--Ticket Data
INSERT INTO Ticket (ReservationPassengerID, CheckInStatus, SeatNumber) VALUES 
(1, 1, '12C');

--Payment Data
INSERT INTO Payment (ReservationID, Amount, PaymentDate) VALUES 
(1, 300.00, '2023-07-15 12:00:00'),
(2, 300.00, '2023-07-15 12:00:00');

--Cancellation Data

INSERT INTO Cancellation (ReservationID, CancellationDate) VALUES
(2, GETDATE());

--Cancellation_Refund Data

INSERT INTO Cancellation_Refund(CancellationID, PassengerID, Amount, ExpirationDate) VALUES
(1, 2, 300, DateAdd("yyyy", 1, GETDATE()));

--Credit Account Data
INSERT INTO Credit_Account (PassengerID, Balance) 
VALUES 
(1, 100.00), 
(2, 150.50);