public with sharing class ReportCreateComponentController {
    public static final String MESSAGE_SICK_LEAVE_NOT_SUIT = 'Для выбранного месяца нету данных.';
    private static final String API_NAME_SMEAR = 'Smear_Covid__c';
    private static final String API_NAME_EXPRESS_TEST = 'Express_Test__c';
    
    @AuraEnabled
    public static String returnCovidReport(String month, String year){
        List<String> resultList = new List<String>();
        List<CovidBuilder> covidBuilderList = new List<CovidBuilder>();
        List<Sick_leave__c> sickLeaves = getSickLeaveRecordsCovid(month, year);

        for (Sick_leave__c sickLeave : sickLeaves) {
            for (Examination__c examination : sickLeave.Examination__r) {
                Date examinationDate = examination.Date_Examination__c;
                Boolean isdateExaminationRight = isDateExaminationMoreDateTestCovid(
                    examinationDate, sickLeave.Smear_Covid__r, sickLeave.Express_Test__r);

                if (isdateExaminationRight) {
                    CovidBuilder covid = new CovidBuilder()
                        .setName((String) sickLeave.getSObject('Patient__r').get('Name'))
                        .setSmear(new BuilderTestAnalysis(sickLeave.Date_Smear__c, sickLeave.Smear_Covid__r, 'Smear_Covid__c'))
                        .setExpressTest(new BuilderTestAnalysis(sickLeave.Date_Express_Test__c, sickLeave.Express_Test__r, 'Express_Test__c'))
                        .setDateLetter(sickLeave.Date_Letter__c)
                        .setLetterText(sickLeave.Letter_Text__c)
                        .setEmergencyNotification(sickLeave.Emergency_Notification__c)
                        .setPatient(new BuilderPatient(sickLeave))
                        .setDateExamination(examinationDate);
                    
                    covidBuilderList.add(covid);
                }
            }
        }

        covidBuilderList.sort();
        for (CovidBuilder covid : covidBuilderList) {
            resultList.add(covid.buildCovid());
        }

        String result;
        if (resultList.isEmpty()) {
            result = MESSAGE_SICK_LEAVE_NOT_SUIT;
        } else {
            result = String.join(resultList, '\n');
        }

        return result;
    }

    @AuraEnabled
    public static String returnContactReport(String month, String year){
        List<String> resultList = new List<String>();
        List<CovidBuilder> covidBuilderList = new List<CovidBuilder>();
        List<Sick_leave__c> sickLeaves = getSickLeaveRecordsContact(month, year);

        for (Sick_leave__c sickLeave : sickLeaves) {
            for (Examination__c examination : sickLeave.Examination__r) {
                Date examinationDate = examination.Date_Examination__c;
                Date contactDate = sickLeave.Date_Contact__c;
                //to do - maybe exception, if sickLeave.Date_Contact__c == null ?
                if (contactDate == null || examinationDate >= contactDate) {
                    CovidBuilder covid = new CovidBuilder()
                        .setName((String) sickLeave.getSObject('Patient__r').get('Name'))
                        .setPatient(new BuilderPatient(sickLeave))
                        .setDateExamination(examinationDate);
                    
                    covidBuilderList.add(covid);
                }
            }
        }

        covidBuilderList.sort();
        for (CovidBuilder covid : covidBuilderList) {
            resultList.add(covid.buildContact());
        }

        String result;
        if (resultList.isEmpty()) {
            result = MESSAGE_SICK_LEAVE_NOT_SUIT;
        } else {
            result = String.join(resultList, '\n');
        }

        return result;
    }

    private static List<Sick_leave__c> getSickLeaveRecordsCovid(String monthString, String yearString) {
        Integer month = Integer.valueOf(monthString); 
        Integer year = Integer.valueOf(yearString); 
        Date firstDate = Date.newInstance(year, month, 1);
        Date lastDate = Date.newInstance(year, month, Date.daysInMonth(year, month));

        List<String> diagnosisesWithCovid = new List<String>{
            SickLeaveUtils.DIAGNOSIS_COVID,
            SickLeaveUtils.DIAGNOSIS_COVID_PNEUMONIA
        };
        String expressTestIgMPlus = '%' + SickLeaveUtils.EXPRESS_TEST_IGM_PLUS + '%';

        List<Sick_leave__c> sickLeaves = 
            [SELECT Date_Smear__c,Date_Express_Test__c,Date_Letter__c,Letter_Text__c,Diagnosis__c,Emergency_Notification__c,
                Patient__r.Second_Name__c,Patient__r.First_Name__c,Patient__r.Patronymic__c,Patient__r.Name,
                (
                    SELECT Date_Examination__c 
                    FROM Examination__r 
                    WHERE Date_Examination__c >= :firstDate AND Date_Examination__c <= :lastDate),
                (
                    SELECT Date_Smear__c,Number_Smear__c,Result__c,	Report_Additional_Text__c 
                    FROM Smear_Covid__r
                    WHERE Result__c = :SickLeaveUtils.SMEAR_POSITIVE),
                (
                    SELECT Date_Express_Test__c,Number_Test__c,Result__c,Report_Additional_Text__c 
                    FROM Express_Test__r
                    WHERE Result__c LIKE :expressTestIgMPlus)
            FROM Sick_leave__c
            WHERE 
                Id IN (
                    SELECT Sick_leave__c
                    FROM Examination__c 
                    WHERE Date_Examination__c >= :firstDate AND Date_Examination__c <= :lastDate)
                AND Diagnosis__c IN :diagnosisesWithCovid];
        
        return sickLeaves;
    }

    private static Boolean isDateExaminationMoreDateTestCovid(Date dateExamination, List<Smear_Covid__c> smears, List<Express_Test__c> expressTests) {
        Boolean result = false;
        if (dateExamination != null) {
            if (smears != null) {
                for (Smear_Covid__c smear : smears) {
                    Date dateSmear = smear.Date_Smear__c; 
                    if (dateSmear != null && dateExamination >= dateSmear) {
                        result = true;
                        break;
                    }
                }
            }
            if (expressTests != null && result == false) {
                for (Express_Test__c expressTest : expressTests) {
                    Date dateExpressTest = expressTest.Date_Express_Test__c; 
                    if (dateExpressTest != null && dateExamination >= dateExpressTest) {
                        result = true;
                        break;
                    }
                }
            }
        }

        return result;
    }

    private static List<Sick_leave__c> getSickLeaveRecordsContact(String monthString, String yearString) {
        Integer month = Integer.valueOf(monthString); 
        Integer year = Integer.valueOf(yearString); 
        Date firstDate = Date.newInstance(year, month, 1);
        Date lastDate = Date.newInstance(year, month, Date.daysInMonth(year, month));

        String diagnosisesWithContact = '%' + SickLeaveUtils.DIAGNOSIS_CONTACT + '%';

        List<Sick_leave__c> sickLeaves = 
            [SELECT Name,Date_Contact__c,Diagnosis__c,
                Patient__r.Second_Name__c,Patient__r.First_Name__c,Patient__r.Patronymic__c,Patient__r.Name,
                (
                    SELECT Date_Examination__c 
                    FROM Examination__r 
                    WHERE Date_Examination__c >= :firstDate AND Date_Examination__c <= :lastDate)
            FROM Sick_leave__c
            WHERE 
                Id IN (
                    SELECT Sick_leave__c
                    FROM Examination__c 
                    WHERE Date_Examination__c >= :firstDate AND Date_Examination__c <= :lastDate)
                AND Diagnosis__c LIKE :diagnosisesWithContact];
        
        return sickLeaves;
    }

    private class CovidBuilder implements Comparable {
        private String name;
        private BuilderTestAnalysis smear;
        private BuilderTestAnalysis expressTest;
        private Datetime dateLetter;
        private String letterText;
        private String emergencyNotification;
        private BuilderPatient patient;
        private Date dateExamination;

        public CovidBuilder setName(String name){
            this.name = name;
            return this;
        }
        public CovidBuilder setSmear(BuilderTestAnalysis smear){
            this.smear = smear;
            return this;
        }
        public CovidBuilder setExpressTest(BuilderTestAnalysis expressTest){
            this.expressTest = expressTest;
            return this;
        }
        public CovidBuilder setDateLetter(Datetime dateLetter){
            this.dateLetter = dateLetter;
            return this;
        }
        public CovidBuilder setLetterText(String letterText){
            this.letterText = letterText;
            return this;
        }
        public CovidBuilder setEmergencyNotification(String emergencyNotification){
            this.emergencyNotification = emergencyNotification;
            return this;
        }
        public CovidBuilder setPatient(BuilderPatient patient){
            this.patient = patient;
            return this;
        }
        public CovidBuilder setDateExamination(Date dateExamination){
            this.dateExamination = dateExamination;
            return this;
        }
        
        public String buildCovid(){
            //to do - null for all
            String result = this.patient.buildNameInitials();
            result += ' а/к' + this.name + ' (';

            List<String> testAnalysisList = new List<String>();
            if (this.smear != null && this.smear.isContainTestAnalysis()) {
                testAnalysisList.add(this.smear.build());
            }
            if (this.expressTest != null && this.expressTest.isContainTestAnalysis()) {
                testAnalysisList.add(this.expressTest.build());
            }
            if (String.isNotEmpty(this.emergencyNotification)) {
                testAnalysisList.add('экстр. изв. от ' + this.emergencyNotification);
            }
            if (String.isNotEmpty(this.letterText) || this.dateLetter != null) {
                String letter = 'письмо МЗЦГиЭ';
                if (String.isNotEmpty(this.letterText)){
                    letter += ' исх №' + this.letterText;
                }
                if (this.dateLetter != null){
                    letter += ' от ' + this.dateLetter.date().format();
                }
                testAnalysisList.add(letter);
            }
            result += String.join(testAnalysisList, ', ');

            result += ') - дата осмотра: ' + this.dateExamination.format();

            return result;
        }
        
        public String buildContact(){
            //to do - null for all
            String result = this.patient.buildNameInitials();
            result += ' а/к' + this.name;
            result += ' - дата осмотра: ' + this.dateExamination.format();

            return result;
        }

        public Integer compareTo(Object compareTo) {
            CovidBuilder covid = (CovidBuilder) compareTo;
            Integer result;
            if (covid.dateExamination == null || this.dateExamination > covid.dateExamination) {
                result = 1;
            } else if (this.dateExamination == null || this.dateExamination < covid.dateExamination) {
                result = -1;
            } else {
                result = 0;   
            }
            
            return result;
        }
    }

    private class BuilderTestAnalysis {
        private Date dateTest {get; private set;}
        private String numberTest {get; private set;}
        private String additionalText {get; private set;}
        private String sobjectApiName {get; private set;}
        private List<BuilderTestAnalysis> builderTestAnalysisList;

        public BuilderTestAnalysis(Date dateCovid, List<SObject> testAnalysisList, String sobjectApiName) {
            this.builderTestAnalysisList = new List<BuilderTestAnalysis>();
            this.sobjectApiName = sobjectApiName;

            if (testAnalysisList != null && !testAnalysisList.isEmpty()) {
                for (SObject testAnalysis : testAnalysisList) {
                    BuilderTestAnalysis builderTestAnalysisRecord;
                    if (API_NAME_SMEAR.equals(sobjectApiName)) {
                        builderTestAnalysisRecord = createSmear(testAnalysis);
                    } else {
                        builderTestAnalysisRecord = createExpressTest(testAnalysis);
                    }

                    if (builderTestAnalysisRecord != null) {
                        this.builderTestAnalysisList.add(builderTestAnalysisRecord);
                    }
                }
            }
            
            if (dateCovid != null && this.builderTestAnalysisList.isEmpty()) {
                this.builderTestAnalysisList.add(new BuilderTestAnalysis(dateCovid, '', ''));
            }
        }

        public Boolean isContainTestAnalysis(){
            return !this.builderTestAnalysisList.isEmpty();
        }

        public String build(){
            List<String> resultList = new List<String>();
            final String textSwear;
            if (API_NAME_SMEAR.equals(sobjectApiName)) {
                textSwear = 'ПЦР';
            } else {
                textSwear = 'IgM+';
            }
            final String textDate = 'от ';
            final String textNumber = '№';

            for (BuilderTestAnalysis builderTestAnalysis : builderTestAnalysisList) {
                Date dateTestAnalysis = builderTestAnalysis.dateTest;
                String numberTestAnalysis = builderTestAnalysis.numberTest;
                String additionalTestAnalysis = builderTestAnalysis.additionalText;

                List<String> testAnalysis = new List<String>{textSwear};
                if (dateTestAnalysis != null){
                    testAnalysis.add(textDate + dateTestAnalysis.format());
                }
                if (String.isNotEmpty(numberTestAnalysis)){
                    testAnalysis.add(textNumber + numberTestAnalysis);
                }
                if (String.isNotEmpty(additionalTestAnalysis)){
                    testAnalysis.add(additionalTestAnalysis);
                }

                resultList.add(String.join(testAnalysis, ' '));
            }

            return String.join(resultList, ', ');
        }

        private BuilderTestAnalysis(Date dateTest, String numberTest, String additionalText) {
            this.dateTest = dateTest;
            this.numberTest = numberTest;
            this.additionalText = additionalText;
        }

        private BuilderTestAnalysis createSmear(SObject smear) {
            BuilderTestAnalysis builderSmear;
            Date dateTestAnalysis = (Date) smear.get('Date_Smear__c');
            String numberTestAnalysis = (String) smear.get('Number_Smear__c');
            String additionalTestAnalysis = (String) smear.get('Report_Additional_Text__c');

            if (dateTestAnalysis != null || String.isNotEmpty(numberTestAnalysis) || String.isNotEmpty(additionalTestAnalysis)) {
                builderSmear = new BuilderTestAnalysis(dateTestAnalysis, numberTestAnalysis, additionalTestAnalysis);
            }

            return builderSmear;
        }

        private BuilderTestAnalysis createExpressTest(SObject expressTest) {
            BuilderTestAnalysis builderExpressTest;
            Date dateTestAnalysis = (Date) expressTest.get('Date_Express_Test__c');
            String numberTestAnalysis = (String) expressTest.get('Number_Test__c');
            String additionalTestAnalysis = (String) expressTest.get('Report_Additional_Text__c');

            if (dateTestAnalysis != null || String.isNotEmpty(numberTestAnalysis) || String.isNotEmpty(additionalTestAnalysis)) {
                builderExpressTest = new BuilderTestAnalysis(dateTestAnalysis, numberTestAnalysis, additionalTestAnalysis);
            }

            return builderExpressTest;
        }
    }
}