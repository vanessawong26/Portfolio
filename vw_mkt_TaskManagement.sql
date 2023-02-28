--Objective: replicate manual reporting that shows promptness of on-site teams' follow up and communications with toured leads

WITH p AS (
    SELECT
        fga2.*
    FROM 
        (SELECT
            fga.ClientID,
            fga.GroupName,
            fga.CustomerProspectIdentifier, --
            fga.PMSCommunityID,
            CONCAT(fga.ClientID, ' - ', fga.GroupName) AS [ClientProperty],
            FORMAT(DATEADD(HOUR, -4, fga.CreatedAt), 'd') AS [DateClientAdded],
            fga.ClientStatusDescription
        FROM dbo.FNL_FactGroupAssignment AS fga
        WHERE fga.ClientStatusDescription IN ('Toured', 'Prospect')
        AND fga.GroupName NOT LIKE 'z%') fga2 ),

 

a AS (
    SELECT
        faa2.NewUserName,
        faa2.ClientProperty,
        CASE
            WHEN faa2.NewUserRole IS NULL AND dfa.LeasingHubStartDate IS NOT NULL THEN 'Leasing Hub Agent'
            ELSE faa2.NewUserRole
        END AS [NewUserRole],
        DENSE_RANK() OVER (PARTITION BY faa2.ClientProperty ORDER BY faa2.CreatedAt DESC) AS [AssignRank] -- in final cte add where assignrank = 1 (most recently assigned agent)
    FROM ( 
            SELECT
                CONCAT(faa.ClientID, ' - ', faa.NewGroupName) AS [ClientProperty],
                faa.NewUserName,
                faa.NewUserRole, 
                faa.CreatedAt,
                faa.NewUserID
            FROM dbo.FNL_FactAgentAssignment AS faa ) faa2
    LEFT JOIN dbo.mkt_DimFunnelAgent AS dfa
        ON faa2.NewUserID = dfa.UserID ),


c AS (
    SELECT
        fc2.*,
        DENSE_RANK() OVER (PARTITION BY fc2.ClientProperty ORDER BY fc2.CommunicationCreatedAt DESC) AS [CommRank] -- where comm rank = 1 to get latest comm
    FROM (
            SELECT
                CONCAT(fc.ClientID, ' - ', fc.GroupName) AS [ClientProperty],
                fc.ClientSnapshotStatus,
				fc.CommunicationCreatedAt,
                FORMAT(DATEADD(HOUR, -4, fc.CommunicationCreatedAt), 'g') AS [CommunicationCreatedAtLocal]
            FROM dbo.FNL_FactConversation AS fc
            WHERE (fc.IsOutgoing = '1') OR (fc.IsIncoming = '1' AND fc.Medium = 'Phone' AND fc.CallStatus = 'completed' AND fc.CallClassification <> 'CC - Routed - Missed' )) fc2 ),


r AS (
    SELECT
        fcr2.*,
        DENSE_RANK() OVER (PARTITION BY fcr2.ClientProperty ORDER BY fcr2.reminder_due_date, fcr2.creation_date) AS [ReminderRank] -- we want the oldest reminder (ReminderRank = 1)
        FROM (
            SELECT    
                CONCAT(fcr.client_id, ' - ', fcr.group_name) AS [ClientProperty],
                fcr.detail,
                fcr.autocompleted,
                fcr.completed_by_user_name,
                fcr.completed_date,
                fcr.reminder_due_date,
                fcr.reminder_id,
                fcr.status, 
                fcr.type,
                fcr.creation_date
            FROM dbo.FNL_FactClientReminders AS fcr
            WHERE (fcr.status = 'Completed' AND fcr.completed_date IS NOT NULL) OR (fcr.status <> 'Completed' )) fcr2 ), -- completed task data clean ; 
			-- same completed task (same taskid) will have two rows, one with missing completion date/completed by, one with complete data -- this line excludes missing data row

r2 AS (
	SELECT DISTINCT
		fcr22.ClientProperty,
		SUM(fcr22.is_open_task) OVER (PARTITION BY fcr22.ClientProperty) AS [total_open_tasks],
		SUM(fcr22.is_overdue_task) OVER (PARTITION BY fcr22.ClientProperty) AS [total_overdue_tasks]
	FROM (
		SELECT
			CONCAT(fcr.client_id, ' - ', fcr.group_name) AS [ClientProperty],
			fcr.reminder_id,
			CASE WHEN fcr.status = 'Active' THEN 1 ELSE 0 END AS [is_open_task],
			CASE WHEN fcr.reminder_due_date < DATEADD(DAY, -1, GETDATE()) AND fcr.status = 'Active' AND fcr.reminder_id IS NOT NULL THEN 1 ELSE 0 END AS [is_overdue_task]
		FROM dbo.FNL_FactClientReminders AS fcr
		WHERE fcr.status = 'Active') fcr22 ),

