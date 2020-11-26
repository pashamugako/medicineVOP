trigger CTScanTrigger on CT_scan__c (after insert, after update) {
    for (CT_scan__c ctScan : Trigger.new) {
        Id sickLeaveId = ctScan.Sick_leave__c;
        if (ctScan != null 
                && String.isNotEmpty(sickLeaveId)
                && SickLeaveUtils.CT_POSITIVE.equals(ctScan.Pneumonia__c)) {
            SickLeaveUtils.addPneumoniaToDiagnosis(sickLeaveId);
        }
    }
}