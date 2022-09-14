-- Objective: custom queries for PowerBI dashboard that shows relationship between online reputation (Google ratings) and prospect activity (lead and visit volume)

-- Pull all-time Google rating
SELECT DISTINCT
rep.LocationName,
rep.osl_PropertyID,
rep.GoogleRating,
rep.Sentiment,
rep.Date,
rep.Comment,
rep.ReviewerName,
ada2.AssetCode2,
CASE
	WHEN rep.AllTimeAverage >= 4 THEN 1
	ELSE 0
	END AS IsAvgGreaterThanEqualTo4
FROM 
	(SELECT
		drdc.LocationName,
		drdc.osl_PropertyID,
		drdc.Rating AS [GoogleRating],
		drdc.Sentiment,
		CAST(drdc.Date AS DATE) AS [Date],
		drdc.Comment,
		drdc.ReviewerName,
		AVG(drdc.Rating) OVER (PARTITION BY drdc.osl_PropertyID) AS [AllTimeAverage]
		FROM dbo.mkt_DimReputationDotComReview AS drdc
		WHERE drdc.SourceID IN ('GOOGLE_QA', 'GOOGLE_PLACES') ) AS rep
INNER JOIN 
	(SELECT DISTINCT 
	MIN(ada.AssetCode) OVER (PARTITION BY ada.oslPropertyID) AS [AssetCode2],
	ada.oslPropertyID
	FROM dbo.vw_AssetDetailActive AS ada ) ada2
ON rep.osl_PropertyID = ada2.oslPropertyID;

--------------------------------------------------------------------------------------------------------------------

-- Pull prospect activity
SELECT
lla.NewYearID,
lla.Date,
lla.NewDate,
lla.YearID,
lla.MonthID,
lla.WeekOfYear,
lla.LeadCount,
lla.VisitCount,
lla.TourCount,
lla.ApplicationCount,
lla.ApplicationApprovedCount,
lla.ApplicationCanceledCount,
lla.ApplicationDeniedCount,
lla.RenewalSignedCount,
lla.TransferSignedCount,
lla.NTVGivenCount,
lla.RentRollBeginCount,
lla.IsStabilized,
lla.NetLeasedCount,
lla.ExposedUnitCount,
lla.ActualOccupiedCount,
lla.ActualUnitCount,
lla.ActualPhysicalOccupancy,
lla.ActualFinancialOccupancy,
lla.BudgetFinancialOccupancy,
lla.ProFormaFinancialOccupancy,
lla.LeaseRent,
lla.EffectiveRent,
lla.ActualMoveInCount,
lla.ActualMoveOutCount,
lla.ScheduledMoveInCount,
lla.ScheduledMoveOutCount,
lla.oslPropertyID,
ada2.AssetCode,
ada2.ParentAssetUnitCount
FROM dbo.vw_ops_LeadLeaseActivity AS lla
INNER JOIN (SELECT DISTINCT
			MIN(ada.AssetCode) OVER (PARTITION BY ada.oslPropertyID) AS [AssetCode],
			ada.oslPropertyID,
			SUM(ada.CurrentUnitCount) OVER (PARTITION BY ada.oslPropertyID) AS [ParentAssetUnitCount]
			FROM dbo.vw_AssetDetailActive AS ada ) ada2
ON ada2.oslPropertyID = lla.oslPropertyID
WHERE lla.Date >= DATEADD(YEAR, -3, GETDATE()); --want prospect activity on a trailing 3 year basis