t AS (
    SELECT
        fca2.ClientProperty,
        fca2.OriginalAppointmentStartDate,
        fca2.OriginalAppointmentStartTime,
        DENSE_RANK() OVER (PARTITION BY fca2.ClientProperty ORDER BY fca2.OriginalAppointmentStart DESC) AS [VisitRank] -- account for same client touring same property more than once (visitrank = 1 /latest tour only)
    FROM (
        SELECT
            CONCAT(fca.ClientID, ' - ', fca.GroupName) AS [ClientProperty],
            CAST(fca.OriginalAppointmentStart AS DATE) AS [OriginalAppointmentStartDate],
            FORMAT(fca.OriginalAppointmentStart, 'HH:mm') AS [OriginalAppointmentStartTime],
            fca.*
        FROM dbo.FNL_FactClientAppointment AS fca ) fca2
    WHERE fca2.GroupName NOT LIKE 'z%' )

 

    SELECT DISTINCT 
        p.ClientID,
        p.GroupName,
        p.ClientProperty,
        p.DateClientAdded,
        p.ClientStatusDescription,
        dg.GuestDesiredMoveInDate, -- 
        --CASE WHEN GETDATE() > dg.GuestDesiredMoveInDate THEN 1 ELSE 0 END AS [past_lease_start],
        CASE WHEN dg.GuestDesiredMoveInDate IS NULL THEN 1 ELSE 0 END AS [lease_start_missing],
        CASE WHEN dg.GuestDesiredMoveInDate <= DATEADD(DAY, 30, GETDATE()) AND dg.GuestDesiredMoveInDate >= GETDATE() THEN 1 ELSE 0 END AS [lease_start_in_next_30],
        a.NewUserName,
        a.NewUserRole,
        c.ClientSnapshotStatus,
		c.CommunicationCreatedAt,
        --CASE WHEN dg.GuestDesiredMoveInDate < DATEADD(DAY, 30, GETDATE()) AND dg.GuestDesiredMoveInDate > GETDATE() AND c.CommunicationCreatedAtLocal < DATEADD(DAY, -10, GETDATE()) THEN 1 ELSE 0 END AS [no_comm_in_10_and_30_to_MI], -- date add -1 day
        t.OriginalAppointmentStartDate,
        t.OriginalAppointmentStartTime,
        --r.detail,
        --r.autocompleted,
		CASE WHEN r2.total_open_tasks >= 1 THEN 1 ELSE 0 END AS [has_open_task],
		CASE WHEN r2.total_overdue_tasks >= 1 THEN 1 ELSE 0 END AS [has_overdue_task],
        r.completed_by_user_name,
        r.completed_date,
        r.reminder_due_date,
        r.reminder_id,
        r.status,
        r.type,
        r.creation_date,
        ada2.EmpManagingDirector,
        ada2.EmpDirectorOfOperations
    FROM p 
    INNER JOIN a 
    ON a.ClientProperty = p.ClientProperty
    AND a.AssignRank = '1'
    INNER JOIN c
    ON c.ClientProperty = p.ClientProperty
    AND c.CommRank = '1'
    INNER JOIN r 
    ON r.ClientProperty = p.ClientProperty
    AND r.ReminderRank = '1'
    INNER JOIN t 
    ON t.ClientProperty = p.ClientProperty
    AND t.VisitRank = '1'
    INNER JOIN (
                SELECT DISTINCT
                ada.oslPropertyID,
                ada.EmpDirectorofOperations,
                ada.EmpManagingDirector
                FROM dbo.vw_AssetDetailActive AS ada ) ada2 -- 15,831 before ada , 15,831 after on 12.14.22
    ON ada2.oslPropertyID = p.PMSCommunityID
	LEFT JOIN r2
	ON r2.ClientProperty = p.ClientProperty
    LEFT JOIN dbo.syn_RPBI_DimGuest AS dg --
    ON dg.osl_gcardID = p.CustomerProspectIdentifier
    AND dg.osl_PropertyID = p.PMSCommunityID;

