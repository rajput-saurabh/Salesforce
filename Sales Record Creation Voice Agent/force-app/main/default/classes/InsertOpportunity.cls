public with sharing class InsertOpportunity {

    /**
     * @description Invocable method to create one or more Opportunity records.
     * @param requests A list of OpportunityRequest objects, each containing details for an Opportunity.
     * @return A list of OpportunityResponse objects, indicating the outcome for each requested Opportunity creation.
     */
    @InvocableMethod(
        label='Create Opportunity'
        description='Creates new Opportunity records with the provided details. Handles multiple requests in a batch.'
        category='Opportunity Management'
    )
    public static List<OpportunityResponse> createOpportunities(List<OpportunityRequest> requests) {
        List<OpportunityResponse> responses = new List<OpportunityResponse>();
        // Initialize response list to match the size of requests, ensuring one response per request.
        for (Integer i = 0; i < requests.size(); i++) {
            responses.add(new OpportunityResponse());
        }

        List<OpportunityWrapper> opportunitiesToProcess = new List<OpportunityWrapper>();

        // Validate requests and prepare Opportunity sObjects
        for (Integer i = 0; i < requests.size(); i++) {
            OpportunityRequest req = requests.get(i);
            OpportunityResponse res = responses.get(i); // Get the pre-initialized response for this request
            res.success = false; // Default to failure, will be updated upon successful DML

            // --- Input Validation ---
            if (String.isBlank(req.name)) {
                res.message = 'Opportunity Name is required.';
                continue; // Skip to the next request, response already marked as failure
            }
            if (String.isBlank(req.stageName)) {
                res.message = 'Stage Name is required.';
                continue;
            }
            if (req.closeDate == null) {
                res.message = 'Close Date is required.';
                continue;
            }
            // Basic sanity check for the year in CloseDate
            if (req.closeDate.year() < 1900 || req.closeDate.year() > 2200) {
                res.message = 'Close Date contains an invalid year. Please provide a valid date.';
                continue;
            }
            if (req.amount != null && req.amount < 0) {
                res.message = 'Amount cannot be negative.';
                continue;
            }

            Opportunity opp = new Opportunity();
            opp.Name = req.name;
            opp.StageName = req.stageName;
            opp.CloseDate = req.closeDate;

            if (req.amount != null) {
                opp.Amount = req.amount;
            }

            if (String.isNotBlank(req.accountId)) {
                // Validate Account ID format (must be 15 or 18 characters)
                if (req.accountId.length() != 15 && req.accountId.length() != 18) {
                    res.message = 'Account ID has an invalid format. It must be 15 or 18 characters long.';
                    continue;
                }
                try {
                    // Further validation by attempting to cast to ID type
                    Id accountSfdcId = Id.valueOf(req.accountId);
                    opp.AccountId = accountSfdcId;
                } catch (System.StringException e) {
                    res.message = 'Invalid Account ID format: ' + req.accountId + '. Error: ' + e.getMessage();
                    continue;
                }
            }

            if (String.isNotBlank(req.description)) {
                opp.Description = req.description;
            }
            
            // If all validations pass for this request, add to process list
            opportunitiesToProcess.add(new OpportunityWrapper(i, opp));
        }

        // Extract actual Opportunity sObjects to insert from wrappers
        List<Opportunity> actualOppsToInsert = new List<Opportunity>();
        for (OpportunityWrapper wrapper : opportunitiesToProcess) {
            actualOppsToInsert.add(wrapper.opp);
        }

        // Perform DML operation if there are valid opportunities to insert
        if (!actualOppsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(actualOppsToInsert, false); // Allow partial success

            // Process DML results and update responses
            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                // Get the wrapper corresponding to this SaveResult
                // The order in actualOppsToInsert matches opportunitiesToProcess
                OpportunityWrapper wrapper = opportunitiesToProcess.get(j); 
                // Get the original response object using the index stored in the wrapper
                OpportunityResponse res = responses.get(wrapper.originalRequestIndex);

                if (sr.isSuccess()) {
                    res.success = true;
                    res.opportunityId = sr.getId();
                    res.message = 'Opportunity created successfully.';
                } else {
                    res.success = false; // Explicitly set, though it was default
                    res.opportunityId = null;
                    String errorMessages = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages += err.getStatusCode() + ': ' + err.getMessage() + '. Fields: ' + String.join(err.getFields(), ', ') + ' ';
                    }
                    res.message = 'Error creating Opportunity: ' + errorMessages.trim();
                }
            }
        }
        return responses;
    }

    /**
     * @description Helper inner class to associate an Opportunity sObject with its original request index.
     * This is used to correctly map DML results back to the appropriate response object in batch processing.
     * Inner classes in Apex are implicitly static if they don't access instance members of the outer class.
     * The 'static' keyword is not explicitly used in their declaration.
     */
    private class OpportunityWrapper { // Removed 'static' keyword here
        Integer originalRequestIndex;
        Opportunity opp;

        OpportunityWrapper(Integer index, Opportunity o) {
            this.originalRequestIndex = index;
            this.opp = o;
        }
    }

    /**
     * @description Defines the structure for requesting an Opportunity creation.
     * Each variable is exposed as an input parameter for the Invocable Action.
     */
    public class OpportunityRequest {
        @InvocableVariable(
            label='Opportunity Name'
            description='Name of the new opportunity (e.g., "ACME Corp Deal").'
            required=true
        )
        public String name;

        @InvocableVariable(
            label='Stage Name'
            description='Current stage of the opportunity (e.g., "Prospecting", "Qualification", "Closed Won"). Must be a valid picklist value.'
            required=true
        )
        public String stageName;

        @InvocableVariable(
            label='Close Date'
            description='Expected date when the opportunity is anticipated to close. Format: YYYY-MM-DD.'
            required=true
        )
        public Date closeDate;

        @InvocableVariable(
            label='Amount'
            description='Estimated monetary value of the opportunity. Must be a non-negative number.'
            required=false
        )
        public Decimal amount;

        @InvocableVariable(
            label='Account ID'
            description='The 15 or 18-character ID of the Account related to this opportunity. Optional.'
            required=false
        )
        public String accountId;

        @InvocableVariable(
            label='Description'
            description='An optional description or notes for the opportunity.'
            required=false
        )
        public String description;
    }

    /**
     * @description Defines the structure for the response of an Opportunity creation attempt.
     * Each variable is exposed as an output parameter for the Invocable Action.
     */
    public class OpportunityResponse {
        @InvocableVariable(
            label='Opportunity ID'
            description='The ID of the newly created Opportunity record, if the operation was successful.'
        )
        public String opportunityId;

        @InvocableVariable(
            label='Success'
            description='Indicates whether the Opportunity creation was successful (true) or not (false).'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='A status message providing details about the operation, such as success confirmation or error descriptions.'
        )
        public String message;

        // Constructor to initialize default values
        public OpportunityResponse() {
            this.success = false; // Default to false
            this.message = '';
            this.opportunityId = null;
        }
    }
}