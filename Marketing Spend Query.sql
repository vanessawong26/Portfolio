-- Objective: create pivot table to evaluate actual marketing spend vs. budget marketing spend per community

SELECT glat.AssetCode,
       ada.AssetName,
	   ada.EmpDirectorofOperations,
	   ada.MarketName,
       glat.MonthID,
       glat.GLAccountNumber,
       dga.GLAccountName AS [Accounttitle],
       glat.FinanceType AS [FinanceTypeName],
       glat.BookID,
       glat.IsFullMonth,
       glat.IsClosedAcctPeriod,
       glat.Amount,
	   SUM(CASE WHEN glat.FinanceType = 'Actuals' THEN glat.Amount ELSE 0 END) AS [Actuals],
	   SUM(CASE WHEN glat.FinanceType = 'Budget' THEN glat.Amount ELSE 0 END) AS [Budget]
FROM dbo.acct_FactGLAccountTotal AS glat
    INNER JOIN dbo.vw_AssetDetailActive AS ada
        ON ada.AssetCode = glat.AssetCode
           AND ada.IsActiveProperty = 1
           AND ada.IsCurrentOSLPropertyID = 1
    INNER JOIN dbo.syn_RPBI_DimGLAccount AS dga
        ON dga.GLAccountNumber COLLATE DATABASE_DEFAULT = glat.GLAccountNumber COLLATE DATABASE_DEFAULT
           AND dga.ChartOfAccounts = 'Cortland'
    INNER JOIN [dbo].[acct_FactGLAccountGroupAccount] AS aga
        ON aga.GLAccountNumber = glat.GLAccountNumber
    INNER JOIN dbo.DimDate AS dd
        ON dd.MonthID = glat.MonthID
           AND dd.IsMonthEndDate = 1
WHERE aga.[Name] LIKE '%DA - Marketing%'
      AND aga.IsDeleted = 0
      AND YEAR(dd.Date) = YEAR(GETDATE())
GROUP BY glat.AssetCode,
         ada.AssetName,
		 ada.MarketName,
		 ada.EmpDirectorofOperations,
         glat.MonthID,
         glat.GLAccountNumber,
         dga.GLAccountName,
         glat.FinanceType,
         glat.BookID,
         glat.IsFullMonth,
         glat.IsClosedAcctPeriod,
         glat.Amount;