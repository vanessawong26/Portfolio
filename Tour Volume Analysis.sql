-- Objective: understand tour volume fluctuations and trends by hour of day and day of week

WITH base AS (
	SELECT
		fcap.OriginalAppointmentStartDate,
		fcap.AppointmentOriginSource,
		fcap.AppointmentStatusDescription,
		fcap.GroupName,
		fcap.OriginalAppointmentStartTime,
		fcap.OriginalAppointmentStart,
		fcap.AppointmentID,
		fcap.Date1,
		(RIGHT(fcap.Date1, 2)) * -1 AS [Date2], -- extract and manipulate minute fields of tour arrival times
		(RIGHT(fcap.Date1,2)) AS [Date3],		-- to round times later on
		dd.DayName,
		dd.QuarterID,
		dd.DayofWeek,
		fcap.IsWalkIn,
		ada.MarketName
	FROM
			(SELECT
			CAST(fca.OriginalAppointmentStart AS DATE) AS [OriginalAppointmentStartDate],
			fca.AppointmentOriginSource,
			fca.AppointmentStatusDescription,
			fca.GroupName,
			fca.GroupID,
			FORMAT(fca.OriginalAppointmentStart, 'hh:mm tt') AS [OriginalAppointmentStartTime],
			fca.OriginalAppointmentStart,
			fca.AppointmentID,
			LEFT(CAST(fca.OriginalAppointmentStart AS TIME), 5) AS [Date1],
			CASE 
				WHEN fca.IsWalkIn = 0 THEN 'False' 
				WHEN fca.IsWalkIn = 1 THEN 'True' 
				ELSE 'Unknown' 
				END AS [IsWalkIn]
			FROM dbo.FNL_FactClientAppointment AS fca) fcap
	INNER JOIN dbo.DimDate AS dd
	ON dd.Date = fcap.OriginalAppointmentStartDate
	INNER JOIN
			(SELECT DISTINCT
			PMSCommunityID,
			GroupID
			FROM dbo.FNL_DimUnit ) fdu
	ON fdu.GroupID = fcap.GroupID
	INNER JOIN 
			(SELECT DISTINCT
			oslPropertyID,
			MarketName
			FROM dbo.vw_AssetDetailActive ) ada
	ON ada.oslPropertyID = fdu.PMSCommunityID )

	SELECT 
		final.*,
		FORMAT(final.RoundedTime, 'hh:mm tt') AS [RoundedTime] -- converting military time to standard time
	FROM
		(SELECT
		 base.*,
			 CASE -- rounding tour arrival times down to the nearest hour  
				WHEN base.Date3 = 00 THEN base.OriginalAppointmentStartTime
				WHEN base.Date3 > 00 AND base.Date3 <= 59 THEN (DATEADD(MINUTE, base.Date2, base.OriginalAppointmentStartTime))
				ELSE base.OriginalAppointmentStartTime
				END AS [RoundedTime]
		 FROM base ) final
	WHERE final.QuarterID >= '2020Q1';




