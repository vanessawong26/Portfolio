-- Objective: calculate customer churn cost (rent loss due to vacant unit, unit cleaning/turnover cost, marketing cost to fill vacancy) for new lease renewal pricing model

-----------------------BASE-----------------------------------------------------
	SELECT DISTINCT
		uc.ParentAssetName,
		uc.osl_PropertyID,
		uc.NumberofBedrooms,
		ys.YieldStarFloorPlan,
		COUNT(ys.osl_UnitID) OVER (PARTITION BY ys.YieldStarFloorPlan, ys.AssetCode) AS [YSFPCount], --pull count of units per floorplan, per community
		uc.IsInDevelopment
	FROM dbo.vw_ops_UnitCurrent AS uc
		LEFT JOIN dbo.ops_FactYieldStarUnit AS ys
		ON uc.FloorPlanKey = ys.FloorPlanKey
	WHERE 
		uc.IsRenewal = 0 
		AND uc.IsTaxCredit = 0
	GROUP BY 
		uc.ParentAssetName,
		uc.osl_PropertyID,
		uc.NumberofBedrooms,
		ys.YieldStarFloorPlan,
		ys.osl_UnitID,
		ys.AssetCode,
		uc.IsInDevelopment
	ORDER BY 
		uc.ParentAssetName, 
		uc.NumberofBedrooms;


-----------------------BASE2-----------------------------------------------------
	WITH a1 AS (
		SELECT DISTINCT
			uc.ParentAssetName,
			uc.osl_PropertyID,
			uc.NumberofBedrooms,
			ys.YieldStarFloorPlan
		FROM dbo.vw_ops_UnitCurrent AS uc
			LEFT JOIN dbo.ops_FactYieldStarUnit AS ys
			ON uc.FloorPlanKey = ys.FloorPlanKey
		WHERE 
			uc.IsRenewal = 0 
			AND uc.IsTaxCredit = 0
		GROUP BY 
			uc.ParentAssetName,
			uc.osl_PropertyID,
			uc.NumberofBedrooms,
			ys.YieldStarFloorPlan), 

	a2 AS (
		SELECT DISTINCT
			uc.osl_PropertyID,
			uc.AssetName,
			SUM(CASE WHEN uc.AssetOccupiedCount = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY uc.osl_PropertyID) AS [CountIsInDevelopment]
		FROM dbo.vw_ops_UnitCurrent AS uc
		GROUP BY 
			uc.osl_PropertyID, 
			uc.AssetName, 
			uc.AssetOccupiedCount);

		SELECT DISTINCT
			a1.*,
			a2.CountIsInDevelopment
		FROM a1
			LEFT JOIN a2
			ON a2.osl_PropertyID = a1.osl_PropertyID
		ORDER BY a1.ParentAssetName, a1.NumberofBedrooms;


-----------------------AVG VACANT DAYS/VACANT RENT LOSS-----------------------------------------------------
	WITH base AS (
		SELECT DISTINCT
			uc.ParentAssetName,
			uc.osl_PropertyID,
			uc.AssetName,
			uc.AssetCode,
			dlsp.RentRollEnd AS [PreviousRentRollEnd],
			uc.RentRollBeginDate AS [CurrentRentRollBegin],
			DATEDIFF(DAY, dlsp.RentRollEnd, uc.RentRollBeginDate) AS [Vacancy],
			uc.EffectiveRent,
			--uc.LeaseAttributesKey,
			uc.NumberofBedrooms,
			ys.YieldStarFloorPlan
		FROM dbo.vw_ops_UnitCurrent AS uc
			INNER JOIN dbo.ops_DimLeaseSummary AS dlsp
			ON uc.PriorLeaseAttributesKey = dlsp.LeaseAttributesKey
			AND uc.AssetCode = dlsp.AssetCode
			LEFT JOIN dbo.ops_FactYieldStarUnit AS ys
			ON uc.FloorPlanKey = ys.FloorPlanKey
		WHERE uc.IsRenewal = 0
		AND uc.IsTaxCredit = 0)

		SELECT
			base.ParentAssetName,
			base.osl_PropertyID,
			base.AssetName,
			base.AssetCode,
			base.PreviousRentRollEnd,
			base.CurrentRentRollBegin,
			base.YieldStarFloorPlan,
			base.NumberofBedrooms,
			AVG(base.Vacancy) OVER (PARTITION BY base.YieldStarFloorPlan, base.osl_PropertyID) AS [YSFPAvgVacantDays],
			base.Vacancy,
			base.EffectiveRent,
			(base.Vacancy) * (base.EffectiveRent/30) AS [VacantRentLoss]
		FROM base
		WHERE base.Vacancy <= 90
		GROUP BY 
			base.ParentAssetName,
			base.osl_PropertyID,
			base.AssetName,
			base.AssetCode,
			base.PreviousRentRollEnd,
			base.CurrentRentRollBegin,
			base.YieldStarFloorPlan,
			base.NumberofBedrooms,
			base.Vacancy,
			base.EffectiveRent
		ORDER BY 
			base.osl_PropertyID,
			base.YieldStarFloorPlan;


