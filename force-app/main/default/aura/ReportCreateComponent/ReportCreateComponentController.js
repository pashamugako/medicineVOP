({
    init : function(component, event, helper) {
        helper.handleInit(component);
    },
    createCovid : function(component, event, helper) {
        let isCovid = true;
        helper.handleCreateReport(component, helper.getCovidReportAction(component), isCovid);
    }, 
    createContact : function(component, event, helper) {
        let isCovid = false;
        helper.handleCreateReport(component, helper.getContactReportAction(component), isCovid);
    }
})