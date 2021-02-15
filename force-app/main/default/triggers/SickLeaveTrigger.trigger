trigger SickLeaveTrigger on Sick_leave__c (before insert, before update) {
    for (Sick_leave__c sickLeave : Trigger.new) {
        SickLeaveUtils.setEndIsolationDayContact(sickLeave);
    }
}