-------------------------------MARKETING COST--------------------------------------------------------

	WITH a1 AS(
		SELECT
			base.ParentAssetName,
			base.osl_PropertyID,
			base.AssetName,
			base.osl_SubPropertyID,
			base.AssetCode,
			base.ActualMoveInDate,
			base.MadeReadyDate,
			SUM(CASE WHEN base.ActualMoveInDate >= DATEADD(MONTH, -3, GETDATE()) THEN 1 ELSE 0 END) OVER (PARTITION BY base.osl_PropertyID) AS [T3MoveIns],
			SUM(CASE WHEN base.MadeReadyDate >= DATEADD(MONTH, -3, GETDATE()) THEN 1 ELSE 0 END) OVER (PARTITION BY base.osl_PropertyID) AS [T3Turns],
			(mkt3.MonthlyAmount * 3) AS [T3MktCost],
			(mkt6.MonthlyAmount * 6) AS [T6MktCost]
		FROM dbo.vw_ops_UnitCurrent AS base
			LEFT JOIN dbo.acct_FactGLAccountGroupTotalTrailing AS mkt3
			ON base.AssetCode = mkt3.AssetCode
			AND base.MonthID = mkt3.MonthID
			AND mkt3.TrailingMonths = 3
			AND mkt3.FinanceType = 'Actuals_Extended'
			AND mkt3.GLAccountGroupName IN ('IS - Marketing')
			LEFT JOIN dbo.acct_FactGLAccountGroupTotalTrailing AS mkt6
			ON base.AssetCode = mkt6.AssetCode
			AND base.MonthID = mkt6.MonthID
			AND mkt6.TrailingMonths = 6
			AND mkt6.FinanceType = 'Actuals_Extended'
			AND mkt6.GLAccountGroupName IN ('IS - Marketing')
		WHERE base.IsRenewal = 0 
			AND base.IsTaxCredit = 0
		GROUP BY 
			base.ParentAssetName,
			base.osl_PropertyID,
			base.AssetName,
			base.osl_SubPropertyID,
			base.AssetCode,
			mkt3.MonthlyAmount,
			mkt6.MonthlyAmount,
			base.ActualMoveInDate,
			base.MadeReadyDate), 

	a2 AS (
		SELECT DISTINCT
			a1.ParentAssetName,
			a1.osl_PropertyID,
			a1.AssetName,
			a1.AssetCode,
			a1.osl_SubPropertyID,
			a1.T3MoveIns,
			a1.T3Turns,
			a1.T3MktCost,
			a1.T6MktCost
		FROM a1)

		SELECT 
			a2.ParentAssetName,
			a2.osl_PropertyID,
			a2.AssetName,
			a2.AssetCode,
			a2.osl_SubPropertyID,
			a2.T3MoveIns,
			a2.T3Turns,
			SUM(a2.T3MktCost) OVER (PARTITION BY a2.osl_PropertyID) AS [T3Mkt],
			SUM(a2.T6MktCost) OVER (PARTITION BY a2.osl_PropertyID) AS [T6Mkt]
		FROM a2
		ORDER BY a2.ParentAssetName;


-------------------------------RENEWAL/ASSET LEVEL--------------------------------------------------------

		SELECT 
			renew.ParentAssetName,
			renew.oslPropertyID,
			SUM(CASE WHEN renew.LeaseActionTypeCode IN ('RENT-ROLL-BEGIN-RENEWAL') THEN 1 ELSE 0 END) as [CountRenewals] ,
			SUM(CASE WHEN renew.LeaseActionTypeCode IN ('RENT-ROLL-END-MOVE-OUT', 'RENT-ROLL-END-TRANSFER-OUT', 'RENT-ROLL-BEGIN-RENEWAL') THEN 1 ELSE 0 END) as [CountLeaseExpirations]
		FROM dbo.vw_ops_LeaseRentRollEnd AS renew
		WHERE renew.LeaseActionDate >= DATEADD(MONTH, -3, GETDATE()) 
			AND renew.IsTaxCredit = 0
		GROUP BY 
			renew.ParentAssetName,
			renew.oslPropertyID
		ORDER BY 
			renew.ParentAssetName;


-------------------------------UNIT TURNOVER COST--------------------------------------------------------

	WITH a1 AS (
		SELECT DISTINCT
			uc.ParentAssetName,
			uc.osl_PropertyID,
			uc.AssetName,
			uc.AssetCode,
			uc.osl_SubPropertyID, 
			afgagtt.MonthlyAmount*3 AS [AssetLevel_T3_TurnoverExpense]
		FROM dbo.vw_ops_UnitCurrent AS uc
			LEFT JOIN dbo.acct_FactGLAccountGroupTotalTrailing AS afgagtt
			ON afgagtt.AssetCode = uc.AssetCode
			AND afgagtt.MonthID = uc.MonthID
		WHERE afgagtt.TrailingMonths = 3
			AND afgagtt.FinanceType = 'Actuals_Extended'
			AND afgagtt.GLAccountGroupName IN ('IS - MAKE READY/TURNOVER')
			AND uc.IsTaxCredit = 0)

		SELECT 
			a1.ParentAssetName,
			a1.osl_PropertyID,
			a1.AssetName,
			a1.osl_SubPropertyID,
			SUM(a1.AssetLevel_T3_TurnoverExpense) OVER (PARTITION BY a1.osl_PropertyID) AS [T3TurnCost]
		FROM a1 
		ORDER BY 
			a1.ParentAssetName;