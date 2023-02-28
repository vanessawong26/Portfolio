-- Objective: create a ReputationX score progress tracker using metrics like Reviews per Week Needed, Score Change From Previous Week 
-- for operations leadership and for assisting on-site teams in effort to reclaim title as ReputationX (multifamily) Industry Leader

WITH a1 AS (						-- rank weekly life to date 
	SELECT
		drc.mkt_DimReputationDotComSummaryKey,
		drc.LocationID,
		drc.LocationName,
		drc.osl_PropertyID,
		drc.Count,
		drc.Rating,
		drc.ReponseCount,
		drc.ReviewCount,
		drc.Score,
		drc.SentimentPositve,
		drc.SentimentNeutral,
		drc.SentimentNegative,
		drc.StarAverage,
		drc.ReviewVolume,
		drc.ReviewRecency,
		drc.ReviewLength,
		drc.ReviewSpread,
		drc.ReviewResponse,
		drc.SearchImpression,
		drc.ListingAccuracy,
		drc.SocialEngagement,
		drc.DateRange,
		drc.DateRangeFrom,
		drc.DateRangeTo,
		DENSE_RANK() OVER (PARTITION BY drc.LocationID ORDER BY drc.DateRangeTo DESC) AS [WeekRank],
		drc.CPSourceSystemCode,
		drc.CPCreatedByID,
		drc.CPModifiedByID,
		drc.CPCreatedTimeStamp,
		drc.CPModifiedTimeStamp,
		drc.CPAction,
		drc.CPBatchID,
		drc.CPJobID
	FROM 
		(SELECT 
		drc.*
		FROM dbo.mkt_DimReputationDotComSummary AS drc
		WHERE drc.DateRange = 'WeeklyLifeToDate'
		AND drc.LocationID NOT IN ('Corp', 'CORT01', 'Other')
		AND drc.LocationID NOT LIKE 'CORT%') drc ),

k AS (
	SELECT DISTINCT
		kdr.osl_PropertyID, 
		AVG(kdr.ResponseValue) OVER (PARTITION BY kdr.osl_PropertyID) AS [T3OCSAsset],
		AVG(kdr.ResponseValue) OVER (PARTITION BY ada.EmpManagingDirector) AS [T3OCSMD]
		FROM dbo.mkt_FactKingsleyDailyResponse AS kdr
		INNER JOIN dbo.vw_AssetDetailActive AS ada
		ON ada.oslPropertyID = kdr.osl_PropertyID
		WHERE kdr.QuestionID = '8446'
		AND kdr.DateResponded >= DATEADD(MONTH, -3, GETDATE())) ,

ltd AS (
	SELECT
		drc.mkt_DimReputationDotComSummaryKey,
		drc.LocationID,
		drc.osl_PropertyID,
		drc.LocationName,
		drc.Count,
		drc.Rating,
		drc.ReponseCount,
		drc.ReviewCount,
		drc.Score,
		drc.SentimentPositve,
		drc.SentimentNeutral,
		drc.SentimentNegative,
		drc.StarAverage,
		drc.ReviewVolume,
		drc.ReviewRecency,
		drc.ReviewLength,
		drc.ReviewSpread,
		drc.ReviewResponse,
		drc.SearchImpression,
		drc.ListingAccuracy,
		drc.SocialEngagement,
		drc.DateRange,
		drc.DateRangeFrom,
		drc.DateRangeTo,
		MAX(drc.Score) OVER (PARTITION BY drc.DateRange) AS [BestInClass]
	FROM 
		(SELECT 
		drc.*
		FROM dbo.mkt_DimReputationDotComSummary AS drc
		WHERE drc.DateRange = 'LifeToDate'
		AND drc.LocationID NOT IN ('Corp', 'CORT01', 'Other')
		AND drc.LocationID NOT LIKE 'CORT%') drc ),

sf AS (
	SELECT DISTINCT -- 12,116 rows as of 10/20/22 ; 233 distinct LocationIDs * 52 weeks 
		a1.LocationID,
		a1.LocationName,
		a1.osl_PropertyID,
		CAST(ltd.DateRangeTo AS DATE) AS [LTDDate],
		ltd.Rating AS [LTDRating],
		ltd.ReviewCount AS [LTDReviewCount],
		CASE
			WHEN ltd.Rating < 3.95 THEN 3.95
			WHEN ltd.Rating >= 3.95 AND ltd.Rating < 4.45 THEN 4.45
			ELSE NULL
		END AS [LTDTargetRating],
		ltd.Score AS [LTDScore],
		CASE
			WHEN ltd.Score < 825 THEN 825
			WHEN ltd.Score >= 825 THEN ltd.BestInClass
			ELSE NULL
		END AS [LTDTargetScore],
		CAST(lw.DateRangeTo AS DATE) AS [LastWeek],
		lw.Rating AS [LWRating],
		lw.ReviewCount AS [LWReviewCount],
		lw.Score AS [LWScore]
	FROM a1
		INNER JOIN ltd
	ON a1.osl_PropertyID = ltd.osl_PropertyID
		INNER JOIN a1 AS lw
	ON a1.osl_PropertyID = lw.osl_PropertyID
	AND lw.WeekRank = 2 ),

today AS (
	SELECT 
		dd.*
	FROM 
		(SELECT
			dd.*,
			dd.MonthSequence + 12 AS [F12]
		FROM dbo.DimDate AS dd
		WHERE dd.Date = CAST(GETDATE() AS DATE)) dd	),

df AS (
	SELECT
		dd.Date AS [enddate],
		CAST(GETDATE() AS DATE) AS [today]
	FROM dbo.DimDate AS dd
		CROSS JOIN today
	WHERE dd.MonthOfYear = 5
		AND dd.DayOfMonth = 31
		AND dd.DaySequence > today.DaySequence
		AND dd.MonthSequence <= today.F12 ),


pr AS (
	SELECT
		dcr2.osl_PropertyID,
		SUM(dcr2.Rating) AS [SumRating],
		COUNT(DISTINCT dcr2.mkt_DimReputationDotComReviewKey) AS [CountRating]
	FROM 
		(SELECT
			dcr.Rating,
			dcr.osl_PropertyID,
			dcr.mkt_DimReputationDotComReviewKey
		FROM dbo.mkt_DimReputationDotComReview AS dcr
		WHERE dcr.SourceID NOT IN ('GOOGLE_QA', 'SURVEY')) dcr2
	GROUP BY dcr2.osl_PropertyID )
		

	SELECT DISTINCT
		sf.*,
		CEILING( sf.LTDReviewCount * (sf.LTDRating - sf.LTDTargetRating) / (sf.LTDTargetRating - 5) ) AS [LTDReviewsNeeded],
		CEILING( sf.LWReviewCount * (sf.LWRating - sf.LTDTargetRating ) / (sf.LTDTargetRating - 5 ) ) AS [LWReviewsNeeded],
		ada.*,
		k.T3OCSAsset,
		k.T3OCSMD,
		df.*,
		pr.SumRating,
		pr.CountRating
	FROM sf
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
	ON sf.osl_PropertyID = ada.oslPropertyID
		LEFT JOIN k
	ON k.osl_PropertyID = sf.osl_PropertyID
		LEFT JOIN pr
	ON pr.osl_PropertyID = sf.osl_PropertyID
		CROSS JOIN df;


