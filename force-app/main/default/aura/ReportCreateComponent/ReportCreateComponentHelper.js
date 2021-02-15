({
    constants: {
        attributes: {
            IS_LOADING: 'v.isLoading',
            MONTH_VALUE: 'v.monthValue',
            YEAR_VALUE: 'v.yearValue',
            RESULT_REPORT: 'v.resultReport',
            HEADER_RESULT: 'v.headerResult'
        },

        actions: {
            GET_COVID_REPORT: 'c.returnCovidReport',
            GET_CONTACT_REPORT: 'c.returnContactReport'
        },

        utils: {
            SUCCESS: 'SUCCESS',
            MESSAGE_SUCCESS: 'success',
            MESSAGE_ERROR: 'error',
            MESSAGE_NOT_POPULATED: 'Проверьте поля для месяца и года и повторите попытку!',
            MESSAGE_ERROR_COVID: 'Ошибка обработки отчета для Ковид+!',
            MESSAGE_ERROR_CONTACT: 'Ошибка обработки отчета для Контактов!',
            HEADER_RESULT_COVID: 'Результат отчета по Ковид+:',
            HEADER_RESULT_CONTACT: 'Результат отчета по Контактам:'
        }
    },

    handleInit: function (component) {
        let todayMonth = $A.localizationService.formatDate(new Date(), "M");
        let todayYear = $A.localizationService.formatDate(new Date(), "YYYY");
        this.setMonthValue(component, todayMonth);
        this.setYearValue(component, todayYear);
    },

    handleCreateReport: function (component, action, isCovid) {
        if (!this.checkRequaredFields(component)) {
            return;
        }

        this.setIsLoading(component, true);
        action.setParams({
            month: this.getMonthValue(component),
            year: this.getYearValue(component)
        });

        let errorMessage;
        let headerMessage;
        if (isCovid) {
            errorMessage = this.constants.utils.MESSAGE_ERROR_COVID;
            headerMessage = this.constants.utils.HEADER_RESULT_COVID;
        } else {
            errorMessage = this.constants.utils.MESSAGE_ERROR_CONTACT;
            headerMessage = this.constants.utils.HEADER_RESULT_CONTACT;
        }

        action.setCallback(this, function (response) {
            let state = response.getState();
            let responceData;
            if (state === this.constants.utils.SUCCESS) {
                responceData = response.getReturnValue();
                if (responceData) {
                    this.setResultReport(component, responceData);
                    this.setHeaderResult(component, headerMessage);
                } else {
                    this.showToastMessage(errorMessage, this.constants.utils.MESSAGE_ERROR);
                }
            } else {
                this.showToastMessage(errorMessage, this.constants.utils.MESSAGE_ERROR);
            }
            this.setIsLoading(component, false);
        });
        $A.enqueueAction(action);
    },

    checkRequaredFields: function (component) {
        let allFieldValid = false;
        if (this.getMonthValue(component) && this.getYearValue(component)) {
            allFieldValid = true;
        } else {
            this.showToastMessage(this.constants.utils.MESSAGE_NOT_POPULATED, this.constants.utils.MESSAGE_ERROR);
        }

        return allFieldValid;
    },

    showToastMessage: function (errorMessage, typeMessage) {
        $A.get('e.force:showToast').setParams({
            'message': errorMessage,
            'type': typeMessage,
        }).fire();
    },

    getMonthValue: function (cmp) {
        return cmp.get(this.constants.attributes.MONTH_VALUE);
    },
    getYearValue: function (cmp) {
        return cmp.get(this.constants.attributes.YEAR_VALUE);
    },
    getCovidReportAction: function (cmp) {
        return cmp.get(this.constants.actions.GET_COVID_REPORT);
    },
    getContactReportAction: function (cmp) {
        return cmp.get(this.constants.actions.GET_CONTACT_REPORT);
    },

	setIsLoading: function (cmp, isLoading) {
		cmp.set(this.constants.attributes.IS_LOADING, isLoading);
	},
	setResultReport: function (cmp, resultReport) {
		cmp.set(this.constants.attributes.RESULT_REPORT, resultReport);
	},
	setHeaderResult: function (cmp, headerResult) {
		cmp.set(this.constants.attributes.HEADER_RESULT, headerResult);
	},
    setMonthValue: function (cmp, monthValue) {
        cmp.set(this.constants.attributes.MONTH_VALUE, monthValue);
    },
    setYearValue: function (cmp, yearValue) {
        cmp.set(this.constants.attributes.YEAR_VALUE, yearValue);
    }
})