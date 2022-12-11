import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import HOME_PAGE_IMAGE from '@salesforce/resourceUrl/fslHomePageWelcomeImage';
import SERKIN_SOLUTIONS_LOGO from '@salesforce/resourceUrl/serkinSolutionsLogo';
import USER_FIRSTNAME_FIELD from '@salesforce/schema/User.FirstName';
import USER_ID from '@salesforce/user/Id';

export default class FslHomePageComponent extends LightningElement {
    @api cardTitle;
    @api cardIcon;

    isLoading = false;
    error;

    homePageWelcomeImage = HOME_PAGE_IMAGE;
    serkinSolutionsLogoImage = SERKIN_SOLUTIONS_LOGO;

    userId = USER_ID;
    userFirstName;

    @wire(getRecord, { recordId: '$userId', fields: [ USER_FIRSTNAME_FIELD ]}) 
    userDetails({error, data}) {
        if (data) {
            this.userFirstName = data.fields.FirstName.value;
        } else if (error) {
            this.error = error ;
        }
    }

    get cardTitleAndUser() {
        return `${this.cardTitle}, ${this.userFirstName}!`;
    }

}