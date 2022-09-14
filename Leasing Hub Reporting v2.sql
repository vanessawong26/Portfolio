-- Objective: automation of leasing hub associates' commission amount determination

WITH a1 AS (
	SELECT 
		faa.ClientID,
		faa.CompanyID,
		faa.CreatedAt,
		DENSE_RANK() OVER (PARTITION BY faa.ClientID ORDER BY faa.CreatedAt) AS [DateRank],
		faa.NewUserID,
		faa.NewUserName,
		dfa.IsLeasingHubAgent,
		CAST(dfa.LeasingHubStartDate AS DATETIME) AS [LeasingHubStartDate],
		CASE 
			WHEN dfa.LeasingHubEndDate IS NULL THEN CAST('2099-12-31 00:00:00.000' AS DATETIME)
			ELSE CAST(dfa.LeasingHubEndDate AS DATETIME)
			END AS [LeasingHubEndDate],
		faa.NewGroupName,
		faa.NewGroupID,
		faa.PMSCommunityID,
		faa.NewUserRole,
		fad.HubGroup
	FROM dbo.FNL_FactAgentAssignment AS faa
		LEFT JOIN dbo.mkt_DimFunnelAgent AS dfa
		ON faa.NewUserID = dfa.UserID
		LEFT JOIN dbo.mkt_FactLHAgentDetail AS fad
		ON fad.AgentEmail = dfa.AgentEmail ),

a2 AS (
	SELECT
		DENSE_RANK() OVER (PARTITION BY a1.ClientID, a1.PMSCommunityID ORDER BY a1.CreatedAt) AS [LHDateRank],
		a1.CreatedAt,
		a1.ClientID
	FROM a1
	WHERE a1.CreatedAt BETWEEN a1.LeasingHubStartDate AND a1.LeasingHubEndDate
	AND a1.IsLeasingHubAgent = 1 ),

a3 AS (
	SELECT
		a1.ClientID,
		a1.NewUserID,
		a1.NewUserName,
		a1.HubGroup,
		a1.IsLeasingHubAgent AS [IsLeasingHubAgentAllTime],
		CASE
			WHEN a1.LeasingHubStartDate IS NOT NULL AND a1.LeasingHubEndDate = '2099-12-31 00:00:00.000' THEN 1
			ELSE 0
			END AS [IsActiveLeasingHubAgent],
		CASE 
			WHEN a2.LHDateRank = 1 THEN 1
			ELSE 0
			END AS [IsFirstAssignedLeasingHubAgent],
		CASE
			WHEN a1.DateRank =1 THEN 1
			ELSE 0 
			END AS [IsFirstAssignedAgent],
		a1.NewGroupName,
		a1.NewGroupID,
		a1.PMSCommunityID
	FROM a1
		LEFT JOIN a2
		ON a2.CreatedAt = a1.CreatedAt
		AND a2.ClientID = a1.ClientID ),

a4 AS (
	SELECT
		DENSE_RANK() OVER (PARTITION BY fca.ClientID, fca.PMSCommunityID ORDER BY fca.OriginalAppointmentStart) AS [VisitRank],
		fca.ClientID,
		fca.PMSCommunityID,
		fca.OriginalAppointmentStart,
		fca.CreatedByUserID AS [AppointmentCreatorID],
		dfa.AgentName AS [AppointmentCreatorName],
		CASE
			WHEN dfa.LeasingHubStartDate IS NOT NULL AND dfa.LeasingHubEndDate IS NULL THEN 1
			ELSE 0
			END AS [ATIsActiveLeasingHubAgent]
	FROM dbo.FNL_FactClientAppointment AS fca
		LEFT JOIN dbo.mkt_DimFunnelAgent AS dfa
		ON dfa.UserID = fca.CreatedByUserID
	WHERE fca.AppointmentStatusDescription = 'Completed' ),

a5 AS (
	SELECT 
		CASE
			WHEN a4.VisitRank = 1 THEN a4.OriginalAppointmentStart
			ELSE NULL
			END AS [FirstVisitStartDateTime],
		a4.ClientID,
		a4.PMSCommunityID,
		a4.AppointmentCreatorID,
		a4.AppointmentCreatorName,
		a4.ATIsActiveLeasingHubAgent
	FROM a4),

comm AS (
	SELECT
		ffc.ClientID,
		ffc.PMSCommunityID,
		MIN(CASE 
			WHEN dfa.IsLeasingHubAgent = 1 THEN DATEADD(HOUR, -4, ffc.CommunicationCreatedAt) --AT TIME ZONE 'Eastern Standard Time'
			ELSE NULL 
			END) AS [FirstLHCommDate]
	FROM dbo.FNL_FactConversation AS ffc 
		LEFT JOIN dbo.mkt_DimFunnelAgent AS dfa
		ON dfa.UserID = ffc.UserID
	GROUP BY
	ffc.ClientID,
	ffc.PMSCommunityID )

	SELECT DISTINCT
		CONCAT(a3.ClientID, ' - ', a3.NewGroupName) AS [ClientProperty],
		a3.*,
		comm.FirstLHCommDate,
		a5.FirstVisitStartDatetime,
		CAST(FORMAT(a5.FirstVisitStartDatetime, 'yyyyMM') AS INT) AS [FirstVisitMonthID],
		CASE 
			WHEN a5.FirstVisitStartDateTime < comm.FirstLHCommDate THEN 1
			WHEN comm.FirstLHCommDate IS NULL THEN 1
			ELSE 0
			END AS [FirstVisitBeforeLHComm],
		a5.AppointmentCreatorID,
		a5.AppointmentCreatorName,
		a5.ATIsActiveLeasingHubAgent
	FROM a3
		LEFT JOIN a5
		ON a5.ClientID = a3.ClientID
		AND a5.PMSCommunityID = a3.PMSCommunityID 
		LEFT JOIN comm
		ON comm.ClientID = a3.ClientID
		AND comm.PMSCommunityID = a3.PMSCommunityID
	WHERE a5.FirstVisitStartDateTime IS NOT NULL
		AND a3.IsFirstAssignedLeasingHubAgent = 1 
	ORDER BY a3.ClientID;

--62,355 before hubgroup
--62,355 after hubgroup