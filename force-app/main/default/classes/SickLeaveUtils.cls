public with sharing class SickLeaveUtils {
    public static final String SMEAR_POSITIVE = 'Positive';
    public static final String SMEAR_NEGATIVE = 'Negative';
    public static final String CT_POSITIVE = 'Yes';
    public static final String CT_NEGATIVE = 'No';
    public static final String EXPRESS_TEST_IGM_PLUS = 'IgM+';
    public static final String FIELD_APINAME_DATE_SWEAR = 'Date_Smear__c';
    public static final String FIELD_APINAME_DATE_EXPRESS_TEST = 'Date_Express_Test__c';
    public static final String EXCEPTION_SICK_LEAVE_NOT_EXIST = 'Sick leave element does not exist!';
    public static final String DIAGNOSIS_COVID = 'B34.2';
    public static final String DIAGNOSIS_PNEUMONIA = 'J18';
    public static final String DIAGNOSIS_COVID_PNEUMONIA = 'B97.2';
    public static final String DIAGNOSIS_COLD = 'J06.9';
    public static final String DIAGNOSIS_CONTACT = 'Z20.8';

    public static void updateSickLeaveFromSmear(Smear_Covid__c smear) {
        Sick_leave__c sickLeave = getSickLeaveRecord(smear.Sick_leave__c);

        Boolean isDateSmearUpdated = setDateSickLeave(
            sickLeave, smear.Date_Smear__c, FIELD_APINAME_DATE_SWEAR);
        Boolean isDiagnosisUpdated = addDiagnosisCovid(sickLeave);

        if (isDateSmearUpdated || isDiagnosisUpdated) {
            update sickLeave;
        }
    }

    public static void updateSickLeaveFromExpressTest(Express_Test__c expressTest) {
        Sick_leave__c sickLeave = getSickLeaveRecord(expressTest.Sick_leave__c);

        Boolean isDateExpressTestUpdated = setDateSickLeave(
            sickLeave, expressTest.Date_Express_Test__c, FIELD_APINAME_DATE_EXPRESS_TEST);
        Boolean isDiagnosisUpdated = addDiagnosisCovid(sickLeave);

        if (isDateExpressTestUpdated || isDiagnosisUpdated) {
            update sickLeave;
        }
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

    private static Boolean addDiagnosisCovid(Sick_leave__c sickLeave){
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
            [SELECT Id, Date_Smear__c, Date_Express_Test__c, Diagnosis__c 
            FROM Sick_leave__c 
            WHERE Id = :idSickLeave];

        if (sickLeaves == null || sickLeaves.isEmpty()) {
            throw new SickLeaveException(EXCEPTION_SICK_LEAVE_NOT_EXIST);
        }
        
        return sickLeaves.get(0);
    }
}