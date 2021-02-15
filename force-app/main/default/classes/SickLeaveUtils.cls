public with sharing class SickLeaveUtils {
    public static final String SMEAR_POSITIVE = 'Positive';
    public static final String SMEAR_NEGATIVE = 'Negative';
    public static final String CT_POSITIVE = 'Yes';
    public static final String CT_NEGATIVE = 'No';
    public static final String EXPRESS_TEST_IGM_PLUS = 'IgM+';
    public static final String STATUS_ACTIVE = 'Active';
    public static final String FIELD_APINAME_DATE_SWEAR = 'Date_Smear__c';
    public static final String FIELD_APINAME_DATE_EXPRESS_TEST = 'Date_Express_Test__c';
    public static final String FIELD_APINAME_DATETIME_SC_SCAN = 'Datetime_CT__c';
    public static final String EXCEPTION_SICK_LEAVE_NOT_EXIST = 'Sick leave element does not exist!';
    public static final String DIAGNOSIS_COVID = 'B34.2';
    public static final String DIAGNOSIS_PNEUMONIA = 'J18';
    public static final String DIAGNOSIS_COVID_PNEUMONIA = 'B97.2';
    public static final String DIAGNOSIS_COLD = 'J06.9';
    public static final String DIAGNOSIS_CONTACT = 'Z20.8';
    public static final Integer ISOLATION_DAYS_COVID = 13;
    public static final Integer ISOLATION_DAYS_CONTACT = 9;
    public static final Integer VKK_DAYS = 29;
    public static final String FIELD_APINAME_END_ISOLATION = 'End_Isolation__c';

    public static void updateSickLeaveFromSmear(Smear_Covid__c smear) {
        Sick_leave__c sickLeave = getSickLeaveRecord(smear.Sick_leave__c);
        handleCovidPositive(sickLeave, smear.Date_Smear__c, FIELD_APINAME_DATE_SWEAR);
    }

    public static void updateSickLeaveFromExpressTest(Express_Test__c expressTest) {
        Sick_leave__c sickLeave = getSickLeaveRecord(expressTest.Sick_leave__c);
        handleCovidPositive(sickLeave, expressTest.Date_Express_Test__c, FIELD_APINAME_DATE_EXPRESS_TEST);
    }

    public static void addPneumoniaToDiagnosis(Id sickLeaveId) {
        Sick_leave__c sickLeave = getSickLeaveRecord(sickLeaveId);
        String oldDiagnosis = sickLeave.Diagnosis__c;

        if (String.isEmpty(oldDiagnosis) || DIAGNOSIS_COLD.equals(oldDiagnosis)) {
            sickLeave.Diagnosis__c = DIAGNOSIS_PNEUMONIA;

        } else if (DIAGNOSIS_COVID.equals(oldDiagnosis)) {
            sickLeave.Diagnosis__c = DIAGNOSIS_COVID_PNEUMONIA;

        } else if (DIAGNOSIS_CONTACT.equals(oldDiagnosis)
                || (oldDiagnosis.contains(DIAGNOSIS_CONTACT) && oldDiagnosis.contains(DIAGNOSIS_COLD))) {
            sickLeave.Diagnosis__c = DIAGNOSIS_CONTACT + ';' + DIAGNOSIS_PNEUMONIA;
        }

        String newDiagnosis = sickLeave.Diagnosis__c;
        if (String.isNotEmpty(newDiagnosis) && !newDiagnosis.equals(oldDiagnosis)) {
            update sickLeave;
        }
    }

    public static void setEndIsolationDayContact(Sick_leave__c sickLeave) {
        Boolean isDiagnosisContact = isDiagnosisContact(sickLeave);
        Boolean isDiagnosisCovid = isDiagnosisCovid(sickLeave);

        Date dateContact = sickLeave.Date_Contact__c;
        Date dateEndIsolationNew;
        if (dateContact != null) {
            if (isDiagnosisContact) {
                dateEndIsolationNew = dateContact.addDays(ISOLATION_DAYS_CONTACT);
            }
            if (isDiagnosisCovid) {
                dateEndIsolationNew = dateContact.addDays(ISOLATION_DAYS_COVID);
            }
        }
    
        if (dateEndIsolationNew != null) {
            sickLeave.put(FIELD_APINAME_END_ISOLATION, dateEndIsolationNew);
        }
    }

    private static void handleCovidPositive(Sick_leave__c sickLeave, Date testDate, String testApiNameField) {
        Boolean isDateTestUpdated = setDateSickLeave(sickLeave, testDate, testApiNameField);

        Boolean isDiagnosisCovid = isDiagnosisCovid(sickLeave);
        Boolean isDiagnosisContactBefore = isDiagnosisContact(sickLeave);

        Boolean isDiagnosisUpdated = addDiagnosisCovid(sickLeave);
        
        isDiagnosisContactBefore = isDiagnosisContactBefore && isDiagnosisCovid(sickLeave);
        isDiagnosisCovid = !isDiagnosisCovid && isDiagnosisCovid(sickLeave);

        Boolean isDateEndIsolationUpdated = setEndIsolationDayCovid(
            sickLeave, testApiNameField, isDiagnosisCovid, isDiagnosisContactBefore);

        if (isDateTestUpdated || isDiagnosisUpdated || isDateEndIsolationUpdated) {
            update sickLeave;
        }
    }

    private static Boolean addDiagnosisCovid(Sick_leave__c sickLeave) {
        Boolean result = true;
        String oldDiagnosis = sickLeave.Diagnosis__c;
        
        if (String.isEmpty(oldDiagnosis) 
                || oldDiagnosis.equals(DIAGNOSIS_COLD)
                || oldDiagnosis.equals(DIAGNOSIS_CONTACT)
                || (oldDiagnosis.contains(DIAGNOSIS_CONTACT) && oldDiagnosis.contains(DIAGNOSIS_COLD))) {
            sickLeave.Diagnosis__c = DIAGNOSIS_COVID;

        } else if (oldDiagnosis.contains(DIAGNOSIS_PNEUMONIA)) {
            sickLeave.Diagnosis__c = DIAGNOSIS_COVID_PNEUMONIA;
        }

        return result;
    }

    private static Boolean setDateSickLeave(Sick_leave__c sickLeave, Date dateValue, String dateApiName){
        Boolean result = false;

        if (dateValue != null) {
            Date dateValueOld = Date.valueOf(sickLeave.get(dateApiName));
    
            if (dateValueOld == null || dateValue < dateValueOld) {
                sickLeave.put(dateApiName, dateValue);
                result = true;
            }
        }

        return result;
    }

    private static Sick_leave__c getSickLeaveRecord(Id idSickLeave) {
        List<Sick_leave__c> sickLeaves = 
            [SELECT Id, Date_Smear__c, Date_Express_Test__c, Diagnosis__c, End_Isolation__c, Date_Contact__c
            FROM Sick_leave__c 
            WHERE Id = :idSickLeave];

        if (sickLeaves == null || sickLeaves.isEmpty()) {
            throw new SickLeaveException(EXCEPTION_SICK_LEAVE_NOT_EXIST);
        }
        
        return sickLeaves.get(0);
    }

    private static Boolean setEndIsolationDayCovid(Sick_leave__c sickLeave, String dateApiName, 
            Boolean isDiagnosisChangedToCovid, Boolean isDiagnosisChangedToCovidFromContact){

        Boolean result = false;
        Date dateBeginIsolation = Date.valueOf(sickLeave.get(dateApiName));
        Date dateEndIsolation = Date.valueOf(sickLeave.get(FIELD_APINAME_END_ISOLATION));
        Date dateContact = sickLeave.Date_Contact__c;

        Date dateEndIsolationNew;
        if (dateContact != null) {
            dateEndIsolationNew = dateContact.addDays(ISOLATION_DAYS_COVID);
        } else if (dateBeginIsolation != null) {
            dateEndIsolationNew = dateBeginIsolation.addDays(ISOLATION_DAYS_COVID);
        }

        if (dateEndIsolationNew != null) {
            if (dateEndIsolation == null 
                || (isDiagnosisChangedToCovid)
                || (isDiagnosisCovid(sickLeave) && dateEndIsolationNew < dateEndIsolation)) {

                sickLeave.put(FIELD_APINAME_END_ISOLATION, dateEndIsolationNew);
                result = true;
            }
        }

        return result;
    }

    private static Boolean isDiagnosisCovid(Sick_leave__c sickLeave){
        Boolean result = false;
        String diagnosis = sickLeave.Diagnosis__c;
        
        if (String.isNotEmpty(diagnosis)) {
            result = diagnosis.equals(DIAGNOSIS_COVID) || diagnosis.equals(DIAGNOSIS_COVID_PNEUMONIA);
        }

        return result;
    }

    private static Boolean isDiagnosisContact(Sick_leave__c sickLeave){
        Boolean result = false;
        String diagnosis = sickLeave.Diagnosis__c;
        
        if (String.isNotEmpty(diagnosis)) {
            result = diagnosis.contains(DIAGNOSIS_CONTACT);
        }

        return result;
    }
}