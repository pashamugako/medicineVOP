trigger ExpressTestTrigger on Express_Test__c (after insert, after update) {
    for (Express_Test__c expressTest : Trigger.new) {
        Id sickLeaveId = expressTest.Sick_leave__c;
        String resultExpressTest = expressTest.Result__c;
        if (expressTest != null 
                && String.isNotEmpty(sickLeaveId)
                && String.isNotEmpty(resultExpressTest) 
                && resultExpressTest.contains(SickLeaveUtils.EXPRESS_TEST_IGM_PLUS)) {
            SickLeaveUtils.updateSickLeaveFromExpressTest(expressTest);
        }
    }
}