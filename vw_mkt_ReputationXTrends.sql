--Objective: create trend reporting for ReputationX scores and score components

WITH a1 AS (						-- rank weekly life to date 
	SELECT
		drc.LocationID,
		drc.osl_PropertyID,
		drc.LocationName,
		drc.ReviewCount,
		drc.SentimentPositve,
		drc.SentimentNegative,
		drc.DateRange,
		drc.DateRangeFrom,
		drc.DateRangeTo,
		DENSE_RANK() OVER (PARTITION BY drc.osl_PropertyID ORDER BY drc.DateRangeTo DESC) AS [WeekRank]
	FROM 
		(SELECT 
		drc.*
		FROM dbo.mkt_DimReputationDotComSummary AS drc
		WHERE drc.DateRange = 'WeeklyLifeToDate'
		AND drc.LocationID NOT IN ('Corp', 'CORT01', 'Other') AND drc.LocationID NOT LIKE ('CORT%')) drc ),

a2 AS (
	SELECT
		drc.LocationID,
		drc.osl_PropertyID,
		drc.LocationName,
		drc.ReviewCount,
		drc.Score,
		drc.Rating,
		drc.SentimentPositve,
		drc.SentimentNeutral, 
		drc.SentimentNegative,
		drc.DateRangeFrom,
		drc.DateRangeTo,
		drc.DateRange,
		DENSE_RANK() OVER (PARTITION BY drc.osl_PropertyID, drc.DateRange ORDER BY drc.DateRangeTo DESC) AS [DateRank]
	FROM
		(SELECT 
		drc.*
		FROM dbo.mkt_DimReputationDotComSummary AS drc
		WHERE drc.DateRange IN ('PastMonth', 'PreviousMonth', 'ThisMonth', 'PreviousYear')
		AND drc.LocationID NOT IN ('Corp', 'CORT01', 'Other') AND drc.LocationID NOT LIKE ('CORT%')) drc )


	SELECT DISTINCT
		a1.LocationID,
		a1.osl_PropertyID,
		a1.LocationName,
		wk0.SentimentPositve AS [Wk0SentimentPositive],
		wk0.SentimentNegative AS [Wk0SentimentNegative],
		wk0.ReviewCount AS [Wk0ReviewCount],
		DATEADD(DAY, 1, wk1.DateRangeTo) AS [Wk0DateRangeFrom], -- subtracting wk0 - wk1 , wk1 - wk2 (WeeklyLifeToDates) to get WoW review volume
		wk0.DateRangeTo AS [Wk0DateRangeTo], 
		wk1.SentimentPositve AS [Wk1SentimentPositive],
		wk1.SentimentNegative AS [Wk1SentimentNegative],
		wk1.ReviewCount AS [Wk1ReviewCount],
		DATEADD(DAY, 1, wk2.DateRangeTo) AS [Wk1DateRangeFrom],
		wk1.DateRangeTo AS [Wk1DateRangeTo],
		wk2.SentimentPositve AS [Wk2SentimentPositive],
		wk2.SentimentNegative AS [Wk2SentimentNegative],
		wk2.ReviewCount AS [Wk2ReviewCount],
		DATEADD(DAY, 1, wk3.DateRangeTo) AS [Wk2DateRangeFrom],
		wk2.DateRangeTo AS [Wk2DateRangeTo],
		wk3.SentimentPositve AS [Wk3SentimentPositive],
		wk3.SentimentNegative AS [Wk3SentimentNegative],
		wk3.ReviewCount AS [Wk3ReviewCount],
		DATEADD(DAY, 1, wk4.DateRangeTo) AS [Wk3DateRangeFrom],
		wk3.DateRangeTo AS [Wk3DateRangeTo],
		wk4.SentimentPositve AS [Wk4SentimentPositive],
		wk4.SentimentNegative AS [Wk4SentimentNegative],
		wk4.ReviewCount AS [Wk4ReviewCount],
		DATEADD(DAY, 1, wk5.DateRangeTo) AS [Wk4DateRangeFrom],
		wk4.DateRangeTo AS [Wk4DateRangeTo],
		wk5.SentimentPositve AS [Wk5SentimentPositive],
		wk5.SentimentNegative AS [Wk5SentimentNegative],
		wk5.ReviewCount AS [Wk5ReviewCount],
		DATEADD(DAY, 1, wk6.DateRangeTo) AS [Wk5DateRangeFrom],
		wk5.DateRangeTo AS [Wk5DateRangeTo],
		wk6.SentimentPositve AS [Wk6SentimentPositive],
		wk6.SentimentNegative AS [Wk6SentimentNegative],
		wk6.ReviewCount AS [Wk6ReviewCount],
		DATEADD(DAY, 1, wk7.DateRangeTo) AS [Wk6DateRangeFrom],
		wk6.DateRangeTo AS [Wk6DateRangeTo],
		tm.Score AS [M0Score],
		tm.DateRangeFrom AS [M0DateRangeFrom],
		tm.SentimentNegative AS [M0SentimentNegative],
		m0.Score AS [M1Score],
		m0.DateRangeFrom AS [M1DateRangeFrom],
		m0.SentimentNegative AS [M1SentimentNegative],
		m1.Score AS [M2Score],
		m1.Rating AS [M2Rating], 
		m1.ReviewCount AS [M2ReviewCount],
		m1.SentimentNegative AS [M2SentimentNegative],
		m1.DateRangeFrom AS [M2DateRangeFrom],
		m1.DateRangeTo AS [M2DateRangeTo],
		m2.Score AS [M3Score],
		m2.Rating AS [M3Rating],
		m2.ReviewCount AS [M3ReviewCount],
		m2.SentimentNegative AS [M3SentimentNegative],
		m2.DateRangeFrom AS [M3DateRangeFrom],
		m2.DateRangeTo AS [M3DateRangeTo],
		m3.Score AS [M4Score],
		m3.Rating AS [M4Rating],
		m3.ReviewCount AS [M4ReviewCount],
		m3.SentimentNegative AS [M4SentimentNegative],
		m3.DateRangeFrom AS [M4DateRangeFrom],
		m3.DateRangeTo AS [M4DateRangeTo],
		ly.Score AS [LYScore],
		ly.Rating AS [LYRating],
		ly.ReviewCount AS [LYReviewCount],
		ly.DateRangeFrom AS [LYDateRangeFrom],
		ly.DateRangeTo AS [LYDateRangeTo],
		ada.*
	FROM a1
	INNER JOIN a1 AS wk0
		ON a1.osl_PropertyID = wk0.osl_PropertyID
		AND wk0.WeekRank = 1
	INNER JOIN a1 AS wk1
		ON a1.osl_PropertyID = wk1.osl_PropertyID
		AND wk1.WeekRank = 2
	INNER JOIN a1 AS wk2
		ON a1.osl_PropertyID = wk2.osl_PropertyID
		AND wk2.WeekRank = 3
	INNER JOIN a1 AS wk3
		ON a1.osl_PropertyID = wk3.osl_PropertyID
		AND wk3.WeekRank = 4
	INNER JOIN a1 AS wk4
		ON a1.osl_PropertyID = wk4.osl_PropertyID
		AND wk4.WeekRank = 5
	INNER JOIN a1 AS wk5
		ON a1.osl_PropertyID = wk5.osl_PropertyID
		AND wk5.WeekRank = 6
	INNER JOIN a1 AS wk6
		ON a1.osl_PropertyID = wk6.osl_PropertyID
		AND wk6.WeekRank = 7
	INNER JOIN a1 AS wk7
		ON a1.osl_PropertyID = wk7.osl_PropertyID
		AND wk7.WeekRank = 8
	INNER JOIN a2 AS tm
		ON tm.osl_PropertyID = a1.osl_PropertyID
		AND tm.DateRange = 'ThisMonth'
	INNER JOIN a2 AS m0
		ON m0.osl_PropertyID = a1.osl_PropertyID
		AND m0.DateRange = 'PreviousMonth'
	INNER JOIN a2 AS m1
		ON m1.osl_PropertyID = a1.osl_PropertyID
		AND m1.DateRank = 1
		AND m1.DateRange = 'PastMonth'
	INNER JOIN a2 AS m2
		ON m2.osl_PropertyID = a1.osl_PropertyID
		AND m2.DateRank = 2
		AND m2.DateRange = 'PastMonth'
	INNER JOIN a2 AS m3
		ON m3.osl_PropertyID = a1.osl_PropertyID
		AND m3.DateRank = 3
		AND m3.DateRange = 'PastMonth'
	INNER JOIN a2 AS ly
		ON ly.osl_PropertyID = a1.osl_PropertyID
		AND ly.DateRange = 'PreviousYear'
	INNER JOIN (
			SELECT DISTINCT
				ada.oslPropertyID,
				ada.MarketName,
				ada.EmpDirectorofOperations,
				SUM(ada.CurrentUnitCount) OVER (PARTITION BY ada.oslPropertyID) AS [CurrentUnitCount],
				ada.EmpManagingDirector,
				MIN(ada.InitialEntityAcquisitionDate) OVER (PARTITION BY ada.oslPropertyID) AS [InitialEntityAcquisitionDate]
			FROM dbo.vw_AssetDetailActive AS ada
			GROUP BY ada.oslPropertyID,
					 ada.MarketName,
					 ada.EmpDirectorOfOperations,
					 ada.CurrentUnitCount,
					 ada.InitialEntityAcquisitionDate,
					 ada.EmpManagingDirector ) ada
		ON ada.oslPropertyID = a1.osl_PropertyID ;
