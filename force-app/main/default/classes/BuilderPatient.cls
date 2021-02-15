public with sharing class BuilderPatient {
    private String secondName;
    private String firstName;
    private String patronymic;

    public BuilderPatient(String secondName, String firstName, String patronymic){
        this.secondName = secondName;
        this.firstName = firstName;
        this.patronymic = patronymic;
    }

    public BuilderPatient(Sick_leave__c sickLeave){
        SObject patient = BuilderPatient.getPatientSObject(sickLeave);
        if (patient != null) {
            this.secondName = (String) patient.get('Second_Name__c');
            this.firstName = (String) patient.get('First_Name__c');
            this.patronymic = (String) patient.get('Patronymic__c');
        }
    }

    public String buildNameInitials(){
        String result = '';
        String resultTemplate = '{0} {1}.{2}.';

        if (String.isNotEmpty(this.secondName) && String.isNotEmpty(this.firstName) && String.isNotEmpty(this.patronymic)) {
            List<String> templateList = new List<String>{
                this.secondName, this.firstName.left(1), this.patronymic.left(1)
            };
            result = String.format(resultTemplate, templateList);
        }

        return result;
    }

    public String buildNameFull(){
        String result = '';
        String resultTemplate = '{0} {1} {2}';

        if (String.isNotEmpty(this.secondName) && String.isNotEmpty(this.firstName) && String.isNotEmpty(this.patronymic)) {
            List<String> templateList = new List<String>{
                this.secondName, this.firstName, this.patronymic
            };
            result = String.format(resultTemplate, templateList);
        }

        return result;
    }

    public static String getPhoneFieldValue(Sick_leave__c sickLeave) {
        String phone;
        SObject patient = BuilderPatient.getPatientSObject(sickLeave);

        if (patient != null) {
            phone = (String) patient.get('Mobile__c');
        }

        return phone;
    }

    private static SObject getPatientSObject(Sick_leave__c sickLeave){
        SObject patient;

        if (sickLeave != null) {
            patient = sickLeave.getSObject('Patient__r');
        }

        return patient;
    }
}
