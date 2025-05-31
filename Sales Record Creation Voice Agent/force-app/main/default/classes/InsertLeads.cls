/**
 * @description Invocable Apex class to create Lead records.
 * Handles batch requests and provides responses for each creation attempt.
 */
public with sharing class InsertLeads {

    /**
     * @description Invocable method to create one or more Lead records.
     * @param requests A list of LeadRequest objects, each containing details for a Lead.
     * @return A list of LeadResponse objects, indicating the outcome for each requested Lead creation.
     */
    @InvocableMethod(
        label='Create Leads'
        description='Creates new Lead records with the provided details. Handles multiple requests in a batch.'
        category='Lead Management'
    )
    public static List<LeadResponse> createLeads(List<LeadRequest> requests) {
        List<LeadResponse> responses = new List<LeadResponse>();
        for (Integer i = 0; i < requests.size(); i++) {
            responses.add(new LeadResponse()); // Initialize with default failure
        }

        List<LeadWrapper> leadsToProcess = new List<LeadWrapper>();

        for (Integer i = 0; i < requests.size(); i++) {
            LeadRequest req = requests.get(i);
            LeadResponse res = responses.get(i);

            // --- Input Validation ---
            if (String.isBlank(req.lastName)) {
                res.message = 'Last Name is required for a Lead.';
                continue;
            }
            if (String.isBlank(req.company)) {
                res.message = 'Company is required for a Lead.';
                continue;
            }
            if (String.isBlank(req.status)) {
                res.message = 'Lead Status is required.';
                continue;
            }
            if (String.isNotBlank(req.email) && !Pattern.matches('^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$', req.email)) {
                res.message = 'Invalid Email format provided.';
                continue;
            }


            Lead ld = new Lead();
            ld.FirstName = String.isNotBlank(req.firstName) ? req.firstName : null;
            ld.LastName = req.lastName;
            ld.Company = req.company;
            ld.Status = req.status; // This should be a valid API name of a Lead Status

            // Optional Fields
            ld.Title = String.isNotBlank(req.title) ? req.title : null;
            ld.Phone = String.isNotBlank(req.phone) ? req.phone : null;
            ld.MobilePhone = String.isNotBlank(req.mobilePhone) ? req.mobilePhone : null;
            ld.Email = String.isNotBlank(req.email) ? req.email : null;
            ld.Website = String.isNotBlank(req.website) ? req.website : null;
            ld.LeadSource = String.isNotBlank(req.leadSource) ? req.leadSource : null; // Valid picklist API name
            ld.Industry = String.isNotBlank(req.industry) ? req.industry : null; // Valid picklist API name
            ld.Rating = String.isNotBlank(req.rating) ? req.rating : null; // Valid picklist API name
            ld.AnnualRevenue = req.annualRevenue; // No negative check, as it might be valid in some contexts (e.g. data migration)
                                                  // Add if (req.annualRevenue != null && req.annualRevenue < 0) if needed.
            ld.NumberOfEmployees = req.numberOfEmployees;

            // Address Fields
            ld.Street = String.isNotBlank(req.street) ? req.street : null;
            ld.City = String.isNotBlank(req.city) ? req.city : null;
            ld.State = String.isNotBlank(req.state) ? req.state : null;
            ld.PostalCode = String.isNotBlank(req.postalCode) ? req.postalCode : null;
            ld.Country = String.isNotBlank(req.country) ? req.country : null;
            ld.Description = String.isNotBlank(req.description) ? req.description : null;
            
            leadsToProcess.add(new LeadWrapper(i, ld));
        }

        List<Lead> actualLeadsToInsert = new List<Lead>();
        for (LeadWrapper wrapper : leadsToProcess) {
            actualLeadsToInsert.add(wrapper.leadRec);
        }

        if (!actualLeadsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(actualLeadsToInsert, false); // Allow partial success

            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                LeadWrapper wrapper = leadsToProcess.get(j);
                LeadResponse res = responses.get(wrapper.originalRequestIndex);

                if (sr.isSuccess()) {
                    res.success = true;
                    res.leadId = sr.getId();
                    res.message = 'Lead created successfully.';
                } else {
                    res.leadId = null; // Already null by default if not set
                    String errorMessages = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages += err.getStatusCode() + ': ' + err.getMessage() + '. Fields: ' + String.join(err.getFields(), ', ') + ' ';
                    }
                    res.message = 'Error creating Lead: ' + errorMessages.trim();
                }
            }
        }
        return responses;
    }

    /**
     * @description Helper inner class to associate a Lead sObject with its original request index.
     */
    private class LeadWrapper {
        Integer originalRequestIndex;
        Lead leadRec;

        LeadWrapper(Integer index, Lead ld) {
            this.originalRequestIndex = index;
            this.leadRec = ld;
        }
    }

    /**
     * @description Defines the structure for requesting a Lead creation.
     * Each variable is exposed as an input parameter for the Invocable Action.
     */
    public class LeadRequest {
        @InvocableVariable(label='First Name' description='First name of the lead.' required=false)
        public String firstName;

        @InvocableVariable(label='Last Name' description='Last name of the lead.' required=true)
        public String lastName;

        @InvocableVariable(label='Company' description='Company name for the lead.' required=true)
        public String company;

        @InvocableVariable(label='Lead Status' description='Current status of the lead (e.g., "Open - Not Contacted", "Working - Contacted"). Must be a valid picklist API name.' required=true)
        public String status;

        @InvocableVariable(label='Title' description='Job title of the lead.' required=false)
        public String title;

        @InvocableVariable(label='Phone' description='Primary phone number of the lead.' required=false)
        public String phone;

        @InvocableVariable(label='Mobile Phone' description='Mobile phone number of the lead.' required=false)
        public String mobilePhone;

        @InvocableVariable(label='Email' description='Email address of the lead.' required=false)
        public String email;

        @InvocableVariable(label='Website' description='Website of the lead or their company.' required=false)
        public String website;

        @InvocableVariable(label='Lead Source' description='Source of the lead (e.g., "Web", "Phone Inquiry"). Must be a valid picklist API name.' required=false)
        public String leadSource;

        @InvocableVariable(label='Industry' description='Industry of the lead. Must be a valid picklist API name.' required=false)
        public String industry;

        @InvocableVariable(label='Rating' description='Rating of the lead (e.g., "Hot", "Warm", "Cold"). Must be a valid picklist API name.' required=false)
        public String rating;
        
        @InvocableVariable(label='Annual Revenue' description='Annual revenue of the lead\'s company.' required=false)
        public Decimal annualRevenue;

        @InvocableVariable(label='Number of Employees' description='Number of employees at the lead\'s company.' required=false)
        public Integer numberOfEmployees;

        @InvocableVariable(label='Street' description='Street address for the lead.' required=false)
        public String street;
        @InvocableVariable(label='City' description='City for the lead.' required=false)
        public String city;
        @InvocableVariable(label='State/Province' description='State or province for the lead.' required=false)
        public String state;
        @InvocableVariable(label='Zip/Postal Code' description='Zip or postal code for the lead.' required=false)
        public String postalCode;
        @InvocableVariable(label='Country' description='Country for the lead.' required=false)
        public String country;
        
        @InvocableVariable(label='Description' description='Additional notes or description for the lead.' required=false)
        public String description;
    }

    /**
     * @description Defines the structure for the response of a Lead creation attempt.
     */
    public class LeadResponse {
        @InvocableVariable(label='Lead ID' description='The ID of the newly created Lead record, if successful.')
        public String leadId;

        @InvocableVariable(label='Success' description='Indicates whether the Lead creation was successful.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status message (e.g., success confirmation or error details).')
        public String message;

        public LeadResponse() {
            this.success = false;
            this.message = '';
            this.leadId = null;
        }
    }
}