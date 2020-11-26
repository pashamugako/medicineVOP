trigger SmearCovidTrigger on Smear_Covid__c (after insert, after update) {
    for (Smear_Covid__c smear : Trigger.new) {
        if (smear != null 
                && String.isNotEmpty(smear.Sick_leave__c)
                && SickLeaveUtils.SMEAR_POSITIVE.equals(smear.Result__c)) {
            SickLeaveUtils.updateSickLeaveFromSmear(smear);
        }
    }
}