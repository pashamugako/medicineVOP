public with sharing class NotificationComponentController {
    private static final Integer DAYS_BEFORE_NOTICE = 1;
    private static final String FIELD_APINAME_NOTICE_END_ISOLATION = 'Is_Ready_Notice_Isolation__c';
    private static final String FIELD_APINAME_NOTICE_VKK = 'Is_Ready_Notice_VKK__c';
    private static final String FIELD_APINAME_NOTICE_CT_SCAN = 'Is_Ready_Notice_Date_CT_Scan__c';
    private static final String FIELD_APINAME_NOTICE_EXPRESS_TEST = 'Is_Ready_Notice_Date_Express_Test__c';
    private static final String FIELD_APINAME_NOTICE_SMEAR = 'Is_Ready_Notice_Date_Smear__c';
    private static Map<String, String> ASSOCIATED_FIELD_TO_MESSAGE_MAP = new Map<String, String> {
        FIELD_APINAME_NOTICE_END_ISOLATION  => 'Срок изоляции заканчивается.',
        FIELD_APINAME_NOTICE_VKK            => 'Необходима ВКК для продления больничного.',
        FIELD_APINAME_NOTICE_CT_SCAN        => 'Подать заявку для КТ.',
        FIELD_APINAME_NOTICE_EXPRESS_TEST   => 'Взять Экспресс Тест.',
        FIELD_APINAME_NOTICE_SMEAR          => 'Взять Мазок.'
    };
    private static Map<String, String> ASSOCIATED_SOBJECT_TO_FIELDS = new Map<String, String> {
        'Sick_leave__c'       => 'Is_Ready_Notice_VKK__c,Is_Ready_Notice_Isolation__c',
        'Smear_Covid__c'      => 'Is_Ready_Notice_Date_Smear__c',
        'Express_Test__c'     => 'Is_Ready_Notice_Date_Express_Test__c',
        'CT_scan__c'          => 'Is_Ready_Notice_Date_CT_Scan__c',
        'Examination__c'      => ''
    };

    public class NotificationWrapper implements Comparable {
        @AuraEnabled public String id;
        @AuraEnabled public String dateNotification;
        @AuraEnabled public String message;
        @AuraEnabled public String patientName;
        @AuraEnabled public String patientPhone;
        @AuraEnabled public String sickLeaveURL;
        @AuraEnabled public String sickLeaveName;
        @AuraEnabled public String sObjectId;
        @AuraEnabled public String sObjectName;
        @AuraEnabled public String sObjectFieldUpdated;
        private Object dateSorted;

        public NotificationWrapper createNoticeFromSickLeave(Sick_leave__c sickLeave, String fieldNoticeApiName, 
            Object dateNotice, SObject sObjectRecord){

            NotificationWrapper notice = new NotificationWrapper();

            if (sickLeave != null) {
                notice.id = sObjectRecord.Id + fieldNoticeApiName;
                if (dateNotice instanceof Date) {
                    notice.dateNotification = Date.valueOf(dateNotice).format();
                } else {
                    notice.dateNotification = Datetime.valueOf(dateNotice).format();
                }
                notice.message = NotificationComponentController.ASSOCIATED_FIELD_TO_MESSAGE_MAP.get(fieldNoticeApiName);
                notice.patientName = new BuilderPatient(sickLeave).buildNameFull();
                notice.patientPhone = BuilderPatient.getPhoneFieldValue(sickLeave);
                notice.sickLeaveURL = URL.getSalesforceBaseUrl().toExternalForm() + '/' + sickLeave.Id;
                notice.sickLeaveName = sickLeave.Name;
                notice.sObjectId = sObjectRecord.Id;
                notice.sObjectName = sObjectRecord.getSObjectType().getDescribe().getName();
                notice.sObjectFieldUpdated = fieldNoticeApiName;
                notice.dateSorted = dateNotice;
            }

            return notice;
        }

        public Integer compareTo(Object compareTo) {
            NotificationWrapper notice = (NotificationWrapper) compareTo;
            Integer result = 0;

            if (!(notice.dateSorted instanceof Date) && !(this.dateSorted instanceof Date)) {
                Datetime compareToDatetime = Datetime.valueOf(notice.dateSorted);
                Datetime recordDatetime = Datetime.valueOf(this.dateSorted);

                if (compareToDatetime > recordDatetime) {
                    result = -1;
                } else if (compareToDatetime < recordDatetime) {
                    result = 1;
                }
            } else {
                Date compareToDate;
                if (notice.dateSorted instanceof Date) {
                    compareToDate = Date.valueOf(notice.dateSorted);
                } else {
                    compareToDate = Datetime.valueOf(notice.dateSorted).date();
                }
                Date recordDate;
                if (this.dateSorted instanceof Date) {
                    recordDate = Date.valueOf(this.dateSorted);
                } else {
                    recordDate = Datetime.valueOf(this.dateSorted).date();
                }

                if (compareToDate > recordDate) {
                    result = -1;
                } else if (compareToDate < recordDate) {
                    result = 1;
                }
            }
            
            return result;
        }
    }

    @AuraEnabled
    public static list<NotificationWrapper> retrieveItemsForTable(){
        List<NotificationWrapper> notificationList = new List<NotificationWrapper>{};

        List<Sick_leave__c> allSickLeaveItems = selectAllSickLeaveItems();
        for (Sick_leave__c sickLeave : allSickLeaveItems) {
            addSickLeaveVKKNotification(notificationList, sickLeave);
            addSickLeaveEndIsolationNotification(notificationList, sickLeave);
            addCTScanDateNotification(notificationList, sickLeave);
            addSmearCovidDateNotification(notificationList, sickLeave);
            addExpressTestDateNotification(notificationList, sickLeave);
        }
        notificationList.sort();

        return notificationList;
    }

    @AuraEnabled
    public static void updateItemsFromTable(String notificationListJSON){
        if (String.isEmpty(notificationListJSON)) {
            return;
        }
        list<NotificationWrapper> notificationList = (list<NotificationWrapper>)JSON.deserialize(
            notificationListJSON, list<NotificationWrapper>.class);
        Map<String, Set<String>> mapSObjectToIds = new Map<String, Set<String>>();
        Map<String, Set<String>> mapIdToFields = new Map<String, Set<String>>();

        for (NotificationWrapper notice : notificationList) {
            if (mapSObjectToIds.containsKey(notice.sObjectName)) {
                mapSObjectToIds.get(notice.sObjectName).add(notice.sObjectId);
            } else {
                mapSObjectToIds.put(notice.sObjectName, new Set<String>{notice.sObjectId});
            }

            if (mapIdToFields.containsKey(notice.sObjectId)) {
                mapIdToFields.get(notice.sObjectId).add(notice.sObjectFieldUpdated);
            } else {
                mapIdToFields.put(notice.sObjectId, new Set<String>{notice.sObjectFieldUpdated});
            }
        }

        for (String sObjectName : mapSObjectToIds.keySet()) {
            List<SObject> recordList = selectRecordsBySObjectNameAndId(sObjectName, mapSObjectToIds.get(sObjectName));
            for (SObject sObjectRecord : recordList) {
                Set<String> fieldList = mapIdToFields.get(sObjectRecord.Id);
                for (String fieldAPI : fieldList) {
                    sObjectRecord.put(fieldAPI, true);
                }
            }
            update recordList;
        }
    }

    private static List<Sick_leave__c> selectAllSickLeaveItems() {
        List<Sick_leave__c> sickLeaves = 
            [SELECT Is_Ready_Notice_VKK__c,Is_Ready_Notice_Isolation__c,Diagnosis__c,Start_Sick_Leave__c,Name,End_Isolation__c,Status__c,
                Patient__r.Second_Name__c,Patient__r.First_Name__c,Patient__r.Patronymic__c,Patient__r.Name,Patient__r.Mobile__c,
                (
                    SELECT Date_Examination__c 
                    FROM Examination__r),
                (
                    SELECT Date_Smear__c,Is_Ready_Notice_Date_Smear__c 
                    FROM Smear_Covid__r
                    WHERE Is_Ready_Notice_Date_Smear__c = false),
                (
                    SELECT Date_Express_Test__c,Is_Ready_Notice_Date_Express_Test__c
                    FROM Express_Test__r
                    WHERE Is_Ready_Notice_Date_Express_Test__c = false),
                (
                    SELECT Datetime_CT__c,Is_Ready_Notice_Date_CT_Scan__c
                    FROM CT_scan__r
                    WHERE Is_Ready_Notice_Date_CT_Scan__c = false)
            FROM Sick_leave__c
            WHERE 
                Status__c = :SickLeaveUtils.STATUS_ACTIVE];
        
        return sickLeaves;
    }

    private static void addSickLeaveVKKNotification(List<NotificationWrapper> notificationList, Sick_leave__c sickLeave) {
        if (sickLeave.Is_Ready_Notice_VKK__c == false) {
            Date dateStartSickLeave = sickLeave.Start_Sick_Leave__c;
            Date dateVKK;
            Date dateVKKWithoutHolidays;
            if (dateStartSickLeave != null) {
                dateVKK = dateStartSickLeave.addDays(SickLeaveUtils.VKK_DAYS);
                dateVKKWithoutHolidays = handleOffsetForHolidays(dateVKK);
            }
    
            if (dateVKKWithoutHolidays != null && (Date.today() >= dateVKKWithoutHolidays - DAYS_BEFORE_NOTICE)) {
                NotificationWrapper notice = new NotificationWrapper().createNoticeFromSickLeave(
                    sickLeave, FIELD_APINAME_NOTICE_VKK, dateVKK, sickLeave);
                notificationList.add(notice);
            }
        }
    }

    private static void addSickLeaveEndIsolationNotification(List<NotificationWrapper> notificationList, Sick_leave__c sickLeave) {
        if (sickLeave.Is_Ready_Notice_Isolation__c == false) {
            Date dateEndIsolation = Date.valueOf(sickLeave.get(SickLeaveUtils.FIELD_APINAME_END_ISOLATION));
            Date dateEndIsolationWithoutHolidays;
            if (dateEndIsolation != null) {
                dateEndIsolationWithoutHolidays = handleOffsetForHolidays(dateEndIsolation);
            }

            if (dateEndIsolationWithoutHolidays != null && (Date.today() >= dateEndIsolationWithoutHolidays - DAYS_BEFORE_NOTICE)) {
                NotificationWrapper notice = new NotificationWrapper().createNoticeFromSickLeave(
                    sickLeave, FIELD_APINAME_NOTICE_END_ISOLATION, dateEndIsolation, sickLeave);
                notificationList.add(notice);
            }
        }
    }

    private static void addCTScanDateNotification(List<NotificationWrapper> notificationList, Sick_leave__c sickLeave) {
        for (CT_scan__c ctScan : sickLeave.CT_scan__r) {
            Datetime datetimeCTScan = Datetime.valueOf(ctScan.get(SickLeaveUtils.FIELD_APINAME_DATETIME_SC_SCAN));
            Date dateCTScanWithoutHolidays;
            if (datetimeCTScan != null) {
                dateCTScanWithoutHolidays = handleOffsetForHolidays(datetimeCTScan.date());
            }
    
            if (dateCTScanWithoutHolidays != null && (Date.today() >= dateCTScanWithoutHolidays - DAYS_BEFORE_NOTICE)) {
                NotificationWrapper notice = new NotificationWrapper().createNoticeFromSickLeave(
                    sickLeave, FIELD_APINAME_NOTICE_CT_SCAN, datetimeCTScan, ctScan);
                notificationList.add(notice);
            }
        }
    }

    private static void addSmearCovidDateNotification(List<NotificationWrapper> notificationList, Sick_leave__c sickLeave) {
        for (Smear_Covid__c smearCovid : sickLeave.Smear_Covid__r) {
            Date dateSmearCovid = Date.valueOf(smearCovid.get(SickLeaveUtils.FIELD_APINAME_DATE_SWEAR));
            Date dateSmearCovidWithoutHolidays;
            if (dateSmearCovid != null) {
                dateSmearCovidWithoutHolidays = handleOffsetForHolidays(dateSmearCovid);
            }
    
            if (dateSmearCovidWithoutHolidays != null && (Date.today() >= dateSmearCovidWithoutHolidays - DAYS_BEFORE_NOTICE)) {
                NotificationWrapper notice = new NotificationWrapper().createNoticeFromSickLeave(
                    sickLeave, FIELD_APINAME_NOTICE_SMEAR, dateSmearCovid, smearCovid);
                notificationList.add(notice);
            }
        }
    }

    private static void addExpressTestDateNotification(List<NotificationWrapper> notificationList, Sick_leave__c sickLeave) {
        for (Express_Test__c expressTest : sickLeave.Express_Test__r) {
            Date dateExpressTest = Date.valueOf(expressTest.get(SickLeaveUtils.FIELD_APINAME_DATE_EXPRESS_TEST));
            Date dateExpressTestWithoutHolidays;
            if (dateExpressTest != null) {
                dateExpressTestWithoutHolidays = handleOffsetForHolidays(dateExpressTest);
            }
    
            if (dateExpressTestWithoutHolidays != null && (Date.today() >= dateExpressTestWithoutHolidays - DAYS_BEFORE_NOTICE)) {
                NotificationWrapper notice = new NotificationWrapper().createNoticeFromSickLeave(
                    sickLeave, FIELD_APINAME_NOTICE_EXPRESS_TEST, dateExpressTest, expressTest);
                notificationList.add(notice);
            }
        }
    }

    private static Date handleOffsetForHolidays(Date dateNotice) {
        Date dateWithoutHolidays;

        if (dateNotice != null) {
            Datetime dateTimeNotice = (DateTime)dateNotice;
            String dayOfWeek = dateTimeNotice.format('u');
    
            if (dayOfWeek.equals('7')) {
                dateWithoutHolidays = dateNotice.addDays(-2);
            } else if (dayOfWeek.equals('6')) {
                dateWithoutHolidays = dateNotice.addDays(-1);
            } else {
                dateWithoutHolidays = dateNotice;
            }
        }

        return dateWithoutHolidays;
    }

    private static List<SObject> selectRecordsBySObjectNameAndId(String SObjectName, Set<String> ids) {
        String queryFormat = 'SELECT {0} FROM {1} WHERE Id IN :ids';

        List<String> params = new List<String>{
            ASSOCIATED_SOBJECT_TO_FIELDS.get(SObjectName), SObjectName};

        return Database.query(String.format(queryFormat, params));
    }
}
