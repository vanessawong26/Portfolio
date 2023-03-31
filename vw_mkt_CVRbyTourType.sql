-- Objective: identify top-converting tour types and tour type combinations (for prospects who toured a community more than once), compare lease cancellation/denial rates and relative frequency of each tour type

WITH a1 AS (
SELECT 
	fga2.ClientID,
	fga2.CustomerProspectIdentifier,
	fga2.PMSCommunityID,
	--fga2.CreatedAt,
	fga2.GroupID,
	fga2.GroupName,
	fga2.ClientStatusDescription,
	fca2.IsRepeatTour,
    fca2.TourType,
    fca2.IsVideoTour,
    fca2.CreatedAt,
    fca2.OriginalAppointmentStart,
	fca2.AppointmentID,
    fca2.OriginalAppointmentEnd,
    fca2.AppointmentStatusDescription,
	fca2.TourRank,
	fl2.LeaseApplicationDate,
	fl2.ActualMoveInDate,
	fl2.CancelReasonGroup,
	fl2.LeaseRejectedDate,
	ada2.MarketName,
	ada2.EmpDirectorOfOperations
FROM (
	SELECT
		fga.ClientID,
		fga.CustomerProspectIdentifier,
		fga.PMSCommunityID,
		fga.CreatedAt,
		fga.GroupID,
		fga.GroupName,
		fga.ClientStatusDescription
	FROM dbo.FNL_FactGroupAssignment AS fga ) fga2  --1162329
INNER JOIN (
	SELECT 
		CASE 
			WHEN fca.IsWalkIn = 1 
				THEN 'Walk In'	-- classify walk-in tours as tour type
			ELSE fca.TourTypeDescription
		END AS [TourType],
		fca.IsVideoTour,
		CASE
			WHEN COUNT(fca.AppointmentID) OVER (PARTITION BY fca.ClientID, fca.PMSCommunityID) > 1 
				THEN 1
			ELSE 0
		END AS [IsRepeatTour],
		fca.ClientID,
		fca.PMSCommunityID,
		RANK() OVER (PARTITION BY fca.ClientID, fca.PMSCommunityID ORDER BY fca.OriginalAppointmentStart, fca.CreatedAt) AS [TourRank], --create tour rank column to pivot on/display repeat tours as columns
		fca.CreatedAt,
		fca.AppointmentID,
		fca.OriginalAppointmentStart,
		fca.TourTypeDescription,
		fca.OriginalAppointmentEnd,
		fca.AppointmentStatusDescription 
	FROM dbo.FNL_FactClientAppointment AS fca 
	WHERE fca.AppointmentStatusDescription = 'Completed' -- exclude cancels, no-shows, and resident appointments before rather than on the join so that each repeat tour is displayed sequentially
	AND fca.TourTypeDescription <> 'Resident Appointment') fca2 
ON fca2.ClientID = fga2.ClientID -- want output on a per client, per community basis
AND fca2.PMSCommunityID = fga2.PMSCommunityID
INNER JOIN (
	SELECT DISTINCT
		ada.oslPropertyID,
		ada.MarketName,
		ada.EmpDirectorOfOperations
	FROM dbo.vw_AssetDetailActive AS ada) ada2 
ON ada2.oslPropertyID = fga2.PMSCommunityID
INNER JOIN dbo.syn_RPBI_DimGuest AS dg --588425
ON dg.osl_gcardId = fga2.CustomerProspectIdentifier 
AND dg.osl_PropertyID = fga2.PMSCommunityID
LEFT JOIN (
	SELECT DISTINCT
		fl.osl_LeaseID,
		fl.osl_PropertyID,
		fl.GuestKey,
		dla.LeaseApplicationDate,
		dla.ActualMoveInDate,
		dla.CancelReasonGroup,
		dla.LeaseRejectedDate,
		RANK() OVER (PARTITION BY fl.GuestKey, dla.osl_PropertyID ORDER BY dla.LeaseApplicationDate, dla.LeaseSignedDate, dla.LeaseAttributesKey) AS [LeaseRank]
	FROM dbo.syn_RPBI_FactLease AS fl
	LEFT JOIN dbo.syn_RPBI_DimLeaseAttributes AS dla
	ON dla.osl_LeaseID = fl.osl_LeaseID
	AND dla.osl_PropertyID = fl.osl_PropertyID  ) fl2 --618079 
ON fl2.GuestKey = dg.GuestKey
AND fl2.osl_PropertyID = dg.osl_PropertyID
AND fl2.LeaseRank = 1 --leaserank = 1 brings row count back to 588425, only want first lease on per client per community level 
) 

SELECT DISTINCT
	a1.ClientID,
	a1.CustomerProspectIdentifier,
	a1.PMSCommunityID,
	CONCAT(a1.ClientID, ' - ', a1.GroupName) AS [ClientProperty],
	a1.GroupID,
	a1.GroupName,
	a1.ClientStatusDescription,
	a1.IsRepeatTour,
	--a1.TourType,
	--a1.IsVideoTour,
	--a1.CreatedAt,
	--a1.OriginalAppointmentStart,
	--a1.AppointmentID,
	--a1.OriginalAppointmentEnd,
	a1.AppointmentStatusDescription,
	--a1.TourRank,
	a1.LeaseApplicationDate,
	a1.ActualMoveInDate,
	a1.LeaseRejectedDate,
	a1.CancelReasonGroup,
	CASE
		WHEN a1.CancelReasonGroup = 'Rejection'
			THEN 1
		ELSE 0
	END AS [IsDenial],
	CASE 
		WHEN a1.CancelReasonGroup = 'Voluntary cancellation'
			THEN 1 
		ELSE 0
	END AS [IsCancellation],
	tour1.TourType AS [FirstTourType],
	tour2.TourType AS [SecondTourType],
	tour3.TourType AS [ThirdTourType],
	tour4.TourType AS [FourthTourType],
	tour1.OriginalAppointmentStart AS [FirstTourDate],
	tour2.OriginalAppointmentStart AS [SecondTourDate],
	tour3.OriginalAppointmentStart AS [ThirdTourDate],
	tour4.OriginalAppointmentStart AS [FourthTourDate],
	a1.MarketName,
	a1.EmpDirectorOfOperations
FROM a1
LEFT JOIN a1 AS tour1
	ON tour1.ClientID = a1.ClientID
	AND tour1.PMSCommunityID = a1.PMSCommunityID --pivot repeat tours (tour type and tour date)
	AND tour1.TourRank = 1
LEFT JOIN a1 AS tour2
	ON tour2.ClientID = a1.ClientID
	AND tour2.PMSCommunityID = a1.PMSCommunityID
	AND tour2.TourRank = 2
LEFT JOIN a1 AS tour3
	ON tour3.ClientID = a1.ClientID
	AND tour3.PMSCommunityID = a1.PMSCommunityID
	AND tour3.TourRank = 3
LEFT JOIN a1 AS tour4
	ON tour4.ClientID = a1.ClientID
	AND tour4.PMSCommunityID = a1.PMSCommunityID
	AND tour4.TourRank = 4;


