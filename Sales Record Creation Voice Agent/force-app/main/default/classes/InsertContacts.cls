/**
 * @description Invocable Apex class to create Contact records.
 * Handles batch requests and provides responses for each creation attempt.
 */
public with sharing class InsertContacts {

    /**
     * @description Invocable method to create one or more Contact records.
     * @param requests A list of ContactRequest objects, each containing details for a Contact.
     * @return A list of ContactResponse objects, indicating the outcome for each requested Contact creation.
     */
    @InvocableMethod(
        label='Create Contacts'
        description='Creates new Contact records with the provided details. Handles multiple requests in a batch.'
        category='Contact Management'
    )
    public static List<ContactResponse> createContacts(List<ContactRequest> requests) {
        List<ContactResponse> responses = new List<ContactResponse>();
        for (Integer i = 0; i < requests.size(); i++) {
            responses.add(new ContactResponse());
        }

        List<ContactWrapper> contactsToProcess = new List<ContactWrapper>();

        for (Integer i = 0; i < requests.size(); i++) {
            ContactRequest req = requests.get(i);
            ContactResponse res = responses.get(i);

            if (String.isBlank(req.lastName)) {
                res.message = 'Last Name is required for a Contact.';
                continue;
            }
            
            if (String.isNotBlank(req.accountId)) {
                 if (req.accountId.length() != 15 && req.accountId.length() != 18) {
                    res.message = 'Account ID has an invalid format. It must be 15 or 18 characters long.';
                    continue;
                }
                try {
                    Id.valueOf(req.accountId); // Validate format
                } catch (System.StringException e) {
                    res.message = 'Invalid Account ID format: ' + req.accountId + '. Error: ' + e.getMessage();
                    continue;
                }
            }
            // Basic email format validation (optional, can be more robust)
            if (String.isNotBlank(req.email) && !Pattern.matches('^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$', req.email)) {
                res.message = 'Invalid Email format provided.';
                continue;
            }

            Contact con = new Contact();
            con.FirstName = String.isNotBlank(req.firstName) ? req.firstName : null;
            con.LastName = req.lastName;
            
            if (String.isNotBlank(req.accountId)) {
                con.AccountId = req.accountId;
            }

            // Optional Fields
            con.Title = String.isNotBlank(req.title) ? req.title : null;
            con.Phone = String.isNotBlank(req.phone) ? req.phone : null;
            con.MobilePhone = String.isNotBlank(req.mobilePhone) ? req.mobilePhone : null;
            con.Email = String.isNotBlank(req.email) ? req.email : null;
            con.Fax = String.isNotBlank(req.fax) ? req.fax : null;
            con.Department = String.isNotBlank(req.department) ? req.department : null;
            con.LeadSource = String.isNotBlank(req.leadSource) ? req.leadSource : null; // Valid picklist API name
            con.Birthdate = req.birthdate;
            con.Description = String.isNotBlank(req.description) ? req.description : null;

            // Mailing Address
            con.MailingStreet = String.isNotBlank(req.mailingStreet) ? req.mailingStreet : null;
            con.MailingCity = String.isNotBlank(req.mailingCity) ? req.mailingCity : null;
            con.MailingState = String.isNotBlank(req.mailingState) ? req.mailingState : null;
            con.MailingPostalCode = String.isNotBlank(req.mailingPostalCode) ? req.mailingPostalCode : null;
            con.MailingCountry = String.isNotBlank(req.mailingCountry) ? req.mailingCountry : null;

            // Other Address 
            con.OtherStreet = String.isNotBlank(req.otherStreet) ? req.otherStreet : null;
            con.OtherCity = String.isNotBlank(req.otherCity) ? req.otherCity : null;
            con.OtherState = String.isNotBlank(req.otherState) ? req.otherState : null;
            con.OtherPostalCode = String.isNotBlank(req.otherPostalCode) ? req.otherPostalCode : null;
            con.OtherCountry = String.isNotBlank(req.otherCountry) ? req.otherCountry : null;
            
            contactsToProcess.add(new ContactWrapper(i, con));
        }

        List<Contact> actualContactsToInsert = new List<Contact>();
        for (ContactWrapper wrapper : contactsToProcess) {
            actualContactsToInsert.add(wrapper.contactRec);
        }

        if (!actualContactsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(actualContactsToInsert, false);

            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                ContactWrapper wrapper = contactsToProcess.get(j);
                ContactResponse res = responses.get(wrapper.originalRequestIndex);

                if (sr.isSuccess()) {
                    res.success = true;
                    res.contactId = sr.getId();
                    res.message = 'Contact created successfully.';
                } else {
                    String errorMessages = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages += err.getStatusCode() + ': ' + err.getMessage() + '. Fields: ' + String.join(err.getFields(), ', ') + ' ';
                    }
                    res.message = 'Error creating Contact: ' + errorMessages.trim();
                }
            }
        }
        return responses;
    }

    private class ContactWrapper {
        Integer originalRequestIndex;
        Contact contactRec;
        ContactWrapper(Integer index, Contact con) {
            this.originalRequestIndex = index;
            this.contactRec = con;
        }
    }

    public class ContactRequest {
        @InvocableVariable(label='First Name' description='First name of the contact.' required=false)
        public String firstName;

        @InvocableVariable(label='Last Name' description='Last name of the contact.' required=true)
        public String lastName;

        @InvocableVariable(label='Account ID' description='ID of the Account this contact is associated with. Must be a valid 15 or 18 character Salesforce ID.' required=false)
        public String accountId;

        @InvocableVariable(label='Title' description='Job title of the contact.' required=false)
        public String title;

        @InvocableVariable(label='Phone' description='Primary phone number of the contact.' required=false)
        public String phone;

        @InvocableVariable(label='Mobile Phone' description='Mobile phone number of the contact.' required=false)
        public String mobilePhone;

        @InvocableVariable(label='Email' description='Email address of the contact.' required=false)
        public String email;
        
        @InvocableVariable(label='Fax' description='Fax number of the contact.' required=false)
        public String fax;

        @InvocableVariable(label='Department' description='Department of the contact.' required=false)
        public String department;

        @InvocableVariable(label='Lead Source' description='Source of the contact (e.g., "Web", "Referral"). Must be a valid picklist API name.' required=false)
        public String leadSource;

        @InvocableVariable(label='Birthdate' description='Birthdate of the contact. Format: YYYY-MM-DD.' required=false)
        public Date birthdate;

        @InvocableVariable(label='Description' description='Additional notes or description for the contact.' required=false)
        public String description;

        // Mailing Address
        @InvocableVariable(label='Mailing Street' description='Mailing street address.' required=false)
        public String mailingStreet;
        @InvocableVariable(label='Mailing City' description='Mailing city.' required=false)
        public String mailingCity;
        @InvocableVariable(label='Mailing State/Province' description='Mailing state or province.' required=false)
        public String mailingState;
        @InvocableVariable(label='Mailing Zip/Postal Code' description='Mailing zip or postal code.' required=false)
        public String mailingPostalCode;
        @InvocableVariable(label='Mailing Country' description='Mailing country.' required=false)
        public String mailingCountry;

        // Other Address
        @InvocableVariable(label='Other Street' description='Other street address.' required=false)
        public String otherStreet;
        @InvocableVariable(label='Other City' description='Other city.' required=false)
        public String otherCity;
        @InvocableVariable(label='Other State/Province' description='Other state or province.' required=false)
        public String otherState;
        @InvocableVariable(label='Other Zip/Postal Code' description='Other zip or postal code.' required=false)
        public String otherPostalCode;
        @InvocableVariable(label='Other Country' description='Other country.' required=false)
        public String otherCountry;
    }

    public class ContactResponse {
        @InvocableVariable(label='Contact ID' description='ID of the newly created Contact.')
        public String contactId;
        @InvocableVariable(label='Success' description='True if creation was successful.')
        public Boolean success;
        @InvocableVariable(label='Message' description='Status message.')
        public String message;

        public ContactResponse() {
            this.success = false; this.message = ''; this.contactId = null;
        }
    }
}